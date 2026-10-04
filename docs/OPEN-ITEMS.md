# Open Items

## Unverified Product And Security Claims

Flutter's `/privacy` and `/terms` copy contains statements that have not been verified by the inspected implementation. The web pages are approved to preserve that copy as-is, but the following claims must remain identified as unverified and must not be represented as technically confirmed by the web implementation:

- Bank linking or linked-bank transaction aggregation. The Flutter bank connection screen is deprecated and empty; no working bank-link service was found.
- Biometric authentication or multi-factor authentication.
- Encryption guarantees beyond the protections provided by the configured Supabase service and transport.
- GDPR, local financial data privacy, or other regulatory compliance claims.

## Legal Copy And Scope

The `delete_user_account()` function is used only by the Flutter app and is out of scope for the web app.

The Flutter Privacy Policy contains this in-app deletion promise in §5, which will remain unchanged in the approved static legal-page copy: “Users can delete their account at any time, which will remove their data from our systems, subject to legal retention requirements.” The Flutter Terms copy has no user-initiated account-deletion promise; its §5 reference to suspension or termination concerns misuse.

## Schema And RLS

The authoritative snapshot is [`docs/supabase/schema-snapshot.md`](./supabase/schema-snapshot.md). It records columns, constraints, and RLS enabled with `auth.uid() = user_id` policies for all seven listed tables. Remote changes after the 2026-10-04 capture still require a refreshed snapshot before depending on them.

### Verified Schema Differences From Earlier Parity Notes

- `web-app/src/types/database.types.ts` models the seven table definitions from the snapshot. Its `Functions` surface is intentionally empty even though the snapshot contains `public.delete_user_account()`; that RPC remains Flutter-only and is deliberately not exposed to the web app.
- `transactions` has a unique `(user_id, transaction_id)` constraint and nullable `updated_at` with default `now()`. The web uses idempotent conflict-ignoring writes and optimistic-concurrency updates. A before-update `updated_at` trigger is proposed, not applied.
- `categories` has no case-insensitive unique key and `user_id` is nullable; no duplicate names were present in the captured data. A `lower(name)` unique index is proposed as a migration file only, not applied.
- `budgets` has a verified unique `(user_id, category)` constraint, so scoped category-budget deletion is representable.
- `trips.trip_id` and `trip_transactions.transaction_id` are text primary keys, not per-user composite keys. Trip persistence remains out of scope. **Phase 6 must generate UUID keys** and reassess the primary-key/ownership model before any trip feature is added.
- Snapshot columns show `transactions.user_id`, `categories.user_id`, and `budgets.user_id` nullable; authenticated web inserts must explicitly provide the session user ID. Transactions store amount as numeric and date as timestamptz.

## Phase 3 Verification Limits

- Phase 3 Playwright tests use a local Supabase-compatible mock. They do not verify deployed Supabase Auth, live RLS behavior, email confirmation, Vercel cookies, or the production schema; use a real test project/account before release.
- The proposed category case-insensitive unique index and transaction `updated_at` trigger are files only under `supabase/migrations/`; neither has been applied. Until the index is approved and applied, concurrent category inserts can still race after the app's duplicate recheck.
- Category and matching-budget deletion currently use separate PostgREST requests. If the budget deletion fails, the app attempts to restore the category and reports both failures, but this compensation is not atomic; a failed restore can leave the category deleted. A transactional server-side operation is required for a guaranteed all-or-nothing delete.
- Cross-tab edit conflicts are guarded by `(user_id, transaction_id, updated_at)` and stale categories are rechecked before save, but the race paths are not exercised by browser tests.
- The 360px browser viewport covers responsive interactions, not a real mobile virtual keyboard or safe-area behavior on a physical iOS/Android device.
