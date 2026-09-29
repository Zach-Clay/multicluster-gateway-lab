#!/usr/bin/env bash
# Remove only the lab-owned edge Envoy container. The two kind clusters remain intact.
source "$(dirname "$0")/lib.sh"
require docker
EDGE_CONTAINER="${EDGE_CONTAINER:-edge-envoy}"

if docker inspect "$EDGE_CONTAINER" >/dev/null 2>&1; then
  docker rm -f "$EDGE_CONTAINER" >/dev/null
  ok "edge Envoy removed"
else
  ok "no edge Envoy container to remove"
fi
