# Phase 3 — Edge Envoy as the global load balancer

**Goal:** A standalone Envoy in front of both clusters with active health checks, priority-based failover, and outlier detection. Kill `orders` in `us-east` and watch traffic move to `us-west`.

## Result

`edge-envoy` is a standalone Envoy container on the Docker `kind` network. It is the only
component that publishes an application port to the laptop: `localhost:8080`. Its two upstreams are
the LoadBalancer addresses assigned to the Envoy Gateway in `us-east` and `us-west`.

The edge starts with `us-east` as priority 0 and uses `us-west` only when east is unhealthy. It
checks `/api/orders/healthz` every two seconds, so it tests the actual routed application path—not
merely whether the cluster Gateway process is accepting TCP connections. Passive outlier detection
also ejects an upstream after two observed 5xx responses for 15 seconds.

## Architecture

```text
client → localhost:8080 → edge-envoy → aggregate cluster
                                      ├─ priority 0: us-east Gateway → orders/users
                                      └─ priority 1: us-west Gateway → orders/users
```

The aggregate cluster is Envoy's ordered failover primitive. `global_orders` refers to `us-east`
first and `us-west` second. Each child is a static cluster with one endpoint: the relevant MetalLB
address. `scripts/edge-up.sh` reads those addresses from the two Kubernetes contexts and renders
`platform/edge-envoy/envoy.yaml.tmpl` into `/tmp/mcgl-edge-envoy.yaml`; no IP address is committed
to the repository.

## Start and inspect the edge

Phase 2 must already be running:

```bash
make up
make up CLUSTER=us-west
```

Start the edge and send normal traffic through it:

```bash
make edge-up
make demo-edge
```

The responses identify `us-east`, showing the preferred upstream is selected while it is healthy.
The same service is also available directly at `http://localhost:8080/api/orders` on the host. The
admin interface is intentionally bound to loopback at `http://localhost:9901`.

Inspect Envoy's upstream view at any time:

```bash
make edge-status
curl -s http://localhost:9901/clusters | grep -E '^(us-east|us-west).*health_flags'
```

`health_flags::healthy` means active checks consider that cluster's Gateway endpoint usable.

## Demonstrate failover

```bash
make demo-failover
```

The demo performs the following reversible sequence:

1. Sends a request through the edge, which is served by `us-east`.
2. Scales only `deployment/orders` in the `kind-us-east` context to zero.
3. Waits for two failed active probes (roughly four seconds) and repeatedly requests the edge.
4. Prints a response from `us-west`.
5. Restores `us-east/orders` to its original replica count, waits for Envoy to mark it healthy,
   and proves traffic returns to the preferred cluster. Restoration also runs if the demo is
   interrupted.

The important detail is the health-check path. If the edge checked only `/healthz` on the Gateway
process, it could keep sending traffic to east while the `orders` Service had no endpoints. By
checking `/api/orders/healthz`, Envoy sees the Gateway's upstream 503 and drains east.

## Why both health mechanisms?

Active health checks answer, “does the routed orders path work right now?” at a predictable interval.
Outlier detection answers, “have real client requests seen repeated upstream 5xx failures?” and
ejects the offending endpoint quickly. Together they cover scheduled probing and failures noticed
first by production traffic.

## Cleanup

```bash
make edge-down
```

This removes only the `edge-envoy` container. The two clusters and their applications continue to
run. Use `make down` to remove the edge and both lab clusters, or `make down-cluster
CLUSTER=us-west` to remove only one cluster.
