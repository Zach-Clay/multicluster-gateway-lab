# multicluster-gateway-lab
# Every target acts on ONE cluster, chosen with CLUSTER=us-east|us-west (default us-east).
#   make up                      # build the us-east cluster with Envoy Gateway + demo APIs
#   make up CLUSTER=us-west      # build the independent us-west cluster the same way
#   make demo-routing            # curl through the gateway
#   make down                    # delete the cluster
SHELL := /bin/bash
export CLUSTER ?= us-east
export EG_VERSION ?= v1.9.1
export METALLB_VERSION ?= 0.16.1
export IMAGE ?= mcgl/echo-api:dev
export ENVOY_IMAGE ?= envoyproxy/envoy:v1.32.3

.DEFAULT_GOAL := help
.PHONY: help tools up cluster metallb envoy-gateway build load deploy status edge-up edge-status edge-down demo-routing demo-edge demo-failover down down-cluster

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo; echo "  CLUSTER=$(CLUSTER)  EG_VERSION=$(EG_VERSION)  METALLB_VERSION=$(METALLB_VERSION)"

tools: ## Verify required CLIs are installed
	@for t in docker kind kubectl helm; do command -v $$t >/dev/null || { echo "missing: $$t"; exit 1; }; done; echo "all tools present"

up: tools cluster metallb envoy-gateway build load deploy status ## Create the selected cluster and install everything

cluster: ## Create the kind cluster
	@scripts/cluster-up.sh
metallb: ## Install MetalLB with a per-cluster IP pool
	@scripts/install-metallb.sh
envoy-gateway: ## Install Envoy Gateway and the cluster Gateway
	@scripts/install-envoy-gateway.sh
build: ## Build the echo-api container image
	@scripts/build-image.sh
load: ## Load the image into the kind cluster
	@scripts/load-image.sh
deploy: ## Deploy demo APIs + HTTPRoutes
	@scripts/deploy-apps.sh
status: ## Show Gateway, routes and pods
	@scripts/status.sh

edge-up: ## Start the Envoy edge load balancer in front of both clusters
	@scripts/edge-up.sh
edge-status: ## Show edge Envoy and its upstream health
	@scripts/edge-status.sh
edge-down: ## Remove only the edge Envoy container
	@scripts/edge-down.sh

demo-routing: ## Curl the APIs through the cluster Gateway
	@demo/routing.sh
demo-edge: ## Curl the APIs through the edge Envoy
	@demo/edge-routing.sh
demo-failover: ## Scale down us-east orders, observe edge failover, then restore it
	@demo/failover.sh

down: edge-down ## Remove the edge Envoy and both lab clusters
	@for cluster in us-east us-west; do CLUSTER=$$cluster scripts/cluster-down.sh; done

down-cluster: ## Delete only the selected cluster (CLUSTER=us-east|us-west)
	@scripts/cluster-down.sh
