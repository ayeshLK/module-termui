import ballerina/time;

// The message shapes of the runtime, copied from termui (this harness does not depend on the package).
public type KeyEvent record {|
    "key" kind = "key";
    string key;
    boolean ctrl = false;
    boolean alt = false;
|};

public type ResizeEvent record {|
    "resize" kind = "resize";
    int width;
    int height;
|};

public type PasteEvent record {|
    "paste" kind = "paste";
    string text;
|};

// Workload messages: a send time for latency, and a producer and sequence number for the stress check.
public type Stamp record {|
    "stamp" kind = "stamp";
    decimal sentAt;
|};

public type Numbered record {|
    "numbered" kind = "numbered";
    int producer;
    int n;
|};

public type Message anydata & readonly;

// What every strategy provides. One consumer calls `waitForWork` and `takeAll`; any strand calls `push`.
public type WorkQueue isolated object {
    // Adds a message. May block when a strategy has a bound and it is full. Never fails: a closed queue drops it.
    isolated function push(Message message);

    // Blocks until at least one message can be taken, the timeout (seconds, negative for none) passes, or the
    // queue is closed. Returns true when a message can be taken.
    isolated function waitForWork(decimal timeout) returns boolean;

    // Takes every message that is available, oldest first, without blocking.
    isolated function takeAll() returns Message[];

    // Ends the queue and wakes whoever is blocked on it.
    isolated function close();
};

isolated function nowSeconds() returns decimal {
    return time:monotonicNow();
}

isolated function keyMessage(string key) returns Message {
    KeyEvent event = {key};
    return event.cloneReadOnly();
}

isolated function resizeMessage() returns Message {
    ResizeEvent event = {width: 100, height: 30};
    return event.cloneReadOnly();
}

isolated function pasteMessage() returns Message {
    string text = "";
    foreach int i in 0 ..< 512 {
        text += "01234567";
    }
    PasteEvent event = {text}; // 4 KB
    return event.cloneReadOnly();
}
