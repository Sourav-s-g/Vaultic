import { describe, expect, it } from "vitest";
import { applyParsedFields, clearAutoFilledFields, type SmartFields } from "./auto-fill";
import type { ParsedTransaction } from "@/lib/parser";

const base: SmartFields = { amount: "", description: "", date: "2026-04-10", type: "Debit", category: "" };
const parsed = (overrides: Partial<ParsedTransaction> = {}): ParsedTransaction => ({
  amount: "250",
  description: "lunch",
  date: "2026-04-10",
  type: "Debit",
  category: "Food",
  confidence: 0.9,
  suggestions: [],
  rawInput: "250 lunch",
  ...overrides,
});

describe("smart input auto-fill", () => {
  it("does not overwrite manually touched fields", () => {
    const result = applyParsedFields({ ...base, amount: "80" }, new Set(["amount"]), new Set(), parsed(), ["Food"], "2026-04-10");
    expect(result.fields.amount).toBe("80");
    expect(result.fields.description).toBe("lunch");
  });

  it("does not set an amount when none is detected", () => {
    const result = applyParsedFields(base, new Set(), new Set(), parsed({ amount: null }), ["Food"], "2026-04-10");
    expect(result.fields.amount).toBe("");
  });

  it("does not overwrite an existing date when the text contains no detected date", () => {
    const fields = { ...base, date: "2024-01-31" };
    const result = applyParsedFields(fields, new Set(), new Set(), parsed(), ["Food"], "2026-04-10");
    expect(result.fields.date).toBe("2024-01-31");
  });

  it("clearing text clears only untouched auto-filled fields", () => {
    const prior = applyParsedFields(base, new Set(), new Set(), parsed(), ["Food"], "2026-04-10");
    const edited = { ...prior.fields, amount: "300" };
    const cleared = clearAutoFilledFields(edited, new Set(["amount"]), prior.autoFilled, "2026-04-10");
    expect(cleared.fields.amount).toBe("300");
    expect(cleared.fields.description).toBe("");
    expect(cleared.fields.category).toBe("");
  });

  it("clears category when Credit is detected", () => {
    const result = applyParsedFields(
      { ...base, category: "Food" },
      new Set(),
      new Set(),
      parsed({ type: "Credit", category: null }),
      ["Food"],
      "2026-04-10",
    );
    expect(result.fields.type).toBe("Credit");
    expect(result.fields.category).toBe("");
  });
});
