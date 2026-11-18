# module-termui

`ayesha/termui` is a terminal UI toolkit for building polished, interactive, agent-style
command-line applications in Ballerina: an inline live region, committed scrollback, streaming
output, and non-blocking input. It is a UI/CLI toolkit only; agent logic stays in the application.

> Status: under development. The design lives in [`openspec/`](openspec/) (see the
> `termui-foundation` and `termui-scaffold` changes).

## Requirements

- JDK 21
- Ballerina 2201.13.5 (the version pinned as `ballerinaLangVersion` in `gradle.properties`)
- macOS or Linux (Windows is not supported yet)
- `python3` (used by the `tty` tests to allocate a pseudo-terminal)
- `packageUser` and `packagePAT` environment variables: a GitHub user and a token that can read
  packages. The Gradle plugin is resolved from `https://maven.pkg.github.com/ballerina-platform/*`,
  even for builds that publish nothing.

## Build and test

Build and test go through Gradle, not `bal` directly, because Gradle regenerates
`ballerina/Ballerina.toml` and `ballerina/version.bal` from the templates in `build-config/`.

```sh
./gradlew build -x test        # compile and package, without tests
./gradlew test                 # default tests: need no terminal
./gradlew test -Pgroups=tty    # tty tests only: need a pseudo-terminal (see below)
./gradlew build                # build and the default tests
```

Run a single test with Ballerina directly: `cd ballerina && bal test --tests <testFunctionName>`.

### Test groups

| Group | Runs by default | What it is for |
|---|---|---|
| (none) | yes | Unit tests that use the in-memory terminal backend and need no terminal. |
| `tty` | no | Tests that need a real pseudo-terminal. They allocate one with Python's `pty` module. |

Coverage is written as XML to `ballerina/target/report/termui/coverage-report.xml`. The unpacked
distribution has no HTML report tools, so the HTML report warning can be ignored.

### Native-image check

`.github/workflows/native-check.yml` runs the package's tests as a GraalVM native image
(`bal test --graalvm`) on a monthly schedule, on demand, and on pull requests. Add the
`Skip GraalVM Check` label to a pull request to opt out. This check is not required: native-image
is a v1 goal, not a first-release gate.

## Versioning

The package version is defined once, in `gradle.properties` (`version=...`, with `-SNAPSHOT` during
development). The build renders `ballerina/Ballerina.toml` and `ballerina/version.bal` from the
templates in `build-config/resources/`; never edit the version in those two files by hand.

## Releasing

Releases are cut with the manual **Publish Release** workflow, which builds and tests the package,
creates a `release-<version>` branch, tags `v<version>`, publishes to Ballerina Central, creates a
GitHub release, and opens a sync pull request. **Publish to the Ballerina Dev/Stage Central** publishes
a development version to the Dev or Stage Central without tagging.

## Repository secrets

The workflows read these secrets. `GITHUB_TOKEN` is provided automatically.

| Secret | Used by |
|---|---|
| `CODECOV_TOKEN` | coverage upload in the build workflow |
| `BALLERINA_BOT_USERNAME`, `BALLERINA_BOT_EMAIL`, `BALLERINA_BOT_TOKEN` | release: git identity, pushing the release branch and tag, GitHub release, sync PR, and the Maven package publish |
| `BALLERINA_CENTRAL_ACCESS_TOKEN` | release: publishing to Ballerina Central |
| `BALLERINA_CENTRAL_DEV_ACCESS_TOKEN`, `BALLERINA_CENTRAL_STAGE_ACCESS_TOKEN` | Dev/Stage Central publish |

## License

Apache License 2.0. See [LICENSE](LICENSE).
