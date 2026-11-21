# Proposal

## Why

Terminal input, pipes, colors, resize and effects can fail in ways that are hard to diagnose from the concept pages: a reader must already know which page explains their problem. The Quick start's own program shows it, since Ctrl+C does not stop it and only `q` does. There is no troubleshooting page in the site, so someone who sees "my program hangs in CI" or "my debug prints garble the screen" has to search several pages. See issue #39.

## What Changes

- A new page, `best-practices/troubleshooting`, organized by symptom. Each entry's heading is what the reader sees, followed by why it happens, what to do, whether it is expected behaviour or something to report, and a link to the page that explains it.
- About fifteen entries in five groups: in CI, pipes and scripts; what you see on screen; keys and input; effects and timers; terminal state. Each is backed by a test, by the reference documentation, or by a reproduction run for this change. Entries the evidence does not support are not included.
- A short "Still stuck?" section that says what to include in a bug report, with a small diagnostic that prints the mode the program runs in and whether color is on. The diagnostic is a compiled function in `examples/best-practices` with a test, included by region.
- One-line pointers to the guide from the Quick start (where Ctrl+C does not quit the counter) and from the headless-modes page.

Out of scope: build, install and JDK problems; direct `UnixTerminal` and `/dev/tty` failures; anything about idle cost or key latency, which consumer documentation must not describe; changes to library behaviour.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `docs-site`: two added requirements, one for a troubleshooting guide organized by symptom and reachable from the sidebar, and one for what it covers and what backs its claims.

## Impact

- `site/src/content/docs/best-practices/troubleshooting.mdx` (new); small edits to `start/quick-start.mdx` and `concepts/headless-modes.mdx`.
- `examples/best-practices/` gains a diagnostic function and a test; `examples/check.sh` already builds and tests that package.
- `CONTRIBUTING.md` gains a line saying the guide's entries are tied to tests and reference pages.
- No package code, API, CI workflow or release is affected.
