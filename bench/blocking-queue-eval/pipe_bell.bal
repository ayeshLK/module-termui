import xlibb/pipe;

// The lock-guarded list stays the queue (its non-blocking `takeAll` is the proven one); a small `xlibb/pipe` is only
// a wake-up signal. The consumer, under the same lock that finds the list empty, records that it is going to sleep;
// a producer that sees that flag rings the bell once, so there is at most one token in the bell per sleep (plus at
// most one stale token left by a sleep that timed out as a producer rang) and a producer never blocks on it. A stale
// token only causes one spurious wake-up, after which the consumer looks at the list again.
isolated class PipeBellQueue {
    *WorkQueue;

    private Message[] items = [];
    private boolean closed = false;
    private boolean sleeping = false;
    private final pipe:Pipe bell;

    isolated function init() {
        self.bell = new (2);
    }

    isolated function push(Message message) {
        boolean ring = false;
        lock {
            if self.closed {
                return;
            }
            self.items.push(message);
            ring = self.sleeping;
            self.sleeping = false;
        }
        if ring {
            pipe:Error? failed = self.bell.produce(true, -1);
            if failed is pipe:Error {
                noteUnexpected(failed);
            }
        }
    }

    isolated function waitForWork(decimal timeout) returns boolean {
        decimal started = nowSeconds();
        while true {
            lock {
                if self.items.length() > 0 {
                    return true;
                }
                if self.closed {
                    return false;
                }
                self.sleeping = true;
            }
            decimal remaining = timeout < 0d ? -1d : timeout - (nowSeconds() - started);
            if timeout >= 0d && remaining <= 0d {
                lock {
                    self.sleeping = false;
                }
                lock {
                    return self.items.length() > 0;
                }
            }
            boolean|pipe:Error rang = self.bell.consume(remaining, boolean);
            lock {
                self.sleeping = false;
            }
            if rang is pipe:Error {
                noteUnexpected(rang);
                lock {
                    if self.closed {
                        return self.items.length() > 0;
                    }
                }
            }
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
        pipe:Error? failed = self.bell.immediateClose();
        if failed is pipe:Error {
            noteUnexpected(failed);
        }
    }
}
