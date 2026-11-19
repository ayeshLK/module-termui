# Tasks

## 1. The examples and the script

- [x] 1.1 Rewrite `.github/scripts/point-examples-at-source.sh` to remove any existing `termui` dependency block from each `examples/*/Ballerina.toml` and append one with the build's version and `repository = "local"`, failing if the version cannot be read; verify by running it twice on a scratch copy of the examples (with and without an existing block) and finding exactly one `termui` block in each manifest, and that `git checkout examples` restores them
- [x] 1.2 Remove the `[[dependency]]` block from the nine example manifests (`counter`, `agent-harness`, `best-practices`, `tutorial/step1-counter` to `step6-testing`); verify with `examples/check.sh` that each builds against the published release from Central and that each generated `Dependencies.toml` records termui 1.0.0
- [x] 1.3 Verify the source flow end to end as CI does: `bal pack && bal push --repository=local`, run the script, then build `examples/counter` and `examples/agent-harness` and run their `verify.py` checks, and build `examples/best-practices`; confirm all three used the local build (the resolved version comes from the repository, not Central)
- [x] 1.4 Update `CONTRIBUTING.md`: the "The examples" section (what the script now does, and that `git checkout examples` undoes it) and the rule for tutorial and example programs (they resolve the published release from Central); verify each command in the section runs as written

## 2. The prose

- [x] 2.1 Reword the README quickstart: remove the `[[dependency]]` snippet and the "to pin a version" sentence, and say what Ballerina does (first build fetches the latest release and records it in `Dependencies.toml`, patch releases are picked up, a newer minor release is the user's choice); verify the README contains no `[[dependency]]` and the description matches Ballerina's dependency documentation
- [x] 2.2 Make the same change on the site's install page; verify the page builds, `npm run check-links` passes, and it contains no `[[dependency]]` snippet
- [x] 2.3 Shrink the tutorial step 1 "Set up" section to `bal new` and the import, with no dependency snippet; verify the page builds and its program is unchanged
- [x] 2.4 Reword the first bullet of the compatibility page (what Ballerina records, and what a minor or patch release may change, linking COMPATIBILITY.md); verify it restates no rule that is not in `COMPATIBILITY.md`
- [x] 2.5 Verify the whole tutorial from a clean directory with no dependency block: rebuild each of the six steps from the code blocks of the built pages against Central, run steps 1 to 5 on a pseudo-terminal, and run step 6's tests; note anything that needed a fix

## 3. Continuous integration

- [x] 3.1 Open the pull request and verify that the build, native-image and `Documentation site` workflows pass, and that the build logs show the examples being pointed at the local build

## Workflow follow-up

- Archive the change after merge; the `project-delivery` spec then loses "Included examples are compiled in continuous integration" and gains "Included examples resolve termui from Ballerina Central".
