# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-03-28
### Added
- Added `-Auto`/`--auto`/`-a` to route non-matching media into label-based subfolders under the configured `-Directory`/`--directory` root (default `noface`), while unlabeled items are moved to the directory root.
- Added `-Group`/`--group`/`-g` to route non-matching media into group-based subfolders under `-Directory` using prioritized YAML definitions in `faceless/labels/*.yaml` (for example `1_People`, `2_Clothing`).
- Added an argparse mutually exclusive mode for `-Auto` and `-Group` so only one output augmenter can be selected per run.
- Added `scripts/Invoke-Build-Faceless-Wheels.ps1` to build wheel/sdist artifacts for distribution with optional `cibuildwheel` support.
- Updated `scripts/Invoke-Build-Faceless-Wheels.ps1` and `mise run build` to prefer the project-local `.venv` interpreter by default.
- Added `scripts/Invoke-Clean-Faceless-Build.ps1` to remove build outputs and common Python build/cache artifacts.
- Added GitHub Actions workflows for CI packaging checks and release publishing with wheel/sdist attachments.
- Added `.github/instructions` agent guidance for release cutting and semantic version bump decisions.
- Added `scripts/Invoke-Bump-Faceless-Version.ps1` to recommend/apply semantic version bumps from the changelog.

### Fixed
- Fixed `-Auto` label name resolution so class folder names no longer degrade to `class_<id>` when YAML mapping files are unavailable; missing IDs now resolve from model metadata at runtime.
