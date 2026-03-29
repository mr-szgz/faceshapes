# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2026-03-29
### Changed
- Simplified File Explorer registry integration to keep only required `FaceShapes` and `FaceShapes Move` commands.

## [0.1.1] - 2026-03-28
### Changed
- Patch release: bumped package version metadata to `0.1.1`.

## [0.1.0] - 2026-03-28
### Added
- Added `pyproject.toml` with standardized packaging metadata and a console script entry point (`faceshapes`).
- Added `scripts/Invoke-Clean-Faceshapes-Build.ps1` to remove build outputs and common Python build/cache artifacts safely.
- Added `scripts/Invoke-Build-Faceshapes-Wheels.ps1` to build wheel/sdist artifacts for local and CI distribution.
- Added `scripts/Invoke-Bump-Faceshapes-Version.ps1` to recommend/apply semantic version bumps from changelog intent.
- Added GitHub Actions workflows for CI packaging checks and release publishing with wheel/sdist attachments.
- Added `mise.toml` tasks (`clean`, `build`, `bump`) for deterministic local release operations.
