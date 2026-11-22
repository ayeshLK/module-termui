import ballerina/io;
import ballerina/jballerina.java;

// Control strategy: `java.util.concurrent.LinkedBlockingQueue`, called through `jballerina.java` interop with no
// Java code of our own. It shows what a plain JDK blocking queue costs, so any pipe result can be read against it.
// The JDK queue has no `close`, so `close` puts a marker message that wakes every waiter.
const string LBQ = "java.util.concurrent.LinkedBlockingQueue";

isolated function newLbq() returns handle = @java:Constructor {
    'class: LBQ,
    paramTypes: []
} external;

isolated function lbqPut(handle queue, Message message) returns error? = @java:Method {
    name: "put",
    'class: LBQ,
    paramTypes: ["java.lang.Object"]
} external;

// poll(timeout, unit): the oldest message, or nil when none arrived in time. Messages are never nil, so nil is "none".
isolated function lbqPollTimed(handle queue, int amount, handle unit) returns Message|error = @java:Method {
    name: "poll",
    'class: LBQ,
    paramTypes: ["long", "java.util.concurrent.TimeUnit"]
} external;

isolated function lbqPoll(handle queue) returns Message = @java:Method {
    name: "poll",
    'class: LBQ,
    paramTypes: []
} external;

// `put` on an unbounded queue only fails if the thread is interrupted; that is reported, not ignored.
isolated function putMessage(handle queue, Message message) {
    error? failed = lbqPut(queue, message);
    if failed is error {
        io:println(string `UNEXPECTED jdk put error: ${failed.message()}`);
    }
}

isolated function millisecondsUnit() returns handle = @java:FieldGet {
    name: "MILLISECONDS",
    'class: "java.util.concurrent.TimeUnit"
} external;

type ClosedMarker record {|
    boolean jdkQueueClosed;
|};

isolated function closedMarker() returns Message {
    ClosedMarker marker = {jdkQueueClosed: true};
    return marker.cloneReadOnly();
}

isolated class JdkQueue {
    *WorkQueue;

    private final handle queue = newLbq();
    private final handle unit = millisecondsUnit();
    private [Message]? held = ();
    private boolean closed = false;

    isolated function push(Message message) {
        putMessage(self.queue, message);
    }

    isolated function waitForWork(decimal timeout) returns boolean {
        lock {
            if self.held is [Message] {
                return true;
            }
            if self.closed {
                return false;
            }
        }
        decimal started = nowSeconds();
        while true {
            decimal remaining = timeout < 0d ? 3600d : timeout - (nowSeconds() - started);
            if remaining <= 0d {
                return false;
            }
            int millis = <int>(remaining * 1000).ceiling();
            Message|error got = lbqPollTimed(self.queue, millis, self.unit);
            if got is error {
                return false;
            }
            if got is ClosedMarker {
                self.markClosed();
                putMessage(self.queue, closedMarker()); // wake the next waiter too
                return false;
            }
            if got is () {
                continue;
            }
            Message received = got;
            lock {
                self.held = [received];
            }
            return true;
        }
    }

    private isolated function markClosed() {
        lock {
            self.closed = true;
        }
    }

    isolated function takeAll() returns Message[] {
        Message[] all = self.takeHeld();
        while true {
            Message got = lbqPoll(self.queue);
            if got is () {
                break;
            }
            if got is ClosedMarker {
                self.markClosed();
                putMessage(self.queue, closedMarker());
                break;
            }
            all.push(got);
        }
        return all;
    }

    private isolated function takeHeld() returns Message[] {
        lock {
            [Message]? first = self.held;
            self.held = ();
            if first is [Message] {
                Message[] one = [];
                one.push(first[0]);
                return one.clone();
            }
        }
        return [];
    }

    isolated function close() {
        putMessage(self.queue, closedMarker());
    }
}
