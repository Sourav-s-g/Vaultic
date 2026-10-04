# Phase 3 Implementation Verification

## 1. Verdict

**READY WITH FIXES — Phase 3 screens, data access, shared finance rules, and automated tests are implemented; category-plus-budget deletion is only compensating, not atomic, so its all-or-nothing behavior must be fixed before relying on it for production. Phase 4 was not started.**

## 2. Final command results

Commands were run from `web-app/`. Dependencies were already present.

| Check | Result | Actual output |
|---|---|---|
| `npm run lint` | **PASS** | `> web-app@0.1.0 lint` / `> eslint`; exit code 0, no warnings or errors. |
| `npm run typecheck` | **PASS** | `> web-app@0.1.0 typecheck` / `> tsc --noEmit`; exit code 0, no diagnostics. |
| `npm test` | **PASS** | `Test Files 6 passed (6)`; `Tests 42 passed (42)`; duration `611ms`. |
| `npm run test:e2e` | **PASS** | `Running 8 tests using 1 worker`; all four scenarios passed in `[desktop]` and `[mobile-360]`; `8 passed (20.7s)`. |
| `npm run build` | **PASS** | Next.js `16.3.8`; `Compiled successfully in 1645ms`; TypeScript and static generation completed; routes include `/`, `/categories`, `/setup`, `/transactions`, and `ƒ Proxy (Middleware)`. |

One initial attempt was made from the repository root and failed before running a check because the root has no `package.json` (`ENOENT: ... '/Users/souravs/Projects/Vaultic/package.json'`). The commands above are the successful reruns from `web-app/`.

The first post-edit typecheck found a duplicate `categoryRows` declaration and an undefined `selectedCategory`; ESLint also reported the now-unused category state. I corrected the state binding/declaration, and the final lint/typecheck runs above are clean.

Playwright uses the local Supabase-compatible mock in `e2e/mock-supabase.mjs`. **None of these eight browser tests needs a real Supabase account.** Live Auth, deployed Vercel cookies, email confirmation/recovery, production RLS, and remote schema behavior still need a real test project/account before release.

## 3. Implementation status: Steps 1–5

| Step | Status | Evidence |
|---|---|---|
| **1. Schema facts, dates, and SQL proposals** | **DONE** | The current [`schema-snapshot.md`](./supabase/schema-snapshot.md) contains columns, constraints, RLS status and policies for all seven tables. It confirms RLS and `auth.uid() = user_id` policies, `(user_id, transaction_id)` uniqueness for transactions, no case-insensitive category uniqueness, numeric transaction amounts, `timestamptz` dates, and nullable transaction `updated_at`. The offsetless Flutter local `toIso8601String()` convention is recorded in [`PARITY.md`](./PARITY.md) and implemented by `serializeFlutterLocalDateTime` in `web-app/src/lib/dates/index.ts`. The case-insensitive category index and transactions `updated_at` trigger are proposed only in `supabase/migrations/20261004193000_categories_case_insensitive_unique.sql` and `supabase/migrations/20261004193001_transactions_updated_at_trigger.sql`; neither was applied. `OPEN-ITEMS.md` records that Phase 6 trip keys must be UUIDs. |
| **2. Housekeeping and types/tokens** | **DONE** | Snapshot references in `.github/copilot-instructions.md` and `docs/` use `docs/supabase/schema-snapshot.md`. `web-app/src/types/database.types.ts` models the seven snapshot table shapes. Its function surface intentionally omits the snapshot's Flutter-only `delete_user_account()` RPC; this scope choice is recorded in `docs/OPEN-ITEMS.md`. The focus/status tokens in `web-app/src/app/globals.css` are neutral; CSS hex values are centralized in theme tokens, while category/chart literals are in the typed `DATA_COLORS` constant in `web-app/src/lib/categories/data.ts`. |
| **3. Shared foundations and unit tests** | **DONE** | Integer-paise parsing/DB conversion/INR formatting: `src/lib/money/index.ts`; date validation and offsetless serialization: `src/lib/dates/index.ts`; suggested/custom colors and FNV-1a: `src/lib/categories/data.ts`; parser port: `src/lib/parser/index.ts`; category and transaction Zod validation: `src/lib/schemas.ts`. Tests are in the corresponding `*.test.ts` files and `src/lib/schemas.test.ts`. |
| **4. Data layer and TanStack Query** | **DONE** | Supabase finance access is centralized in `src/lib/data/finance.ts`; `getAuthenticatedUserId` obtains the session identity, and each category/budget/transaction request scopes by that ID. `src/lib/data/hooks.ts` defines per-feature category, transaction, search, balance, and summary keys; mutations use optimistic cache updates with rollback where safe and invalidate finance keys. Category removal waits for the remote mutation rather than removing optimistically. |
| **5. Phase 3 features** | **PARTIAL** | `/setup`, `/categories`, and `/transactions` are implemented by their route pages and `CategorySetup`, `CategoriesPage`, `TransactionForm`, and `TransactionsPage` components. `src/proxy.ts:proxy` protects routes, gates users with no categories, and validates `next`. Transactions use 20-row server pagination, server-side debounced search, conflict-checked edits, confirmation/undo deletion, and the exported `RecentTransactions`. E2E coverage passes at desktop and 360px. The category and budget delete requests are separate; compensation is attempted if the budget request fails, but this is not a database transaction and cannot guarantee rollback if the compensating category insert also fails. See defect 1 below. |

## 4. Feature and edge-case evidence

### Routes and behavior

- **Setup:** `CategorySetup` implements intro, category selection, and review steps with previous/next navigation. Suggested categories and the first-five selection come from `INITIAL_CATEGORIES`; category names are trimmed and checked case-insensitively, custom categories can be added/removed, and finish is disabled for an empty selection. `useSaveSetupCategories` persists name, color, and icon. Post-auth and direct-root category routing are handled in `src/proxy.ts:proxy`.
- **Categories:** `CategoriesPage` lists and adds categories, supports suggested/custom additions and duplicate feedback, and confirms that deleting a category and its budget leaves transaction category text unchanged. `removeCategory` scopes both deletes by authenticated `user_id`; it does not issue any transaction mutation. UI removal follows remote completion; errors are shown and category restoration is attempted if budget deletion fails.
- **Transaction form:** `TransactionForm` provides a dialog at desktop widths and a full-height mobile sheet, parser preview, editable amount/description/date/type/category, category refresh when the category disappears, and a double-submit guard. Credit clears category. Blank descriptions become `Manual Entry`; creates use a UUID, `Completed`, `is_split: false`, and `split_count: 1`. Input remains in the mounted form after save errors. The shared schema/money/date functions reject invalid or non-positive amounts, more than two decimals, exponent notation, invalid dates, and out-of-range dates.
- **Transaction history:** `TransactionsPage` groups newest-first records by their calendar date, pages in groups of 20 from Supabase, debounces search by 300 ms, and searches descriptions/categories server-side. Edit errors are surfaced; an `updated_at` mismatch distinguishes changed/deleted records and invalidates cached transactions. Delete confirmation and undo are present, as are loading, empty, error/retry, and success/undo states. `RecentTransactions` renders at most four from the latest five loaded rows.
- **Not built (intentionally):** charts, summaries, balances, carry-forward, budgets UI, PDF, and trips.

### Requested edge cases

| Edge case | Code behavior | Test coverage |
|---|---|---|
| Double-tap save | `pending` state plus a synchronous `submitting` ref blocks repeat submission. | CRUD E2E exercises saves, but no dedicated rapid-double-click assertion. |
| Category deleted in another tab while form is open | Rechecks the category before write; refetches and retains form values on `CategoryUnavailableError`. | Not specifically race-tested. |
| Transaction deleted/changed in another tab while editing | Update filters by the originally loaded `updated_at`; zero rows triggers a changed/deleted conflict and cache invalidation. | Not specifically race-tested. |
| Very long descriptions | Text wraps in transaction rows; no app-side description truncation is applied. | No dedicated long-description test. |
| `en-IN` INR (`₹1,23,456.00`) | `formatPaise` uses `Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" })`. | Unit-tested. |
| Month end, Feb 29, midnight, and range bounds | Calendar-field parsing, leap-day clamping, minimum `2020-01-01`, and max one calendar year ahead. | Unit-tested. |
| Asia/Kolkata 00:30 and 23:30; timezone day/month shifts | Tests convert corresponding UTC instants to the requested Asia/Kolkata calendar date. Date-only values are handled as calendar fields, not parsed as UTC date-only strings; offsetless serialized timestamps retain the selected wall date. | Unit-tested for 00:30/23:30, month end, and date-only parsing. Cross-device/live Supabase round trips remain unverified. |
| Emoji and Unicode | Stored/rendered as ordinary text; no ASCII-only normalization or truncation in the transaction path. | No dedicated emoji/Unicode E2E assertion. |
| Network failure during save | Mutation cache rolls back; the form stays open and displays the error without clearing the entered fields. | No dedicated failure-injection E2E assertion. |
| Session expiry mid-action | Every data operation rechecks `auth.getUser()` and returns a sign-in/session-expired error. | No real-session-expiry browser test. |
| 360px layout with keyboard open | 360px mobile project covers route/CRUD interactions, bottom sheet and responsive shell. | Browser viewport tested; a real iOS/Android virtual keyboard and safe-area behavior are not simulated. |

## 5. Defects and limits, ordered by severity

1. **Medium — category + budget removal is not atomic.** `web-app/src/lib/data/finance.ts:116-156` deletes the category and budget in separate PostgREST requests. A failed budget deletion triggers a category restore attempt, and both failures are surfaced, but if the restore also fails the operation leaves the category deleted. The smallest reliable fix is a transactional server-side operation, which requires an explicitly approved/applied database function or equivalent; the current snapshot has no category-removal RPC. This limitation is documented in `docs/OPEN-ITEMS.md`.
2. **Release verification outstanding — no live Supabase/Vercel/device run.** Automated E2E is mocked and cannot prove production Auth configuration, live RLS, email flows, Vercel cookie behavior, remote migration state, or physical keyboard/safe-area behavior. Verify with a dedicated test account and device/browser matrix before release.
3. **Category uniqueness remains raceable until proposal activation.** `addCategory` prechecks and rechecks case-insensitive duplicates, but the database has no corresponding unique index yet. Concurrent inserts can race until the proposed migration is approved and applied.

No other failing lint, typecheck, unit, E2E, or build issue remained after final validation.

## 6. Whole-repository scans and scope checks

- **Web production/localhost URLs:** No production origin is hardcoded in web runtime code. Local test URLs occur in `web-app/playwright.config.ts:9,26,32,36`, `web-app/e2e/mock-supabase.mjs:61,70,105,194`, and `web-app/e2e/phase3.spec.ts:3,19,41`; the README development URL is `web-app/README.md:17`. `web-app/src/lib/auth/safe-next-path.ts:15-16` uses the non-routable `vaultic.invalid` sentinel, and `safe-next-path.test.ts:10` uses `attacker.example` as hostile test input.
- **Outside the Next.js app:** The existing Flutter `lib/config/build_config.dart:5` contains a Supabase project URL, and root Flutter `index.html:11,17` contains the existing `vaultic.app` canonical/OG URL. Flutter/root `web/` is out of scope and was not modified.
- **Injection/secrets/logging:** No `dangerouslySetInnerHTML`, service-role key usage, or `console.log`/`console.debug` call was found in implementation code. Service-role references are documentation safeguards. No token or user-data console logging was found.
- **TODO/fake persistence:** No TODO/FIXME or fake persistence logic was found in shipped Phase 3 paths. The `placeholder` hits are ordinary form placeholder attributes/selectors in `transaction-form.tsx:178,197,231`, `categories-page.tsx:103`, `category-setup.tsx:117`, `transaction-list.tsx:154`, and `globals.css:563`.
- **Money arithmetic:** No floating-point financial arithmetic was found in web production code. Money input and arithmetic use integer paise/`BigInt`; numeric conversion is limited to Supabase's numeric DB boundary and formatting. Confidence-score rounding and test fixture amounts are not monetary calculations.
- **UI colors:** UI chrome uses centralized monochrome theme tokens (with a separate danger token); the green travel color is category data only. Category/chart data colors are centralized in `DATA_COLORS`.
- **Account deletion:** No account deletion UI, action, or RPC call exists in `web-app/`. The snapshot's function is intentionally not exposed through the web database function types.
- **Migrations:** No migration was applied. The two SQL proposals remain files under `supabase/migrations/`.
- **Flutter/worktree:** No Flutter source was changed. The working tree changes are confined to `web-app/`, `docs/`, and the proposed `supabase/` SQL. The snapshot file was already modified in the worktree and was preserved; it was not reverted.
- **Whitespace check:** `git diff --check` reports trailing whitespace at `docs/supabase/schema-snapshot.md:136` in that preserved snapshot change. `git diff --check` passes when that file is excluded; no other whitespace errors were reported.

## 7. Remaining verification

- Use a dedicated Supabase test account/project to verify email/password Auth, live RLS and CRUD, category/budget failure behavior, session expiry, and real `timestamptz` round trips.
- Approve and apply the proposed category unique index and transaction `updated_at` trigger only after the normal database review/deployment process; confirm deployed schema and migration history afterward.
- Validate 360px behavior with a real mobile virtual keyboard and safe areas.
- Decide whether to add a transactional category-removal operation before treating the remove-category failure path as all-or-nothing.
- Do not begin Phase 4 until the user approves that next phase.
