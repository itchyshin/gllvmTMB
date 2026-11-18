#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$here/watchdog.py" "$@"
