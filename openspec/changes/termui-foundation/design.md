# Design

## Context

See `proposal.md` - Why. The project is greenfield: no code exists yet. `termui-scaffold` supplies the build and CI. The toolchain is Ballerina 2201.14.2, which needs JDK 25 (and so Gradle 9); GraalVM `native-image` is not installed locally. Reference designs are Ratatui (cell buffer, diffing, inline viewport, `insert_before`) and Ink (declarative components, a `<Static>` region for committed output). The primary consumers are agentic CLIs that stream output while accepting input.

Findings from inspecting the local distribution:
- The standard library exposes `os:exec` (process spawn), `io` byte channels and stdout printing, `runtime:sleep`, and `runtime:onGracefulStop`.
- It has no queue or channel type, no condition variable, and no raw-terminal or stdin-raw API.
- Ballerina's Java interop is hand-written `@java:Method` externals; `bal bindgen` is experimental and is not used.
- The Ballerina distribution bundles JLine 3.25.0 for its own CLI, but this is not relied on.

## Goals / Non-Goals

**Goals:**
- A pure-Ballerina, Unix-first terminal UI foundation that supports the claude-code-style interaction model: live region, committed scrollback, streaming, and non-blocking input.
- A design where the riskiest layer (the terminal backend) sits behind an interface so it can be replaced and tested.
- Predictable behavior for non-interactive use from the first release.

**Non-Goals:**
- Agent logic, a declarative component layer, a layout solver, structured output, widgets, markdown, Windows, or a Java dependency in the first release (see `proposal.md`).

## Decisions

**Layering.** Four modules in one package, with no import cycles:

```
  text    (no deps)             styles, width, wrapping
  term    (io, os, text)        Terminal interface, unix backend, fake backend, mode detection
  render  (text, term)          cell buffer, diff, inline viewport, commit-above, plain renderer
  root    (text, term, render)  MVU runtime, event queue, effects, prompts
```

The foundation imports only `io`, `os`, `time`, and `lang.*`, so that heavy modules (`http`, AI) remain the application's choice and startup stays light.

**Boundary: toolkit only.** The package exposes a message seam; the agent loop, tool registry, and permissions live in the application. Alternative: bundle harness primitives. Rejected: it would duplicate Ballerina's AI work and limit the toolkit's use for non-agent CLIs. A harness package can be layered on later.

**Terminal backend: interface plus two implementations.** A small `Terminal` interface with (a) a pure-Ballerina Unix backend and (b) an in-memory fake. The Unix backend:
- enters and leaves raw mode with `stty` run through `os:exec`, bound to `/dev/tty` (`stty -g` to save, restore on release), and reads bytes from the tty with blocking reads (`min 1 time 0`) and decodes them itself, telling a lone Esc from the start of a sequence with a short decoder-level timeout (a pending Esc is emitted as Esc if no further byte arrives within a few tens of milliseconds), because the tty's own read timeout (`min 0 time 1`) does not work with Ballerina's byte channel (see Spike results);
- obtains the size from a cursor-position report (or `stty size`), detects resize by polling, and uses DEC mode 2048 notifications where a terminal supports them;
- restores the terminal on normal exit, on catchable errors, and through `runtime:onGracefulStop`;
- writes each frame in one flushed write.

Alternatives: JLine via a Java shim (mature, handles Windows and real signals, but adds a Java dependency, a callback-queue shim, and a packaging and native-image cost) and a hand-rolled approach without an interface (untestable). JLine remains an optional later backend behind the same interface, mainly for Windows. Pure Ballerina costs Windows support, real signal handling, and a hard-kill restore, which is accepted for macOS/Linux first.

**Renderer: Ratatui-inspired cell buffer.** Each frame is rendered into a grid of cells and diffed against the previous frame, with an inline viewport and a commit-above operation to move finished output into scrollback. Alternative: Ink-style string rewrite per frame. Rejected: it is more prone to flicker and scroll jumps under streaming and is harder to assert on in tests. A declarative component layer could be added on top of the buffer later without changing the core.

**Resize.** Committed history is never re-laid out by the toolkit. Prose is committed as logical lines so terminals that reflow soft-wrapped text do so for free; structured blocks (tables, boxes, diffs) are hard-wrapped at commit time. The live region is recomputed on resize: the toolkit knows what it drew, so it computes how many rows the old region now occupies (the sum over its lines of the ceiling of old width over new width), moves up that many, clears, and redraws. Alternatives: re-emit the entire transcript (needs clearing scrollback, which destroys the user's terminal history, and flickers), kept as a possible opt-in later; alt-screen mode is the escape hatch for layout-sensitive UIs.

**Runtime: pragmatic MVU.** The loop is Elm-shaped: all state changes happen in an update in response to a message, and effects return messages. Unlike strict MVU, the model may hold mutable widget objects and update may mutate it. The loop strand alone reads and mutates the model; effects communicate only by posting messages, which must be `readonly`; effect functions are `isolated`. Alternative: strict Bubble Tea-style purity with explicit forwarding. Rejected: Ballerina cannot enforce purity, and the ceremony hurts ergonomics.

**Event queue.** Ballerina has no channel or condition variable, so the queue is a lock-guarded structure behind a small interface. A reader strand (blocking tty read) pushes input, effects push results, and a tick strand pushes timers; the loop polls the queue every ~5-10 ms, drains all pending messages, applies them, and draws one frame. Costs: up to ~10 ms added latency and a few hundred cheap wakeups per second. The interface lets a different mechanism (for example a Java-backed blocking queue) replace polling if measurement requires it.

**Prompts.** Blocking convenience calls (`confirm`, `select`) are sugar over the loop. Without a terminal they return `NoTerminal` or the supplied default, so scripts never hang.

**Headless.** Mode is derived from whether stdin and stdout are terminals (detected with `test -t` via `os:exec`), plus `NO_COLOR`, `TERM=dumb`, and a default width of 80. Interactive chrome goes to the tty (or stderr) and results to stdout. The plain renderer prints committed items as lines with no ANSI. A committed item keeps room for an optional structured payload so a JSON/NDJSON mode can be added later without reworking the commit model.

**Platforms.** macOS and Linux first. Windows is deferred, and would require a different backend.

**Native-image.** A v1 goal but not a first-release goal. The foundation avoids reflection-style dynamism and heavy imports so the option stays open; `termui-scaffold` adds a non-blocking GraalVM check.

## Risks / Trade-offs

- [The pure-Ballerina tty approach may not work as assumed] -> The spike below gates the rest of the work; if it fails, fall back to the JLine shim backend behind the same interface.
- [Polling queue adds latency and wakeups] -> Keep the interval small, coalesce frames, measure, and keep the queue interface replaceable.
- [A hard kill (SIGKILL) can leave the terminal in raw mode] -> Restore on normal exit, catchable errors, and graceful stop; document `stty sane` for recovery.
- [Polling for resize leaves a short window of redrawing at the old size] -> Accept occasional self-healing artifacts; use DEC mode 2048 where available.
- [Terminals differ in reflow behavior] -> Compute clearing conservatively and cover it with fake-terminal tests that simulate reflowing and non-reflowing terminals.
- [JVM startup time] -> Measured in the spike (about 160 ms to first frame on the JVM, about 90 ms with an AppCDS archive); keep the foundation dependency-light and hold it to the budget proposed under Spike results.
- [Mutable model plus concurrent effects invites races] -> Single-owner loop, `readonly` messages, `isolated` effect functions, and verification that the compiler enforces this (spike).

## Spike (gate for the rest of the change)

These must be answered before building on the design; each has a fallback noted above.

1. Can a byte channel on `/dev/tty` read raw keystrokes, and does a read timeout (`min 0 time 1`) work, or is a zero-byte read treated as end of input? (Answered below.)
2. Does a blocking read starve other strands, and does the reader need a dedicated thread? (Answered below.)
3. Does the compiler enforce `isolated` for `start`ed effect functions, or only hint? (Answered below.)
4. Does `runtime:onGracefulStop` fire on SIGINT and SIGTERM, including while the terminal is in raw mode? (Answered below.)
5. Is write throughput acceptable, and can a whole frame be flushed in one write without flicker? (Answered below.)
6. Baseline: hello-world startup and time-to-first-frame on the JVM. (Answered below.)

## Open Questions

- Structured (JSON/NDJSON) output format: deferred to a later change; the commit model leaves room for it.
- The message seam with Ballerina's AI module: deferred until widgets and an agent example exist.
- The startup budget: proposed below from the spike baseline; confirmed or revised in task 8.3.
- Whether to add a JLine backend, and for which platforms: decided after the first release.

## Spike results

Measured on Ballerina 2201.14.2 / JDK 25 / macOS, driving a throwaway Ballerina program through a pseudo-terminal from a Python harness (the program is not in the repo).

1. **Raw tty reads (task 1.1).**
   - `stty raw -echo min 1 time 0 </dev/tty` through `os:exec`, then `io:openReadableFile("/dev/tty")` and `read(64)`, works: a read returns as soon as any bytes are available, not after 64. A typed `a` returned `[61]`, a lone Esc returned `[1b]` immediately, and an arrow-up sequence written by the terminal in one write returned `[1b 5b 41]` in a single read.
   - **`min 0 time 1` does not work.** The first read returns 0 bytes after about 100 ms, and every later read fails immediately with `EoF when reading from the channel`, so a zero-byte read permanently puts the channel into end-of-input. Read timeouts therefore cannot come from the tty driver.
   - **Consequence:** blocking reads plus a decoder-level Esc timeout (a trailing Esc waits a few tens of milliseconds for more bytes before it is reported as Esc). The decoder must also tolerate a sequence split across two reads, which can happen over slow links.

2. **Blocking reads and strand starvation (task 1.2).** A 100 ms ticker strand (`start`, `runtime:sleep`) kept a steady cadence of about 106 ms through a 3 second blocked `/dev/tty` read on the main strand, and a key written at 3.0 s was read at 3.05 s with no added delay. Repeating the run with `BALLERINA_MAX_POOL_SIZE=1` and `=2` gave the same result, but I could not confirm that variable shrinks the pool, so a very small thread pool is not proven safe. **Consequence:** the reader can be an ordinary `start`ed strand that blocks on the read; no dedicated thread or `@strand` annotation was needed on an 11-core machine, and CI (2-4 cores) will confirm it.

3. **Isolation enforcement (task 1.3).** Compiled on 2201.14.2 with throwaway samples:
   - A plain `start effect()` where `effect` is a non-isolated function that mutates a module-level variable **compiles with no diagnostic**: `start` itself does not enforce isolation.
   - The enforcement comes from types. A parameter typed `isolated function (...)` **rejects** a non-isolated function (`expected 'isolated function () returns ()', found 'function () returns ()'`), a parameter typed `Msg & readonly` **rejects** a mutable `Msg`, an `isolated` function that touches mutable module state is rejected (`invalid access of mutable storage in an 'isolated' function`), and an unlocked access to a mutable field of an `isolated` class is rejected.
   - **Consequence:** the runtime's effect API must take `isolated function` parameters and `readonly` messages, and the event queue must be an `isolated` class that guards its state with `lock`; then the single-owner and immutable-message rules are compiler-checked for everything that goes through the API. Application code that calls `start` directly bypasses the check, which is documented as out of contract.

4. **`onGracefulStop` on signals (task 1.4).** A handler registered with `runtime:onGracefulStop` that runs `stty <saved>` through `os:exec` ran and **restored the terminal (raw to cooked) on SIGTERM, SIGINT, and SIGHUP**, whether the main strand was sleeping or blocked in a `/dev/tty` read; the JVM then exited. SIGKILL cannot be handled, as expected. In raw mode Ctrl+C is the byte `0x03` and not a signal, so the application handles it as a key event; SIGINT only arrives from outside (for example `kill -INT`). **Caveat for tests:** when a harness signals a whole process group, the `bal run` launcher script dies at once while the JVM is still running its shutdown hook, so wait for the JVM itself (or signal only the JVM) before checking the terminal state. **Consequence:** the restore-on-exit plan stands; only SIGKILL leaves the terminal raw, which the README recovery note (`stty sane`) covers.

5. **Write throughput and flushing (task 1.5).** Measured by a Ballerina program writing to a pty that a harness drains, on this macOS machine (11 cores, JDK 25).
   - `io:print` **flushes without a newline**: `io:print("PARTIAL")` was visible 0.18 s after launch (when the JVM had started), not after the 2 s sleep that followed.
   - **One `io:print` per frame beats one per row by 4-6x**: 24x80 frames ran at about 32.8k frames/s in one write versus 5.5k frames/s row by row, and 50x200 frames (about 10 KB with ANSI) at about 11.6k frames/s versus 2.6k (0.09 ms versus 0.38 ms per frame). A single write is far below a 60 fps budget (16 ms).
   - I could not count `write(2)` calls (no `strace` or `dtruss` here), so "one write" is inferred from the throughput gap. Flicker cannot be measured headlessly; the mitigation is the single write per frame plus wrapping each frame in synchronized-output sequences (DEC mode 2026) on terminals that support it.
   - **Consequence:** the renderer builds the whole frame as one string and emits it with a single `io:print` (or `io:fprint` to the tty or stderr path), with synchronized output where available.

6. **JVM startup baseline (task 1.5).** `java -jar` of a built executable jar, 10 runs after a warm-up, timed from process start to the first byte of output under a pty (medians):

   | Configuration | Time to first frame |
   |---|---|
   | `java -version` (JVM floor) | 20 ms |
   | hello, imports `io` only | 156 ms |
   | hello, imports `io`, `os`, `time` (what the foundation imports) | 161 ms |
   | same, C1 compiler only (`-XX:TieredStopAtLevel=1`) | 140 ms |
   | same, AppCDS archive (`-XX:SharedArchiveFile`) | 92 ms |
   | same, AppCDS and C1 only | 80 ms |

   The three stdlib imports cost about 5 ms; the Ballerina runtime itself is the bulk of the gap above the JVM floor. **Proposed startup budget:** time to first frame of **250 ms or less** for a plain `java -jar` on a developer laptop (about 1.5x the measured 161 ms, leaving room for the foundation's own code), and **120 ms or less** with a documented AppCDS launcher (measured 92 ms). Task 8.3 re-measures on the finished foundation and confirms or revises these numbers.

## Go / no-go for the pure-Ballerina Unix backend (task 1.6)

**Recommendation: GO.** All six spike questions were answered, and none requires the JLine/Java-shim fallback.

| # | Question | Outcome | Adjustment to the design |
|---|---|---|---|
| 1 | Raw tty reads and read timeouts | Works with blocking reads; `min 0 time 1` fails (zero-byte read is a sticky EoF) | Esc versus sequence is decided by a decoder-level timeout; the decoder tolerates sequences split across reads |
| 2 | Blocking read starving strands | No starvation observed | The reader is an ordinary `start`ed strand |
| 3 | `isolated` enforcement | Enforced through types, not by `start` | Effect API takes `isolated function` and `readonly` messages; the queue is an `isolated` class with `lock` |
| 4 | `onGracefulStop` on signals | Restores the terminal on SIGTERM, SIGINT, SIGHUP | None; only SIGKILL leaves the terminal raw (README documents `stty sane`) |
| 5 | Write throughput and flushing | `io:print` flushes immediately; one write per frame is 4-6x faster than per row | One string and one print per frame; synchronized output where supported |
| 6 | Startup | About 160 ms to first frame on the JVM, about 90 ms with AppCDS | Budget proposed: 250 ms (120 ms with an AppCDS launcher) |

**Not covered by the spike (carried into later tasks):**
- Everything was measured on macOS only; Linux behavior (pty, `stty`, signals) is confirmed by the `tty` group in CI (task 4.2 onward).
- A very small thread pool is not proven safe for the blocking reader (task 1.2 caveat); CI runners (2-4 cores) will show it.
- The cost of spawning `stty` through `os:exec` for resize polling was not measured; task 4.3 should measure it and prefer the cursor-position-report method or DEC mode 2048 if it is slow.
- Windows remains out of scope.

If a later task finds one of these assumptions false, the fallback is the JLine backend behind the same `Terminal` interface, as designed.

## Findings while building the `term` module

- **Stdio detection needs an OS lookup.** A child started with `os:exec` always gets pipes, so it cannot tell whether the parent's stdin, stdout, or stderr is a terminal. `detectEnvironment` instead asks the operating system about its parent process: `readlink /proc/<pid>/fd/N` on Linux and `lsof` on macOS (about 25 ms, run once at startup), and treats a missing answer as "not a terminal" so the safe non-interactive mode is chosen. The probe script and its parser are separate, public, and tested (including under a real pty).
- **The fake terminal has a small virtual screen.** The `term` module imports `text` for display width, so `term` depends on `text` as well as `io` and `os`. The screen interprets cursor movement, erase, scrolling, and autowrap, and ignores styles and modes; a line feed moves down only, as in raw mode. Reflow on resize is not simulated yet; task 5.4 adds it where the renderer needs it.
- **`Terminal` is an isolated object type.** `nextEvent` blocks, so implementations must not hold a lock while waiting; the fake never blocks and returns `()` when its script is exhausted.

## Findings while building the Unix backend

- **Testing without a controlling terminal.** `UnixTerminal` takes the tty path (default `/dev/tty`) and runs `stty` with `< path`, so tests do not need a controlling terminal. A Python helper (`tests/resources/pty_helper.py`) owns a pty pair, publishes the slave path, and drives a plan of steps through marker files: it snapshots termios, injects bytes, and reads what the application wrote. Snapshots mask the kernel's transient `PENDIN` flag, which changes as a side effect of switching modes and is not a setting.
- **The reader strand and the byte queue.** One reader strand per terminal blocks on the device and pushes bytes into an `isolated` queue; `nextEvent` polls the queue every 2 ms, decodes, and applies the 50 ms Esc timeout. A blocked read cannot be cancelled, so `release` does not stop the reader and it may take the first byte typed after release; applications that exit right after `release` are unaffected.
- **Ballerina gotcha:** pushing a `byte` directly into an `int[]` compiles but throws a `ClassCastException` at runtime (bytes and ints have different representations). Convert explicitly (`int value = chunk[i]`). `ByteQueue` has a regression test.
- **Reserved words** that are easy to hit as names: `start`, `final`, `flush`, `from`.
- **Resize detection cost.** `size()` through `sh` and `stty` costs about 15 ms per call, so the backend turns on in-band resize reports (DEC mode 2048) and polls only until the first report arrives; without one it polls about once a second, outside the terminal lock so writes never wait on it. A cursor-position or `CSI 18 t` query would avoid the spawn and is left as an optimization.
- **Frame write cost.** Each `write` opens, writes, and closes the device through `io:fileWriteString`: about 860 frames per second at 10 KB per frame (1.2 ms each) measured through a pty, against about 11,600 frames per second for `io:print` in the spike. That is far above a 60 fps need, but if profiling shows it matters, writing through `io:print` when standard output is the terminal is the mitigation. Large frames (200 KB, more than a pty holds) arrive complete and in order.
- **A vanished terminal can block `release` forever.** Opening the device of a closed window or a destroyed pty for writing blocks, and `release` runs inside the graceful-stop hook (for example on SIGHUP when the window closes), so an untimed release could keep the process from ever exiting. This was found when a test left a terminal acquired after its pty was gone, and a thread dump showed the hook stuck in `openWritableFile`. Every device access in `acquire`, `release`, and `size` now runs through `shellWithin`, a shell command in a background subshell that a timer kills after a few seconds (3 s for release); `release` is a single timed command that switches the reports off and restores the settings. A regression test covers it.

## Findings while building the renderer

- **Reflow needed a model.** The fake terminal now tracks which rows ended in an automatic wrap, re-splits them like a reflowing terminal on a width change (the cursor stays on its character, rows that no longer fit move into the scrollback, empty rows below the cursor are not content), and can instead cut text off (`reflow = false`). It also supports the alternate screen. A mutation of the rows-occupied calculation fails exactly the narrowing test, so the resize tests are not vacuous.
- **Resize cannot be fully automatic.** The renderer cannot detect whether the terminal reflowed, so `InlineRenderer` takes a `reflow` option (default `true`); a wrong value leaves stale rows or clears too many. A cursor-position query could detect it later.
- **Region rules:** it starts on a row at column 0, is clamped to the terminal height, and leaves the cursor at column 0 of its last row; `close` moves to a fresh line. Terminal height is passed in and updated by `resize`.
- **Renderers are plain classes**, not isolated ones: the runtime's loop strand owns them, so locking would only add ceremony.

## Findings while building the runtime

- **The `Engine` is the unit.** `Engine.step()` applies every waiting message, carries out the commands they return, and draws at most one frame; `run` is a loop over it. Tests drive `step()` directly, which keeps them deterministic.
- **Compile-time checks, shown on 2201.14.2:** passing a mutable `map<string>` to `Session.send` fails (`expected 'Message', found 'map<string>'`), and passing a non-isolated function to `effect` fails (`expected 'EffectFunction', found 'function (Session) returns (error?)'`). The runtime test also asserts that every delivered message, including terminal input, is readonly.
- **The final frame is drawn on quit**, so the last state stays on screen.
- **Prompts:** an effect asks through a one-slot board and polls for the answer; the loop shows the question below the view and routes keys to it. `choose` is the name of the pick-one method because `select` is reserved.
- **Reserved words** hit again: `commit`, `select`, `start`, `by`, `order`.

## Findings while building headless mode

- **`Interface` is the one place that chooses.** It picks the terminal (`UnixTerminal` for `interactive` and `pipedOutput`, `StreamTerminal` otherwise), the renderer (inline or plain), and the `run` options from the four stdin/stdout combinations; `result` always goes to standard output (or a result file for tests), so chrome and results never mix. In `pipedOutput` a terminal is still available, so questions can be asked.
- **Questions without a terminal fail fast.** `confirm` and `choose` return their default or a `NoTerminal` error at once instead of waiting for input that cannot come; verified with a time bound.
- **Colors on a terminal with redirected output** are decided by `NO_COLOR` and `TERM=dumb` only, because the interface is not drawn on standard output; `Environment` therefore gained a `noColor` field.
- **A Ballerina gotcha for tests:** `io:fileReadString` drops a trailing newline (3 characters for 4 bytes). Read bytes when a test must see exactly what was written.
- **`PlainRenderer` writes the live region once**, at `close`, so a spinner appears as its final frame only.
