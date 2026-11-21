# Contributing to Pastu

Thanks for helping! Pastu is small on purpose: keep changes focused.

## Ground rules

- **Privacy first.** No network calls, telemetry or analytics, ever.
- **No new dependencies** without discussing it in an issue first.
- **Test-first.** Every behavior change comes with a test, especially in the clipboard filter and the
  database layer. Write the test, watch it fail for the right reason, then make it pass.
- Keep code, comments and commit messages in English.

## Setup

```bash
git clone <repo-url> && cd pastu
swift test
./scripts/build-app.sh && open build/Pastu.app
```

Requires macOS 15+ and Xcode 26+.

## Where things go

- Logic that does not need a window goes in `Sources/PastuCore` (and is unit-tested).
- AppKit/SwiftUI shell code goes in `Sources/Pastu`. Keep it thin.

## Pull requests

1. Make sure `swift test` passes and the app builds.
2. Describe what changed and why; link the issue if there is one.
3. Keep the PR small. One idea per PR is easier to review.
