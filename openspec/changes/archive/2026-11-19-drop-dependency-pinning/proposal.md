# Proposal

## Why

The docs tell readers to pin termui in `Ballerina.toml` with a `[[dependency]]` block. That is not how Ballerina dependencies normally work: the build resolves an imported package, records the version in `Dependencies.toml`, picks up patch releases on its own, and moves to a newer minor release only when the user asks. Ballerina's own documentation describes the `[[dependency]]` table as needed only to pin a version or to use a local repository. Advising every reader to write one adds a step that is not needed, and shows a pattern the Ballerina community does not follow. It also costs us: each release so far needed a "move the README and the examples to X" commit only because the examples carry a pinned version.

## What Changes

- Remove the pinning advice and its `[[dependency]]` snippet from the README quickstart, the site's install page, and the tutorial's step 1 set-up. Say instead what Ballerina does: the first build fetches the latest release from Ballerina Central and records it in `Dependencies.toml`, patch releases are picked up automatically, and a newer minor release is the user's choice.
- Reword the first bullet of the compatibility page ("Pin a version in `Ballerina.toml`") to describe the same behaviour and what a minor or patch release may change.
- Remove the `[[dependency]]` block from the nine example manifests (`examples/counter`, `examples/agent-harness`, `examples/best-practices`, `examples/tutorial/step1-counter` to `step6-testing`), so they resolve termui from Central like any other project.
- Change `.github/scripts/point-examples-at-source.sh`, which today edits the version line of an existing block, to add a local-repository dependency to each example's manifest, and to replace one that is already there so running it twice is safe.
- Update `CONTRIBUTING.md`: the rule for tutorial and example programs, and the section on trying the examples against the working tree.
- Replace the `project-delivery` requirement "Included examples are compiled in continuous integration", whose only scenario is "Example pinned to a release", with "Included examples resolve termui from Ballerina Central" (same obligation, no pin), and add a scenario for the script that points the examples at the source. It is a removal plus an addition, not an edit, because a scenario's name is part of what identifies a requirement.

Out of scope: committing a `Dependencies.toml` for the examples, changing which versions the examples compile against in CI, and any change to the package's own `Ballerina.toml`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `project-delivery`: the requirement that included examples are compiled in CI is restated without the pin, and a scenario states how the examples are pointed at the working tree.

## Impact

- `README.md`, `site/src/content/docs/start/install.md`, `site/src/content/docs/tutorial/01-counter.mdx`, `site/src/content/docs/best-practices/compatibility.md`, `CONTRIBUTING.md`.
- Nine `examples/**/Ballerina.toml` files and `.github/scripts/point-examples-at-source.sh` (used by `build.yml` and `native-check.yml`).
- A consequence to accept: `Dependencies.toml` is git-ignored for the examples, so a fresh clone resolves the latest release on Central. If a 2.0.0 is ever published, examples and tutorial code written for 1.x would resolve to it. See design.md.
- No package code, API or release is affected.
