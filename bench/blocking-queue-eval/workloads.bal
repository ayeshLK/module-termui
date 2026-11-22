import ballerina/io;
import ballerina/lang.runtime;

// ---- reporting -------------------------------------------------------------------------------------------

isolated function ms(decimal seconds) returns string {
    return (seconds * 1000).round(3).toString();
}

isolated function us(decimal seconds) returns string {
    return (seconds * 1000000).round(1).toString();
}

// One machine-readable line per measurement: RESULT workload=<w> strategy=<s> key=value ...
isolated function report(string workload, string strategy, map<string> fields) {
    string line = string `RESULT workload=${workload} strategy=${strategy}`;
    foreach var [key, value] in fields.entries() {
        line += string ` ${key}=${value}`;
    }
    io:println(line);
}

isolated function percentile(decimal[] sorted, decimal p) returns decimal {
    if sorted.length() == 0 {
        return 0;
    }
    int rank = <int>(<decimal>sorted.length() * p).ceiling();
    int index = rank < 1 ? 0 : (rank > sorted.length() ? sorted.length() - 1 : rank - 1);
    return sorted[index];
}

// p50, p95 and max of durations in seconds, as text in milliseconds (or microseconds when `micro`).
isolated function summary(decimal[] values, boolean micro = false) returns map<string> {
    decimal[] sorted = values.sort();
    decimal top = sorted.length() == 0 ? 0 : sorted[sorted.length() - 1];
    return {
        n: values.length().toString(),
        p50: micro ? us(percentile(sorted, 0.5)) : ms(percentile(sorted, 0.5)),
        p95: micro ? us(percentile(sorted, 0.95)) : ms(percentile(sorted, 0.95)),
        max: micro ? us(top) : ms(top)
    };
}

// ---- 1. wake latency after an idle gap ----------------------------------------------------------------------

isolated function consumeOne(WorkQueue queue, decimal timeout) returns decimal|error {
    if !queue.waitForWork(timeout) {
        return error("timed out waiting for the message");
    }
    if queue.takeAll().length() == 0 {
        return error("woke with nothing to take");
    }
    return nowSeconds();
}

// The consumer is already waiting when the producer's gap starts, so a backing-off consumer is as far into its
// backoff as it would be in a program that has been idle for `gap`.
isolated function latencyWorkload(string strategy, decimal[] gaps, int samples) returns error? {
    foreach decimal gap in gaps {
        WorkQueue queue = check newQueue(strategy, 1024);
        decimal[] latencies = [];
        foreach int i in 0 ..< samples {
            future<decimal|error> consumer = start consumeOne(queue, gap + 30);
            runtime:sleep(gap);
            decimal sent = nowSeconds();
            Stamp stamp = {sentAt: sent};
            queue.push(stamp.cloneReadOnly());
            decimal received = check wait consumer;
            latencies.push(received - sent);
        }
        queue.close();
        map<string> fields = summary(latencies);
        fields["gapSeconds"] = gap.toString();
        report("latency", strategy, fields);
    }
}

// ---- 2. idle CPU ---------------------------------------------------------------------------------------------

// The process's CPU time is read from outside (idle_cpu.py), between the IDLE_READY marker plus a warm-up and the
// end of the wait; this only waits.
isolated function idleWorkload(string strategy, decimal seconds) returns error? {
    WorkQueue queue = check newQueue(strategy, 1024);
    io:println("IDLE_READY");
    boolean woke = queue.waitForWork(seconds);
    queue.close();
    report("idle", strategy, {seconds: seconds.toString(), woke: woke.toString()});
}

// ---- 3. throughput and the cost of a drain ---------------------------------------------------------------------

isolated function produceMany(WorkQueue queue, int count, Message message) {
    foreach int i in 0 ..< count {
        queue.push(message);
    }
}

isolated function throughputWorkload(string strategy, int producers, int total, string shape) returns error? {
    WorkQueue queue = check newQueue(strategy, 1024);
    Message message = shape == "paste" ? pasteMessage() : keyMessage("a");
    int each = total / producers;
    int expected = each * producers;
    decimal started = nowSeconds();
    foreach int p in 0 ..< producers {
        _ = start produceMany(queue, each, message);
    }
    int received = 0;
    decimal lastProgress = nowSeconds();
    while received < expected {
        if queue.waitForWork(1) {
            int before = received;
            received += queue.takeAll().length();
            if received > before {
                lastProgress = nowSeconds();
            }
        }
        if nowSeconds() - lastProgress > 30d {
            return error(string `${strategy}: no progress for 30 s at ${received} of ${expected}`);
        }
    }
    decimal elapsed = nowSeconds() - started;
    queue.close();
    report("throughput", strategy, {
        producers: producers.toString(),
        shape,
        messages: expected.toString(),
        seconds: elapsed.round(3).toString(),
        perSecond: (<decimal>expected / elapsed).round(0).toString()
    });
}

// Time to get `size` waiting messages out (waiting then taking when there are some; an empty take when there
// are none), measured one drain at a time.
isolated function drainWorkload(string strategy) returns error? {
    int[] sizes = [0, 1, 50, 1000];
    int[] repeats = [2000, 2000, 300, 60];
    foreach int index in 0 ..< sizes.length() {
        int size = sizes[index];
        WorkQueue queue = check newQueue(strategy, 1024);
        Message message = keyMessage("a");
        decimal[] times = [];
        foreach int round in 0 ..< repeats[index] + 100 {
            foreach int i in 0 ..< size {
                queue.push(message);
            }
            decimal began = nowSeconds();
            if size > 0 && !queue.waitForWork(5) {
                return error(string `${strategy}: waitForWork timed out with ${size} queued`);
            }
            Message[] got = queue.takeAll();
            decimal took = nowSeconds() - began;
            if got.length() != size {
                return error(string `${strategy}: drained ${got.length()} of ${size}`);
            }
            if round >= 100 { // the first rounds warm the JIT and are not counted
                times.push(took);
            }
        }
        queue.close();
        map<string> fields = summary(times, true);
        fields["batch"] = size.toString();
        fields["unit"] = "us";
        report("drain", strategy, fields);
    }
}

// ---- 4. correctness under concurrent producers ----------------------------------------------------------------

isolated class Tally {
    private int finished = 0;
    private int sent = 0;
    private int exceptions = 0;

    isolated function done(int count, boolean failed) {
        lock {
            self.finished += 1;
            self.sent += count;
            if failed {
                self.exceptions += 1;
            }
        }
    }

    isolated function snapshot() returns [int, int, int] {
        lock {
            return [self.finished, self.sent, self.exceptions];
        }
    }
}

isolated function produceNumbered(WorkQueue queue, int producer, decimal deadline, int[] counter) {
    int n = 0;
    while nowSeconds() < deadline {
        Numbered message = {producer, n};
        queue.push(message.cloneReadOnly());
        n += 1;
        counter[0] = n;
        if n % 64 == 0 {
            runtime:sleep(0.0001); // lets the consumer interleave, and keeps unbounded queues from growing without limit
        }
    }
}

isolated function stressProducer(WorkQueue queue, int producer, decimal deadline, Tally tally) {
    int[] counter = [0];
    error? failure = trap produceNumbered(queue, producer, deadline, counter);
    tally.done(counter[0], failure is error);
}

isolated function sleepFor(decimal seconds) {
    runtime:sleep(seconds);
}

// Every producer sends numbered messages for `seconds`; the consumer checks that each arrives once and in the order
// its producer sent it. `spin` mode drains in a tight loop without waiting, which maximises empty drains.
isolated function stressRun(string strategy, int producers, decimal seconds, string mode) returns map<string>|error {
    WorkQueue queue = check newQueue(strategy, 1024);
    Tally tally = new;
    decimal deadline = nowSeconds() + seconds;
    foreach int p in 0 ..< producers {
        _ = start stressProducer(queue, p, deadline, tally);
    }
    int[] expected = [];
    foreach int p in 0 ..< producers {
        expected.push(0);
    }
    int received = 0;
    int outOfOrder = 0;
    int consumerExceptions = 0;
    decimal lastProgress = nowSeconds();
    decimal allDoneAt = 0;
    while true {
        [int, int, int] [finished, sent, _] = tally.snapshot();
        boolean allDone = finished == producers;
        if allDone && received >= sent {
            break;
        }
        if allDone {
            if allDoneAt == 0d {
                allDoneAt = nowSeconds();
            } else if nowSeconds() - allDoneAt > 5d {
                break; // messages that never arrived: reported as lost below
            }
        }
        if nowSeconds() - lastProgress > 30d {
            return error(string `${strategy}: no message for 30 s at ${received} received`);
        }
        Message[]|error got = [];
        if mode == "spin" {
            got = trap queue.takeAll();
        } else {
            boolean|error ready = trap queue.waitForWork(0.2);
            got = ready is error ? ready : (ready ? trap queue.takeAll() : []);
        }
        if got is error {
            consumerExceptions += 1;
            continue;
        }
        if got.length() > 0 {
            lastProgress = nowSeconds();
        }
        foreach Message message in got {
            if message is Numbered {
                received += 1;
                if message.n != expected[message.producer] {
                    outOfOrder += 1;
                }
                expected[message.producer] = message.n + 1;
            }
        }
    }
    queue.close();
    [int, int, int] [_, sentTotal, producerExceptions] = tally.snapshot();
    int lost = sentTotal - received;
    boolean ok = lost == 0 && outOfOrder == 0 && consumerExceptions == 0 && producerExceptions == 0;
    return {
        mode,
        producers: producers.toString(),
        sent: sentTotal.toString(),
        received: received.toString(),
        lostOrDuplicated: lost.toString(),
        outOfOrder: outOfOrder.toString(),
        exceptions: (consumerExceptions + producerExceptions).toString(),
        ok: ok.toString()
    };
}

// `runs` runs of `seconds` each; a run that does not finish within `seconds` + 60 s is a hang.
isolated function stressWorkload(string strategy, string mode, decimal seconds, int runs) returns error? {
    int failures = 0;
    foreach int run in 0 ..< runs {
        future<map<string>|error> body = start stressRun(strategy, 8, seconds, mode);
        future<()> watchdog = start sleepFor(seconds + 60d);
        map<string>|error|() outcome = trap wait body|watchdog;
        if outcome is () {
            report("stress", strategy, {run: run.toString(), mode, hang: "true", ok: "false"});
            return error(string `${strategy}: run ${run} hung`);
        }
        if outcome is error {
            report("stress", strategy, {run: run.toString(), mode, failure: outcome.message(), ok: "false"});
            failures += 1;
            continue;
        }
        map<string> fields = {run: run.toString()};
        foreach var [key, value] in outcome.entries() {
            fields[key] = value;
        }
        report("stress", strategy, fields);
        if outcome["ok"] != "true" {
            failures += 1;
        }
    }
    report("stressTotal", strategy, {mode, runs: runs.toString(), failedRuns: failures.toString()});
}

// ---- 5. timer retention (the heap is read from outside, by retention.py, while this holds) ------------------------

isolated function retentionWorkload(string strategy, int count, decimal hold, boolean fresh = false) returns error? {
    WorkQueue queue = check newQueue(strategy, 1024);
    Message message = keyMessage("a");
    decimal started = nowSeconds();
    foreach int i in 0 ..< count {
        if fresh { // a newly created record every time, as the stress producers do
            Numbered numbered = {producer: 0, n: i};
            queue.push(numbered.cloneReadOnly());
        } else {
            queue.push(message);
        }
        if !queue.waitForWork(0.5) {
            return error(string `${strategy}: waitForWork timed out with a message queued`);
        }
        _ = queue.takeAll();
    }
    decimal elapsed = nowSeconds() - started;
    report("retention", strategy, {
        operations: count.toString(),
        seconds: elapsed.round(3).toString(),
        perOperationUs: us(elapsed / <decimal>count)
    });
    if hold > 0d {
        io:println("RETENTION_DONE");
        runtime:sleep(hold);
    }
    queue.close();
}

// ---- 6. closing while others are blocked -------------------------------------------------------------------------

isolated function blockedConsumer(WorkQueue queue) returns [decimal, string] {
    boolean|error outcome = trap queue.waitForWork(-1);
    return [nowSeconds(), outcome is error ? "error" : (outcome ? "work" : "closed")];
}

isolated function blockedProducer(WorkQueue queue) returns [decimal, string] {
    error? outcome = trap queue.push(keyMessage("x"));
    return [nowSeconds(), outcome is error ? "error" : "returned"];
}

isolated function shutdownWorkload(string strategy, int capacity) returns error? {
    // A consumer blocked on an empty queue.
    WorkQueue queue = check newQueue(strategy, capacity);
    future<[decimal, string]> consumer = start blockedConsumer(queue);
    future<()> watchdog = start sleepFor(10);
    runtime:sleep(0.3);
    decimal closedAt = nowSeconds();
    queue.close();
    [decimal, string]|()|error consumerResult = trap wait consumer|watchdog;
    if consumerResult is error {
        return consumerResult;
    }
    if consumerResult is () {
        report("shutdown", strategy, {case: "consumer", hang: "true"});
        return error(string `${strategy}: a blocked consumer did not return after close`);
    }
    report("shutdown", strategy, {
        case: "consumer",
        returnedMs: ms(consumerResult[0] - closedAt),
        status: consumerResult[1]
    });

    // Eight producers blocked on a full queue (for a queue with no bound they do not block at all).
    WorkQueue full = check newQueue(strategy, capacity);
    foreach int i in 0 ..< capacity {
        full.push(keyMessage("fill"));
    }
    future<[decimal, string]>[] producers = [];
    foreach int p in 0 ..< 8 {
        future<[decimal, string]> started = start blockedProducer(full);
        producers.push(started);
    }
    runtime:sleep(0.3);
    decimal fullClosedAt = nowSeconds();
    full.close();
    decimal slowest = 0;
    int blocked = 0;
    string[] statuses = [];
    foreach future<[decimal, string]> producer in producers {
        future<()> producerWatchdog = start sleepFor(10);
        [decimal, string]|()|error result = trap wait producer|producerWatchdog;
        if result is error {
            return result;
        }
        if result is () {
            report("shutdown", strategy, {case: "producers", hang: "true"});
            return error(string `${strategy}: a blocked producer did not return after close`);
        }
        if result[0] >= fullClosedAt {
            blocked += 1;
            decimal after = result[0] - fullClosedAt;
            slowest = after > slowest ? after : slowest;
        }
        statuses.push(result[1]);
    }
    report("shutdown", strategy, {
        case: "producers",
        producers: "8",
        blockedUntilClose: blocked.toString(),
        slowestReturnMs: ms(slowest),
        statuses: string:'join(",", ...statuses)
    });
}
