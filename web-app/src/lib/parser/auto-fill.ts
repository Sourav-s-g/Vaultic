import type { ParsedTransaction } from "@/lib/parser";

export type SmartFields = {
  amount: string;
  description: string;
  date: string;
  type: "Credit" | "Debit";
  category: string;
};

export type SmartFieldName = keyof SmartFields;
export type SmartFieldSet = ReadonlySet<SmartFieldName>;

export function clearAutoFilledFields(
  fields: SmartFields,
  touched: SmartFieldSet,
  autoFilled: SmartFieldSet,
  today: string,
): { fields: SmartFields; autoFilled: Set<SmartFieldName> } {
  const next = { ...fields };
  const remaining = new Set(autoFilled);
  for (const field of autoFilled) {
    if (touched.has(field)) {
      remaining.delete(field);
      continue;
    }
    if (field === "date") next.date = today;
    else if (field === "type") next.type = "Debit";
    else next[field] = "";
    remaining.delete(field);
  }
  return { fields: next, autoFilled: remaining };
}

export function applyParsedFields(
  fields: SmartFields,
  touched: SmartFieldSet,
  previousAutoFilled: SmartFieldSet,
  parsed: ParsedTransaction,
  categories: readonly string[],
  today: string,
): { fields: SmartFields; autoFilled: Set<SmartFieldName> } {
  const cleared = clearAutoFilledFields(fields, touched, previousAutoFilled, today);
  const next = { ...cleared.fields };
  const autoFilled = cleared.autoFilled;
  const set = <K extends SmartFieldName>(field: K, value: SmartFields[K]) => {
    if (touched.has(field)) return;
    next[field] = value;
    autoFilled.add(field);
  };

  if (parsed.amount !== null) set("amount", parsed.amount);
  if (parsed.description !== "Transaction") set("description", parsed.description);
  if (parsed.type === "Credit") {
    set("type", "Credit");
    if (!touched.has("category")) {
      next.category = "";
      autoFilled.add("category");
    }
  } else {
    set("type", "Debit");
    const category = categories.find((name) => name.toLocaleLowerCase("en") === parsed.category?.toLocaleLowerCase("en"));
    if (category) set("category", category);
  }
  if (parsed.date && parsed.date !== today) set("date", parsed.date);
  return { fields: next, autoFilled };
}
