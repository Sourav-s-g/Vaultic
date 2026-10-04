import { describe, expect, it } from "vitest";
import { CategoryAlreadyExistsError, throwIfCategoryUniqueViolation } from "./category-errors";

describe("category insert errors", () => {
  it("reports unique violations as an existing category", () => {
    expect(() => throwIfCategoryUniqueViolation({ code: "23505" })).toThrowError(
      new CategoryAlreadyExistsError(),
    );
  });

  it("leaves other database errors to normal error handling", () => {
    expect(() => throwIfCategoryUniqueViolation({ code: "42501" })).not.toThrow();
  });
});
