# Tasks

## 1. Quick start (the pattern)

- [x] 1.1 Build the Quick start's skeleton in a scratch package under the scratchpad and record whether `bal build` accepts it without a `main` and whether an unused import is an error; verify by noting both answers at the top of the scratch notes and, if a `main` is needed, adding it to the skeleton stage
- [x] 1.2 Rewrite "Write the program" in `site/src/content/docs/start/quick-start.mdx` as stages (types, skeleton, state, `update`, `view`, storage, `main`), each snippet saying whether it replaces or adds, with each stage's imports and the `summary()` helper defined where first called; verify by reading the page and checking every snippet is introduced with one of the three phrases from design.md
- [x] 1.3 Assemble the stages in a scratch package and run `bal build` after each; verify every stage builds and the last stage is identical to `examples/quick-start/main.bal` (`diff` is empty), fixing snippets, not the example
- [x] 1.4 Keep "The whole program" as an `ExampleCode` include of the whole file, remove the `// region` markers from `examples/quick-start/main.bal`, and verify `npm run build` in `site/` succeeds and `examples/check.sh` still builds and tests the example
- [x] 1.5 Review the Quick start page with the user as the pattern before continuing; verify the user's go-ahead (or requested changes, applied) before group 2

## 2. Tutorial steps 1 to 3

- [x] 2.1 Rewrite the program section of `01-counter.mdx` as stages starting from a skeleton; verify with a scratch build after each stage and an empty `diff` of the last stage against `examples/tutorial/step1-counter/main.bal`
- [x] 2.2 Rewrite `02-prompt.mdx` with its first stage being step 1's complete program and each snippet saying what it replaces or adds; verify with a scratch build after each stage and an empty `diff` against `examples/tutorial/step2-prompt/main.bal`
- [x] 2.3 Rewrite `03-streaming.mdx` the same way, covering the scripted model, state, turn start, stream handling and drawing as separate stages; verify with a scratch build after each stage and an empty `diff` against `examples/tutorial/step3-streaming/main.bal` and `model.bal`
- [x] 2.4 Remove `// region` markers from the step 1 to 3 sources where no page still uses them; verify `npm run build` in `site/` succeeds and `examples/check.sh` still passes for those steps

## 3. Tutorial steps 4 and 5

- [x] 3.1 Rewrite `04-status.mdx` with its first stage being step 3's complete program, staging the status state, the interrupt, the timer and the status line; verify with a scratch build after each stage and an empty `diff` against `examples/tutorial/step4-status/main.bal` and `model.bal`
- [x] 3.2 Rewrite `05-approval.mdx` with its first stage being step 4's complete program, staging the confirm request and the headless default; verify with a scratch build after each stage and an empty `diff` against `examples/tutorial/step5-approval/main.bal` and `model.bal`
- [x] 3.3 Remove `// region` markers from the step 4 and 5 sources where no page still uses them; verify `npm run build` in `site/` succeeds and `examples/check.sh` still passes for those steps

## 4. Integration

- [x] 4.1 Check that the tutorial index, "Next" links and each page's "What changed" text still match the rewritten pages; verify `node site/scripts/check-links.mjs` reports no broken links
- [x] 4.2 Confirm the pages left out of scope (concepts, best-practices, step 6) still build with their excerpts; verify `npm run build` in `site/` succeeds and `ExampleCode` region includes on those pages still resolve
- [x] 4.3 Run `openspec validate stage-docs-code --strict`; verify it reports the change valid

## Workflow follow-up

- Archive the change after review and sync the `docs-site` spec.
