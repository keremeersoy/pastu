# Changelog

All notable changes to Pastu are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-11-21

First public prerelease (early prototype). Not notarized; see the release notes for first-launch steps.

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
