import { z } from "zod";
import { isTransactionDateAllowed } from "./dates";
import { parseAmountToPaise } from "./money";

export const categoryInputSchema = z.object({
  name: z.string().trim().min(1, "Enter a category name.").max(120, "Category names must be 120 characters or fewer."),
  color: z.string().regex(/^#[\da-f]{6}$/i),
  icon: z.string().trim().min(1),
});

export const transactionInputSchema = z.object({
  amount: z.string().refine((value) => {
    try {
      parseAmountToPaise(value);
      return true;
    } catch {
      return false;
    }
  }, "Enter an amount greater than zero with at most two decimal places."),
  description: z.string().max(100_000, "Description is too long."),
  date: z.string().refine((value) => isTransactionDateAllowed(value), "Choose a date from 2020 through one year from today."),
  type: z.enum(["Credit", "Debit"]),
  category: z.string().max(120),
}).superRefine((value, context) => {
  if (value.type === "Debit" && !value.category.trim()) {
    context.addIssue({ code: "custom", message: "Choose a category for this debit.", path: ["category"] });
  }
});

export type CategoryInput = z.infer<typeof categoryInputSchema>;
export type TransactionInput = z.infer<typeof transactionInputSchema>;
