#!/usr/bin/env bash
# Cross-compile the HTTP backend + shared libs and rsync them to foundry,
# then restart via PM2.
#
# Working tree must be clean. Remote logs are never overwritten.
#
# Host:  foundry@foundry.owlbeardm.com:/home/foundry/ph-lib
# Nginx: api-ph.foundry.owlbeardm.com → 127.0.0.1:3003
#
# Env overrides:
#   PH_LIB_DEPLOY_HOST    default foundry@foundry.owlbeardm.com
#   PH_LIB_DEPLOY_DIR     default /home/foundry/ph-lib
#   PH_LIB_ZIG_TARGET     default: linux-gnu from remote uname -m + glibc
#   PH_LIB_OPTIMIZE       default ReleaseFast
#   PH_LIB_PM2_APP        default ph-lib
#   PH_LIB_PM2_LEGACY_ID  default 7 (old update-demo.sh process)
set -euo pipefail

DEPLOY_HOST="${PH_LIB_DEPLOY_HOST:-foundry@foundry.owlbeardm.com}"
REMOTE_DIR="${PH_LIB_DEPLOY_DIR:-/home/foundry/ph-lib}"
APP_NAME="${PH_LIB_PM2_APP:-ph-lib}"
LEGACY_PM2_ID="${PH_LIB_PM2_LEGACY_ID:-7}"
OPTIMIZE="${PH_LIB_OPTIMIZE:-ReleaseFast}"
BIN_NAME="phonological-rules-backend"

REPO="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(git -C "$REPO" rev-parse --show-toplevel)"
cd "$REPO"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: uncommitted content. Commit or stash before deploying." >&2
  git status --porcelain >&2
  exit 1
fi

for cmd in zig rsync ssh; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: $cmd is required." >&2
    exit 1
  fi
done

remote() {
  ssh "$DEPLOY_HOST" "$@"
}

echo "==> Probe ${DEPLOY_HOST}"
REMOTE_UNAME="$(remote uname -m)"
if [[ -n "${PH_LIB_ZIG_TARGET:-}" ]]; then
  ZIG_TARGET="$PH_LIB_ZIG_TARGET"
else
  case "$REMOTE_UNAME" in
    x86_64) ZIG_ARCH=x86_64 ;;
    aarch64|arm64) ZIG_ARCH=aarch64 ;;
    *)
      echo "error: unsupported remote arch ${REMOTE_UNAME} (set PH_LIB_ZIG_TARGET)." >&2
      exit 1
      ;;
  esac
  GLIBC_VER="$(remote getconf GNU_LIBC_VERSION | awk '{print $2}')"
  if [[ -z "$GLIBC_VER" ]]; then
    echo "error: could not read remote glibc (set PH_LIB_ZIG_TARGET)." >&2
    exit 1
  fi
  ZIG_TARGET="${ZIG_ARCH}-linux-gnu.${GLIBC_VER}"
fi

GIT_HEAD="$(git rev-parse --short HEAD)"
GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "==> Build ${ZIG_TARGET} ${OPTIMIZE} (${GIT_BRANCH} ${GIT_HEAD})"

STAGE="$(mktemp -d)"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

zig build \
  -Doptimize="$OPTIMIZE" \
  -Dtarget="$ZIG_TARGET" \
  --prefix "$STAGE/prefix"

PREFIX="$STAGE/prefix"
if [[ ! -x "$PREFIX/bin/$BIN_NAME" ]]; then
  echo "error: missing $PREFIX/bin/$BIN_NAME" >&2
  exit 1
fi

mkdir -p "$STAGE/root/libs"
cp -a "$PREFIX/bin/$BIN_NAME" "$STAGE/root/$BIN_NAME"
# Shared objects + SONAME symlinks only (skip static .a).
find "$PREFIX/lib" -maxdepth 1 \( -name '*.so' -o -name '*.so.*' \) -exec cp -a {} "$STAGE/root/libs/" \;
cp "$REPO/deploy/run.sh" "$STAGE/root/run.sh"
cp "$REPO/deploy/run.sh" "$STAGE/root/start.sh"
cp "$REPO/deploy/ecosystem.config.cjs" "$STAGE/root/ecosystem.config.cjs"
chmod +x "$STAGE/root/$BIN_NAME" "$STAGE/root/run.sh" "$STAGE/root/start.sh"

shopt -s nullglob
ph_libs=( "$STAGE/root/libs"/libph_lib.so* )
shopt -u nullglob
if (( ${#ph_libs[@]} == 0 )); then
  echo "error: no libph_lib.so* under $PREFIX/lib" >&2
  ls -la "$PREFIX/lib" >&2 || true
  exit 1
fi

echo "==> Ensure remote dirs"
remote "mkdir -p $(printf '%q' "$REMOTE_DIR/libs") $(printf '%q' "$REMOTE_DIR/logs")"

# Libs first so a crash-restart of the new binary can resolve SONAME.
echo "==> Rsync libs/ (versioned .so + symlinks)"
rsync -az --delete --delay-updates "$STAGE/root/libs/" "${DEPLOY_HOST}:${REMOTE_DIR}/libs/"

echo "==> Rsync binary via .next (avoids ETXTBSY on a running executable)"
rsync -az "$STAGE/root/$BIN_NAME" "${DEPLOY_HOST}:${REMOTE_DIR}/${BIN_NAME}.next"
remote "mv -f $(printf '%q' "$REMOTE_DIR/${BIN_NAME}.next") $(printf '%q' "$REMOTE_DIR/$BIN_NAME") && chmod +x $(printf '%q' "$REMOTE_DIR/$BIN_NAME")"

echo "==> Rsync run scripts (does not touch logs/)"
rsync -az \
  "$STAGE/root/run.sh" \
  "$STAGE/root/start.sh" \
  "$STAGE/root/ecosystem.config.cjs" \
  "${DEPLOY_HOST}:${REMOTE_DIR}/"
remote "chmod +x $(printf '%q' "$REMOTE_DIR/run.sh") $(printf '%q' "$REMOTE_DIR/start.sh")"

echo "==> PM2 restart ${APP_NAME}"
remote "REMOTE_DIR=$(printf '%q' "$REMOTE_DIR") APP_NAME=$(printf '%q' "$APP_NAME") LEGACY_PM2_ID=$(printf '%q' "$LEGACY_PM2_ID") bash -s" <<'REMOTE'
set -euo pipefail
export PM2_HOME="${PM2_HOME:-$HOME/.pm2}"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
fi
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"
# Old update-demo.sh used a pinned nvm pm2.
if [[ -x "${HOME}/.nvm/versions/node/v14.19.2/bin/pm2" ]]; then
  export PATH="${HOME}/.nvm/versions/node/v14.19.2/bin:${PATH}"
fi
if ! command -v pm2 >/dev/null 2>&1; then
  echo "error: pm2 not found on remote (PATH=${PATH})" >&2
  exit 1
fi
cd "$REMOTE_DIR"

legacy_is_this_app() {
  pm2 describe "$LEGACY_PM2_ID" >/dev/null 2>&1 || return 1
  pm2 show "$LEGACY_PM2_ID" | grep -F "$REMOTE_DIR" >/dev/null 2>&1
}

if pm2 describe "$APP_NAME" >/dev/null 2>&1; then
  pm2 restart "$APP_NAME" --update-env
elif legacy_is_this_app; then
  echo "==> Replace PM2 id ${LEGACY_PM2_ID} with named app ${APP_NAME}"
  pm2 delete "$LEGACY_PM2_ID"
  pm2 start ecosystem.config.cjs
  pm2 save
else
  pm2 start ecosystem.config.cjs
  pm2 save
fi
pm2 status "$APP_NAME"
sleep 1
if command -v curl >/dev/null 2>&1; then
  curl -sf --max-time 5 http://127.0.0.1:3003/api/version || {
    echo "error: health check failed" >&2
    pm2 logs "$APP_NAME" --lines 40 --nostream >&2 || true
    exit 1
  }
  echo
fi
REMOTE

echo
echo "Done. ${APP_NAME} @ ${DEPLOY_HOST}:${REMOTE_DIR} (http://127.0.0.1:3003)"
echo "  Public API: https://api-ph.foundry.owlbeardm.com"
echo "  Version:    GET /api/version  (${GIT_BRANCH} ${GIT_HEAD})"
