#!/usr/bin/env sh
# Build time and image size, measured rather than claimed.
#
# WHY A SCRIPT AND NOT A COMMITTED FILE: both numbers move with every base
# image bump, every ModSecurity release and every runner change, so a
# `docs/build-report.md` in git would be a stale number that reads like a
# current one. This writes to $GITHUB_STEP_SUMMARY, so the record is attached
# to the run that produced it and to the exact inputs that run used.
#
# The size measured is the ARTIFACT image — a scratch image holding the module
# and its library — which is the thing this repo ships. It is deliberately not
# the size of a runnable nginx: shipping one of those is the thing this project
# exists not to do.
set -eu

IMAGE="${1:?usage: report.sh IMAGE VERSION DOCKERFILE NGINX MODSEC BASE [SHA]}"
VERSION="${2:?}"
DOCKERFILE="${3:?}"
NGINX_VERSION="${4:?}"
FLAVOUR="${5:?}"
MODSECURITY_VERSION="${6:?}"
BASE="${7:?}"
NGINX_SHA256="${8:-}"

REF="${IMAGE}:${VERSION}"

# --no-cache, because a cached build reports the time it took to do nothing.
# That is the number most likely to be quoted and the one least worth having.
set -- build -f "$DOCKERFILE" --no-cache \
  --build-arg "NGINX_VERSION=${NGINX_VERSION}" \
  --build-arg "MODSECURITY_VERSION=${MODSECURITY_VERSION}" \
  --build-arg "BASE=${BASE}"
[ -n "$NGINX_SHA256" ] && set -- "$@" --build-arg "NGINX_SHA256=${NGINX_SHA256}"
set -- "$@" -t "$REF" .

echo "==> timed clean build of ${REF}"
START="$(date +%s)"
docker "$@"
END="$(date +%s)"
SECONDS_TAKEN=$((END - START))

BYTES="$(docker image inspect --format '{{.Size}}' "$REF")"
# Integer MiB with one decimal, without depending on bc or awk's locale.
MIB="$((BYTES / 104857))"
MIB="$((MIB / 10)).$((MIB % 10))"

LAYERS="$(docker image inspect --format '{{len .RootFS.Layers}}' "$REF")"
ARCH="$(docker image inspect --format '{{.Architecture}}' "$REF")"

printf '\n  image        %s\n' "$REF"
printf '  arch         %s\n' "$ARCH"
printf '  size         %s bytes (%s MiB) in %s layer(s)\n' "$BYTES" "$MIB" "$LAYERS"
printf '  build time   %ss (clean, --no-cache)\n\n' "$SECONDS_TAKEN"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  # shellcheck disable=SC2016
  # The backticks are markdown code spans in the summary, not substitutions.
  {
    printf '### Build report — nginx %s (%s)\n\n' "$NGINX_VERSION" "$FLAVOUR"
    printf '| | |\n| --- | --- |\n'
    printf '| image | `%s` |\n' "$REF"
    printf '| base | `%s` |\n' "$BASE"
    printf '| ModSecurity | %s |\n' "$MODSECURITY_VERSION"
    printf '| architecture | %s |\n' "$ARCH"
    printf '| size | %s MiB (%s bytes, %s layer(s)) |\n' "$MIB" "$BYTES" "$LAYERS"
    printf '| clean build time | %ss |\n' "$SECONDS_TAKEN"
    printf '| runner | %s |\n\n' "${RUNNER_NAME:-unknown} / ${RUNNER_OS:-unknown}"
    printf 'Build time is from a `--no-cache` build on a shared CI runner, so treat '
    printf 'it as an order of magnitude rather than a benchmark. The size is the '
    printf 'artifact image — the module and its library on `scratch` — not a runnable nginx.\n'
  } >> "$GITHUB_STEP_SUMMARY"
fi
