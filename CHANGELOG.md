# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial personality definitions: `sre`, `go`, `python`.
- CI workflow to package and push personality OCI artifacts on release.
- Repository setup with devctl (branch protection, Renovate, workflows).

### Changed

- Hardened auto-release tagging flow with semver filtering, retry logic, and release concurrency control.
- Added OCI manifest annotations to published personality artifacts for richer remote discovery in klausctl.

[Unreleased]: https://github.com/giantswarm/klaus-personalities/tree/HEAD
