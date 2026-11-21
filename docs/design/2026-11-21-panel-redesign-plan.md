# Panel Redesign (0.2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the panel look native on macOS 26 (and good on 15), usable with mouse and keyboard, searchable with visible matches, accessible, and able to reach the whole history.

**Architecture:** All decisions that can be tested without a window go into `PastuCore` (paging, navigation, highlighting/snippets, code detection, labels, banner choice) with unit tests written first. The SwiftUI/AppKit shell in `Sources/Pastu` only renders them and is covered by `PanelSnapshotTests` and real-key tests in `PastuTests`.

**Tech Stack:** Swift 6, SwiftUI + AppKit (`NSPanel`), SQLite/FTS5, Swift Testing, SwiftPM. Zero dependencies.

**Spec:** `docs/design/2026-11-21-panel-redesign.md` (read it first; this plan does not repeat its visual details).

## Global Constraints

- No new dependencies, no network calls, never log clipboard content.
- macOS 15+ runtime; macOS 26 APIs only behind `#available(macOS 26, *)`. `ConcentricRectangle` and `scrollEdgeEffectStyle` are "verify": if `swift build` says they are unavailable on macOS, use the spec's fallback.
- Panel stays a borderless non-activating `ClipPanel`, about 780×460. Keyboard focus stays in the search field; every new control is `.focusable(false)`.
- Tests never touch `UserDefaults` (use `InMemorySettings`), the real history, or `NSPasteboard.general` (tests pass a private pasteboard).
- Gate for every commit: `swift test` exit code 0 with the result lines read, and `find ~/Library/Preferences -maxdepth 1 -name 'pastu.test*' | wc -l` prints 0. Never run `scripts/build-app.sh` in the repo (the maintainer's running copy lives in `build/`).
- Copy: sentence case in the panel; menu items title case per the HIG (spec, "Menu bar menu").
- Commits: small, English, ending with the harness attribution line.

## Review Focus

1. Whitespace-only or empty query: no highlight, no snippet, list unchanged (Task 3 test `emptyQueryHasNoRangesOrSnippet`).
2. A 1 MB clip with the match near the end: snippet and preview window still show the match and cut on grapheme boundaries (Task 3 tests `snippetFindsMatchNearEndOfHugeText`, `snippetNeverSplitsEmojiOrCombiningMarks`).
3. A new copy arrives while 250 rows are loaded: `refresh()` keeps all loaded rows and the selected clip (Task 2 test `refreshKeepsLoadedPagesAndSelectedClip`).
4. Changing query or filter after paging starts again from the first page, selection at top (Task 2 test `queryChangeResetsPaging`).
5. Context-menu or click in the panel must not close it or take focus from the search field (Task 8 key test `clickingARowKeepsSearchFieldFocused` and the manual checklist in Task 12).

---

### Task 1: Paged store queries

**Files:**
- Modify: `Sources/PastuCore/ClipStore+Queries.swift` (`recent`, `search`, private `query`)
- Test: `Tests/PastuCoreTests/ClipStoreTests.swift`

**Interfaces:**
- Produces: `ClipStore.recent(limit: Int = 50, offset: Int = 0, kind: ClipKind? = nil) throws -> [StoredClip]` and `ClipStore.search(_ query: String, limit: Int = 50, offset: Int = 0, kind: ClipKind? = nil) throws -> [StoredClip]`. Same order as today (`pinned DESC, last_copied_at DESC, id DESC`); offset is a bound parameter, never interpolated.

- [ ] **Step 1: Write failing tests** `pagesOfRecentDoNotOverlapAndCoverAll` (insert 250 clips; pages `offset: 0/100/200, limit: 100` have 100, 100, 50 rows; union of ids == all 250; no duplicates) and `searchPagesKeepOrder` (120 clips containing "item"; `search("item", limit: 100, offset: 100)` returns the 20 oldest, in the same order as the tail of `search("item", limit: 200)`).
- [ ] **Step 2: Run** `swift test --filter ClipStoreTests` — Expected: FAIL (extra argument `offset`).
- [ ] **Step 3: Implement** add `offset` to both methods; in `query(...)` append `OFFSET ?N` using a bind slot after the existing ones (keep `?1` = limit). Negative offsets are clamped to 0.
- [ ] **Step 4: Run** `swift test --filter ClipStoreTests` — Expected: PASS.
- [ ] **Step 5: Gate and commit** `git commit -m "ClipStore: paged recent/search with a bound offset"`.

### Task 2: List model navigation and paging

**Files:**
- Modify: `Sources/PastuCore/ClipListModel.swift`, `Sources/PastuCore/ClipKind.swift` (`ClipFilter.previous`)
- Test: `Tests/PastuCoreTests/ClipListModelTests.swift`, `Tests/PastuCoreTests/ClipKindTests.swift`

**Interfaces:**
- Consumes: Task 1 `search(_:limit:offset:kind:)`.
- Produces (all `public`, `@MainActor`):
  - `ClipListModel.init(store: ClipStore, pageSize: Int = 100)` (replaces `limit:`; update existing call sites/tests).
  - `var hasMore: Bool { get }` — false once a page came back short.
  - `func loadMore()` — appends the next page for the current query/filter; selection unchanged.
  - Auto-load: whenever the selection moves to within 10 rows of the end and `hasMore`, call `loadMore()`.
  - `func refresh()` — re-runs the query for **all loaded rows** (limit = loaded count, at least pageSize) and keeps the selection on the same clip id if still present, else clamps.
  - `func cycleFilter(reverse: Bool = false)`; `ClipFilter.previous` (All ← Text ← Links ← Images ← All).
  - `func resetForShow()` — query "", filter .all, first page only, selection 0, notice nil.
  - `enum EscapeOutcome { case clearedQuery, close }` and `func escape() -> EscapeOutcome` — non-empty query → clears it, returns `.clearedQuery`; else `.close`.
  - `func moveToStart()`, `func moveToEnd()` (last loaded row, then `loadMore()` if `hasMore`), `func movePage(_ direction: Int, rowsPerPage: Int)` (clamped like `moveSelection`). All clear `notice`.

- [ ] **Step 1: Write failing tests:**
  - `startsWithOnePage` (250 clips → 100 rows, `hasMore == true`).
  - `movingNearTheEndLoadsTheNextPage` (`moveSelection(by: 90)` → 200 rows; selection still 90).
  - `loadMoreStopsAtTheEnd` (250 clips; after loads → 250 rows, `hasMore == false`, another `loadMore()` changes nothing).
  - `refreshKeepsLoadedPagesAndSelectedClip` (load 200, select row 150, insert a new clip, `refresh()` → 201 rows, `selectedClip?.id` unchanged).
  - `queryChangeResetsPaging` (load 200, set query → at most 100 rows, selection 0; same for filter).
  - `reverseCycleGoesAllImagesLinksTextAll`; `ClipKindTests.previousIsTheInverseOfNext` (for every filter `f.next.previous == f`).
  - `resetForShowClearsQueryFilterAndSelection`.
  - `escapeClearsQueryFirstThenCloses` (query "a" → `.clearedQuery`, query ""; again → `.close`).
  - `moveToStartAndEnd` (end = last loaded row and triggers next page when `hasMore`), `movePageClamps` (`movePage(1, rowsPerPage: 8)` from 0 → 8; `movePage(-1, …)` from 3 → 0).
- [ ] **Step 2: Run** `swift test --filter "ClipListModelTests|ClipKindTests"` — Expected: FAIL (missing members).
- [ ] **Step 3: Implement** the interfaces above in `ClipListModel.swift`; existing behaviors (notice clearing, pin keeps selection on clip, delete clamps) unchanged.
- [ ] **Step 4: Run** the same filter — Expected: PASS; then full `swift test` (existing callers of `limit:` updated).
- [ ] **Step 5: Gate and commit** `"ClipListModel: paging, reverse filter cycle, Esc semantics, start/end/page moves"`.

### Task 3: Match ranges, snippets and the preview window

**Files:**
- Create: `Sources/PastuCore/SearchHighlighter.swift`
- Modify: `Sources/PastuCore/ClipFormatting.swift` (preview around a match)
- Test: `Tests/PastuCoreTests/SearchHighlighterTests.swift`, `Tests/PastuCoreTests/ClipFormattingTests.swift`

**Interfaces:**
- Produces:
  - `public enum SearchHighlighter`
  - `static func terms(of query: String) -> [String]` — whitespace-split, same as `ClipStore.search`.
  - `static func ranges(of query: String, in text: String) -> [Range<String.Index>]` — sorted, merged, non-overlapping. Terms of 3+ characters: `.caseInsensitive` + `.diacriticInsensitive`. Shorter terms: case-insensitive for ASCII letters only, no diacritic folding (mirrors `instr(lower(...))`).
  - `public struct Snippet: Equatable { public let text: String; public let highlights: [Range<String.Index>] }` — `text` already contains "…" at cut ends; highlights index into `text`.
  - `static func snippet(of query: String, in text: String, maxLength: Int = 120) -> Snippet?` — nil for empty query or no match; whitespace runs collapsed to one space (like `rowTitle`); window centered on the first match (about a third before it), cut on `Character` boundaries.
  - `static func titleContainsMatch(_ title: String, query: String) -> Bool`.
  - `ClipFormatting.previewText(_ text: String, around query: String, limit: Int = 4_000) -> (text: String, hiddenBefore: Int, hiddenAfter: Int)` — when the first match is inside the first `limit` characters, identical to today's start-of-text preview (`hiddenBefore == 0`); otherwise a `limit`-sized window around the first match.

- [ ] **Step 1: Write failing tests** (exact expectations):
  - `rangesAreCaseAndAccentInsensitiveForLongTerms`: `ranges(of: "cafe", in: "Café au lait")` covers "Café".
  - `shortTermsFoldAsciiCaseOnly`: `ranges(of: "is", in: "This IS")` → 2 ranges; `ranges(of: "is", in: "İstanbul")` → empty.
  - `multipleTermsMergeOverlaps`: `ranges(of: "abc bcd", in: "abcd")` → one range "abcd".
  - `emptyQueryHasNoRangesOrSnippet`: `"   "` → `[]` and `nil`.
  - `snippetCentersOnFirstMatch`: 500 × "x " + "needle" + 500 × " y" → text starts and ends with "…", contains "needle", `count <= 122`, highlight covers "needle".
  - `snippetAtStartHasNoLeadingEllipsis`.
  - `snippetFindsMatchNearEndOfHugeText`: 1,000,000 "a" + " needle" → snippet contains "needle".
  - `snippetNeverSplitsEmojiOrCombiningMarks`: text of "👩‍👩‍👧" and "e\u{301}" repeated around a match → every `Character` in `snippet.text` exists in the source.
  - `titleContainsMatch` true/false cases.
  - `previewAroundMatchBeyondLimit`: 10,000 "a" + "needle" + 10 "b", limit 4,000 → text contains "needle", `hiddenBefore > 0`; match inside the first 4,000 → `hiddenBefore == 0`.
- [ ] **Step 2: Run** `swift test --filter "SearchHighlighterTests|ClipFormattingTests"` — Expected: FAIL.
- [ ] **Step 3: Implement** `SearchHighlighter.swift` and the new `previewText(_:around:limit:)` overload. Do not walk the whole text more than once per term; use `String.range(of:options:range:)`.
- [ ] **Step 4: Run** same filter — Expected: PASS.
- [ ] **Step 5: Gate and commit** `"SearchHighlighter: match ranges, snippets and a preview window around the match"`.

### Task 4: Presentation helpers (code detection, links, labels, banner)

**Files:**
- Modify: `Sources/PastuCore/ClipFormatting.swift`
- Create: `Sources/PastuCore/PanelBanner.swift`
- Test: `Tests/PastuCoreTests/ClipFormattingTests.swift`, `Tests/PastuCoreTests/PanelBannerTests.swift`

**Interfaces:**
- Produces:
  - `ClipFormatting.looksLikeCode(_ text: String, sourceBundleIdentifier: String?) -> Bool` — true if source is one of `com.apple.Terminal`, `com.googlecode.iterm2`, `com.mitchellh.ghostty`, `dev.warp.Warp-Stable`, `com.apple.dt.Xcode`, `com.microsoft.VSCode`, `dev.zed.Zed`; or (only inspecting the first 2,000 characters) the text has ≥2 lines and at least two of: a line starting with `$ ` or `#!`, a `{` and a `}` on different lines, a line ending in `;`, a line indented by 4+ spaces or a tab. Conservative: prose with one semicolon is false.
  - `ClipFormatting.linkParts(_ text: String) -> (host: String, full: String)?` — only for text where `ClipKind.detect == .link`; mailto → host is the address.
  - `ClipFormatting.accessibilityLabel(kind: ClipKind, appName: String?, pixelSize: (width: Int, height: Int)?, copiedAt: Date, now: Date, isPinned: Bool) -> String` — exact forms: `"Text from Terminal, just now, pinned"`, `"Link from Safari, 5 minutes ago"`, `"Image from Preview, 1440 by 900, 2 hours ago"`, unknown app → `"Text, 3 days ago"`. Spoken time words: just now / N minute(s) ago / N hour(s) ago / N day(s) ago / N month(s) ago (singular for 1).
  - `public enum PanelBanner: Equatable { case accessibilityMissing, recordingPaused }` with `static func current(canAutoPaste: Bool, isPaused: Bool) -> PanelBanner?` — accessibility wins over paused; nil when neither.
- [ ] **Step 1: Write failing tests** for each listed example plus: `looksLikeCodeIsFalseForProse` ("Hi; see you at 5.\nThanks"), `looksLikeCodeForShellSnippet` ("$ swift test\n$ git push"), `linkPartsForUrlAndMailto`, `linkPartsNilForPlainText`, `bannerPriority` (all four combinations).
- [ ] **Step 2: Run** `swift test --filter "ClipFormattingTests|PanelBannerTests"` — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Gate and commit** `"Presentation helpers: code detection, link parts, spoken labels, banner choice"`.

### Task 5: Shell style, glass and fallbacks

**Files:**
- Modify: `Sources/Pastu/Panel/PanelShell.swift`, `Sources/Pastu/Panel/PanelView.swift` (`PanelMetrics`), `Sources/Pastu/PanelController.swift` (`invalidateShadow`), `Sources/Pastu/ClipPanel.swift` if needed
- Create: `Sources/Pastu/Panel/VisualEffectBackground.swift` (`NSViewRepresentable` wrapping `NSVisualEffectView`)
- Test: `Tests/PastuTests/PanelSnapshotTests.swift`

**Interfaces:**
- Produces:
  - `enum PanelStyle { case glass, legacy; static var system: PanelStyle }` (`.glass` iff `#available(macOS 26, *)`), injected with `@Environment(\.panelStyle)` (default `.system`).
  - `PanelMetrics.cornerRadius: CGFloat` (22), `PanelMetrics.contentInset: CGFloat` (8), `PanelMetrics.innerRadius` = cornerRadius − contentInset.
  - `View.panelShell()` reads `panelStyle`, `accessibilityReduceTransparency` (opaque `Color(nsColor: .windowBackgroundColor)`), `colorSchemeContrast` (1pt `separatorColor` stroke when `.increased`).
- [ ] **Step 1: Write failing snapshot tests** `panelRendersLegacyStyle`, `panelRendersWithReduceTransparency`: render `PanelView` with `.environment(\.panelStyle, .legacy)` / `.environment(\.accessibilityReduceTransparency, true)` and assert the corner pixel at (2,2) is transparent (rounded shell) and the center pixel of the header area is not fully transparent (a background exists). Save PNGs via `PASTU_SNAPSHOT_DIR` like the other tests.
- [ ] **Step 2: Run** `swift test --filter PanelSnapshotTests` — FAIL (no `panelStyle`).
- [ ] **Step 3: Implement**; on `.glass`, add the scroll edge effect under header/footer only if `scrollEdgeEffectStyle` compiles for macOS (else skip); call `panel.invalidateShadow()` after setting `contentView` in `PanelController.show()`; appear animation ≤150 ms skipped when `accessibilityReduceMotion`.
- [ ] **Step 4: Run** — PASS. Look at the PNGs in a scratch `PASTU_SNAPSHOT_DIR` (light and dark).
- [ ] **Step 5: Gate and commit** `"Panel shell: style switch, macOS 15 visual-effect fallback, reduce transparency and contrast"`.

### Task 6: Header row, filter control and banners

**Files:**
- Create: `Sources/Pastu/Panel/SearchHeader.swift`, `Sources/Pastu/Panel/FilterControl.swift` (replaces `FilterBar.swift`; delete it), `Sources/Pastu/Panel/BannerRow.swift`
- Modify: `Sources/Pastu/Panel/PanelView.swift`, `Sources/Pastu/PanelController.swift` (pass `isPaused` and `onResume`, `onOpenAccessibilitySettings`)
- Test: `Tests/PastuTests/QuickPasteKeyTests.swift`, `Tests/PastuTests/PanelSnapshotTests.swift`

**Interfaces:**
- Consumes: `cycleFilter(reverse:)` (Task 2), `PanelBanner.current` (Task 4), `PanelStyle` (Task 5).
- Produces: `PanelView` gains `isPaused: Bool = false`, `onResume: () -> Void = {}`, `onOpenAccessibilitySettings: () -> Void = {}`. Header: `magnifyingglass` + `TextField("Search")` (`.title2`) + clear button (only when query non-empty, sets query "") + `FilterControl(selection:)`. FilterControl: glass buttons in `GlassEffectContainer` (`.glassProminent` selected / `.glass`) on `.glass`; segmented `Picker` `.controlSize(.small)` on `.legacy`; every button `.focusable(false)`; symbols per spec.
- [ ] **Step 1: Write failing tests:** key test `shiftTabCyclesFiltersBackwards` (keyCode 48 with `.shift` → `.images`, then `.links`); snapshots `panelRendersAccessibilityBanner` (`canAutoPaste: false`) and `panelRendersPausedBanner` (`isPaused: true`) — assert render succeeds and size matches; save PNGs.
- [ ] **Step 2: Run** `swift test --filter "QuickPasteKeyTests|PanelSnapshotTests"` — FAIL.
- [ ] **Step 3: Implement**; remove the orange warning from the footer (moves to the banner). Wire `onResume` to `RecordingState.toggle()` and `onOpenAccessibilitySettings` to the existing settings URL (move `openAccessibilitySettings` into a small shared helper used by both the menu and the panel).
- [ ] **Step 4: Run** — PASS; full suite (existing Tab test must still pass).
- [ ] **Step 5: Gate and commit** `"Panel header: search icon, clear button, clickable filters, Accessibility and paused banners"`.

### Task 7: Row redesign, highlight, snippet and VoiceOver

**Files:**
- Modify: `Sources/Pastu/Panel/ClipRow.swift`, `Sources/Pastu/Panel/ThumbnailView.swift`, `Sources/Pastu/Panel/AppIconView.swift`, `Sources/Pastu/Panel/PanelView.swift` (list, ⌘-held state)
- Create: `Sources/Pastu/Panel/CommandKeyMonitor.swift` (observes `flagsChanged` while the panel is visible; publishes `isCommandHeld`)
- Test: `Tests/PastuTests/PanelSnapshotTests.swift`

**Interfaces:**
- Consumes: `SearchHighlighter.ranges/snippet/titleContainsMatch` (Task 3), `ClipFormatting.accessibilityLabel` (Task 4), `PanelMetrics.innerRadius` (Task 5).
- Produces: `ClipRow(clip:isSelected:shortcutDigit:showsShortcut:query:imageData:)`. Visuals per spec "List row" (leading slot 28pt; solid accent selection with white text; `.quaternary` hover; ⌘ badge only when `showsShortcut`; subtitle = snippet when a query matches outside the title, else "App · time"; picture subtitle "App · W×H · time"). Accessibility: `.accessibilityElement(children: .ignore)`, label from Task 4, `.isSelected` trait, hint "Press Return to paste". Post `AccessibilityNotification.Announcement(label)` when the selection changes.
- [ ] **Step 1: Write failing snapshot tests** `panelRendersSearchSnippet` (long clip with the query deep inside; assert the model's selected row title does not contain the term and that `SearchHighlighter.snippet` is non-nil — guards the setup — then render and save), `panelRendersWithCommandHeld` (inject `isCommandHeld: true` via environment or init), `panelRendersSelectedAndHoverRows` (hover state injected for one row).
- [ ] **Step 2: Run** `swift test --filter PanelSnapshotTests` — FAIL.
- [ ] **Step 3: Implement.** Thumbnails stay synchronous (async is 0.4).
- [ ] **Step 4: Run** — PASS; inspect PNGs.
- [ ] **Step 5: Gate and commit** `"Panel rows: native selection, hover, match highlight and snippets, VoiceOver labels"`.

### Task 8: Mouse: click, double click, context menu

**Files:**
- Modify: `Sources/Pastu/Panel/ClipRow.swift`, `Sources/Pastu/Panel/PanelView.swift`, `Sources/Pastu/PanelController.swift`, `Sources/Pastu/PasteCoordinator.swift`
- Test: `Tests/PastuTests/QuickPasteKeyTests.swift` (rename suite file is not needed)

**Interfaces:**
- Consumes: `ClipListModel.select(row:)`, `togglePinSelected()`, `deleteSelected()`.
- Produces: `PanelView` gains `onCopyOnly: () -> Void = {}`. Row: `.onTapGesture(count: 2)` → select + `onSubmit()`; `.onTapGesture` → `select(row:)`; `.contextMenu` with Paste, Copy, Pin/Unpin, Delete, Ignore "App" (disabled when app unknown). `PanelController`: Copy = hide panel, then `PasteCoordinator.copy(_ clip: StoredClip)` (pasteboard write + `markUsed`, no ⌘V, no Accessibility prompt). Pin/Delete/Ignore keep the panel open.
- [ ] **Step 1: Write failing tests:**
  - `PasteCoordinator.copy` unit-level test in `PastuTests`: with a private `NSPasteboard(name: .init("pastu.test.\(UUID())"))`-backed `SystemPasteboard` and in-memory store, `copy(clip)` puts the text on that pasteboard and bumps `lastCopiedAt`; it never calls `PasteSender` (inject a `sendPaste: () -> Void` closure, default `PasteSender.sendCommandV`, and assert it was not called). Release the private pasteboard at the end.
  - `clickingARowKeepsSearchFieldFocused`: send a left-mouse-down/up pair at the second row's location; expect `model.selectedIndex == 1`, the panel still visible, and `panel.firstResponder` is the search field's text view (`NSTextView`).
  - `doubleClickSubmits`: two clicks with `clickCount` 2 → `onSubmit` called once with that row.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.** If gestures take focus, restore it with the existing `@FocusState` after the action.
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Gate and commit** `"Panel: click to select, double click to paste, row context menu with Copy"`.

### Task 9: Preview redesign

**Files:**
- Modify: `Sources/Pastu/Panel/PreviewPane.swift`
- Test: `Tests/PastuTests/PanelSnapshotTests.swift`

**Interfaces:**
- Consumes: `looksLikeCode`, `linkParts` (Task 4), `previewText(_:around:limit:)`, `SearchHighlighter.ranges` (Task 3), `PanelMetrics.innerRadius` (Task 5).
- Produces: `PanelView` drops its three `Divider()`s (spacing separates areas) and the list becomes 320pt wide. `PreviewPane(clip:query:imageData:)`; content surface per spec; no app/time header; text `.body` or monospaced if `looksLikeCode`; links as host + full URL; matches highlighted and scrolled into view (`ScrollViewReader` to an id at the first match paragraph); "…" markers when `hiddenBefore/hiddenAfter > 0`; metadata `Grid`: Source, Copied, Size, Copied N times (if > 1), Pinned (if pinned).
- [ ] **Step 1: Write failing snapshot tests** `previewRendersLinkParts`, `previewRendersProseInBodyFont` (assert via a tiny exposed helper `PreviewPane.usesMonospace(for:)` returning `looksLikeCode` for prose == false and for a shell snippet == true), `previewRendersMatchBeyondLimit`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — PASS; inspect PNGs.
- [ ] **Step 5: Gate and commit** `"Preview: calm content surface, metadata grid, code-aware font, links, jump to match"`.

### Task 10: Footer, shortcuts overlay and empty states

**Files:**
- Modify: `Sources/Pastu/Panel/HintFooter.swift`, `Sources/Pastu/Panel/PanelView.swift`
- Create: `Sources/Pastu/Panel/ShortcutsOverlay.swift`, `Sources/Pastu/Panel/EmptyState.swift`
- Test: `Tests/PastuTests/PanelSnapshotTests.swift`, `Tests/PastuTests/QuickPasteKeyTests.swift`

**Interfaces:**
- Produces: footer = keycaps `↩ Paste`, `⌘P Pin`, `⌘⌫ Delete`, trailing `⌘/ Shortcuts` (a `.focusable(false)` button toggling `showsShortcuts`). Notices still replace the hints and are announced with `AccessibilityNotification.Announcement` when set. `ShortcutsOverlay` lists: ↩ Paste, ⌘1–9 Paste row, ⌘P Pin, ⌘⌫ Delete, ⌘I Ignore app, ⇥ / ⇧⇥ Filter, ↑↓ Select, ⌘↑ ⌘↓ First / last, Page Up/Down, Esc Clear search / close. Empty states use `ContentUnavailableView` with the spec's exact copy: "Nothing copied yet" / "Copy something, then press ⌘⇧V."; "No text yet" / "No links yet" / "No images yet"; search: `ContentUnavailableView.search(text:)` plus "Searching <Filter> only. Press Tab to change." when filter ≠ All.
- [ ] **Step 1: Write failing tests:** key test `commandSlashTogglesShortcuts` (keyCode 44 with `.command` toggles a `@State` exposed through an observable flag on the model or a binding the test can read; simplest: `ClipListModel.showsShortcuts: Bool`); snapshots `panelRendersShortcutsOverlay`, `panelRendersNoResultsInLinks` (query "zzz", filter .links), and update `panelRendersEmptyState`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** (`ClipListModel.showsShortcuts` added in Core with a one-line unit test that `resetForShow()` sets it false).
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Gate and commit** `"Footer keycaps, shortcuts overlay (⌘/), ContentUnavailableView empty states"`.

### Task 11: Keyboard wiring and paging in the panel

**Files:**
- Modify: `Sources/Pastu/ClipPanel.swift` (`cancelOperation`, key equivalents for ⌘↑/⌘↓), `Sources/Pastu/Panel/PanelView.swift` (`onKeyPress` for Home/End/Page keys, list `onAppear` of the last row → `loadMore()`), `Sources/Pastu/PanelController.swift` (`show()` calls `model.resetForShow()`; Esc uses `model.escape()`)
- Test: `Tests/PastuTests/QuickPasteKeyTests.swift`

**Interfaces:**
- Consumes: Task 2 API.
- [ ] **Step 1: Write failing key tests:** `escClearsQueryBeforeClosing` (via `PanelController`: type query, Esc → panel visible, query ""; Esc → hidden), `commandDownGoesToLastLoadedRowAndLoadsMore` (250 clips: ⌘↓ keyCode 125 → selection 99 and 200 rows loaded), `endAndHomeKeys` (keyCodes 119 / 115), `pageDownMovesByAPage` (keyCode 121), `showResetsFilterToAll` (set filter .links, `hide()`, `show()` → `.all`).
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.** Rows per page for Page keys: `Int(listHeight / rowHeight)`, fall back to 8.
- [ ] **Step 4: Run** — PASS; full suite.
- [ ] **Step 5: Gate and commit** `"Keyboard: Esc clears search first, ⌘↑/⌘↓, Home/End, Page keys, reset on open, load more on scroll"`.

### Task 12: Menu bar menu, docs and manual checklist

**Files:**
- Modify: `Sources/Pastu/StatusMenuController.swift`, `README.md` (keys table: Esc, ⇧Tab, ⌘↑/⌘↓, ⌘/, mouse), `CHANGELOG.md` (`[Unreleased]`), `docs/images/panel.png` and `panel-pictures.png` (regenerate from snapshots with sample data, same composition as before)
- Create: `docs/design/2026-11-21-panel-redesign-checklist.md` (manual checks)
- Test: `Tests/PastuTests/StatusMenuTests.swift` (new)

**Interfaces:**
- Produces: `StatusMenuController.menuForTesting: NSMenu` (built by `install()` without a real status item when a flag is passed: `install(inStatusBar: Bool = true)`).
- [ ] **Step 1: Write failing tests:** titles are `["Show Pastu", "Pause Recording", "Clear History…", "Ignored Apps", "About Pastu", "Quit Pastu"]` in that order (ignoring hidden warning items and separators); "Show Pastu" has `keyEquivalent == "v"` with `[.command, .shift]`; after `toggleRecording` the pause item's `state == .on` and its title is unchanged; status item description "Pastu (paused)" is produced by a pure `StatusMenuController.accessibilityDescription(isPaused:)`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement**, including `NSApp.activate()` before the Clear History alert, `exclamationmark.triangle` images on warnings, human-readable warning text ("Pastu can't save new clips right now" etc. instead of raw errors; raw error still goes to `NSLog`), and "About Pastu" via `NSApp.orderFrontStandardAboutPanel`.
- [ ] **Step 4: Run** — PASS. Regenerate README images (sample data only) and update README/CHANGELOG.
- [ ] **Step 5: Write the manual checklist** (from the spec's Testing section: glass light/dark, macOS 15 if available, VoiceOver row reading, click/double-click/context menu in TextEdit, Safari and Terminal with the paste landing in that app, Reduce Transparency/Motion, Increase Contrast).
- [ ] **Step 6: Gate, commit** `"Menu bar menu per HIG; docs, images and manual checklist for 0.2"`, push, and check CI is green.
