# Design

## Context

`tutorial/todo-list/index.mdx` is the to-do list as one page: seven stages (item type, skeleton, state, update, view, load and save, main) that end in the whole program from `examples/todo-list` (146 lines, 11 tests, built against the repository's library). The harness track beside it is `tutorial/harness/` with an index (a step list and a start button) and six step pages, each backed by a package under `examples/tutorial/` (built against the published release, interactive steps tested with a fake terminal) and, for the visual ones, a recording. The Quick start builds the counter in four stages. See proposal.md for why.

## Goals / Non-Goals

**Goals:**
- The to-do track has the same shape as the harness track: an overview, then steps that are each a complete, tested program.
- One new termui idea per step.

**Non-Goals:**
- Rewriting the finished program, or changing its behaviour.
- A sixth, testing step.

## Decisions

**Five steps, cut where the program gains one idea.** Each step's program is the previous one plus a change small enough to show in two or three snippets.

| Step | Adds | The idea |
|---|---|---|
| 1. A list on screen | `Item`, a `TodoList` that replaces the counter, `up` and `down`, `q`, quit when input ends | state is a field, `view` is drawn from it |
| 2. Check things off | `space` toggles, `d` deletes and clamps the selection, dim and `[x]` styling, an empty-list line | `update` changes a collection |
| 3. Add items | the `input` module's `LineEditor`, an `adding` mode, `update` split into `browsing` and `typing` | handing keys to a component |
| 4. Leave the list behind | a `leaving` flag, `summary()`, `commitProse` and `quit` in a batch, `view` drawing nothing on the way out | commands and committed output |
| 5. Keep it between runs | `loadItems`, `saveItems`, a `main` that loads and saves | ordinary Ballerina around the runtime |

Step 5's program is the finished `examples/todo-list` unchanged. Alternatives: merge steps 1 and 2 (rejected: a first page with navigation, toggling and deleting is too long); put the scrollback step after persistence (rejected: it is the distinctive termui idea, and file I/O is not).

**Step 1 starts from the Quick start's counter.** It replaces the `Counter` class with `TodoList` and changes one line of `main`, so the reader sees how little of the program is about the data. Its page says "start from the counter in your `main.bal`", and for a reader who skipped the Quick start it links to the counter's whole program. `update` handles `termui:InputEnded` from the first step, with a sentence on why, so every step works in a pipe and under a fake terminal.

**Steps 1 to 4 are packages under `examples/tutorial/`, step 5 is `examples/todo-list`.** The new packages are `todo1-list`, `todo2-check`, `todo3-add` and `todo4-scrollback`, flat beside the harness steps so the recorder and the CI list need no new layout. They are built against the published release, like the other tutorial packages, and use only API that release has. Step 5 stays where it is, so the finished program is still built against the repository's library and keeps its tests. Alternative: a nested `todo/` folder (rejected: the recorder and CI list assume flat names).

**Each step is tested with scripted keys.** A step's tests are the matching subset of the finished program's tests, run on a fake terminal: step 1 the selection staying in range and quitting, step 2 toggling and the selection after a delete, step 3 adding, ignoring an empty item and giving up with Escape, step 4 the list left in the scrollback, step 5 all 11 as today. Each step's page ends with a collapsed "How this step is tested" showing its tests from the example file by region, as the harness pages do. This is what "Each tutorial step's behaviour is checked" already asks of tutorial steps.

**Pages use the staged convention.** Each step page says what changed, then shows snippets that each say whether they replace or add, and adds only the imports they use, so the program compiles after every snippet. The complete step program is included from its example at the end of the page, collapsed. The overview page has a step list and a start button, as the harness's does; steps are `01-list` to `05-persist`, and the sidebar picks them up by autogeneration.

**Recordings for three steps.** Step 1 (moving through the list), step 3 (adding items) and step 5 (the finished program, the existing `todo-list.cast`). Steps 2 and 4 are explained by their screens and tests. The recorder gets scripts for `todo1-list` and `todo3-add`.

## Risks / Trade-offs

- [Four new packages and four sets of tests to keep in step with the finished program] -> The tests are small subsets of the finished program's tests, and `examples/check.sh` builds and runs all of them in CI.
- [The to-do page's text has to be split, not just cut] -> The stages keep their wording; each step adds a short intro and "what changed" list. Links from the old single page go to the overview.
- [Step 3 moves code: `update` becomes a dispatcher plus `browsing` and `typing`] -> It is shown as one "replace `update` with these three functions" snippet, as the single page does now.

## Migration Plan

Build every snippet of every step page once in a scratch package, assembled from the page's own code fences, and check that each step's last snippet gives exactly that step's example file. Run the new tests locally, then `examples/check.sh`, the site build and the link check. The old single page's address (`/tutorial/todo-list/`) becomes the overview, so it needs no redirect.
