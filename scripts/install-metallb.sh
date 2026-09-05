#!/usr/bin/env bash
# Install MetalLB and give this cluster its own slice of the kind Docker network for LoadBalancer IPs.
source "$(dirname "$0")/lib.sh"
require helm kubectl docker
METALLB_VERSION="${METALLB_VERSION:-0.16.1}"

log "installing MetalLB ${METALLB_VERSION}"
helm repo add metallb https://metallb.github.io/metallb >/dev/null 2>&1 || true
helm repo update metallb >/dev/null
helm --kube-context "$CTX" upgrade --install metallb metallb/metallb \
  --version "$METALLB_VERSION" --namespace metallb-system --create-namespace --wait --timeout 5m >/dev/null
ok "MetalLB running"

# Carve a per-cluster range out of the top of the kind subnet, well above the node IPs
# Docker hands out from the bottom. Each cluster gets 50 addresses.
subnet="$(kind_subnet)"
[[ "$subnet" == */16 ]] || die "expected a /16 kind subnet, got '$subnet' (edit scripts/install-metallb.sh)"
prefix="${subnet%.0.0/16}"
case "$CLUSTER" in
  us-east) POOL_START="$prefix.255.1";   POOL_END="$prefix.255.50"  ;;
  us-west) POOL_START="$prefix.255.51";  POOL_END="$prefix.255.100" ;;
  *)       POOL_START="$prefix.255.101"; POOL_END="$prefix.255.150" ;;
esac
log "LoadBalancer pool: $POOL_START - $POOL_END"

rendered="$(sed -e "s/\${CLUSTER}/$CLUSTER/g" -e "s/\${POOL_START}/$POOL_START/g" -e "s/\${POOL_END}/$POOL_END/g" "$ROOT/platform/metallb/pool.yaml.tmpl")"
# The MetalLB webhook can take a moment to start answering after the chart reports ready.
for i in $(seq 1 20); do
  if echo "$rendered" | k apply -f - >/dev/null 2>&1; then break; fi
  [[ $i -eq 20 ]] && die "could not apply IPAddressPool (webhook not answering?)"
  sleep 3
done
ok "IPAddressPool applied"
