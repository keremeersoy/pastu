#!/bin/bash
# Checks scripts/update-cask.sh on a copy of the cask. Run by CI; no network needed.
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp Casks/pastu.rb "$TMP/pastu.rb"
SHA="$(printf 'x' | shasum -a 256 | cut -d' ' -f1)"

./scripts/update-cask.sh 9.8.7 "$SHA" "$TMP/pastu.rb"
grep -q "^  version \"9.8.7\"$" "$TMP/pastu.rb" || { echo "version not updated"; exit 1; }
grep -q "^  sha256 \"$SHA\"$" "$TMP/pastu.rb" || { echo "sha256 not updated"; exit 1; }
# Only those two lines may change.
[ "$(diff Casks/pastu.rb "$TMP/pastu.rb" | grep -c '^>')" -eq 2 ] || { echo "more than two lines changed"; exit 1; }
ruby -c "$TMP/pastu.rb" >/dev/null

# Bad input is refused and leaves the file alone.
cp "$TMP/pastu.rb" "$TMP/before.rb"
for bad in "1.2" "v1.2.3" "1.2.3-beta"; do
  if ./scripts/update-cask.sh "$bad" "$SHA" "$TMP/pastu.rb" 2>/dev/null; then echo "accepted version $bad"; exit 1; fi
done
if ./scripts/update-cask.sh 1.2.3 "NOTAHASH" "$TMP/pastu.rb" 2>/dev/null; then echo "accepted a bad sha256"; exit 1; fi
cmp -s "$TMP/pastu.rb" "$TMP/before.rb" || { echo "a refused update changed the file"; exit 1; }
echo "update-cask: ok"
