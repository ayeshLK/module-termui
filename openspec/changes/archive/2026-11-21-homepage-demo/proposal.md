# Proposal

## Why

The documentation homepage is a text hero and four capability cards. A first-time visitor cannot see what a running `termui` program looks like (the live region, committed scrollback, streamed output, an approval prompt) without leaving the page, and the page describes the library as for "agent-style" apps, which suggests it is specialised for agent frameworks. The homepage is the main evaluation path for new users, so it should show a real interaction and state the library's actual scope. See issue #36.

## What Changes

- Keep the homepage's wording light: the four cards stay, and the introduction is one short sentence. The recording of `examples/agent-harness` plays beside it in the hero, on its own and in a loop, with a one-line caption that links to the example's source. No new headings or paragraphs are added.
- Give `CastPlayer` optional `autoplay` and `loop` props (off by default; autoplay is skipped for readers who prefer reduced motion), an optional `poster` time, and a text fallback for when scripts are unavailable: a description of the recording that replaces the bare download link.
- Replace Starlight's hero with a two-column one (text on the left, recording on the right, stacked on narrow screens) so the recording is on the first screen.
- Describe `termui` as a general-purpose terminal UI library in one short sentence, used for the hero tagline, the site description and the README tagline. The agent harness is shown as one example.

Out of scope: a new recording or example program; a section explaining scrollback or non-interactive behaviour (the existing cards already say it); changes to the library; changes to other pages' recordings, apart from the `CastPlayer` options being available to them.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `docs-site`: adds a requirement that the homepage plays a recording of a runnable example, links its source and states the library's general scope, and extends "The site works without scripts for reading" so that a recording's content is available as text when scripts are off.

## Impact

- `site/src/content/docs/index.mdx` (tagline and description; the cards are unchanged).
- `site/src/components/CastPlayer.astro` (optional `poster`, `autoplay`, `loop`, a `fallback` slot, and a caption that may contain a link; existing uses are unchanged).
- `site/src/components/Hero.astro` (new) and `site/src/components/HomeDemo.astro` (new), registered as the `Hero` override in `site/astro.config.mjs`: the two-column hero and the recording with its text fallback.
- `site/astro.config.mjs` and `README.md` (description and tagline wording).
- `CONTRIBUTING.md` (a sentence on updating the homepage when the recording is replaced).
- No package code, example program, CI script or release is affected.
