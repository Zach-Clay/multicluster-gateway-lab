# 0001 — kind for local clusters

**Context.** The lab needs two Kubernetes clusters on one laptop, plus a proxy outside both of
them that can reach each cluster's ingress.

**Decision.** Use kind. Every kind cluster puts its nodes on the same Docker network (`kind`),
so a plain Docker container running Envoy can reach both clusters' LoadBalancer IPs. Clusters are
single-node to stay inside Docker Desktop's default memory.

**Alternatives.** minikube (one cluster at a time by default, heavier). k3d (fine, but kind is the
upstream conformance tool and its network model is simpler to explain).

**Consequences.** macOS cannot reach the Docker network directly, so demos curl from a container
until the edge Envoy exists. See TROUBLESHOOTING.md.
