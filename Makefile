# The artifact is the module, not an image. `build` produces a scratch image
# holding it; `extract` writes it to ./dist for consumers who would rather have
# files than a registry.
IMAGE               ?= fabiocicerchia/nginx-modsecurity-module
NGINX_VERSION       ?= 1.27.5
MODSECURITY_VERSION ?= 3.0.14
VERSION             ?= $(MODSECURITY_VERSION)-nginx$(NGINX_VERSION)
PLATFORMS           ?= linux/amd64,linux/arm64

BUILD_ARGS = --build-arg NGINX_VERSION=$(NGINX_VERSION) \
             --build-arg MODSECURITY_VERSION=$(MODSECURITY_VERSION) \
             --build-arg BASE=nginx:$(NGINX_VERSION)-bookworm

.PHONY: help build extract lint test push release clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

build: ## Compile the module into a scratch image
	docker build $(BUILD_ARGS) -t $(IMAGE):$(VERSION) .

extract: ## Write the module and its library to ./dist
	docker build $(BUILD_ARGS) --output type=local,dest=./dist .
	@echo "wrote:"; find dist -type f | sed 's/^/  /'

lint: ## Lint the Dockerfile
	docker run --rm -i hadolint/hadolint < Dockerfile

test: build ## Prove the module loads in a stock nginx of the same version
	./test.sh $(IMAGE):$(VERSION) $(NGINX_VERSION)

push: build ## Push the artifact image
	docker push $(IMAGE):$(VERSION)

release: ## Build and push multi-arch
	docker buildx build --platform $(PLATFORMS) $(BUILD_ARGS) \
		-t $(IMAGE):$(VERSION) -t $(IMAGE):latest --push .

clean: ## Remove extracted artifacts
	rm -rf dist
