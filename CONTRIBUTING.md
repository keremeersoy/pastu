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

Run `./scripts/setup-dev-signing.sh` once if you rebuild often: it keeps the Accessibility permission across
rebuilds (see the README).

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
