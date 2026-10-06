import { expect, test } from "@playwright/test";

const mockUrl = "http://127.0.0.1:54321";
const userId = "b7b7c3b4-16aa-48d8-a0aa-6d98490c31ef";

function currentMonthDate(day = 1) {
  const now = new Date();
  const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(Math.min(day, lastDay)).padStart(2, "0")}`;
}

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
  await page.getByRole("button", { name: "Add custom" }).click();
  await page.getByLabel("Category name").fill("Pets");
  await page.getByRole("button", { name: "Add category" }).click();
  await expect(page.getByRole("dialog").getByRole("alert")).toHaveText("A category with this name already exists.");
  await expect(page.getByLabel("Category name")).toHaveValue("Pets");

  await page.getByRole("button", { name: "Add category" }).click();
  await expect(page.getByRole("status")).toContainText("Pets added.");

  await page.getByRole("button", { name: "Add custom" }).click();
  await page.getByLabel("Category name").fill(" pets ");
  await page.getByRole("button", { name: "Add category" }).click();
  await expect(page.locator(".inline-error")).toContainText("already exists");
  await page.getByRole("dialog").getByRole("button", { name: "Cancel" }).click();

  await page.getByRole("button", { name: "Remove category: fOoD" }).click();
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
    transactions: [{ transaction_id: "seed-1", description: "Old coffee ☕", amount: 50, type: "Debit", date: `${currentMonthDate(2)}T00:00:00.000`, category: "Food" }],
  });
  await page.goto("/transactions");
  const addTransaction = (page.viewportSize()?.width ?? 1280) < 1024
    ? page.locator(".mobile-add-button")
    : page.getByRole("button", { name: "Add transaction", exact: true });
  await addTransaction.click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page.getByLabel("Amount (₹)").fill("250.50");
  await page.getByLabel("Description", { exact: true }).fill("Coffee ☕");
  const createdDate = currentMonthDate(3);
  await page.getByLabel("Date").fill(createdDate);
  await page.getByLabel("Category", { exact: true }).selectOption("Food");
  await page.getByRole("button", { name: "Save transaction" }).click();
  await expect(page.locator(".transaction-row").getByText("Coffee ☕", { exact: true })).toBeVisible();
  await expect(page.getByRole("status")).toContainText("Transaction saved.");

  await page.getByPlaceholder("Search transactions...").fill("coffee");
  await expect(page.locator(".transaction-row").getByText("Old coffee ☕", { exact: true })).toBeVisible();
  await expect(page.locator(".transaction-row").getByText("Coffee ☕", { exact: true })).toBeVisible();
  await page.getByPlaceholder("Search transactions...").fill("nothing matches");
  await expect(page.getByText("No transactions match these filters.")).toBeVisible();
  await page.getByPlaceholder("Search transactions...").fill("");

  await page.getByRole("button", { name: "Edit transaction: Coffee ☕" }).click();
  await page.getByLabel("Amount (₹)").fill("1e3");
  await page.getByRole("button", { name: "Save changes" }).click();
  await expect(page.locator(".inline-error")).toContainText("greater than zero");
  await expect(page.getByLabel("Amount (₹)")).toHaveValue("1e3");
  await page.getByLabel("Amount (₹)").fill("300");
  await page.getByRole("button", { name: "Save changes" }).click();
  await expect(page.getByRole("status")).toContainText("Transaction updated.");

  await page.getByRole("button", { name: "Delete transaction: Coffee ☕" }).click();
  const dialog = page.getByRole("dialog");
  await expect(dialog).toContainText("300.00");
  await expect(dialog).toContainText(createdDate.split("-").reverse().join("/"));
  await dialog.getByRole("button", { name: "Delete", exact: true }).click();
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
      date: `${currentMonthDate((index % 28) + 1)}T00:00:00.000`,
      category: "Food",
    })),
  });
  await page.goto("/transactions");
  await expect(page.locator(".transaction-row")).toHaveCount(20);
  await page.getByPlaceholder("Search transactions...").fill("Transaction 0");
  await expect(page.locator(".transaction-row").getByText("Transaction 0", { exact: true })).toBeVisible();
  await page.getByPlaceholder("Search transactions...").fill("");
  await expect(page.locator(".transaction-row")).toHaveCount(20);
  await expect(page.getByRole("button", { name: "Load more" })).toBeVisible();
  await page.getByRole("button", { name: "Load more" }).click();
  await expect(page.getByText("Transaction 0", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "Load more" })).toHaveCount(0);
});

test("matches the responsive transaction layout and shared modal behavior", async ({ page, request }) => {
  await resetBackend(request, {
    categories: [
      { name: "Food", color: "#FF9800", icon: "utensils" },
      { name: "Transport", color: "#00BCD4", icon: "bus" },
      { name: "Bills", color: "#795548", icon: "receipt" },
      { name: "Pets", color: "#9E9E9E", icon: "tag" },
    ],
    transactions: [{ transaction_id: "layout-row", description: "Lunch", amount: 80, type: "Debit", date: `${currentMonthDate(1)}T00:00:00.000`, category: "Food" }],
  });
  await page.goto("/transactions");
  const deleteButton = page.getByRole("button", { name: "Delete transaction: Lunch" });
  await expect(deleteButton).toBeVisible();
  await expect(deleteButton).toHaveCSS("opacity", "1");
  await expect(page.getByText("Apply to fields", { exact: true })).toHaveCount(0);

  const layout = await page.evaluate(() => {
    return {
      width: window.innerWidth,
      height: window.innerHeight,
      scrollWidth: document.documentElement.scrollWidth,
      categoryCardCount: document.querySelectorAll(".category-card").length,
    };
  });
  expect(layout.scrollWidth).toBeLessThanOrEqual(layout.width);
  expect(layout.categoryCardCount).toBe(0);

  const trigger = page.getByRole("button", { name: "Add transaction", exact: true });
  const originalUrl = page.url();
  await trigger.focus();
  await page.keyboard.press("Enter");
  const dialog = page.getByRole("dialog");
  await expect(dialog).toBeVisible();
  const box = await dialog.boundingBox();
  expect(box).not.toBeNull();
  if (box) {
    expect(Math.abs(box.x + box.width / 2 - layout.width / 2)).toBeLessThanOrEqual(2);
    expect(box.y).toBeGreaterThanOrEqual(0);
    expect(box.y + box.height).toBeLessThanOrEqual(layout.height);
  }
  await expect(dialog.getByText("Apply to fields", { exact: true })).toHaveCount(0);
  await page.getByLabel("Quick entry").fill("250 lunch");
  await expect(page.getByLabel("Amount (₹)")).toHaveValue("250");
  await expect(page.getByLabel("Description", { exact: true })).toHaveValue("Lunch");
  await expect(page.getByText("Filled from your text")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(dialog).toBeHidden();
  expect(page.url()).toBe(originalUrl);
  await expect(trigger).toBeFocused();
});

test("keeps twelve category tiles compact", async ({ page, request }) => {
  await resetBackend(request, {
    categories: Array.from({ length: 12 }, (_, index) => ({
      name: `Category ${index + 1}`,
      color: "#9E9E9E",
      icon: "tag",
    })),
  });
  await page.goto("/categories");
  await expect(page.locator(".category-tile")).toHaveCount(12);
  const height = await page.locator(".category-panel").evaluate((element) => element.getBoundingClientRect().height);
  expect(height).toBeLessThan(600);
  const pageWidth = await page.evaluate(() => document.documentElement.scrollWidth);
  expect(pageWidth).toBeLessThanOrEqual(page.viewportSize()!.width);
});

test("uses the approved Dashboard title and history chart layout", async ({ page, request }) => {
  await resetBackend(request, {
    categories: [
      { name: "Food", color: "#FF9800", icon: "utensils" },
      { name: "Travel", color: "#4CAF50", icon: "car" },
    ],
    transactions: [
      { transaction_id: "food-a", description: "Lunch", amount: 114.6, type: "Debit", date: `${currentMonthDate(3)}T00:00:00.000`, category: "Food" },
      { transaction_id: "food-b", description: "Snack", amount: 5, type: "Debit", date: `${currentMonthDate(4)}T00:00:00.000`, category: "Food" },
      { transaction_id: "travel-a", description: "Bus", amount: 30, type: "Debit", date: `${currentMonthDate(5)}T00:00:00.000`, category: "Travel" },
      { transaction_id: "income-a", description: "Salary", amount: 150, type: "Credit", date: `${currentMonthDate(6)}T00:00:00.000`, category: null },
    ],
  });
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Dashboard", exact: true })).toBeVisible();
  await expect(page.getByText("Your personalised dashboard for your expenses", { exact: true })).toBeVisible();
  await expect(page).toHaveTitle("Dashboard · Vaultic");
  await expect(page.getByRole("region", { name: "Category totals" })).toBeVisible();

  await page.goto("/transactions");
  await expect(page.getByRole("heading", { name: "Transaction History" })).toBeVisible();
  await expect(page.locator(".category-card")).toHaveCount(0);
  await expect(page.locator(".donut-chart path")).toHaveCount(2);
  await expect(page.getByTestId("weekly-bar")).toHaveCount(7);
  await expect(page.getByRole("button", { name: "Filter by Food" })).toBeVisible();
  await expect(page.getByText("Monthly Income")).toBeVisible();
  await expect(page.getByText("Monthly Spent")).toBeVisible();
  await expect(page.getByText("Total Balance")).toBeVisible();
  const columns = await page.locator(".transactions-summary-panel .summary-block").evaluateAll((items) =>
    items.map((item) => ({ top: item.getBoundingClientRect().top, left: item.getBoundingClientRect().left })),
  );
  expect(columns).toHaveLength(3);
  expect(new Set(columns.map((item) => item.top)).size).toBe(1);
  const firstWeek = await page.locator("#weekly-chart-title").textContent();
  await page.getByRole("button", { name: "Previous week" }).click();
  await expect(page.locator("#weekly-chart-title")).not.toHaveText(firstWeek ?? "");

  const consoleWarnings: string[] = [];
  page.on("console", (message) => {
    if (/recharts|width\(-1\)|height\(-1\)/i.test(message.text())) consoleWarnings.push(message.text());
  });
  await expect(page.locator(".weekly-bar")).toHaveCount(7);
  expect(consoleWarnings).toEqual([]);
});

test("opens the global add dialog in place from supported routes and checks mobile sizing", async ({ page, request }) => {
  await resetBackend(request, {
    categories: [{ name: "Food", color: "#FF9800", icon: "utensils" }],
  });

  for (const route of ["/", "/transactions", "/categories", "/categories/Food"]) {
    await page.goto(route);
    const before = page.url();
    const add = page.getByRole("button", { name: "Add transaction", exact: true });
    await add.click();
    const dialog = page.getByRole("dialog");
    await expect(dialog).toBeVisible();
    expect(page.url()).toBe(before);

    const viewport = await page.evaluate(() => ({
      width: window.innerWidth,
      height: window.innerHeight,
      meta: document.querySelector('meta[name="viewport"]')?.getAttribute("content") ?? "",
      fontSizes: [...document.querySelectorAll("input, select, textarea")].map((element) => Number.parseFloat(getComputedStyle(element).fontSize)),
    }));
    if (viewport.width <= 1023) expect(viewport.fontSizes.every((size) => size >= 16)).toBe(true);
    expect(viewport.meta).not.toMatch(/maximum-scale|user-scalable\s*=\s*no/i);
    const box = await dialog.boundingBox();
    expect(box).not.toBeNull();
    if (box) {
      expect(Math.abs(box.x + box.width / 2 - viewport.width / 2)).toBeLessThanOrEqual(2);
      expect(box.y).toBeGreaterThanOrEqual(0);
      expect(box.y + box.height).toBeLessThanOrEqual(viewport.height);
    }
    await page.getByRole("button", { name: "Cancel", exact: true }).click();
    await expect(dialog).toBeHidden();
    expect(page.url()).toBe(before);

    await add.click();
    await page.keyboard.press("Escape");
    await expect(dialog).toBeHidden();
    expect(page.url()).toBe(before);
  }
});

test("back arrows always return to Dashboard", async ({ page, request }) => {
  await resetBackend(request, {
    categories: [{ name: "Food", color: "#FF9800", icon: "utensils" }],
  });
  for (const route of ["/transactions", "/categories", "/categories/Food"]) {
    await page.goto(route);
    const back = page.getByRole("link", { name: "Back to Dashboard" });
    await expect(back).toBeVisible();
    const box = await back.boundingBox();
    expect(box?.width).toBeGreaterThanOrEqual(44);
    expect(box?.height).toBeGreaterThanOrEqual(44);
    expect(box?.x).toBeGreaterThanOrEqual(0);
    await back.click();
    await expect(page).toHaveURL(/\/$/);
  }
});
