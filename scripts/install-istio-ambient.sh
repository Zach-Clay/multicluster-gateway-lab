#!/usr/bin/env bash
# Install (or reconcile) Istio's ambient profile in one kind cluster.
source "$(dirname "$0")/lib.sh"
require istioctl kubectl
cluster_exists || die "cluster does not exist; run make cluster first"
ISTIO_VERSION="${ISTIO_VERSION:-1.31.0}"
client_version="$(istioctl version --remote=false 2>/dev/null | sed -n 's/^client version: //p')"
[[ "$client_version" == "$ISTIO_VERSION" ]] || die "istioctl ${ISTIO_VERSION} is required (found ${client_version:-unknown}); install it or set ISTIO_VERSION to the installed version"

log "installing Istio ${ISTIO_VERSION} ambient profile (istiod, CNI, and ztunnel)"
istioctl install --context "$CTX" --set profile=ambient --skip-confirmation >/dev/null

k rollout status deployment/istiod -n istio-system --timeout=180s >/dev/null
k rollout status daemonset/istio-cni-node -n istio-system --timeout=180s >/dev/null
k rollout status daemonset/ztunnel -n istio-system --timeout=180s >/dev/null
ok "Istio ambient control plane and ztunnel are ready"
