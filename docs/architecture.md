# Architecture

A two-stage Dockerfile whose final stage is `scratch`. The output is not an
image you run; it is a directory of files you take.

```
FROM ${BASE}  (nginx:X-bookworm)  AS build
  ├── build libmodsecurity v3            → /usr/local/modsecurity/lib/libmodsecurity.so.3
  ├── ./configure --with-compat
  │     --add-dynamic-module=ModSecurity-nginx
  │   make modules                       → objs/ngx_http_modsecurity_module.so
  └── stage into /out

FROM scratch
COPY --from=build /out/ /

  /modules/ngx_http_modsecurity_module.so
  /lib/libmodsecurity.so.3
  /conf/modsecurity.conf
  /conf/unicode.mapping
  /NGINX_VERSION
  /MODSECURITY_VERSION
```

## Why `scratch`

A runnable WAF image means adopting someone else's nginx: their base, their
version, their config layout, their patch cadence. That is a large thing to
take on for one module.

A `scratch` final stage cannot be run at all — `docker run` on it fails
immediately — which is the intended message. It exists to be
`COPY --from`'d, or written to disk with `docker build --output`
(`make extract`).

## Two shared objects, and why that is the first thing that goes wrong

`ngx_http_modsecurity_module.so` is the nginx connector. It links against
`libmodsecurity.so.3`, which is the engine and is a separate build.

Copy only the module and nginx starts with:

```
libmodsecurity.so.3: cannot open shared object file: No such file or directory
```

Which does not obviously say "you took half the artifact". Both are in `/lib`
and `/modules`; consumers copy both, and run `ldconfig` over the library
directory so the dynamic loader finds it.

## `--with-compat` does not mean version-independent

This is the second thing that goes wrong.

`--with-compat` makes a module *loadable by a binary built elsewhere* — it
fixes the ABI-signature check that otherwise requires the module to be built by
the exact same `./configure` invocation. It does not decouple the module from
the nginx version:

```
module "..." version 1027005 instead of 1029001 — not binary compatible
```

Nor from the libc. A module built here on a Debian base fails to load into an
`nginx:alpine` with `Error loading shared library`, because musl is not glibc
and the error does not say which of the two problems you have.

Hence `NGINX_VERSION` and `BASE` are build args, and the Makefile derives
`BASE` from `NGINX_VERSION` so they cannot drift apart. Build the artifact
against the nginx you will load it into.

## The artifact records what it was built against

```
/NGINX_VERSION           1.27.5
/MODSECURITY_VERSION     3.0.14
```

Plain files, so a consumer's Dockerfile or CI step can assert rather than
assume:

```dockerfile
RUN test "$(cat /NGINX_VERSION)" = "1.27.5"
```

The image tag carries the same pair (`3.0.14-nginx1.27.5`), and
`org.opencontainers.image.version` repeats it. Three copies of the same fact,
because the failure it prevents is one that appears at nginx start rather than
at build.

## No rule set

`modsecurity.conf` is the recommended engine configuration — the parsing,
limits and logging directives — and nothing else. The OWASP Core Rule Set is
not bundled.

Which rules run, at what paranoia level, with which exclusions, is a decision
about your traffic. Baking one in would be an opinion presented as a default,
and the usual result is CRS at PL1 blocking a legitimate request in week one
and the whole thing being disabled in week two.

CRS is one `COPY` and one `Include` away for anyone who wants it.

## Why the build happens on the nginx image itself

`FROM ${BASE} AS build` where `BASE` is `nginx:1.27.5-bookworm` — the build
runs on the same base the module will be loaded into. That guarantees the libc,
the OpenSSL and the PCRE the module links against are the ones present at
runtime, rather than approximately the ones.

The nginx *source* is downloaded separately, because the image has the binary,
not the source tree the module build needs.

## Bumping versions

1. `make build NGINX_VERSION=1.29.1` — `BASE` follows automatically.
2. `make test` loads the module into a stock nginx of that version. That is the
   only assertion worth having here: a module that compiles and does not load
   is the normal failure, not the exotic one.
3. The tag changes, because the tag *is* the version pair.

`MODSECURITY_VERSION` and `MODSECURITY_NGINX_VERSION` move independently of
nginx; a bump to either is a new tag against the same nginx version.
