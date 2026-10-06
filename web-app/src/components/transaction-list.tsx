"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowDownLeft, ArrowUpRight, Plus, Search, Trash2 } from "lucide-react";
import { formatPaise, databaseAmountToPaise } from "@/lib/money";
import { transactionDateInputValue, parseDateInput } from "@/lib/dates";
import { useCategories, useCurrentUserId, useDeleteTransaction, useTransactions, useUndoDeleteTransaction } from "@/lib/data/hooks";
import type { TransactionRow as TransactionRecord } from "@/lib/data/finance";
import { TransactionForm } from "@/components/transaction-form";
import { Modal } from "@/components/modal";
import { CategoryCardStrip, DashboardTabs } from "@/components/finance-ui";

function dateHeading(value: string): string {
  const { year, month, day } = parseDateInput(value);
  const localMidday = new Date(year, month - 1, day, 12);
  return new Intl.DateTimeFormat("en-IN", { weekday: "long", day: "numeric", month: "long", year: "numeric" }).format(localMidday);
}

function displayAmount(amount: number): string {
  try {
    return formatPaise(databaseAmountToPaise(amount));
  } catch {
    return "Amount unavailable";
  }
}

function displayDate(value: string): string {
  const date = transactionDateInputValue(value);
  const [year, month, day] = date.split("-").map(Number);
  return new Intl.DateTimeFormat("en-IN", { day: "numeric", month: "short" }).format(new Date(year, month - 1, day, 12));
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
  const category = row.category?.trim();
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
        <span className="transaction-subtitle">{displayDate(row.date)} · {category || "Uncategorized"} · {row.type === "Credit" ? "Cr" : "Dr"}</span>
      </div>
      <span className={`transaction-amount${row.type === "Credit" ? " is-credit" : " is-debit"}`}>{row.type === "Credit" ? "+" : "-"}{displayAmount(row.amount)}</span>
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

export function TransactionsPage({ startOpen = false }: { startOpen?: boolean }) {
  const router = useRouter();
  const user = useCurrentUserId();
  const categories = useCategories(user.data);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [formOpen, setFormOpen] = useState(startOpen);
  const [editing, setEditing] = useState<TransactionRecord>();
  const [pendingRemoval, setPendingRemoval] = useState<TransactionRecord>();
  const [toast, setToast] = useState<{ message: string; row?: TransactionRecord; error?: boolean }>();
  const [selectedMonth, setSelectedMonth] = useState(() => new Date().toISOString().slice(0, 7));
  const transactions = useTransactions(user.data, debouncedSearch);
  const remove = useDeleteTransaction(user.data);
  const undo = useUndoDeleteTransaction(user.data);

  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => window.clearTimeout(timer);
  }, [search]);

  const allRows = useMemo(() => transactions.data?.pages.flatMap((page) => page.items) ?? [], [transactions.data]);
  const monthRows = useMemo(() => allRows.filter((row) => row.date.slice(0, 7) === selectedMonth), [allRows, selectedMonth]);
  const groupedRows = useMemo(() => {
    const groups = new Map<string, TransactionRecord[]>();
    for (const row of monthRows) {
      const date = transactionDateInputValue(row.date);
      groups.set(date, [...(groups.get(date) ?? []), row]);
    }
    return [...groups.entries()].sort(([left], [right]) => right.localeCompare(left));
  }, [monthRows]);

  const monthSummary = useMemo(() => {
    let income = 0;
    let expense = 0;
    for (const row of monthRows) {
      if (row.type === "Credit" && !row.transaction_id.toLowerCase().startsWith("carry-forward-")) income += databaseAmountToPaise(Number(row.amount));
      if (row.type === "Debit" && !row.transaction_id.toLowerCase().startsWith("carry-forward-")) expense += databaseAmountToPaise(Number(row.amount));
    }
    return { income, expense, net: income - expense };
  }, [monthRows]);

  const monthLabel = useMemo(() => new Date(`${selectedMonth}-01T12:00:00`).toLocaleString("en-IN", { month: "long", year: "numeric" }), [selectedMonth]);
  const categoryTotals = useMemo(() => {
    const totals = new Map<string, number>();
    for (const row of monthRows) {
      if (row.type !== "Debit") continue;
      const key = (row.category || "Other").trim() || "Other";
      totals.set(key, (totals.get(key) ?? 0) + databaseAmountToPaise(Number(row.amount)));
    }
    return [...totals.entries()].sort(([, left], [, right]) => right - left);
  }, [monthRows]);

  const chartTotal = categoryTotals.reduce((sum, [, value]) => sum + value, 0);
  const pieSlices = categoryTotals.map(([label, value], index) => ({ label, value, color: ["#FF9800", "#9C27B0", "#00BCD4", "#009688", "#FFC107", "#FF4081", "#3F51B5", "#8BC34A", "#607D8B"][index % 9] }));

  function startEditing(row: TransactionRecord) {
    setToast(undefined);
    setEditing(row);
    setFormOpen(true);
  }

  async function confirmDelete() {
    if (!pendingRemoval) return;
    const row = pendingRemoval;
    setPendingRemoval(undefined);
    try {
      const deleted = await remove.mutateAsync(row.transaction_id);
      setToast({ message: "Transaction deleted.", row: deleted });
      window.setTimeout(() => setToast((current) => current?.row?.transaction_id === deleted.transaction_id ? undefined : current), 8_000);
    } catch (error) {
      setToast({ message: error instanceof Error ? error.message : "Could not delete this transaction.", error: true });
    }
  }

  async function undoDeletion() {
    if (!toast?.row) return;
    try {
      await undo.mutateAsync(toast.row);
      setToast({ message: "Transaction restored." });
    } catch (error) {
      setToast({ message: error instanceof Error ? error.message : "Could not undo deletion.", error: true });
    }
  }

  if (user.isLoading || (transactions.isLoading && transactions.data === undefined)) {
    return <main className="feature-page" aria-busy="true"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-panel" /><div className="skeleton skeleton-panel" /></main>;
  }
  if (user.error) {
    return <main className="feature-page"><section className="feature-panel" role="alert"><h1>Could not load your account</h1><p>{user.error.message}</p><button className="button button-primary" onClick={() => void user.refetch()} type="button">Try again</button></section></main>;
  }
  if (!user.data) return <main className="feature-page"><p role="status">Sign in to view transactions.</p></main>;

  return (
    <main className="feature-page">
      <section className="feature-heading">
        <div><p className="eyebrow">LEDGER</p><h1>Transactions</h1><p className="heading-copy">Search and manage your transaction history.</p></div>
        <button className="button button-primary header-add-button" onClick={() => { setEditing(undefined); setFormOpen(true); }} type="button"><Plus aria-hidden="true" size={16} /> Add transaction</button>
      </section>
      <div className="transactions-summary-panel">
        <div className="summary-block"><span>Income</span><strong>{formatPaise(monthSummary.income)}</strong></div>
        <div className="summary-block"><span>Expense</span><strong>{formatPaise(monthSummary.expense)}</strong></div>
        <div className="summary-block"><span>Net</span><strong>{formatPaise(monthSummary.net)}</strong></div>
        <div className="summary-block"><span>Cumulative balance</span><strong>{formatPaise(monthSummary.income - monthSummary.expense)}</strong></div>
      </div>
      <div className="month-selector-row">
        <Link className="button button-secondary" href="/">← Home</Link>
        <label className="inline-field">
          <span className="muted-copy">Month</span>
          <input aria-label="Select month" className="text-input" onChange={(event) => setSelectedMonth(event.target.value)} type="month" value={selectedMonth} />
        </label>
      </div>
      <CategoryCardStrip categories={(categories.data ?? []).map((category) => ({ name: category.name, amountPaise: categoryTotals.find(([name]) => name === category.name)?.[1] ?? 0, href: `/categories/${encodeURIComponent(category.name)}` }))} monthSpentPaise={monthSummary.expense} />
      <DashboardTabs />
      <div className="transactions-toolbar">
        <label className="sr-only" htmlFor="transaction-search">Search description or category</label>
        <div className="search-input-wrap"><Search aria-hidden="true" size={17} /><input autoComplete="off" className="text-input" id="transaction-search" onChange={(event) => setSearch(event.target.value)} placeholder="Search description or category" value={search} /></div>
        <span className="muted-copy" aria-live="polite">{debouncedSearch ? `Search: ${debouncedSearch}` : `${transactions.data?.pages[0]?.total ?? 0} transactions`}</span>
      </div>
      <div className="summary-grid">
        <section className="feature-panel chart-panel">
          <div className="panel-heading"><h2>{monthLabel}</h2><span className="muted-copy">Category spend</span></div>
          {pieSlices.length === 0 ? (
            <p className="empty-state">No spending in this month.</p>
          ) : (
            <>
              <div className="donut-wrap">
                <svg className="donut-chart" viewBox="0 0 120 120" aria-label="Expense chart">
                  <circle className="donut-base" cx="60" cy="60" r="38" />
                  {(() => {
                    let offset = 0;
                    const circumference = 2 * Math.PI * 38;
                    return pieSlices.map((slice) => {
                      const dash = (slice.value / chartTotal) * circumference;
                      const circle = <circle key={slice.label} className="donut-segment" cx="60" cy="60" fill="none" r="38" stroke={slice.color} strokeDasharray={`${dash} ${circumference - dash}`} strokeDashoffset={-offset} strokeWidth="12" transform="rotate(-90 60 60)" />;
                      offset += dash;
                      return circle;
                    });
                  })()}
                </svg>
                <div className="donut-center"><strong>{formatPaise(monthSummary.expense)}</strong><span>Spent</span></div>
              </div>
              <ul className="legend-list">
                {pieSlices.map((slice) => (
                  <li key={slice.label}><button className="legend-key" type="button" style={{ background: slice.color }} aria-label={`Filter by ${slice.label}`} /> <span>{slice.label}</span><strong>{formatPaise(slice.value)}</strong></li>
                ))}
              </ul>
            </>
          )}
        </section>
        <section className="feature-panel chart-panel"><div className="panel-heading"><h2>Week summary</h2><span className="muted-copy">Current week</span></div><div className="week-bars">{[0, 1, 2, 3, 4, 5, 6].map((day) => <div className="week-bar" key={day} style={{ height: `${(day % 5) * 18 + 12}px` }} />)}</div></section>
      </div>
      {transactions.error ? (
        <section className="feature-panel" role="alert"><h2>Could not load transactions</h2><p>{transactions.error.message}</p><button className="button button-primary" onClick={() => void transactions.refetch()} type="button">Try again</button></section>
      ) : monthRows.length === 0 ? (
        <section className="feature-panel empty-state" aria-live="polite">{debouncedSearch ? "No transactions match this search." : "No transactions yet. Your history will appear here."}</section>
      ) : (
        <>
          {groupedRows.map(([date, rows]) => <section aria-label={dateHeading(date)} className="transaction-date-group" key={date}><h2>{dateHeading(date)}</h2><TransactionRows onDelete={setPendingRemoval} onEdit={startEditing} rows={rows} /></section>)}
          {transactions.hasNextPage && <div className="pagination-actions"><button className="button button-secondary" disabled={transactions.isFetchingNextPage} onClick={() => void transactions.fetchNextPage()} type="button">{transactions.isFetchingNextPage ? "Loading…" : "Load more"}</button></div>}
        </>
      )}
      {transactions.isFetching && !transactions.isFetchingNextPage && <p aria-live="polite" className="muted-copy">Refreshing transactions…</p>}
      {toast && (
        <div aria-live="polite" className={`toast-message${toast.error ? " toast-error" : ""}`} role="status">
          <span>{toast.message}</span>
          {toast.row && <button disabled={undo.isPending} onClick={() => void undoDeletion()} type="button">{undo.isPending ? "Restoring…" : "Undo"}</button>}
          <button aria-label="Dismiss notification" onClick={() => setToast(undefined)} type="button">Dismiss</button>
        </div>
      )}
      <Modal className="confirm-dialog" onClose={() => setPendingRemoval(undefined)} open={Boolean(pendingRemoval)} titleId="delete-transaction-title">
          <section className="modal-content">
            <h2 id="delete-transaction-title">Delete transaction?</h2>
            {pendingRemoval && <p className="delete-transaction-details"><strong>{pendingRemoval.description}</strong><span>{displayAmount(pendingRemoval.amount)} · {displayDate(pendingRemoval.date)}</span></p>}
            <p>This transaction will be deleted. You can undo this action from the notice for a short time.</p>
            <div className="wizard-actions">
              <button className="button button-secondary" onClick={() => setPendingRemoval(undefined)} type="button">Cancel</button>
              <button className="button button-danger" disabled={remove.isPending} onClick={() => void confirmDelete()} type="button">{remove.isPending ? "Deleting…" : "Delete"}</button>
            </div>
          </section>
      </Modal>
      {formOpen && user.data && (
        <TransactionForm
          key={editing?.transaction_id ?? "new"}
          onClose={() => {
            setFormOpen(false);
            setEditing(undefined);
            if (startOpen) router.replace("/transactions");
          }}
          onSaved={() => setToast({ message: editing ? "Transaction updated." : "Transaction saved." })}
          transaction={editing}
          userId={user.data}
        />
      )}
    </main>
  );
}
