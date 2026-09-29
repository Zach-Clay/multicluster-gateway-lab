# Phase 2 — Second cluster

**Goal:** Bring up `us-west` with the same scripts, parameterized by `CLUSTER`. Prove the manifests are cluster-agnostic.

## Result

There are now two independent kind clusters: `us-east` and `us-west`. Each has its own Kubernetes
API server, MetalLB installation, Envoy Gateway controller, Gateway address, and copy of the demo
applications. They share the Docker `kind` network because that is the local-underlay network, but
they do not share Kubernetes resources or service discovery.

The only workload difference is the `CLUSTER_NAME` response field. It is injected by a small
kustomize overlay, so the same base Deployments, Services, and HTTPRoutes work in both clusters.

## What changed

| Concern | Mechanism |
| --- | --- |
| Select a cluster | `CLUSTER=us-east` is the default; pass `CLUSTER=us-west` to any Make target. |
| Keep commands scoped | `scripts/lib.sh` derives `kind-$CLUSTER`; every `kubectl` and Helm command uses that context explicitly. |
| Prevent address collisions | MetalLB assigns `us-east` `x.x.255.1-50` and `us-west` `x.x.255.51-100` from the kind subnet. |
| Identify the responder | `k8s/echo-api/overlays/<cluster>/cluster-name.yaml` patches `CLUSTER_NAME` on both Deployments. |
| Reuse application configuration | The shared kustomize base contains the namespace, Services, Deployments, and HTTPRoutes. |

## Bring up both clusters

Start with the existing east cluster, or create it if needed:

```bash
make up
```

Then create the west cluster using the exact same workflow:

```bash
make up CLUSTER=us-west
```

The image build is intentionally safe to repeat. `kind load docker-image` then imports that local
image into the selected cluster's node, which is necessary because the two kind nodes have separate
container runtimes.

Check both contexts without relying on whichever context happens to be current in kubeconfig:

```bash
make status
make status CLUSTER=us-west

kubectl --context kind-us-east get gateway cluster-gateway -n ingress
kubectl --context kind-us-west get gateway cluster-gateway -n ingress
```

The two Gateway addresses must be different. This confirms each MetalLB installation chose an
address from its cluster-specific pool.

## Prove the same routes work in both clusters

Run the routing demo once per cluster:

```bash
make demo-routing
make demo-routing CLUSTER=us-west
```

Both runs return successful responses for `/api/orders` and `/api/users`; the JSON response from
the first run includes `"cluster":"us-east"`, while the second includes `"cluster":"us-west"`.
`/nope` remains a Gateway-generated 404 in each case, which is a useful check that requests are
really passing through the same HTTPRoute configuration.

You can inspect the rendered overlays directly:

```bash
kubectl kustomize k8s/echo-api/overlays/us-east > /tmp/us-east.yaml
kubectl kustomize k8s/echo-api/overlays/us-west > /tmp/us-west.yaml
diff -u /tmp/us-east.yaml /tmp/us-west.yaml
```

The meaningful differences should be only the two `CLUSTER_NAME` values. The Gateway and route
objects are deliberately not duplicated or renamed per cluster: they live in different API servers.

## Why this matters for the next phase

At this point the clusters are deliberately independent: calling either Gateway reaches only that
cluster. Phase 3 adds a standalone edge Envoy in front of these two Gateway addresses so a single
entry point can perform health checking and failover. Keeping the per-cluster setup identical makes
that layer straightforward to reason about and test.

## Cleanup

Clusters can be deleted independently:

```bash
make down-cluster CLUSTER=us-west
make down-cluster                 # removes us-east
```

Use `make down` when the entire lab—including the edge Envoy added in Phase 3—should be removed.
