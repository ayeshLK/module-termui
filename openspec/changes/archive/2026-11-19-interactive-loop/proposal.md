# Proposal

## Why

"The update and view loop" is the page that explains the core idea of termui, and it shows it twice in two different ways: a static diagram of the message flow at the top, and, further down, a separate small playground ("Try the loop") that lets you press keys and watch a state and a frame change. The playground never says which step of the diagram it is showing, and the diagram never shows the code. A reader has to connect the two on their own. Claude Code's documentation does better with its "Explore the context window" page: one interactive piece where you press play, click an event, and read what it is. The loop deserves the same: one diagram you can walk a message through, and click any step to see what it is and, for the steps that are your code, the code.

## What Changes

- Make the flow diagram on "The update and view loop" interactive, as a progressive enhancement of the static one:
  - **Send a message** (press `+`, `-`, `x` or `q`) and **step** it through the loop one step at a time (or play it through), with the current step highlighted: outside the program, the queue, the loop, `update`, the command, then `view` and the frame.
  - The **state** changes at the step where `update` runs, and the **frame** at the last step, so the reader sees which step causes which change.
  - **Select any step** to open an inspector: what the step does, who owns it (the colours of the diagram), and, for `update` and `view`, the real code from the counter example that CI compiles. The runtime's own steps show the contract and a link, not internal code.
- Keep a **written breakdown** of every step (the same explanations and the same code) in the page. With scripts it moves into the inspector; without scripts it is simply there, so nothing is lost.
- **Fold the separate playground into it.** The "Try the loop" section and the `LoopPlayground` component go away, so the page has one interactive diagram, not two.
- Make it usable by keyboard and assistive technology: every control is a real button, the current step is announced, and reduced-motion preferences are honoured (no automatic playing, no movement).

Out of scope: running the real termui runtime in the browser (this stays an illustration, labelled as one), interactive versions of the other diagrams, and any animation library or charting dependency.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `docs-site`: the requirement that the loop can be tried in the page grows from "send a message and see the state and frame" to stepping a message through the loop, selecting a step to see what it does and its code, and a written equivalent without scripts.

## Impact

- New component `site/src/components/diagrams/InteractiveLoop.astro` (with a small client script), built on the existing `Flow` markup; `LoopPlayground.astro` is removed.
- `site/src/content/docs/concepts/the-loop.mdx` changes: the interactive diagram replaces the static one and the "Try the loop" section.
- The code in the inspector comes from `examples/counter/main.bal` through the existing `ExampleCode` regions (`update`, `view`), so it cannot drift from compiled code.
- A small amount of client JavaScript on one page (no external library). No package code, API or release is affected.
