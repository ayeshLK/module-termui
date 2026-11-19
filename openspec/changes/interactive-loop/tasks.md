# Tasks

## 1. The walk model and its tests

- [ ] 1.1 Write `site/src/lib/loop-walk.ts`: a pure model of the counter's loop that, given the state (`count`) and a key (`+`, `-`, `q`, or any other), returns the ordered stops a message takes (outside, queue, loop, update, command, view, frame; a `q` ends at the command), the state after `update`, the command (nothing or `quit()`), the frame, and whether the frame changed; plus `autoplayAllowed(prefersReducedMotion)`; verify it compiles under `node` type stripping and a scratch call prints the expected walk for `+`
- [ ] 1.2 Test it with `node --test` (`+` increments and changes the frame, `-` decrements, an ignored key leaves state and frame unchanged and ends at the frame, `q` ends at the command with `quit()`, the stops are in order, `autoplayAllowed(true)` is false); add `npm test` to `site/package.json`; verify `npm test` passes and fails when the model is changed to be wrong
- [ ] 1.3 Run `npm test` in the site workflow before the build and note it in `site/README.md`; verify with `actionlint` and that a deliberately broken model fails the workflow's test step locally

## 2. The component without its script

- [ ] 2.1 Give `Flow` an optional `id` per step that is emitted as `data-step`, with no change to its output when no ids are given; verify every existing `Flow` page builds to identical HTML
- [ ] 2.2 Build `InteractiveLoop.astro`: the `Flow` with ids, a written breakdown (one section per step in the table of the design, the `update` and `view` sections using `ExampleCode` regions of `examples/counter/main.bal`), the initial state and frame readouts, a caption, and the note that it is an illustration with a link to `examples/counter`; verify the built HTML has all seven sections, the real counter code, and no `hidden` attribute (so the page is complete without scripts)
- [ ] 2.3 Check the no-script page: strip scripts from the built HTML and look at it in a browser; verify every step's text and code is visible, in order, in light and dark mode, and at a real 390px viewport

## 3. The enhancement script

- [ ] 3.1 Write the client script: turn each step's pill into a button, add the controls (send `+` `-` `x` `q`, Step, Play, Reset, Show all steps), show only the selected breakdown section, and reserve the inspector's height from its tallest section; verify in a browser that selecting each step shows its section and that the page height does not change when switching
- [ ] 3.2 Walk a message through with the model: highlight the current step with `aria-current="step"`, change the state readout at `update` and the frame readout at the last step, follow the walk with the inspector, and stop or restart correctly when a new message is sent mid-walk; verify by stepping `+`, `+`, `x`, `-` and `q` and comparing every readout with the model's output
- [ ] 3.3 Add Play (every 900 ms, stopping at the end), the polite status announcements, and the reduced-motion behaviour (no Play, no timer, no transitions outside `prefers-reduced-motion: no-preference`); verify the status text for each stop in a browser, that Play reaches the end and stops, and that the CSS motion rules are inside the media query
- [ ] 3.4 Verify keyboard use: tab through the controls and steps in a sensible order, activate each with Enter and Space, see a visible focus ring, and confirm stepping never moves focus; check focus order and the ring with a script and a screenshot

## 4. The page, and the review

- [ ] 4.1 Use `InteractiveLoop` at the top of "The update and view loop" in place of the static diagram, remove the "Try the loop" section and `LoopPlayground.astro`, and fix any links to the removed section; verify the page builds, the link check passes, and nothing refers to the playground
- [ ] 4.2 Review the page in light and dark mode at the normal width and at a real 390px viewport: no horizontal overflow, no overlaps, readable text, the inspector and readouts stacked when narrow; measure as for the other diagrams and fix what is found
- [ ] 4.3 Update `CONTRIBUTING.md` (the loop diagram now lives in `InteractiveLoop`, plus the model and `npm test`) and verify the described commands run

## Workflow follow-up

- Land group 1 as its own pull request, then groups 2 to 4 together, so the page never has two interactive pieces or none.
- Archive the change after merge, which syncs the modified `docs-site` requirement.
