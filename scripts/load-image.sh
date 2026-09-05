#!/usr/bin/env bash
# kind nodes cannot pull local images, so side-load the image into the cluster's nodes.
source "$(dirname "$0")/lib.sh"
require kind docker
IMAGE="${IMAGE:-mcgl/echo-api:dev}"
log "loading $IMAGE into kind nodes"
kind load docker-image "$IMAGE" --name "$CLUSTER" >/dev/null
ok "image loaded"
