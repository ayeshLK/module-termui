## Why

The documentation site and README are read by developers who consume termui. Parts of them describe how the runtime works inside (the polling backoff, first-key latency figures, CPU percentages, benchmark scripts, cursor-query mechanics). That content does not change what a consumer writes, and figures such as "about half a second to the first key" read as defects. Runtime behavior is already specified in `mvu-runtime` and `terminal-backend`, which is where framework developers should find it.

## What Changes

- Delete the `Idle cost` concept page and its `BackoffChart` component.
- Remove idle, backoff, benchmark and timing-number mentions from the other site pages (`commands-and-timers`, `tutorial/04-status`, `tutorial/index`, `tutorial/06-testing`, `compatibility`, `headless-modes`, `inline-rendering`), keeping the practical guidance (an unchanged view costs no redraw; keep `view` cheap).
- Remove the idle and first-key bullets from the README's "Status and limits", keeping startup as one line.
- Drop "idle cost" from the list of concepts the `docs-site` spec requires the site to explain, and state that consumer docs do not describe runtime internals.
- Out of scope: `CHANGELOG.md`, the runtime specs, `bench/` and `CONTRIBUTING.md`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `docs-site`: the concepts requirement no longer includes idle cost, and a new requirement keeps runtime internals out of consumer-facing docs.

## Impact

- `site/src/content/docs/**`, `site/src/components/diagrams/BackoffChart.astro`, `README.md`.
- `site/scripts/check-links.mjs` must pass with the page gone.
- No code, API or behavior change.
