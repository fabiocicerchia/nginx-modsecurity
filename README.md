# nginx-modsecurity

[![CI](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/ci.yml/badge.svg)](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/ci.yml)
[![Code Quality](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/code-quality.yml/badge.svg)](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/code-quality.yml)
[![Security](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/security.yml/badge.svg)](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/security.yml)
[![License](https://img.shields.io/badge/license-Apache_2.0-blue.svg)](LICENSE)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/fabiocicerchia/nginx-modsecurity/badge)](https://securityscorecards.dev/viewer/?uri=github.com/fabiocicerchia/nginx-modsecurity)

The **ModSecurity v3 dynamic module for nginx, as an artifact** — a `.so` you
load into your own nginx, not another nginx image to adopt.

Shipping a whole WAF image means inheriting someone else's nginx: their base,
their version, their config layout, their patch cadence. This ships the part you
cannot easily build yourself and leaves the rest alone.

## Install

```sh
make build                       # builds fabiocicerchia/nginx-modsecurity-module:$(MODSECURITY_VERSION)-nginx$(NGINX_VERSION) locally
docker pull fabiocicerchia/nginx-modsecurity-module:$(MODSECURITY_VERSION)-nginx$(NGINX_VERSION)
```

## Use it

Copy the module into your own image:

```dockerfile
FROM fabiocicerchia/nginx-modsecurity-module:3.0.14-nginx1.27.5 AS modsec

FROM nginx:1.27.5-bookworm
RUN apt-get update \
 && apt-get install -y --no-install-recommends libcurl4 libgeoip1 liblmdb0 libxml2 libyajl2 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=modsec /modules/ngx_http_modsecurity_module.so /usr/lib/nginx/modules/
COPY --from=modsec /lib/                                   /usr/local/modsecurity/lib/
COPY --from=modsec /conf/unicode.mapping                   /etc/nginx/modsecurity/unicode.mapping
RUN ldconfig /usr/local/modsecurity/lib
```

Then load it, above `events`:

```nginx
load_module /usr/lib/nginx/modules/ngx_http_modsecurity_module.so;

http {
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsecurity/modsecurity.conf;
}
```

Or take the files directly, with no registry involved:

```sh
make extract NGINX_VERSION=1.27.5
# dist/modules/ngx_http_modsecurity_module.so
# dist/lib/libmodsecurity.so.3
# dist/conf/{modsecurity.conf,unicode.mapping}
```

## Documentation

Full docs live in [`docs/`](docs/). Runnable examples live in [`examples/`](examples/).

## License

Apache-2.0 (packaging) — see [LICENSE](LICENSE). nginx is BSD-2, ModSecurity is
Apache-2.0.
