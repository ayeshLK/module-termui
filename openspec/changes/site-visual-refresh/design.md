# Design

## Context

See proposal.md for the motivation. The site is Starlight on Astro, with `ExampleCode`, `CastPlayer` and `LoopPlayground` as custom components, and the home page uses Starlight's `CardGrid`. The `docs-site` spec already requires that every page's text and code are readable with scripts disabled. The five diagrams are fenced text blocks today; the loop playground is the only styled, hand-built visual and keeps its own CSS. `ballerina/Module.md` and `ballerina/modules/render/Module.md` are shown on Ballerina Central, which cannot be relied on to render SVG or Mermaid; the README is shown only on GitHub, which renders Mermaid.

## Goals / Non-Goals

**Goals:**
- Diagrams and the step list that look deliberate in light and dark mode, on desktop and on a phone.
- No JavaScript, readable text, accessible: a reader using a screen reader, a keyboard or forced colours loses nothing.
- Declarative authoring: a page lists the content as props; the styling lives in one place.
- The chart cannot drift from the code it describes.

**Non-Goals:**
- A general diagramming system. Five specific diagrams do not need one.
- Moving the loop playground onto the new styles (a later consistency pass, if wanted).
- Changing any wording of the pages beyond the diagrams.

## Decisions

**Purpose-built components, not Mermaid or D2.** The five diagrams are different shapes (a flow, stacked screens, a chart, a list), and a general tool gives all of them one generic look. Mermaid on the site would also add client-side JavaScript or a headless browser to the build, and leave raw source for readers without scripts. Components are plain HTML and CSS (and inline SVG for the chart), rendered at build time.

**Style reference, decided after looking at other sites.** Claude Code's docs draw their loop as a panel with a dashed container around the repeating part, colour by role, and a curved return arrow; Anthropic's essays use small typed nodes with edge labels and dashed secondary paths; the Codex docs use prose, callouts and tables with no flow diagram on the pages looked at. For termui the Claude Code treatment fits better: colour by owner carries real information (your `update` and `view` against the runtime's own steps), the dashed container is the loop's whole point, and the panel surface matches the terminal-styled `Screen` diagrams that follow. From Anthropic's style it borrows the edge label (on the return arc) and the dashed outside node. Edge labels on the short horizontal arrows were left out: at the content width there is no room for them.

**Foundation: one stylesheet with Starlight's tokens.** `site/src/styles/diagrams.css`, registered in `customCss`, defines a few classes and variables on top of Starlight's colour tokens (`--sl-color-accent`, the grey scale, `--sl-color-bg`), so dark mode, contrast and the accent follow the theme. No colours are hard-coded except the terminal-style surface in `Screen`, which is dark in both themes on purpose, because it depicts a terminal. Components import nothing at runtime.

**Components under `site/src/components/diagrams/`.**
- `StepList` takes `steps` (title, href, build, learn[]) and renders an `<ol>` whose items are single links (a block-level anchor, no nested links), so the whole row is the click target. A connecting line joins the numbers on wide screens. It has visible `:focus-visible` styles and a hover lift that respects `prefers-reduced-motion`. A `LinkButton` above it starts step 1.
- `Flow` takes steps and renders them on a panel as a real nested list joined by drawn arrows, coloured by **who owns each step**: outside the program (dashed grey), the runtime (accent) or your program (green), with a legend. Optional extras explain a loop: a `group` (a dashed container with a label, "this part repeats"), a `feedback` arc above the row that returns from a later step to an earlier one with a label, and a `branch` that hangs under one step. Below a width breakpoint it stacks top to bottom, the container and arc are dropped, and the arc becomes a sentence under the list. The arc, the container and the arrows are drawn and `aria-hidden`; their meaning is in the words (a visually hidden sentence, "then", "on a branch from here"), so nothing is lost to a screen reader.
- `Screen` takes rows of a kind (`committed`, `gap`, `live`, `prompt`), each with text, and renders a mock terminal with a labelled gutter (what the row is). Used for both inline-rendering diagrams.
- `BackoffChart` computes the step function at build time and draws it as inline SVG with a title, a description, labelled axes and the ceiling line. The numbers come from the source: the base sleep and the ceiling from the defaults of `pollInterval` and `maxPollInterval` in `ballerina/engine.bal`, and the checks per step from `EMPTY_CHECKS_PER_STEP` in `ballerina/backoff.bal`. Each is read with a strict pattern, and the site build fails with a clear message if one is not found, as `ExampleCode` does for a missing region. Alternative: constants copied into the component; rejected because that is the drift the page already has to guard against.
- `Layers` takes a list of (what you test, how) and renders a numbered list with the "how" as a tag.

**Every diagram is a `<figure>` with a `<figcaption>` and structure a screen reader can follow.** Lists are real lists, text is real text, and nothing depends on colour alone. The chart's `<svg>` has a `<title>` and `<desc>`, and a visually quiet text sentence beside it states the same numbers.

**README: Mermaid. `Module.md` files: ASCII, one wording.** GitHub renders a `mermaid` fence in the README. The two `Module.md` files keep an ASCII diagram with identical labels, and CONTRIBUTING says that the diagram's wording lives in the site component, the README and those files. Alternative: an SVG file in the repository for all three; rejected for Central, which cannot be relied on to show it.

**Verification is part of the work, not an afterthought.** Each component is checked in light and dark mode, at desktop and phone width, with keyboard focus visible, in forced-colours mode, and in the built HTML with scripts absent (the components emit none). The existing link check and the site build keep running in CI.

## Risks / Trade-offs

- [Custom CSS to maintain, and a Starlight upgrade could rename a token] → Use only documented tokens, keep the CSS in one file, and look at the five pages after a Starlight upgrade.
- [Reading constants from source with a pattern is coupling] → Fail loudly with the file and the name, so a refactor of those constants shows up in the build, not in a wrong chart.
- [The loop diagram's wording now exists in three forms] → One wording, a CONTRIBUTING note, and a search for the phrase "one frame per batch" finds all of them.
- [Pixel-level polish takes iteration] → Land one component and one page first, review it in a browser, then the rest, so the style is agreed before it is repeated.
- [A hover lift or an arrow reads as noise to someone sensitive to motion] → Transitions only under `prefers-reduced-motion: no-preference`.

## Migration Plan

1. Foundation and the `Flow` component on the loop page, as one pull request, so the look can be reviewed before it spreads.
2. The remaining components and pages (`Screen`, `BackoffChart`, `Layers`, `StepList`), one or two per pull request.
3. README and `Module.md` last, with the CONTRIBUTING note.
Rollback is reverting a pull request; no page content depends on a component beyond its own diagram.

## Open Questions

- The accent stays Starlight's default blue (the runtime colour). Changing it later is one variable.

## Follow-up (not part of this change)

An interactive version of the loop diagram, in the spirit of Claude Code's "Explore the context window": click a step to open an inspector with a short explanation and the code that implements it, and a "step through" control that lights the path a message takes. It would fold the existing loop playground into the diagram, so there is one interactive diagram and not two. It breaks this change's "no JavaScript" rule, so it is its own change, with the written list as the no-script fallback. To be scaffolded once this change lands.
