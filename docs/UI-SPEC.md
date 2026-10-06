# Vaultic Web UI Specification

This is the single presentation reference for the Phase 3.5 revision and later web phases. It describes layout and interaction only; it does not change data behavior.

## Breakpoints and shell

- **Mobile and tablet, below 1024px:** no bottom navigation bar. The workspace has a header with “Vaultic” left and “Edit Categories” plus “Logout” pill actions right; a horizontal scroll-snap category-card strip; an accessible tab row; grouped transaction rows; and a fixed bottom-right add button. Reserve bottom padding so the add button never covers content.
- **Desktop, 1024px and wider:** retain the persistent sidebar. Main content may use up to approximately 1200px. Category cards become an auto-fill grid (`minmax(168px, 1fr)`) instead of a horizontal scroller. Keep a layout slot available for later summary/chart surfaces, but do not render them in Phase 3.5. At 1280px and wider, transactions may use two columns if this improves readability.
- Chrome is black/grey and token-based; category data colors remain in the shared `DATA_COLORS` mapping.

## Shared presentational components

- **AppHeader:** displays Vaultic and pill links for category management and a Logout action. Logout requires confirmation.
- **CategoryCardStrip / CategoryCard:** mobile cards are approximately 145×160px, 20px radius, 12px gap, horizontal scroll snap, with a leading icon, one-line truncated label, bold en-IN amount, and a final dashed “+ Add category” card. The month-spent card uses the expense data color. Card text color is selected for WCAG AA contrast. Desktop wraps cards into the category grid. Cards are focusable/clickable; Phase 4 supplies destinations.
- **DashboardTabs:** an accessible tab list with a neutral underline for Transactions. Render only implemented tabs; later tabs are added when those capabilities exist.
- **TransactionRow:** rounded card with category icon tile, description (up to two lines), muted date/category/Dr-or-Cr metadata, signed amount, and an always-visible trailing trash button. The whole non-control row opens edit. The trash action has a 44×44px target, descriptive accessible name, pointer tooltip, muted default styling, and destructive hover/focus/pressed states.
- **FloatingAddButton:** fixed bottom-right on mobile, token-colored, safe-area aware, and paired with content bottom padding.
- **Modal:** one shared native-dialog wrapper for transaction entry/edit, destructive confirmations, category add, and logout confirmation. It provides backdrop, browser focus containment, Escape handling, body-scroll lock, focus restoration, reduced-motion-aware transitions, and an internal scroll region. Desktop is centered with max width about 520px and max height 90dvh. Below 1024px it docks full-width to the bottom with a drag handle and safe-area padding. Forms keep their Save action visible while the body scrolls.
- **Category tiles:** `/categories` and setup review use compact individual tiles, approximately 56px high. Phone layout uses two columns; wider screens auto-fill from 180px. Names are one-line ellipsized with a title tooltip and a 44px remove action. Suggested categories are compact selectable chips.

Until Phase 4 adds summary data, category cards on `/transactions` show a dash rather than a fabricated total. Card values are formatted from integer paise, using en-IN INR grouping and suppressing `.00` only for whole rupees.

## Natural-language transaction entry

The smart-entry field debounces parsing by approximately 200ms and pauses during IME composition. It applies detected values directly to form fields, without an Apply button or separate preview panel. A user-edited field is never overwritten by later parsing. Missing amount detection leaves amount empty. Category is applied only when it matches a user's category; Credit clears it. Date defaults to today unless text supplies a date. Clearing smart-entry text clears only untouched auto-filled fields. Show the muted “Filled from your text” line while any fields are auto-filled.

## Modal and deletion behavior

- Transaction delete controls are visible without hover at every viewport. Confirmation names the transaction, amount, and date and offers a destructive Delete action plus Cancel. Successful deletion retains the existing Undo toast.
- Category removal uses a visible per-tile trash action named “Remove category: <name>” and a confirmation dialog.
- Dialog positioning must not depend on ancestor transforms; native dialog top-layer placement and the shared modal styles define centering/docking.

## Responsive quality targets

Test at 360×740, 390×844, 768×1024, and 1440×900. Page-level horizontal overflow is not allowed. Category cards scroll horizontally below 1024px and wrap at/above it. Verify touch targets, no content obscured by the floating add button, reduced motion, and keyboard navigation. Real mobile keyboard/safe-area behavior still needs a physical-device check.
