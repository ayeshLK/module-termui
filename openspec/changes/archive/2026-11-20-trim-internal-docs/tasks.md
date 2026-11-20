## 1. Remove the idle-cost page

- [x] 1.1 Delete `site/src/content/docs/concepts/idle-cost.mdx` and `site/src/components/diagrams/BackoffChart.astro`
- [x] 1.2 Remove links to `idle-cost` from `concepts/commands-and-timers.mdx` and `tutorial/04-status.mdx`

## 2. Trim internals from other site pages

- [x] 2.1 `commands-and-timers.mdx`: drop the backoff and wake-up sentence, keep what `every` does
- [x] 2.2 `tutorial/04-status.mdx`: drop CPU percentages, `bench/idle_cpu.py` and backoff text; keep "an unchanged view costs no redraw" and "keep `view` cheap"
- [x] 2.3 `tutorial/index.mdx`: remove the "idle cost" chip
- [x] 2.4 `tutorial/06-testing.mdx`: reword the idle mentions (lines near 42 and 140) without the term
- [x] 2.5 `best-practices/compatibility.md`: keep "defaults are frozen" without naming `pollInterval` and `maxPollInterval` values
- [x] 2.6 `concepts/headless-modes.mdx`: remove the "about 25 ms" figure
- [x] 2.7 `concepts/inline-rendering.mdx`: remove the paragraph describing the anchoring algorithm; keep the option, diagram and limits

## 3. README

- [x] 3.1 In "Status and limits", remove the idle and first-key bullets; keep startup as one line

## 4. Verify

- [x] 4.1 Run `site/scripts/check-links.mjs` and the site build; no dead links
- [x] 4.2 Grep the site and README for `idle`, `backoff`, `bench/`, `pollInterval` and confirm no consumer-facing leftovers
- [x] 4.3 Run `openspec validate trim-internal-docs`
