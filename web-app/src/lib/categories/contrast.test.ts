import { describe, expect, it } from "vitest";
import { cardForeground, contrastRatio } from "./contrast";

describe("category card contrast", () => {
  it("uses dark text for light amber and white text for dark purple", () => {
    expect(cardForeground("#FF9800")).toBe("#000000");
    expect(cardForeground("#9C27B0")).toBe("#FFFFFF");
  });

  it("selects a foreground with WCAG AA contrast", () => {
    for (const color of ["#FF9800", "#2196F3", "#9C27B0", "#FFC107", "#795548"]) {
      expect(contrastRatio(color, cardForeground(color))).toBeGreaterThanOrEqual(4.5);
    }
  });
});
