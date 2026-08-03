# nginx-modsecurity

The **ModSecurity v3 dynamic module for nginx, as an artifact** — a `.so` you
load into your own nginx, not another nginx image to adopt.

Shipping a whole WAF image means inheriting someone else's nginx: their base,
their version, their config layout, their patch cadence. This ships the part you
cannot easily build yourself and leaves the rest alone.

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

## Two things that will bite you

**It is two shared objects, not one.** `ngx_http_modsecurity_module.so` links
against `libmodsecurity.so.3`. Copy only the module and nginx starts with
`libmodsecurity.so.3: cannot open shared object file`, which does not obviously
point at the missing half. Both are in the artifact — copy both, and run
`ldconfig` over the library directory.

**The module is tied to the nginx version and the libc.** `--with-compat` makes
a module loadable by a binary built elsewhere; it does not make it
version-independent. nginx refuses a mismatch with `module ... is not binary
compatible`, and a glibc build dropped into `nginx:alpine` fails with `Error
loading shared library`. Build with `NGINX_VERSION` and `BASE` matching the
target:

```sh
make build NGINX_VERSION=1.27.5     # then load it into nginx:1.27.5-*
```

The artifact records what it was built against at `/NGINX_VERSION` and
`/MODSECURITY_VERSION`, so a consumer can check rather than guess.

## Rules are yours

No rule set is bundled. The OWASP Core Rule Set is the usual choice and is one
`COPY` away, but which rules run, at what paranoia level, with which exclusions,
is a decision about your traffic — baking one in would be an opinion pretending
to be a default.

`conf/modsecurity.conf` is a minimal starting point: engine on, no rules. Add
the CRS after it.

## Test

```sh
make test NGINX_VERSION=1.27.5
```

Builds the module, loads it into a stock nginx of that version, runs `nginx -t`,
and fires one request a single rule should block. Compiling proves nothing here
— a module built against the wrong version compiles cleanly and fails at
startup — so this is a load test, not a build test.

**Not yet run.** The Docker daemon was unavailable on the machine this was
converted on. The build and the test are written and shell-checked; neither has
executed.

## Status

- [x] Build the module and libmodsecurity as a standalone artifact
- [x] `scratch` output, so it cannot be mistaken for a runnable image
- [x] Load test against a stock nginx of the matching version
- [ ] Run the build and the test on a machine with Docker
- [ ] Replace the stub `unicode.mapping` with the full upstream file in CI
- [ ] Matrix build across supported nginx versions; rebuild on CVEs
- [ ] Alpine/musl variant

## Development

`make build` / `make extract` / `make lint` / `make test` / `make release`.

## License

Apache-2.0 (packaging) — see [LICENSE](LICENSE). nginx is BSD-2, ModSecurity is
Apache-2.0.
