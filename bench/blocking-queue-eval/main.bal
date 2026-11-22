import ballerina/io;
import ballerina/lang.runtime;

isolated function newQueue(string strategy, int capacity = 1024) returns WorkQueue|error {
    match strategy {
        "poll" => {
            return new PollQueue();
        }
        "pipe-queue" => {
            return new PipeQueue(capacity);
        }
        "pipe-bell" => {
            return new PipeBellQueue();
        }
        "jdk" => {
            return new JdkQueue();
        }
        "broken" => {
            return new BrokenQueue();
        }
    }
    return error(string `unknown strategy: ${strategy}`);
}

// A push must not block whether or not the consumer is awake: 20000 pushes with nobody waiting, then while the
// consumer is asleep and while it is awake, each within a generous limit.
isolated function bellDoesNotBlock(WorkQueue queue) returns error? {
    decimal began = nowSeconds();
    foreach int i in 0 ..< 20000 {
        queue.push(keyMessage("a"));
    }
    _ = queue.takeAll();
    future<decimal|error> sleeper = start consumeOne(queue, 5);
    runtime:sleep(0.2);
    foreach int i in 0 ..< 20000 {
        queue.push(keyMessage("b"));
    }
    decimal|error received = wait sleeper;
    boolean woke = received is decimal;
    decimal took = nowSeconds() - began;
    if !woke || took > 5d {
        return error(string `bell: pushes took ${took} s, consumer woke: ${woke}`);
    }
    io:println(string `bell pushes did not block: 40000 pushes in ${(took * 1000).round(1)} ms`);
}

isolated function smoke(string strategy) returns error? {
    WorkQueue queue = check newQueue(strategy);
    Message[] sent = [keyMessage("a"), resizeMessage(), pasteMessage()];
    foreach Message message in sent {
        queue.push(message);
    }
    if !queue.waitForWork(1) {
        return error(string `${strategy}: waitForWork timed out with messages queued`);
    }
    Message[] got = queue.takeAll();
    if got != sent {
        return error(string `${strategy}: took ${got.length()} messages, expected the ${sent.length()} sent, in order`);
    }
    if queue.waitForWork(0.05) {
        return error(string `${strategy}: waitForWork reported work on an empty queue`);
    }
    if strategy == "pipe-bell" {
        check bellDoesNotBlock(queue);
    }
    queue.close();
    io:println(string `smoke ${strategy}: ok`);
}

isolated function intArg(string[] args, int index, int fallback) returns int|error {
    return args.length() > index ? check int:fromString(args[index]) : fallback;
}

isolated function decimalArg(string[] args, int index, decimal fallback) returns decimal|error {
    return args.length() > index ? check decimal:fromString(args[index]) : fallback;
}

// Every workload with small parameters, to check that the driver works for a strategy.
isolated function quick(string strategy) returns error? {
    check smoke(strategy);
    check latencyWorkload(strategy, [0.1, 0.5], 3);
    check idleWorkload(strategy, 1);
    check drainWorkload(strategy);
    check throughputWorkload(strategy, 2, 4000, "key");
    check stressWorkload(strategy, "wait", 1, 2);
    check retentionWorkload(strategy, 1000, 0);
    check shutdownWorkload(strategy, 64);
}

const string USAGE = string `usage: bal run -- <command> <strategy> [arguments]
  smoke
  quick
  latency [samples=30] [gap gap ...]      gaps default to 0.1 1 3 10 seconds
  idle [seconds=75]                       prints IDLE_READY; measure CPU from outside (idle_cpu.py)
  drain
  throughput [producers=1] [messages=200000] [shape=key|paste]
  stress [mode=wait|spin] [seconds=2] [runs=1]
  retention [operations=100000] [hold=0] [fresh]  with hold > 0 prints RETENTION_DONE and waits (retention.py)
  shutdown [capacity=1024]`;

public function main(string... args) returns error? {
    if args.length() < 2 {
        io:println(USAGE);
        return;
    }
    string strategy = args[1];
    match args[0] {
        "smoke" => {
            check smoke(strategy);
        }
        "quick" => {
            check quick(strategy);
        }
        "latency" => {
            decimal[] gaps = [];
            foreach int i in 3 ..< args.length() {
                gaps.push(check decimal:fromString(args[i]));
            }
            check latencyWorkload(strategy, gaps.length() == 0 ? [0.1, 1, 3, 10] : gaps, check intArg(args, 2, 30));
        }
        "idle" => {
            check idleWorkload(strategy, check decimalArg(args, 2, 75));
        }
        "drain" => {
            check drainWorkload(strategy);
        }
        "throughput" => {
            check throughputWorkload(strategy, check intArg(args, 2, 1), check intArg(args, 3, 200000),
                    args.length() > 4 ? args[4] : "key");
        }
        "stress" => {
            check stressWorkload(strategy, args.length() > 2 ? args[2] : "wait", check decimalArg(args, 3, 2),
                    check intArg(args, 4, 1));
        }
        "retention" => {
            check retentionWorkload(strategy, check intArg(args, 2, 100000), check decimalArg(args, 3, 0),
                    args.length() > 4 && args[4] == "fresh");
        }
        "shutdown" => {
            check shutdownWorkload(strategy, check intArg(args, 2, 1024));
        }
        _ => {
            return error(string `unknown command: ${args[0]}`);
        }
    }
}
