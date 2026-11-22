# Proposal

## Why

The runtime waits for work by polling: the message loop sleeps and calls `takeAll`, the Unix terminal does the same
for input bytes, and prompts spin on 5 ms sleeps. Release 1.0.1 added an idle backoff to make that cheap (about 1% of
a core idle, a median first key of 40 to 110 ms after idleness), but a blocking wait would remove the idle cost and
the first-key delay altogether. `xlibb/pipe` is the obvious blocking queue for Ballerina, and an exploration of its
source found two risks that reading cannot settle: the "is it empty?" check goes through a Java timer thread and an
unsynchronized observer list, and every pipe owns a `java.util.Timer`. Adopting a native-backed, thinly maintained
dependency into a package that is pure Ballerina today is only worth it if the numbers justify it.

## What Changes

- Build a throwaway measurement harness, outside the `ballerina/` package, that runs the same workloads against four
  waiting strategies: the current polling backoff (baseline), `xlibb/pipe` used as the engine's queue, `xlibb/pipe`
  used only as a wake-up signal, and a blocking queue taken from the JDK through Ballerina's Java interop.
- Measure wake latency after idle, idle CPU, per-message and per-frame cost, correctness under concurrent
  producers (including timeout-0 drains), shutdown behavior with blocked producers, and what each option does to the
  package's platform and build.
- Write the results and a go or no-go recommendation against the criteria in `design.md`.
- No change to the package, its tests, its options or its specs. If the recommendation is "go", the adoption is
  proposed as a separate change.

## Capabilities

### New Capabilities

None. This change measures; it does not change behavior.

### Modified Capabilities

None. `mvu-runtime` and `terminal-backend` would change only if a later change adopts a blocking queue, and that
change owns the spec delta. This change sets `skip_specs: true`.

## Impact

- Adds a small Ballerina project under `bench/` (not published, not part of the package build) and a findings report
  in this change's directory.
- Needs network access once to pull `xlibb/pipe` from Ballerina Central, and the local JDK 25 / Ballerina 2201.14.2
  toolchain.
- No effect on the published package, its API, or its dependencies.
