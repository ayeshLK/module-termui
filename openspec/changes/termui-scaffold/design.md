# Design

## Context

See `proposal.md` - Why. The reference is the author's `module-arxiv` repo, a Ballerina connector package built with Gradle and the `io.ballerina.plugin`, with a single version source, templated `Ballerina.toml` and `version.bal`, and six GitHub workflows. `termui` is a library, supports macOS and Linux first, ships no Java dependencies in its first release, and needs a tty-aware test tier that arxiv's API-based `live` tests do not cover.

`module-arxiv` pins Ballerina 2201.13.0. `termui` targets the 2201.14 line, which needs JDK 25 (and so Gradle 9). GraalVM `native-image` is not installed locally, and `bal build --graalvm` is documented as experimental.

## Goals / Non-Goals

**Goals:**
- Reuse the proven arxiv layout and release flow with the fewest changes.
- Make the terminal-dependent test tier a first-class, opt-in concept from day one.
- Surface native-image problems early without gating merges or releases.
- Fix the security and maintenance weak spots of the arxiv workflows instead of copying them.

**Non-Goals:**
- Library code, widgets, or example applications (the foundation change adds those).
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
  build.gradle, settings.gradle, gradle.properties
  .github/{workflows,CODEOWNERS,pull_request_template.md}
```

Alternative considered: a plain `bal`-only repo with scripts. Rejected, because the Gradle plugin already provides coverage flags, group selection, Maven-style publishing, and the release plugin, and the author already operates it.

**Single version source.** `gradle.properties` holds the version (with `-SNAPSHOT` during development) and `ballerinaLangVersion`; a Gradle task renders `Ballerina.toml` and `version.bal` from templates, as in arxiv. Alternative: edit `Ballerina.toml` directly. Rejected, because the in-code version constant would drift.

**Package identity.** Org `ayesha` (same as arxiv), name `termui`, `platform = "any"`, `isConnector = false`, Apache-2.0. The Gradle group stays under the author's existing namespace. Both `ballerinaLangVersion` and the package `distribution` are pinned to 2201.14.2, the line the foundation targets, so no older Ballerina line needs to be supported.

**Test tiers.** Reuse arxiv's group mechanism (`disable = 'live'` by default, `-Pgroups=...` to enable), renaming the group to `tty`. Default tests use the fake terminal backend from `termui-foundation` and need no terminal. The `tty` group runs against a pseudo-terminal: on Linux through `script` (or an equivalent pty wrapper), on macOS through the BSD `script`. Alternative: run everything on a real tty locally only. Rejected, because the Unix backend is the riskiest part of the library and needs CI coverage.

**Build path (verified).** Follow the `module-ballerinax-solace` wiring, not arxiv's. The Ballerina Gradle plugin is 4.0.0 (2.3.0 resolves `jballerina-tools:null` unless `isConnector = true`, which switches to a Docker-only build). The root `build.gradle` declares `jbalTools` (the pinned `jballerina-tools`) and `ballerinaStdLibs` for subprojects; `ballerina/build.gradle` sets `langVersion = ballerinaLangVersion` and makes `build` and `test` depend on `unpackJballerinaTools`, and `updateTomlFiles` on `copyStdlibs`. The stdlib closure for what the foundation imports is `io`, `os`, and `time`, with versions in `gradle.properties`. The stack is the same as `module-ballerinax-solace`: Gradle 9.5.1, plugin 4.0.0, release plugin 3.1.0, `ExecOperations` instead of the removed `project.exec`, and a root `build` task that extends the one the release plugin provides. The build runs on JDK 25. This path needs no Docker, so it runs on macOS and Linux runners and runs tty tests on a native terminal. Alternative: arxiv's `isConnector = true` (Docker) path. Rejected: macOS runners have no Docker and a pty is awkward inside a container.

**`commitTomlFiles` only for releases.** The plugin runs it after every build, which makes an unwanted git commit (and fails without a git identity in CI), so it only runs with `-PcommitToml`, which the release workflow passes.

**CI matrix.** Ubuntu and macOS for PR and main builds. `./gradlew build -x test` and `./gradlew test` run as separate steps, because the plugin only supports test-group selection with `gradlew test` (the official ballerina-library templates do the same). The daily build runs on Ubuntu only unless a regression suggests otherwise. It tracks the latest released Ballerina with `bal build` and `bal test` directly, using the JDK that line needs (the mapping used by `ballerina-platform/ballerina-library`), so it stays a canary for newer releases without being tied to the Gradle stack.

**Workflow set.** Keep: pull-request, main build (with Codecov), daily build, release, Dev/Stage publish. Add: `native-check` (non-blocking, monthly and on demand). Drop for now: Trivy scan, because there is no `ballerina/lib` of Java dependencies.

**Native-image check.** Follow the official GraalVM check: build with Gradle, then run `bal test --graalvm` from `ballerina/` with `setup-ballerina` and `setup-graalvm`. It runs monthly and on manual dispatch, can be skipped with a PR label, and is not a required check, so a failure is visible but not blocking. This implements the "v1 goal, not a first-release gate" decision and tests the package's own tests natively, which is more than building a sample app. Alternative: a gating job, or building an `examples/` app. Rejected for now: the feature is experimental, and the example app belongs to `termui-foundation`.

**Static analysis.** Run `bal scan` on the package in the PR workflow, as the official PR template does, and report findings in the check output.

**Workflow hygiene (deliberate deviations from arxiv).**
- Pass secrets per step through `env`, never by exporting the whole `secrets` object into `GITHUB_ENV`.
- Pin actions to a full version or commit SHA, with no `@master`, and upgrade the old `v3` actions.
- Use a concurrency group that works for both push and pull_request events (`github.workflow` plus `github.ref`), not `github.head_ref`.
- Keep the `repository_owner` guard on release and publish workflows.

**Release flow.** Keep arxiv's shape: manual dispatch, build and test, create `release-<version>`, run the release plugin (tag `v<version>`), publish to Central, create the GitHub release, and open a sync PR. Dev/Stage publish stays separate and never tags.

## Risks / Trade-offs

- [pty tests flaky in CI] -> Keep the `tty` group small, run it separately from the default tests, and treat it as a distinct check so flakiness is isolated.
- [The stdlib list in the root `build.gradle` can drift from the package's imports] -> Keep it next to the versions in `gradle.properties`, and let the PR build fail when an imported stdlib module is missing from the unpacked distribution.
- [A newer Ballerina line needs a newer JDK or Gradle again] -> The setup action derives the JDK from the pinned version's minor, so a pin bump moves CI's JDK automatically; the daily canary shows the next line's problems early.
- [A committed `Dependencies.toml` goes stale when the pin moves, and a stale lock whose `distribution-version` matches the installed Ballerina made the daily `bal build` fail to resolve `ballerina/os` on a clean runner] -> Refresh it with a `bal build` whenever the pin or the stdlib versions change, and keep its `io`, `os`, and `time` versions equal to those in `gradle.properties`.
- [The `jballerina-tools` distribution lacks the HTML coverage report tools] -> Verify that the XML coverage report is still produced (task 3.3).
- [macOS runner cost and queue time] -> Restrict the macOS job to PR and main, and skip it for docs-only changes if cost becomes an issue.
- [Native-image feature is experimental] -> The check is non-blocking, and failures are triaged rather than gated.
- [Secrets are not yet provisioned] -> The scaffold documents the required secrets; CI cannot fully run until they exist. Local builds still work without them where possible.
- [Ballerina version pin diverges from arxiv] -> Pin explicitly and let the daily build against the latest distribution catch drift.
