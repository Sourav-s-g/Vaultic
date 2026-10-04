import { describe, expect, it } from "vitest";
import { getCategorySuggestions, parseTransactionInput } from "./index";

describe("SmartInputParser port", () => {
  it("parses currency, decimals, category, credit/debit and confidence", () => {
    expect(parseTransactionInput("Paid lunch ₹250.50 Food", ["Food"], "2024-05-06")).toMatchObject({
      amount: "250.50",
      category: "Food",
      type: "Debit",
      description: "Lunch Food",
      date: "2024-05-06",
      confidence: 1,
    });
    expect(parseTransactionInput("Got €500 salary", ["Income"], "2024-05-06")).toMatchObject({
      amount: "500",
      type: "Credit",
      category: "Income",
      date: "2024-05-06",
    });
  });

  it("defaults to Debit and the provided current calendar date", () => {
    expect(parseTransactionInput("lunch", ["Food"], "2024-05-06")).toMatchObject({
      type: "Debit",
      date: "2024-05-06",
      category: "Food",
    });
  });

  it("uses the last numeric match for the amount", () => {
    expect(parseTransactionInput("Paid 12 for lunch 250", ["Food"]).amount).toBe("250");
  });

  it("returns up to five direct and keyword suggestions", () => {
    expect(getCategorySuggestions("fo", ["Food", "Food extras", "Foyer", "Funds", "Fossils", "Foreign"])).toHaveLength(5);
    expect(getCategorySuggestions("", ["Food"])).toEqual([]);
  });

  it("returns an empty parse for blank input", () => {
    expect(parseTransactionInput("  ", [], "2024-05-06")).toMatchObject({
      amount: null,
      description: "",
      confidence: 0,
      date: "2024-05-06",
    });
  });
});
