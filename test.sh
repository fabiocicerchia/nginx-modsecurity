#!/usr/bin/env sh
# The only test that matters for a dynamic module: does a stock nginx of the
# target version load it, and does the engine then actually inspect a request?
#
# Building proves nothing. A module compiled against the wrong nginx version, or
# against a different libc, compiles cleanly and fails at startup with "module
# ... is not binary compatible" or "Error loading shared library". Both are
# caught here and nowhere earlier.
set -eu
ARTIFACT="${1:?usage: test.sh <artifact-image:tag> <nginx-version>}"
NGINX_VERSION="${2:?usage: test.sh <artifact-image:tag> <nginx-version>}"

WORK="$(mktemp -d)"
cleanup() {
  docker rm -f modsec-lib-test >/dev/null 2>&1 || true
  [ -n "${WORK:-}" ] && [ -d "$WORK" ] && rm -rf -- "$WORK"
}
trap cleanup EXIT

cat > "$WORK/nginx.conf" <<'CONF'
load_module /usr/lib/nginx/modules/ngx_http_modsecurity_module.so;
events {}
http {
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsecurity/modsecurity.conf;
    server {
        listen 80;
        location / { return 200 "ok\n"; }
    }
}
CONF

# One rule, so the test depends on the engine running rather than on the CRS
# being present — the rule set is the consumer's choice, not the module's.
cat > "$WORK/modsecurity.conf" <<'CONF'
SecRuleEngine On
SecRequestBodyAccess Off
SecUnicodeMapFile unicode.mapping 20127
SecRule ARGS:probe "@streq blocked" "id:1,phase:1,deny,status:403"
CONF

cat > "$WORK/Dockerfile" <<CONF
FROM ${ARTIFACT} AS module
FROM nginx:${NGINX_VERSION}-bookworm
RUN apt-get update \\
 && apt-get install -y --no-install-recommends libcurl4 libgeoip1 liblmdb0 libxml2 libyajl2 \\
 && rm -rf "/var/lib/apt/lists"
COPY --from=module /modules/ngx_http_modsecurity_module.so /usr/lib/nginx/modules/
COPY --from=module /lib/ /usr/local/modsecurity/lib/
COPY --from=module /conf/unicode.mapping /etc/nginx/modsecurity/unicode.mapping
RUN ldconfig /usr/local/modsecurity/lib
COPY nginx.conf /etc/nginx/nginx.conf
COPY modsecurity.conf /etc/nginx/modsecurity/modsecurity.conf
CONF

docker build -q -t modsec-lib-test "$WORK" >/dev/null

# nginx -t exits non-zero and prints the reason when the module will not load,
# which is the failure this exists to catch.
docker run --rm modsec-lib-test nginx -t

docker run -d --rm --name modsec-lib-test -p 18082:80 modsec-lib-test >/dev/null
sleep 2
OK="$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:18082/')"
BLOCKED="$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:18082/?probe=blocked')"

[ "$OK" = "200" ] || { echo "FAIL: clean request returned $OK" >&2; exit 1; }
[ "$BLOCKED" = "403" ] || {
  echo "FAIL: rule did not fire, got $BLOCKED — module loaded but the engine is inert" >&2
  exit 1
}
echo "PASS: module loads in nginx ${NGINX_VERSION} and the engine inspects requests"
