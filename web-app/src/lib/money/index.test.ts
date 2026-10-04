import { describe, expect, it } from "vitest";
import {
  databaseAmountToPaise,
  formatPaise,
  MAX_PAISA,
  parseAmountToPaise,
  paiseToDatabaseAmount,
} from "./index";

describe("money conversion", () => {
  it.each([
    ["1", 100],
    ["0.01", 1],
    ["123456.78", 12_345_678],
  ])("parses %s as integer paise", (input, expected) => {
    expect(parseAmountToPaise(input)).toBe(expected);
  });

  it.each(["0", "0.00", "-1", "NaN", "Infinity", "1e3", "1.001", "1,000", ""])(
    "rejects invalid user amount %s",
    (input) => expect(() => parseAmountToPaise(input)).toThrow(),
  );

  it("rejects unsafe integer-paise amounts", () => {
    expect(() => parseAmountToPaise("1000000000001")).toThrow("too large");
  });

  it("round-trips numeric DB values at paise precision", () => {
    for (const paise of [1, 100, 12_345_678, MAX_PAISA]) {
      expect(databaseAmountToPaise(paiseToDatabaseAmount(paise))).toBe(paise);
    }
  });

  it("formats Indian grouping and exactly two paise digits", () => {
    expect(formatPaise(12_345_600)).toBe("₹1,23,456.00");
    expect(formatPaise(1)).toBe("₹0.01");
    expect(databaseAmountToPaise(0)).toBe(0);
    expect(formatPaise(databaseAmountToPaise(-12.34))).toContain("12.34");
  });
});
