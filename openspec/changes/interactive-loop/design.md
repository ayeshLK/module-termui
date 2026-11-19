# Design

## Context

See proposal.md for the motivation. The page "The update and view loop" has a static `Flow` diagram (steps coloured by owner, a dashed "the loop" group, a feedback arc, a `view` branch) and, further down, `LoopPlayground`, a separate small JavaScript illustration (four key buttons, an update readout, a state box and a frame box). The `docs-site` spec already allows interactive components and requires the page's text and code to be readable without scripts. `ExampleCode` renders regions of compiled example files; `examples/counter/main.bal` has regions `update` and `view`. The site has no JavaScript framework and the other diagram components emit no script. The reference for the idea is Claude Code's "Explore the context window": one panel with controls, an inspector that follows hover or click, and a written breakdown of the same content for people who cannot or do not want to play it.

## Goals / Non-Goals

**Goals:**
- One interactive diagram that answers "what happens to a message, and whose code runs when" by letting the reader walk a message through the steps.
- The real counter code for the steps that are the reader's, kept honest by the existing compile checks.
- Nothing is lost without scripts, and nothing is hidden from keyboard or assistive-technology users with them.
- A small, dependency-free script whose logic is testable without a browser.

**Non-Goals:**
- Running the real termui runtime in the browser. The component says it is an illustration.
- Showing the runtime's internal code. It is not public API and would change; the runtime's steps show the documented contract and a link.
- Making the other diagrams interactive.

## Decisions

**Progressive enhancement over the existing markup, not a separate widget.** The server renders the same `Flow` diagram as today, with a `data-step` id on each step, plus a *written breakdown* (a section per step) and the readouts' initial values. A client script then enhances it: it turns each step's pill into a button, adds the controls, and shows one breakdown section at a time. Without the script the page shows the static diagram and every section, in order. Alternative: a client-rendered widget that replaces the diagram; rejected because it would leave nothing at all without scripts and would duplicate the diagram markup.

**The inspector is the breakdown, not a copy of it.** The sections already in the page are the inspector's content. With the script they are stacked in one grid cell, so the inspector is as tall as the tallest section (the page does not jump when the reader switches steps, and it needs no measuring, so it stays right when the width changes); only the selected one is visible, the others are `visibility: hidden` and so also out of the accessibility tree. A "Show all steps" button puts them all back in normal flow for linear reading. There is no cloning, so the highlighted code blocks keep their copy buttons and their listeners, and there is one source of text. Alternative: clone content into a separate panel; rejected for the lost listeners and the duplication.

**Content per step.**

| Step | Owner | Inspector shows |
|---|---|---|
| keys, resizes, timers, effect results | outside | what can happen to a program and that each becomes a message |
| message queue | runtime | one queue, so `update` never runs twice at once |
| loop | runtime | applies every waiting message, then draws one frame |
| `update(message)` | yours | the `update` region of `examples/counter/main.bal` |
| command | runtime | what `update` returns (`quit()`, `effect`, `commitProse`, `every`, `batch`, or nothing), with a link to the commands page |
| `view()` | yours | the `view` region of `examples/counter/main.bal` |
| one frame per batch | runtime | only changed cells are written, with a link to the inline-rendering page |

**The walk is a small pure model.** `site/src/lib/loop-walk.ts` holds the logic with no DOM: given the counter's state and a key (`+`, `-`, `q`, or any other key) it returns the ordered stops a message takes (outside, queue, loop, update, command, view, frame), what the state is after `update`, what the command is (nothing, or `quit()`), what the frame is, and whether the frame changed. It mirrors the counter's `update` and `view` and is covered by `node --test`, which runs TypeScript directly on the Node the site already requires. The script only maps stops to highlights and readouts. A walk for `q` ends at the command (the program quits); a key the counter ignores ends at the frame with "unchanged, so nothing is written". Alternative: logic inline in the script; rejected because it could not be tested without a browser.

**Controls.** *Send* buttons for `+`, `-`, `x` and `q` start a walk. *Step* advances one stop, *Play* advances every 900 ms, *Reset* returns to the start. Sending during a walk abandons it and starts the new one. The state readout changes when the walk reaches `update` and the frame readout when it reaches the frame, so the reader sees which step causes which change.

**Reduced motion.** The decision is a pure function of the reader's preference (`autoplayAllowed(prefersReducedMotion)`), tested the same way. When motion is reduced the *Play* control is not offered and no timer runs; stepping by hand is unchanged, and the only visual change is the highlight moving. CSS transitions (the readout's brief emphasis) are inside `prefers-reduced-motion: no-preference`.

**Accessibility.** Steps and controls are real `<button>`s in the page's tab order; the active step has `aria-current="step"`; the selected one has `aria-pressed`. A visually hidden `role="status"` region announces each stop ("Step 4 of 7: update(message), your program: ..."). "Show all steps" restores the full written breakdown to assistive technology. Focus is never moved by stepping or playing. The inspector's height is reserved from its tallest section so the page does not jump when the reader switches steps.

**Where it lives.** A new `InteractiveLoop.astro` renders the `Flow` markup (with ids), the controls' mount point, the breakdown, and the readouts, and ships the script. `the-loop.mdx` uses it at the top in place of the static `Flow`, and the "Try the loop" section and `LoopPlayground.astro` are removed. The counter code comes from `ExampleCode` regions. Alternative: keep the playground as a second interactive piece; rejected: two interactive explanations of one loop, side by side, is the problem this change exists to fix.

**Elements the script creates need the component's style scope.** Astro scopes a component's CSS with a `data-astro-cid-*` attribute, so the buttons the script makes (the step buttons that replace `Flow`'s pills, and the controls) would lose the styles of the component that rendered what they stand in for. The script copies those attributes onto what it creates. This was found, not foreseen: the first run showed unstyled controls and a diagram wider than its panel.

## Risks / Trade-offs

- [The model drifts from the real counter] → It mirrors a five-line `update` and a two-line `view`; the inspector shows the real code beside it, and a test pins the model's behaviour for `+`, `-`, `q` and an ignored key. If the counter changes, the page's code changes with it (regions) and the model is the one place to update.
- [Client JavaScript on a documentation page] → One page, no library, about a few hundred lines, written so the page is complete without it.
- [Breakdown sections hidden from assistive technology with the script on] → "Show all steps", and the announcements carry each step's explanation.
- [Layout jumps as sections differ in height] → Reserve the tallest height once on load, at the wide layout.
- [The walk's order oversimplifies the real loop, which batches messages] → Say so in the "loop" step ("every message that is waiting, then one frame") and in the caption.

## Migration Plan

1. Land the pure model and its tests first, with the CI step (`npm test`).
2. Land the component with the page change in one pull request, so the page never has two interactive pieces or none.
3. Review it in a browser with the same measurements used for the other diagrams (overflow, overlaps, focus order, light and dark, a real 390px viewport) and with scripts disabled.
Rollback is reverting the pull request; the static diagram is what is left.

## Open Questions

- Resolved: *Play* stops at the end (the frame, or the command after `q`).
