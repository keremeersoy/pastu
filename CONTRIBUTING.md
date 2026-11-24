# Contributing to Pastu

Thanks for helping! Pastu is small on purpose: keep changes focused.

## Ground rules

- **Privacy first.** No network calls, telemetry or analytics, ever.
- **No new dependencies** (packages, linters, formatters, build tools) without agreeing on it in an issue first.
  Pastu builds with nothing but the Swift toolchain and the macOS SDK.
- **Tests first.** Every behavior change comes with a test, especially in the clipboard filter and the
  database layer. Write the test, watch it fail for the right reason, then make it pass.
- **Never log clipboard content**: no `NSLog`/`print` of copied text, or of errors that embed it.
- Tests must not write to `UserDefaults` or anywhere outside a temporary directory. Use `InMemorySettings`
  for settings (a `UserDefaults` suite leaves a `.plist` in `~/Library/Preferences`).
- Keep code, comments and commit messages in English.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). Security problems: see [SECURITY.md](SECURITY.md)
(please report them privately, not as issues).

## Setup

Requires macOS 15+ and **Xcode 26+** (the macOS 26 SDK is needed to compile).

```bash
git clone https://github.com/keremeersoy/pastu.git && cd pastu
swift test
./scripts/build-app.sh && open build/Pastu.app
```

### Keeping the Accessibility permission across rebuilds

An ad-hoc signature changes with every build, so macOS forgets the Accessibility permission each time.
Run `./scripts/setup-dev-signing.sh` once: it creates a self-signed certificate "Pastu Local Dev" in its own keychain
(`~/Library/Keychains/pastu-dev.keychain-db`), and `build-app.sh` then signs with it. No Apple Developer account
is needed. The keychain password `pastu-dev` is deliberately not a secret: the certificate only works on your Mac
and the scripts must unlock it without a prompt. Never distribute builds signed with it. To undo it:
`security delete-keychain ~/Library/Keychains/pastu-dev.keychain-db`.

`VERSION=0.1.0 ./scripts/build-app.sh` sets the version of the built app only (the release workflow uses it).

### Releasing

Pushing a tag `vX.Y.Z` (after bumping `Resources/Info.plist` and adding a `## [X.Y.Z]` section to `CHANGELOG.md`)
runs the release workflow (which refuses a changelog section with no entries): it tests, builds, publishes the zip, and then commits the new version and SHA-256 to
`Casks/pastu.rb` on `main`. Nothing to edit by hand; `scripts/update-cask.sh` is the same step for a manual fix.

## Project layout

```
Sources/PastuCore/        UI-free logic, unit-tested
  Storage/                ClipStore (SQLite + FTS5): schema and migrations, queries, retention, undo, picture text
  Clipboard/              pasteboard capture, privacy filter, recording state, ignored apps
  Panel/                  what the panel shows: list model, search highlighting, kinds, colours, paste queue
  Settings/               every setting and its stored form: theme, shortcut, limits, login item, welcome guide
  Pictures/               reading the text in pictures (the recogniser is a protocol; Vision lives in the app)
Sources/Pastu/            thin AppKit/SwiftUI shell
  App/                    main, app delegate (wiring), AppSettings (all settings in one place), paths
  Menu/                   the menu bar item and its menu
  Panel/                  the NSPanel, its SwiftUI views, thumbnails and previews
  Paste/                  pasting into other apps, the global hotkey
  Settings/               the Settings window and the welcome guide
  System/                 small wrappers around macOS: window focus, app lookup, Vision, System Settings
Tests/PastuCoreTests/     mirrors PastuCore (fast, no windows)
Tests/PastuTests/         mirrors Pastu (opens real windows; needs a GUI session); Support/ has shared helpers
Casks/pastu.rb            the Homebrew cask, updated by the release workflow
scripts/                  build, icon, signing and measurement scripts
docs/                     design documents and performance numbers
```

New logic goes in `PastuCore` with a test; the shell only draws and wires. A new setting is a small observable
class in `PastuCore/Settings` that takes a `SettingsStore`, a key in `DefaultsKeys` (pinned by a test), a field in
`AppSettings`, and a section in the Settings window.

## Tests

```bash
swift test                              # everything
swift test --filter PastuCoreTests      # logic only (fast, no windows)
swift test --filter PastuTests          # app shell: opens real AppKit windows
```

`PastuTests` open real windows and send key events, so run them in a **logged-in GUI session** (not over SSH
or with the screen locked).

## Where things go

- Logic that does not need a window goes in `Sources/PastuCore` (and is unit-tested).
- AppKit/SwiftUI shell code goes in `Sources/Pastu` (panel views in `Sources/Pastu/Panel`). Keep it thin.
- Settings keys live in `DefaultsKeys`; never rename an existing key (users would lose that setting).

## Pull requests

1. `swift test` passes and `./scripts/build-app.sh` builds.
2. Behavior changes come with a test that you saw failing first.
3. Describe what changed and why; link the issue if there is one.
4. User-visible change: update the README and add a line under `[Unreleased]` in `CHANGELOG.md`.
5. Keep the PR small. One idea per PR is easier to review.

New here? Look for issues labelled `good first issue`.

## License

Pastu is released under the [MIT License](LICENSE). By contributing, you agree that your contribution is
licensed under the same terms.
