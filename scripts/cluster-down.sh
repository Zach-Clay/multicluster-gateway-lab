#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
require kind
if cluster_exists; then kind delete cluster --name "$CLUSTER"; ok "deleted"; else ok "no cluster to delete"; fi
