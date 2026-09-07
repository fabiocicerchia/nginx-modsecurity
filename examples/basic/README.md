# Basic Example

What it shows: the module loaded into a stock nginx, blocking a request — and
a build that fails if the nginx versions ever drift apart.

## Run

```sh
docker build -t modsec-demo .
docker run --rm -p 8080:80 modsec-demo
```

If nginx starts and prints nothing alarming, the module loaded. That is the
step that fails in practice; compiling is the easy part.

## Watch it block

```sh
curl -i 'http://localhost:8080/?testparam=hello'    # 200 ok
curl -i 'http://localhost:8080/?testparam=blocked'  # 403
```

```sh
curl -i 'http://localhost:8080/unprotected/?testparam=blocked'  # 200
```

The third one shows `modsecurity off` in a `location` — which is how a rollout
should start: on for one path, not for the whole site on day one.

## What is load-bearing in the Dockerfile

**Both shared objects are copied.** The module links against
`libmodsecurity.so.3`. Comment out the `/lib/` line and rebuild:

```text
nginx: [emerg] dlopen() ".../ngx_http_modsecurity_module.so" failed
(libmodsecurity.so.3: cannot open shared object file: No such file or directory)
```

Nothing in that message says "you took half the artifact".

**`ldconfig` runs.** The library is in `/usr/local/modsecurity/lib`, which is
not on the default search path. Skip it and you get the same error with both
files present.

**The version assertion is a build step.** `test "$(cat /NGINX_VERSION)" = ...`
fails the build if the module tag and the base tag stop matching. Without it
the mismatch shows up at container start:

```text
nginx: [emerg] module ... version 1027005 instead of 1029001 — not binary compatible
```

**`load_module` is above `events`.** It is a top-level directive; inside `http`
it is a syntax error.

## Add real rules

`modsecurity.conf` configures the engine and ships **no detection rules** — the
one rule in this example is appended by the Dockerfile so there is something to
see. For actual protection, add the OWASP Core Rule Set:

```dockerfile
ADD https://github.com/coreruleset/coreruleset/archive/refs/tags/v4.7.0.tar.gz /tmp/crs.tar.gz
RUN mkdir -p /etc/nginx/modsecurity/crs \
 && tar -xz --strip-components=1 -f /tmp/crs.tar.gz -C /etc/nginx/modsecurity/crs \
 && mv /etc/nginx/modsecurity/crs/crs-setup.conf.example \
       /etc/nginx/modsecurity/crs/crs-setup.conf \
 && printf '%s\n%s\n' \
      'Include /etc/nginx/modsecurity/crs/crs-setup.conf' \
      'Include /etc/nginx/modsecurity/crs/rules/*.conf' \
      >> /etc/nginx/modsecurity/modsecurity.conf
```

Set `SecRuleEngine DetectionOnly` first and read the audit log for a week. CRS
at its default paranoia level flags legitimate traffic, and a WAF that blocked
a customer in week one is a WAF that is switched off in week two.

## Different nginx, different artifact

```sh
# in the repo root
make build NGINX_VERSION=1.29.1
```

Then change both the `FROM ... AS modsec` tag and the `FROM nginx:` tag in this
Dockerfile. The assertion catches you if you change only one.
