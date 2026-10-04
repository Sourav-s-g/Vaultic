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

The snapshot currently contains no table DDL, column types, constraints, indexes, or RLS policies. The data models inferred in `docs/PARITY.md` remain provisional. Verify actual schema and policies before relying on client filters, uniqueness, cascade behavior, or RPC behavior. In particular, check duplicate `(user_id, transaction_id)` records and actual types/constraints before proposing or activating the carry-forward unique index.
