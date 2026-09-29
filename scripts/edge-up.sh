#!/usr/bin/env bash
# Render the current cluster Gateway addresses into the edge Envoy config and start it on the kind network.
source "$(dirname "$0")/lib.sh"
require docker kubectl sed
ENVOY_IMAGE="${ENVOY_IMAGE:-envoyproxy/envoy:v1.32.3}"
EDGE_CONTAINER="${EDGE_CONTAINER:-edge-envoy}"
EDGE_CONFIG="${EDGE_CONFIG:-/tmp/mcgl-edge-envoy.yaml}"

gateway_address_for() {
  local cluster=$1
  kubectl --context "kind-$cluster" get gateway cluster-gateway -n ingress \
    -o jsonpath='{.status.addresses[0].value}' 2>/dev/null
}

east_ip="$(gateway_address_for us-east)"
west_ip="$(gateway_address_for us-west)"
[[ -n "$east_ip" ]] || die "us-east Gateway has no address; run 'make up' first"
[[ -n "$west_ip" ]] || die "us-west Gateway has no address; run 'make up CLUSTER=us-west' first"

sed \
  -e "s/\${US_EAST_GATEWAY_IP}/$east_ip/g" \
  -e "s/\${US_WEST_GATEWAY_IP}/$west_ip/g" \
  "$ROOT/platform/edge-envoy/envoy.yaml.tmpl" > "$EDGE_CONFIG"

log "validating edge config for us-east=$east_ip, us-west=$west_ip"
docker run --rm -v "$EDGE_CONFIG:/etc/envoy/envoy.yaml:ro" "$ENVOY_IMAGE" \
  --mode validate -c /etc/envoy/envoy.yaml >/dev/null

if docker inspect "$EDGE_CONTAINER" >/dev/null 2>&1; then
  log "replacing existing $EDGE_CONTAINER container"
  docker rm -f "$EDGE_CONTAINER" >/dev/null
fi

docker run -d --name "$EDGE_CONTAINER" --network kind \
  -p 8080:8080 -p 127.0.0.1:9901:9901 \
  -v "$EDGE_CONFIG:/etc/envoy/envoy.yaml:ro" \
  "$ENVOY_IMAGE" -c /etc/envoy/envoy.yaml >/dev/null

ok "edge Envoy is listening on http://localhost:8080 (admin: http://localhost:9901)"
