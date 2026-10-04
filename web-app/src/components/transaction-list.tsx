"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Pencil, Plus, Search, Trash2 } from "lucide-react";
import { formatPaise, databaseAmountToPaise } from "@/lib/money";
import { transactionDateInputValue, parseDateInput } from "@/lib/dates";
import { useCurrentUserId, useDeleteTransaction, useTransactions, useUndoDeleteTransaction } from "@/lib/data/hooks";
import type { TransactionRow } from "@/lib/data/finance";
import { TransactionForm } from "@/components/transaction-form";

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

export function TransactionRows({
  rows,
  onEdit,
  onDelete,
}: {
  rows: TransactionRow[];
  onEdit?: (row: TransactionRow) => void;
  onDelete?: (row: TransactionRow) => void;
}) {
  return (
    <div className="transaction-group">
      {rows.map((row) => {
        const category = row.category?.trim();
        return (
          <article className="transaction-row" key={row.transaction_id}>
            <div className="transaction-description">
              <strong>{row.description}</strong>
              <span className="transaction-subtitle">{row.type === "Debit" ? category || "Uncategorized" : "Income"}{row.status ? ` · ${row.status}` : ""}</span>
            </div>
            <span className="transaction-amount">{row.type === "Credit" ? "+" : "−"}{displayAmount(row.amount)}</span>
            {(onEdit || onDelete) && (
              <div className="transaction-actions">
                {onEdit && <button aria-label={`Edit ${row.description}`} className="icon-button" onClick={() => onEdit(row)} type="button"><Pencil aria-hidden="true" size={17} /></button>}
                {onDelete && <button aria-label={`Delete ${row.description}`} className="icon-button" onClick={() => onDelete(row)} type="button"><Trash2 aria-hidden="true" size={17} /></button>}
              </div>
            )}
          </article>
        );
      })}
    </div>
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
        ? <p className="empty-state">No transactions yet. Add one to start your history.</p>
        : <TransactionRows rows={latestFive.slice(0, 4)} />}
    </section>
  );
}

export function TransactionsPage({ startOpen = false }: { startOpen?: boolean }) {
  const router = useRouter();
  const user = useCurrentUserId();
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [formOpen, setFormOpen] = useState(startOpen);
  const [editing, setEditing] = useState<TransactionRow>();
  const [pendingRemoval, setPendingRemoval] = useState<TransactionRow>();
  const [toast, setToast] = useState<{ message: string; row?: TransactionRow; error?: boolean }>();
  const transactions = useTransactions(user.data, debouncedSearch);
  const remove = useDeleteTransaction(user.data);
  const undo = useUndoDeleteTransaction(user.data);

  useEffect(() => {
    const timer = window.setTimeout(() => setDebouncedSearch(search.trim()), 300);
    return () => window.clearTimeout(timer);
  }, [search]);

  const allRows = useMemo(() => transactions.data?.pages.flatMap((page) => page.items) ?? [], [transactions.data]);
  const groupedRows = useMemo(() => {
    const groups = new Map<string, TransactionRow[]>();
    for (const row of allRows) {
      const date = transactionDateInputValue(row.date);
      groups.set(date, [...(groups.get(date) ?? []), row]);
    }
    return [...groups.entries()].sort(([left], [right]) => right.localeCompare(left));
  }, [allRows]);

  function startEditing(row: TransactionRow) {
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
      <div className="transactions-toolbar">
        <label className="sr-only" htmlFor="transaction-search">Search description or category</label>
        <div className="search-input-wrap"><Search aria-hidden="true" size={17} /><input autoComplete="off" className="text-input" id="transaction-search" onChange={(event) => setSearch(event.target.value)} placeholder="Search description or category" value={search} /></div>
        <span className="muted-copy" aria-live="polite">{debouncedSearch ? `Search: ${debouncedSearch}` : `${transactions.data?.pages[0]?.total ?? 0} transactions`}</span>
      </div>
      {transactions.error ? (
        <section className="feature-panel" role="alert"><h2>Could not load transactions</h2><p>{transactions.error.message}</p><button className="button button-primary" onClick={() => void transactions.refetch()} type="button">Try again</button></section>
      ) : allRows.length === 0 ? (
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
      {pendingRemoval && (
        <div aria-labelledby="delete-transaction-title" aria-modal="true" className="confirm-backdrop" role="dialog">
          <section className="confirm-dialog">
            <h2 id="delete-transaction-title">Delete transaction?</h2>
            <p>“{pendingRemoval.description}” will be deleted. This cannot be undone after the undo notice expires.</p>
            <div className="wizard-actions">
              <button className="button button-secondary" onClick={() => setPendingRemoval(undefined)} type="button">Cancel</button>
              <button className="button button-primary" disabled={remove.isPending} onClick={() => void confirmDelete()} type="button">{remove.isPending ? "Deleting…" : "Delete transaction"}</button>
            </div>
          </section>
        </div>
      )}
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
