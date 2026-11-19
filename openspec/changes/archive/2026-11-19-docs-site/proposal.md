# Proposal

## Why

termui 1.0.0 is stable, but its documentation is a README, a package guide and `Module.md` files. They list what exists. They do not teach how the pieces work together (the update/view loop, commands, the strand rules, idle cost), what to do and avoid, or how to build something real. The strand-group rule is the clearest example: a program that blocks one non-isolated function stalls everything, and nothing in the current docs says so up front. A documentation site with concept pages, best practices and a step-by-step tutorial lowers the cost of adopting the library, and gives the community a place to start.

## What Changes

- Add a documentation site under `site/`, built with Starlight (Astro) from Markdown and MDX, and published to GitHub Pages.
- Add concept pages (the update/view loop, commands and timers, inline rendering, headless mode, the line editor, idle cost) and best-practice pages (strands and isolation, testing, compatibility).
- Reserve a `tutorial/` section in the site's sidebar for a step-by-step guide to building a small agent harness. The tutorial pages and programs arrive in a follow-up change; this change ships the section with the first step, the counter, as the pattern to follow.
- Embed recordings of the real library (asciinema casts) in pages, and add one small interactive component for the update/view loop.
- Show code in pages by including real files from `examples/`, and build those programs in CI, so a page cannot drift from code that compiles.
- Build the site on pull requests that touch `site/` or `examples/`, and deploy it to GitHub Pages from `main`.
- Link the site from the README, and link the API reference on Ballerina Central rather than duplicating it.

Out of scope: versioned docs (one version until 2.0), a generated API reference, search beyond what Starlight provides, translations, and the full harness tutorial.

## Capabilities

### New Capabilities
- `docs-site`: what the documentation site contains and guarantees: its sections, how code shown in pages is kept in step with compiling programs, how recordings and interactive components are embedded, and how the site is linked from the project.

### Modified Capabilities
- `project-delivery`: adds how the site is built on pull requests and published from `main`, without slowing the package build.

## Impact

- New directory `site/` (Node toolchain, isolated from the Ballerina and Gradle build).
- New workflow(s) under `.github/workflows/` for the site build and Pages deploy; actions pinned per the existing policy.
- Repository setting: GitHub Pages enabled with the GitHub Actions source (a maintainer action).
- `examples/` gains a compile check for any code the site includes.
- README gains a link to the site. No package code or public API changes, and no release is needed.
