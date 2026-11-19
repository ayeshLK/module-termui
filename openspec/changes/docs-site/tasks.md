# Tasks

## 1. Site skeleton

- [x] 1.1 Scaffold a Starlight project in `site/` with a lockfile and pinned versions; verify `npm ci && npm run build` succeeds and produces `site/dist/index.html`
- [x] 1.2 Configure `site` and `base` for `https://ayeshlk.github.io/module-termui/` and define the sidebar (Start here, Concepts, Best practices, Tutorial, Reference); verify the built home page and a built inner page load with working internal links under the base path (`npm run preview`)
- [x] 1.3 Add a home page (what termui is, install, link to Quickstart and Tutorial) and a "Start here" page; verify neither duplicates symbol docs and both link to the Ballerina Central reference for each module
- [x] 1.4 Add `site/README.md` with local-preview and authoring instructions, and add `site/node_modules` and `site/dist` to `.gitignore`; verify a fresh clone follows the README to a running preview

## 2. Concepts pages

- [x] 2.1 Write the update/view loop page (Model, Message, update, view, run) using the counter's real code; verify every snippet is quoted from a file that compiles
- [x] 2.2 Write the commands and timers page (effects as isolated functions, `every`, immutable messages); verify it states the isolated and `readonly` rules and each claim matches `ballerina/Module.md`
- [x] 2.3 Write the inline rendering page (live region vs scrollback, anchoring, resize); verify the page includes a cast of the harness demo and the text matches the `buffer-renderer` spec
- [x] 2.4 Write the headless and modes page (interactive, piped output, piped input, headless, plain-output rules); verify it matches `ballerina/Package.md`
- [x] 2.5 Write the line editor page (key bindings, history, multiline); verify the binding table matches `ballerina/modules/input/Module.md`
- [x] 2.6 Write the idle cost page (adaptive backoff, `maxPollInterval`, quiet ticks, the 0.5 s trade-off); verify the numbers match the measurements in `CHANGELOG.md` and `bench/README.md`

## 3. Best-practices pages

- [x] 3.1 Write the strands and isolation page, including the rule that a blocking call in a non-isolated function stalls other work and the isolated alternative; verify the example reproduces the stall and its fix when run
- [x] 3.2 Write the testing page (`FakeTerminal`, headless `Interface`, asserting on frames); verify its example test passes with `bal test`
- [x] 3.3 Write the compatibility page as a short guide that links to `COMPATIBILITY.md` for the policy; verify it restates no rule that is not in that file

## 4. Recordings and the loop component

- [x] 4.1 Add the asciinema-player assets under `site/public/` and a `CastPlayer` component with a text fallback; verify a page plays, pauses and seeks a cast, and that text is selectable
- [x] 4.2 Copy `docs/assets/harness-demo.cast` into the site and add a recording of the counter, recorded from the real programs; verify both play on the built site
- [x] 4.3 Build the `LoopPlayground` component (counter: buttons send messages, panels show state and frame), labelled as an illustration with a link to `examples/counter`; verify it updates state and frame on each message in a browser
- [x] 4.4 Add no-script fallbacks for both components; verify with scripts disabled that the page text and code are visible and the component notes that it needs scripts

## 5. Tutorial section and first step

- [x] 5.1 Create `examples/tutorial/step1-counter` as a standalone package pinned to the released termui, and add its compile check to a script used by CI; verify `bal build` succeeds locally
- [x] 5.2 Write `tutorial/01-counter` which includes the example source via `?raw` and explains it, with a link to the next step marked "coming soon"; verify the page text is the file content and changing the file changes the built page
- [x] 5.3 Add a tutorial index page listing the planned steps; verify the sidebar shows the Tutorial section with step 1

## 6. Delivery

- [x] 6.1 Add a pull-request workflow, path-filtered to `site/**`, `examples/**` and the workflow itself, that builds the site and compiles included examples; actions pinned by commit; verify a site-only change runs it and a package-only change does not
- [x] 6.2 Add a deploy workflow on pushes to `main` with the same path filter, using the official Pages actions with `pages: write` and `id-token: write` only on the deploy job; verify the workflow lints with `actionlint` and its permissions match
- [x] 6.3 Verify a deliberately broken tutorial example makes the pull-request check fail, then revert it
- [x] 6.4 Update `CONTRIBUTING.md` with how to preview and add a page, and with the rule that tutorial programs use only released API; verify the steps work on a clean checkout

## 7. Publish and link

- [x] 7.1 Maintainer: enable GitHub Pages with the GitHub Actions source in repository settings; verify the Pages settings page shows that source
- [x] 7.2 Merge to `main` and verify the deploy workflow succeeds and the site loads at its address, including an inner page and a cast
- [x] 7.3 Add the site link to `README.md` and `ballerina/Package.md` and add a CHANGELOG "Unreleased" note; verify the links resolve to the live site

## Workflow follow-up

- Archive the change after the site is live, then plan `harness-tutorial` (steps 2 onward) as a separate change.
