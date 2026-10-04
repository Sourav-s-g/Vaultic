import { describe, expect, it } from "vitest";
import {
  DATA_COLORS,
  duplicateCategory,
  findSuggestedCategory,
  fnv1a,
  getCategoryColor,
  INITIAL_CATEGORIES,
  SUGGESTED_CATEGORIES,
} from "./data";

describe("category data and color mapping", () => {
  it("keeps the ten audited suggested colors and preselects the first five", () => {
    expect(SUGGESTED_CATEGORIES.map(({ color }) => color)).toEqual([
      "#FF9800", "#2196F3", "#9C27B0", "#4CAF50", "#E91E63",
      "#F44336", "#3F51B5", "#009688", "#00BCD4", "#795548",
    ]);
    expect(INITIAL_CATEGORIES.map(({ name }) => name)).toEqual([
      "Food", "Stationary", "Outings", "Travel", "Shopping",
    ]);
  });

  it("maps suggested categories case-insensitively", () => {
    expect(findSuggestedCategory("  fOoD ")?.color).toBe(DATA_COLORS.suggested.Food);
    expect(getCategoryColor("FOOD")).toBe(DATA_COLORS.suggested.Food);
  });

  it("uses stable FNV-1a values for normalized custom names", () => {
    expect(fnv1a("hello")).toBe(0x4f9f2cab);
    expect(getCategoryColor("  My Custom  ")).toBe(getCategoryColor("my custom"));
    expect(DATA_COLORS.dashboard).toContain(getCategoryColor("My Custom"));
  });

  it("detects trimmed case-insensitive duplicates", () => {
    expect(duplicateCategory([{ name: " Food " }], "food")).toBe(true);
    expect(duplicateCategory([{ name: "Food" }], "Food and Dining")).toBe(false);
  });
});
