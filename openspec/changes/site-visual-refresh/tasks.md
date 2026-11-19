# Tasks

## 1. Foundation and the flow diagram

- [x] 1.1 Add `site/src/styles/diagrams.css` (the shared surface, spacing and accent variables, on Starlight's tokens) and register it with `customCss`; verify the site builds and no existing page changes appearance
- [x] 1.2 Build the `Flow` component (an ordered list of pills with arrows and one optional branch, stacking on narrow screens, with a caption); verify it renders from props in a scratch page
- [x] 1.3 Replace the ASCII diagram on "The update and view loop" with `Flow`; verify in a browser in light and dark mode and at phone width, with keyboard focus visible, and that the built HTML contains no `<script>` from the component and the same text as the old diagram
- [x] 1.4 Redo `Flow` after comparing other documentation sites (Claude Code, Anthropic, Codex): a panel, colour by owner with a legend, a dashed group container, a feedback arc, and a branch; verify in light and dark mode and in a narrow container, that the built HTML has no script and the feedback sentence appears once, and that the checks pass
- [ ] 1.5 Review the look of this first page with you before the style is repeated (density, arrow style); apply the feedback to the foundation

## 2. The screen diagrams

- [x] 2.1 Build the `Screen` component (a terminal-styled stack of rows with a labelled gutter); verify it renders every row kind (`committed`, `gap`, `live`, `prompt`) in a scratch page
- [x] 2.2 Replace both diagrams on "Inline rendering" with `Screen`; verify in light and dark mode and at phone width, that each row's meaning is readable as text, and that the page's links still resolve

## 3. The backoff chart

- [ ] 3.1 Read the base sleep, the ceiling and the checks per step from `ballerina/engine.bal` and `ballerina/backoff.bal` at build time with strict patterns; verify the site build fails with a message naming the file and the constant when one is renamed in a scratch copy, and passes again when restored
- [ ] 3.2 Build `BackoffChart` (inline SVG with a title, a description, labelled axes, the ceiling line, and a sentence stating the same numbers); verify the plotted steps are 5 ms doubling after every 20 checks to 0.5 s, reached after about 12.7 s, matching the page's "about 13 seconds"
- [ ] 3.3 Replace the curve on "Idle cost" with it; verify in light and dark mode and at phone width, and that the SVG is readable by a screen reader through its title and description

## 4. The layers list and the stepper

- [ ] 4.1 Build `Layers` and use it for the four layers on "Testing it"; verify it renders as a numbered list and the page builds
- [ ] 4.2 Build `StepList` (an ordered list of single-link rows with number, title, what you build and "you learn" chips, a connecting line on wide screens, focus and hover styles that respect reduced motion) and a "Start with step 1" button; verify there are no nested links, the whole row is clickable and focusable in order, and the layout stacks at phone width
- [ ] 4.3 Replace the table on the tutorial index; verify the six links resolve (`npm run check-links`), the chips match the old "You learn" column, and the page looks right in light and dark mode

## 5. README and Module.md

- [ ] 5.1 Replace the README's loop diagram with a Mermaid block with the same labels as the site's `Flow`; verify it parses with Mermaid's parser and renders on GitHub when viewing the branch's README
- [ ] 5.2 Make the loop diagram in `ballerina/Module.md` and the anchoring diagram in `ballerina/modules/render/Module.md` tidy ASCII with identical wording to the site; verify searching the repository for "one frame per batch" finds the site, the README and `ballerina/Module.md`
- [ ] 5.3 Note in `CONTRIBUTING.md` where the loop diagram's wording lives; verify the note names each file

## 6. Whole-site review

- [ ] 6.1 Look at every page that changed in light and dark mode and at phone width, and run the link check and the site build in CI; list anything that still looks off and fix it

## Workflow follow-up

- Land one pull request for group 1 first, so the look is agreed before it is repeated; the others follow in order.
- Archive the change after the last pull request merges (it has no spec deltas to sync).
