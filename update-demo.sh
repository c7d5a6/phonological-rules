#!/bin/bash
set -euo pipefail

CURRENT_DIR="$(pwd)"
SERV_DIR="$CURRENT_DIR"
IMAGE_TAG="phonological-rules-build:latest"
CONTAINER_NAME="phonological-rules-build-tmp"

# Build inside Docker (Dockerfile runs zig build).
docker build -t "$IMAGE_TAG" -f "$CURRENT_DIR/Dockerfile" "$CURRENT_DIR"

# Ensure old temp container does not interfere.
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker create --name "$CONTAINER_NAME" "$IMAGE_TAG" >/dev/null

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Copy built artifacts from container.
mkdir -p "$SERV_DIR/libs" "$SERV_DIR/zig-out/bin" "$SERV_DIR/zig-out/lib"
rm -f "$SERV_DIR/zig-out/bin/phonological-rules-backend" \
  "$SERV_DIR/zig-out/lib/libph_lib.so.0.1.0" \
  "$SERV_DIR/zig-out/lib/libfacil.io.so"
docker cp "$CONTAINER_NAME:/app/zig-out/bin/phonological-rules-backend" "$SERV_DIR/zig-out/bin/phonological-rules-backend"
docker cp "$CONTAINER_NAME:/app/zig-out/lib/libph_lib.so.0.1.0" "$SERV_DIR/zig-out/lib/libph_lib.so.0.1.0"
docker cp "$CONTAINER_NAME:/app/zig-out/lib/libfacil.io.so" "$SERV_DIR/zig-out/lib/libfacil.io.so"

# Prepare deploy libs and symlinks.
cp -f "$SERV_DIR/zig-out/lib/libph_lib.so.0.1.0" "$SERV_DIR/libs/"
cp -f "$SERV_DIR/zig-out/lib/libfacil.io.so" "$SERV_DIR/libs/"
ln -sf libph_lib.so.0.1.0 "$SERV_DIR/libs/libph_lib.so.0"
ln -sf libph_lib.so.0 "$SERV_DIR/libs/libph_lib.so"

# Deploy backend and libs.
ssh foundry@foundry.owlbeardm.com "mkdir -p ~/ph-lib/libs && rm -f ~/ph-lib/phonological-rules-backend ~/ph-lib/libs/libph_lib.so.0.1.0 ~/ph-lib/libs/libfacil.io.so"
scp "$SERV_DIR/zig-out/bin/phonological-rules-backend" foundry@foundry.owlbeardm.com:~/ph-lib/
scp "$SERV_DIR/libs/libph_lib.so.0.1.0" foundry@foundry.owlbeardm.com:~/ph-lib/libs/
scp "$SERV_DIR/libs/libfacil.io.so" foundry@foundry.owlbeardm.com:~/ph-lib/libs/
ssh foundry@foundry.owlbeardm.com "ln -sf libph_lib.so.0.1.0 ~/ph-lib/libs/libph_lib.so.0 && ln -sf libph_lib.so.0 ~/ph-lib/libs/libph_lib.so"

ssh foundry@foundry.owlbeardm.com 'PM2_BIN="/home/foundry/.nvm/versions/node/v14.19.2/bin/pm2"; if [ -x "$PM2_BIN" ]; then "$PM2_BIN" restart 7; else source ~/.profile >/dev/null 2>&1 || true; command -v pm2 >/dev/null 2>&1 && pm2 restart 7; fi'
