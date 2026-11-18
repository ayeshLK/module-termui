# Proposal

## Why

`ayesha/termui` is a Ballerina terminal UI toolkit for agentic CLIs, and it has no build, test, CI, or release setup yet. The author's existing `module-arxiv` repo already has a working Ballerina-package pipeline (Gradle plus the Ballerina plugin, a single version source, and a set of GitHub workflows). Reusing it now gives the foundation work (`termui-foundation`) a working CI and release path before any library code lands, and avoids retrofitting delivery tooling around a moving design.

## What Changes

- Create the `module-termui` repository skeleton, adapted from `module-arxiv`:
  - Gradle multi-project build with the `io.ballerina.plugin`, `ballerina/` as the package directory, and `gradle.properties` as the single source of truth for the package version and tool versions.
  - Templates under `build-config/resources/` that render `Ballerina.toml` and `version.bal`, so versions cannot drift.
  - `ayesha/termui` package metadata (Apache-2.0, `platform = "any"`, library rather than connector).
- Add GitHub Actions workflows: pull-request build, main-branch build with coverage upload, daily build against the latest Ballerina, manual release (release branch, Central publish, GitHub release, sync PR), and Dev/Stage Central publish.
- Add a test setup with two tiers: fake-backend unit tests that run anywhere, and a `tty` test group (disabled by default, enabled with `-Pgroups=tty`) that needs a real pseudo-terminal.
- Run CI on Ubuntu and macOS, the two supported platforms.
- Add a non-blocking native-image check workflow that builds an `examples/` sample with `bal build --graalvm`, so native-hostile choices are caught early (a v1 goal, not a first-release gate).
- Add repository hygiene: `CODEOWNERS`, a PR template (including a native-image compatibility checkbox), Apache-2.0 license headers, and README / `Package.md` placeholders.
- Deliberately do **not** copy from `module-arxiv`: dumping all secrets into the job environment, unpinned or outdated action versions, the empty-on-push `head_ref` concurrency group, and the Trivy scan of `ballerina/lib` (there are no Java dependencies yet).
- Out of scope: any library code (see `termui-foundation`), widgets, a JLine backend, and Windows CI.

## Capabilities

### New Capabilities
- `project-delivery`: how the package is built, tested, versioned, checked for native-image compatibility, and released, including the CI behavior expected on pull requests, main, and release.

### Modified Capabilities

None.

## Impact

- New repository files: root Gradle files, `ballerina/` package shell, `build-config/`, `.github/`, and an `examples/` placeholder.
- Requires secrets on the new repo before CI can fully run: the Ballerina bot credentials, Central access tokens (release, dev, stage), and a Codecov token.
- No runtime behavior or public API yet. This change only prepares the delivery path for `termui-foundation`.
- Org is `ayesha` (matching `module-arxiv`), package `termui`, repo `module-termui`.
