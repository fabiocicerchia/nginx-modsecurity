# nginx-modsecurity

[![CI](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/ci.yml/badge.svg)](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/ci.yml)
[![Code Quality](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/code-quality.yml/badge.svg)](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/code-quality.yml)
[![Security](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/security.yml/badge.svg)](https://github.com/fabiocicerchia/nginx-modsecurity/actions/workflows/security.yml)
[![License](https://img.shields.io/badge/license-Apache_2.0-blue.svg)](LICENSE)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/fabiocicerchia/nginx-modsecurity/badge)](https://securityscorecards.dev/viewer/?uri=github.com/fabiocicerchia/nginx-modsecurity)
[![CI carbon](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/fabiocicerchia/nginx-modsecurity/gh-pages/badge.json)](.github/workflows/carbon-badge.yml)

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

## glibc or musl

The module is a compiled artifact, so it can only be loaded into a runtime with
the same libc. Both are built:

```sh
make build                    # glibc  -> 3.0.14-nginx1.27.5
make build FLAVOUR=alpine     # musl   -> 3.0.14-nginx1.27.5-alpine
```

The flavour is in the tag rather than left for a consumer to remember, because
getting it wrong fails at nginx startup with `Error loading shared library`,
which does not say which libc it wanted.

**What the musl variant is worth.** The artifact itself is the same size — it
is mostly `libmodsecurity.so.3` either way. The saving is in the image you load
it into:

| runtime with the module | size |
|---|---|
| `nginx:1.27.5-bookworm` | 364 MB |
| `nginx:1.27.5-alpine` | **158 MB** |

206 MB, or 57%, measured on the images the test suite builds.

### Two things musl needs that Debian does not

**`libstdc++`.** ModSecurity is C++ and Alpine's nginx image does not ship the
runtime, so the module loads and then fails on
`libstdc++.so.6: No such file or directory`.

**The library path is a file, not `ldconfig`.** musl reads
`/etc/ld-musl-<arch>.path`, and that file does not exist by default. Creating
it **replaces** the built-in search path rather than adding to it, so it has to
list the defaults too:

```dockerfile
RUN printf '%s\n' /lib /usr/local/lib /usr/lib /usr/local/modsecurity/lib \
      > "/etc/ld-musl-$(uname -m).path"
```

Appending a bare line to it — the obvious thing — leaves nginx unable to find
its own `libssl`, and the errors point at nginx rather than at what changed.
Both are in `test.sh`, which is the copy worth following.

## Supported nginx versions

`versions.json` is the source of truth. CI builds and tests **every** version in
it, and the published tag names the nginx version the module was compiled
against:

| nginx | channel | tag |
|---|---|---|
| 1.28.0 | stable | `3.0.14-nginx1.28.0` |
| 1.27.5 | mainline | `3.0.14-nginx1.27.5` — also `latest` |
| 1.26.3 | oldstable | `3.0.14-nginx1.26.3` |

Every version is built for both libcs; the musl tag is the same name with
`-alpine` appended, e.g. `3.0.14-nginx1.28.0-alpine`.

The tag names the version because loading a module into a different one fails
at startup with `module ... is not binary compatible`, which does not say that
is what happened. `latest` follows the default version only — a rolling tag
that moved with whichever matrix job finished last would be a different nginx
each week.

Adding a version is one edit to `versions.json`: the checksum there is the same
one the Dockerfile verifies before unpacking, so a version cannot be built
without one.

## Staying current

A security image going stale is the failure that matters here: the module is
compiled against a base that receives CVE fixes, and a build from six months
ago ships whatever was vulnerable then.

`rebuild.yml` has three triggers, because there are three ways this goes stale:

- **Weekly schedule** — picks up the base image's security updates without
  anyone reading an advisory.
- **`repository_dispatch` with type `cve`** — any watcher can fire a rebuild
  the moment an advisory lands:

  ```sh
  gh api repos/OWNER/REPO/dispatches -f event_type=cve \
    -f 'client_payload[reason]=CVE-2026-XXXX in libmodsecurity'
  ```

- **Manual dispatch** — someone read the advisory email first.

Every rebuild runs the full test suite before it pushes: a rebuild that
publishes a module which does not load is worse than a stale one that does.
Publishing is conditional on the registry credential existing, so a fork still
gets the useful half — an early warning that the current base no longer builds.
