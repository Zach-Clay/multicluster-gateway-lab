#!/usr/bin/env bash
# Send requests to the cluster Gateway and show which service/cluster/pod answered.
# macOS cannot reach the kind Docker network directly, so curl runs in a container on that network.
source "$(dirname "$0")/../scripts/lib.sh"
require docker kubectl
ip="$(gateway_ip)"; [[ -n "$ip" ]] || die "Gateway has no address yet"

curl_in_net() { docker run --rm --network kind curlimages/curl:8.11.1 -s "$@"; }

for path in /api/orders /api/users /api/orders/healthz /nope; do
  echo "${bold}GET http://$ip$path${rst}"
  curl_in_net -w "${dim}HTTP %{http_code}${rst}\n" "http://$ip$path"
  echo
done
