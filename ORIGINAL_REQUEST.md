# Original User Request

## Initial Request — 2026-09-05T10:52:40Z

This is a single self-contained refactor; keep it small and focused.

Working directory: c:\Users\User\Documents\antigravity\peaceful-bell
Integrity mode: development

Consolidate and polish the Zippy South African payments platform into a unified, production-grade Flutter mobile application (`zippy_app/`) backed by Appwrite Serverless Functions, removing redundant prototype folders and delivering a Cash App / Revolut-grade dark aesthetic.

## Requirements

### R1. Workspace Cleanup & Redundancy Removal
Clean up the root workspace (`c:\Users\User\Documents\antigravity\peaceful-bell`) by safely removing the temporary web prototype directories (`client/` and `backend/`), leaving `zippy_app/` as the single canonical codebase alongside `appwrite_schema/` and `appwrite_functions/`.

### R2. Flutter UI/UX Polish & Screen Flow
Refine the Flutter application (`zippy_app/`) to adopt the high-end modern dark theme:
- The Home screen opens with a bold, clean question: **"Who are you paying?"** with two distinct cards: **Merchant** (Zippy #) and **Split Fare** (1-Tap payback), plus quick-pay recent vendors.
- Zero financial fee jargon on the customer's face: clear ZAR numpad, bold amounts, and seamless transitions.
- The Merchant flow provides instant 4-digit lookup with verified vendor badges and 1-tap payment.
- The Split Fare flow enables selecting friends, calculating equal or custom portions, and provides a real-time progress settlement dashboard.

### R3. BaaS Architecture Integrity & Testing
Ensure the Flutter app is strictly connected to the Appwrite BaaS services:
- Pass-through calculations for the 2.5% merchant service fee and R2.50 split convenience fee reside in clean, testable core modules.
- Maintain Appwrite functions and database schemas for `vendors`, `transactions`, and `splits`.
- Verify with `dart analyze` (0 errors, 0 warnings) and `flutter test` (all passing).

## Acceptance Criteria

### Workspace Hygiene
- [ ] Temporary prototype folders (`client/` and `backend/`) are completely removed from the workspace.
- [ ] The root workspace contains only `zippy_app/`, `appwrite_schema/`, `appwrite_functions/`, and documentation.

### Code Quality & Static Analysis
- [ ] `dart analyze` in `zippy_app/` reports zero errors, warnings, or lints.
- [ ] All public classes, methods, and properties have `///` doc comments following Effective Dart guidelines.
- [ ] `flutter test` executes and passes all widget and logic tests.

### UI & Flow Verification
- [ ] The Flutter app compiles and runs cleanly on web/desktop target with `flutter run -d chrome` or `flutter build web`.
- [ ] The flow is intuitive: single initial screen offering Merchant vs. Split Fare selection with tactile ZAR numpad.
- [ ] The receipt screen includes a prominent "Split this bill with friends?" prompt that pre-populates the split amount.

## Follow-up — 2026-09-05T21:26:13Z

This is a single self-contained refactor; keep it small and focused.

Working directory: c:\Users\User\Documents\antigravity\peaceful-bell\zippy_app
Integrity mode: development

Elevate the Zippy South African payments platform (`zippy_app/`) to world-class design-engineering standards using principles from UI Skills for Design Engineers (https://www.ui-skills.com/) (`ibelick/baseline-ui`, `emilkowalski/animate`, `emilkowalski/apple-design`, `addyosmani/accessibility`, `anthropics/frontend-design`). Eliminate visual clutter, unify Merchant and Split Fare into a coherent, high-craft product experience, and implement tactile micro-interactions with fluid spring motion.

## Technical Context & Decisions

### 1. Navigation Architecture (`ibelick/baseline-ui`)
- Completely eliminate the redundant bottom navigation bar.
- Provide a single animated segmented pill `[ 🏪 Merchant | 👥 Split Fare ]` directly below the brand header `[Z] zippy • Pay simply. ⋯`.
- Clean task progression:
  - Merchant: Recipient (4-digit Zippy till or quick recents) → Amount (bold optical display) → Tactile ZAR keypad → Concluding "Pay R[Amount]" button.
  - Split Fare: Title/Context → Amount & Friends (sharing the same tactile ZAR keypad and unified surface cards) → Concluding "Create & Split R[Amount]" action.

### 2. Physical Motion & Tactile Feedback (`emilkowalski/animate` + `apple-design`)
- Spring-based tab switcher: Custom sliding indicator between Merchant and Split Fare using smooth spring curves (`Curves.easeOutCubic`).
- Tactile micro-interactions:
  - Scale micro-interaction (`0.96` scale on press-down) on all custom ZAR numpad keys and primary CTA buttons.
  - Animated optical number scaling on amount entry with `AnimatedDefaultTextStyle` or `AnimatedSwitcher`.
  - Animated vendor verification reveal when 4-digit Zippy till code is entered.

### 3. Shared Design System & Aesthetics (`anthropics/frontend-design`)
- Unify Merchant (`#16C784` Emerald) and Split Fare (`#8B5CF6` Electric Violet) so they feel like two cohesive facets of one application.
- Shared dark tokens: `#080D18` background, `#0F172A` cards, subtle 1px border `rgba(255,255,255,0.06)`, 16px corner radii.
- Seamless animated cross-fade/slide when switching between modes.

### 4. Accessibility & Touch Targets (`addyosmani/accessibility`)
- Minimum 48x48px touch targets for all interactive controls (numpad keys, mode pills, quick chips).
- WCAG AA contrast compliance across text and status indicators.

## Requirements

### R1. Navigation & Deslop Refactor
- Remove `BottomNavigationBar` entirely from `HomeScreen`.
- Refactor `_buildModePromptAndSegmentedControl` into a high-craft animated sliding pill widget with smooth background indicator movement.
- Ensure the brand header `[Z] zippy • Pay simply. ⋯` and the mode pill sit cleanly at the top of the viewport with consistent 8pt spacing.

### R2. Unified Merchant Flow
- Clean up competing cards on the Merchant screen:
  1. Recipient card: 4-digit code input + quick recent chips (`Siy'a's Tuck Shop`, `Mama Themba's`) with verified badge and bank details smoothly expanding once verified.
  2. Amount display: Optical typography with animated ZAR currency formatting.
  3. Tactile ZAR numpad with press micro-interactions.
  4. Full-width concluding action button: "Pay R[Amount]" with processing state.

### R3. Unified Split Fare Flow
- Bring Split Fare into full parity with the Merchant screen's visual and interaction design:
  1. Context card (e.g. "Dinner at RocoMamas 🍔") and friend selectors (chips with avatar indicators).
  2. Shared tactile ZAR numpad for total bill input.
  3. Live breakdown per person updating in real-time.
  4. Active split management & settlement view sharing the identical dark card styling and animated progress bars.

### R4. Shared Tactile Micro-Interactions
- Enhance `ZarNumpad` widget with responsive press animations (`ScaleTransition` / `AnimatedScale`).
- Add smooth transitions on the "Split this bill with friends?" prompt in the receipt view so users can transition seamlessly into Split Fare with the pre-filled amount.

### R5. Integrity & Verification
- Ensure all 39 tests in `test/widget_test.dart`, `fee_engine_test.dart`, `models_test.dart`, and `payment_service_test.dart` pass (`flutter test`).
- Zero warnings or errors on `dart analyze`.
- Verify live in browser at `http://localhost:8080`.

## Acceptance Criteria
- [ ] Bottom navigation bar is completely removed; single animated sliding pill switcher handles mode switching.
- [ ] Merchant and Split Fare share the exact same dark design language, card styles, and tactile keypad.
- [ ] Mode transitions animate smoothly with spring physics and sliding pill indicator.
- [ ] Keypad keys and primary CTA buttons have tactile press-down micro-animations (`AnimatedScale`).
- [ ] Verified vendor details expand smoothly upon entering a valid 4-digit code.
- [ ] All interactive elements have touch targets >= 48x48px.
- [ ] `dart analyze` reports zero errors, warnings, or lints.
- [ ] `flutter test` reports all 39 tests passing.
