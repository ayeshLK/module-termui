# Design

## Context

"Start here" opens `start/quick-start.mdx`, a seven-stage to-do list included from `examples/quick-start` (which has 11 tests). The counter exists as `examples/counter` (CI builds it against the repository's library and runs `verify.py` on a pseudo-terminal; its regions feed the concepts page), as `examples/tutorial/step1-counter` (harness step 1, built against the published release) and in the README. The tutorial lives at `/tutorial/` with `index.mdx` and six steps, listed in the sidebar by autogeneration from that folder. Casts are in `site/public/casts/`: `counter-demo.cast` (the counter), `quick-start.cast` (the to-do list). See proposal.md for why.

## Goals / Non-Goals

**Goals:**
- A newcomer's first program is the counter, finished in about five minutes.
- The to-do list stays, as one of two clearly separate tutorials, and the layout is ready for it to become steps.

**Non-Goals:**
- Splitting the to-do list into steps (the next change).
- Merging `examples/counter` and `step1-counter`.

## Decisions

**The Quick start is the counter, built in four stages, with the whole program included at the end.** The stages are a skeleton with empty `update` and `view`, then `update`, then `view`, then `main`, using the convention from the staged-snippets work: each snippet says whether it replaces or adds, each stage adds only the imports it uses. The complete program is included from `examples/counter/main.bal`, which CI already builds and verifies, so the page cannot drift from compiled code. The page says "build after any stage to check", but only asks for a run at the end, so staged builds do not eat the five minutes. Alternatives: one pasted block with annotations (rejected: the reader asked for stages, and a block gives no checkpoints); including `step1-counter` (rejected: it is built against the published release, so a change in the repository would not be tested against the page).

**After running, the page explains in a few sentences and suggests one change.** "What you wrote" has three bullets (the class is the program, `update` handles messages, `view` describes the screen), then "Change one thing": make `+` add ten. The "Where next" section has three links: the tutorials, the to-do list, and the update and view loop concept. The recording is `counter-demo.cast`.

**The tutorial section is split in two, with a chooser at `/tutorial/`.** The files move to `tutorial/harness/` (the index and six steps), `tutorial/todo-list/` (the to-do page, as `index.mdx` for now, so the next change can add steps beside it) and `tutorial/index.mdx` (a short page with a card for each track). The sidebar has a "Tutorials" group with the chooser and one subgroup per track, each using autogeneration from its folder. Alternatives: leave the harness at `/tutorial/` and group in the sidebar (rejected: asymmetric addresses, and the sidebar needs a hand-kept list); put the to-do list outside the tutorials (rejected: it is a worked project, which is what the section is for).

**Old addresses redirect.** The six old step addresses (`/tutorial/01-counter/` to `/tutorial/06-testing/`) get entries in Astro's `redirects`, which writes a small page at each old address that sends the reader on. Astro does not add the site's base path to a redirect's target, so the config adds it. `/tutorial/` itself is now the chooser, so it needs no redirect: a reader with the old link lands on the page that offers the harness. The site is only days old, but published links should still work.

**The example is renamed `examples/todo-list`, and stays under `examples/`.** The rename follows the page's new name; the package becomes `todo_list`. It stays out of `examples/tutorial/` because that folder is built against the published release while the others under `examples/` are built against the repository's library, and the to-do tests should keep running against the repository. The recorder's name for it, its cast (`quick-start.cast` becomes `todo-list.cast`), the CI example list and `CONTRIBUTING.md` follow.

**Harness step 1 keeps its program and drops its setup.** `examples/tutorial/step1-counter` and step 2's starting point do not change, so the chain of steps stays intact. The page loses its "Set up" section and its four stages: it says "this is the program from the Quick start", shows it whole, keeps "Try this" (including the headless exercise, which the Quick start does not cover) and the "Next" link. A reader who skipped the Quick start can copy the whole program from step 1, so it stays self-sufficient.

**The homepage's second button opens the tutorials.** Its text becomes "Tutorials" and it links to the chooser. The first button still opens the Quick start, which is now the short page. The to-do list is reached through the chooser, the Quick start's "Where next" and the sidebar.

**Links are fixed by the link checker.** Moving the harness one level down makes its `../../concepts/` links need one more `../`, and links between harness steps stay sibling-relative. `npm run check-links` fails on any link left pointing at a path that no longer exists, so the moves are done and then checked, not audited by hand.

## Risks / Trade-offs

- [Step 1 and the Quick start show the same program] -> Different jobs: the Quick start builds it, step 1 shows it and goes further. Merging `counter` and `step1-counter` into one example is a possible later cleanup, not part of this change.
- [Old addresses are redirected by a page with a meta refresh, not a server redirect] -> Enough for a static site on GitHub Pages; search engines follow it.
- [The to-do page, after the move, still says it is a "Quick start" in places] -> The move includes rewording its introduction and title to a tutorial ("A to-do list") and its "Next" section to the harness track.
- [Two changes touch the to-do page in turn] -> This change moves the page without changing its stages, so the next change starts from a stable file.

## Migration Plan

Verify the four Quick-start stages once locally in a scratch package built from the page's own code fences (each compiles; the last matches `examples/counter/main.bal`), as for the staged pages. The rename and the moves are done with `git mv` so history follows. After the build and link check pass, check every redirect in the built site (each target page exists).
