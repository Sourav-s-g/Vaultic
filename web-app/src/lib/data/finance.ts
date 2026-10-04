import type { SupabaseClient } from "@supabase/supabase-js";
import { createCategoryDraft, duplicateCategory, normalizeCategoryName, type CategoryDraft } from "@/lib/categories/data";
import { serializeFlutterLocalDateTime } from "@/lib/dates";
import { databaseAmountToPaise, paiseToDatabaseAmount } from "@/lib/money";
import { createClient } from "@/lib/supabase/browser";
import type { Database } from "@/types/database.types";
import { CategoryAlreadyExistsError, throwIfCategoryUniqueViolation } from "./category-errors";
import { categoryDeleteRpcArgs } from "./category-rpc";

export { CategoryAlreadyExistsError } from "./category-errors";

export type CategoryRow = Database["public"]["Tables"]["categories"]["Row"];
export type TransactionRow = Database["public"]["Tables"]["transactions"]["Row"];
export type TransactionPage = { items: TransactionRow[]; total: number };
export const TRANSACTION_PAGE_SIZE = 20;

export class CategoryUnavailableError extends Error {
  constructor(name: string) {
    super(`The category "${name}" is no longer available. Choose another category.`);
    this.name = "CategoryUnavailableError";
  }
}

export class TransactionConflictError extends Error {
  constructor(readonly reason: "changed" | "deleted") {
    super(reason === "changed"
      ? "This transaction changed in another tab. Reload it before saving."
      : "This transaction was deleted in another tab.");
    this.name = "TransactionConflictError";
  }
}

function client(): SupabaseClient<Database> {
  return createClient();
}

export async function getAuthenticatedUserId(expectedUserId?: string): Promise<string> {
  const { data, error } = await client().auth.getUser();
  if (error || !data.user) {
    throw new Error("Your session has expired. Sign in again to continue.");
  }
  if (expectedUserId && expectedUserId !== data.user.id) {
    throw new Error("Your session changed. Refresh the page and try again.");
  }
  return data.user.id;
}

export async function getCurrentUserId(): Promise<string> {
  return getAuthenticatedUserId();
}

export async function getCategories(expectedUserId?: string): Promise<CategoryRow[]> {
  const userId = await getAuthenticatedUserId(expectedUserId);
  const { data, error } = await client()
    .from("categories")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: true });
  if (error) throw new Error(`Could not load categories: ${error.message}`);
  if (data === null) throw new Error("Could not load categories: the database returned no result.");
  return data;
}

async function assertCategoryDoesNotExist(userId: string, name: string): Promise<void> {
  const categories = await getCategories(userId);
  if (duplicateCategory(categories, name)) throw new CategoryAlreadyExistsError();
}

export async function addCategory(draft: CategoryDraft, expectedUserId: string): Promise<CategoryRow> {
  const userId = await getAuthenticatedUserId(expectedUserId);
  const normalized = createCategoryDraft(draft.name);
  await assertCategoryDoesNotExist(userId, normalized.name);

  const { data, error } = await client()
    .from("categories")
    .insert({ user_id: userId, name: normalized.name, color: normalized.color, icon: normalized.icon })
    .select("*")
    .single();
  if (!error && data) return data;
  if (error) throwIfCategoryUniqueViolation(error);

  try {
    await assertCategoryDoesNotExist(userId, normalized.name);
  } catch (recheckError) {
    if (recheckError instanceof CategoryAlreadyExistsError) throw recheckError;
    throw new Error(`Category insert failed (${error?.message ?? "no row returned"}) and duplicate recheck failed: ${String(recheckError)}`);
  }
  throw new Error(`Could not add category: ${error?.message ?? "the database returned no category row"}`);
}

export async function addCategories(
  drafts: readonly CategoryDraft[],
  expectedUserId: string,
): Promise<CategoryRow[]> {
  const userId = await getAuthenticatedUserId(expectedUserId);
  const normalizedNames = new Set<string>();
  for (const draft of drafts) {
    const normalized = normalizeCategoryName(createCategoryDraft(draft.name).name);
    if (normalizedNames.has(normalized)) throw new CategoryAlreadyExistsError();
    normalizedNames.add(normalized);
  }

  const existing = await getCategories(userId);
  const saved: CategoryRow[] = [];
  for (const draft of drafts) {
    const normalized = createCategoryDraft(draft.name);
    const alreadySaved = existing.find((category) =>
      normalizeCategoryName(category.name) === normalizeCategoryName(normalized.name));
    saved.push(alreadySaved ?? await addCategory(normalized, userId));
  }
  return saved;
}

export async function removeCategory(name: string, expectedUserId: string): Promise<void> {
  const userId = await getAuthenticatedUserId(expectedUserId);
  const categories = await getCategories(userId);
  const category = categories.find((item) => normalizeCategoryName(item.name) === normalizeCategoryName(name));
  const { error } = await client().rpc(
    "delete_category",
    categoryDeleteRpcArgs(category?.name ?? name.trim()),
  );
  if (error) throw new Error(`Could not remove category: ${error.message}`);
}

function escapeLikePattern(value: string): string {
  return value.replace(/[\\"]/g, "\\$&").replace(/[%_]/g, "\\$&");
}

async function queryTransactionPage(
  userId: string,
  offset: number,
  search?: string,
): Promise<TransactionPage> {
  const supabase = client();
  let query = supabase
    .from("transactions")
    .select("*", { count: "exact" })
    .eq("user_id", userId)
    .order("date", { ascending: false })
    .order("transaction_id", { ascending: false })
    .range(offset, offset + TRANSACTION_PAGE_SIZE - 1);

  if (search) {
    const pattern = `%${escapeLikePattern(search)}%`;
    query = query.or(`description.ilike."${pattern}",category.ilike."${pattern}"`);
  }

  const { data, error, count } = await query;
  if (error) throw new Error(`Could not load transactions: ${error.message}`);
  if (data === null) throw new Error("Could not load transactions: the database returned no rows result.");
  if (count === null) throw new Error("Could not load transactions: the database did not return a count.");
  return { items: data, total: count };
}

export async function getTransactionsPage(
  expectedUserId: string,
  offset: number,
  search?: string,
): Promise<TransactionPage> {
  const userId = await getAuthenticatedUserId(expectedUserId);
  return queryTransactionPage(userId, offset, search?.trim() || undefined);
}

export type NewTransaction = {
  transaction_id: string;
  description: string;
  amount: number;
  type: "Credit" | "Debit";
  date: string;
  category: string;
};

export type EditableTransaction = {
  transactionId: string;
  updatedAt: string | null;
  description: string;
  amountPaise: number;
  type: "Credit" | "Debit";
  date: string;
  category: string;
};

async function assertCategoryAvailable(userId: string, type: "Credit" | "Debit", category: string): Promise<void> {
  if (type === "Credit") return;
  const categories = await getCategories(userId);
  if (!categories.some((item) => normalizeCategoryName(item.name) === normalizeCategoryName(category))) {
    throw new CategoryUnavailableError(category);
  }
}

export async function createTransaction(
  input: NewTransaction,
  expectedUserId: string,
): Promise<TransactionRow> {
  const userId = await getAuthenticatedUserId(expectedUserId);
  await assertCategoryAvailable(userId, input.type, input.category);
  const row = {
    user_id: userId,
    transaction_id: input.transaction_id,
    description: input.description,
    amount: input.amount,
    type: input.type,
    date: serializeFlutterLocalDateTime(input.date),
    category: input.category || null,
    status: "Completed",
    is_split: false,
    split_count: 1,
  };

  const { data, error } = await client()
    .from("transactions")
    .upsert(row, { onConflict: "user_id,transaction_id", ignoreDuplicates: true })
    .select("*")
    .maybeSingle();
  if (error) throw new Error(`Could not save transaction: ${error.message}`);
  if (data) return data;

  const { data: existing, error: readError } = await client()
    .from("transactions")
    .select("*")
    .eq("user_id", userId)
    .eq("transaction_id", input.transaction_id)
    .maybeSingle();
  if (readError || !existing) {
    throw new Error(`Transaction insert was ignored but the existing row could not be confirmed: ${readError?.message ?? "row not found"}`);
  }
  return existing;
}

export async function updateTransaction(
  input: EditableTransaction,
  expectedUserId: string,
): Promise<TransactionRow> {
  const userId = await getAuthenticatedUserId(expectedUserId);
  await assertCategoryAvailable(userId, input.type, input.category);
  const changes = {
    description: input.description,
    amount: paiseToDatabaseAmount(input.amountPaise),
    type: input.type,
    date: serializeFlutterLocalDateTime(input.date),
    category: input.type === "Credit" ? null : input.category,
    updated_at: new Date().toISOString(),
  };
  let query = client()
    .from("transactions")
    .update(changes)
    .eq("user_id", userId)
    .eq("transaction_id", input.transactionId);
  query = input.updatedAt === null
    ? query.is("updated_at", null)
    : query.eq("updated_at", input.updatedAt);

  const { data, error } = await query.select("*").maybeSingle();
  if (error) throw new Error(`Could not update transaction: ${error.message}`);
  if (data) return data;

  const { data: current, error: readError } = await client()
    .from("transactions")
    .select("transaction_id")
    .eq("user_id", userId)
    .eq("transaction_id", input.transactionId)
    .maybeSingle();
  if (readError) throw new Error(`Could not check transaction after update conflict: ${readError.message}`);
  throw new TransactionConflictError(current ? "changed" : "deleted");
}

export async function deleteTransaction(
  transactionId: string,
  expectedUserId: string,
): Promise<TransactionRow> {
  const userId = await getAuthenticatedUserId(expectedUserId);
  const { data, error } = await client()
    .from("transactions")
    .delete()
    .eq("user_id", userId)
    .eq("transaction_id", transactionId)
    .select("*")
    .maybeSingle();
  if (error) throw new Error(`Could not delete transaction: ${error.message}`);
  if (!data) throw new TransactionConflictError("deleted");
  return data;
}

export async function restoreDeletedTransaction(
  row: TransactionRow,
  expectedUserId: string,
): Promise<TransactionRow> {
  const userId = await getAuthenticatedUserId(expectedUserId);
  const { data, error } = await client()
    .from("transactions")
    .upsert({
      user_id: userId,
      transaction_id: row.transaction_id,
      description: row.description,
      amount: row.amount,
      type: row.type,
      date: row.date,
      category: row.category,
      status: row.status,
      is_split: row.is_split,
      split_count: row.split_count,
      created_at: row.created_at,
      updated_at: row.updated_at,
    }, { onConflict: "user_id,transaction_id", ignoreDuplicates: true })
    .select("*")
    .maybeSingle();
  if (error) throw new Error(`Could not undo transaction deletion: ${error.message}`);
  if (!data) throw new Error("The transaction already exists and was not overwritten.");
  return data;
}

export function amountToPaise(row: TransactionRow): number {
  return databaseAmountToPaise(row.amount);
}
