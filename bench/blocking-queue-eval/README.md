# Blocking message queue evaluation

A throwaway harness, outside the `ballerina/` package, that runs the same workloads against different ways for the
runtime's loop to wait for messages. It exists to answer one question with numbers: is `xlibb/pipe` (or another
blocking queue) a good replacement for the polling backoff of termui 1.0.1? The plan, the strategies and the criteria
for the answer are in `openspec/changes/evaluate-blocking-message-queue/` (`design.md`); the results are in
`findings.md` there. Nothing here is part of the published package.

## Strategies

| id | What it is |
|---|---|
| `poll` | Baseline: termui's lock-guarded list, and a consumer that sleeps between checks with the 1.0.1 idle backoff (5 ms growing to 0.5 s). |
| `pipe-queue` | `xlibb/pipe` as the queue: one blocking `consume` for the first message, then `consume(0)` to drain. |
| `pipe-bell` | The lock-guarded list stays the queue; a one-slot `xlibb/pipe` is only a wake-up signal. |
| `jdk` | `java.util.concurrent.LinkedBlockingQueue` through Ballerina's Java interop. |
| `broken` | A deliberately faulty queue (drops every 1000th message), used to check that the stress test can fail. |

`jdk` is unbounded and `poll`, `pipe-bell` and `jdk` keep their messages in a list or JDK queue; only `pipe-queue` is bounded (1024).

## Running

Needs Ballerina 2201.14.2 and a JDK (the machine's `java`, or `JAVA=/path/to/java`); Python 3 for the two wrappers.
`xlibb/pipe` is fetched from Ballerina Central the first time the project is built.

```sh
cd bench/blocking-queue-eval
bal build                                   # target/bin/blocking_queue_eval.jar
java -jar target/bin/blocking_queue_eval.jar <command> <strategy> [arguments]
```

(`bal run -- <command> <strategy> ...` does the same.) Every measurement is one line,
`RESULT workload=<name> strategy=<id> key=value ...`, so a run can be filtered with `grep ^RESULT`.

| Command | Measures | Defaults |
|---|---|---|
| `smoke` | Pushes the three message shapes, takes them in order, and checks that an empty queue reports no work. | |
| `quick` | Every workload with tiny parameters, to check a strategy works with the driver. Not for numbers. | |
| `latency [samples] [gaps...]` | Time from a push to the consumer holding the message, after an idle gap during which the consumer was already waiting. p50, p95 and max in milliseconds per gap. | 30 samples; gaps 0.1, 1, 3, 10 s |
| `idle [seconds]` | Nothing by itself: it waits, and prints `IDLE_READY`. Use `idle_cpu.py` to measure. | 75 s |
| `drain` | Time to get 0, 1, 50 and 1000 waiting messages out, one drain at a time, in microseconds. The empty drain is the cost the loop pays on every frame. | |
| `throughput [producers] [messages] [shape]` | Messages per second with that many producer strands and one consumer; `shape` is `key` (small record) or `paste` (4 KB string). | 1, 200000, key |
| `stress [mode] [seconds] [runs]` | Correctness: 8 producers send numbered messages; the consumer checks that each arrives once and in its producer's order. `mode` is `wait` (wait, then drain) or `spin` (drain in a tight loop, which maximises empty drains). A run that does not finish within `seconds` + 60 s is a hang. | wait, 2 s, 1 run |
| `retention [operations] [hold] [fresh]` | Time per successful timed wait over many operations; with `fresh` every message is a newly created record, otherwise one pre-built message is reused. With `hold` > 0 it prints `RETENTION_DONE` and waits, so `retention.py` can read the heap and the live timer tasks. | 100000, 0, reused |
| `shutdown [capacity]` | Close the queue while a consumer is blocked, and while 8 producers are blocked on a full queue; time until each returns. | 1024 |

### CPU while idle

```sh
python3 idle_cpu.py poll --warmup 16 --window 60
```

Runs `idle`, waits for the marker, lets it settle (the backoff takes about 13 s to reach its ceiling), then reads the
process's CPU time with `ps` over the window. It is the method of `bench/idle_cpu.py`, without a pseudo-terminal.
Repeat with `--runs 3` and read the figures as magnitudes.

### Retention

```sh
python3 retention.py pipe-queue 100000 fresh      # <strategy> [operations] [same|fresh]
```

Runs `retention` with a hold, then takes a full-GC class histogram with `jcmd` (live objects only) and prints one
`RESULT workload=retentionJvm` line: heap in use, and the live pipe `Callback`, `Observable` and `TimerTask` objects and
message maps. It shows whether finished waits leave timer tasks or messages behind. Needs `jcmd` from the same JDK.

## Reproducing `findings.md`

The commands behind each section (every number is from this machine; see the note on noise below):

```sh
bq() { java -jar target/bin/blocking_queue_eval.jar "$@"; }   # works in bash and zsh
bq latency <s> 30 0.1 1 3 10                        # wake latency
python3 idle_cpu.py <s> --warmup 16 --window 60 --runs 3   # idle CPU
bq drain <s>                                        # drain cost
java -Xmx2g -jar target/bin/blocking_queue_eval.jar throughput <s> 1 2000000 key   # three runs; 400000 for pipe-queue
bq shutdown <s>
bq stress <s> wait 2 100 ; bq stress <s> spin 2 20 # short stress
bq stress <s> wait 600 1                            # long stress, idle machine
# long stress under load: start 2 x cores `yes > /dev/null &` first, as bench/stress_tests.sh does, then
bq stress <s> wait 600 1                            # (default heap for every strategy, so they are comparable)
bq stress broken wait 2 3                           # must report failedRuns=3, or the stress check proves nothing
```

where `<s>` is `poll`, `pipe-queue`, `pipe-bell` or `jdk`. Use the same heap setting for every strategy in one
comparison; an unbounded queue under load can need more than a small heap.

## Reading the numbers

Timing on a laptop is noisy: run workloads more than once and read distributions (p50, p95, max) as magnitudes, as
`bench/README.md` advises. Latency numbers for `poll` should be of the same order as `bench/latency.py` on the counter
example; the cross-check is recorded in `findings.md`.
