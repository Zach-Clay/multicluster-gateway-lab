# 0002 — MetalLB for LoadBalancer IPs

**Context.** Envoy Gateway exposes each Gateway as a Service of type LoadBalancer. Without a cloud
provider nothing assigns it an IP and the Gateway stays unaddressed.

**Decision.** Install MetalLB in L2 mode with a distinct address range per cluster carved from the
top of the kind subnet (`x.x.255.1-50` for us-east, `x.x.255.51-100` for us-west). Distinct ranges
mean the edge Envoy can be configured with stable, non-colliding upstream addresses.

**Alternatives.** cloud-provider-kind: simpler, but its macOS behavior relies on host port
mapping, which hides the "real IP on a network" model this lab wants to show.

**Consequences.** One more component per cluster. IP ranges assume a /16 kind network.
