# Proposal

## Why

The first page under "Start here", "Install and run", installs nothing and runs nothing. It is a package overview: the Central link, a note on versions and a table of the five modules. A reader who wants to know what using termui is like has to start the tutorial, whose first step is a counter inside a longer path to an agent harness. For a library, the first page is expected to be a quick start: add the import, write a small program that does something worth keeping, run it, see it work.

## What Changes

- Replace the page `start/install` with a **Quick start** page at `start/quick-start`. It lists the requirements in a line, creates a package, imports termui, builds a small to-do list a piece at a time (state, `update`, `view`, `main`), runs it, and shows it working with a recording. It ends by saying what just happened and where to go next.
- The to-do list is a real, small program: browse with the arrow keys, add an item with a text input, mark it done, delete it, quit. Items are loaded from a JSON file in `main` before the run and saved after it, so the list survives between runs. On quit the final list is written into the scrollback, so it stays on screen after the program exits.
- Add the program as `examples/quick-start`, a complete package built and tested by `examples/check.sh` and the site workflow, and include it in the page from the file. Record the demonstration from the real program.
- Move the module table ("The five modules") to its own page in "Start here", after the quick start, and keep the pointer to the API reference there.
- Point the home page's "Start here" button and every other link at the new address.
- Leave the tutorial and the README quickstart as they are. Tutorial step 1 stays the counter, and the README keeps its short counter.

Out of scope: a piped or headless run on the page (the design decides whether it can be shown cleanly), a redirect from the old address, and any change to the library.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `docs-site`: the site gains a requirement for a quick-start page that builds and runs a small program with the library, and that program is held to the same rule as tutorial programs, namely that it is compiled and tested in continuous integration.

## Impact

- `site/src/content/docs/start/` (the install page is replaced by the quick start and a modules page), `site/src/content/docs/index.mdx`, `site/public/casts/` (one new recording).
- `examples/quick-start/` (new), `examples/check.sh`, `examples/tutorial/record.py` or a recorder for the new example.
- `CONTRIBUTING.md` if its list of examples or its docs-site section names the install page.
