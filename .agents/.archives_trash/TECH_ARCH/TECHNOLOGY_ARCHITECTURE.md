# Technology Architecture: Build and Distribution Blueprint

This document captures the technology architecture used to build and distribute this Python CLI project, so another agent can replicate the setup for a different CLI tool.

## 1) Architecture Goals

- Build a reusable Python CLI package with both module and script entry points.
- Generate reproducible distribution artifacts (wheel + source distribution).
- Validate package quality continuously in CI.
- Publish release artifacts automatically from semantic version tags.
- Keep local release steps scripted and deterministic.

## 2) High-Level System

```text
Developer
  -> updates code + changelog + version
  -> runs local clean/build scripts
  -> pushes commit + semantic tag (vX.Y.Z)

GitHub Actions CI
  -> builds wheel/sdist across Python versions
  -> runs twine checks

GitHub Actions Release
  -> triggers on tag push or manual dispatch
  -> rebuilds wheel/sdist
  -> creates/updates GitHub Release
  -> uploads artifacts to release

Consumers
  -> install from wheel/sdist or run bundled exe (optional PyInstaller path)
```

## 3) Source and Packaging Layout

```text
faceless/
  __init__.py          # CLI implementation + main() entry
  __main__.py          # python -m faceless entry point
  labels/*.yaml        # Packaged runtime data files

scripts/
  Invoke-Clean-Faceless-Build.ps1
  Invoke-Build-Faceless-Wheels.ps1
  Invoke-Bump-Faceless-Version.ps1

.github/workflows/
  ci.yml
  release.yml

pyproject.toml         # Build system + project metadata + entry points
faceless.spec          # Optional PyInstaller onefile executable definition
mise.toml              # Local toolchain/task shortcuts
CHANGELOG.md           # Keep a Changelog + SemVer source for bump decisions
```

## 4) Packaging Technology Stack

- Build backend: setuptools via PEP 517/518.
- Package artifacts: wheel and sdist via python -m build.
- Metadata source: pyproject.toml.
- Runtime dependencies: declared in pyproject.toml.
- Optional dev tooling: build, cibuildwheel, pyinstaller.
- Entry point model: console script mapped from project.scripts.
- Data files: included via setuptools package-data.

## 5) Distribution Channels

### A. Python packaging artifacts

- Primary outputs:
  - dist/*.whl
  - dist/*.tar.gz
- Built locally by PowerShell script and in CI/Release workflows.
- Suitable for pip-based installation or internal artifact distribution.

### B. Optional standalone executable

- PyInstaller spec produces onefile Windows executable.
- Useful for environments where Python is not pre-installed.
- Treated as an optional secondary distribution path.

## 6) Local Build and Release Automation

### Build clean script

- Script: scripts/Invoke-Clean-Faceless-Build.ps1
- Responsibilities:
  - Removes build/, dist/, egg-info, caches, and transient artifacts.
  - Guards against deleting paths outside the project root.

### Build artifact script

- Script: scripts/Invoke-Build-Faceless-Wheels.ps1
- Responsibilities:
  - Resolves Python interpreter (prefers project .venv when enabled).
  - Installs required build tooling.
  - Builds wheel (+ optional sdist skip, optional cibuildwheel mode).
  - Writes output artifacts to dist/ (or configured output path).

### Version bump script

- Script: scripts/Invoke-Bump-Faceless-Version.ps1
- Responsibilities:
  - Reads current version from pyproject.toml.
  - Inspects CHANGELOG.md Unreleased section.
  - Recommends or applies semantic version bump.
  - Optionally creates local git tag.

## 7) CI/CD Architecture

### Continuous Integration workflow

- File: .github/workflows/ci.yml
- Triggered on pull requests, pushes to main, and manual dispatch.
- Matrix build across Python versions 3.10-3.13.
- For each matrix entry:
  - Install build tooling.
  - Build wheel and sdist.
  - Validate artifacts using twine check.

### Release workflow

- File: .github/workflows/release.yml
- Triggered by semantic tag push (v*) or manual dispatch.
- Build job:
  - Rebuild wheel and sdist from source.
  - Upload dist artifacts to workflow artifacts.
- Publish job:
  - Download artifacts.
  - Resolve and validate tag metadata format.
  - Create or update GitHub release.
  - Upload release assets.

## 8) Versioning and Release Control Model

- Version source of truth: pyproject.toml project.version.
- Change intent source: CHANGELOG.md Unreleased section.
- Semantic versioning policy:
  - major: breaking changes
  - minor: backward-compatible features
  - patch: fixes/maintenance
- Tag naming convention: vX.Y.Z.
- Consistency requirement: tag version must match package version.

## 9) Standard Release Runbook

1. Confirm pyproject version and changelog updates.
2. Run clean script.
3. Run build script to produce fresh artifacts.
4. Commit release-related changes.
5. Create semantic tag vX.Y.Z.
6. Push commit and tag.
7. Verify GitHub Release contains expected artifacts.

## 10) Copy-This-Setup Template for Another Python CLI

Use this as a migration checklist for a different CLI project:

1. Keep pyproject.toml as the central package metadata source.
2. Define a console script entry point under project.scripts.
3. Place CLI executable logic in package __init__.py main() and module entry in __main__.py.
4. Add package-data declarations for runtime non-code assets.
5. Create scripts for:
   - clean build artifacts
   - build wheel/sdist
   - bump semver from changelog intent
6. Add CI workflow:
   - matrix Python packaging build
   - twine artifact checks
7. Add Release workflow:
   - tag/manual trigger
   - rebuild artifacts
   - create/update GitHub release and attach files
8. Standardize semantic tags to vX.Y.Z.
9. Keep CHANGELOG.md in Keep a Changelog format.
10. Optionally add PyInstaller spec for native executable distribution.

## 11) Minimal Command Set to Replicate

```powershell
# clean
pwsh -NoProfile -File scripts/Invoke-Clean-<Tool>-Build.ps1

# build wheel + sdist
pwsh -NoProfile -File scripts/Invoke-Build-<Tool>-Wheels.ps1

# recommend bump
pwsh -NoProfile -File scripts/Invoke-Bump-<Tool>-Version.ps1 -BumpVersion auto

# apply recommended bump + local tag
pwsh -NoProfile -File scripts/Invoke-Bump-<Tool>-Version.ps1 -BumpVersion auto -Apply -CreateTag

# push
git push origin HEAD
git push origin vX.Y.Z
```

## 12) Non-Functional Guardrails

- Determinism: always build release artifacts from a clean workspace.
- Safety: clean script must refuse deletion outside project root.
- Portability: prefer standards-based pyproject packaging.
- Auditability: changelog-driven version decisions.
- Reproducibility: CI and release workflows rebuild artifacts from source instead of trusting local dist leftovers.

## 13) Suggested Reusable File Names for New Projects

- pyproject.toml
- CHANGELOG.md
- scripts/Invoke-Clean-<Tool>-Build.ps1
- scripts/Invoke-Build-<Tool>-Wheels.ps1
- scripts/Invoke-Bump-<Tool>-Version.ps1
- .github/workflows/ci.yml
- .github/workflows/release.yml
- <tool>.spec (optional)

This architecture is intentionally modular: the domain logic of the CLI can change completely while the build and distribution framework remains stable.
