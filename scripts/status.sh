#!/usr/bin/env bash
# One-screen summary of what is running in this cluster.
source "$(dirname "$0")/lib.sh"
cluster_exists || die "cluster does not exist"
echo "${bold}== $CLUSTER: Gateway${rst}"; k get gateway -n ingress
echo "${bold}== $CLUSTER: HTTPRoutes${rst}"; k get httproute -n demo
echo "${bold}== $CLUSTER: Istio ambient${rst}"; k get daemonset/istio-cni-node daemonset/ztunnel -n istio-system
echo "${bold}== $CLUSTER: Waypoint${rst}"; k get gateway/waypoint -n demo
echo "${bold}== $CLUSTER: AuthorizationPolicy${rst}"; k get authorizationpolicy -n demo
echo "${bold}== $CLUSTER: Pods${rst}"; k get pods -n demo -o wide
