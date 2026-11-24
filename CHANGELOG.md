# Changelog

All notable changes to Pastu are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Colour clips (`#1e90ff`, `rgb(30, 144, 255)`, `hsl(…)`) show a swatch in the list and a large swatch with the hex and rgb values in the preview.
- A thin divider between pinned and recent clips.

### Fixed
- A database upgrade that fails half way is rolled back as a whole instead of leaving a transaction open (every multi-statement change now runs in one transaction).
- The Settings window no longer grows past the screen: it is as tall as its content up to the screen height, and the form scrolls.
- The last step of the welcome guide shows why "Open Pastu at login" cannot be switched on (a copy outside the Applications folder) instead of an unexplained dead switch.

## [0.5.0] - 2026-11-24

## [0.4.0] - 2026-11-23

### Added
- Paste queue: ⌥↩ collects the selected clip (up to 20) and moves to the next row, ⌘↩ pastes the queue one clip after another, with a new line, space, tab or nothing between text clips (Settings). Queued rows show their number, the footer has a Clear button, and the queue lives in memory only.
- Drag a clip out of the panel into another app: text drops as text, a picture as a PNG file.
- "Open in Preview" in a picture's right-click menu. The copy it opens is removed when Pastu starts and quits.

### Changed
- Picture thumbnails are decoded off the main thread, so opening the panel on a history full of screenshots no longer stalls (a retina screenshot took about 15 ms each on the main thread).

## [0.3.0] - 2026-11-23

### Added
- A three-step welcome guide on first launch (what Pastu does, letting it paste, open at login). Reopen it with "Show Welcome Guide…" in Settings.
- ⌘Z in the panel restores clips you deleted (up to 20, kept in memory only until the panel closes).
- A Settings window ("Settings…" in the menu bar menu) with the panel theme, "Open Pastu at login", a changeable global shortcut and history limits (clip count, age, size) and a list of ignored apps. More settings follow.

## [0.2.0] - 2026-11-23

### Added
- A redesigned panel with a Liquid Glass look on macOS 26 (a clean fallback look on macOS 15), rounded corners
  and a calmer preview with source, time and size.
- Mouse support: click a clip to select it, double click to paste it, right click for Paste, Copy, Pin, Delete and
  Ignore app. Clicking never takes focus away from the app you are pasting into.
- Pictures show as thumbnails in the list and a large preview, with their size.
- Links show their host and the full address in the preview; code-like clips use a monospaced font; search matches are highlighted and the
  preview jumps to the match in long clips.
- Keyboard: ⇧Tab filters backwards, ⌘↑/⌘↓ and Home/End jump to the first or last clip, Page Up/Down move by a page,
  and ⌘/ shows every shortcut.
- Clear messages for empty history, no results and filters with nothing in them.
- VoiceOver reads each clip and announces selection changes and notices.
- "About Pastu" in the menu bar menu.
- A Theme submenu in the menu bar menu: panel appearance (System, Light, Dark) and material (Liquid Glass,
  Frosted, Solid). Reduce Transparency in System Settings still wins.

### Changed
- Esc clears the search first and closes the panel on the second press.
- The panel always opens on "All" with the newest clip selected and an empty search.
- The menu bar menu follows macOS conventions: title-case items, a checkmark on "Pause Recording" instead of a
  renamed item, and ⌘⇧V shown next to "Show Pastu".
- Warnings in the menu use an icon and plain wording instead of raw error text.
- Long histories load more clips as you scroll.

### Fixed
- The Clear History confirmation could open behind other windows.
- Thumbnails no longer reload every time the panel opens.

## [0.1.1] - 2026-11-21

First public prerelease (early prototype). Not notarized; see the release notes for first-launch steps.

### Fixed
- A timing-sensitive test could fail on busy CI machines, which stopped the 0.1.0 release build.

## [0.1.0] - 2026-11-21

Tagged but never released: the release build stopped on the flaky test fixed in 0.1.1. Everything below ships in 0.1.1.

### Added
- Menu bar app that records copied text and keeps it in a local SQLite database.
- Global hotkey (⌘⇧V) that opens a floating, non-activating panel on the screen with the mouse.
- Two-pane panel with source app, relative time, preview and a hint footer.
- Substring search (FTS5 trigram index), case- and accent-insensitive; every word must match.
- Keyboard control: arrows, Return to paste, ⌘1–⌘9 quick paste, ⌘P pin, Esc close.
- Pinned clips: kept on top and never pruned.
- Auto-paste via the Accessibility permission, with a clear warning when it is missing.
- Privacy filter: concealed and transient pasteboard items are never read or stored; copies over 1 MB are skipped.
- Retention policy: 5,000 unpinned clips, 90 days and about 200 MB in total (estimated); pinned clips are never pruned.
- Pause/Resume recording and Clear history (keeps pinned) in the menu bar menu; the pause state survives a relaunch.
- Link detection and a type filter (All / Text / Links / Images) cycled with Tab.
- Pictures: copied images and screenshots are recorded (PNG, up to 10 MB), shown as thumbnails with a full
  preview and size, and pasted back with Return. Identical pictures merge; the privacy rules (concealed items,
  ignored apps) apply to pictures too. Database schema v3 (existing databases are upgraded in place).
- Ignored apps: ⌘I in the panel ignores the selected clip's source app (saved; managed from the menu bar menu).
- Delete the selected clip from the panel with ⌘⌫ (plain Backspace keeps editing the search text).
- Database folder `0700`, database files `0600`; old looser permissions are tightened on open.
- Local self-signed signing script so the Accessibility permission survives rebuilds.
- Database migrations (`PRAGMA user_version`) from older builds (pins, trigram index).
- MIT License.
- GitHub Actions CI, CONTRIBUTING, SECURITY and Code of Conduct.
- Temporary app icon, generated in code (`scripts/make-icon.swift`).
- `VERSION=x.y.z ./scripts/build-app.sh` sets the version of the built app.

### Changed
- Bundle identifier is `io.github.keremeersoy.Pastu`. A build from before this change is a different app to macOS:
  grant the Accessibility permission again after updating.
- Code reorganised for contributors (no behavior change): `ClipStore` split into extensions, panel views in
  `Sources/Pastu/Panel`, menu and paste logic moved out of `main.swift`, settings keys in one place.

### Fixed
- Copies made while a menu bar menu is open are no longer missed (pasteboard timer runs in common run loop modes).
- Text containing NUL characters is stored whole instead of being truncated (which could merge different clips).
- Deleted and pruned clips are overwritten in the database file (`secure_delete`).

[Unreleased]: https://github.com/keremeersoy/pastu/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/keremeersoy/pastu/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/keremeersoy/pastu/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/keremeersoy/pastu/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/keremeersoy/pastu/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/keremeersoy/pastu/releases/tag/v0.1.1
[0.1.0]: https://github.com/keremeersoy/pastu/tree/v0.1.0
