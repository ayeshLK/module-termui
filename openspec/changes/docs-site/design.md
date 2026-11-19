# Design

## Context

See proposal.md for motivation. The repository is a Ballerina package built with Gradle; CI runs on Linux and macOS and pins third-party actions by commit. `examples/counter` and `examples/agent-harness` are standalone Ballerina packages pinned to a released termui version, with `verify.py` pty checks. `docs/` holds the announcement drafts and the demo recording (`docs/assets/harness-demo.cast`). GitHub Pages is not enabled yet. The site must not slow the Ballerina build or require Node for contributors who never touch docs.

## Goals / Non-Goals

**Goals:**
- A site authored in Markdown and MDX, with no hand-written page HTML.
- Code in pages cannot drift from code that compiles.
- Docs-only changes publish without a package release.
- Node stays confined to `site/` and to its own workflows.

**Non-Goals:**
- Versioned docs, translations, a generated API reference, a custom domain.
- The full harness tutorial (a follow-up change). This change ships the section and step 1.
- Running real Ballerina in the browser.

## Decisions

**Starlight (Astro) in `site/`.** It gives sidebar, search, dark mode and code highlighting from Markdown, and MDX allows one component per interactive piece. Alternatives: Zensical (markdown only, young, fewer ways to embed a custom widget); mdBook (simple, but custom widgets mean hand-written JS); Material for MkDocs (maintenance ended on November 5, 2026). `site/` rather than `docs/` keeps the announcement drafts and assets separate from the site.

**Layout.**
```
site/
  astro.config.mjs      sidebar: Start here, Concepts, Best practices, Tutorial, Reference
  src/content/docs/
    index.mdx
    concepts/*.md(x)
    best-practices/*.md
    tutorial/01-counter.mdx ...
  src/components/       LoopPlayground.*, CastPlayer.*
  public/casts/         .cast files
examples/tutorial/stepN/   compiled in CI, included into pages
```

**Code comes from files, never copies.** Tutorial pages include the example source with an `ExampleCode` component that reads the file at build time, drops its licence header, and can show a line range, so the page text is the file. Snippets inside prose may be inline; any full program is included. (Astro's `?raw` import would work too; reading the file lets one component strip the header and cut excerpts.) Alternative: a copy with a check script; rejected because it adds a thing that can fail silently. Line ranges move when a file changes, so a range is checked by reading the built page; named markers are the next step if that becomes a burden.

**Examples compile against a released termui.** Tutorial programs pin the released version like the existing examples, so a page always matches what a reader can install. A new API used by a step therefore waits for its release, which is the same rule the project already follows for examples.

**Recordings.** Casts are recorded with asciinema from the real programs (the existing `record_demo.py` shows how) and played with asciinema-player, loaded from the site's own `public/` files so the site has no runtime third-party host. The player supports pause, seek and text selection. Alternative: GIF; rejected because it cannot be paused or copied.

**One interactive component.** A small component models the update and view loop for a counter: buttons send messages, panels show state and frame. It is an illustration written in JS, labelled as such, and links to the runnable counter example. It is deliberately not a Ballerina runtime. Everything else uses casts, so the amount of JS to keep honest stays small.

**No-JS reading.** Components render a text fallback; code and prose are plain Markdown output.

**Delivery.** Two workflows with path filters on `site/**` and `examples/**`:
- a pull-request build runs `npm ci` and `astro build`, then compiles the included examples (installing Ballerina as the other workflows do);
- a deploy workflow on pushes to `main` builds and publishes with the official Pages actions (`upload-pages-artifact`, `deploy-pages`), pinned by commit, with `pages: write` and `id-token: write` granted only to the deploy job.
Both are separate from `build.yml`, so a package-only pull request does not pay for Node.

**Base path.** Pages serves the project at `https://ayeshlk.github.io/module-termui/`, so Starlight is configured with `site` and `base` to match. If a custom domain is added later only these two values change.

**Package overview and README link to the site; the site links to Ballerina Central for symbols.** This avoids two sources for symbol docs.

## Risks / Trade-offs

- [The JS component drifts from real behavior] → Keep it to the loop's shape (message, update, view), label it an illustration, and link to the real example; do not model timers or rendering details.
- [Node toolchain adds maintenance and supply-chain surface] → Pin versions with a lockfile, pin actions by commit, run Dependabot-style updates by hand at release time, keep Node out of package builds.
- [A tutorial step waits for a release when it needs new API] → Same rule as the existing examples; steps use only the released API.
- [Pages setting is a repository action, not code] → Listed as a maintainer task; the deploy workflow fails visibly until it is done.
- [Docs rot as the API grows] → The compile check catches code; the compatibility policy bounds API change within a major version.

## Migration Plan

1. Merge the site and workflows; PR builds start running on `site/` and `examples/` changes.
2. A maintainer enables Pages with the GitHub Actions source.
3. The first deploy runs from `main`; add the README link once the URL resolves.
Rollback: disable Pages or revert the workflow; nothing in the package depends on the site.

## Open Questions

- Whether to add a "last verified against termui X.Y.Z" note to tutorial pages. It can be added later without changing the specs.
