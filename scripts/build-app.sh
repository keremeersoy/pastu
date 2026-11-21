#!/bin/bash
# Builds build/Pastu.app from the SwiftPM executable and ad-hoc signs it.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Pastu"

APP="build/Pastu.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Pastu"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Prefer the local dev identity (scripts/setup-dev-signing.sh): it keeps the code identity stable across
# rebuilds, so macOS does not forget the Accessibility permission. Fall back to an ad-hoc signature,
# which changes with every build.
KC="$HOME/Library/Keychains/pastu-dev.keychain-db"
IDENTITY=""
if [ -f "$KC" ] && security unlock-keychain -p "pastu-dev" "$KC" 2>/dev/null; then
    IDENTITY="$(security find-identity -p codesigning "$KC" | awk '/Pastu Local Dev/ {print $2; exit}')"
fi

if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" --keychain "$KC" "$APP"
    echo "Signed with local dev identity ($IDENTITY)"
else
    codesign --force --sign - "$APP"
    echo "Signed ad-hoc (run scripts/setup-dev-signing.sh to keep permissions across rebuilds)"
fi
codesign --verify --verbose "$APP"
echo "Built $APP"
