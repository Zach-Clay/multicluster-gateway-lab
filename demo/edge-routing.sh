#!/usr/bin/env bash
# Send traffic through the host-published edge Envoy, from a curl container on the kind network.
source "$(dirname "$0")/../scripts/lib.sh"
require docker
EDGE_CONTAINER="${EDGE_CONTAINER:-edge-envoy}"
docker inspect "$EDGE_CONTAINER" >/dev/null 2>&1 || die "edge Envoy is not running; run 'make edge-up'"

curl_edge() { docker run --rm --network kind curlimages/curl:8.11.1 -s "$@"; }

for path in /api/orders /api/users /api/orders/healthz /nope; do
  echo "${bold}GET http://localhost:8080$path${rst}"
  curl_edge -w "${dim}HTTP %{http_code}${rst}\n" "http://$EDGE_CONTAINER:8080$path"
  echo
done
