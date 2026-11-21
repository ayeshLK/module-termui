# Proposal

## Why

The to-do list tutorial is one long page of seven stages. The agent-harness tutorial, beside it, is six short steps that each end in a program that compiles, runs and is tested. A reader of the to-do list cannot stop partway with something that runs, and nothing on the page says what each new piece teaches. Splitting it the same way makes the two tutorials one shape, and gives each termui idea its own step.

## What Changes

- The to-do tutorial becomes five steps, each a complete program that compiles and runs, each starting from the one before:
  1. a list on screen, built from the Quick start's counter, that you move through
  2. check things off and delete them
  3. add items with the line editor
  4. leave the list in the terminal's scrollback when you quit
  5. keep the items in a file between runs
- `tutorial/todo-list/` becomes an overview page with a step list, like the harness's, and a page per step. The existing page's content moves into the steps; its stages are not rewritten beyond what splitting needs.
- Steps 1 to 4 get their own example packages with tests that drive them with scripted keys, and step 5 is the finished `examples/todo-list` with its existing tests. CI builds and tests all of them.
- Recordings for the steps that are easiest to follow by watching: moving through the list, adding items, and the finished program.

Out of scope: changes to the harness steps; a testing step for the to-do list (the best-practices testing page covers that); changes to the finished to-do program's behaviour.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `docs-site`: the to-do tutorial requirement now describes ordered steps that build the program; a new requirement says the track starts from the Quick start's counter and that its overview lists every step.

## Impact

- `site/src/content/docs/tutorial/todo-list/index.mdx` is rewritten as the overview; five step pages are added beside it. The chooser's card text and the Quick start's link are updated.
- `examples/tutorial/` gains four packages (`todo1-list`, `todo2-check`, `todo3-add`, `todo4-scrollback`); `examples/check.sh` and `examples/tutorial/record.py` learn about them; `CONTRIBUTING.md` lists them.
- `site/public/casts/` gains two recordings.
- No package code, API, CI workflow or release is affected.
