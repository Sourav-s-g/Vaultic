export class CategoryAlreadyExistsError extends Error {
  constructor() {
    super("A category with this name already exists.");
    this.name = "CategoryAlreadyExistsError";
  }
}

export function throwIfCategoryUniqueViolation(error: { code?: string }): void {
  if (error.code === "23505") throw new CategoryAlreadyExistsError();
}
