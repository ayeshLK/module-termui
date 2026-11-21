import ayesha/termui;
import ayesha/termui.term;
import ballerina/file;
import ballerina/io;
import ballerina/test;

// Runs a list against a fake terminal that is 40 columns by 8 rows, after the keys have been typed.
function play(TodoList list, function (term:FakeTerminal) keys) returns string[]|error {
    term:FakeTerminal terminal = new (40, 8);
    keys(terminal);
    check termui:run(list, terminal);
    return terminal.screenLines();
}

function addItem(term:FakeTerminal terminal, string text) {
    terminal.pushText("a");
    terminal.pushText(text);
    terminal.pushKey("enter");
}

// region tests
@test:Config {}
function testAnItemCanBeAdded() returns error? {
    TodoList list = new;
    _ = check play(list, t => addItem(t, "buy milk"));
    test:assertEquals(list.items, [{text: "buy milk", done: false}]);
}

@test:Config {}
function testAnEmptyItemIsNotAdded() returns error? {
    TodoList list = new;
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushText("a");
        t.pushText("   ");
        t.pushKey("enter");
    });
    test:assertEquals(list.items.length(), 0);
}

@test:Config {}
function testEscapeGivesUpAnAdd() returns error? {
    TodoList list = new;
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushText("a");
        t.pushText("never");
        t.pushKey("escape");
    });
    test:assertEquals(list.items.length(), 0);
    test:assertFalse(list.adding);
}

@test:Config {}
function testSpaceTogglesTheSelectedItem() returns error? {
    TodoList list = new ([{text: "one"}, {text: "two"}]);
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushKey("down");
        t.pushText(" ");
    });
    test:assertEquals(list.items, [{text: "one", done: false}, {text: "two", done: true}]);
}

@test:Config {}
function testDeletingTheLastItemMovesTheSelectionUp() returns error? {
    TodoList list = new ([{text: "one"}, {text: "two"}]);
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushKey("down");
        t.pushText("d");
    });
    test:assertEquals(list.items, [{text: "one", done: false}]);
    test:assertEquals(list.selected, 0);
}

@test:Config {}
function testDeletingTheOnlyItemLeavesAnEmptyList() returns error? {
    TodoList list = new ([{text: "one"}]);
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushText("d");
        t.pushText("d");
        t.pushText(" ");
    });
    test:assertEquals(list.items.length(), 0);
    test:assertEquals(list.selected, 0);
}

@test:Config {}
function testTheSelectionStaysInRange() returns error? {
    TodoList list = new ([{text: "one"}, {text: "two"}]);
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushKey("up");
        t.pushKey("down");
        t.pushKey("down");
        t.pushKey("down");
    });
    test:assertEquals(list.selected, 1);
}

@test:Config {}
function testQuitLeavesTheListInTheScrollback() returns error? {
    TodoList list = new ([{text: "one", done: true}, {text: "two"}]);
    string[] lines = check play(list, function(term:FakeTerminal t) {
        t.pushText("q");
    });
    test:assertEquals(lines.slice(0, 2), ["[x] one", "[ ] two"]);
}

@test:Config {}
function testItemsSurviveASaveAndALoad() returns error? {
    string dir = check file:createTempDir();
    string path = check file:joinPath(dir, "todos.json");
    Item[] items = [{text: "one", done: true}, {text: "two"}];
    check saveItems(items, path);
    test:assertEquals(check loadItems(path), items);
    check file:remove(dir, file:RECURSIVE);
}

@test:Config {}
function testAMissingFileIsAnEmptyList() returns error? {
    string dir = check file:createTempDir();
    test:assertEquals(check loadItems(check file:joinPath(dir, "none.json")), []);
    check file:remove(dir, file:RECURSIVE);
}

@test:Config {}
function testAFileThatIsNotAListIsAnError() returns error? {
    string dir = check file:createTempDir();
    string path = check file:joinPath(dir, "bad.json");
    check io:fileWriteString(path, "{\"oops\": 1}");
    Item[]|error result = loadItems(path);
    test:assertTrue(result is error);
    test:assertEquals(check io:fileReadString(path), "{\"oops\": 1}");
    check file:remove(dir, file:RECURSIVE);
}
// endregion tests
