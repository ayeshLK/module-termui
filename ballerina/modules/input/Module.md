## Overview

A text input for a terminal program, in the shape the runtime uses: a `LineEditor` holds a text and a
cursor, the program hands it the key and paste events it receives, and draws what `render` returns. It
holds no terminal and needs none, so it is tested like the rest of the package.

- **Editing.** Typing inserts at the cursor. Backspace and Delete, moving by character, by word and
  to the start or end of the line, deleting a word or the rest of a line.
- **Multi-line.** Enter submits; Alt+Enter or Ctrl+J inserts a line break, and Up and Down move
  between lines. Create the editor with `multiline = false` for a single line.
- **Paste.** Pasted text goes in as one edit and never submits. Line breaks are kept (or turned into
  spaces in a single-line editor), and tabs become four spaces.
- **History.** Submissions are remembered; Up and Down at the first or last line walk through them and
  keep the unsent draft. `history()` returns them so the program can save them between runs.
- **Drawing.** `render(width, prompt)` returns the rows as styled text: the prompt on the first row,
  later rows indented under it, long lines wrapped by display width (a wide character is never split),
  and the cursor as the character under it in reverse video.
- **Keys the editor does not use** (Ctrl+C, Escape, Tab, Ctrl+D on empty text, anything else) come
  back as `ignored`, for the program to act on.

`handleEvent` returns `edited` when the editor used the event, `ignored` when it did not, or a
`Submitted` with the text when Enter was pressed; the editor is then empty again.

### Keys

| Action | Keys |
|---|---|
| Submit | Enter |
| Line break (multi-line) | Alt+Enter, Ctrl+J |
| Left, right | arrows, Ctrl+B, Ctrl+F |
| Word left, word right | Alt+B, Alt+F, Ctrl+arrows, Alt+arrows |
| Start, end of line | Home, Ctrl+A, End, Ctrl+E |
| Delete back, forward | Backspace, Delete, Ctrl+D (when there is text) |
| Delete word back, forward | Ctrl+W, Alt+D |
| Delete to start, end of line | Ctrl+U, Ctrl+K |
| Up, down | between lines; on the first or last line, through the history |

Shift+Enter cannot be told from Enter on most terminals, which is why a line break is Alt+Enter or
Ctrl+J. On macOS Terminal and iTerm2 the Option key must be set to send Escape sequences ("Use
Option as Meta key" in Terminal, "Esc+" for the Option key in iTerm2) for the Alt shortcuts to work.

### Limits

A character is a code point with its combining marks. Longer sequences, such as emoji joined with a
zero-width joiner, take several cursor steps. There is no undo, selection or mouse support. The
cursor is drawn as a reverse-video cell, not as the terminal's own cursor.

### Stability

Supported: `LineEditor`, `EditResult`, `Submitted` and the key bindings above. A new key may be added in
a minor release; an existing binding is kept for the whole major version.

### Example

```ballerina
import ayesha/termui;
import ayesha/termui.input;
import ayesha/termui.term;
import ayesha/termui.text;

class Prompt {
    *termui:Program;

    input:LineEditor editor = new (history = ["hello"]);
    int width = 80;

    public function update(termui:Message message) returns termui:Command? {
        if message is term:ResizeEvent {
            self.width = message.width; // the first message is the size, so the width is known from the first view
        }
        if message is term:KeyEvent|term:PasteEvent {
            input:EditResult result = self.editor.handleEvent(message);
            if result is input:Submitted {
                return termui:commitProse([[{text: "you said: " + result.text}]]);
            }
            if result == "ignored" && message is term:KeyEvent && message.ctrl && message.key == "c" {
                return termui:quit();
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return self.editor.render(self.width);
    }
}

public function main() returns error? {
    termui:Interface ui = new (term:detectEnvironment());
    check ui.run(new Prompt());
}
```

Type a line and press Enter to see it committed above the prompt; Up recalls `hello`; Ctrl+C quits.
