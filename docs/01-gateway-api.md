# Phase 1 — One cluster, Envoy Gateway, routing by path

**Goal:** stand up a single Kubernetes cluster locally, install Envoy Gateway as the Gateway API
implementation, and route `/api/orders` and `/api/users` to two different services.

## The moving parts

| Piece         | What it is                                                           | Where                                             |
| ------------- | -------------------------------------------------------------------- | ------------------------------------------------- |
| kind          | A Kubernetes cluster whose nodes are Docker containers               | `kind/cluster.yaml`, `scripts/cluster-up.sh`      |
| MetalLB       | Hands out LoadBalancer IPs on bare metal (here, the Docker network)  | `platform/metallb/`, `scripts/install-metallb.sh` |
| Envoy Gateway | Controller that turns Gateway API objects into a running Envoy proxy | `scripts/install-envoy-gateway.sh`                |
| GatewayClass  | "Use Envoy Gateway for Gateways of this class"                       | `platform/envoy-gateway/gatewayclass.yaml`        |
| Gateway       | The cluster's front door: one HTTP listener on port 80               | `platform/envoy-gateway/gateway.yaml`             |
| HTTPRoute     | App-owned routing rules that attach to the Gateway                   | `k8s/echo-api/base/httproutes.yaml`               |
| echo-api      | Tiny Go service that reports which cluster/pod answered              | `apps/echo-api/`                                  |

## The Gateway API model in one paragraph

Gateway API splits ingress across roles. The **infrastructure provider** ships a `GatewayClass`
(Envoy Gateway does this by naming its controller). The **platform team** creates a `Gateway`,
which is a real listening proxy with an address, and decides which namespaces may attach to it.
**Application teams** create `HTTPRoute`s in their own namespaces that reference the Gateway via
`parentRefs`. This is the ownership split that the old `Ingress` resource never had.

## Walkthrough

_Filled in step by step as we go. Each step: what we ran, what to look at, what surprised us._

1. Create the cluster
2. Install MetalLB and give it an IP range
3. Install Envoy Gateway; create the GatewayClass and Gateway
4. Build the echo-api image and load it into kind
5. Deploy orders + users and their HTTPRoutes
6. Curl through the Gateway and read the response

## My Notes

To save resources on my local computer and for the sake of this demo project, I'm running the control-plane and the workload host on the same node.
In a typical setup, obviously the control-plane and workload would be on separate nodes in the same cluster.

### Appendix: How we performed this step

#### Reset

```bash
make down
```

This deletes the `us-east` cluster so you build it fresh. Run `docker ps` afterwards and note the node
container is gone.

---

#### Step 1 — Create the cluster

Read `kind/cluster.yaml` and `scripts/cluster-up.sh` first, then:

```bash
make cluster
```

**Things to look at:**

```bash
docker ps
```

The node is a container named `us-east-control-plane`. That is all a kind node is.

```bash
docker network inspect kind --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}'
```

This is the network every piece of the lab lives on. The subnet will be `172.18.0.0/16` and MetalLB
will hand out IPs from the top of it.

```bash
kubectl config get-contexts
```

kind created a context named `kind-us-east`. Every script uses that context explicitly so it can never
hit the wrong cluster. Then `kubectl get pods -A` shows the bare control plane: apiserver, etcd,
scheduler, CoreDNS, kube-proxy, and kindnet as the CNI.

---

#### Step 2 — MetalLB

Read `scripts/install-metallb.sh` and the pool template, then:

```bash
make metallb
```

Then look at the two things it created:

```bash
kubectl get pods -n metallb-system
```

A **controller**, which picks IPs, and a **speaker** DaemonSet, which answers ARP on the node's network
so the Docker bridge learns where that IP lives. That is what "L2 mode" means.

```bash
kubectl get ipaddresspool,l2advertisement -n metallb-system
```

Now prove it works with a throwaway Service before any gateway exists:

```bash
kubectl create deploy nginx --image=nginx \
  && kubectl expose deploy nginx --port 80 --type LoadBalancer \
  && kubectl get svc nginx -w
```

Watch `EXTERNAL-IP` go from `<pending>` to `172.18.255.1` within a few seconds. Press `Ctrl+C`, then
delete it so the gateway gets a clean slate:

```bash
kubectl delete svc,deploy nginx
```

---

#### Step 3 — Envoy Gateway

Read `scripts/install-envoy-gateway.sh`, `gatewayclass.yaml`, and `gateway.yaml`. In a second terminal,
start a watch so you can see pods appear as the script runs:

```bash
kubectl get pods -n envoy-gateway-system -w
```

Then in the first terminal:

```bash
make envoy-gateway
```

You will see two pods appear in sequence:

1. **`envoy-gateway`** — the controller, which is not a proxy at all. It watches Gateway API objects.
2. **`envoy-ingress-cluster-gateway-<hash>`** — appears only after the Gateway object is applied. That
   one is the actual Envoy proxy, and the controller created it in response to your Gateway.

> This is the central idea: a Gateway is a declaration, and the implementation materializes a real
> proxy for it.

```bash
kubectl get crd | grep gateway.networking
```

The Gateway API CRDs came bundled with the Envoy Gateway Helm chart.

```bash
kubectl describe gateway cluster-gateway -n ingress
```

Read the `Status` section. Conditions `Accepted` and `Programmed` should both be `True`. Under
`Listeners`, note `Attached Routes: 0` — nothing routes yet. Also note the `Address`, which came from
MetalLB via the LoadBalancer Service:

```bash
kubectl get svc -n envoy-gateway-system
```

Now the best part for seeing what is going on: **Envoy's admin API**. Port-forward to it and open the
config dump:

```bash
kubectl port-forward -n envoy-gateway-system \
  deploy/$(kubectl get deploy -n envoy-gateway-system \
    -l gateway.envoyproxy.io/owning-gateway-name=cluster-gateway \
    -o name | cut -d/ -f2) \
  19000:19000
```

Leave that running and open <http://localhost:19000/config_dump> in your browser, or:

```bash
curl -s localhost:19000/config_dump | less
```

Search for `route_config`. Right now it is nearly empty. Come back here after step 5.

---

#### Step 4 — Build and load the image

Read `apps/echo-api/main.go` with an eye on two things:

- every response includes cluster and pod name
- any path ending in `/healthz` is a health probe

Then:

```bash
make build load
```

**Why two steps:** kind nodes have their own container runtime inside the node container, with no
access to your Mac's Docker image cache. Confirm the image exists in both places:

```bash
docker images mcgl/echo-api \
  && docker exec us-east-control-plane crictl images | grep echo-api
```

---

#### Step 5 — Deploy the apps and routes

Read `k8s/echo-api/base/httproutes.yaml` and the `us-east` overlay. Note the namespace has the label
`gateway-access: "true"`, which the Gateway's listener requires. Then:

```bash
make deploy
```

Check the route was accepted by the Gateway:

```bash
kubectl get httproute -n demo -o yaml | grep -A12 'status:'
```

Look for `Accepted: True` and `ResolvedRefs: True` under `parents`. Then re-run the `describe` from
step 3 and `Attached Routes` should now say `2`. Reload the config dump: `route_config` now has both
path prefixes, and `dynamic_active_clusters` lists the orders and users backends with their pod IPs.
That is the Gateway API translated into Envoy.

---

#### Step 6 — Send traffic

Read `demo/routing.sh`, then:

```bash
make demo-routing
```

Then experiment by hand. Set the IP once:

```bash
IP=$(kubectl get gateway cluster-gateway -n ingress -o jsonpath='{.status.addresses[0].value}')
```

Run this several times and watch the pod name alternate as Envoy load balances between the two
replicas:

```bash
docker run --rm --network kind curlimages/curl -s http://$IP/api/users | grep pod
```

Watch Envoy's access log at the same time in another terminal:

```bash
kubectl logs -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-name=cluster-gateway \
  -c envoy -f
```

---

#### Three experiments worth doing

1. **Break the route.** Edit the users HTTPRoute path prefix to `/api/people`, apply the overlay, and
   curl `/api/users` again:

   ```bash
   kubectl apply -k k8s/echo-api/overlays/us-east
   ```

   You get a `404` from Envoy itself, not from the app. Then put it back.

2. **Preview failover.** Scale users to zero and curl `/api/orders`:

   ```bash
   kubectl scale deploy users -n demo --replicas 0
   ```

   The response now carries an `error` field, because orders could not reach users. Then hit
   `/api/orders/healthz`. It still returns `200`, which is exactly the trap ADR 0003 warns about: a
   naive health check would call this cluster healthy while it is serving broken responses. Scale back
   to 2:

   ```bash
   kubectl scale deploy users -n demo --replicas 2
   ```

3. **Remove the namespace label.** Drop the label and check `Attached Routes` in the Gateway describe:

   ```bash
   kubectl label ns demo gateway-access-
   ```

   Re-add the label:

   ```bash
   kubectl label ns demo gateway-access=true
   ```

   That is the platform-team boundary in action.
