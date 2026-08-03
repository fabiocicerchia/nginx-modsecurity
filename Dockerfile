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
# The base the module is compiled against. It must match the libc of the image
# you load it into: a module built here on glibc will not load into an
# nginx:alpine, and the error ("Error loading shared library") does not say so.
ARG BASE=nginx:1.27.5-bookworm

FROM ${BASE} AS build
ARG NGINX_VERSION
ARG MODSECURITY_VERSION
ARG MODSECURITY_NGINX_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gcc g++ make automake libtool pkgconf \
      libcurl4-openssl-dev libgeoip-dev liblmdb-dev libpcre2-dev \
      libxml2-dev libyajl-dev zlib1g-dev libssl-dev \
 && rm -rf /var/lib/apt/lists/*

# libmodsecurity v3 — the engine the nginx connector calls into.
RUN curl -fsSL "https://github.com/owasp-modsecurity/ModSecurity/releases/download/v${MODSECURITY_VERSION}/modsecurity-v${MODSECURITY_VERSION}.tar.gz" \
      | tar -xz -C /usr/src \
 && cd "/usr/src/modsecurity-v${MODSECURITY_VERSION}" \
 && ./build.sh && ./configure --with-pcre2 && make -j"$(nproc)" && make install

# The connector, built against this exact nginx source.
#
# --with-compat is what makes the result loadable by a binary built elsewhere,
# but it does not make it version-independent: nginx refuses a module built
# against a different version with "module ... is not binary compatible". Build
# with NGINX_VERSION set to the version you will load it into.
RUN curl -fsSL "https://github.com/owasp-modsecurity/ModSecurity-nginx/releases/download/v${MODSECURITY_NGINX_VERSION}/modsecurity-nginx-v${MODSECURITY_NGINX_VERSION}.tar.gz" \
      | tar -xz -C /usr/src \
 && curl -fsSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" | tar -xz -C /usr/src \
 && cd "/usr/src/nginx-${NGINX_VERSION}" \
 && ./configure --with-compat --add-dynamic-module="/usr/src/modsecurity-nginx-v${MODSECURITY_NGINX_VERSION}" \
 && make modules

# Stage the artifact in one place so the final COPY is a single layer and the
# layout is what the consumer sees.
RUN set -eu; \
    mkdir -p /out/modules /out/lib /out/conf; \
    cp "/usr/src/nginx-${NGINX_VERSION}/objs/ngx_http_modsecurity_module.so" /out/modules/; \
    cp -P /usr/local/modsecurity/lib/libmodsecurity.so* /out/lib/; \
    printf '%s\n' "${NGINX_VERSION}" > /out/NGINX_VERSION; \
    printf '%s\n' "${MODSECURITY_VERSION}" > /out/MODSECURITY_VERSION

COPY modsecurity.conf /out/conf/modsecurity.conf
COPY unicode.mapping /out/conf/unicode.mapping

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
