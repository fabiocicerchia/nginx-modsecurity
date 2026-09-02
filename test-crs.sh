#!/usr/bin/env sh
# The other half of test.sh: prove the module works with the rule set people
# will actually load into it.
#
# test.sh deliberately uses ONE hand-written rule, so that it tests the module
# and not the CRS being present. That is the right shape for a smoke test, and
# it leaves a real gap: the OWASP Core Rule Set is what every consumer of this
# artifact puts in front of it, it is far larger than anything hand-written,
# and it uses features — anomaly scoring, transformations, `SecRuleUpdate`,
# libinjection operators — that a single `@streq` never touches. A module that
# loads and runs one rule can still fall over on the rules that matter.
#
# So this runs the CRS at paranoia level 1 and asserts, per attack class, that
# a known-bad request is refused and a clean one is not. Both halves matter:
# a WAF that blocks everything is as broken as one that blocks nothing, and
# only the negative case catches it.
set -eu

ARTIFACT="${1:?usage: test-crs.sh <artifact-image:tag> <nginx-version> [flavour]}"
NGINX_VERSION="${2:?usage: test-crs.sh <artifact-image:tag> <nginx-version> [flavour]}"
FLAVOUR="${3:-bookworm}"

# Pinned, and verified by digest before it is unpacked — this image exists to
# verify other people's supply chains, so it does not get to be sloppy about
# its own. # VERSION-BUMP
CRS_VERSION="${CRS_VERSION:-4.29.0}"
CRS_SHA256="${CRS_SHA256:-1aa1c5c8fc29e532d35293bcea36bf72de61db8f6ed4716a0f91ab14552b7fed}"
CRS_URL="https://github.com/coreruleset/coreruleset/releases/download/v${CRS_VERSION}/coreruleset-${CRS_VERSION}-minimal.tar.gz"

PORT="${PORT:-18083}"
NAME=modsec-crs-test

WORK="$(mktemp -d)"
cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  [ -n "${WORK:-}" ] && [ -d "$WORK" ] && rm -rf -- "$WORK"
}
trap cleanup EXIT

echo "==> fetching CRS ${CRS_VERSION}"
curl -fsSL --retry 3 --retry-delay 2 "$CRS_URL" -o "$WORK/crs.tar.gz"
echo "${CRS_SHA256}  ${WORK}/crs.tar.gz" | sha256sum -c - >/dev/null
mkdir -p "$WORK/crs"
tar -xzf "$WORK/crs.tar.gz" -C "$WORK/crs" --strip-components=1
cp "$WORK/crs/crs-setup.conf.example" "$WORK/crs/crs-setup.conf"

# NOT `return 200`, and this is the whole reason the first run of this script
# reported every attack as a 200 with 840 rules loaded and not one rule line in
# the error log.
#
# `return` is a REWRITE-phase directive: it answers the request before the
# preaccess phase, which is where ModSecurity-nginx runs its phase-2 handler.
# Every CRS blocking rule is phase:2 — 949110 evaluates the anomaly score there
# — so the whole rule set was loaded, parsed, and never consulted.
#
# test.sh gets away with `return 200` because its single hand-written rule is
# phase:1, which runs in the rewrite phase and does fire. That is exactly the
# kind of gap a one-rule smoke test cannot see, and finding it is what this
# script is for.
cat > "$WORK/nginx.conf" <<'CONF'
load_module /usr/lib/nginx/modules/ngx_http_modsecurity_module.so;
events {}
http {
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsecurity/main.conf;
    server {
        listen 80;
        root /var/www/crs-test;
        location / { index index.html; }
    }
}
CONF

# The engine settings CRS expects, then crs-setup, then the rules. Order is
# load-bearing: crs-setup defines the tx variables the rules read, and the 949
# blocking rule has to come after everything that scores.
cat > "$WORK/main.conf" <<'CONF'
SecRuleEngine On
SecRequestBodyAccess On
SecRequestBodyLimit 131072
SecRequestBodyNoFilesLimit 131072
SecRequestBodyLimitAction Reject
SecUnicodeMapFile unicode.mapping 20127
SecDebugLogLevel 0
SecAuditEngine Off

# NO SecDefaultAction here. crs-setup.conf sets one per phase, all `pass`, and
# a second set in the same context is refused outright:
#
#   SecDefaultActions can only be placed once per phase and configuration
#   context. Phase 1 was informed already.
#
# `pass` is also the correct setting, not a concession to that error. Anomaly
# scoring is CRS's whole design: individual rules ADD to a score and pass, and
# rule 949110 carries its own explicit `deny,status:403` for when the total
# crosses the threshold. Making every rule deny would block on the first match
# instead of at the threshold — which is not how anyone runs CRS, and would
# make this test pass for the wrong reason.
Include /etc/nginx/modsecurity/crs/crs-setup.conf
Include /etc/nginx/modsecurity/crs/rules/*.conf
CONF

if [ "$FLAVOUR" = "alpine" ]; then
  cat > "$WORK/Dockerfile" <<CONF
FROM ${ARTIFACT} AS module
FROM nginx:${NGINX_VERSION}-alpine
RUN apk add --no-cache libstdc++ libcurl geoip lmdb libxml2 yajl
COPY --from=module /modules/ngx_http_modsecurity_module.so /usr/lib/nginx/modules/
COPY --from=module /lib/ /usr/local/modsecurity/lib/
COPY --from=module /conf/unicode.mapping /etc/nginx/modsecurity/unicode.mapping
RUN printf '%s\\n' /lib /usr/local/lib /usr/lib /usr/local/modsecurity/lib \\
      > "/etc/ld-musl-\$(uname -m).path"
# A real document root, served through the content phase, so the request
# actually reaches ModSecurity's phase-2 handler. app.min.js exists because one
# of the negative cases asks for a path with a dot in it.
RUN mkdir -p /var/www/crs-test/assets \\
 && printf 'ok\\n' > /var/www/crs-test/index.html \\
 && printf 'ok\\n' > /var/www/crs-test/assets/app.min.js
COPY nginx.conf /etc/nginx/nginx.conf
COPY main.conf /etc/nginx/modsecurity/main.conf
COPY crs/ /etc/nginx/modsecurity/crs/
CONF
else
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
# A real document root, served through the content phase, so the request
# actually reaches ModSecurity's phase-2 handler. app.min.js exists because one
# of the negative cases asks for a path with a dot in it.
RUN mkdir -p /var/www/crs-test/assets \\
 && printf 'ok\\n' > /var/www/crs-test/index.html \\
 && printf 'ok\\n' > /var/www/crs-test/assets/app.min.js
COPY nginx.conf /etc/nginx/nginx.conf
COPY main.conf /etc/nginx/modsecurity/main.conf
COPY crs/ /etc/nginx/modsecurity/crs/
CONF
fi

echo "==> building the test image"
docker build -q -t "$NAME" "$WORK" >/dev/null

# `nginx -t` parses every CRS rule. A rule the engine cannot compile fails
# here, with the file and line, rather than at the first request that hits it.
echo "==> nginx -t with the full rule set"
docker run --rm "$NAME" nginx -t

docker run -d --rm --name "$NAME" -p "${PORT}:80" "$NAME" >/dev/null

# Retry rather than sleep: loading 29 rule files takes noticeably longer than
# the one-rule config in test.sh, and a fixed sleep would either be flaky or
# be a wasted five seconds on every run.
ready=0
i=0
while [ "$i" -lt 60 ]; do
  if curl -fsS -o /dev/null --max-time 2 "http://127.0.0.1:${PORT}/" 2>/dev/null; then
    ready=1
    break
  fi
  i=$((i + 1))
  sleep 0.5
done
[ "$ready" = 1 ] || {
  echo "FAIL: nginx never came up with the CRS loaded" >&2
  docker logs "$NAME" 2>&1 | tail -30 >&2
  exit 1
}

code() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@"; }

fails=0
check() { # check <expected> <label> <curl args...>
  want="$1"
  label="$2"
  shift 2
  got="$(code "$@")"
  if [ "$got" = "$want" ]; then
    printf '  ok    %-42s %s\n' "$label" "$got"
  else
    printf '  FAIL  %-42s got %s, want %s\n' "$label" "$got" "$want"
    fails=$((fails + 1))
  fi
}

echo "==> known-bad requests must be refused"
# One per attack class, chosen so each is scored by a different CRS rule file.
# If only one of these fires, the engine is running but something in the
# transformation or operator path is not.
check 403 "SQLi (942)" "http://127.0.0.1:${PORT}/?id=1%27%20OR%20%271%27%3D%271"
check 403 "XSS (941)" "http://127.0.0.1:${PORT}/?q=%3Cscript%3Ealert(1)%3C/script%3E"
check 403 "LFI (930)" "http://127.0.0.1:${PORT}/?file=../../../../etc/passwd"
check 403 "RCE (932)" "http://127.0.0.1:${PORT}/?cmd=;cat%20/etc/passwd"
check 403 "scanner UA (913)" --user-agent "nikto/2.1.6" "http://127.0.0.1:${PORT}/"

echo "==> ordinary requests must not be"
# The half that catches a WAF blocking everything, which is as broken as one
# blocking nothing and much easier to ship by accident.
check 200 "plain GET" "http://127.0.0.1:${PORT}/"
check 200 "query string with punctuation" "http://127.0.0.1:${PORT}/?q=hello%20world%21"
check 200 "an ordinary browser UA" \
  --user-agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36" \
  "http://127.0.0.1:${PORT}/"
check 200 "a path with a dot in it" "http://127.0.0.1:${PORT}/assets/app.min.js"

if [ "$fails" -ne 0 ]; then
  echo "FAIL: $fails CRS check(s) did not behave as expected" >&2
  echo "--- nginx error log ---" >&2
  docker logs "$NAME" 2>&1 | tail -40 >&2
  exit 1
fi

echo "PASS: CRS ${CRS_VERSION} loads and blocks under nginx ${NGINX_VERSION} (${FLAVOUR})"
