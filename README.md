# Pastu

A fast, local-first, privacy-focused clipboard manager for macOS. Open source, free, no subscription.

> **Status: early prototype.** It captures, searches and pastes text. There is no release yet.

## What works today

- Menu bar app that records copied **text** (polls the pasteboard every 0.5 s).
- **⌘⇧V** opens a floating panel without stealing focus from the app you are typing in.
- Type to search (SQLite FTS5, prefix match, case/diacritic-insensitive).
- ↑ ↓ to select, **Return** to paste, **⌘1–⌘9** to paste a row directly, **Esc** to close.
- Duplicate copies are merged and move to the top.

## Privacy

- Everything stays on your Mac, in `~/Library/Application Support/Pastu/history.sqlite`.
- No network calls, no telemetry, no analytics.
- Copies marked `org.nspasteboard.ConcealedType` or `TransientType` (what password managers set) are never stored.

## Build from source

Requires macOS 15+ and Xcode 26+ (Swift 6).

```bash
swift test                # run the tests
./scripts/build-app.sh    # builds build/Pastu.app (ad-hoc signed)
open build/Pastu.app
```

Pasting into other apps needs the **Accessibility** permission
(System Settings → Privacy & Security → Accessibility). Without it, the selected text is still
placed on your clipboard and you can press ⌘V yourself.

### Keeping the permission across rebuilds

An ad-hoc signature changes with every build, so macOS forgets the Accessibility permission each time.
Run this once to create a local, self-signed signing identity (in its own keychain; no Apple Developer
account needed). `build-app.sh` then signs with it and the permission survives rebuilds:

```bash
./scripts/setup-dev-signing.sh
```

If it is not set up, `build-app.sh` falls back to an ad-hoc signature.

## Project layout

```
Sources/PastuCore/   UI-independent logic: clipboard monitor, privacy filter, SQLite store, list model
Sources/Pastu/       Menu bar app shell: NSPanel, SwiftUI view, global hotkey, paste sender
Tests/               Swift Testing tests for PastuCore
scripts/             build-app.sh
docs/                Market research, product roadmap, naming (Turkish)
```

## Roadmap

See [docs/02-urun-ve-yol-haritasi.md](docs/02-urun-ve-yol-haritasi.md) (in Turkish). Next up: images, links and
file types, pins, source-app info, privacy indicator.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Not decided yet (MIT or GPL).
