# Tasks

## 1. The program and its tests

- [x] 1.1 Create `examples/quick-start` (`Ballerina.toml` with no dependency block, `main.bal` with the licence header and region markers `state`, `update`, `view`, `main`): a to-do `Program` with a browsing mode (up and down select, space toggles done, `d` deletes, `a` starts an add, `q` quits) and an adding mode (an `input:LineEditor`; enter appends and returns to browsing, escape cancels); verify `bal build` succeeds and a scratch run in a terminal shows each key doing what it says
- [x] 1.2 Load and save in `main`: read `todos.json` (an empty list when the file is missing, an error from `main` when it holds something that is not a list of items), run the program, and write the items back when `run` returns; verify by running twice, adding an item in the first run and seeing it in the second, and by running with a corrupt file and seeing the error and the file left untouched
- [x] 1.3 On `q`, commit the final list to the scrollback as prose before quitting; verify in a real terminal that the list stays visible after the program exits
- [x] 1.4 Test it in `examples/quick-start/tests/` against a fake terminal: add, toggle, delete, cancel an add, selection stays in range after a delete (including the last and the only item), quit commits the list; and a test that `main`'s load and save round-trip through a temporary file; verify `bal test` passes and fails when the toggle is made a no-op
- [x] 1.5 Add `quick-start` to the directory list in `examples/check.sh`; verify `sh examples/check.sh` builds and tests it with the others
- [x] 1.6 Settle the open question: try `bal run` with piped input and with output redirected, and decide whether a clean result can go on the page; verify the decision is written in `design.md` with the output seen

## 2. The recording

- [ ] 2.1 Record the program with a script that adds two items, completes one, deletes one and quits, using the existing pty recorder (a new entry in its scripts); verify the cast plays in the site's player, shows the final list in the scrollback at the end, and has no personal paths or names in it

## 3. The pages

- [ ] 3.1 Replace `start/install.md` with `start/quick-start.mdx`: requirements in a line, `bal new`, the import (with the note that there is nothing to add to `Ballerina.toml`), the program in four pieces with `ExampleCode` regions and the whole file, `bal run`, the recording, what just happened in a few lines, and links to the loop concept and the tutorial; verify the page builds and every code block is from the example file
- [ ] 3.2 Add `start/modules.md` with the module table, the pointer to the API reference and the versions note that stays relevant; verify both pages appear in the sidebar in the order quick start, modules
- [ ] 3.3 Point the home page's "Start here" button at `start/quick-start/` and fix every link that named `start/install`; verify `npm run check-links` passes and a search for `start/install` finds nothing in the site, README or CONTRIBUTING.md
- [ ] 3.4 Review the pages in light and dark mode at normal width and at a real 390px viewport: no horizontal overflow, the recording readable; verify with measurements as for the other pages

## 4. Housekeeping

- [ ] 4.1 Update `CONTRIBUTING.md` where it lists the examples or the docs-site pages; verify the commands it names run
- [ ] 4.2 Run the whole local check: `sh examples/check.sh`, `npm test`, `npm run build` and `npm run check-links`; verify all pass

## Workflow follow-up

- Land groups 1 and 2 as one pull request (the example and its recording), and groups 3 and 4 as a second, so the site never links to an example that is not there.
- Archive the change after merge, which syncs the added `docs-site` requirements.
