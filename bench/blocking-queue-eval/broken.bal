// Deliberately faulty: a `poll` queue that silently drops every 1000th message. It exists only to prove that the
// stress check can fail; a stress pass for a real strategy means something only if this one does not pass.
isolated class BrokenQueue {
    *WorkQueue;

    private final PollQueue inner = new;
    private int pushed = 0;

    isolated function push(Message message) {
        boolean drop = false;
        lock {
            self.pushed += 1;
            drop = self.pushed % 1000 == 0;
        }
        if !drop {
            self.inner.push(message);
        }
    }

    isolated function waitForWork(decimal timeout) returns boolean {
        return self.inner.waitForWork(timeout);
    }

    isolated function takeAll() returns Message[] {
        return self.inner.takeAll();
    }

    isolated function close() {
        self.inner.close();
    }
}
