# Proposal

## Why

Two parts of the documentation look dated next to the rest of the site. The tutorial index lists the six steps as a plain Markdown table with underlined links, which does not read as a path to walk in order. And five diagrams are ASCII art in code fences: the message flow on "The update and view loop", the live region on "Inline rendering" (twice), the backoff curve on "Idle cost", and the four layers on "Testing it". The message flow also exists, in slightly different spellings, in the README and two `Module.md` files. The site is the first thing a newcomer sees, and these are the pages that explain the core idea, so they should look as considered as the home page does.

## What Changes

- Add a small set of presentational components to the site, built on Starlight's colour tokens so light and dark mode follow the theme, with no JavaScript:
  - `StepList`: an ordered list of linked steps (number, title, what you build, "you learn" chips) with a "Start with step 1" button, replacing the table on the tutorial index.
  - `Flow`: a message-flow diagram of steps and one branch, stacking vertically on narrow screens, replacing the diagram on "The update and view loop".
  - `Screen`: a terminal-styled stack of rows (committed output, gap, live region, prompt), replacing the two diagrams on "Inline rendering".
  - `BackoffChart`: an SVG chart of the idle backoff, with its numbers read from the source constants at build time, replacing the curve on "Idle cost".
  - `Layers`: a numbered list of layers (what you test, how), replacing the fenced table on "Testing it".
- Give every diagram a caption and a text equivalent, so it is understandable without seeing it.
- In the README, replace the unicode-arrow loop diagram with a Mermaid block (GitHub renders it). In `ballerina/Module.md` and `ballerina/modules/render/Module.md`, which Ballerina Central shows, keep ASCII, tidied and worded identically to one another.
- Note in `CONTRIBUTING.md` where the loop diagram's wording lives (site, README, `Module.md`), so a change to it is made in each.

Out of scope: restyling the site's other tables (they are real tabular data), changing the loop playground, the home page, or the theme's overall look, and any change to what the pages say.

## Capabilities

### New Capabilities

None. This change is presentational, so it adds no requirement, and the change is marked `skip_specs`.

### Modified Capabilities

None.

## Impact

- New components under `site/src/components/` and a shared stylesheet registered with Starlight; edits to five site pages and the tutorial index.
- `README.md`, `ballerina/Module.md`, `ballerina/modules/render/Module.md`, `CONTRIBUTING.md`.
- No package code, API or release is affected. The site's build and its link check are unchanged, and the new components add no scripts.
