# Contributing to termui

Thanks for helping. This page covers building, testing, and releasing. For what the library is and how to use it, see the [README](README.md). What counts as public API, and what each kind of release may change, is in [COMPATIBILITY.md](COMPATIBILITY.md); record every user-visible change in the [CHANGELOG](CHANGELOG.md) under *Unreleased*.

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

Tests that sleep, read a clock or assert on a duration must also pass when the machine is busy: run `bench/stress_tests.sh` on them (see [`bench/README.md`](bench/README.md)) and give any upper bound a wide margin.

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

### Checklist for a stable release (1.0.0 and later)

Do not start the **Publish Release** workflow for a stable version until every item is done. Tick them
in the release pull request.

- [ ] **API audit.** Every public symbol is either supported API or listed as low-level in its module
      page, and the *Stability* sections and [COMPATIBILITY.md](COMPATIBILITY.md) agree.
- [ ] **Documentation.** `bal doc` (run in `ballerina/`) prints no warnings, the module pages and
      `Package.md` match the code, and the examples in them are covered by the doc tests.
- [ ] **Changelog.** [CHANGELOG.md](CHANGELOG.md) has an entry for the version, with a migration note
      for anything removed or changed, and the *Unreleased* section is empty.
- [ ] **Status.** The README and `Package.md` describe the package as stable (no "experimental" notice,
      no 0.x wording) and the badges and install snippets show the new version.
- [ ] **Version.** `gradle.properties` has the release version with `-SNAPSHOT`, and the checked-in
      `Ballerina.toml`, `Dependencies.toml` and `version.bal` match it.
- [ ] **CI.** The build is green on Linux and macOS for the commit to be released, including the
      `tty` tests and the agent-harness check.
- [ ] **Terminal checks** with the agent harness (`examples/agent-harness`, run with `anchorBottom`) in
      tmux and in one Linux terminal: the input stays on the bottom rows, a resize keeps the layout, an
      approval prompt works, and Alt+Enter, the cursor keys and Ctrl+U edit the input.
      `examples/agent-harness/tmux_check.sh` runs these in tmux (for example in a Linux container with
      `tmux` and JDK 25 installed); run the harness by hand in a Linux terminal emulator for the other.
      Note the results in the pull request. A failure blocks the release only if it breaks documented
      behaviour; otherwise record it as a known limit in the README.

## Measuring performance

`bench/` has two scripts that run a built program on a pseudo-terminal and report the CPU it uses while idle
(`idle_cpu.py`) and how long a key takes to produce output after idle pauses of different lengths
(`latency.py`). Run them against the counter example before a release and after any change to the loops or the
renderer; see [bench/README.md](bench/README.md). They are not a CI gate, because timing on shared runners is
noisy. Expected on a laptop: a waiting program without a fast timer, such as the counter, idles under 3% of a
core; a program with a 10 Hz timer idles at a few percent more; the median first key takes about 40 ms after a
second of idleness, 110 ms after three seconds and half a second after 13 seconds or more.

## The examples

The examples name no version of termui. Their manifests have only a `[package]` section, so anyone who clones the repository can run them with `bal run`, and Ballerina resolves the published release from Ballerina Central. To try them against the code in your working tree, publish it to your local repository and point the examples at it:

```sh
(cd ballerina && bal pack && bal push --repository=local)
.github/scripts/point-examples-at-source.sh          # adds a dependency on the local build to each example's Ballerina.toml: do not commit the result
(cd examples/agent-harness && bal build && JAVA=$(which java) python3 verify.py)   # python3 with pyte installed, see Requirements
(cd examples/counter && bal build && JAVA=$(which java) python3 verify.py)
git checkout examples                                  # back to the published release
```

The script covers the examples under `examples/` and not the tutorial packages in `examples/tutorial/`, which are always built against the published release. Running it twice is safe: it replaces the entry it added. CI does the same on Linux and macOS, and `examples/agent-harness/record_demo.py` regenerates the recording used in the README (it needs [`agg`](https://github.com/asciinema/agg)).

## The documentation site

The site in [`site/`](site) is built with Starlight from Markdown and MDX and published to GitHub Pages. It needs Node 22.23.4 or later (24 works), and nothing else in the repository does.

```sh
cd site
npm ci
npm run dev        # live preview at http://localhost:4321/module-termui/
npm run build      # the build CI runs
npm run check-links  # then check every internal link and #fragment in the built site (CI runs it too)
```

- **Add a page** by creating a `.md` or `.mdx` file under `site/src/content/docs/<section>/`. The sidebar is generated from the folders; order a page with `sidebar.order` in its front matter. Quote a `description` that contains a colon.
- **Show code from a file, never a copy.** Include a program with `<ExampleCode file="examples/..." />`, or part of one with `region="name"`, which shows the lines between `// region name` and `// endregion name` in the source (the markers are not shown, and a missing region fails the build). `examples/check.sh` compiles every example a page includes, and runs their tests, and CI runs it, so a page cannot show code that does not build. Add a new included example to that script.
- **Use only released API in tutorial and example programs.** They resolve the published termui release from Ballerina Central, with no version in their manifests, so a page matches what a reader can install. A new API appears in the site after the release that contains it.
- **Link to the API reference** on Ballerina Central instead of restating symbol documentation.
- **Some diagrams exist in more than one form, with the same wording.** The message-flow diagram of the loop is the `InteractiveLoop` component (`site/src/components/diagrams/InteractiveLoop.astro`, built on `Flow`) on `site/src/content/docs/concepts/the-loop.mdx`, a Mermaid block in `README.md` (GitHub renders it), and ASCII in `ballerina/Module.md` (Ballerina Central shows that file and cannot be relied on to render anything richer). The anchoring diagram is the `Screen` in `site/src/content/docs/concepts/inline-rendering.mdx` and ASCII in `ballerina/modules/render/Module.md`. When the wording or the shape changes, change every form; searching the repository for "one frame per batch" finds the first three.
- **The interactive loop diagram mirrors the counter.** What happens when a key is pressed comes from `site/src/lib/loop-walk.ts`, and the code it shows comes from the `update` and `view` regions of `examples/counter/main.bal`. `npm test` (in `site`) includes a test that reads the counter source, so changing the counter's keys or the text of its view fails it until the model is updated. If you add JavaScript that creates elements, give them the `data-astro-cid-*` attributes of the markup they stand in for (the component shows how), or Astro's scoped styles will not reach them.
- **The quick start is `examples/counter`, and the to-do tutorial is five steps: `examples/tutorial/todo1-list` to `todo4-scrollback`, then `examples/todo-list` as the finished program.** Each page builds its program in stages from snippets written in the page and includes the whole file at the end, so change a page and its example together, re-check that the stages still add up to the file, and keep the examples' checks passing (`verify.py` for the counter, the tests for the to-do steps): they are what the requirements rely on. Each step's program is the previous one plus the change its page describes, so a change to the finished program usually means a change to the steps before it.
- **Recordings** are asciinema casts in `site/public/casts/`, recorded from the real programs. `examples/tutorial/record.py` records the tutorial steps and the to-do steps (`python3 record.py todo1-list`, `todo3-add` or `todo-list`, with `pyte` installed; each run starts in an empty folder), and `examples/counter/record_demo.py` and `examples/agent-harness/record_demo.py` show how the others were made. The homepage describes `harness-demo.cast` in text for readers without scripts (`site/src/components/HomeDemo.astro`) and shows it from the frame at 13 seconds, so update both if that recording is replaced.

The `Documentation site` workflow builds the site and the examples on pull requests that touch `site/` or `examples/`, and publishes from `main`. Package-only changes do not run it.

## How changes are planned

Larger changes are planned with [OpenSpec](https://openspec.dev): a proposal, the behavior as requirements with scenarios, a design, and tasks. The current specifications are in [`openspec/specs`](openspec/specs) and finished changes, with their design notes, are in [`openspec/changes/archive`](openspec/changes/archive). Small fixes do not need any of that.

## Code and documentation conventions

- Every public function and type has a documentation comment.
- Examples in `Module.md`, `Package.md` and the README are checked: the quickstart is `examples/counter`, and the module examples are mirrored by tests, so change both together.
- Behavior that depends on a terminal is tested through `FakeTerminal`, or in the `tty` test group against a real pseudo-terminal.
- Keep credentials, token names, and setup details out of the documentation.
