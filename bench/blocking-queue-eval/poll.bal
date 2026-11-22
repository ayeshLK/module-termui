import ballerina/lang.runtime;

// The idle backoff of termui 1.0.1 (ballerina/backoff.bal), copied unchanged so the baseline waits the way
// the runtime does.
const int EMPTY_CHECKS_PER_STEP = 20;
const decimal BASE_INTERVAL = 0.005;
const decimal CEILING_INTERVAL = 0.5;

isolated function backOff(decimal current, int emptyChecks, decimal base, decimal ceiling) returns [decimal, int] {
    if ceiling <= base {
        return [base, 0];
    }
    decimal now = current < base ? base : (current > ceiling ? ceiling : current);
    int counted = emptyChecks + 1;
    if counted < EMPTY_CHECKS_PER_STEP || now >= ceiling {
        return [now, now >= ceiling ? 0 : counted];
    }
    decimal doubled = now * 2;
    return [doubled > ceiling ? ceiling : doubled, 0];
}

// Baseline: the lock-guarded list of termui's MessageQueue, and a consumer that sleeps between checks with
// the backoff. `waitForWork` is the engine's "sleep, then step" loop with the step reduced to "is anything
// waiting".
isolated class PollQueue {
    *WorkQueue;

    private Message[] items = [];
    private boolean closed = false;
    private decimal interval = 0;
    private int emptyChecks = 0;

    isolated function push(Message message) {
        lock {
            if !self.closed {
                self.items.push(message);
            }
        }
    }

    isolated function waitForWork(decimal timeout) returns boolean {
        decimal started = nowSeconds();
        while true {
            lock {
                if self.items.length() > 0 {
                    self.interval = 0;
                    self.emptyChecks = 0;
                    return true;
                }
                if self.closed {
                    return false;
                }
            }
            decimal remaining = timeout < 0d ? 3600d : timeout - (nowSeconds() - started);
            if remaining <= 0d {
                return false;
            }
            decimal sleepFor = 0;
            lock {
                if self.interval == 0d {
                    self.interval = BASE_INTERVAL;
                } else {
                    [decimal, int] [longer, counted] = backOff(self.interval, self.emptyChecks, BASE_INTERVAL, CEILING_INTERVAL);
                    self.interval = longer;
                    self.emptyChecks = counted;
                }
                sleepFor = self.interval;
            }
            runtime:sleep(sleepFor < remaining ? sleepFor : remaining);
        }
    }

    isolated function takeAll() returns Message[] {
        lock {
            if self.items.length() == 0 {
                return [];
            }
            Message[] all = self.items.clone();
            self.items = [];
            return all.clone();
        }
    }

    isolated function close() {
        lock {
            self.closed = true;
        }
    }
}
