# Design

## Context

See `proposal.md` - Why. The reference is the author's `module-arxiv` repo, a Ballerina connector package built with Gradle and the `io.ballerina.plugin`, with a single version source, templated `Ballerina.toml` and `version.bal`, and six GitHub workflows. `termui` is a library, supports macOS and Linux first, ships no Java dependencies in its first release, and needs a tty-aware test tier that arxiv's API-based `live` tests do not cover.

The local toolchain is Ballerina 2201.13.5 on Java 21; `module-arxiv` pins 2201.13.0. GraalVM `native-image` is not installed locally, and `bal build --graalvm` is documented as experimental.

## Goals / Non-Goals

**Goals:**
- Reuse the proven arxiv layout and release flow with the fewest changes.
- Make the terminal-dependent test tier a first-class, opt-in concept from day one.
- Surface native-image problems early without gating merges or releases.
- Fix the security and maintenance weak spots of the arxiv workflows instead of copying them.

**Non-Goals:**
- Library code, widgets, or examples beyond a minimal build-able sample.
- Windows CI, a JLine/Java platform dependency, or a vulnerability scan of Java libraries (revisit if a Java shim is ever added).
- Changing how Ballerina Central publishing works.

## Decisions

**Repository layout.** Mirror arxiv, with names adapted:

```
module-termui/
  ballerina/                 package: Ballerina.toml, Dependencies.toml, Package.md,
    modules/                 submodules arrive with termui-foundation
    tests/
    build.gradle
  build-config/resources/    Ballerina.toml + version.bal.template
  examples/                  sample app used by the native-image check
  build.gradle, settings.gradle, gradle.properties
  .github/{workflows,CODEOWNERS,pull_request_template.md}
```

Alternative considered: a plain `bal`-only repo with scripts. Rejected, because the Gradle plugin already provides coverage flags, group selection, Maven-style publishing, and the release plugin, and the author already operates it.

**Single version source.** `gradle.properties` holds the version (with `-SNAPSHOT` during development) and `ballerinaLangVersion`; a Gradle task renders `Ballerina.toml` and `version.bal` from templates, as in arxiv. Alternative: edit `Ballerina.toml` directly. Rejected, because the in-code version constant would drift.

**Package identity.** Org `ayesha` (same as arxiv), name `termui`, `platform = "any"`, `isConnector = false`, Apache-2.0. The Gradle group stays under the author's existing namespace. The development `distribution` is pinned to the same value as `ballerinaLangVersion`; because the local toolchain is newer than arxiv's pin, the pin is set deliberately during implementation instead of copied.

**Test tiers.** Reuse arxiv's group mechanism (`disable = 'live'` by default, `-Pgroups=...` to enable), renaming the group to `tty`. Default tests use the fake terminal backend from `termui-foundation` and need no terminal. The `tty` group runs against a pseudo-terminal: on Linux through `script` (or an equivalent pty wrapper), on macOS through the BSD `script`. Alternative: run everything on a real tty locally only. Rejected, because the Unix backend is the riskiest part of the library and needs CI coverage.

**CI matrix.** Ubuntu and macOS for PR, main, and daily builds. arxiv only builds on Ubuntu. macOS runners cost more, so the full matrix runs on PRs and main, while the daily build against the latest Ballerina runs on Ubuntu only unless a regression suggests otherwise.

**Workflow set.** Keep: pull-request, main build (with Codecov), daily build, release, Dev/Stage publish. Add: `native-check` (non-blocking). Drop for now: Trivy scan, because there is no `ballerina/lib` of Java dependencies.

**Native-image check.** A workflow sets up GraalVM, then runs `bal build --graalvm` on the `examples/` app and reports the result. It is marked non-required, so a failure is visible but not blocking. This implements the "v1 goal, not a first-release gate" decision. Alternative: a gating job. Rejected for now, because the Ballerina native-image feature is experimental and would block unrelated work.

**Workflow hygiene (deliberate deviations from arxiv).**
- Pass secrets per step through `env`, never by exporting the whole `secrets` object into `GITHUB_ENV`.
- Pin actions to a full version or commit SHA, with no `@master`, and upgrade the old `v3` actions.
- Use a concurrency group that works for both push and pull_request events (`github.workflow` plus `github.ref`), not `github.head_ref`.
- Keep the `repository_owner` guard on release and publish workflows.

**Release flow.** Keep arxiv's shape: manual dispatch, build and test, create `release-<version>`, run the release plugin (tag `v<version>`), publish to Central, create the GitHub release, and open a sync PR. Dev/Stage publish stays separate and never tags.

## Risks / Trade-offs

- [pty tests flaky in CI] -> Keep the `tty` group small, run it separately from the default tests, and treat it as a distinct check so flakiness is isolated.
- [Gradle plugin may not handle submodules the way a single-module arxiv does] -> Confirm early in implementation by adding an empty submodule before `termui-foundation` starts, and adapt the plugin's `module` configuration if needed.
- [macOS runner cost and queue time] -> Restrict the macOS job to PR and main, and skip it for docs-only changes if cost becomes an issue.
- [Native-image feature is experimental] -> The check is non-blocking, and failures are triaged rather than gated.
- [Secrets are not yet provisioned] -> The scaffold documents the required secrets; CI cannot fully run until they exist. Local builds still work without them where possible.
- [Ballerina version pin diverges from arxiv] -> Pin explicitly and let the daily build against the latest distribution catch drift.
