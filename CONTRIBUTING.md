# Contributing to termui

Thanks for helping. This page covers building, testing, and releasing. For what the library is and how to use it, see the [README](README.md).

## Requirements

- JDK 25 (Ballerina 2201.14 and later need it)
- Ballerina 2201.14.2 (the version pinned as `ballerinaLangVersion` in `gradle.properties`)
- macOS or Linux (Windows is not supported yet)
- `python3` (used by the `tty` tests to allocate a pseudo-terminal), and `pyte` for the agent harness check (a terminal emulator it uses to look at the screen; install it in a virtualenv: `python3 -m venv .venv && .venv/bin/pip install pyte`, then run the check with `.venv/bin/python`)
- `packageUser` and `packagePAT` environment variables: a GitHub user and a token that can read
  packages. The Gradle plugin is resolved from `https://maven.pkg.github.com/ballerina-platform/*`,
  even for builds that publish nothing.

## Build and test

The build uses the Gradle wrapper (Gradle 9.5.1). Run it on JDK 25, for example with
`JAVA_HOME` pointing at a JDK 25 install, because the Ballerina tools it unpacks need that Java.

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

## The examples

The examples depend on the version of termui published on Ballerina Central, so anyone who clones the repository can run them with `bal run`. To try them against the code in your working tree, publish it to your local repository and point the examples at it:

```sh
(cd ballerina && bal pack && bal push --repository=local)
.github/scripts/point-examples-at-source.sh          # edits the examples' Ballerina.toml: do not commit the result
(cd examples/agent-harness && bal build && JAVA=$(which java) python3 verify.py)   # python3 with pyte installed, see Requirements
(cd examples/counter && bal build && JAVA=$(which java) python3 verify.py)
git checkout examples                                  # back to the published dependency
```

CI does the same on Linux and macOS, and `examples/agent-harness/record_demo.py` regenerates the recording used in the README (it needs [`agg`](https://github.com/asciinema/agg)).

## How changes are planned

Larger changes are planned with [OpenSpec](https://openspec.dev): a proposal, the behavior as requirements with scenarios, a design, and tasks. The current specifications are in [`openspec/specs`](openspec/specs) and finished changes, with their design notes, are in [`openspec/changes/archive`](openspec/changes/archive). Small fixes do not need any of that.

## Code and documentation conventions

- Every public function and type has a documentation comment.
- Examples in `Module.md`, `Package.md` and the README are checked: the quickstart is `examples/counter`, and the module examples are mirrored by tests, so change both together.
- Behavior that depends on a terminal is tested through `FakeTerminal`, or in the `tty` test group against a real pseudo-terminal.
- Keep credentials, token names, and setup details out of the documentation.
