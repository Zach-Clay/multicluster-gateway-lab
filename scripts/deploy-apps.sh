#!/usr/bin/env bash
# Deploy the demo APIs and their HTTPRoutes using this cluster's kustomize overlay.
source "$(dirname "$0")/lib.sh"
require kubectl
overlay="$ROOT/k8s/echo-api/overlays/$CLUSTER"
[[ -d "$overlay" ]] || die "no overlay at $overlay"
log "applying $overlay"
k apply -k "$overlay" >/dev/null
k rollout status deploy/users -n demo --timeout=120s >/dev/null
k rollout status deploy/orders -n demo --timeout=120s >/dev/null
k wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True httproute/orders httproute/users -n demo --timeout=60s >/dev/null
ok "orders and users deployed; HTTPRoutes accepted by the Gateway"
