#!/usr/bin/env bash
# Deprecated: Docker+scp demo deploy. Use deploy/deploy.sh.
exec "$(cd "$(dirname "$0")" && pwd)/deploy/deploy.sh" "$@"
