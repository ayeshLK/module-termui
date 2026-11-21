# Design

## Context

The behaviour a troubleshooting guide needs is already written down, but across pages: headless modes (`concepts/headless-modes`), inline rendering (`concepts/inline-rendering`), the line editor, commands and timers, the terminal module reference, and the compatibility page. The best-practices section holds three pages (`strands-and-isolation` order 1, `testing` 2, `compatibility` 3). `examples/best-practices` is a compiled package with tests that the testing page includes by region. The spec forbids consumer pages from describing polling or backoff mechanics, quoting latency or CPU figures, or devoting a section to idle cost. See proposal.md for why.

## Goals / Non-Goals

**Goals:**
- A reader can find their problem by the words they would use for it, and leave with a cause and a next step.
- Every claim is traceable to a test, a reference page or a reproduction.

**Non-Goals:**
- A second copy of the concept pages. Entries are short and link out.
- Coverage of every possible failure. The guide is short, and an entry is added when it can be backed.

## Decisions

**The page is `best-practices/troubleshooting`, order 4.** It is about operating a program, like the compatibility page beside it, and the sidebar picks it up from the folder. Alternative: a top-level "Troubleshooting" item before Reference (rejected for now: a fifth section for one page).

**Entries are headed by the symptom, and the page's own table of contents is the index.** A heading is how the reader would say it ("Ctrl+C does not stop my program"), never an API name. That also makes the site's search find it. Under each heading: what you see, why it happens (one or two sentences), what to do, whether it is expected behaviour or worth reporting, and a "Read more" link. Five groups keep the page scannable: in CI, pipes and scripts; what you see on screen; keys and input; effects and timers; terminal state. A last "Still stuck?" section says what to include in a bug report and shows a diagnostic.

**The entries, and what backs each.** All the tests named below were confirmed to exist. Entries 11 and the graceful-signal part of 15 rest on the reference documentation alone.

| # | Symptom | Backed by |
|---|---|---|
| 1 | My program hangs in CI or with `< /dev/null` | headless page; reproduction (see below); the `InputEnded` handling in `headless_test.bal` |
| 2 | A question returns at once, or I get a `NoTerminal` error | tests `testQuestionsWithoutATerminalReturnImmediately`, `testTheErrorNamesTheQuestion`, `testAProgramAskingWithoutATerminalGetsTheErrorAsAnAnswer` |
| 3 | No colors or styling in CI logs or a pipe | tests `testNoColorStillAppliesOnTheTerminal`, `testHeadlessOutputIsPlainAndRepeatable` |
| 4 | In CI I only see the final state, or output differs between runs | tests `testFullyHeadlessUsesPlainOutput`, `testHeadlessOutputIsPlainAndRepeatable` |
| 5 | My output file has only results, not the interface | tests `testRedirectedOutputKeepsTheInterfaceOnTheTerminal`, `testOnlyResultsGoToRedirectedOutput` |
| 6 | A long line is cut off at the right edge | inline-rendering page; test `testALongLineIsCutAtTheRightEdge` (`render/tests/render_test.bal`) |
| 7 | The prompt sits at the top, or `anchorBottom` does nothing | tests `testTheDefaultStartsTheRegionOnTheCursorRow`, `testTheOptionPutsTheFirstFrameOnTheLastRows`, `testTheOptionIsIgnoredWhenTheRunIsNotInteractive`; compatibility page |
| 8 | After I resize the window the old output looks wrong | inline-rendering page; reflow tests in `render/tests/anchor_test.bal` |
| 9 | My debug prints garble the display | reproduction (a print inside `update` overwrote the live region); inline-rendering's note that other writers are not accounted for |
| 10 | Ctrl+C does not stop my program | reproduction (the counter kept running after Ctrl+C and ended on `q`); terminal reference (Ctrl+C is a key event) |
| 11 | Alt shortcuts do not work, or Shift+Enter submits | line editor page (terminal settings it documents; not testable) |
| 12 | A compile error when I pass a function to `effect` or send a message | reproduction (see below); strands-and-isolation page |
| 13 | My timer or spinner shows nothing, or stops | commands-and-timers page; tests `testATickThatChangesNothingDrawsNothing` and `testATickThatChangesTheViewIsDrawn`; `Interface.interactive` is public and false in the two modes without a terminal on stdin |
| 14 | An effect's messages stop arriving, or I see `EffectFailed` | commands-and-timers page; tests `testNoMessageIsDeliveredAfterTheProgramHasStopped` and `testAFailingEffectReportsAMessage` |
| 15 | My terminal shows no echo after the program was killed | tests `testSttySaneRecoversATerminalLeftRaw`, `testTheTerminalIsRestoredWhenTheWorkFails`, `testQuittingRestoresTheTerminalAndEndsTheRun`; the terminal reference for graceful signals and `kill -9` (documented, not tested) |

**Entry 12 quotes what the compiler really says**, from a reproduction: a function that is not `isolated` gives `incompatible types: expected '...:EffectFunction', found 'function (...:Session) returns (error?)'`, which never mentions "isolated", and a mutable message gives `incompatible types: expected '...:Message', found 'map<string>'`. The entry explains both and omits the package version that appears in the raw text, so it does not go stale.

**Entry 9 says "write to the screen with commit commands instead".** `commitProse` and `commitBlock` put output above the live region, `ui.result` is for what a caller or pipe waits for, and a log file is for diagnostics. It must say that raw prints are not tracked, so it does not contradict the commands page's "output stays in sequence", which is about results and commits.

**A diagnostic, compiled and tested.** A small function in `examples/best-practices` takes a `term:Environment` and returns one line saying which mode `selectMode` picks, which of stdin, stdout and stderr are terminals, whether color is on and the size. It is included by region, and a test builds a CI-like and an interactive environment with `term:environmentFrom`. This keeps "never a copy" and gives the reader something concrete to attach to a bug report.

**Left out on purpose.** The first key after a pause feeling slow (the spec forbids describing idle cost), build and JDK problems (not terminal or execution-mode issues), and direct `UnixTerminal` or `/dev/tty` failures (advanced). The compatibility page already covers platforms; the guide links to it for Windows instead of restating it.

**Links in, kept to two.** The Quick start's "Run it" gets one line saying `q` quits and Ctrl+C does not, with a link to entry 10, because the counter really behaves that way. The headless-modes page gets a "see also" for CI problems. `CONTRIBUTING.md` gains a line saying entries are tied to tests and reference pages, so a behaviour change should check the guide.

## Risks / Trade-offs

- [The guide repeats facts that live elsewhere and may drift] -> Entries are short, state the rule and link out, and each is tied to a test or page named in this design; `CONTRIBUTING.md` says to check the guide when behaviour changes.
- [A doc-only entry turns out to be wrong or untestable] -> Confirmed during the work; an entry that cannot be confirmed is dropped or reworded, not published.
- [A reproduction depends on a terminal emulator] -> The reproductions use a pseudo-terminal and a terminal emulator library once, locally, and are recorded here; they are not added to CI.

## Evidence

From reproductions run for this change, in scratch packages, not committed. They ran against termui 1.0.0, the release the examples use:

- **Ctrl+C:** the counter from the Quick start, run on a pseudo-terminal, was still running two seconds after Ctrl+C and exited on `q`.
- **Debug print:** an `io:println` inside the counter's `update`, run the same way, left the screen as `count: 0`, `debug: count is now 2quits`, `2`: the print landed in the live region and the hint line and the count were overwritten.
- **Effect errors:** the two messages quoted for entry 12, produced by compiling a program with both mistakes.
- **Hang in CI:** the Quick start's counter, which does not handle `termui:InputEnded`, was still running after 25 seconds with standard input from `/dev/null`. Step 1 of the to-do tutorial, which does, exited with code 0 after 0.3 seconds and wrote its list as plain text (`> buy milk`, `  write the docs`, `  call mum`, then the hint line), which also shows entry 4's final-state-only output.

## Migration Plan

Confirm each "to confirm" entry first and record the result here. Then add the diagnostic and its test, write the page, add the links, and run the site build, tests, link check and `examples/check.sh`. Check the finished page for words that belong to internals (polling, latency, CPU, backoff).
