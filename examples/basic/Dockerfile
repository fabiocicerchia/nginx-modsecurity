# A stock nginx with the ModSecurity module loaded, and nothing else adopted.
#
# The base tag and the module tag name the same nginx version. They have to:
# --with-compat makes the module loadable by a binary built elsewhere, not by a
# different version.
FROM ghcr.io/fabiocicerchia/nginx-modsecurity-module:3.0.16-nginx1.31.4 AS modsec

FROM nginx:1.31.4@sha256:b34848eff6db786b6b1282d3a9c3fd0b5563dfb6d261df4923378b419e0d24f0
# The version-drift check below pipes into sed; without pipefail a failing
# `nginx -v` would leave an empty string that silently compares unequal.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The runtime halves of what libmodsecurity links against. The -dev packages
# were only needed to build it. Unpinned on purpose: the digest on FROM pins
# the base, and exact Debian versions vanish on the next security update.
# kics-scan ignore-block
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libcurl4 libgeoip1 liblmdb0 libxml2 libyajl2 \
 && rm -rf /var/lib/apt/lists/*

# Both shared objects. Copying only the module gives you
# "libmodsecurity.so.3: cannot open shared object file" at start-up.
COPY --from=modsec /modules/ngx_http_modsecurity_module.so /usr/lib/nginx/modules/
COPY --from=modsec /lib/                                   /usr/local/modsecurity/lib/
COPY --from=modsec /conf/unicode.mapping                   /etc/nginx/modsecurity/unicode.mapping
COPY --from=modsec /conf/modsecurity.conf                  /etc/nginx/modsecurity/modsecurity.conf

# Make the loader find libmodsecurity.so.3 in a non-standard directory.
RUN ldconfig /usr/local/modsecurity/lib

# Fail the build, not the container start, if the versions ever drift apart.
COPY --from=modsec /NGINX_VERSION /tmp/NGINX_VERSION
RUN test "$(cat /tmp/NGINX_VERSION)" = "$(nginx -v 2>&1 | sed 's|.*/||')" \
 && rm /tmp/NGINX_VERSION

# One demo rule, so the example blocks something observable. modsecurity.conf
# configures the engine and contains no detection rules of its own.
RUN printf '%s\n' \
  'SecRule ARGS:testparam "@contains blocked" "id:1001,phase:2,deny,status:403,msg:demo rule"' \
  >> /etc/nginx/modsecurity/modsecurity.conf

COPY nginx.conf /etc/nginx/nginx.conf

# Unprivileged: nginx.conf listens on 8080 and keeps its pid and temp files in
# /tmp, the only places the nginx user can write.
USER nginx
HEALTHCHECK CMD ["curl", "-fsS", "-o", "/dev/null", "http://127.0.0.1:8080/"]
