# multicluster-gateway-lab
# Every target acts on ONE cluster, chosen with CLUSTER=us-east|us-west (default us-east).
#   make up                      # build phase 1: one cluster with Envoy Gateway + demo APIs
#   make up CLUSTER=us-west      # the same for the second cluster
#   make demo-routing            # curl through the gateway
#   make down                    # delete the cluster
SHELL := /bin/bash
export CLUSTER ?= us-east
export EG_VERSION ?= v1.9.1
export METALLB_VERSION ?= 0.16.1
export IMAGE ?= mcgl/echo-api:dev

.DEFAULT_GOAL := help
.PHONY: help tools up cluster metallb envoy-gateway build load deploy status demo-routing down

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo; echo "  CLUSTER=$(CLUSTER)  EG_VERSION=$(EG_VERSION)  METALLB_VERSION=$(METALLB_VERSION)"

tools: ## Verify required CLIs are installed
	@for t in docker kind kubectl helm; do command -v $$t >/dev/null || { echo "missing: $$t"; exit 1; }; done; echo "all tools present"

up: tools cluster metallb envoy-gateway build load deploy status ## Create the cluster and install everything (phase 1)

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

demo-routing: ## Curl the APIs through the cluster Gateway
	@demo/routing.sh

down: ## Delete the kind cluster
	@scripts/cluster-down.sh
