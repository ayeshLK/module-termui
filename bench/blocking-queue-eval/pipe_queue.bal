import ballerina/io;
import xlibb/pipe;

const string PIPE_TIMEOUT_TEXT = "Operation has timed out";

// `xlibb/pipe` as the queue. The consumer blocks on `consume` for the first message (a negative timeout waits
// without limit) and drains the rest with `consume(0)`, which returns a timeout error when the pipe is empty.
// The message `waitForWork` received is kept until `takeAll` hands it out, so `takeAll` returns oldest first.
isolated class PipeQueue {
    *WorkQueue;

    private final pipe:Pipe pipe;
    private [Message]? held = ();

    isolated function init(int capacity) {
        self.pipe = new (capacity);
    }

    isolated function push(Message message) {
        pipe:Error? failed = self.pipe.produce(message, -1);
        if failed is pipe:Error {
            noteUnexpected(failed);
        }
    }

    isolated function waitForWork(decimal timeout) returns boolean {
        lock {
            if self.held is [Message] {
                return true;
            }
        }
        Message|pipe:Error got = self.pipe.consume(timeout < 0d ? -1 : timeout, Message);
        if got is pipe:Error {
            noteUnexpected(got);
            return false;
        }
        Message received = got; // declared as Message, so it may enter the lock
        lock {
            self.held = [received];
        }
        return true;
    }

    isolated function takeAll() returns Message[] {
        Message[] all = self.takeHeld();
        while true {
            Message|pipe:Error got = self.pipe.consume(0, Message);
            if got is pipe:Error {
                noteUnexpected(got);
                break;
            }
            all.push(got);
        }
        return all;
    }

    // The message `waitForWork` received, if it is still waiting to be handed out.
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
        pipe:Error? failed = self.pipe.immediateClose();
        if failed is pipe:Error {
            noteUnexpected(failed);
        }
    }
}

// A timeout is how an empty pipe answers `consume(0)`, and a closed pipe is how a closed queue answers; anything
// else would be a fault, so it is printed once per distinct message.
isolated string[] seenUnexpected = [];

isolated function noteUnexpected(pipe:Error failure) {
    string text = failure.message();
    if text == PIPE_TIMEOUT_TEXT || text.includes("closed") || text.includes("close") {
        return;
    }
    lock {
        if seenUnexpected.indexOf(text) is () {
            seenUnexpected.push(text);
            io:println(string `UNEXPECTED pipe error: ${text}`);
        }
    }
}
