import { describe, expect, it } from "vitest";
import { categoryInputSchema, transactionInputSchema } from "./schemas";

describe("input schemas", () => {
  it("trims category names and rejects empty names", () => {
    expect(categoryInputSchema.parse({ name: " Food ", color: "#FF9800", icon: "utensils" }).name).toBe("Food");
    expect(categoryInputSchema.safeParse({ name: "   ", color: "#FF9800", icon: "tag" }).success).toBe(false);
  });

  it("requires a valid positive transaction amount, date and type", () => {
    expect(transactionInputSchema.safeParse({
      amount: "12.50", description: "", date: "2024-02-29", type: "Debit", category: "Food",
    }).success).toBe(true);
    expect(transactionInputSchema.safeParse({
      amount: "0", description: "", date: "2019-12-31", type: "Transfer", category: "",
    }).success).toBe(false);
  });
});
