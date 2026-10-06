# Vaultic Web UI Specification

This is the single presentation reference for the Phase 4.5 revision and later web phases. It describes layout and interaction only; it does not change data behavior.

## Breakpoints and shell

- **Mobile and tablet, below 1024px:** no bottom navigation bar. The Dashboard header has “Dashboard” and the subline “Your personalised dashboard for your expenses”, with “Edit Categories” and “Logout” pill actions on the right (wrapping is allowed). A horizontal scroll-snap category-card strip, accessible tab row, grouped transaction rows, and fixed bottom-right add button are used where applicable. Reserve bottom padding so the add button never covers content.
- **Desktop, 1024px and wider:** retain the persistent sidebar with Dashboard / Transaction History / Categories. Main content may use up to approximately 1200px. Dashboard category cards become an auto-fill grid (`minmax(168px, 1fr)`). Transaction history uses the order and responsive chart/list arrangement below.
- **Shared TopBar:** every non-home page starts with a sticky bar below the safe-area inset, solid surface background, and bottom border. A clearly visible back arrow (24px icon, 44×44px target, 1px border, visible focus ring, accessible name “Back to Dashboard”) always navigates to `/`. The adjacent 20px medium title is truncated on one line. Transaction History and category-detail pages include a Refresh icon action which spins while fetching. Do not render a PDF action.
- Chrome is black/grey and token-based; category data colors remain in the shared `DATA_COLORS` mapping.

## Shared presentational components

- **AppHeader:** displays Vaultic and pill links for category management and a Logout action. Logout requires confirmation.
- **CategoryCardStrip / CategoryCard:** mobile cards are approximately 145×160px, 20px radius, 12px gap, horizontal scroll snap, with a leading icon, one-line truncated label, bold en-IN amount, and a final dashed “+ Add category” card. The month-spent card uses the expense data color. Card text color is selected for WCAG AA contrast. Desktop wraps cards into the category grid. Cards are focusable/clickable; Phase 4 supplies destinations.
- **DashboardTabs:** an accessible tab list with a neutral underline for Transactions. Render only implemented tabs; later tabs are added when those capabilities exist.
- **TransactionRow:** rounded card with category icon tile, description (up to two lines), muted date/category/Dr-or-Cr metadata, signed amount, and an always-visible trailing trash button. The whole non-control row opens edit. The trash action has a 44×44px target, descriptive accessible name, pointer tooltip, muted default styling, and destructive hover/focus/pressed states.
- **FloatingAddButton:** fixed bottom-right on mobile, token-colored, safe-area aware, and paired with content bottom padding.
- **Modal:** one shared native-dialog wrapper for transaction entry/edit, destructive confirmations, category add, and logout confirmation. It is centered horizontally and vertically at all sizes with width `min(92vw, 520px)`. It provides backdrop, browser focus containment, Escape handling, body-scroll lock, focus restoration, reduced-motion-aware transitions, visualViewport-aware positioning, safe-area padding, and an internal scrolling body. It is never a bottom sheet. Keep the Save action reachable while the body scrolls and the on-screen keyboard is open.
- **Category tiles:** `/categories` and setup review use compact individual tiles, approximately 56px high. Phone layout uses two columns; wider screens auto-fill from 180px. Names are one-line ellipsized with a title tooltip and a 44px remove action. Suggested categories are compact selectable chips.

The category card strip appears only on the Dashboard (`/`), never on `/transactions`. Card values are formatted from integer paise, using en-IN INR grouping and suppressing `.00` only for whole rupees.

### Dashboard

- Page heading is “Dashboard”; subline is exactly “Your personalised dashboard for your expenses”.
- Browser tab title is “Dashboard · Vaultic”.
- Dashboard uses the shared category cards, tabs, recent transactions, and in-place floating Add transaction dialog.

### Transaction history

- A compact previous / month label / next selector controls the monthly donut, summary, and transaction list.
- Content order is category donut card, one-row three-value summary card (Monthly Income, Monthly Spent, Total Balance), weekly bar card, 56px search field, then grouped transaction list.
- At desktop widths, the summary spans the full content width; donut and weekly chart share a row; the list spans full width. Do not render empty placeholder columns.
- Donut segments use the history palette in the category order defined in `docs/PARITY.md`; segments are separated by thin card-colored strokes. Percentage labels are shown inside segments at 5% or more. The wrapped legend filters the list and includes a screen-reader text/table fallback.
- Weekly chart starts weeks on Sunday and has independent previous/next navigation. Show a DD/MM - DD/MM range, y-axis title Amount with rupee ticks and solid horizontal gridlines, dashed vertical gridlines, framed plot area, weekday initials with full accessible day names, x-axis title Days, and rounded 16px bars in `#FFAB40`. Support touch/hover tooltips and zero-value weeks with axes intact.
- Each chart container has explicit sizing and is rendered by a client component. Loading and empty states remain visible; do not use fabricated data.
- Transaction date headings and row metadata use DD/MM/YYYY. Rows include icon, description, muted date/category, signed amount, neutral Completed chip, and visible delete action; activating the row edits it.
- The compact summary money formatter uses en-IN grouping and omits `.00` for whole-rupee values.

### Mobile field sizing and add flow

- Inputs, selects, and textareas compute to at least 16px at touch/mobile widths, preventing iOS Safari focus zoom. Use `-webkit-text-size-adjust: 100%`; retain viewport `width=device-width, initial-scale=1, viewport-fit=cover`, without `maximum-scale` or `user-scalable=no`.
- Floating Add transaction opens the shared dialog in place on Dashboard, Transaction History, Categories, and category detail. Opening, saving, canceling, and Escape do not change the URL. A successful save closes the dialog, updates existing query-backed views without a page reload, and shows a toast.

## Natural-language transaction entry

The smart-entry field debounces parsing by approximately 200ms and pauses during IME composition. It applies detected values directly to form fields, without an Apply button or separate preview panel. A user-edited field is never overwritten by later parsing. Missing amount detection leaves amount empty. Category is applied only when it matches a user's category; Credit clears it. Date defaults to today unless text supplies a date. Clearing smart-entry text clears only untouched auto-filled fields. Show the muted “Filled from your text” line while any fields are auto-filled.

## Modal and deletion behavior

- Transaction delete controls are visible without hover at every viewport. Confirmation names the transaction, amount, and date and offers a destructive Delete action plus Cancel. Successful deletion retains the existing Undo toast.
- Category removal uses a visible per-tile trash action named “Remove category: <name>” and a confirmation dialog.
- Dialog positioning must not depend on ancestor transforms; native dialog top-layer placement and the shared modal styles define centering.

## Responsive quality targets

Test at 360×740, 390×844, 768×1024, and 1440×900. Page-level horizontal overflow is not allowed. Category cards scroll horizontally below 1024px and wrap at/above it. Verify touch targets, no content obscured by the floating add button, reduced motion, and keyboard navigation. Real mobile keyboard/safe-area behavior still needs a physical-device check.
