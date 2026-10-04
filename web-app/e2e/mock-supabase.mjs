import { createServer } from "node:http";
import { randomUUID } from "node:crypto";

const userId = "b7b7c3b4-16aa-48d8-a0aa-6d98490c31ef";
let categories = [];
let budgets = [];
let transactions = [];

function send(response, status, body, extraHeaders = {}) {
  response.writeHead(status, {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "apikey, authorization, content-type, prefer, range, accept, x-client-info, x-supabase-api-version",
    "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, HEAD, OPTIONS",
    "Access-Control-Expose-Headers": "content-range, preference-applied",
    "Content-Type": "application/json",
    ...extraHeaders,
  });
  response.end(body === undefined ? "" : JSON.stringify(body));
}

function representRows(request, rows) {
  return String(request.headers.accept ?? "").includes("application/vnd.pgrst.object+json")
    ? rows[0] ?? null
    : rows;
}

function matchesFilter(rows, params, field) {
  const filter = params.get(field);
  if (!filter?.startsWith("eq.")) return rows;
  const value = filter.slice(3);
  return rows.filter((row) => String(row[field] ?? "") === value);
}

function filteredRows(table, params) {
  let rows = table === "categories" ? categories : table === "budgets" ? budgets : transactions;
  rows = matchesFilter(rows, params, "user_id");
  for (const field of ["id", "name", "category", "transaction_id", "updated_at"]) {
    rows = matchesFilter(rows, params, field);
  }
  const search = params.get("or");
  if (search) {
    const match = /%((?:\\.|[^%])*)%/.exec(search);
    const term = match?.[1]?.replace(/\\([\\%_"])/g, "$1").toLocaleLowerCase();
    if (term) {
      rows = rows.filter((row) =>
        `${row.description ?? ""} ${row.category ?? ""}`.toLocaleLowerCase().includes(term));
    }
  }
  return rows;
}

function tableFor(name) {
  if (name === "categories") return categories;
  if (name === "budgets") return budgets;
  if (name === "transactions") return transactions;
  return undefined;
}

function sortAndPage(rows, request, response) {
  const count = rows.length;
  const order = new URL(request.url, "http://localhost").searchParams.get("order") ?? "";
  for (const orderPart of order.split(",").reverse()) {
    const [field, direction] = orderPart.split(".");
    if (!field) continue;
    rows.sort((left, right) => {
      const result = String(left[field] ?? "").localeCompare(String(right[field] ?? ""));
      return direction === "desc" ? -result : result;
    });
  }
  const params = new URL(request.url, "http://localhost").searchParams;
  const offsetParam = params.get("offset");
  const limitParam = params.get("limit");
  const offset = offsetParam === null ? 0 : Number(offsetParam);
  const limit = limitParam === null ? 0 : Number(limitParam);
  const range = request.headers.range;
  if (offsetParam !== null && limitParam !== null &&
      Number.isInteger(offset) && offset >= 0 && Number.isInteger(limit) && limit >= 0) {
    rows = rows.slice(offset, offset + limit);
    response.setHeader("Content-Range", `${offset}-${Math.max(offset + rows.length - 1, offset)}/${count}`);
  } else if (range) {
    const [start, end] = range.split("-").map(Number);
    rows = rows.slice(start, end + 1);
    response.setHeader("Content-Range", `${start}-${Math.max(start + rows.length - 1, start)}/${count}`);
  } else {
    response.setHeader("Content-Range", `0-${Math.max(count - 1, 0)}/${count}`);
  }
  return rows;
}

function seedRow(table, input) {
  const now = new Date().toISOString();
  if (table === "categories") {
    return { id: randomUUID(), user_id: userId, color: "#FF9800", icon: "tag", created_at: now, updated_at: now, ...input };
  }
  if (table === "budgets") {
    return { id: randomUUID(), user_id: userId, amount: 0, created_at: now, updated_at: now, ...input };
  }
  return {
    id: randomUUID(), user_id: userId, category: "Food", status: "Completed", is_split: false,
    split_count: 1, created_at: now, updated_at: now, ...input,
  };
}

const server = createServer(async (request, response) => {
  const url = new URL(request.url ?? "/", "http://127.0.0.1:54321");
  if (request.method === "OPTIONS") {
    return send(response, 204, undefined, {
      "Access-Control-Allow-Headers": request.headers["access-control-request-headers"] ?? "apikey, authorization, content-type",
    });
  }
  if (url.pathname === "/__test/health") return send(response, 200, { status: "ok" });
  if (url.pathname === "/__test/reset" && request.method === "POST") {
    const body = await readBody(request);
    categories = (body.categories ?? []).map((row) => seedRow("categories", row));
    budgets = (body.budgets ?? []).map((row) => seedRow("budgets", row));
    transactions = (body.transactions ?? []).map((row) => seedRow("transactions", row));
    return send(response, 200, { status: "reset" });
  }
  if (url.pathname === "/__test/state") {
    return send(response, 200, { categories, budgets, transactions });
  }
  if (url.pathname === "/auth/v1/user") {
    if (request.headers.authorization !== "Bearer mock-access-token") {
      return send(response, 401, { message: "Invalid token", code: 401 });
    }
    return send(response, 200, {
      id: userId, aud: "authenticated", role: "authenticated",
      email: "phase3@example.test", app_metadata: { provider: "email", providers: ["email"] },
      user_metadata: {}, created_at: new Date(0).toISOString(),
    });
  }
  if (url.pathname.startsWith("/rest/v1/")) {
    const tableName = url.pathname.slice("/rest/v1/".length);
    const table = tableFor(tableName);
    if (!table) return send(response, 404, { message: "Unknown table" });

    if (request.method === "GET" || request.method === "HEAD") {
      const rows = sortAndPage(filteredRows(tableName, url.searchParams), request, response);
      return send(response, 200, request.method === "HEAD" ? undefined : representRows(request, rows));
    }

    const body = await readBody(request);
    const inputs = Array.isArray(body) ? body : [body];
    const prefer = String(request.headers.prefer ?? "");
    if (request.method === "POST") {
      const inserted = [];
      for (const input of inputs) {
        if (tableName === "transactions") {
          const existing = transactions.find((row) => row.user_id === input.user_id && row.transaction_id === input.transaction_id);
          if (existing && prefer.includes("resolution=ignore-duplicates")) continue;
          if (existing) return send(response, 409, { code: "23505", message: "duplicate key" });
        }
        if (tableName === "categories" && categories.some((row) =>
          row.user_id === input.user_id && row.name.toLocaleLowerCase() === input.name.toLocaleLowerCase())) {
          return send(response, 409, { code: "23505", message: "duplicate category" });
        }
        const row = seedRow(tableName, input);
        table.push(row);
        inserted.push(row);
      }
      return send(response, 201, prefer.includes("return=representation") ? representRows(request, inserted) : undefined, { "Content-Range": `*/${inserted.length}` });
    }

    const matched = filteredRows(tableName, url.searchParams);
    if (request.method === "PATCH") {
      for (const row of matched) Object.assign(row, body);
      return send(response, 200, prefer.includes("return=representation") ? representRows(request, matched) : undefined);
    }
    if (request.method === "DELETE") {
      const rows = matched.slice();
      const set = new Set(rows);
      const remaining = table.filter((row) => !set.has(row));
      if (tableName === "categories") categories = remaining;
      else if (tableName === "budgets") budgets = remaining;
      else transactions = remaining;
      return send(response, 200, prefer.includes("return=representation") ? representRows(request, rows) : undefined);
    }
  }
  return send(response, 404, { message: "Not found" });
});

function readBody(request) {
  return new Promise((resolve, reject) => {
    let body = "";
    request.setEncoding("utf8");
    request.on("data", (chunk) => { body += chunk; });
    request.on("end", () => {
      try { resolve(body ? JSON.parse(body) : {}); } catch (error) { reject(error); }
    });
    request.on("error", reject);
  });
}

server.listen(54321, "127.0.0.1");
