# Getting Started

## Prerequisites

Docker with BuildKit (for `--output`), and the nginx version you intend to run.
That last one is not a formality — the module is tied to it.

## Decide the version first

The module must be built against the same nginx version and the same libc as
the image you load it into. Find out what you are running:

```sh
docker run --rm nginx:1.27.5-bookworm nginx -v
# nginx version: nginx/1.27.5
```

Everything below uses `1.27.5`. Substitute yours.

## Option A — take the files

No registry involved:

```sh
make extract NGINX_VERSION=1.27.5
```

```text
wrote:
  dist/modules/ngx_http_modsecurity_module.so
  dist/lib/libmodsecurity.so.3
  dist/conf/modsecurity.conf
  dist/conf/unicode.mapping
  dist/NGINX_VERSION
  dist/MODSECURITY_VERSION
```

**Take both shared objects.** The module links against `libmodsecurity.so.3`;
copying only `ngx_http_modsecurity_module.so` produces
`libmodsecurity.so.3: cannot open shared object file` at nginx start, which
does not point at the missing half.

## Option B — `COPY --from` in your own image

```dockerfile
FROM fabiocicerchia/nginx-modsecurity-module:3.0.14-nginx1.27.5 AS modsec

FROM nginx:1.27.5-bookworm
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libcurl4 libgeoip1 liblmdb0 libxml2 libyajl2 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=modsec /modules/ngx_http_modsecurity_module.so /usr/lib/nginx/modules/
COPY --from=modsec /lib/                                   /usr/local/modsecurity/lib/
COPY --from=modsec /conf/unicode.mapping                   /etc/nginx/modsecurity/unicode.mapping
COPY --from=modsec /conf/modsecurity.conf                  /etc/nginx/modsecurity/modsecurity.conf
RUN ldconfig /usr/local/modsecurity/lib
```

The runtime packages are the shared libraries libmodsecurity links against —
the `-dev` versions were only needed to build it. `ldconfig` is what makes the
loader find `libmodsecurity.so.3` in a non-standard directory.

The base tag here (`nginx:1.27.5-bookworm`) must match the tag the module was
built against. Assert it rather than remember it:

```dockerfile
COPY --from=modsec /NGINX_VERSION /tmp/NGINX_VERSION
RUN test "$(cat /tmp/NGINX_VERSION)" = "$(nginx -v 2>&1 | sed 's|.*/||')"
```

## Load it

`load_module` must be at the top level of `nginx.conf`, **above** the `events`
block:

```nginx
load_module /usr/lib/nginx/modules/ngx_http_modsecurity_module.so;

events {}

http {
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsecurity/modsecurity.conf;

    server {
        listen 80;
        location / {
            proxy_pass http://backend;
        }
    }
}
```

`modsecurity on` can also be set per `server` or `location`, which is the usual
way to roll it out: on for one path first, not for everything at once.

## The two errors you will hit

**`module ... is not binary compatible`**

```
nginx: [emerg] module "ngx_http_modsecurity_module.so" version 1027005
instead of 1029001 in /etc/nginx/nginx.conf
```

The module was built against a different nginx. Rebuild with the matching
`NGINX_VERSION`.

**`Error loading shared library`**

The libc does not match — usually a glibc-built module dropped into
`nginx:alpine`. There is no flag for this; build against an Alpine base
instead:

```sh
make build NGINX_VERSION=1.27.5 BASE=nginx:1.27.5-alpine
```

## Rules are yours

No rule set is bundled. `modsecurity.conf` configures the *engine* — parsing
limits, body handling, logging — and contains no detection rules at all, so the
setup above blocks nothing yet.

Add the OWASP Core Rule Set when you want detection:

```dockerfile
ADD https://github.com/coreruleset/coreruleset/archive/refs/tags/v4.7.0.tar.gz /tmp/crs.tar.gz
RUN mkdir -p /etc/nginx/modsecurity/crs \
 && tar -xz --strip-components=1 -f /tmp/crs.tar.gz -C /etc/nginx/modsecurity/crs \
 && mv /etc/nginx/modsecurity/crs/crs-setup.conf.example \
       /etc/nginx/modsecurity/crs/crs-setup.conf
```

```nginx
# appended to modsecurity.conf
Include /etc/nginx/modsecurity/crs/crs-setup.conf
Include /etc/nginx/modsecurity/crs/rules/*.conf
```

Start in detection mode — `SecRuleEngine DetectionOnly` — and read the audit
log for a week before switching to `On`. CRS at its default paranoia level will
flag legitimate traffic, and a WAF that blocked a customer in week one gets
disabled in week two.

## Development

```sh
make build NGINX_VERSION=1.27.5     # compile into a scratch image
make extract NGINX_VERSION=1.27.5   # write the files to ./dist
make lint                           # hadolint
make test                           # loads the module into a stock nginx
make release                        # multi-arch buildx push
make clean                          # rm -rf dist
```

`make test` is the one that matters: it starts a stock nginx of the target
version with the module loaded. Compiling proves nothing here — the failure
mode is a module that builds and will not load.
