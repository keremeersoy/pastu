# Pastu

A fast, local-first, privacy-focused clipboard manager for macOS. Open source (MIT), free, no subscription,
no network access.

> **Status: early prototype (v0.1).** It captures text and pictures, searches them and pastes them back.
> Builds are **not signed or notarized** by Apple yet, so macOS warns on first launch (see
> [Installing](#installing-a-release)). Expect rough edges; bug reports are welcome.

<!-- SCREENSHOT PLACEHOLDER: replace with a real screenshot or GIF of the panel (light and dark mode).
     Automated window captures do not render the Liquid Glass shell, so none is included on purpose. -->
> 📷 **Screenshot coming soon.** No screenshot yet: automated captures cannot show the real Liquid Glass panel,
> and we would rather show nothing than something misleading.

## What works today

- Menu bar app that records copied **text and pictures** (polls the pasteboard every 0.5 s). Files are not captured yet.
  When a copy has both text and a picture (browsers, office apps), the text is kept.
- **⌘⇧V** opens a floating panel (on the screen with the mouse) without stealing focus from the app you are typing in.
  The shortcut is fixed for now. If another app already owns it, use "Show Pastu" in the menu bar menu.
- Type to search: substring match anywhere in the text (SQLite FTS5 trigram index), case- and accent-insensitive.
  Every word must match. Words shorter than 3 characters are matched without the index and are only
  case-insensitive for ASCII letters.
- ↑ ↓ to select, **Return** to paste, **⌘1–⌘9** to paste a row directly, **⌘P** to pin or unpin,
  **⌘⌫** to delete the selected clip from the history (pinned ones too), **⌘I** to ignore the selected clip's
  source app, **Esc** to close.
- Pinned clips stay on top and are never deleted automatically.
- Two-pane panel: list with source app and relative time, plus a preview of the selected clip.
- **Tab** cycles the type filter above the list: All, Text, Links, Images (a link is a clip that is only one
  http/https URL or a mailto address).
- Pictures (screenshots, copied images) get a thumbnail in the list and a full preview with their size; Return
  pastes the picture back. The same picture copied twice is merged into one clip.
- Duplicate copies are merged and move to the top.
- **Ignored apps**: press ⌘I on a clip and Pastu stops recording copies from its source app (and never reads
  their content). The list is saved, and "Ignored apps" in the menu bar menu lets you stop ignoring one. This is best
  effort: the source app is whichever app was frontmost when Pastu noticed the copy, so a very fast app switch
  can be misattributed. Clips already recorded are kept; delete them with ⌘⌫.
- Menu bar menu: **Pause recording** / **Resume recording** (the choice survives a relaunch; while paused Pastu does not
  even look at the pasteboard) and **Clear history…** (asks first; pinned clips are kept).
- History limits, whichever is hit first: 5,000 unpinned clips, 90 days, or about 200 MB in total (an estimate: the text
  size times 4.5 for the search index, plus picture sizes). Pinned clips are never deleted by these limits.
  Text over 1 MB and pictures over 10 MB are skipped.

Not there yet: a settings window (custom shortcut, launch at login, limits), file and color clips, rich-text paste,
paste queue, snippets, OCR, sync. See the [roadmap](#roadmap).

## Privacy and threat model

- Everything stays on your Mac, in `~/Library/Application Support/Pastu/history.sqlite`.
  No network calls, no telemetry, no analytics.
- Copies marked `org.nspasteboard.ConcealedType` or `TransientType` (what password managers set) are not stored,
  and their content is never even read: Pastu looks at the pasteboard's type list first.
- **History is stored in plaintext.** It is not encrypted yet. The folder is `0700` and the database files are `0600`
  (owner only), and deleted or pruned clips are overwritten in the database file. But anything running as your
  user, and anyone with access to your unlocked disk or a backup of it, can read the history.
  Apps that do not mark their secrets as concealed (some do not) will have them recorded.
  **Pictures such as screenshots are stored the same way** (unencrypted PNG in the same database) and can show
  passwords or personal data; delete a clip with ⌘⌫, or ignore the app it came from with ⌘I.
- Pastu records which app was frontmost when it noticed the copy. That is a best guess, not a guarantee.
- Pastu needs the Accessibility permission only to send ⌘V for you. It never reads other apps' windows or keystrokes.
- Found a security problem? See [SECURITY.md](SECURITY.md).

## Installing a release

Requires **macOS 15 (Sequoia) or later**. The prebuilt zip contains an **Apple Silicon (arm64)** build; on an
Intel Mac, build from source.

1. Download `Pastu-<version>.zip` from [Releases](https://github.com/keremeersoy/pastu/releases) and unzip it.
   Each release lists the zip's SHA-256 checksum; you can check it with `shasum -a 256 Pastu-<version>.zip`.
2. Move `Pastu.app` to `/Applications` and open it.
3. macOS says it cannot verify the developer. **Why:** Pastu is signed ad hoc, not with an Apple Developer ID,
   and is not notarized (the project has no paid Apple Developer account yet). To allow it **for this app only**:
   open **System Settings → Privacy & Security**, scroll down to the message about Pastu and click
   **Open Anyway**, then confirm. (On macOS 15 and later, Control-click → Open no longer skips this step.)
   Do not turn off Gatekeeper for your whole Mac.
4. Grant the **Accessibility** permission when asked (System Settings → Privacy & Security → Accessibility).
   Pastu uses it only to press ⌘V for you. Without it, the chosen clip is still put on the clipboard and you
   can press ⌘V yourself; the panel footer says when this is the case.

Because the signature is ad hoc, macOS may ask for the Accessibility permission again after you update Pastu.
If macOS 15.4+ is set to deny Pastu clipboard access, the menu bar menu shows a warning.

## Build from source

Requires macOS 15+ to run, and **Xcode 26+** (Swift 6, macOS 26 SDK) to build: the panel uses Liquid Glass on
macOS 26 and a material on macOS 15. Some tests open real windows, so run them in a logged-in GUI session.

```bash
swift test                # run the tests
./scripts/build-app.sh    # builds build/Pastu.app (see signing below)
open build/Pastu.app
```

`VERSION=0.1.0 ./scripts/build-app.sh` sets the version in the built app only (the release workflow uses this).

### Keeping the permission across rebuilds

An ad-hoc signature changes with every build, so macOS forgets the Accessibility permission each time.
Run this once to create a local, self-signed signing identity (in its own keychain; no Apple Developer
account needed). `build-app.sh` then signs with it and the permission survives rebuilds:

```bash
./scripts/setup-dev-signing.sh
```

If it is not set up, `build-app.sh` falls back to an ad-hoc signature.

What the script does: it creates a self-signed certificate "Pastu Local Dev" in a separate keychain,
`~/Library/Keychains/pastu-dev.keychain-db`, protected by the throwaway password `pastu-dev`. That password is
not a secret: the keychain holds only a local certificate that is valid for signing on your Mac alone, and it
exists so the scripts can unlock it without a prompt. Do not distribute builds signed with it; other Macs
will show the Gatekeeper warning for them. To undo it: `security delete-keychain ~/Library/Keychains/pastu-dev.keychain-db`.

## Known limitations and unverified areas

Being honest about what has and has not been checked:

- **Not signed or notarized**: Gatekeeper warning on first launch; Accessibility may need re-granting after updates.
- **History is unencrypted**, including pictures and screenshots (see the threat model above).
- **Looks**: the Liquid Glass panel (macOS 26) and Dark mode have not been visually verified, and there is no real
  screenshot yet.
- **Not tested by hand yet**: pasting a picture into another app with ⌘V, clicking the menu bar items (Pause, the
  Clear history alert, the Ignored apps submenu), ⌘⌫ and ⌘I on a real keyboard, multiple displays, full-screen
  apps and Spaces.
- **macOS 15.4+ clipboard privacy prompt**: how macOS asks about Pastu's clipboard access has not been observed.
- **Build**: only built against the macOS 27.2 SDK so far; building with exactly the macOS 26 SDK has not been tried.
- **Performance**: panel-open latency has not been measured.
- The source app of a clip is a best guess (the frontmost app when the copy was noticed).
- Search terms shorter than 3 characters are case-insensitive for ASCII letters only.
- The app icon is a temporary one drawn in code (`scripts/make-icon.swift`); a designed icon is welcome.

## Project layout

```
Sources/PastuCore/   UI-independent logic: clipboard monitor, privacy filter, SQLite store, list model, clip kinds
Sources/Pastu/       Menu bar app shell: app delegate, status menu, paste coordinator, NSPanel, global hotkey
Sources/Pastu/Panel/ SwiftUI views of the panel (list rows, preview, filter bar, footer)
Tests/               Swift Testing tests (PastuCoreTests: logic; PastuTests: panel/key handling with real windows)
Resources/           Info.plist and the app icon
scripts/             build-app.sh, setup-dev-signing.sh, make-icon.swift
docs/                Market research, product roadmap, naming (Turkish; see docs/README.md)
```

## Roadmap

See [docs/02-urun-ve-yol-haritasi.md](docs/02-urun-ve-yol-haritasi.md) (in Turkish). Next up: a settings window
(custom shortcut, ignored apps, launch at login), file and color clips, then paste queue, snippets and OCR.
Issues labelled [`good first issue`](https://github.com/keremeersoy/pastu/labels/good%20first%20issue) are a good
place to start.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE), copyright Pastu contributors.
