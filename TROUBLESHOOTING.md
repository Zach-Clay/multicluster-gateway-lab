# Troubleshooting

Problems hit while building this lab, and what fixed them. Newest at the top.

## macOS cannot reach the Gateway's LoadBalancer IP

**Symptom:** `curl http://172.18.255.1/api/orders` from the Mac terminal hangs.

**Cause:** Docker Desktop on macOS runs containers inside a Linux VM. Container and MetalLB IPs
exist only inside that VM's network. Linux hosts can reach them; macOS cannot.

**Fix:** Run curl inside a container on the same Docker network:

```bash
docker run --rm --network kind curlimages/curl -s http://172.18.255.1/api/orders
```

Or `kubectl port-forward -n envoy-gateway-system svc/<envoy-service> 8888:80` for a quick look.
From phase 3 the edge Envoy publishes a host port, which is the intended entry point.
OrbStack makes container IPs reachable from macOS directly, but the repo does not depend on it.

## MetalLB IPAddressPool apply fails right after install

**Symptom:** `failed calling webhook "ipaddresspoolvalidationwebhook.metallb.io"` a few seconds
after `helm install` reports success.

**Cause:** The Helm chart reports ready before the validating webhook is serving.

**Fix:** `scripts/install-metallb.sh` retries the apply for up to a minute.

## Gateway never gets an ADDRESS

**Check:** `kubectl get svc -n envoy-gateway-system` should show a `LoadBalancer` Service with an
external IP. If it says `<pending>`, MetalLB is not handing out addresses: check
`kubectl get ipaddresspool -n metallb-system` and the speaker logs.
