// Copyright (c) 2026, Ayesh Almeida.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific
// language governing permissions and limitations under the License.

import ayesha/termui.text;

# Anything that can happen to the program: a key press, a resize, the result of an effect, a timer
# tick, or a message of the application's own. Messages are immutable, so they can safely cross from
# one strand to another.
public type Message anydata & readonly;

# The terminal's input has ended (end of file or the terminal went away).
#
# + kind - tells the message and command types apart
public type InputEnded record {|
    "inputEnded" kind = "inputEnded";
|};

# Reading the terminal failed.
#
# + kind - tells the message and command types apart
# + reason - what went wrong
public type InputFailed record {|
    "inputFailed" kind = "inputFailed";
    string reason;
|};

# An effect returned an error.
#
# + kind - tells the message and command types apart
# + reason - the error message
public type EffectFailed record {|
    "effectFailed" kind = "effectFailed";
    string reason;
|};

# Work that runs on its own strand and reports back only by sending messages. It must be an isolated
# function, so it cannot reach the program's state; the compiler checks this where an effect is
# passed in.
public type EffectFunction isolated function (Session session) returns error?;

# Ends the program.
#
# + kind - tells the message and command types apart
public type Quit record {|
    "quit" kind = "quit";
|};

# Starts an effect.
#
# + kind - tells the message and command types apart
# + run - the work to do
public type Effect record {|
    "effect" kind = "effect";
    EffectFunction run;
|};

# Writes finished paragraphs above the live region.
#
# + kind - tells the message and command types apart
# + paragraphs - the paragraphs
public type CommitProse record {|
    "commitProse" kind = "commitProse";
    text:Span[][] paragraphs;
|};

# Writes a finished block above the live region.
#
# + kind - tells the message and command types apart
# + lines - the lines of the block
public type CommitBlock record {|
    "commitBlock" kind = "commitBlock";
    text:Span[][] lines;
|};

# Sends a message again and again at an interval, until the program ends.
#
# + kind - tells the message and command types apart
# + interval - seconds between messages
# + message - the message to send
public type Every record {|
    "every" kind = "every";
    decimal interval;
    Message message;
|};

# Several commands at once.
#
# + kind - tells the message and command types apart
# + commands - the commands, carried out in order
public type Batch record {|
    "batch" kind = "batch";
    Command[] commands;
|};

# What the program asks the runtime to do after handling a message.
public type Command Quit|Effect|CommitProse|CommitBlock|Every|Batch;

# A command that ends the program.
#
# + return - the command
public isolated function quit() returns Command {
    return {kind: "quit"};
}

# A command that runs work on its own strand.
#
# + run - the work; results come back as messages sent through the session
# + return - the command
public isolated function effect(EffectFunction run) returns Command {
    return {kind: "effect", run};
}

# A command that commits paragraphs above the live region.
#
# + paragraphs - the paragraphs
# + return - the command
public isolated function commitProse(text:Span[][] paragraphs) returns Command {
    return {kind: "commitProse", paragraphs};
}

# A command that commits a block above the live region.
#
# + lines - the lines of the block
# + return - the command
public isolated function commitBlock(text:Span[][] lines) returns Command {
    return {kind: "commitBlock", lines};
}

# A command that sends a message repeatedly, for animations and clocks.
#
# + interval - seconds between messages
# + message - the message to send
# + return - the command
public isolated function every(decimal interval, Message message) returns Command {
    return {kind: "every", interval, message};
}

# A command that carries out several commands.
#
# + commands - the commands
# + return - the command
public isolated function batch(Command[] commands) returns Command {
    return {kind: "batch", commands};
}

isolated function inputEnded() returns Message {
    InputEnded & readonly message = {kind: "inputEnded"};
    return message;
}

isolated function inputFailed(string reason) returns Message {
    InputFailed & readonly message = {kind: "inputFailed", reason};
    return message;
}

isolated function effectFailed(string reason) returns Message {
    EffectFailed & readonly message = {kind: "effectFailed", reason};
    return message;
}
