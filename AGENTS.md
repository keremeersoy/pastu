# Notes for AI-assisted contributions

This file is for AI coding assistants (and the humans using them). The rules are the same as in
[CONTRIBUTING.md](CONTRIBUTING.md); this is the short version.

## Project

Pastu is a local-first macOS clipboard manager: Swift 6, SwiftUI + AppKit (`NSPanel`), SQLite with FTS5,
Swift Package Manager, **zero dependencies**. macOS 15+; building needs Xcode 26+ (macOS 26 SDK).

- `Sources/PastuCore`: UI-independent logic, unit-tested, in `Storage`, `Clipboard`, `Panel`, `Settings`, `Pictures`.
- `Sources/Pastu`: thin AppKit/SwiftUI shell, in `App`, `Menu`, `Panel`, `Paste`, `Settings`, `System`.
- `Tests/PastuCoreTests` (fast) and `Tests/PastuTests` (open real windows; need a GUI session) mirror those folders.
- The full tree, and how to add a setting, is in [CONTRIBUTING.md](CONTRIBUTING.md#project-layout).

## Rules

- **Tests first.** Write a failing test, see it fail for the right reason, then implement. Never delete,
  skip or weaken a test to get green.
- **Green before commit.** `swift test` must exit 0, and you must read the result lines, before every commit.
- **Small commits** with clear English messages; one idea each.
- **No new dependencies** (packages, linters, formatters, tools) without an agreed issue.
- **Privacy:** no network calls, telemetry or analytics. Never log clipboard content.
- **Tests stay sandboxed:** no `UserDefaults` (use `InMemorySettings`), no files outside a temporary directory,
  never the real history in `~/Library/Application Support/Pastu/`.
- Never rename keys in `DefaultsKeys`, and add a migration step (never edit an old one) when the database
  schema changes.
- Code, comments, commits and docs in English (the existing `docs/` files are Turkish).

## Commands

```bash
swift test                          # all tests
swift test --filter PastuCoreTests  # logic only
./scripts/build-app.sh              # build/Pastu.app
```
