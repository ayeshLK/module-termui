# Tasks

## 1. Region markers

- [x] 1.1 Add a `region` prop to `ExampleCode` (shows the lines between `// region <name>` and `// endregion <name>`, without the marker lines) that fails the site build with a clear message when the region is missing or unterminated; verify by building with a bad region name and seeing the failure, and with a good one and seeing the marker lines absent from the page
- [x] 1.2 Add region markers to `examples/counter/main.bal`, `examples/tutorial/step1-counter/main.bal`, `examples/agent-harness/main.bal` (the parts the pages quote) and `examples/best-practices/` and move every line-range `ExampleCode` in the site to `region`; verify `grep -rn "start={" site/src` finds nothing, the site builds, and the built pages' code blocks are unchanged from before the move (compare the extracted code text)
- [x] 1.3 Document `region` in `site/README.md` and `CONTRIBUTING.md`, replacing the line-range guidance; verify the documented example builds as written

## 2. Step 2: a prompt

- [ ] 2.1 Create `examples/tutorial/step2-prompt` (extends step 1: a `LineEditor`, history, `commitProse` of the submitted line, Ctrl+C quits) pinned to termui 1.0.0; verify `bal build` succeeds
- [ ] 2.2 Add tests with a `FakeTerminal` (a typed line is shown in the region; Enter commits it above and clears the editor; Up recalls it; Ctrl+C quits) and add the package to `examples/check.sh`; verify `bal test` passes and `examples/check.sh` runs it
- [ ] 2.3 Write `tutorial/02-prompt` with a "What changed" section, regions from the program, and a "Try this" list whose suggestions were each run; verify the page builds and every "Try this" step works on the program
- [ ] 2.4 Link step 1's "Next" and the tutorial index to step 2; verify the links resolve in the built site

## 3. Step 3: streaming output

- [ ] 3.1 Create `examples/tutorial/step3-streaming` with `model.bal` (a scripted model of at most 60 lines whose delays are constructor arguments) and a program that runs it as an effect, commits finished lines and shows the partial line live, and anchors to the bottom; verify `bal build` succeeds
- [ ] 3.2 Add tests (zero-delay model: the answer is committed in order, the partial line is live while streaming, a second question after the first answer works) and wire into `examples/check.sh`; verify `bal test` passes several times in a row
- [ ] 3.3 Add the shared recorder `examples/tutorial/record.py` (scripted keys into a built step on a pseudo-terminal, answers cursor reports) and record `step3-streaming.cast` into `site/public/casts/`; verify the cast plays in the built site
- [ ] 3.4 Write `tutorial/03-streaming` with "What changed", the cast, and a "Connecting a real model" note beside the effect (what to replace, what to keep); verify the page builds and the note refers only to released API

## 4. Step 4: status and interrupt

- [ ] 4.1 Create `examples/tutorial/step4-status` (a timer-driven spinner and elapsed time, Esc cancels the running answer through a shared cancel flag); verify `bal build` succeeds
- [ ] 4.2 Add tests (Esc during streaming stops the answer and commits an "interrupted" line; the next question still works; no duplicated or lost lines) and wire into `examples/check.sh`; verify they pass several times in a row
- [ ] 4.3 Record `step4-status.cast` with the recorder; verify it plays in the built site
- [ ] 4.4 Write `tutorial/04-status` covering the timer, quiet ticks, the idle-cost rule and the cancel flag, each linked to its concept page; verify the numbers quoted match `site/src/content/docs/concepts/idle-cost.mdx`

## 5. Step 5: tool calls with approval

- [ ] 5.1 Create `examples/tutorial/step5-approval` (the model plan gains a tool step; `session.confirm` runs before it; a denied tool is reported as denied); verify `bal build` succeeds
- [ ] 5.2 Add tests (answering `y` runs the tool, answering `n` denies it, and with a headless `Interface` the default is deny and nothing waits) and wire into `examples/check.sh`; verify `bal test` passes
- [ ] 5.3 Record `step5-approval.cast`; verify it plays in the built site
- [ ] 5.4 Write `tutorial/05-approval` including the headless behaviour and why deny is the default; verify the page matches `site/src/content/docs/concepts/headless-modes.mdx`

## 6. Step 6 and the finish

- [ ] 6.1 Create `examples/tutorial/step6-testing`: the harness from step 5 with a `tests/` folder showing the testing approach end to end (a scripted session under `FakeTerminal`, and a headless run asserting plain output); verify `bal test` passes and `examples/check.sh` runs it
- [ ] 6.2 Write `tutorial/06-testing` and a closing section that links `examples/agent-harness`, the concepts pages and the API reference; verify the harness program on the page is the one the tests run against
- [ ] 6.3 Replace the "coming soon" wording on the tutorial index and step 1 with real links; verify no page in `site/dist` contains "coming" and every internal link under `tutorial/` resolves (a link check over the built site)
- [ ] 6.4 Verify the finished tutorial end to end: follow steps 1 to 6 from a clean directory using only the pages and the pinned release, and confirm each step runs as its page says; note anything that needed a fix

## Workflow follow-up

- One pull request per step (or per two), merged in order; the index and step 1 links change in the last one.
- Archive the change after step 6 is live, then announce.
