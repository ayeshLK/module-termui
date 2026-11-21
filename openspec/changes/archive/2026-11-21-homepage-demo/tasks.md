# Tasks

## 1. The player

- [x] 1.1 Add an optional `poster` prop to `site/src/components/CastPlayer.astro`, defaulting to the current `npt:0:1`, and pass it to the player
- [x] 1.2 Add an optional description to `CastPlayer`, shown inside `<noscript>` after the notice and the download link, as a named `fallback` slot; with none given, the output is exactly as before
- [x] 1.3 Replay `harness-demo.cast` through `pyte` to find the time at which the streamed answer and an approval prompt are on screen, and to capture the text of that frame
- [x] 1.4 Add opt-in `autoplay` and `loop` props to `CastPlayer` (both off by default), starting playback only when the reader has not asked for reduced motion
- [x] 1.5 Render the caption as HTML so a caption can link to a page

## 2. The homepage

- [x] 2.1 Reword the `index.mdx` description and hero tagline, the `astro.config.mjs` description and the README tagline to describe a general-purpose terminal UI library, keeping the three concrete features
- [x] 2.2 Add `HomeDemo.astro`: the player with `harness-demo.cast`, the poster from 1.3, autoplay and loop, and a caption that names it as an agent harness built with termui and links to `examples/agent-harness`
- [x] 2.3 Write the text description for the recording in `HomeDemo.astro`: an ordered walk-through of what happens, plus the captured frame as preformatted text
- [x] 2.4 Keep the four cards and add no further headings or paragraphs to the page; the introduction is the one-sentence tagline
- [x] 2.5 Add `Hero.astro`, a two-column copy of Starlight's hero with the recording on the right, and register it as the `Hero` component in `astro.config.mjs`

## 3. Check

- [x] 3.1 Build the site and check the homepage in a browser with scripts on (the recording is beside the introduction, starts by itself, loops, and can be paused and scrubbed; the poster shows the streamed answer and an approval prompt) and with scripts off (the description and frame are visible)
- [x] 3.2 Check the homepage with reduced motion on (no autoplay, the poster frame shows), at phone width, and in both colour themes
- [x] 3.3 Run `npm test`, the site build and the link check, and confirm the pages that use `CastPlayer` without the new props render as before
- [x] 3.4 Add a sentence to `CONTRIBUTING.md`'s recordings line saying the homepage description and poster time need updating when `harness-demo.cast` is replaced

## Workflow follow-up

- Archive the change after review, syncing the `docs-site` requirements.
