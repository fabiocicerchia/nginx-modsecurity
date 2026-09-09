# The artifact is the module, not an image. `build` produces a scratch image
# holding it; `extract` writes it to ./dist for consumers who would rather have
# files than a registry.
IMAGE               ?= fabiocicerchia/nginx-modsecurity-module
NGINX_VERSION       ?= 1.27.5
MODSECURITY_VERSION ?= 3.0.16
# debian (glibc) or alpine (musl). The module can only be loaded into a
# runtime with the same libc, so the flavour is part of the tag rather than
# something a consumer has to remember.
#
# `debian` builds on the bare `nginx:<version>` tag, not on `-bookworm`: the
# codename tag is retired when Debian moves on, so `nginx:1.31.4-bookworm`
# simply does not exist. The bare tag is the Debian variant for every version
# past and future, and resolves to the same digest as the codename tag did.
FLAVOUR             ?= debian
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
BASE_TAG            ?= nginx:$(NGINX_VERSION)$(if $(filter alpine,$(FLAVOUR)),-alpine,)
BASE                ?= $(BASE_TAG)$(if $(BASE_DIGEST),@$(BASE_DIGEST),)
NGINX_SHA256        ?=

BUILD_ARGS = --build-arg NGINX_VERSION=$(NGINX_VERSION) \
             --build-arg MODSECURITY_VERSION=$(MODSECURITY_VERSION) \
             --build-arg BASE=$(BASE) \
             $(if $(NGINX_SHA256),--build-arg NGINX_SHA256=$(NGINX_SHA256),)

# FC-GEN-057: the same eight verbs in every repo, each either wired or a
# declared no-op that says why. None of them exit 0 quietly.
.DEFAULT_GOAL := help

.PHONY: help setup install build run extract lint format analyze test test-crs \
        report push release clean print-image print-version print-base

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

setup: ## Install the pre-commit hook
	pre-commit install

install: ## Pull the published artifact image onto this machine
	docker pull $(IMAGE):$(VERSION)

# --- Declared no-op (FC-GEN-058) ---

run: ## Not applicable — the artifact is a module, not a program
	@echo "Nothing to run: the image is a scratch image holding a .so, so it has"
	@echo "no entrypoint. 'make test' loads the module into a stock nginx, and"
	@echo "'make extract' writes the files to ./dist. See README > Not applicable."

build: ## Compile the module into a scratch image (FLAVOUR=debian|alpine)
	docker build -f $(DOCKERFILE) $(BUILD_ARGS) -t $(IMAGE):$(VERSION) .

extract: ## Write the module and its library to ./dist
	docker build -f $(DOCKERFILE) $(BUILD_ARGS) --output type=local,dest=./dist .
	@echo "wrote:"; find dist -type f | sed 's/^/  /'

lint: ## Run the whole gate — every hook, every file
	pre-commit run --all-files

format: ## Rewrite what the gate can fix: whitespace, line endings, final newline
	@# A fixing hook exits 1 when it rewrites a file. That is this target doing
	@# its job, not failing, so the exits are ignored — make still prints what
	@# each hook said.
	-pre-commit run --all-files trailing-whitespace
	-pre-commit run --all-files end-of-file-fixer
	-pre-commit run --all-files mixed-line-ending

analyze: ## Scan the tree the way CI does — vulnerabilities, misconfig, secrets
	@command -v trivy >/dev/null 2>&1 || { \
		echo "analyze needs trivy: https://trivy.dev/latest/getting-started/installation/" >&2; \
		exit 69; }
	trivy fs --scanners vuln,misconfig,secret --severity CRITICAL,HIGH .

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

print-base: ## Print the base image tag this FLAVOUR builds against
	@echo $(BASE_TAG)
