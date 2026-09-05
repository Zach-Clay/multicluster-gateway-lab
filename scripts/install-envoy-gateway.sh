#!/usr/bin/env bash
# Install Envoy Gateway (which bundles the Gateway API CRDs) and create the cluster's ingress Gateway.
source "$(dirname "$0")/lib.sh"
require helm kubectl
EG_VERSION="${EG_VERSION:-v1.9.1}"

log "installing Envoy Gateway ${EG_VERSION}"
helm --kube-context "$CTX" upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version "$EG_VERSION" --namespace envoy-gateway-system --create-namespace --wait --timeout 5m >/dev/null
k wait --for=condition=Available deploy/envoy-gateway -n envoy-gateway-system --timeout=180s >/dev/null
ok "Envoy Gateway controller running"

k apply -f "$ROOT/platform/envoy-gateway/gatewayclass.yaml" -f "$ROOT/platform/envoy-gateway/gateway.yaml" >/dev/null
log "waiting for Gateway to be programmed and get a LoadBalancer IP"
k wait --for=condition=Programmed gateway/cluster-gateway -n ingress --timeout=180s >/dev/null
retry 30 2 bash -c "[[ -n \"\$(kubectl --context $CTX get gateway cluster-gateway -n ingress -o jsonpath='{.status.addresses[0].value}')\" ]]" \
  || die "Gateway never received an address; is MetalLB healthy?"
ok "Gateway ready at $(gateway_ip)"
