# Tasks

## 1. Step programs and tests

- [x] 1.1 Create `examples/tutorial/todo1-list`: a `Ballerina.toml` like the other tutorial steps and a `main.bal` that is the counter turned into `TodoList` (the item, `up`, `down`, `q`, quit when input ends, a view with the selection marker), with tests for the selection staying in range and for quitting
- [x] 1.2 Create `examples/tutorial/todo2-check`: step 1 plus `space` and `d`, dim and `[x]` styling and the empty-list line, with tests for toggling, the selection after deleting the last item and deleting the only item
- [x] 1.3 Create `examples/tutorial/todo3-add`: step 2 plus the line editor, the `adding` mode and `update` split into `browsing` and `typing`, with tests for adding, ignoring an empty item and giving up with Escape
- [x] 1.4 Create `examples/tutorial/todo4-scrollback`: step 3 plus `leaving`, `summary()` and the batched `commitProse` and `quit`, with a test that the list is left in the scrollback
- [x] 1.5 Check that step 4 plus the file helpers and `main` of `examples/todo-list` is exactly `examples/todo-list/main.bal`, so step 5 needs no new package
- [x] 1.6 Add the four packages to `examples/check.sh` and run it: every package builds and its tests pass

## 2. Pages

- [x] 2.1 Rewrite `site/src/content/docs/tutorial/todo-list/index.mdx` as the overview: what is built, a step list of five steps and a start button, in the harness index's style, with the sidebar label unchanged
- [x] 2.2 Write `01-list.mdx`: start from the counter in `main.bal`, replace it with `TodoList` in staged snippets, explain state and `view`, explain `InputEnded`, include the whole program from `todo1-list`, add a collapsed "How this step is tested"
- [x] 2.3 Write `02-check.mdx`: what changed, the `update` and `view` snippets, the whole program from `todo2-check`, how it is tested
- [x] 2.4 Write `03-add.mdx`: the `input` import, the new fields, `update` as three functions, the view with the editor, the whole program from `todo3-add`, how it is tested
- [x] 2.5 Write `04-scrollback.mdx`: `leaving`, `summary`, the batched command and the empty view, with a pointer to the inline-rendering concept, the whole program from `todo4-scrollback`, how it is tested
- [x] 2.6 Write `05-persist.mdx`: the two imports, the load and save helpers, `main`, the finished program from `examples/todo-list`, how it is tested, and a "Next" that links to the concepts and to the harness track
- [x] 2.7 Update the chooser's card text to say five steps

## 3. Recordings

- [x] 3.1 Add scripts for `todo1-list` and `todo3-add` to `examples/tutorial/record.py`, record both, and use them on their pages; step 5 uses the existing `todo-list.cast`

## 4. Wording elsewhere

- [x] 4.1 `CONTRIBUTING.md`: say the to-do tutorial is five steps (`examples/tutorial/todo1-list` to `todo4-scrollback` and `examples/todo-list`), and where its recordings come from
- [x] 4.2 Look for other places that call the to-do list a single page and fix them

## 5. Check

- [x] 5.1 For each step page, build every snippet in order in a scratch package and check that the last one equals the step's example file (ignoring the header comment and region markers)
- [x] 5.2 Build the site, then run `npm test`, `npm run check-links` and `examples/check.sh`
- [x] 5.3 Look at the overview, each step and the sidebar in a browser, with scripts on and off, in both colour themes and at phone width, and play the two new recordings

## Workflow follow-up

- Archive the change after review, syncing the `docs-site` requirements.
