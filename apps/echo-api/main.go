// echo-api is a tiny HTTP service used to make traffic routing visible.
//
// Every response reports which service, cluster, and pod handled the request,
// so you can watch requests move between clusters during failover demos.
// If UPSTREAM_URL is set, requests to /api/<service> also call that upstream
// and embed its response, which gives the service mesh an east-west call to secure.
package main

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync/atomic"
	"time"
)

type response struct {
	Service  string            `json:"service"`
	Cluster  string            `json:"cluster"`
	Pod      string            `json:"pod"`
	Node     string            `json:"node"`
	Path     string            `json:"path"`
	Time     string            `json:"time"`
	Headers  map[string]string `json:"headers,omitempty"`
	Upstream json.RawMessage   `json:"upstream,omitempty"`
	Error    string            `json:"error,omitempty"`
}

var (
	service  = envOr("SERVICE_NAME", "echo")
	cluster  = envOr("CLUSTER_NAME", "unknown")
	pod      = envOr("POD_NAME", "local")
	node     = envOr("NODE_NAME", "local")
	upstream = os.Getenv("UPSTREAM_URL")
	failing  atomic.Bool
)

func envOr(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /admin/fail", func(w http.ResponseWriter, _ *http.Request) {
		failing.Store(true)
		w.WriteHeader(http.StatusAccepted)
		_, _ = io.WriteString(w, "healthz will now return 503\n")
	})
	mux.HandleFunc("POST /admin/recover", func(w http.ResponseWriter, _ *http.Request) {
		failing.Store(false)
		w.WriteHeader(http.StatusAccepted)
		_, _ = io.WriteString(w, "healthz will now return 200\n")
	})
	mux.HandleFunc("/", handle)

	addr := ":" + envOr("PORT", "8080")
	log.Printf("%s starting on %s (cluster=%s pod=%s upstream=%q)", service, addr, cluster, pod, upstream)
	log.Fatal(http.ListenAndServe(addr, mux))
}

func handle(w http.ResponseWriter, r *http.Request) {
	// Any path ending in /healthz is a health probe, e.g. /healthz or /api/orders/healthz.
	if strings.HasSuffix(r.URL.Path, "/healthz") {
		if failing.Load() {
			http.Error(w, "unhealthy (forced via /admin/fail)", http.StatusServiceUnavailable)
			return
		}
		_, _ = io.WriteString(w, "ok\n")
		return
	}

	resp := response{
		Service: service,
		Cluster: cluster,
		Pod:     pod,
		Node:    node,
		Path:    r.URL.Path,
		Time:    time.Now().UTC().Format(time.RFC3339),
		Headers: interestingHeaders(r),
	}

	if upstream != "" && !strings.Contains(r.URL.Path, "/shallow") {
		body, err := callUpstream(upstream)
		if err != nil {
			resp.Error = "upstream: " + err.Error()
		} else {
			resp.Upstream = body
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Served-By-Cluster", cluster)
	w.Header().Set("X-Served-By-Pod", pod)
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	_ = enc.Encode(resp)
}

func callUpstream(url string) (json.RawMessage, error) {
	client := &http.Client{Timeout: 2 * time.Second}
	res, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	b, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if !json.Valid(b) {
		b, _ = json.Marshal(map[string]any{"status": res.StatusCode, "body": strings.TrimSpace(string(b))})
	}
	return b, nil
}

// interestingHeaders surfaces the headers that show which proxies touched the request.
func interestingHeaders(r *http.Request) map[string]string {
	out := map[string]string{}
	for _, h := range []string{"X-Forwarded-For", "X-Request-Id", "X-Envoy-External-Address", "X-Edge-Route", "Host"} {
		if v := r.Header.Get(h); v != "" {
			out[h] = v
		}
	}
	if r.Host != "" {
		out["Host"] = r.Host
	}
	return out
}
