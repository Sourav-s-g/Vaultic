import { describe, expect, it } from "vitest";
import { formatCardAmount } from "./card";

describe("category card money display", () => {
  it("uses en-IN grouping and omits only whole-rupee decimals", () => {
    expect(formatCardAmount(12_345_600)).toBe("₹1,23,456");
    expect(formatCardAmount(12_345_678)).toBe("₹1,23,456.78");
  });

  it("shows a dash when totals are not part of this phase", () => {
    expect(formatCardAmount(null)).toBe("—");
  });
});
