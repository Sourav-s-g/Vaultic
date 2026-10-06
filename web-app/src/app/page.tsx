"use client";

import { useEffect, useMemo } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { CategoryCardStrip, DashboardTabs } from "@/components/finance-ui";
import { RecentTransactions } from "@/components/transaction-list";
import { useCategories, useCurrentUserId, useTransactions } from "@/lib/data/hooks";
import { getCurrentMonthKey } from "@/lib/finance-summary";
import type { TransactionRow } from "@/lib/data/finance";
import { databaseAmountToPaise } from "@/lib/money";
import { DATA_COLORS, normalizeCategoryName } from "@/lib/categories/data";

function isTransactionDebit(row: TransactionRow): boolean {
  return row.type === "Debit" && !row.transaction_id.toLowerCase().startsWith("carry-forward-") && !row.description.toLowerCase().startsWith("balance carried forward");
}

export default function Home() {
  const router = useRouter();
  const user = useCurrentUserId();
  const categories = useCategories(user.data);
  const transactions = useTransactions(user.data);
  const monthKey = getCurrentMonthKey();

  useEffect(() => {
    if (categories.data && categories.data.length === 0) router.replace("/setup");
  }, [categories.data, router]);

  const rows = useMemo(() => transactions.data?.pages.flatMap((page) => page.items) ?? [], [transactions.data]);
  const categoryMap = useMemo(() => new Map((categories.data ?? []).map((category) => [normalizeCategoryName(category.name), category])), [categories.data]);

  const categoryTotals = useMemo(() => {
    const totals = new Map<string, number>();
    for (const row of rows) {
      if (!isTransactionDebit(row)) continue;
      if (row.date.slice(0, 7) !== monthKey) continue;
      const key = normalizeCategoryName(row.category?.trim() || "Other");
      totals.set(key, (totals.get(key) ?? 0) + databaseAmountToPaise(Number(row.amount)));
    }
    return totals;
  }, [monthKey, rows]);

  const monthSpent = Array.from(categoryTotals.values()).reduce((sum, value) => sum + value, 0);
  const stripCategories = (categories.data ?? []).map((category) => ({
    name: category.name,
    amountPaise: categoryTotals.get(normalizeCategoryName(category.name)) ?? 0,
    href: `/categories/${encodeURIComponent(category.name)}`,
  }));

  const unmatchedSpent = rows.filter((row) => isTransactionDebit(row) && row.date.slice(0, 7) === monthKey && !categoryMap.has(normalizeCategoryName(row.category?.trim() || "Other"))).reduce((sum, row) => sum + databaseAmountToPaise(Number(row.amount)), 0);
  const cardItems = [...stripCategories, ...(unmatchedSpent > 0 ? [{ name: "Other", amountPaise: unmatchedSpent, href: "/categories/all-debit", color: DATA_COLORS.custom }] : [])];

  if (user.isLoading || categories.isLoading || transactions.isLoading) {
    return <main className="workspace-page" aria-busy="true"><div className="skeleton skeleton-title" /><div className="skeleton skeleton-panel" /></main>;
  }
  if (user.error || categories.error || transactions.error) {
    return (
      <main className="workspace-page">
        <section className="feature-panel" role="alert">
          <h1>Could not load your workspace</h1>
          <p>{(user.error ?? categories.error ?? transactions.error)?.message}</p>
          <button className="button button-primary" onClick={() => { void user.refetch(); void categories.refetch(); void transactions.refetch(); }} type="button">Try again</button>
        </section>
      </main>
    );
  }
  if (categories.data?.length === 0) return <main className="workspace-page" aria-live="polite"><div className="skeleton skeleton-panel" /><p>Opening setup…</p></main>;

  return (
    <main className="workspace-page">
      <CategoryCardStrip categories={cardItems} monthSpentPaise={monthSpent} />
      <DashboardTabs />
      <RecentTransactions />
      <div className="panel-heading home-view-all"><h2>Latest activity</h2><Link className="text-button" href="/transactions">View all</Link></div>
    </main>
  );
}
