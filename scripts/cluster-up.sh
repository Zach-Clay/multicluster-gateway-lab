#!/usr/bin/env bash
# Create the kind cluster named $CLUSTER if it does not already exist.
source "$(dirname "$0")/lib.sh"
require kind kubectl docker

if cluster_exists; then
  ok "kind cluster already exists"
else
  log "creating kind cluster"
  kind create cluster --name "$CLUSTER" --config "$ROOT/kind/cluster.yaml" --wait 120s
  ok "cluster created (context $CTX)"
fi
k get nodes
