# Tasks

## 1. Repository and package shell

- [x] 1.1 Initialize a local git repository at `/Users/ayeshalmeida/projects/ayeshLK/module-termui` (with `openspec/` moved into it), add `.gitignore` and `.gitattributes` adapted from `module-arxiv`, and verify `git log` shows a first commit; creating the GitHub repository is deferred to 7.4
- [x] 1.2 Add the root Gradle files (`settings.gradle`, `build.gradle`, `gradle.properties`, wrapper) adapted from `module-arxiv` with the `ayesha`/`termui` identity, and verify `./gradlew projects` lists the `termui-ballerina` subproject
- [x] 1.3 Create the `ballerina/` package shell (`Ballerina.toml`, `Dependencies.toml`, `Package.md`, `Module.md`, a minimal root `.bal` file, and `ballerina/build.gradle` with `isConnector = false` and `platform = "any"`), and verify `bal build` succeeds inside `ballerina/`
- [x] 1.4 Pin `ballerinaLangVersion` and the package `distribution` to one deliberately chosen Ballerina version (the local toolchain is 2201.13.5), and verify local `bal version`, `gradle.properties`, and `Ballerina.toml` agree on the pin (that CI reads the pin from `gradle.properties` is verified in 4.1)

## 2. Single version source

- [x] 2.1 Add `build-config/resources/Ballerina.toml` and `version.bal.template` plus the `updateTomlFiles` Gradle task, and verify that changing `version` in `gradle.properties` and running the task rewrites both `Ballerina.toml` and `version.bal` to the same value
- [x] 2.2 Verify a `-SNAPSHOT` development version produces generated files without the suffix (inspect `Ballerina.toml` and `version.bal` after the task)
- [x] 2.3 Add an empty placeholder submodule under `ballerina/modules/` and verify `./gradlew build` handles a multi-module package (this confirms the Gradle-plugin risk from `design.md`); adapt the plugin's `module` configuration if it does not, and keep or remove the placeholder as `termui-foundation` needs

## 3. Test tiers and coverage

- [ ] 3.1 Add a trivial default test that needs no terminal, and verify `./gradlew test` passes in an environment with no tty (for example `./gradlew test < /dev/null` or in CI)
- [ ] 3.2 Add the `tty` test group, disabled by default and enabled with `-Pgroups=tty`, with a sample test that allocates a pseudo-terminal, and verify the sample is skipped by default and runs and passes with `-Pgroups=tty` on macOS and Linux
- [ ] 3.3 Enable XML coverage output in `ballerina/build.gradle` and verify a coverage report file is produced by `./gradlew build`

## 4. CI workflows

- [ ] 4.1 Add `.github/workflows/pull-request.yml` with an Ubuntu and macOS matrix, pinned action versions, per-step secrets only, a concurrency group keyed by workflow and ref, and the coverage upload; verify it with `actionlint` and with a green run on a pushed pull request on both OSes
- [ ] 4.2 Add a CI step that runs the `tty` group on both OSes (pty via `script` on Linux and the BSD equivalent on macOS), and verify the step passes in the pull-request run
- [ ] 4.3 Add `.github/workflows/ci.yml` for pushes to `main` with coverage upload, and verify a merge to `main` triggers a green run
- [ ] 4.4 Add `.github/workflows/daily-build.yml` that builds and tests against the latest Ballerina distribution on Ubuntu, and verify a manual dispatch run completes and shows the Ballerina version used
- [ ] 4.5 Verify no workflow exports the whole `secrets` object and that every third-party action is pinned (`grep` the workflows for `toJson(secrets)` and `@master`/`@main`)

## 5. Native-image check

- [ ] 5.1 Add a minimal `examples/` Ballerina app (for example a hello program) that builds with `bal build`, and verify `bal build` succeeds on it locally
- [ ] 5.2 Add `.github/workflows/native-check.yml` that sets up GraalVM, runs `bal build --graalvm` on the example, and is not a required check, then verify a manual run reports a clear pass or fail without blocking a pull request

## 6. Release and publishing

- [ ] 6.1 Add `.github/workflows/release.yml` (manual dispatch, repository-owner guard, build and test, `release-<version>` branch, release plugin tag, Central publish, GitHub release, sync PR) adapted from `module-arxiv` without the Trivy step, and verify it with `actionlint` and a review that nothing publishes before tests pass
- [ ] 6.2 Add `.github/workflows/dev-stg-release.yml` for Dev/Stage Central publishing that never tags, and verify a Stage Central publish of a development version succeeds once the secrets exist
- [ ] 6.3 Verify the release workflow does not run from a fork (confirm the owner guard on both release workflows)

## 7. Repository hygiene and documentation

- [ ] 7.1 Add `.github/CODEOWNERS`, `.github/pull_request_template.md` (including the native-image checkbox), the Apache-2.0 `LICENSE`, and license headers on the build files, and verify each file exists and the headers match `module-arxiv`
- [ ] 7.2 Write `README.md` covering the project purpose, how to build and test, the `tty` test group, the native-image check, and the release process, and verify the documented build and test commands run as written
- [ ] 7.3 Document the secrets maintainers must provision (Ballerina bot username and token, Central release/dev/stage tokens, Codecov token) in the README, and verify the list matches every secret referenced in `.github/workflows/`
- [ ] 7.4 Maintainer action: create the `ayeshLK/module-termui` GitHub repository, add it as `origin`, push `main`, provision those secrets, and verify `git remote -v` shows it and the pull-request and main workflows run end to end

## 8. Integration check

- [ ] 8.1 Open a pull request from a branch with a deliberately failing test and verify the check fails on both OSes, then fix it and verify the checks turn green

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived `project-delivery` spec.
