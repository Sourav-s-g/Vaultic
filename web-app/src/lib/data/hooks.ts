"use client";

import {
  InfiniteData,
  useInfiniteQuery,
  useMutation,
  useQuery,
  useQueryClient,
  type QueryClient,
} from "@tanstack/react-query";
import {
  addCategories,
  addCategory,
  createTransaction,
  deleteTransaction,
  getAuthenticatedUserId,
  getCategories,
  getCurrentUserId,
  getTransactionsPage,
  removeCategory,
  restoreDeletedTransaction,
  updateTransaction,
  type CategoryRow,
  type NewTransaction,
  type TransactionPage,
  type TransactionRow,
  type EditableTransaction,
  TRANSACTION_PAGE_SIZE,
} from "./finance";
import type { CategoryDraft } from "@/lib/categories/data";
import { paiseToDatabaseAmount } from "@/lib/money";

export const financeKeys = {
  auth: ["auth", "current-user"] as const,
  categories: {
    all: ["categories"] as const,
    list: (userId: string) => ["categories", userId] as const,
  },
  transactions: {
    all: ["transactions"] as const,
    list: (userId: string) => ["transactions", userId, "list"] as const,
  },
  transactionsSearch: {
    all: ["transactions-search"] as const,
    list: (userId: string, term: string) => ["transactions-search", userId, term] as const,
  },
  balance: {
    all: ["balance"] as const,
    user: (userId: string) => ["balance", userId] as const,
  },
  summaries: {
    all: ["summaries"] as const,
    user: (userId: string) => ["summaries", userId] as const,
  },
};

type CachedTransactionPages = InfiniteData<TransactionPage, number>;
type CacheSnapshot = Array<[readonly unknown[], unknown]>;

export function useCurrentUserId() {
  return useQuery({
    queryKey: financeKeys.auth,
    queryFn: getCurrentUserId,
    staleTime: 30_000,
    retry: false,
  });
}

export function useCategories(userId: string | undefined) {
  return useQuery({
    queryKey: userId ? financeKeys.categories.list(userId) : financeKeys.categories.all,
    queryFn: () => getCategories(userId),
    enabled: Boolean(userId),
  });
}

function invalidateFinance(client: QueryClient, userId?: string) {
  return Promise.all([
    client.invalidateQueries({ queryKey: financeKeys.categories.all }),
    client.invalidateQueries({ queryKey: financeKeys.transactions.all }),
    client.invalidateQueries({ queryKey: financeKeys.transactionsSearch.all }),
    client.invalidateQueries({ queryKey: userId ? financeKeys.balance.user(userId) : financeKeys.balance.all }),
    client.invalidateQueries({ queryKey: userId ? financeKeys.summaries.user(userId) : financeKeys.summaries.all }),
  ]);
}

function snapshots(client: QueryClient): CacheSnapshot {
  return [
    ...client.getQueriesData({ queryKey: financeKeys.transactions.all }),
    ...client.getQueriesData({ queryKey: financeKeys.transactionsSearch.all }),
  ];
}

function restoreSnapshots(client: QueryClient, saved: CacheSnapshot) {
  for (const [key, value] of saved) client.setQueryData(key, value);
}

function updatePages(
  value: unknown,
  updater: (pages: CachedTransactionPages) => CachedTransactionPages,
): unknown {
  if (!value || typeof value !== "object" || !("pages" in value)) return value;
  return updater(value as CachedTransactionPages);
}

function updateTransactionCaches(
  client: QueryClient,
  row: TransactionRow,
  mode: "insert" | "replace" | "remove",
) {
  const allQueries = [
    ...client.getQueriesData({ queryKey: financeKeys.transactions.all }),
    ...client.getQueriesData({ queryKey: financeKeys.transactionsSearch.all }),
  ];
  for (const [key, value] of allQueries) {
    client.setQueryData(key, updatePages(value, (pages) => {
      const first = pages.pages[0];
      if (!first) return pages;
      if (mode === "insert") {
        if (first.items.some((item) => item.transaction_id === row.transaction_id)) return pages;
        const matchesSearch = !key.includes("transactions-search") ||
          String(key[2] ?? "").trim() === "" ||
          `${row.description} ${row.category ?? ""}`.toLocaleLowerCase().includes(String(key[2]).toLocaleLowerCase());
        if (!matchesSearch) return pages;
        const items = [...first.items, row].sort((left, right) => right.date.localeCompare(left.date));
        return { ...pages, pages: [{ ...first, items: items.slice(0, TRANSACTION_PAGE_SIZE), total: first.total + 1 }, ...pages.pages.slice(1)] };
      }
      const exists = pages.pages.some((page) => page.items.some((item) => item.transaction_id === row.transaction_id));
      return {
        ...pages,
        pages: pages.pages.map((page) => ({
          ...page,
          items: mode === "remove"
            ? page.items.filter((item) => item.transaction_id !== row.transaction_id)
            : page.items.map((item) => item.transaction_id === row.transaction_id ? row : item),
          total: mode === "remove" && exists ? Math.max(0, page.total - 1) : page.total,
        })),
      };
    }));
  }
}

function optimisticRow(input: NewTransaction, userId: string): TransactionRow {
  const now = new Date().toISOString();
  return {
    id: `optimistic-${input.transaction_id}`,
    user_id: userId,
    transaction_id: input.transaction_id,
    description: input.description,
    amount: input.amount,
    type: input.type,
    date: input.date,
    category: input.category || null,
    status: "Completed",
    is_split: false,
    split_count: 1,
    created_at: now,
    updated_at: now,
  };
}

export function useAddCategory(userId: string | undefined) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (draft: CategoryDraft) => {
      if (!userId) throw new Error("Sign in to manage categories.");
      return addCategory(draft, userId);
    },
    onMutate: async (draft) => {
      if (!userId) return;
      const key = financeKeys.categories.list(userId);
      await client.cancelQueries({ queryKey: key });
      const previous = client.getQueryData<CategoryRow[]>(key);
      const now = new Date().toISOString();
      const optimistic: CategoryRow = {
        id: `optimistic-${crypto.randomUUID()}`,
        user_id: userId,
        name: draft.name.trim(),
        color: draft.color,
        icon: draft.icon,
        created_at: now,
        updated_at: now,
      };
      client.setQueryData<CategoryRow[]>(key, (current = []) => [...current, optimistic]);
      return { key, previous };
    },
    onError: (_error, _draft, context) => {
      if (context) client.setQueryData(context.key, context.previous);
    },
    onSuccess: (row) => {
      if (userId) client.setQueryData<CategoryRow[]>(financeKeys.categories.list(userId), (current = []) =>
        [...current.filter((category) => !category.id.startsWith("optimistic-")), row]);
    },
    onSettled: () => invalidateFinance(client, userId),
  });
}

export function useSaveSetupCategories(userId: string | undefined) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (drafts: readonly CategoryDraft[]) => {
      if (!userId) throw new Error("Sign in to set up categories.");
      return addCategories(drafts, userId);
    },
    onMutate: async (drafts) => {
      if (!userId) return;
      const key = financeKeys.categories.list(userId);
      await client.cancelQueries({ queryKey: key });
      const previous = client.getQueryData<CategoryRow[]>(key);
      const now = new Date().toISOString();
      client.setQueryData<CategoryRow[]>(key, drafts.map((draft, index) => ({
        id: `optimistic-${index}`,
        user_id: userId,
        name: draft.name,
        color: draft.color,
        icon: draft.icon,
        created_at: now,
        updated_at: now,
      })));
      return { key, previous };
    },
    onError: (_error, _drafts, context) => {
      if (context) client.setQueryData(context.key, context.previous);
    },
    onSuccess: (rows) => {
      if (userId) client.setQueryData(financeKeys.categories.list(userId), rows);
    },
    onSettled: () => invalidateFinance(client, userId),
  });
}

export function useRemoveCategory(userId: string | undefined) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (name: string) => {
      if (!userId) throw new Error("Sign in to remove categories.");
      return removeCategory(name, userId);
    },
    onMutate: async () => {
      if (!userId) return;
      const key = financeKeys.categories.list(userId);
      await client.cancelQueries({ queryKey: key });
    },
    onSettled: () => invalidateFinance(client, userId),
  });
}

export function useTransactions(userId: string | undefined, search = "") {
  const normalizedSearch = search.trim();
  const key = userId
    ? normalizedSearch
      ? financeKeys.transactionsSearch.list(userId, normalizedSearch)
      : financeKeys.transactions.list(userId)
    : normalizedSearch
      ? financeKeys.transactionsSearch.all
      : financeKeys.transactions.all;
  return useInfiniteQuery({
    queryKey: key,
    queryFn: ({ pageParam }) => {
      if (!userId) throw new Error("Sign in to view transactions.");
      return getTransactionsPage(userId, pageParam, normalizedSearch || undefined);
    },
    enabled: Boolean(userId),
    initialPageParam: 0,
    getNextPageParam: (lastPage, _pages, lastOffset) =>
      lastOffset + lastPage.items.length < lastPage.total ? lastOffset + TRANSACTION_PAGE_SIZE : undefined,
  });
}

export function useCreateTransaction(userId: string | undefined) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: NewTransaction) => {
      if (!userId) throw new Error("Sign in to add a transaction.");
      return createTransaction(input, userId);
    },
    onMutate: async (input) => {
      if (!userId) return;
      await Promise.all([
        client.cancelQueries({ queryKey: financeKeys.transactions.all }),
        client.cancelQueries({ queryKey: financeKeys.transactionsSearch.all }),
      ]);
      const previous = snapshots(client);
      updateTransactionCaches(client, optimisticRow(input, userId), "insert");
      return { previous };
    },
    onError: (_error, _input, context) => {
      if (context) restoreSnapshots(client, context.previous);
    },
    onSuccess: (row) => updateTransactionCaches(client, row, "replace"),
    onSettled: () => invalidateFinance(client, userId),
  });
}

export function useUpdateTransaction(userId: string | undefined) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (input: EditableTransaction) => {
      if (!userId) throw new Error("Sign in to edit a transaction.");
      return updateTransaction(input, userId);
    },
    onMutate: async (input) => {
      if (!userId) return;
      await Promise.all([
        client.cancelQueries({ queryKey: financeKeys.transactions.all }),
        client.cancelQueries({ queryKey: financeKeys.transactionsSearch.all }),
      ]);
      const previous = snapshots(client);
      const old = previous.flatMap(([, value]) =>
        value && typeof value === "object" && "pages" in value
          ? (value as CachedTransactionPages).pages.flatMap((page) => page.items)
          : [],
      ).find((row) => row.transaction_id === input.transactionId);
      if (old) {
        updateTransactionCaches(client, {
          ...old,
          description: input.description,
          amount: paiseToDatabaseAmount(input.amountPaise),
          type: input.type,
          date: input.date,
          category: input.type === "Credit" ? null : input.category,
        }, "replace");
      }
      return { previous };
    },
    onError: (_error, _input, context) => {
      if (context) restoreSnapshots(client, context.previous);
    },
    onSuccess: (row) => updateTransactionCaches(client, row, "replace"),
    onSettled: () => invalidateFinance(client, userId),
  });
}

export function useDeleteTransaction(userId: string | undefined) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (transactionId: string) => {
      if (!userId) throw new Error("Sign in to delete a transaction.");
      return deleteTransaction(transactionId, userId);
    },
    onMutate: async (transactionId) => {
      if (!userId) return;
      await Promise.all([
        client.cancelQueries({ queryKey: financeKeys.transactions.all }),
        client.cancelQueries({ queryKey: financeKeys.transactionsSearch.all }),
      ]);
      const previous = snapshots(client);
      const row = previous.flatMap(([, value]) =>
        value && typeof value === "object" && "pages" in value
          ? (value as CachedTransactionPages).pages.flatMap((page) => page.items)
          : [],
      ).find((item) => item.transaction_id === transactionId);
      if (row) updateTransactionCaches(client, row, "remove");
      return { previous, row };
    },
    onError: (_error, _transactionId, context) => {
      if (context) restoreSnapshots(client, context.previous);
    },
    onSuccess: (row) => updateTransactionCaches(client, row, "remove"),
    onSettled: () => invalidateFinance(client, userId),
  });
}

export function useUndoDeleteTransaction(userId: string | undefined) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (row: TransactionRow) => {
      if (!userId) throw new Error("Sign in to undo this deletion.");
      return restoreDeletedTransaction(row, userId);
    },
    onMutate: async (row) => {
      if (!userId) return;
      await Promise.all([
        client.cancelQueries({ queryKey: financeKeys.transactions.all }),
        client.cancelQueries({ queryKey: financeKeys.transactionsSearch.all }),
      ]);
      const previous = snapshots(client);
      updateTransactionCaches(client, row, "insert");
      return { previous };
    },
    onError: (_error, _row, context) => {
      if (context) restoreSnapshots(client, context.previous);
    },
    onSuccess: (row) => updateTransactionCaches(client, row, "replace"),
    onSettled: () => invalidateFinance(client, userId),
  });
}

export async function refreshCurrentUserId(): Promise<string> {
  return getAuthenticatedUserId();
}
