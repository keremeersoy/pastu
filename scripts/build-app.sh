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

# Ad-hoc signature ("-"): no Apple Developer account needed.
codesign --force --sign - "$APP"
codesign --verify --verbose "$APP"
echo "Built $APP"
