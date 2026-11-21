# Changelog

All notable changes to Pastu are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
will follow [Semantic Versioning](https://semver.org/) once it has a first release.

## [Unreleased]

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
- Link detection and a type filter (All / Text / Links) cycled with Tab.
- Ignored apps: ⌘I in the panel ignores the selected clip's source app (saved; managed from the menu bar menu).
- Delete the selected clip from the panel with ⌘⌫ (plain Backspace keeps editing the search text).
- Database folder `0700`, database files `0600`; old looser permissions are tightened on open.
- Local self-signed signing script so the Accessibility permission survives rebuilds.
- Database migrations (`PRAGMA user_version`) from older builds (pins, trigram index).
- GitHub Actions CI, CONTRIBUTING, SECURITY and Code of Conduct.

### Fixed
- Copies made while a menu bar menu is open are no longer missed (pasteboard timer runs in common run loop modes).
- Text containing NUL characters is stored whole instead of being truncated (which could merge different clips).
- Deleted and pruned clips are overwritten in the database file (`secure_delete`).
