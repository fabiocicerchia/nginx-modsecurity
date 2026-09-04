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
# Overridable so one checkout can build every supported version — CI passes
# these from versions.json, which is where the set is defined.
#
# The base is pinned by digest, read out of versions.json so the pin lives
# beside the version it belongs to rather than in a second list that has to
# agree with the first. A tag alone lets the base move under a rebuild, which
# is the whole point of pinning it -- but it degrades to the bare tag when jq
# is missing or the entry carries no digest, so a checkout without jq still
# builds. `make build BASE_DIGEST=` opts out deliberately; rebuild.yml does
# exactly that, because tracking the moving tag is its reason to exist.
BASE_DIGEST         ?= $(shell jq -r --arg v '$(NGINX_VERSION)' --arg f '$(FLAVOUR)' \
                         '.supported[] | select(.nginx == $$v) | .digest[$$f] // empty' \
                         versions.json 2>/dev/null)
BASE                ?= nginx:$(NGINX_VERSION)-$(FLAVOUR)$(if $(BASE_DIGEST),@$(BASE_DIGEST),)
NGINX_SHA256        ?=

BUILD_ARGS = --build-arg NGINX_VERSION=$(NGINX_VERSION) \
             --build-arg MODSECURITY_VERSION=$(MODSECURITY_VERSION) \
             --build-arg BASE=$(BASE) \
             $(if $(NGINX_SHA256),--build-arg NGINX_SHA256=$(NGINX_SHA256),)

.PHONY: help build extract lint test test-crs report push release clean print-image print-version

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

# Separate from `test` on purpose: this one downloads the rule set, so it needs
# the network and takes noticeably longer. `test` stays the fast answer to
# "does the module load".
test-crs: build ## ...and that the OWASP CRS loads into it and actually blocks
	./test-crs.sh $(IMAGE):$(VERSION) $(NGINX_VERSION) $(FLAVOUR)

# The two numbers a consumer asks about before adopting an artifact, measured
# rather than claimed. Writes to $$GITHUB_STEP_SUMMARY when there is one, so
# every CI run leaves the record rather than one committed file going stale.
report: ## Measure build time and image size for the current version
	@./report.sh $(IMAGE) $(VERSION) $(DOCKERFILE) $(NGINX_VERSION) $(FLAVOUR) \
		$(MODSECURITY_VERSION) $(BASE) $(NGINX_SHA256)

push: build ## Push the artifact image
	docker push $(IMAGE):$(VERSION)

release: ## Build and push multi-arch
	docker buildx build -f $(DOCKERFILE) --platform $(PLATFORMS) $(BUILD_ARGS) \
		-t $(IMAGE):$(VERSION) -t $(IMAGE):latest --push .

clean: ## Remove extracted artifacts
	rm -rf dist

# Machine-readable, for CI: the tag scheme lives here rather than being
# duplicated into a workflow where it can drift from what `make push` builds.
print-image: ## Print the image name
	@echo $(IMAGE)

print-version: ## Print the tag for the current NGINX_VERSION
	@echo $(VERSION)
