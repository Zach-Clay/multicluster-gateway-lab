#!/usr/bin/env bash
# Shared helpers for every script. Source this; do not run it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="${CLUSTER:-us-east}"
CTX="kind-${CLUSTER}"

bold=$'\e[1m'; dim=$'\e[2m'; red=$'\e[31m'; grn=$'\e[32m'; ylw=$'\e[33m'; cyn=$'\e[36m'; rst=$'\e[0m'

log()  { printf '%s[%s]%s %s\n' "$cyn" "$CLUSTER" "$rst" "$*"; }
ok()   { printf '%s[%s]%s %s✔%s %s\n' "$cyn" "$CLUSTER" "$rst" "$grn" "$rst" "$*"; }
warn() { printf '%s[%s]%s %s!%s %s\n' "$cyn" "$CLUSTER" "$rst" "$ylw" "$rst" "$*" >&2; }
die()  { printf '%s[%s]%s %s✘ %s%s\n' "$cyn" "$CLUSTER" "$rst" "$red" "$*" "$rst" >&2; exit 1; }

require() { for t in "$@"; do command -v "$t" >/dev/null 2>&1 || die "missing tool: $t (see README prerequisites)"; done; }

# kubectl pinned to this cluster's context so scripts never touch the wrong cluster.
k() { kubectl --context "$CTX" "$@"; }

cluster_exists() { kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; }

# Retry a command until it succeeds or the attempts run out: retry <attempts> <sleep> cmd...
retry() {
  local n=$1 s=$2; shift 2
  local i
  for ((i = 1; i <= n; i++)); do
    if "$@"; then return 0; fi
    sleep "$s"
  done
  return 1
}

# The IPv4 subnet of the Docker network kind puts every node on, e.g. 172.18.0.0/16.
kind_subnet() {
  docker network inspect kind -f '{{range .IPAM.Config}}{{println .Subnet}}{{end}}' | grep -v ':' | head -1
}

# Address the cluster Gateway received from MetalLB.
gateway_ip() {
  k get gateway cluster-gateway -n ingress -o jsonpath='{.status.addresses[0].value}' 2>/dev/null
}
