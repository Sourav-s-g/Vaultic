# Flutter Category Name Change

This records the one-time Flutter exception for category-name comparison. The exception in `.github/copilot-instructions.md` was removed after implementation and test execution; all other Flutter files remain read-only.

## Files changed

- `lib/utils/category_name.dart` — added trimmed, whitespace-collapsed, lowercase comparison and first-occurrence deduplication helpers.
- `lib/screens/app_setup_screen.dart` — reject duplicate custom categories and prevent duplicate suggested-category selections.
- `lib/screens/category_management_screen.dart` — reject duplicate custom/suggested category names.
- `lib/HomePage.dart` — reject duplicate dashboard category creation and surface duplicate/persistence errors.
- `lib/services/hybrid_storage_service.dart` — deduplicate local/cloud category lists, reject duplicate adds, and resolve the original stored name before category removal.
- `lib/services/local_storage.dart` — deduplicate persisted category lists, check additions by normalized name, and remove using the exact stored category name.
- `lib/services/supabase_service.dart` — check category existence case-insensitively, treat Postgres unique violations as an already-existing category, deduplicate sync input, and keep deletion scoped to the authenticated user and exact stored name.
- `test/category_name_test.dart` — test case, edge/internal whitespace, empty name, and Unicode normalization/duplicate behavior.
- `docs/OPEN-ITEMS.md` — list unchanged case-sensitive transaction grouping and budget-key lookups, plus the normalization difference between app checks and the proposed lowercase-only database index.
- `docs/FLUTTER-CATEGORY-CHANGE.md` — this record.
- `.github/copilot-instructions.md` — temporarily added the requested exception, then removed it after implementation/testing; the final file is unchanged.

`lib/services/smart_input_parser.dart` was inspected and not edited: both direct category matching and category suggestions already lowercase the input/category strings.

No Flutter platform/config files or `web-app/` files were changed. No migration was applied.
