# Phase 1 — One cluster, Envoy Gateway, routing by path

**Goal:** stand up a single Kubernetes cluster locally, install Envoy Gateway as the Gateway API
implementation, and route `/api/orders` and `/api/users` to two different services.

## The moving parts

| Piece | What it is | Where |
|-------|-----------|-------|
| kind | A Kubernetes cluster whose nodes are Docker containers | `kind/cluster.yaml`, `scripts/cluster-up.sh` |
| MetalLB | Hands out LoadBalancer IPs on bare metal (here, the Docker network) | `platform/metallb/`, `scripts/install-metallb.sh` |
| Envoy Gateway | Controller that turns Gateway API objects into a running Envoy proxy | `scripts/install-envoy-gateway.sh` |
| GatewayClass | "Use Envoy Gateway for Gateways of this class" | `platform/envoy-gateway/gatewayclass.yaml` |
| Gateway | The cluster's front door: one HTTP listener on port 80 | `platform/envoy-gateway/gateway.yaml` |
| HTTPRoute | App-owned routing rules that attach to the Gateway | `k8s/echo-api/base/httproutes.yaml` |
| echo-api | Tiny Go service that reports which cluster/pod answered | `apps/echo-api/` |

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

## What surprised me

_To be written._
