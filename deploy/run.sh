#!/usr/bin/env bash
# Load libs from ./libs (and $ORIGIN/libs via rpath) and exec the HTTP backend.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
export LD_LIBRARY_PATH="${ROOT}/libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$ROOT/phonological-rules-backend"
