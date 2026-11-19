# Design

## Context

See proposal.md for motivation. The site, `ExampleCode`, `CastPlayer`, `examples/check.sh` and step 1 (`examples/tutorial/step1-counter`) exist. `examples/agent-harness` is a 349-line finished harness (plus `llm.bal`, a scripted model) that already uses every feature the tutorial teaches, so the steps can be derived from it. `FakeTerminal` supports scripted keys, so steps can be tested without a pseudo-terminal. Tutorial programs pin the released termui 1.0.0 and may use only its API.

## Goals / Non-Goals

**Goals:**
- A reader can type along, one file per step, and end with a harness that resembles the real example.
- Every step's behaviour, not just its compilation, is checked in CI.
- Pages cannot drift from the code they show, including when a step's file changes.

**Non-Goals:**
- Teaching LLM integration, or shipping a bridge to one.
- Re-implementing everything `examples/agent-harness` does (colored code blocks, a welcome banner, token counts). The final page points there for the rest.

## Decisions

**Step plan.** Each step is a complete package that adds one idea to the previous one:

```
 1 counter ---> 2 prompt ---> 3 stream ---> 4 status + Esc ---> 5 approval ---> 6 tests
   Program       LineEditor     effect         every, quiet       confirm         FakeTerminal
   update/view   commitProse    session.send   ticks, cancel      headless        headless run
                                anchorBottom                      default-deny
```

**Scripted model in its own file.** From step 3 the programs share a `model.bal` (a fixed plan of thinking, text and tool steps, chunked into small pieces with short sleeps), copied unchanged into each later step. It is tiny and obviously fake, so the page can say "replace this effect with your model call". Alternative: import the harness's `llm.bal`; rejected because each step must be a standalone package a reader can copy.

**One package per step, copied forward.** `examples/tutorial/stepN-name/`, each with its own `Ballerina.toml` pinned to 1.0.0. A reader copies one folder; a page's file include is that folder's `main.bal`. The cost is duplicated code across steps, which is also the point: each page can show the diff in prose. Alternative: one package with `step2.bal`, `step3.bal` modules; rejected because it hides which file a reader runs.

**Region markers instead of line numbers.** `ExampleCode` gains a `region="name"` prop that shows the lines between `// region name` and `// endregion name` and removes the marker lines. A page that explains what a step added includes the region, so edits to a file cannot silently shift an excerpt, and a missing region fails the site build. Existing line-range pages (loop, commands, line editor, strands, testing, step 1) move to regions in the same change. Alternative: keep line numbers and a lint; rejected as more fragile.

**Behaviour checks are `bal test`s on a `FakeTerminal`.** Steps 2 to 5 each get a `tests/` folder with tests that push keys and assert on `screenLines()` (a submitted line is committed; a streamed answer ends up in order; Esc stops it; an approval answered `n` is denied). Delays in the scripted model are constructor arguments, so tests run it with zero sleeps and stay quick and deterministic. Step 6's page is about these tests and shows them. Alternative: `verify.py` pty scripts as for `examples/agent-harness`; kept for the finished harness, but too heavy for five small steps.

**Headless behaviour is shown in step 5.** The approval step runs with no terminal and shows that `confirm` returns the default (deny) instead of hanging, using the real behaviour documented for headless mode.

**Recordings.** A shared recorder, `examples/tutorial/record.py <step> <script>`, plays a scripted key sequence into a built step on a pseudo-terminal and writes a cast. Steps 3, 4 and 5 get casts, because they are the ones where motion matters. It needs `pyte` to answer cursor reports (step 3 uses `anchorBottom`), as `examples/agent-harness/record_demo.py` does, and is an author-time tool, not part of CI.

**Released API only.** The steps use no API after 1.0.0. If writing a step shows a missing ability, it becomes a separate change and a later release, not a workaround in the tutorial.

**Final page.** Links to `examples/agent-harness` for what the tutorial left out, to the concepts pages, and to the API reference.

## Risks / Trade-offs

- [Five copies of near-identical code drift apart] → Each step is built and tested in CI, each page includes regions, and `check.sh` runs all of them. The diffs between steps are small by construction.
- [Timing in tests makes CI flaky] → Zero-delay model in tests, assertions on order and content, no wall-clock assertions (the lesson from the idle-cost tests).
- [The scripted model looks like busywork] → Keep it under 60 lines, describe it in two sentences, and put the "plug in a real model here" note beside the effect.
- [Region markers add noise to the example sources] → Markers are single comment lines, stripped from the page, and invisible to the program.
- [A step needs API that does not exist] → Stop and open a separate change; do not work around it in tutorial code.

## Migration Plan

Land the steps in order, one pull request per step or per two steps, so the site never shows a "coming soon" link that points to a missing page. The index is updated in the last pull request. Rollback is reverting the pages; the examples are independent of the package.

## Open Questions

- Whether step 4's spinner should use the same braille frames as `examples/agent-harness`. This is cosmetic and can be settled when writing the step.
