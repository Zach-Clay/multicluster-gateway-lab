# 0003 — Standalone Envoy plays the global load balancer

**Context.** Production would use a cloud GLB (GCP Global External LB, AWS Global Accelerator,
Cloudflare) in front of the clusters. Locally there is no such thing.

**Decision.** Run a single Envoy container with a static config outside both clusters. It has one
upstream cluster per Kubernetes cluster, active HTTP health checks against a real API route, and
priority levels so us-west only receives traffic when us-east is unhealthy.

**Alternatives.** A third kind cluster running Envoy Gateway with `Backend` resources pointing at
the other clusters. More Gateway API practice, but it pretends the edge is Kubernetes when in real
deployments it is not, and raw Envoy config is worth learning because Envoy Gateway and Istio both
generate it.

**Consequences.** Health checks must target a path that reaches the application (for example
`/api/orders/healthz`), not just the cluster gateway, or failover never triggers.
