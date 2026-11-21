# Proposal

## Why

The site's "Start here" action opens a to-do list application: seven stages that add application state, a line editor, selection and deletion, JSON persistence and file I/O. A developer who wants to meet the smallest termui program first has to work through all of that. The counter already exists (the README, the concepts page, step 1 of the harness tutorial), but nothing leads a newcomer to it as a first program. The to-do list is a good second project and should stay, as a tutorial. See issue #37.

## What Changes

- The Quick start becomes the counter: an empty package, four compiling stages (skeleton, update, view, main), run it, then a short "what you wrote" and three ways to go on. It reuses `examples/counter`, which CI already builds and verifies.
- The tutorial section becomes two tracks under a "Tutorials" sidebar group: a to-do list and an agent harness. `/tutorial/` is a small page for choosing between them. The homepage's primary action still opens the Quick start; its second action opens the tutorials.
- The existing to-do page moves, unchanged in content, to `/tutorial/todo-list/`. Its example `examples/quick-start` is renamed `examples/todo-list` (package, CI list, recorder, contributor notes and cast included).
- The harness tutorial moves to `/tutorial/harness/`. The old addresses redirect. Step 1 no longer repeats the Quick start's setup and staging: it says the program is the one from the Quick start, shows it whole, and keeps its "Try this" exercises.
- Links into the moved pages, and out of them to the concepts pages, are updated.

Out of scope: splitting the to-do list into steps (the next change, `todo-step-by-step`); changes to the harness steps 2 to 6 beyond their addresses and the links in them; a unified counter example for the Quick start and harness step 1; the homepage hero.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `docs-site`: the quick-start requirements (which described the to-do program) are replaced by requirements for a counter Quick start; the tutorial requirement now describes two tracks; added requirements for the track chooser, the to-do tutorial, the harness tutorial's start from the Quick start, and redirects from the old addresses.

## Impact

- `site/src/content/docs/start/quick-start.mdx` is rewritten; `start/modules.md` has a link fixed.
- `site/src/content/docs/tutorial/` is split into `tutorial/index.mdx` (the chooser), `tutorial/harness/` (the index and six steps, moved) and `tutorial/todo-list/` (the moved to-do page); `site/astro.config.mjs` gains the sidebar group and the redirects; `site/src/content/docs/index.mdx` changes its second button.
- `examples/quick-start` becomes `examples/todo-list`; `examples/check.sh`, `examples/tutorial/record.py`, `CONTRIBUTING.md` and `site/public/casts/quick-start.cast` (renamed `todo-list.cast`) follow it.
- `examples/counter/main.bal`'s header comment mentions the site page. No package code, API, CI workflow or release is affected.
