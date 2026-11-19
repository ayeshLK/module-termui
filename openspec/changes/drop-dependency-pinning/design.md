# Design

## Context

See proposal.md for the motivation. Today every example manifest carries `[[dependency]]` with `version = "1.0.0"`. `.github/scripts/point-examples-at-source.sh` rewrites that block's version to the one in `ballerina/Ballerina.toml` and adds `repository = "local"`, so CI (`build.yml`, `native-check.yml`) and a contributor can build the examples against the working tree after `bal pack && bal push --repository=local`. The script only matches `examples/*/Ballerina.toml`, so the tutorial packages (`examples/tutorial/*/`) are never pointed at source; the `Documentation site` workflow builds them against Central. `examples/**/Dependencies.toml` is git-ignored.

How Ballerina behaves, from its own documentation: on the first build with no `Dependencies.toml`, an imported package is resolved from Central and the version is recorded; later builds treat the recorded version as a minimum and pick up patch releases; a newer minor release is the user's choice. The `[[dependency]]` table is only needed to pin a version or use a local repository, and the second is exactly what the script needs.

## Goals / Non-Goals

**Goals:**
- Docs and examples show the normal Ballerina way: import, build, let Ballerina record the version.
- Releasing termui no longer needs a commit that moves the examples to the new version.
- The source-pointing script keeps working, and is safe to run more than once.

**Non-Goals:**
- Committing `Dependencies.toml` for the examples, or locking them to a major version.
- Pointing the tutorial packages at source (they are built against the published release, as before).

## Decisions

**Delete the block, do not replace it with an empty one.** An example manifest has only `[package]`. The import in `main.bal` is enough. Alternative: keep `[[dependency]]` without a `version`; rejected because Ballerina requires a version in that block, and the point is to show the plain case.

**The script appends a block instead of editing one.** With no block to edit, it removes any existing `termui` dependency block (so a second run replaces the first) and appends:

```toml
[[dependency]]
org = "ayesha"
name = "termui"
version = "<version of the build>"
repository = "local"
```

The version still comes from `ballerina/Ballerina.toml`. It writes through a temporary file and fails loudly if it cannot read the version, as it does today. `git checkout examples` still undoes it, because the manifests are tracked and the block is only ever appended in the working tree.

**Prose says what Ballerina does, not what to do.** The replacement text is a description (the first build fetches the latest release and records it; patch releases are picked up; a newer minor release is your choice), and it links to COMPATIBILITY.md for what each kind of release may change. It does not tell readers to edit any file. Alternative: link Ballerina's dependency documentation instead of describing it; kept as an addition to the compatibility page only, since the install page should work on its own.

**The tutorial's "Set up" shrinks to `bal new` and the import.** Step 1 already shows `import ayesha/termui;` as part of the program. The page no longer has a separate dependency snippet.

**CONTRIBUTING's rule changes meaning, not strength.** "Use only released API in tutorial and example programs" stays. Its reason changes from "they pin a published version" to "they resolve the published release from Central, so a page matches what a reader can install".

## Risks / Trade-offs

- [A future 2.0.0 is picked up by fresh clones of the examples, and by a reader's new package] → Accepted for now. Within a major version nothing breaks (see COMPATIBILITY.md). When 2.0.0 is planned, either update the examples and pages in the same release or add a `Dependencies.toml` for them; this is noted here so the decision is not forgotten.
- [An example fails to build in CI the day a release lands that changes behaviour it relies on] → The same exposure the daily build against the latest Ballerina already accepts, and a failure here is a useful signal. Patch and minor releases follow the compatibility policy.
- [A reader on an older machine already has a `Dependencies.toml` from before] → Ballerina keeps their recorded version, which is the point of the lock file; nothing in the docs needs to say more.
- [The script changes behaviour for a contributor who runs it by hand] → Same command, same result (the examples build against the working tree), same advice to not commit it. The CONTRIBUTING section is updated to match.

## Migration Plan

1. Land the script change first, together with the manifest edits, in one pull request so CI exercises the new script on every example.
2. Update the prose in the same pull request, so no page tells readers to do something the examples no longer show.
3. Verify by rebuilding the tutorial steps from the built pages in a clean directory with no dependency block, as was done when the tutorial was finished.
Rollback is reverting the pull request.

## Open Questions

- Whether the compatibility page should also link Ballerina's dependency documentation. It does not change the specs or the tasks and can be decided while writing the page.
