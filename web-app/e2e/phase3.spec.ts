import { expect, test } from "@playwright/test";

const mockUrl = "http://127.0.0.1:54321";
const userId = "b7b7c3b4-16aa-48d8-a0aa-6d98490c31ef";

async function setSession(page: import("@playwright/test").Page) {
  const now = Math.floor(Date.now() / 1000);
  const session = {
    access_token: "mock-access-token",
    refresh_token: "mock-refresh-token",
    token_type: "bearer",
    expires_in: 3600,
    expires_at: now + 3600,
    user: { id: userId, aud: "authenticated", role: "authenticated", email: "phase3@example.test" },
  };
  await page.context().addCookies([{
    name: "sb-127-auth-token",
    value: `base64-${Buffer.from(JSON.stringify(session)).toString("base64url")}`,
    domain: "127.0.0.1",
    path: "/",
    expires: now + 3600,
    httpOnly: false,
    secure: false,
    sameSite: "Lax",
  }]);
}

async function resetBackend(
  request: import("@playwright/test").APIRequestContext,
  data: {
    categories?: object[];
    budgets?: object[];
    transactions?: object[];
    categoryInsertError?: boolean;
  } = {},
) {
  await request.post(`${mockUrl}/__test/reset`, { data });
}

test.beforeEach(async ({ page, request }) => {
  await resetBackend(request);
  await setSession(page);
});

test("protects workspace routes and requires a category during onboarding", async ({ browser, page }) => {
  const anonymousContext = await browser.newContext({ baseURL: "http://127.0.0.1:3100" });
  const anonymousPage = await anonymousContext.newPage();
  await anonymousPage.goto("/transactions");
  await expect(anonymousPage).toHaveURL(/\/login\?next=%2Ftransactions/);
  await anonymousContext.close();
  await page.goto("/");
  await expect(page).toHaveURL(/\/setup/);
  await page.getByRole("button", { name: "Next", exact: true }).click();
  await expect(page.getByText("Step 2 of 3")).toBeVisible();
  for (const name of ["Food", "Stationary", "Outings", "Travel", "Shopping"]) {
    await page.getByRole("button", { name: new RegExp(name) }).click();
  }
  await page.getByRole("button", { name: "Next", exact: true }).click();
  await expect(page.getByText("No categories selected yet.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Finish setup" })).toBeDisabled();
});

test("adds and removes categories without rewriting transaction history", async ({ page, request }) => {
  await resetBackend(request, {
    categoryInsertError: true,
    categories: [{ name: "fOoD", color: "#FF9800", icon: "utensils" }],
    budgets: [{ category: "fOoD" }],
    transactions: [{ transaction_id: "history-1", description: "Lunch", amount: 120, type: "Debit", date: "2024-01-31T00:00:00.000", category: "Food" }],
  });
  await page.goto("/categories");
  await page.getByLabel("Category name").fill("Pets");
  await page.getByRole("button", { name: "Add category" }).click();
  await expect(page.locator(".inline-error")).toHaveText("A category with this name already exists.");
  await expect(page.getByLabel("Category name")).toHaveValue("Pets");

  await page.getByRole("button", { name: "Add category" }).click();
  await expect(page.getByRole("status")).toContainText("Pets added.");

  await page.getByLabel("Category name").fill(" pets ");
  await page.getByRole("button", { name: "Add category" }).click();
  await expect(page.locator(".inline-error")).toContainText("already exists");

  await page.getByRole("button", { name: "Remove fOoD" }).click();
  const dialog = page.getByRole("dialog");
  await expect(dialog).toContainText("Transactions keep their existing category text");
  await dialog.getByRole("button", { name: "Remove category" }).click();
  await expect(page.getByRole("status")).toContainText("fOoD removed.");
  const state = await (await request.get(`${mockUrl}/__test/state`)).json();
  expect(state.categories.map((row: { name: string }) => row.name)).toEqual(["Pets"]);
  expect(state.budgets).toHaveLength(0);
  expect(state.transactions).toHaveLength(1);
  expect(state.transactions[0].category).toBe("Food");
  expect(state.lastRpcCall).toEqual({ function: "delete_category", args: { p_category_name: "fOoD" } });
});

test("creates, edits, searches and deletes transactions with an undo path", async ({ page, request }) => {
  await resetBackend(request, {
    categories: [{ name: "Food", color: "#FF9800", icon: "utensils" }],
    transactions: [{ transaction_id: "seed-1", description: "Old coffee ☕", amount: 50, type: "Debit", date: "2024-01-30T00:00:00.000", category: "Food" }],
  });
  await page.goto("/transactions");
  const addTransaction = (page.viewportSize()?.width ?? 1280) < 1024
    ? page.locator(".mobile-add-button")
    : page.getByRole("button", { name: "Add transaction", exact: true });
  await addTransaction.click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page.getByLabel("Amount (₹)").fill("250.50");
  await page.getByLabel("Description", { exact: true }).fill("Coffee ☕");
  await page.getByLabel("Date").fill("2024-01-31");
  await page.getByLabel("Category", { exact: true }).selectOption("Food");
  await page.getByRole("button", { name: "Save transaction" }).click();
  await expect(page.locator(".transaction-row").getByText("Coffee ☕", { exact: true })).toBeVisible();
  await expect(page.getByRole("status")).toContainText("Transaction saved.");

  await page.getByLabel("Search description or category").fill("coffee");
  await expect(page.locator(".transaction-row").getByText("Old coffee ☕", { exact: true })).toBeVisible();
  await expect(page.locator(".transaction-row").getByText("Coffee ☕", { exact: true })).toBeVisible();
  await page.getByLabel("Search description or category").fill("nothing matches");
  await expect(page.getByText("Search: nothing matches")).toBeVisible();
  await expect(page.getByText("No transactions match this search.")).toBeVisible();
  await page.getByLabel("Search description or category").fill("");

  await page.getByRole("button", { name: "Edit Coffee ☕" }).click();
  await page.getByLabel("Amount (₹)").fill("1e3");
  await page.getByRole("button", { name: "Save changes" }).click();
  await expect(page.locator(".inline-error")).toContainText("greater than zero");
  await expect(page.getByLabel("Amount (₹)")).toHaveValue("1e3");
  await page.getByLabel("Amount (₹)").fill("300");
  await page.getByRole("button", { name: "Save changes" }).click();
  await expect(page.getByRole("status")).toContainText("Transaction updated.");

  await page.getByRole("button", { name: "Delete Coffee ☕" }).click();
  const dialog = page.getByRole("dialog");
  await dialog.getByRole("button", { name: "Delete transaction" }).click();
  await expect(page.getByRole("status")).toContainText("Transaction deleted.");
  await page.getByRole("button", { name: "Undo" }).click();
  await expect(page.getByRole("status")).toContainText("Transaction restored.");
  const state = await (await request.get(`${mockUrl}/__test/state`)).json();
  expect(state.transactions).toHaveLength(2);
  expect(state.transactions.find((row: { description: string }) => row.description === "Coffee ☕").amount).toBe(300);
});

test("uses server pagination for transaction history", async ({ page, request }) => {
  await resetBackend(request, {
    categories: [{ name: "Food", color: "#FF9800", icon: "utensils" }],
    transactions: Array.from({ length: 25 }, (_, index) => ({
      transaction_id: `page-${index}`,
      description: `Transaction ${index}`,
      amount: index + 1,
      type: "Debit",
      date: `2024-01-${String((index % 28) + 1).padStart(2, "0")}T00:00:00.000`,
      category: "Food",
    })),
  });
  await page.goto("/transactions");
  await expect(page.getByText("25 transactions")).toBeVisible();
  await expect(page.locator(".transaction-row")).toHaveCount(20);
  await page.getByLabel("Search description or category").fill("Transaction 0");
  await expect(page.locator(".transaction-row").getByText("Transaction 0", { exact: true })).toBeVisible();
  await page.getByLabel("Search description or category").fill("");
  await expect(page.locator(".transaction-row")).toHaveCount(20);
  await expect(page.getByRole("button", { name: "Load more" })).toBeVisible();
  await page.getByRole("button", { name: "Load more" }).click();
  await expect(page.getByText("Transaction 0", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "Load more" })).toHaveCount(0);
});
