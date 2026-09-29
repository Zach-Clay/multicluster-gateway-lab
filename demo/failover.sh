#!/usr/bin/env bash
# Demonstrate east-to-west failover, then restore the east workload even if the demo is interrupted.
source "$(dirname "$0")/../scripts/lib.sh"
require docker kubectl
EDGE_CONTAINER="${EDGE_CONTAINER:-edge-envoy}"
EAST_CTX="kind-us-east"
docker inspect "$EDGE_CONTAINER" >/dev/null 2>&1 || die "edge Envoy is not running; run 'make edge-up'"

curl_edge() { docker run --rm --network kind curlimages/curl:8.11.1 -sS --connect-timeout 2 "$@"; }
original_replicas="$(kubectl --context "$EAST_CTX" get deploy/orders -n demo -o jsonpath='{.spec.replicas}')"
[[ "$original_replicas" =~ ^[0-9]+$ ]] || die "could not determine us-east orders replica count"
scaled_down=false

restore() {
  if [[ "$scaled_down" == true ]]; then
    log "restoring us-east orders to $original_replicas replicas"
    kubectl --context "$EAST_CTX" scale deploy/orders -n demo --replicas="$original_replicas" >/dev/null || true
    kubectl --context "$EAST_CTX" rollout status deploy/orders -n demo --timeout=120s >/dev/null || true
    scaled_down=false
  fi
}
trap restore EXIT

echo "${bold}Before failure: edge chooses us-east (priority 0)${rst}"
curl_edge http://"$EDGE_CONTAINER":8080/api/orders
echo

log "scaling us-east orders to zero; the edge health check should fail after two probes"
kubectl --context "$EAST_CTX" scale deploy/orders -n demo --replicas=0 >/dev/null
scaled_down=true

for attempt in $(seq 1 30); do
  response="$(curl_edge http://"$EDGE_CONTAINER":8080/api/orders 2>&1 || true)"
  if grep -q '"cluster": "us-west"' <<<"$response"; then
    echo "${bold}After failure: edge chose us-west${rst}"
    echo "$response"
    restore
    echo "${bold}After recovery: waiting for the edge to prefer us-east again${rst}"
    for recovery_attempt in $(seq 1 30); do
      recovered_response="$(curl_edge http://"$EDGE_CONTAINER":8080/api/orders 2>&1 || true)"
      if grep -q '"cluster": "us-east"' <<<"$recovered_response"; then
        echo "$recovered_response"
        exit 0
      fi
      sleep 1
    done
    echo "$recovered_response" >&2
    die "us-east did not become preferred again within 30 seconds"
  fi
  sleep 1
done

echo "$response" >&2
die "edge did not fail over to us-west within 30 seconds"
