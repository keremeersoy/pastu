#!/bin/bash
# Builds build/Pastu.app from the SwiftPM executable and signs it (local dev identity if present, else ad-hoc).
#
# Optional: VERSION=0.1.0 ./scripts/build-app.sh sets CFBundleShortVersionString in the built bundle only;
# Resources/Info.plist is never modified (the release workflow passes the tag's version this way).
set -euo pipefail
cd "$(dirname "$0")/.."

# Validate before touching anything, so a bad value never leaves a half-built bundle behind.
if [ -n "${VERSION:-}" ] && ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
    echo "VERSION must look like 1.2.3 or 1.2.3-beta.1, got: $VERSION" >&2
    exit 1
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Pastu"

APP="build/Pastu.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/Pastu"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

if [ -n "${VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
    echo "Version set to $VERSION in the built bundle"
fi

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
