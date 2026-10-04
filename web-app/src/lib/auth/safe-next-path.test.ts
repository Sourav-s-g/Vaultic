import { describe, expect, it } from "vitest";
import { safeNextPath } from "./safe-next-path";

describe("safeNextPath", () => {
  it("preserves a same-origin relative path and its query", () => {
    expect(safeNextPath("/transactions?period=month#recent")).toBe("/transactions?period=month#recent");
  });

  it.each([
    "https://attacker.example/path",
    "//attacker.example/path",
    "///attacker.example/path",
    "/\\attacker.example/path",
    "/%5c%5cattacker.example/path",
    "relative/path",
    "javascript:alert(1)",
    "/path%zz",
  ])("rejects unsafe destination %s", (candidate) => {
    expect(safeNextPath(candidate)).toBeNull();
  });

  it("rejects empty values and control characters", () => {
    expect(safeNextPath(null)).toBeNull();
    expect(safeNextPath("/safe\n/location")).toBeNull();
  });
});
