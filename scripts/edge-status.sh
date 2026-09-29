#!/usr/bin/env bash
# Show the edge container and its view of upstream health from Envoy's admin interface.
source "$(dirname "$0")/lib.sh"
require docker
EDGE_CONTAINER="${EDGE_CONTAINER:-edge-envoy}"

docker inspect "$EDGE_CONTAINER" >/dev/null 2>&1 || die "edge Envoy is not running; run 'make edge-up'"
echo "${bold}== edge Envoy${rst}"
docker ps --filter "name=^/${EDGE_CONTAINER}$" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo "${bold}== upstream health${rst}"
docker run --rm --network kind curlimages/curl:8.11.1 -fsS http://"$EDGE_CONTAINER":9901/clusters \
  | grep -E '^(us-east|us-west).*::(health_flags|membership_healthy|membership_total)::' || true
