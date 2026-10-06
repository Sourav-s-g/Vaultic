import { normalizeCategoryName } from "@/lib/categories/data";
import { databaseAmountToPaise } from "@/lib/money";
import type { TransactionRow } from "@/lib/data/finance";

export function isCarryForwardTransaction(row: Pick<TransactionRow, "transaction_id" | "description">): boolean {
  const transactionId = (row.transaction_id ?? "").trim();
  const description = (row.description ?? "").trim();
  return transactionId.toLowerCase().startsWith("carry-forward-") || description.toLowerCase().startsWith("balance carried forward");
}

export function getMonthKey(dateValue: string): string {
  const [year, month] = dateValue.slice(0, 10).split("-").map(Number);
  return `${year}-${String(month).padStart(2, "0")}`;
}

export function getCurrentMonthKey(now = new Date()): string {
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
}

export function monthLabel(dateValue: string): string {
  const [year, month] = dateValue.slice(0, 10).split("-").map(Number);
  const safeDate = new Date(Date.UTC(year, month - 1, 1, 12));
  return new Intl.DateTimeFormat("en-IN", { month: "short", year: "numeric" }).format(safeDate);
}

export function sumMonthlyExpenses(rows: readonly TransactionRow[], monthKey?: string): number {
  return rows.reduce((total, row) => {
    if (!row || row.type !== "Debit" || !isRealTransaction(row)) return total;
    const entryMonth = getMonthKey(row.date);
    if (monthKey && entryMonth !== monthKey) return total;
    return total + databaseAmountToPaise(Number(row.amount));
  }, 0);
}

export function sumMonthlyIncome(rows: readonly TransactionRow[], monthKey?: string): number {
  return rows.reduce((total, row) => {
    if (!row || row.type !== "Credit" || !isRealTransaction(row)) return total;
    const entryMonth = getMonthKey(row.date);
    if (monthKey && entryMonth !== monthKey) return total;
    return total + databaseAmountToPaise(Number(row.amount));
  }, 0);
}

export function getMonthlySummary(rows: readonly TransactionRow[], monthKey?: string) {
  const expensePaise = sumMonthlyExpenses(rows, monthKey);
  const incomePaise = sumMonthlyIncome(rows, monthKey);
  return {
    incomePaise,
    expensePaise,
    netPaise: incomePaise - expensePaise,
    balancePaise: incomePaise - expensePaise,
  };
}

export function isRealTransaction(row: Pick<TransactionRow, "transaction_id" | "description">): boolean {
  return !isCarryForwardTransaction(row);
}

export function summarizeCategorySpend(rows: readonly TransactionRow[], monthKey?: string) {
  const totals = new Map<string, { name: string; amountPaise: number }>();

  for (const row of rows) {
    if (!row || row.type !== "Debit" || !isRealTransaction(row)) continue;
    if (monthKey && getMonthKey(row.date) !== monthKey) continue;
    const name = (row.category ?? "Other").trim() || "Other";
    const key = normalizeCategoryName(name) || "other";
    const current = totals.get(key) ?? { name, amountPaise: 0 };
    totals.set(key, {
      name: current.name,
      amountPaise: current.amountPaise + databaseAmountToPaise(Number(row.amount)),
    });
  }

  return [...totals.entries()]
    .map(([, value]) => value)
    .sort((left, right) => right.amountPaise - left.amountPaise);
}

export function findUnmatchedCategorySpending(rows: readonly TransactionRow[], knownCategories: readonly { name: string }[], monthKey?: string) {
  const categoryNames = new Set(knownCategories.map((category) => normalizeCategoryName(category.name)));
  const spend = summarizeCategorySpend(rows, monthKey).filter((entry) => !categoryNames.has(normalizeCategoryName(entry.name) || "other"));
  return spend;
}
