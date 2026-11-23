#!/bin/bash
# Points the Homebrew cask at a release: ./scripts/update-cask.sh VERSION SHA256 [CASK_FILE]
# The release workflow runs this after it publishes the zip, so the cask never has to be edited by hand.
set -euo pipefail

VERSION="${1:?usage: update-cask.sh VERSION SHA256 [CASK_FILE]}"
SHA256="${2:?usage: update-cask.sh VERSION SHA256 [CASK_FILE]}"
CASK="${3:-$(cd "$(dirname "$0")/.." && pwd)/Casks/pastu.rb}"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "VERSION must look like 1.2.3, got: $VERSION" >&2; exit 1; }
[[ "$SHA256" =~ ^[0-9a-f]{64}$ ]] || { echo "SHA256 must be 64 lowercase hex characters, got: $SHA256" >&2; exit 1; }

# Exactly one version line and one sha256 line are expected; anything else means the file changed shape.
[ "$(grep -c '^  version "' "$CASK")" -eq 1 ] && [ "$(grep -c '^  sha256 "' "$CASK")" -eq 1 ] \
  || { echo "$CASK does not have exactly one version and one sha256 line" >&2; exit 1; }

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
sed -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA256\"/" "$CASK" > "$TMP"
cat "$TMP" > "$CASK"
