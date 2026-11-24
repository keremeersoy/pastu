#!/bin/bash
# Prints the memory a running Pastu uses: resident set size and physical footprint, in MB.
# Usage: ./scripts/measure-memory.sh [path-to-Pastu.app]   (default: any running Pastu)
# Reads only numbers about the process. Let the app sit idle for a minute first, with the panel closed.
set -euo pipefail

APP="${1:-}"
if [ -n "$APP" ]; then
  PID="$(pgrep -f "$APP/Contents/MacOS/Pastu" | head -1 || true)"
else
  PID="$(pgrep -f 'Pastu.app/Contents/MacOS/Pastu' | head -1 || true)"
fi
[ -n "$PID" ] || { echo "Pastu is not running" >&2; exit 1; }

RSS_KB="$(ps -o rss= -p "$PID" | tr -d ' ')"
FOOTPRINT="$(footprint -p "$PID" 2>/dev/null | grep -o 'Footprint: [0-9.]* [KMG]B' | head -1 | cut -d' ' -f2-)"
echo "pid $PID"
echo "resident set size: $(( RSS_KB / 1024 )) MB"
echo "physical footprint: ${FOOTPRINT:-unknown}"
echo "macOS $(sw_vers -productVersion), $(sysctl -n machdep.cpu.brand_string)"
