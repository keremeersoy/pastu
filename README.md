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

Because the app is ad-hoc signed (no Apple Developer account yet), macOS may treat every rebuild as a new
app and ask for the permission again. If pasting stops working after a rebuild, remove Pastu from the
Accessibility list and add it again.

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
