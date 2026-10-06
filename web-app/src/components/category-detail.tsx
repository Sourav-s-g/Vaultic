"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { useCategories, useCategoryBudget, useCurrentUserId, useDeleteCategoryBudget, useSaveCategoryBudget, useTransactions } from "@/lib/data/hooks";
import { TransactionForm } from "@/components/transaction-form";
import { TransactionRow } from "@/components/transaction-list";
import { Modal } from "@/components/modal";
import { TopBar } from "@/components/finance-ui";
import { normalizeCategoryName } from "@/lib/categories/data";
import { databaseAmountToPaise, formatPaise, parseAmountToPaise } from "@/lib/money";
import type { TransactionRow as TransactionRecord } from "@/lib/data/finance";

function formatMonthLabel(value: string): string {
  if (!value || value === "all") return "All time";
  const [year, month] = value.split("-").map(Number);
  const safeDate = new Date(Date.UTC(year, month - 1, 1, 12));
  return new Intl.DateTimeFormat("en-IN", { month: "short", year: "numeric" }).format(safeDate);
}

function getMonthDays(monthKey: string): number {
  if (!monthKey || monthKey === "all") return 30;
  const [year, month] = monthKey.split("-").map(Number);
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

export function CategoryDetailPage({ category }: { category: string }) {
  const user = useCurrentUserId();
  const categories = useCategories(user.data);
  const [selectedMonth, setSelectedMonth] = useState(() => new Date().toISOString().slice(0, 7));
  const [showAllTime, setShowAllTime] = useState(false);
  const [search, setSearch] = useState("");
  const [budgetInput, setBudgetInput] = useState<string>();
  const [budgetError, setBudgetError] = useState("");
  const [editing, setEditing] = useState<TransactionRecord>();
  const [pendingRemoval, setPendingRemoval] = useState<TransactionRecord>();
  const [formOpen, setFormOpen] = useState(false);

  const decodedCategory = category;
  const isAllDebit = decodedCategory === "all-debit";
  const matchedCategory = useMemo(() => {
    if (isAllDebit) return null;
    return (categories.data ?? []).find((item) => normalizeCategoryName(item.name) === normalizeCategoryName(decodedCategory)) ?? null;
  }, [categories.data, decodedCategory, isAllDebit]);

  const budget = useCategoryBudget(user.data, matchedCategory?.name ?? "");
  const currentBudgetInput = budgetInput ?? (budget.data !== null && budget.data !== undefined ? String(budget.data / 100) : "");
  const transactions = useTransactions(user.data, search);
  const topBar = <TopBar isFetching={transactions.isFetching} onRefresh={() => { void transactions.refetch(); }} title={isAllDebit ? "All debits" : matchedCategory?.name ?? decodedCategory} />;
  const saveBudget = useSaveCategoryBudget(user.data);
  const deleteBudget = useDeleteCategoryBudget(user.data);

  const filteredRows = useMemo(() => {
    const allRows = transactions.data?.pages.flatMap((page) => page.items) ?? [];
    const normalizedSearch = search.trim().toLowerCase();
    return allRows.filter((row) => {
      if (row.type !== "Debit") return false;
      if (normalizedSearch && !`${row.description} ${row.category ?? ""}`.toLowerCase().includes(normalizedSearch)) return false;
      if (showAllTime) return isAllDebit ? true : (row.category ?? "").trim().toLocaleLowerCase("en") === (matchedCategory?.name ?? decodedCategory).trim().toLocaleLowerCase("en");
      if (row.date.slice(0, 7) !== selectedMonth) return false;
      return isAllDebit ? true : (row.category ?? "").trim().toLocaleLowerCase("en") === (matchedCategory?.name ?? decodedCategory).trim().toLocaleLowerCase("en");
    });
  }, [decodedCategory, isAllDebit, matchedCategory, search, selectedMonth, showAllTime, transactions.data]);

  const monthSpend = filteredRows.reduce((sum, row) => sum + databaseAmountToPaise(Number(row.amount)), 0);
  const budgetPaise = budget.data ?? 0;
  const daysThisMonth = getMonthDays(selectedMonth);
  const dailyAverage = monthSpend / Math.max(daysThisMonth, 1);
  const projected = dailyAverage * daysThisMonth;

  async function handleBudgetSave(event: React.FormEvent) {
    event.preventDefault();
    if (!matchedCategory) return;
    try {
      const paise = parseAmountToPaise((budgetInput ?? currentBudgetInput).trim());
      await saveBudget.mutateAsync({ category: matchedCategory.name, amountPaise: paise });
      setBudgetError("");
    } catch (error) {
      setBudgetError(error instanceof Error ? error.message : "Budget amount is invalid.");
    }
  }

  async function handleBudgetClear() {
    if (!matchedCategory) return;
    setBudgetInput("");
    await deleteBudget.mutateAsync(matchedCategory.name);
  }

  if (user.isLoading || categories.isLoading || transactions.isLoading) {
    return <main className="feature-page">{topBar}<div aria-busy="true"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-panel" /></div></main>;
  }
  if (user.error || categories.error || transactions.error) {
    return <main className="feature-page">{topBar}<section className="feature-panel" role="alert"><h1>Could not load this category</h1><p>{(user.error ?? categories.error ?? transactions.error)?.message}</p><button className="button button-primary" onClick={() => { void user.refetch(); void categories.refetch(); void transactions.refetch(); }} type="button">Try again</button></section></main>;
  }
  if (!user.data) return <main className="feature-page">{topBar}<p role="status">Sign in to view category details.</p></main>;
  if (!isAllDebit && !matchedCategory) {
    return <main className="feature-page">{topBar}<section className="feature-panel"><h1>Category not found</h1><p>That category is no longer available for this account.</p><Link className="button button-primary" href="/">Back home</Link></section></main>;
  }

  return (
    <main className="feature-page category-detail-page">
      {topBar}

      <div className="category-toolbar">
        <label className="inline-field">
          <span className="muted-copy">Month</span>
          <input aria-label="Choose month" className="text-input" onChange={(event) => { setShowAllTime(false); setSelectedMonth(event.target.value); }} type="month" value={selectedMonth} />
        </label>
        <button className="button button-secondary" onClick={() => setShowAllTime((current) => !current)} type="button">{showAllTime ? "Current month" : "All time"}</button>
      </div>

      {!isAllDebit && (
        <section className="feature-panel budget-panel">
          <div className="panel-heading"><h2>Budget</h2>{budgetPaise > 0 && <button className="text-button" onClick={() => void handleBudgetClear()} type="button">Clear</button>}</div>
          <form className="budget-form" onSubmit={(event) => void handleBudgetSave(event)}>
            <label className="sr-only" htmlFor="category-budget">Category budget</label>
            <input className="text-input" id="category-budget" onChange={(event) => setBudgetInput(event.target.value)} placeholder="₹1000" value={currentBudgetInput} />
            <button className="button button-primary" disabled={saveBudget.isPending} type="submit">{saveBudget.isPending ? "Saving…" : "Save budget"}</button>
          </form>
          {budgetError && <p className="inline-error" role="alert">{budgetError}</p>}
          {budgetPaise > 0 && <div className="budget-progress"><div className="budget-progress-bar" style={{ width: `${Math.min((monthSpend / budgetPaise) * 100, 100)}%` }} /><span>{monthSpend >= budgetPaise ? "Over budget" : `${Math.round((monthSpend / budgetPaise) * 100)}% used`}</span></div>}
        </section>
      )}

      <div className="summary-grid category-summary-grid">
        <section className="feature-panel summary-panel">
          <div className="panel-heading"><h2>{showAllTime ? "All time" : formatMonthLabel(selectedMonth)}</h2><span className="muted-copy">Total spent</span></div>
          <strong className="summary-total">{formatPaise(monthSpend)}</strong>
          <div className="mini-stats">
            <span>Daily average: {formatPaise(Math.round(dailyAverage))}</span>
            <span>Projected month end: {formatPaise(Math.round(projected))}</span>
          </div>
        </section>
      </div>

      <section className="feature-panel">
        <div className="panel-heading"><h2>Transactions</h2><span className="muted-copy">{filteredRows.length} matches</span></div>
        <div className="transactions-toolbar compact-toolbar">
          <label className="sr-only" htmlFor="category-search">Search this category</label>
          <div className="search-input-wrap"><input autoComplete="off" className="text-input" id="category-search" onChange={(event) => setSearch(event.target.value)} placeholder="Search description" value={search} /></div>
        </div>
        {filteredRows.length === 0 ? (
          <p className="empty-state">No debit transactions match this category.</p>
        ) : (
          <>
            {filteredRows.map((row) => <TransactionRow key={row.transaction_id} onDelete={setPendingRemoval} onEdit={setEditing} row={row} />)}
            <div className="pagination-actions"><button className="button button-secondary" type="button">Load more</button></div>
          </>
        )}
      </section>

      <Modal className="confirm-dialog" onClose={() => setPendingRemoval(undefined)} open={Boolean(pendingRemoval)} titleId="delete-transaction-title">
        <section className="modal-content">
          <h2 id="delete-transaction-title">Delete transaction?</h2>
          {pendingRemoval && <p className="delete-transaction-details"><strong>{pendingRemoval.description}</strong><span>{formatPaise(databaseAmountToPaise(Number(pendingRemoval.amount)))} · {pendingRemoval.date}</span></p>}
          <div className="wizard-actions">
            <button className="button button-secondary" onClick={() => setPendingRemoval(undefined)} type="button">Cancel</button>
            <button className="button button-danger" type="button">Delete</button>
          </div>
        </section>
      </Modal>

      {formOpen && user.data && (
        <TransactionForm
          key={editing?.transaction_id ?? "new"}
          onClose={() => {
            setFormOpen(false);
            setEditing(undefined);
          }}
          onSaved={() => setPendingRemoval(undefined)}
          transaction={editing}
          userId={user.data}
        />
      )}
    </main>
  );
}
