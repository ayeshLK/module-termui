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
  term    (io, os)              Terminal interface, unix backend, fake backend, mode detection
  render  (text, term)          cell buffer, diff, inline viewport, commit-above, plain renderer
  root    (text, term, render)  MVU runtime, event queue, effects, prompts
```

The foundation imports only `io`, `os`, `time`, and `lang.*`, so that heavy modules (`http`, AI) remain the application's choice and startup stays light.

**Boundary: toolkit only.** The package exposes a message seam; the agent loop, tool registry, and permissions live in the application. Alternative: bundle harness primitives. Rejected: it would duplicate Ballerina's AI work and limit the toolkit's use for non-agent CLIs. A harness package can be layered on later.

**Terminal backend: interface plus two implementations.** A small `Terminal` interface with (a) a pure-Ballerina Unix backend and (b) an in-memory fake. The Unix backend:
- enters and leaves raw mode with `stty` run through `os:exec`, bound to `/dev/tty` (`stty -g` to save, restore on release), and reads and decodes bytes from the tty itself, using `min 0 time 1` style timeouts to distinguish a lone Esc from a sequence;
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
- [JVM startup time] -> Keep the foundation dependency-light and measure a hello-world baseline and time-to-first-frame in the spike; set a startup budget from the measured numbers.
- [Mutable model plus concurrent effects invites races] -> Single-owner loop, `readonly` messages, `isolated` effect functions, and verification that the compiler enforces this (spike).

## Spike (gate for the rest of the change)

These must be answered before building on the design; each has a fallback noted above.

1. Can a byte channel on `/dev/tty` read raw keystrokes, and does a read timeout (`min 0 time 1`) work, or is a zero-byte read treated as end of input?
2. Does a blocking read starve other strands, and does the reader need a dedicated thread?
3. Does the compiler enforce `isolated` for `start`ed effect functions, or only hint?
4. Does `runtime:onGracefulStop` fire on SIGINT and SIGTERM, including while the terminal is in raw mode?
5. Is write throughput acceptable, and can a whole frame be flushed in one write without flicker?
6. Baseline: hello-world startup and time-to-first-frame on the JVM.

## Open Questions

- Structured (JSON/NDJSON) output format: deferred to a later change; the commit model leaves room for it.
- The message seam with Ballerina's AI module: deferred until widgets and an agent example exist.
- The startup budget: set after the spike's baseline measurement.
- Whether to add a JLine backend, and for which platforms: decided after the first release.
