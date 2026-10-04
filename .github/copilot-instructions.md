# Vaultic Web Engineering Rules

These rules govern the Next.js application in `web-app/`. The Flutter application at the repository root is read-only and remains the behavior source. Its existing Flutter web platform target is preserved and is not the Next.js application directory.

## 1. Scope And Paths

- Build the web application only in `web-app/`.
- Keep Flutter source and platform files read-only.
- Put parity decisions in `docs/PARITY.md`, deployment instructions in `docs/DEPLOY.md`, unresolved product/security claims in `docs/OPEN-ITEMS.md`, and proposed SQL in `supabase/migrations/`.
- Vercel's project root and all web-specific CI working directories are `web-app/`.
- Any intentional behavior change from Flutter is logged in `docs/PARITY.md` under `Intentional Changes`.
- Work only on the phase explicitly approved by the user. Stop after that phase and summarize what changed, edge cases covered, tests run/added, and backend assumptions.

## 2. Stack And Foundation

- Next.js App Router, React, strict TypeScript, ESLint, Tailwind CSS, and npm.
- Keep browser and server Supabase clients separate. Validate environment values at the boundary where they are used; never add real credentials or a production origin to source control or environment defaults.
- Use `@supabase/ssr` for cookie-aware browser/server clients. Use the public anon key only in public client configuration; never expose a service-role key.
- Types derived from `docs/supabase/schema-snapshot.md` are authoritative only for SQL objects actually present there. If table definitions are absent, use explicitly marked provisional database types based on `docs/PARITY.md`; do not describe them as generated or verified.
- Keep the foundation deployable from Vercel with project root `web-app/`; do not add a production domain to code or env defaults.
- Keep the responsive application shell capability-neutral: mobile tab navigation and desktop sidebar must expose the same implemented capabilities.

## 3. Design And Accessibility

- Use black and grey as the dominant interface colors; preserve the approved stable category/chart palette in all data visualizations.
- Support light and dark themes. Keep visual tokens centralized.
- Design mobile-first, responsive, keyboard operable, screen-reader understandable, and respectful of reduced-motion preferences.
- Use semantic controls, visible focus, sufficient contrast, useful labels, and non-color indicators for financial states.
- Prefer dense, calm finance-workspace layouts over marketing/landing-page composition.

## 4. Data, Security, And Correctness

- Supabase is the source of truth. Use TanStack Query for caching, invalidation, optimistic updates, and rollback. Do not implement an offline mutation queue. “Sync now” is a Refresh action.
- RLS is the security boundary. Never trust a client-supplied user ID; use the authenticated Supabase session and verify the actual policies before relying on them.
- Do not infer schema, constraints, RLS, or RPC behavior from client code. Record unknowns and verify against the checked-in schema snapshot.
- All Supabase DB `amount` columns are numbers. Parse monetary input into integer paise, perform arithmetic in paise, and serialize to a number with at most two decimal places. Reject non-finite amounts and require amounts greater than zero wherever users enter a transaction, budget, or debt/payment amount.
- Keep transaction dates timezone-safe. Date-range end dates are inclusive through the end of that calendar day in the selected user timezone.
- Category removal never deletes or rewrites transaction history. Delete the matching category and its budget using both authenticated `user_id` and category key/name.
- Trip-transaction mutations are per-row and scoped by `(user_id, transaction_id)`; do not delete a trip's complete transaction set to update it. Editing updates in place and preserves status/split fields.
- JSON import merges only records missing by `transaction_id` / `owo_id`; preview counts, request confirmation, and never replace existing records. JSON export downloads a user-controlled file. Local auto-backup history and DataRecovery are omitted and must be recorded as intentional changes.
- Do not put provider secrets or service-role credentials in browser code. PDF generation is server-side and must use a font that renders the rupee glyph.
- Add security headers, avoid open redirects, do not leak secrets in errors or health checks, and rate-limit sensitive server endpoints when implemented.

## 5. Balance Carry-Forward

- Carry-forward is a Credit transaction with deterministic `transaction_id` `carry-forward-YYYY-MM` and description `Balance carried forward from <Mon YYYY>`.
- Before insert, check by that deterministic ID and by the description for the target month, because the Flutter app used different IDs. Negative balances create an owe entry with `owo_id` `carry-forward-owe-YYYY-MM`.
- Run rollover under `navigator.locks` so multiple tabs cannot race. Treat the lock as browser-tab coordination, not a substitute for database uniqueness.
- Propose a unique index on `(user_id, transaction_id)` as a SQL file under `supabase/migrations/`. Verify it against `docs/supabase/schema-snapshot.md` first, document any unverifiable assumptions, and do not apply it without explicit approval. Check existing duplicates and actual column types/constraints before activation.

## 6. Approved Intentional Behavior Changes

Record each of these under `Intentional Changes` in `docs/PARITY.md`:

- Require amounts greater than zero everywhere users enter monetary values.
- Ask for confirmation before deleting a transaction.
- “This Month Spent” and category totals default to the current month and provide an All time switch.
- Cap OWO partial payments at the remaining amount. Reopening a settled OWO entry warns that its earlier settlement transaction remains.
- PDF ranges include the full end date and compute opening balance using all transactions before the selected start date.
- Monthly net and month details exclude carry-forward helper rows consistently with summaries.
- Use one stable category-color mapping across dashboard, history pie, trips, and PDF: the ten suggested categories retain their suggested colors from the audit; custom categories use FNV-1a of the name into the dashboard palette. Never use Dart `hashCode` behavior.
- Supabase is online-first; no offline mutation queue. TanStack Query handles cache and optimistic updates. “Sync now” becomes Refresh.
- Backup becomes JSON export/download and confirmed JSON merge import with inserted/skipped counts. Omit local auto-backup history and the DataRecovery screen.
- Trip transaction edits use row-level updates and preserve status/split fields.
- The standalone Flutter `QuickAddBar` and deprecated bank-connection screen are not ported. `/privacy` and `/terms` are static pages with Flutter copy as-is; Settings also retains the external privacy URL. List unverified bank-linking, biometrics/MFA, encryption, and compliance claims in `docs/OPEN-ITEMS.md`.

## 7. Authentication Rules

- Use email + password sign-in and sign-up to match Flutter. Do not implement OTP. Normalize email by trimming and lowercasing it. Password minimum is 8 characters; signup/recovery confirmation must match.
- Signup handles email-confirmation-required (null session) and the existing-account case (empty identities list) like the mobile app.
- Forgot password returns an enumeration-safe message. Call `resetPasswordForEmail` with `redirectTo` built at runtime from the current origin: `${window.location.origin}/reset-password`. Never hardcode a domain or a development host in code. The production URL is not known; the user will add it to Supabase's redirect allowlist after first deployment.
- If a reset email arrives but the link lands on the wrong page or Supabase rejects the redirect, `/reset-password` must show a clear, friendly error and a “Request a new link” action, never a blank page or raw Supabase error.
- Handle the `PASSWORD_RECOVERY` event; enforce minimum length and matching confirmation; expired and reused links must have a retry path.
- Block open redirects. Accept only same-origin relative `next` paths; reject protocol-relative, absolute, and backslash-based destinations.
- Synchronize multi-tab auth state with `onAuthStateChange`. Protect authenticated routes in middleware and re-verify identity on the server with `supabase.auth.getUser()`.

## 8. Quality Gates

- Use strict TypeScript and avoid `any` except at a documented external boundary.
- Add focused tests for money conversion, rollover idempotency, date boundaries, color mapping, and destructive/security-sensitive behavior as their phases are implemented.
- Before completion, run the web-app lint, typecheck, test suite, and production build where available. Do not fix unrelated Flutter issues.
- Keep CI scoped to `web-app/` and make its working directory explicit.
- `/api/health` returns status only, with no secrets or environment values.
- No shipped route may use TODO or fake persistence logic. Clearly disclose not-yet-implemented phase scope in repository documentation rather than implying a feature works.

## 9. Phase Sequence

0. Parity audit (complete and approved).
1. Foundation in `web-app/`: scaffold, strict TypeScript, env validation, Supabase clients, provisional or snapshot-derived DB types, design tokens, responsive layout shell, theme support, error boundaries, CI, Vercel-ready shell, health route, and first-deployment docs.
2. Email/password auth, recovery, sessions, middleware, and branded auth experience.
3. Categories and transactions.
4. Balance logic and dashboard.
5. Server-side PDF export.
6. Settings and remaining approved parity surfaces.
7. Accessibility, performance, security hardening, PWA, E2E, deployment guide, and launch checklist.