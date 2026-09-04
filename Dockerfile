# nginx-modsecurity — the ModSecurity v3 dynamic module for nginx, as an
# artifact rather than an image.
#
# The final stage is `scratch` and contains nothing but the shared objects and
# the two files ModSecurity needs at runtime. It is not runnable; it exists to
# be COPY --from'd into your own nginx image, or extracted to disk with
# `docker build --output`.
#
# Two shared objects, not one. ngx_http_modsecurity_module.so links against
# libmodsecurity.so.3 — shipping only the module gives you
# "libmodsecurity.so.3: cannot open shared object file" the first time nginx
# starts, which is a confusing way to learn this.
ARG NGINX_VERSION=1.27.5
ARG MODSECURITY_VERSION=3.0.14
ARG MODSECURITY_NGINX_VERSION=1.0.4
# SHA-256 of each source tarball. A pinned version says which artifact is asked
# for; it says nothing about the bytes that arrive. This is a WAF built from
# three network downloads, so every one is verified before it is unpacked.
# Bump these with the versions above — a stale digest fails the build loudly,
# which is the point.
# VERSION-BUMP
ARG NGINX_SHA256=e96acebb9c2a6db8a000c3dd1b32ecba1b810f0cd586232d4d921e376674dd0e
# VERSION-BUMP
ARG MODSECURITY_SHA256=f7599057b35e67ab61764265daddf9ab03c35cee1e55527547afb073ce8f04e8
# VERSION-BUMP
ARG MODSECURITY_NGINX_SHA256=6bdc7570911be884c1e43aaf85046137f9fde0cfa0dd4a55b853c81c45a13313
# The base the module is compiled against. It must match the libc of the image
# you load it into: a module built here on glibc will not load into an
# nginx:alpine, and the error ("Error loading shared library") does not say so.
# Build Dockerfile.alpine for that runtime — `make build FLAVOUR=alpine`.
# VERSION-BUMP
ARG BASE=nginx:1.27.5-bookworm@sha256:6784fb0834aa7dbbe12e3d7471e69c290df3e6ba810dc38b34ae33d3c1c05f7d

FROM ${BASE} AS build
ARG NGINX_VERSION
ARG MODSECURITY_VERSION
ARG MODSECURITY_NGINX_VERSION
ARG NGINX_SHA256
ARG MODSECURITY_SHA256
ARG MODSECURITY_NGINX_SHA256

# Downloads land in a file and are checksummed before they are unpacked, so a
# substituted artifact fails the build instead of being compiled into the WAF.
# pipefail stays on for everything else that pipes.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gcc g++ make automake libtool pkgconf \
      libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre2-dev \
      libxml2-dev libyajl-dev zlib1g-dev libssl-dev \
 && rm -rf /var/lib/apt/lists/*

# libmodsecurity v3 — the engine the nginx connector calls into.
RUN set -eu; \
    curl -fsSLo /tmp/modsecurity.tar.gz \
      "https://github.com/owasp-modsecurity/ModSecurity/releases/download/v${MODSECURITY_VERSION}/modsecurity-v${MODSECURITY_VERSION}.tar.gz"; \
    echo "${MODSECURITY_SHA256}  /tmp/modsecurity.tar.gz" | sha256sum -c -; \
    tar -xz -C /usr/src -f /tmp/modsecurity.tar.gz; \
    rm -f /tmp/modsecurity.tar.gz
WORKDIR /usr/src/modsecurity-v${MODSECURITY_VERSION}
RUN ./build.sh && ./configure --with-pcre2 && make -j"$(nproc)" && make install

# The connector, built against this exact nginx source.
#
# --with-compat is what makes the result loadable by a binary built elsewhere,
# but it does not make it version-independent: nginx refuses a module built
# against a different version with "module ... is not binary compatible". Build
# with NGINX_VERSION set to the version you will load it into.
RUN set -eu; \
    curl -fsSLo /tmp/modsecurity-nginx.tar.gz \
      "https://github.com/owasp-modsecurity/ModSecurity-nginx/releases/download/v${MODSECURITY_NGINX_VERSION}/modsecurity-nginx-v${MODSECURITY_NGINX_VERSION}.tar.gz"; \
    echo "${MODSECURITY_NGINX_SHA256}  /tmp/modsecurity-nginx.tar.gz" | sha256sum -c -; \
    tar -xz -C /usr/src -f /tmp/modsecurity-nginx.tar.gz; \
    curl -fsSLo /tmp/nginx.tar.gz "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"; \
    echo "${NGINX_SHA256}  /tmp/nginx.tar.gz" | sha256sum -c -; \
    tar -xz -C /usr/src -f /tmp/nginx.tar.gz; \
    rm -f /tmp/modsecurity-nginx.tar.gz /tmp/nginx.tar.gz
WORKDIR /usr/src/nginx-${NGINX_VERSION}
RUN ./configure --with-compat --add-dynamic-module="/usr/src/ModSecurity-nginx-v${MODSECURITY_NGINX_VERSION}" \
 && make modules

# Stage the artifact in one place so the final COPY is a single layer and the
# layout is what the consumer sees.
RUN set -eu; \
    mkdir -p /out/modules /out/lib /out/conf; \
    cp "/usr/src/nginx-${NGINX_VERSION}/objs/ngx_http_modsecurity_module.so" /out/modules/; \
    cp -P /usr/local/modsecurity/lib/libmodsecurity.so* /out/lib/; \
    printf '%s\n' "${NGINX_VERSION}" > /out/NGINX_VERSION; \
    printf '%s\n' "${MODSECURITY_VERSION}" > /out/MODSECURITY_VERSION

# unicode.mapping comes out of the verified ModSecurity tarball, not the repo.
# What used to be committed here was a 22-byte placeholder holding a codepage
# header and no mappings at all, while modsecurity.conf activated it via
# SecUnicodeMapFile — so t:urlDecodeUni had no table to fold non-ASCII code
# points onto ASCII with, and every consumer that followed the documented
# COPY --from inherited it. Taking it from the tarball costs no extra trust:
# those bytes are already checksummed above, and they track MODSECURITY_VERSION
# instead of drifting from it.
RUN set -eu; \
    cp "/usr/src/modsecurity-v${MODSECURITY_VERSION}/unicode.mapping" /out/conf/unicode.mapping; \
    [ "$(wc -c < /out/conf/unicode.mapping)" -gt 10000 ] \
      || { echo "unicode.mapping looks like a stub, not the upstream table" >&2; exit 1; }

COPY modsecurity.conf /out/conf/modsecurity.conf
# Apache-2.0 §4(d): the artifact is entirely upstream ModSecurity + nginx, so
# the attribution has to travel inside it.
COPY NOTICE /out/NOTICE

# Nothing but the artifact. `scratch` keeps a consumer from accidentally
# treating this as a runnable image.
FROM scratch
ARG NGINX_VERSION
ARG MODSECURITY_VERSION
ARG MODSECURITY_NGINX_VERSION
LABEL org.opencontainers.image.title="nginx-modsecurity-module" \
      org.opencontainers.image.description="ModSecurity v3 dynamic module for nginx, as a COPY --from artifact. Not runnable." \
      org.opencontainers.image.version="${MODSECURITY_VERSION}-nginx${NGINX_VERSION}" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/fabiocicerchia/nginx-modsecurity"
COPY --from=build /out/ /
