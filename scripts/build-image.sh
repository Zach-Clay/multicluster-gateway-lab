#!/usr/bin/env bash
# Build the echo-api image once; scripts/load-image.sh copies it into each kind cluster.
source "$(dirname "$0")/lib.sh"
require docker
IMAGE="${IMAGE:-mcgl/echo-api:dev}"
log "building $IMAGE"
docker build -q -t "$IMAGE" "$ROOT/apps/echo-api" >/dev/null
ok "built $IMAGE"
