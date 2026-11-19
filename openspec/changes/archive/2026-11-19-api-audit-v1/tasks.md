# Tasks

## 1. Make internals non-public

- [x] 1.1 Make `Queue` and `PromptRequest` non-public in the root module and verify `bal build` and the root tests pass (the compiler shows if a public signature needs them)
- [x] 1.2 Make `probeStdio`, `parseStdioProbe`, `isTerminalPath` and `environmentFrom` non-public in `term` (and `DEFAULT_WIDTH`/`DEFAULT_HEIGHT` if the compiler allows) and verify the `term` tests still pass, since tests live in the module
- [x] 1.3 Re-run the usage search over `ballerina/` and `examples/` for every remaining public symbol and verify each one is either supported API or listed as low-level in its module page; record any change to the classification table in design.md

## 2. Frozen contracts and growth rule

- [x] 2.1 Add a test with a minimal third-party renderer (only the five required methods) driving a program through the runtime, and verify it passes; add the same for a minimal terminal with no `CursorReporter`
- [x] 2.2 Document the growth rule and the capability-type pattern on `Renderer` and `Terminal` and in the `Module.md` of `render`, `term` and the root, and tell programs to ignore unknown messages and events; verify the wording appears in each page
- [x] 2.3 Add a test that the default `Options` have the stable values (`colors`, `reflow`, `anchorBottom`, `interactive`, `pollInterval`) and document them in `Package.md`; verify the test passes

## 3. Docs and migration

- [x] 3.1 Check that every public symbol has a documentation comment (run `bal doc` and read the warnings, or search) and fix gaps; verify the generated docs have no undocumented public symbol
- [x] 3.2 Add a "Stability" section to each `Module.md` naming the supported API and the low-level pieces, and verify the four pages and `Package.md` agree
- [x] 3.3 Write the list of removed symbols and their replacements (if any) into design.md under "Migration", for the changelog in `v1-release-readiness`; verify examples and tests build against the final surface (`./gradlew build`, and the examples build in CI)

## Workflow follow-up

- Release as 0.3.0 once the user approves, then archive the change.
