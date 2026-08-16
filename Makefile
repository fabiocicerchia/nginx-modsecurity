# The artifact is the module, not an image. `build` produces a scratch image
# holding it; `extract` writes it to ./dist for consumers who would rather have
# files than a registry.
IMAGE               ?= fabiocicerchia/nginx-modsecurity-module
NGINX_VERSION       ?= 1.27.5
MODSECURITY_VERSION ?= 3.0.14
# bookworm (glibc) or alpine (musl). The module can only be loaded into a
# runtime with the same libc, so the flavour is part of the tag rather than
# something a consumer has to remember.
FLAVOUR             ?= bookworm
DOCKERFILE          ?= $(if $(filter alpine,$(FLAVOUR)),Dockerfile.alpine,Dockerfile)
TAG_SUFFIX          ?= $(if $(filter alpine,$(FLAVOUR)),-alpine,)
VERSION             ?= $(MODSECURITY_VERSION)-nginx$(NGINX_VERSION)$(TAG_SUFFIX)
PLATFORMS           ?= linux/amd64,linux/arm64

BUILD_ARGS = --build-arg NGINX_VERSION=$(NGINX_VERSION) \
             --build-arg MODSECURITY_VERSION=$(MODSECURITY_VERSION) \
             --build-arg BASE=nginx:$(NGINX_VERSION)-$(FLAVOUR)

.PHONY: help build extract lint test push release clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

build: ## Compile the module into a scratch image (FLAVOUR=bookworm|alpine)
	docker build -f $(DOCKERFILE) $(BUILD_ARGS) -t $(IMAGE):$(VERSION) .

extract: ## Write the module and its library to ./dist
	docker build -f $(DOCKERFILE) $(BUILD_ARGS) --output type=local,dest=./dist .
	@echo "wrote:"; find dist -type f | sed 's/^/  /'

lint: ## Lint both Dockerfiles
	docker run --rm -i hadolint/hadolint < Dockerfile
	docker run --rm -i hadolint/hadolint < Dockerfile.alpine

test: build ## Prove the module loads in a stock nginx of the same version and libc
	./test.sh $(IMAGE):$(VERSION) $(NGINX_VERSION) $(FLAVOUR)

push: build ## Push the artifact image
	docker push $(IMAGE):$(VERSION)

release: ## Build and push multi-arch
	docker buildx build --platform $(PLATFORMS) $(BUILD_ARGS) \
		-t $(IMAGE):$(VERSION) -t $(IMAGE):latest --push .

clean: ## Remove extracted artifacts
	rm -rf dist
