# Panel redesign and "feels right" polish (Pastu 0.2)

Status: proposed, 2026-11-21. Layout direction chosen by the maintainer: **A, refined two-pane**.

## Intent

Pastu works, but the panel does not yet look or feel like a modern Mac app. Version 0.2 makes the panel look native
on macOS 26 (Liquid Glass) and still good on macOS 15, and makes everyday use smoother for both keyboard and mouse.
This is the first step toward "the best open-source clipboard manager for the Mac": before adding features, the
thing people see every day has to feel right.

## Goals

1. The panel follows Apple's current design language: glass only on the shell and controls, content on a calm
   surface, system selection style, SF Symbols, concentric corners, semantic text styles.
2. The panel can be used fully with the mouse (click, double click, context menu, clickable filters) without
   breaking the keyboard-first flow or stealing focus from the app the user is pasting into.
3. Keyboard behavior matches what Mac users expect (Esc clears search first, ⇧Tab, jump to top/bottom, page keys).
4. The whole history is reachable, not only the newest 50 clips.
5. Search results show why they matched (highlighted terms) and empty states explain what to do.
6. VoiceOver, Reduce Transparency, Reduce Motion and Increase Contrast are respected.
7. The menu bar menu follows macOS conventions.

## Non-goals (later milestones)

- Settings window, configurable shortcut, launch at login, onboarding window, undo for delete (0.3).
- Async thumbnails, drag-out, paste queue (0.4); OCR (0.5).
- Layout B (compact, Spotlight-style) and layout C (horizontal cards): considered and not chosen.

## Anti-goals (a failure even if it "works")

- A click or control in the panel activates Pastu or moves focus away from the target app, so ⌘V lands in the wrong place.
- Text or previews placed directly on glass so they become hard to read over busy wallpapers.
- Any new dependency, network call, or logging of clipboard content.
- The panel opening noticeably slower than today.
- Tests that touch `UserDefaults`, the real history or the user's pasteboard.

## Constraints

- Swift 6, SwiftUI + AppKit, SwiftPM, zero dependencies. macOS 15+ runtime; built with the macOS 26 SDK.
- macOS 26-only APIs (`glassEffect`, `GlassEffectContainer`, `.glass`/`.glassProminent` button styles) must sit behind
  `#available(macOS 26, *)` with a macOS 15 fallback. APIs marked "verify" below must be checked to exist on macOS
  before use; if one does not, use the stated fallback.
- The panel stays a borderless, non-activating `NSPanel` (`ClipPanel`). Keyboard focus stays in the search field.
- Test-first: logic goes in `PastuCore` with unit tests; the shell stays thin and is covered by
  `PanelSnapshotTests` and the existing key-handling tests in `PastuTests`.
- Panel size stays about 780×460 (layout A).

## Approaches considered

| | Layout | Trade-off | Decision |
|---|---|---|---|
| A | Refined two-pane: list left, preview always visible right | Great for code and pictures; preview area is empty-ish for short clips; least change and risk | **Chosen** by the maintainer |
| B | Compact Spotlight-style list (~640 wide), preview expands for pictures/long text or with Space | Lightest and closest to macOS 26 Spotlight; two layouts to build and test | Not chosen |
| C | Horizontal cards along the bottom of the screen | Very visual for pictures; weak for search, long text and density | Rejected |

## Design

### Shell (`Panel/PanelShell.swift`, `ClipPanel.swift`)

- Corner radius about 22pt (builder picks 20–24 by comparing with Spotlight). Inner shapes are concentric:
  inner radius = shell radius − inset (`ConcentricRectangle` if it exists on macOS 26: verify; else compute).
- macOS 26: `glassEffect(.regular, in:)` on the shell, as today.
- The shell's style (glass or legacy) comes from one internal value that defaults to `#available(macOS 26, *)` and
  that tests can override, so snapshot tests on the macOS 26 CI runner also render the macOS 15 fallback.
- macOS 15: an `NSVisualEffectView` (`.popover` or `.hudWindow` material, `.behindWindow` blending) behind the
  hosting view, masked to the rounded shape, instead of `.regularMaterial`.
- Reduce Transparency: opaque `windowBackgroundColor` shell. Increase Contrast: 1pt separator-colored stroke on the shell.
- Call `invalidateShadow()` after setting the content so the shadow follows the rounded shape.
- Appearing: short fade/scale (≤150 ms); none when Reduce Motion is on.

### Header (one row, about 52pt high)

- `magnifyingglass` symbol, then the search field (`.title2` style, placeholder "Search"), then a clear button
  (`xmark.circle.fill`) shown only when there is a query, then the filter control on the trailing side.
- Filter control: All / Text / Links / Images with symbols (`text.alignleft`, `link`, `photo`; All without a symbol).
  - macOS 26: buttons in a `GlassEffectContainer`; selected one `.glassProminent`, others `.glass`.
  - macOS 15: segmented `Picker`, `.controlSize(.small)`.
  - Clickable, but `.focusable(false)` so focus stays in the search field. Tab / ⇧Tab cycle as before.
- Banners directly under the header, only when relevant, one at a time (highest first):
  1. Accessibility missing: `exclamationmark.triangle.fill` (orange), "Pastu can't paste for you", button "Enable…"
     (opens the Accessibility settings pane). Replaces today's orange footer text.
  2. Recording paused: `pause.circle`, "Recording is paused", button "Resume".

### Content (no hard `Divider`s; spacing separates areas)

- Left: the list, about 320pt wide. Right: the preview on a subtle rounded content surface inset ~8pt
  (`.background` at reduced opacity, or `.quaternary` fill; builder's call), so content is not on glass.
- macOS 26: scroll edge effect under header/footer if `scrollEdgeEffectStyle` exists on macOS (verify); else nothing.

### List row (`Panel/ClipRow.swift`)

- Leading slot 28pt wide: app icon 24pt, or picture thumbnail 28×22 with ~4pt radius.
- Title `.body`, one line. Subtitle `.subheadline`, secondary: "App · 2m"; pinned clips show `pin.fill` (secondary)
  at the start of the subtitle. Picture title "Image", subtitle "App · 1440×900 · 2m".
- Selected: solid `Color.accentColor` fill, white title, white 80% subtitle and symbols; concentric corners.
- Hover (mouse): a light fill (`.quaternary`) on non-selected rows.
- ⌘1–⌘9 badge: shown as a keycap only on the selected row and on all nine rows while ⌘ is held
  (observe `flagsChanged`); hidden otherwise.
- Mouse: single click selects; double click pastes (same as Return); right click opens a context menu:
  Paste, Copy (to the clipboard only, no ⌘V), Pin/Unpin, Delete, Ignore "App name". Opening the menu or clicking must
  not take focus from the search field or close the panel (see risks). After the action: Paste and Copy close the
  panel (Copy is Paste without ⌘V); Pin, Delete and Ignore keep it open, like their keyboard shortcuts today.
- Search highlight: matched terms are emphasized (semibold, or a contrast-safe highlight on the selected row).
  When the first match is not inside the visible title, the subtitle shows a Spotlight-style snippet instead of
  "App · time": about one line of text around the first match, with "…" at cut ends and the match emphasized
  (the app and time move to the preview's metadata for that row). Snippet and ranges come from one `PastuCore`
  function (unit-tested: match at start, middle, end, several terms, no match, multi-byte text).

### Preview (`Panel/PreviewPane.swift`)

- No repeated app/time header (the row already shows it).
- Text: `.body` font; monospaced only for code-like text. During a search the preview scrolls to the first match;
  if the match lies beyond the 4,000-character preview cut, the preview shows a window of text around the match
  (with "…" markers) instead of the first 4,000 characters. "Code-like" is decided in `PastuCore`
  (e.g. source app is a terminal or code editor, or the text has code signals such as leading `$`, braces with
  newlines, semicolons at line ends). Matches are highlighted.
- Links: host in `.title3`, full URL below (selectable). No fetching, ever.
- Pictures: fitted, rounded 8pt; "Picture not available" state as today.
- Bottom: a two-column `Grid` with secondary labels: Source, Copied (relative), Size ("57 characters · 2 lines" or
  "1440×900 · 1.1 MB"), Copied N times (only if > 1), Pinned (only if pinned).
- Padding 16pt.

### Footer

- Keycap hints only: `↩ Paste`, `⌘P Pin`, `⌘⌫ Delete`, and on the trailing side `⌘/ Shortcuts`.
  Keycap = `.caption.monospaced()` on a small rounded `.quaternary` background.
- `⌘/` (or clicking "Shortcuts") shows a popover/overlay listing every shortcut, including ⌘1–9, ⌘I, Tab/⇧Tab,
  Esc, Space (if used), ⌘↑/⌘↓.
- Notices (e.g. "Ignoring Safari…") still replace the hints until the user moves on (existing behavior).

### Empty states (`ContentUnavailableView`, macOS 14+)

- No clips at all: `doc.on.clipboard`, "Nothing copied yet", "Copy something, then press ⌘⇧V."
- Filter empty: "No links yet" / "No images yet" / "No text yet".
- Search with no results: `ContentUnavailableView.search(text:)`; when a filter other than All is active, add
  "Searching Links only. Press Tab to change."

### Keyboard

- Esc: clears a non-empty query; with an empty query, closes the panel.
- ⇧Tab cycles filters backwards.
- ⌘↑ / Home: first row. ⌘↓ / End: last row loaded so far, and it also loads the next page if there is one (so
  pressing it again keeps going). It never loads the whole history at once. Page Up / Page Down: move by a page
  (about the number of visible rows).
- Opening the panel resets the query **and the filter** to All and selects the first row.
- ⌘/ toggles the shortcuts overlay.
- Arrow keys stay non-wrapping (as today).

### Whole history reachable (`ClipListModel`)

- First load 100 rows. When the selection comes within 10 rows of the end, or the list scrolls to the end, load the
  next 100 (same query and filter), keeping the selection. Stop when a page returns fewer rows than requested.
- Lists stay metadata-only (no picture bytes), as today.

### Accessibility

- Each row is one element: label like "Text from Terminal, just now, pinned" / "Image from Safari, 1440 by 900,
  2 minutes ago"; `.isSelected` trait on the selected row; hint "Press Return to paste". The label is built by a
  `PastuCore` function (unit-tested).
- Selection changes and notices are announced (`AccessibilityNotification.Announcement`) because focus stays in the
  search field.
- Filter buttons get button and selected traits (comes with real buttons).
- Respect `accessibilityReduceTransparency`, `accessibilityReduceMotion`, `colorSchemeContrast`.
- Semantic text styles everywhere; no fixed font sizes.

### Menu bar menu (`StatusMenuController.swift`)

- Title-case items per the HIG: "Show Pastu", "Pause Recording" (checkmark when paused, not a renamed item),
  "Clear History…", "Ignored Apps", "About Pastu", "Quit Pastu".
- "Show Pastu" displays ⌘⇧V as its key equivalent (display only; the global hotkey stays the real trigger).
- Warning items get an `exclamationmark.triangle` image and short human text (no raw error strings).
- Activate Pastu before showing the Clear History alert so it is in front.
- "About Pastu" uses the standard About panel (version from Info.plist).
- Status item accessibility description says "Pastu (paused)" while paused.

## Testing

- `PastuCore` unit tests (written first) for: reverse filter cycle; Esc semantics (`clearQueryOrClose`-style API);
  first/last/page moves; reset on show; paging (`loadMore`, selection kept, stops at end); highlight ranges
  (case- and accent-insensitive, multiple terms, short terms); code-like detection; accessibility label builder;
  footer/banner priority logic if it lives in the model.
- `PastuTests`: key-handling tests for the new keys; snapshot tests for: normal list, picture selected, link selected,
  each empty state, Accessibility banner, paused banner, shortcuts overlay, hover/selected row, Reduce Transparency.
- Manual checklist for the maintainer (cannot be automated here): glass look in light and dark mode on macOS 26;
  macOS 15 fallback look if a macOS 15 machine is available; clicking rows, chips and the context menu while typing
  in TextEdit, Safari and Terminal, then pasting: the paste must land in that app.

## Risks

- **Focus**: mouse interaction in a non-activating panel can make it key-but-active or close it via
  `windowDidResignKey`. Mitigation: `.focusable(false)` on controls, test the context menu and double click by hand
  in several apps before release.
- **macOS 15 look**: only verifiable on a macOS 15 machine; CI renders it but not visually checked.
- **Unverified APIs** (`ConcentricRectangle`, `scrollEdgeEffectStyle` on macOS): fallbacks defined above.
- **VoiceOver** with focus pinned to the search field: announcements are the mitigation; needs a manual check.

## Decided by the maintainer

- Layout A (refined two-pane).
- Matches deep inside long clips are shown with a snippet around the match (row) and the preview moves to the match.

## Calls made by the designer (can be overridden)

- Highlighting follows the search exactly: terms of 3+ characters case- and accent-insensitive, shorter terms
  case-insensitive for ASCII only (as the search does today). Changing short-term search is out of scope.
- The macOS 15 look is tested through the style override above (snapshot), not a macOS 15 CI job.

- Filter resets to All on every open (today it persists, which hides clips).
- Undo for delete deferred to 0.3.
- First page 100 rows, page size 100.
- ⌘1–9 badges only on the selected row or while ⌘ is held.

## Left to the builder

- Exact paddings, radii within the stated ranges, colors of hover/highlight, animation curves.
- File organization inside `Sources/Pastu/Panel/`.
- Code-like heuristic details (as long as it is tested and conservative).
