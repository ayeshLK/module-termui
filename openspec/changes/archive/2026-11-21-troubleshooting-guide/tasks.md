# Tasks

## 1. Evidence

- [x] 1.1 For each entry in the design's table, find the test (name and file) or reference page that supports it; for the entries marked "to confirm" (1, 6, 13), confirm against the implementation or tests, and drop or reword any entry that cannot be confirmed
- [x] 1.2 Reproduce entry 1 (a program that does not handle `termui:InputEnded` waits forever with `< /dev/null`, and one that does exits) in a scratch package, and record the result in the design's evidence section
- [x] 1.3 Re-run the Ctrl+C, debug-print and effect-error reproductions against the released library the examples use, and update the quoted text if it differs

## 2. The diagnostic

- [x] 2.1 Add a function to `examples/best-practices` that describes a `term:Environment` in one line (the mode `selectMode` picks, which of stdin, stdout and stderr are terminals, whether color is on, the size), in a region named `diagnose`
- [x] 2.2 Add tests that build a CI-like and an interactive environment with `term:environmentFrom` and check the line

## 3. The page

- [x] 3.1 Write `site/src/content/docs/best-practices/troubleshooting.mdx` with `sidebar.order: 4`: a short intro, the five groups, and "Still stuck?" with the diagnostic included by region
- [x] 3.2 Give every entry a symptom heading, what you see, why, what to do, an expected-or-report note, and a "Read more" link; keep shell snippets inline and programs in compiled files
- [x] 3.3 Phrase entry 9 so it does not contradict the commands page, and quote entry 12's messages without the package version

## 4. Links

- [x] 4.1 `start/quick-start.mdx`: in "Run it", say that `q` quits and Ctrl+C does not, with a link to the guide's entry
- [x] 4.2 `concepts/headless-modes.mdx`: add a see-also link to the guide
- [x] 4.3 `CONTRIBUTING.md`: say the guide's entries are tied to tests and reference pages and should be checked when behaviour changes

## 5. Check

- [x] 5.1 Build the site, then run `npm test`, `npm run check-links` and `examples/check.sh`
- [x] 5.2 Search the page for internals (polling, backoff, latency, CPU, milliseconds) and for unsupported platform claims, and read each entry against the pages it links to for contradictions
- [x] 5.3 Look at the page in a browser: the headings in "On this page", search finding an entry, both colour themes, phone width and scripts off

## Workflow follow-up

- Archive the change after review, syncing the `docs-site` requirements.
