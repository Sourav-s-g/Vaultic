"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { ArrowDownLeft, ArrowLeft, ArrowRight, ArrowUpRight, Search, Trash2 } from "lucide-react";
import { formatPaise, databaseAmountToPaise } from "@/lib/money";
import { transactionDateInputValue, parseDateInput } from "@/lib/dates";
import { useCategories, useCurrentUserId, useDeleteTransaction, useTransactions, useUndoDeleteTransaction } from "@/lib/data/hooks";
import type { TransactionRow as TransactionRecord } from "@/lib/data/finance";
import { TransactionForm } from "@/components/transaction-form";
import { Modal } from "@/components/modal";
import { TopBar } from "@/components/finance-ui";
import { CategoryDonutChart, WeeklySpendingChart, type DonutSlice } from "@/components/finance-charts";
import { DATA_COLORS, normalizeCategoryName } from "@/lib/categories/data";
import { getCurrentMonthKey, isCarryForwardTransaction } from "@/lib/finance-summary";

function displayFullDate(value: string): string {
  const { year, month, day } = parseDateInput(transactionDateInputValue(value));
  return `${String(day).padStart(2, "0")}/${String(month).padStart(2, "0")}/${year}`;
}

function formatMonth(value: string): string {
  const [year, month] = value.split("-").map(Number);
  return new Intl.DateTimeFormat("en-IN", { month: "long", year: "numeric" })
    .format(new Date(Date.UTC(year, month - 1, 1, 12)));
}

function changeMonth(monthKey: string, offset: number): string {
  const [year, month] = monthKey.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1 + offset, 1, 12));
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

function compactAmount(amount: number): string {
  const paise = databaseAmountToPaise(amount);
  const formatted = formatPaise(paise);
  return paise % 100 === 0 ? formatted.slice(0, -3) : formatted;
}

function compactPaise(paise: number): string {
  const formatted = formatPaise(paise);
  return paise % 100 === 0 ? formatted.slice(0, -3) : formatted;
}

export function TransactionRows({
  rows,
  onEdit,
  onDelete,
}: {
  rows: TransactionRecord[];
  onEdit?: (row: TransactionRecord) => void;
  onDelete?: (row: TransactionRecord) => void;
}) {
  return (
    <div className="transaction-group">
      {rows.map((row) => <TransactionRow key={row.transaction_id} onDelete={onDelete} onEdit={onEdit} row={row} />)}
    </div>
  );
}

export function TransactionRow({
  row,
  onEdit,
  onDelete,
}: {
  row: TransactionRecord;
  onEdit?: (row: TransactionRecord) => void;
  onDelete?: (row: TransactionRecord) => void;
}) {
  const category = row.category?.trim() || "Uncategorized";
  const signed = row.type === "Credit" ? "+" : "-";
  return (
    <article
      aria-label={onEdit ? `Edit transaction: ${row.description}` : undefined}
      className="transaction-row"
      onClick={() => onEdit?.(row)}
      onKeyDown={(event) => { if (onEdit && (event.key === "Enter" || event.key === " ")) { event.preventDefault(); onEdit(row); } }}
      role={onEdit ? "button" : undefined}
      tabIndex={onEdit ? 0 : undefined}
    >
      <span aria-hidden="true" className={`transaction-icon-tile${row.type === "Credit" ? " is-credit" : ""}`}>
        {row.type === "Credit" ? <ArrowDownLeft size={19} /> : <ArrowUpRight size={19} />}
      </span>
      <div className="transaction-description">
        <strong>{row.description}</strong>
        <span className="transaction-subtitle">{displayFullDate(row.date)} <span aria-hidden="true">•</span> {category}</span>
      </div>
      <span className={`transaction-amount${row.type === "Credit" ? " is-credit" : " is-debit"}`}>{signed}{compactAmount(row.amount)}</span>
      <span className="transaction-status">Completed</span>
      {onDelete && <button aria-label={`Delete transaction: ${row.description}`} className="transaction-delete" onClick={(event) => { event.stopPropagation(); onDelete(row); }} title={`Delete transaction: ${row.description}`} type="button"><Trash2 aria-hidden="true" size={18} /></button>}
    </article>
  );
}

export function RecentTransactions() {
  const user = useCurrentUserId();
  const transactions = useTransactions(user.data);
  if (user.isLoading || transactions.isLoading) {
    return <section aria-busy="true" className="recent-transactions"><h2>Recent transactions</h2><div className="skeleton skeleton-panel" /></section>;
  }
  if (user.error || transactions.error) {
    return <section className="recent-transactions" role="alert"><h2>Recent transactions</h2><p>{(user.error ?? transactions.error)?.message}</p><button className="button button-secondary" onClick={() => { void user.refetch(); void transactions.refetch(); }} type="button">Try again</button></section>;
  }

  const latestFive = transactions.data?.pages.flatMap((page) => page.items).slice(0, 5) ?? [];
  return (
    <section className="recent-transactions" aria-labelledby="recent-heading">
      <div className="panel-heading"><h2 id="recent-heading">Recent transactions</h2><Link className="text-button" href="/transactions">View all</Link></div>
      {latestFive.length === 0
        ? <p className="empty-state">Add your first transaction</p>
        : <TransactionRows rows={latestFive} onDelete={undefined} onEdit={undefined} />}
    </section>
  );
}

export function TransactionsPage() {
  const user = useCurrentUserId();
  const categories = useCategories(user.data);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState<TransactionRecord>();
  const [pendingRemoval, setPendingRemoval] = useState<TransactionRecord>();
  const [selectedMonth, setSelectedMonth] = useState(getCurrentMonthKey);
  const [selectedCategory, setSelectedCategory] = useState("");
  const transactions = useTransactions(user.data, debouncedSearch);
  const remove = useDeleteTransaction(user.data);
  const undo = useUndoDeleteTransaction(user.data);

  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => window.clearTimeout(timer);
  }, [search]);

  const allRows = useMemo(() => transactions.data?.pages.flatMap((page) => page.items) ?? [], [transactions.data]);
  const monthRows = useMemo(() => allRows.filter((row) => transactionDateInputValue(row.date).slice(0, 7) === selectedMonth), [allRows, selectedMonth]);
  const monthSummary = useMemo(() => {
    let income = 0;
    let spent = 0;
    for (const row of monthRows) {
      if (isCarryForwardTransaction(row)) continue;
      if (row.type === "Credit") income += databaseAmountToPaise(Number(row.amount));
      if (row.type === "Debit") spent += databaseAmountToPaise(Number(row.amount));
    }
    return { income, spent, balance: income - spent };
  }, [monthRows]);

  const categoryTotals = useMemo(() => {
    const totals = new Map<string, { name: string; amountPaise: number }>();
    for (const row of monthRows) {
      if (row.type !== "Debit" || isCarryForwardTransaction(row)) continue;
      const name = row.category?.trim() || "Other";
      const key = normalizeCategoryName(name);
      const current = totals.get(key) ?? { name, amountPaise: 0 };
      totals.set(key, { ...current, amountPaise: current.amountPaise + databaseAmountToPaise(Number(row.amount)) });
    }
    const order = new Map((categories.data ?? []).map((category, index) => [normalizeCategoryName(category.name), index]));
    return [...totals.values()].sort((left, right) => {
      const leftIndex = order.get(normalizeCategoryName(left.name));
      const rightIndex = order.get(normalizeCategoryName(right.name));
      if (leftIndex !== undefined || rightIndex !== undefined) {
        return (leftIndex ?? Number.MAX_SAFE_INTEGER) - (rightIndex ?? Number.MAX_SAFE_INTEGER);
      }
      return 0;
    });
  }, [categories.data, monthRows]);

  const donutTotal = categoryTotals.reduce((sum, item) => sum + item.amountPaise, 0);
  const slices: DonutSlice[] = categoryTotals.map((item, index) => ({
    name: item.name,
    amountPaise: item.amountPaise,
    color: DATA_COLORS.history[index % DATA_COLORS.history.length],
  }));
  const shownRows = useMemo(() => monthRows.filter((row) =>
    !selectedCategory || normalizeCategoryName(row.category ?? "Other") === normalizeCategoryName(selectedCategory),
  ), [monthRows, selectedCategory]);
  const shownGroupedRows = useMemo(() => {
    const groups = new Map<string, TransactionRecord[]>();
    for (const row of shownRows) {
      const date = transactionDateInputValue(row.date);
      groups.set(date, [...(groups.get(date) ?? []), row]);
    }
    return [...groups.entries()].sort(([left], [right]) => right.localeCompare(left));
  }, [shownRows]);
  const monthLabel = formatMonth(selectedMonth);
  const currentMonth = getCurrentMonthKey();

  function queueToast(payload: { message: string; row?: TransactionRecord; error?: boolean; onUndo?: () => Promise<void> | void }) {
    if (typeof window !== "undefined") {
      window.dispatchEvent(new CustomEvent("vaultic:toast", { detail: payload }));
    }
  }

  function startEditing(row: TransactionRecord) {
    setEditing(row);
    setFormOpen(true);
  }

  async function confirmDelete() {
    if (!pendingRemoval) return;
    const row = pendingRemoval;
    setPendingRemoval(undefined);
    try {
      const deleted = await remove.mutateAsync(row.transaction_id);
      queueToast({
        message: "Transaction deleted.",
        row: deleted,
        onUndo: async () => {
          try {
            await undo.mutateAsync(deleted);
            queueToast({ message: "Transaction restored." });
          } catch (error) {
            queueToast({
              message: error instanceof Error ? error.message : "Could not undo deletion.",
              error: true,
            });
          }
        },
      });
    } catch (error) {
      queueToast({
        message: error instanceof Error ? error.message : "Could not delete this transaction.",
        error: true,
      });
    }
  }

  const topBar = <TopBar isFetching={transactions.isFetching} onRefresh={() => { void transactions.refetch(); }} title="Transaction History" />;
  if (user.isLoading || categories.isLoading || (transactions.isLoading && transactions.data === undefined)) {
    return <main className="feature-page">{topBar}<div aria-busy="true"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-panel" /><div className="skeleton skeleton-panel" /></div></main>;
  }
  if (user.error) {
    return <main className="feature-page">{topBar}<section className="feature-panel" role="alert"><h1>Could not load your account</h1><p>{user.error.message}</p><button className="button button-primary" onClick={() => void user.refetch()} type="button">Try again</button></section></main>;
  }
  if (!user.data) return <main className="feature-page">{topBar}<p role="status">Sign in to view transactions.</p></main>;

  return (
    <main className="feature-page transactions-page">
      {topBar}
      <div className="month-selector-row">
        <button aria-label="Previous month" className="month-nav-button" onClick={() => setSelectedMonth((month) => changeMonth(month, -1))} type="button"><ArrowLeft aria-hidden="true" size={18} /></button>
        <h2 aria-live="polite" className="month-selector-label">{monthLabel}</h2>
        <button aria-label="Next month" className="month-nav-button" disabled={selectedMonth >= currentMonth} onClick={() => setSelectedMonth((month) => changeMonth(month, 1))} type="button"><ArrowRight aria-hidden="true" size={18} /></button>
      </div>

      <div className="history-dashboard-grid">
        <CategoryDonutChart
          onSelectCategory={setSelectedCategory}
          selectedCategory={selectedCategory}
          slices={slices}
          totalPaise={donutTotal}
        />
        <section aria-label="Monthly summary" className="transactions-summary-panel">
          <div className="summary-block"><strong>{compactPaise(monthSummary.income)}</strong><span>Monthly Income</span></div>
          <div className="summary-block"><strong>{compactPaise(monthSummary.spent)}</strong><span>Monthly Spent</span></div>
          <div className={`summary-block total-balance${monthSummary.balance >= 0 ? " is-positive" : " is-negative"}`}><strong style={{ color: monthSummary.balance >= 0 ? DATA_COLORS.suggested.Travel : DATA_COLORS.expense }}>{compactPaise(monthSummary.balance)}</strong><span>Total Balance</span></div>
        </section>
        <WeeklySpendingChart rows={allRows} />
      </div>

      <div className="transactions-toolbar history-search">
        <label className="sr-only" htmlFor="transaction-search">Search transactions</label>
        <div className="search-input-wrap"><Search aria-hidden="true" size={21} /><input autoComplete="off" className="text-input" id="transaction-search" onChange={(event) => setSearch(event.target.value)} placeholder="Search transactions..." value={search} /></div>
      </div>
      {selectedCategory && (
        <div className="active-filter">
          <span>Category: {selectedCategory}</span>
          <button className="text-button" onClick={() => setSelectedCategory("")} type="button">Clear filter</button>
        </div>
      )}

      {transactions.error ? (
        <section className="feature-panel" role="alert"><h2>Could not load transactions</h2><p>{transactions.error.message}</p><button className="button button-primary" onClick={() => void transactions.refetch()} type="button">Try again</button></section>
      ) : shownRows.length === 0 ? (
        <section className="feature-panel empty-state" aria-live="polite">{debouncedSearch || selectedCategory ? "No transactions match these filters." : "No transactions yet. Your history will appear here."}</section>
      ) : (
        <>
          {shownGroupedRows.map(([date, rows]) => <section aria-label={displayFullDate(date)} className="transaction-date-group" key={date}><h2>{displayFullDate(date)}</h2><TransactionRows onDelete={setPendingRemoval} onEdit={startEditing} rows={rows} /></section>)}
          {transactions.hasNextPage && <div className="pagination-actions"><button className="button button-secondary" disabled={transactions.isFetchingNextPage} onClick={() => void transactions.fetchNextPage()} type="button">{transactions.isFetchingNextPage ? "Loading…" : "Load more"}</button></div>}
        </>
      )}
      {transactions.isFetching && !transactions.isFetchingNextPage && <p aria-live="polite" className="muted-copy">Refreshing transactions…</p>}
      <Modal className="confirm-dialog" onClose={() => setPendingRemoval(undefined)} open={Boolean(pendingRemoval)} titleId="delete-transaction-title">
        <section className="modal-content">
          <h2 id="delete-transaction-title">Delete transaction?</h2>
          {pendingRemoval && <p className="delete-transaction-details"><strong>{pendingRemoval.description}</strong><span>{formatPaise(databaseAmountToPaise(pendingRemoval.amount))} · {displayFullDate(pendingRemoval.date)}</span></p>}
          <p>This transaction will be deleted. You can undo this action from the notice for a short time.</p>
          <div className="wizard-actions">
            <button className="button button-secondary" onClick={() => setPendingRemoval(undefined)} type="button">Cancel</button>
            <button className="button button-danger" disabled={remove.isPending} onClick={() => void confirmDelete()} type="button">{remove.isPending ? "Deleting…" : "Delete"}</button>
          </div>
        </section>
      </Modal>
      {formOpen && user.data && (
        <TransactionForm
          key={editing?.transaction_id ?? "edit"}
          onClose={() => { setFormOpen(false); setEditing(undefined); }}
          onSaved={() => queueToast({ message: "Transaction updated." })}
          transaction={editing}
          userId={user.data}
        />
      )}
    </main>
  );
}
