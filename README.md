# multicluster-gateway-lab

A hands-on lab for Kubernetes networking beyond a single cluster: **Envoy** at the edge and at each
cluster's front door, the **Kubernetes Gateway API** for routing, and **Istio ambient mode** for
zero-trust service-to-service traffic. Everything runs on a laptop with Docker.

> Status: **Phase 4 complete** (Istio ambient mode in both clusters, with ztunnel mTLS and
> waypoint-enforced service authorization).
> See the [roadmap](#roadmap) for what comes next. The learning notes live in [`docs/`](docs/).

## What this shows

```
                       laptop :8080
                            │
                 ┌──────────▼──────────┐
                 │   edge-envoy (GLB)  │   standalone Envoy on the Docker network
                 │ health checks + P0/P1│   active health checks, priority failover
                 └─────┬─────────┬─────┘
                       │         │
        ┌──────────────▼──┐   ┌──▼──────────────┐
        │ kind: us-east   │   │ kind: us-west   │
        │ Envoy Gateway   │   │ Envoy Gateway   │   Gateway API: GatewayClass, Gateway, HTTPRoute
        │  /api/orders ───┼─► orders          │
        │  /api/users  ───┼─► users           │
        │ Istio ambient   │   │ Istio ambient   │   ztunnel mTLS, waypoint L7, AuthorizationPolicy
        │ orders ─► users │   │ orders ─► users │   east-west call secured by the mesh
        └─────────────────┘   └─────────────────┘
```

Two clusters, each with its own Envoy-based ingress, fronted by an edge Envoy that plays the role a
cloud global load balancer would play in production. Kill the API in one cluster and watch the edge
route around it. Inside each cluster, Istio ambient mode encrypts and authorizes the call from
`orders` to `users` without sidecars.

## Roadmap

Each phase is a pull request with its own doc in `docs/`. The commit history is the learning log.

| Phase | Goal | Doc | Status |
|------:|------|-----|--------|
| 1 | One kind cluster, Envoy Gateway, two APIs routed by path with HTTPRoutes | [docs/01-gateway-api.md](docs/01-gateway-api.md) | ✅ done |
| 2 | Second cluster (`us-west`) from the same scripts and manifests | [docs/02-second-cluster.md](docs/02-second-cluster.md) | ✅ done |
| 3 | Edge Envoy as the "GLB": active health checks, priority failover, outlier detection | [docs/03-edge-failover.md](docs/03-edge-failover.md) | ✅ done |
| 4 | Istio ambient in each cluster: ztunnel mTLS, a waypoint, AuthorizationPolicy | [docs/04-istio-ambient.md](docs/04-istio-ambient.md) | ✅ done |
| 5 | Stretch: multi-cluster ambient mesh with an east-west gateway | [docs/05-multicluster-mesh.md](docs/05-multicluster-mesh.md) | ⬜ |
| 6 | GitOps: Argo CD ApplicationSet deploying to both clusters | [docs/06-gitops-argocd.md](docs/06-gitops-argocd.md) | ⬜ |

Design choices are recorded as short ADRs in [`docs/decisions/`](docs/decisions/).

## Prerequisites

| Tool | Why | Install (macOS) |
|------|-----|-----------------|
| Docker Desktop (8 GB memory recommended) | runs the kind nodes and the edge Envoy | https://docker.com |
| `kind` | Kubernetes clusters as Docker containers | `brew install kind` |
| `kubectl` | talk to the clusters | `brew install kubectl` |
| `helm` | install MetalLB, Envoy Gateway, Istio | `brew install helm` |
| `istioctl` | phase 4+ | `brew install istioctl` |
| `make` | the task runner; ships with macOS | already there |

Pinned versions live at the top of the [`Makefile`](Makefile) and can be overridden, e.g. `make up EG_VERSION=v1.9.1`.

## Quickstart

```bash
make up                         # create us-east, install MetalLB + Envoy Gateway, deploy the APIs
make up CLUSTER=us-west         # repeat the same setup as an independent second cluster
make demo-routing                # curl /api/orders and /api/users through us-east's Gateway
make demo-routing CLUSTER=us-west # curl through us-west's Gateway
make status                      # Gateway, HTTPRoutes, pods in us-east
make edge-up                     # start the host-published Envoy edge load balancer
make demo-edge                   # route through localhost:8080; us-east is preferred
make demo-failover               # demonstrate us-east → us-west failover and restore us-east
make edge-down                   # remove only the edge Envoy container
make down                        # remove the edge Envoy and both lab clusters
make down-cluster CLUSTER=us-west # remove only us-west
```

Cluster-scoped targets act on the cluster chosen with `CLUSTER=us-east|us-west` (default
`us-east`). Edge targets and `make down` deliberately operate across the whole lab. Run `make help`
for the full list.

### Why curl runs in a container

On macOS, Docker Desktop does not route traffic from the host to container IPs, so the Gateway's
LoadBalancer IP (`172.18.255.x`) is unreachable from a terminal. The demo scripts therefore run
`curl` inside a container attached to the `kind` Docker network. From phase 3 on, the edge Envoy
publishes a port to the host and becomes the single entry point. Details in
[TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Repository layout

```
apps/echo-api/          Go service that echoes service/cluster/pod; orders calls users
kind/                   kind cluster config
platform/metallb/       LoadBalancer IP pool template (per-cluster range)
platform/envoy-gateway/ GatewayClass + the cluster Gateway
platform/edge-envoy/    Envoy edge configuration template, rendered with live Gateway IPs
k8s/echo-api/           kustomize base + per-cluster overlays (Deployments, Services, HTTPRoutes)
scripts/                one script per step, including the Istio ambient installation, all driven by the Makefile
demo/                   scripted demos that print what happened
docs/                   one doc per phase, plus ADRs in docs/decisions/
```

## License

MIT
