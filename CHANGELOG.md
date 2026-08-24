# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0](https://github.com/fabiocicerchia/nginx-modsecurity/compare/v1.0.2...v1.1.0) (2026-08-24)


### Features

* **build:** musl/Alpine variant, linked and proven to load ([#25](https://github.com/fabiocicerchia/nginx-modsecurity/issues/25)) ([eb777f1](https://github.com/fabiocicerchia/nginx-modsecurity/commit/eb777f1950e22de4b091f057864be754d36cd171))
* **ci:** build every supported nginx version, and rebuild when it goes stale ([#24](https://github.com/fabiocicerchia/nginx-modsecurity/issues/24)) ([03a7cde](https://github.com/fabiocicerchia/nginx-modsecurity/commit/03a7cdee8db2de9c2d6a79387697c26b5f6874b6))

## [1.0.2](https://github.com/fabiocicerchia/nginx-modsecurity/compare/v1.0.1...v1.0.2) (2026-08-13)


### Bug Fixes

* security and code-quality findings ([#22](https://github.com/fabiocicerchia/nginx-modsecurity/issues/22)) ([63f1672](https://github.com/fabiocicerchia/nginx-modsecurity/commit/63f1672d57f00c6b27990651e4db348dccb4674c))

## [1.0.1](https://github.com/fabiocicerchia/nginx-modsecurity/compare/v1.0.0...v1.0.1) (2026-08-11)


### Bug Fixes

* ship the real unicode.mapping and verify every download ([aa58bce](https://github.com/fabiocicerchia/nginx-modsecurity/commit/aa58bce5ea306ef309af599e4ce314adafd31cea))

## 1.0.0 (2026-08-06)


### Bug Fixes

* **ci:** stop security workflows failing on private repos ([#7](https://github.com/fabiocicerchia/nginx-modsecurity/issues/7)) ([81256fc](https://github.com/fabiocicerchia/nginx-modsecurity/commit/81256fc67e111bede7fdbae0b4841c55bb8621e7))
* point --add-dynamic-module at the real extracted directory ([98c8b03](https://github.com/fabiocicerchia/nginx-modsecurity/commit/98c8b036be2c57a124a452e07b71b5aa52a13397))
* point --add-dynamic-module at the real extracted directory ([3882be2](https://github.com/fabiocicerchia/nginx-modsecurity/commit/3882be222b0f85718f9c1827c92e295f54cd3cf5))
* **pre-commit:** stop check-yaml failing on Helm templates and multi-doc manifests ([ebfee49](https://github.com/fabiocicerchia/nginx-modsecurity/commit/ebfee49eef41815914907658561a423e91ab67f9))
* set pipefail in the basic example (DL4006) ([10cbc30](https://github.com/fabiocicerchia/nginx-modsecurity/commit/10cbc30668ed641087ccce9daeeb4c26bc4ff173))

## [Unreleased]

### Added

- ModSecurity v3 dynamic module built as an artifact: the `.so`, its
  `libmodsecurity.so.3`, a recommended `modsecurity.conf` and
  `unicode.mapping`, tagged by ModSecurity and nginx version.
- `make extract` to take the files without a registry.

Not yet released.
