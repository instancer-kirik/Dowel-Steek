module editor;

import dlangui;
import dlangui.dialogs.dialog;
import dlangui.widgets.editors;
import dlangui.core.events;
import dlangui.core.types;
import dlangui.widgets.widget;
import dlangui.core.signals;
import note;
import std.conv : to;
import std.datetime;
import core.thread;
import std.regex;
import std.typecons : tuple;
import std.algorithm : map, filter, splitter;
import std.array : array, join;
import dlangui.dialogs.msgbox;
import dlangui.core.stdaction;  // For StandardAction
import dlangui.widgets.styles;  // For TextFlag
import std.path : buildPath;
import std.file : tempDir;
import std.stdio : File;
import dlangui.core.types : Point, Rect;  // For Point type
import dlangui.widgets.widget : Widget, State;  // For Widget and State

// Action for undo/redo
private struct EditAction {
    string beforeText;
    string afterText;
    int beforePos;
    int afterPos;
}

// Add Touch to EventType enum if not present
enum EventType {
    Touch = 100,  // Use a unique number that doesn't conflict with existing EventType values
    AutoSave = 1
}

class MarkdownEditor : Dialog {
    private EditBox contentEdit;
    private TextWidget preview;
    private Note* currentNote;
    private bool isDirty;
    private Thread autoSaveThread;
    private bool isAutoSaving;
    private SysTime lastEdit;
    private EditAction[] undoStack;
    private EditAction[] redoStack;
    private string lastContent;
    private HorizontalLayout touchToolbar;
    private bool isSelectionMode;
    private Point touchStart;
    
    // Keyboard shortcuts
    enum Shortcut {
        Save = KeyCode.KEY_S | KeyFlag.Control,
        Preview = KeyCode.KEY_P | KeyFlag.Control,
        Help = KeyCode.KEY_H | KeyFlag.Control,
        NewLine = KeyCode.RETURN,
        Indent = KeyCode.TAB,
        Undo = KeyCode.KEY_Z | KeyFlag.Control,
        Redo = KeyCode.KEY_Y | KeyFlag.Control,
    }
    
    this(Window parent, Note* note) {
        super(UIString.fromRaw("Edit Note"d), parent, DialogFlag.Resizable, 800, 600);
        
        try {
            // Initialize fields
            currentNote = note;
            touchStart = Point(-1, -1);  // Invalid point to start
            
            // Create main layout
            auto mainLayout = new VerticalLayout();
            mainLayout.padding(Rect(10, 10, 10, 10));
            mainLayout.layoutWidth = FILL_PARENT;
            mainLayout.layoutHeight = FILL_PARENT;
            
            // Add toolbar with keyboard shortcut hints
            auto toolbar = new HorizontalLayout();
            auto saveBtn = new Button(null, "Save (Ctrl+S)"d);
            saveBtn.click = &onSave;
            
            auto previewBtn = new Button(null, "Toggle Preview (Ctrl+P)"d);
            previewBtn.click = &onTogglePreview;
            
            auto helpBtn = new Button(null, "Shortcuts (Ctrl+H)"d);
            helpBtn.click = &onShowShortcuts;
            
            auto undoBtn = new Button(null, "Undo (Ctrl+Z)"d);
            undoBtn.click = &onUndo;
            auto redoBtn = new Button(null, "Redo (Ctrl+Y)"d);
            redoBtn.click = &onRedo;
            
            toolbar.addChild(saveBtn);
            toolbar.addChild(previewBtn);
            toolbar.addChild(helpBtn);
            toolbar.addChild(undoBtn);
            toolbar.addChild(redoBtn);
            
            // Create split layout for editor and preview
            auto splitLayout = new HorizontalLayout();
            splitLayout.layoutWidth = FILL_PARENT;
            splitLayout.layoutHeight = FILL_PARENT;
            
            // Editor pane
            auto editorPane = new VerticalLayout();
            editorPane.layoutWidth = FILL_PARENT;
            editorPane.layoutHeight = FILL_PARENT;
            
            // Title field
            auto titleLayout = new HorizontalLayout();
            auto titleEdit = new EditLine(null);
            titleEdit.text = currentNote.title.to!dstring;
            setupTitleEdit(titleEdit);
            titleLayout.addChild(titleEdit);
            
            // Tags field
            auto tagsLayout = new HorizontalLayout();
            auto tagsEdit = new EditLine(null);
            tagsEdit.text = currentNote.tags.join(", ").to!dstring;
            setupTagsEdit(tagsEdit);
            tagsLayout.addChild(tagsEdit);
            
            // Content editor
            contentEdit = new EditBox(null);
            contentEdit.text = currentNote.content.to!dstring;
            setupContentEdit();
            contentEdit.fontFamily = FontFamily.MonoSpace;
            contentEdit.backgroundColor = 0xFFFFFF;
            
            editorPane.addChild(titleLayout);
            editorPane.addChild(tagsLayout);
            editorPane.addChild(contentEdit);
            
            // Add touch-friendly toolbar
            touchToolbar = new HorizontalLayout();
            touchToolbar.layoutWidth = FILL_PARENT;
            touchToolbar.padding(Rect(5, 5, 5, 5));
            
            // Add touch controls
            auto cursorLeftBtn = new Button(null, "←"d);
            cursorLeftBtn.click = &onCursorLeft;
            cursorLeftBtn.minWidth = 50;  // Larger touch target
            
            auto cursorRightBtn = new Button(null, "→"d);
            cursorRightBtn.click = &onCursorRight;
            cursorRightBtn.minWidth = 50;
            
            auto selectBtn = new Button(null, "Select"d);
            selectBtn.click = &onToggleSelect;
            
            auto insertLinkBtn = new Button(null, "Link"d);
            insertLinkBtn.click = &onInsertLink;
            
            touchToolbar.addChild(cursorLeftBtn);
            touchToolbar.addChild(cursorRightBtn);
            touchToolbar.addChild(selectBtn);
            touchToolbar.addChild(insertLinkBtn);
            
            // Add touch toolbar to layout
            editorPane.addChild(touchToolbar);
            
            // Preview pane
            setupPreview();
            
            splitLayout.addChild(editorPane);
            splitLayout.addChild(preview);
            
            // Add all to main layout
            mainLayout.addChild(toolbar);
            mainLayout.addChild(splitLayout);
            
            // Set dialog content
            mainLayout.layoutWidth = FILL_PARENT;
            mainLayout.layoutHeight = FILL_PARENT;
            this.addChild(mainLayout);  // Dialog inherits from VerticalLayout, so we add the layout as a child
            
            // Use contentWidget for Dialog class
            setupContentEdit();        // Update preview
            updatePreview();
            
            // Start auto-save thread
            startAutoSave();
            
            // Initialize undo system
            lastContent = currentNote.content;
            
            // Enhance content editor for touch
            contentEdit.minHeight = 30;
            contentEdit.fontSize = 16;
            
        } catch (Exception e) {
            Log.e("Error in editor initialization: ", e.msg);
            throw e;
        }
    }
    
    ~this() {
        stopAutoSave();
    }
    
    private void startAutoSave() {
        if (isAutoSaving) return;
        
        isAutoSaving = true;
        autoSaveThread = new Thread({
            while (isAutoSaving) {
                if (isDirty && Clock.currTime - lastEdit > dur!"seconds"(3)) {
                    // Use window for event posting
                    if (auto window = window)  // Get window from Dialog
                        window.postEvent(new CustomEvent(EventType.AutoSave));
                }
                Thread.sleep(dur!"seconds"(1));
            }
        });
        autoSaveThread.isDaemon = true;
        autoSaveThread.start();
    }
    
    private void stopAutoSave() {
        isAutoSaving = false;
        if (autoSaveThread) {
            autoSaveThread.join();
            autoSaveThread = null;
        }
    }
    
    override bool onEvent(CustomEvent event) {
        if (event.id == CUSTOM_RUNNABLE) {
            if (auto runnable = cast(RunnableEvent)event) {
                runnable.run();
                return true;
            }
        }
        return super.onEvent(event);
    }
    
    private bool onEditorKeyEvent(Widget source, KeyEvent event) {
        if (event.action == KeyAction.KeyDown) {
            // Handle keyboard shortcuts
            if (event.flags & KeyFlag.Control) {
                switch (event.keyCode) {
                    case KeyCode.KEY_Z:
                        return onUndo(null);
                    case KeyCode.KEY_Y:
                        return onRedo(null);
                    case KeyCode.KEY_B:
                        insertMarkdownSyntax("**", "**");
                        return true;
                    case KeyCode.KEY_I:
                        insertMarkdownSyntax("*", "*");
                        return true;
                    case KeyCode.KEY_K:
                        insertLink();
                        return true;
                    default:
                        break;
                }
            }
            
            // Handle syntax highlighting
            updateSyntaxHighlighting();
        }
        return false;
    }
    
    private void updateSyntaxHighlighting() {
        auto text = contentEdit.text.to!string;
        TextPosition pos = contentEdit.caretPos;
        
        // Reset all colors
        contentEdit.backgroundColor = 0xFFFFFF;
        
        // Define markdown patterns with more precise regex
        static immutable patterns = [
            // Headers (# to ######)
            tuple(r"^#{1,6}\s.*$", 0x0000FF),
            
            // Code blocks with language specification
            tuple(r"```[a-zA-Z0-9]*\n[\s\S]*?```", 0x008000),
            
            // Inline code
            tuple(r"`[^`\n]+`", 0x008000),
            
            // Bold with both ** and __
            tuple(r"(\*\*|__)[^\*\n]+\1", 0xFF0000),
            
            // Italic with both * and _
            tuple(r"(\*|_)[^\*\n]+\1", 0x800080),
            
            // Links [text](url)
            tuple(r"\[([^\]]+)\]\(([^\)]+)\)", 0x0000FF),
            
            // Lists
            tuple(r"^\s*[\*\-\+]\s.*$", 0x800000),
            tuple(r"^\s*\d+\.\s.*$", 0x800000),
            
            // Blockquotes
            tuple(r"^>\s.*$", 0x008080),
            
            // Tables
            tuple(r"^\|[^\n]+\|$", 0x800080),
            
            // Task lists
            tuple(r"^\s*\-\s\[[x\s]\].*$", 0x800000)
        ];
        
        // Apply highlighting
        foreach (pattern; patterns) {
            try {
                auto r = regex(pattern[0], "g");
                foreach (m; text.matchAll(r)) {
                    contentEdit.textColor = pattern[1];
                }
            } catch (Exception e) {
                // Skip invalid patterns
                continue;
            }
        }
        
        // Restore cursor position
        contentEdit.setCaretPos(pos.line, pos.pos);
    }
    
    private void saveChanges() {
        if (!isDirty) return;
        
        // Save note changes
        currentNote.modified = Clock.currTime();
        isDirty = false;
    }
    
    private bool onShowShortcuts(Widget w) {
        auto msg = "Keyboard Shortcuts:\n\n" ~
                  "Ctrl+S: Save\n" ~
                  "Ctrl+P: Toggle Preview\n" ~
                  "Ctrl+H: Show This Help\n" ~
                  "Tab: Indent\n" ~
                  "Shift+Tab: Unindent\n" ~
                  "Ctrl+B: Bold\n" ~
                  "Ctrl+I: Italic\n" ~
                  "Ctrl+K: Insert Link\n" ~
                  "Ctrl+`: Code Block\n" ~
                  "Ctrl+Z: Undo\n" ~
                  "Ctrl+Y: Redo";
        
        window.showMessageBox(
            UIString.fromRaw("Keyboard Shortcuts"d),
            UIString.fromRaw(msg.to!dstring),
            [ACTION_OK]  // Use predefined ACTION_OK constant
        );
        return true;
    }
    
    private bool onSave(Widget w) {
        if (!isDirty) return true;
        
        // TODO: Save note changes
        isDirty = false;
        close(new Action(StandardAction.Ok));  // Use StandardAction.Ok
        return true;
    }
    
    private bool onTogglePreview(Widget w) {
        preview.visibility = preview.visibility == Visibility.Visible ? 
            Visibility.Gone : Visibility.Visible;
        if (preview.visibility == Visibility.Visible) {
            updatePreview();
        }
        return true;
    }
    
    private bool onTitleChanged(EditableContent source) {
        currentNote.title = source.text.to!string;
        isDirty = true;
        return true;
    }
    
    private bool onTagsChanged(EditableContent source) {
        import std.string : split, strip;
        currentNote.tags = source.text.to!string
            .split(",")
            .map!(t => t.strip)
            .filter!(t => t.length > 0)
            .array;
        isDirty = true;
        return true;
    }
    
    private bool onContentChanged(EditableContent source) {
        auto newContent = source.text.to!string;
        
        // Add to undo stack if significant change
        if (newContent != lastContent) {
            undoStack ~= EditAction(
                lastContent,
                newContent,
                contentEdit.caretPos.pos,
                contentEdit.caretPos.pos
            );
            lastContent = newContent;
            redoStack.length = 0; // Clear redo stack on new change
        }
        
        currentNote.content = newContent;
        isDirty = true;
        lastEdit = Clock.currTime();
        
        if (preview.visibility) {
            updatePreview();
        }
        
        return true;
    }
    
    private bool onUndo(Widget w) {
        if (undoStack.length == 0) return true;
        
        auto action = undoStack[$-1];
        undoStack.length--;
        
        redoStack ~= EditAction(
            contentEdit.text.to!string,
            action.beforeText,
            contentEdit.caretPos.pos,
            action.beforePos
        );
        
        contentEdit.text = action.beforeText.to!dstring;
        contentEdit.setCaretPos(0, action.beforePos);
        updateSyntaxHighlighting();
        return true;
    }
    
    private bool onRedo(Widget w) {
        if (redoStack.length == 0) return true;
        
        auto action = redoStack[$-1];
        redoStack.length--;
        
        undoStack ~= EditAction(
            contentEdit.text.to!string,
            action.beforeText,
            contentEdit.caretPos.pos,
            action.beforePos
        );
        
        contentEdit.text = action.beforeText.to!dstring;
        contentEdit.setCaretPos(0, action.beforePos);
        updateSyntaxHighlighting();
        return true;
    }
    
    private void updatePreview() {
        import std.process : execute;
        
        // Save current content to temp file
        import std.file : write, remove;
        auto tempFile = buildPath(tempDir, "preview.md");
        write(tempFile, currentNote.toMarkdown());
        
        // Use pandoc to convert markdown to HTML
        auto result = execute(["pandoc", "-f", "markdown", "-t", "html", tempFile]);
        remove(tempFile);
        
        if (result.status == 0) {
            preview.text = result.output.to!dstring;
        } else {
            preview.text = "Error generating preview"d;
        }
    }
    
    private void insertMarkdownSyntax(string prefix, string suffix) {
        auto text = contentEdit.text.to!string;
        auto pos = contentEdit.caretPos;
        
        if (contentEdit.selectionRange.empty) {
            // No selection, just insert at cursor
            auto newText = text[0..pos.pos] ~ prefix ~ suffix ~ text[pos.pos..$];
            contentEdit.text = newText.to!dstring;
            contentEdit.setCaretPos(pos.line, pos.pos + cast(int)prefix.length);
        } else {
            // Wrap selection
            auto sel = contentEdit.selectionRange;
            auto selText = text[sel.start.pos..sel.end.pos];
            auto newText = text[0..sel.start.pos] ~ prefix ~ selText ~ 
                suffix ~ text[sel.end.pos..$];
            contentEdit.text = newText.to!dstring;
            contentEdit.setCaretPos(sel.start.line, sel.start.pos);
            contentEdit.selectionRange = TextRange(
                TextPosition(sel.start.line, sel.start.pos),
                TextPosition(sel.end.line, sel.end.pos + cast(int)(prefix.length + suffix.length))
            );
        }
    }
    
    private void insertLink() {
        auto text = contentEdit.text.to!string;
        auto pos = contentEdit.caretPos;
        auto sel = contentEdit.selectionRange;
        
        if (sel.empty) {
            insertMarkdownSyntax("[", "](url)");
        } else {
            auto selectedText = text[sel.start.pos..sel.end.pos];
            auto newText = text[0..sel.start.pos] ~ "[" ~ selectedText ~ 
                "](url)" ~ text[sel.end.pos..$];
            contentEdit.text = newText.to!dstring;
            contentEdit.setCaretPos(sel.end.line, sel.end.pos + 2);
            contentEdit.selectionRange = TextRange(
                TextPosition(sel.end.line, sel.end.pos + 2),
                TextPosition(sel.end.line, sel.end.pos + 7)
            );
        }
    }
    
    private void setupContentEdit() {
        contentEdit.contentChange = (EditableContent source) {
            onContentChanged(source);
        };
        
        contentEdit.keyEvent = (Widget source, KeyEvent event) {
            return onEditorKeyEvent(source, event);
        };
    }
    
    private void setupTitleEdit(EditLine titleEdit) {
        titleEdit.contentChange = (EditableContent source) {
            onTitleChanged(source);
        };
    }
    
    private void setupTagsEdit(EditLine tagsEdit) {
        tagsEdit.contentChange = (EditableContent source) {
            onTagsChanged(source);
        };
    }
    
    private void setupPreview() {
        preview = new TextWidget(null, ""d);
        preview.fontFamily = FontFamily.SansSerif;
        preview.textFlags = TextFlag.init;  // Use correct enum values from dlangui
        preview.visibility = Visibility.Gone;
        preview.backgroundColor = 0xFAFAFA;
    }
    
    private void showError(dstring message) {
        window.showMessageBox(
            UIString.fromRaw("Error"d),
            UIString.fromRaw(message),
            [ACTION_OK]  // Use predefined ACTION_OK constant
        );
    }
    
    private void setCaretPosition(int line, int col) {
        contentEdit.setCaretPos(line, col);  // Use setCaretPos instead of assigning to caretPos
    }
    
    private void setTextColor(int pos, int len, uint color) {
        contentEdit.textColor = color;
    }
    
    override bool onMouseEvent(MouseEvent event) {
        if (event.action == MouseAction.ButtonDown) {
            touchStart = Point(event.x, event.y);
            if (!isSelectionMode) {
                // Just use raw coordinates divided by a reasonable font size estimate
                int line = event.y / 20;  // Assuming ~20 pixels per line
                int col = event.x / 10;   // Assuming ~10 pixels per character
                contentEdit.setCaretPos(line, col);
                return true;
            }
        } else if (event.action == MouseAction.Move && event.button) {
            if (isSelectionMode && touchStart.x >= 0) {
                // Calculate rough positions
                int startLine = touchStart.y / 20;
                int startCol = touchStart.x / 10;
                int endLine = event.y / 20;
                int endCol = event.x / 10;
                
                // First set caret to start
                contentEdit.setCaretPos(startLine, startCol);
                
                // Then move to end position to create selection
                contentEdit.setCaretPos(endLine, endCol, true);  // true = select
            }
        }
        return super.onMouseEvent(event);
    }
    
    private bool onCursorLeft(Widget w) {
        auto pos = contentEdit.caretPos;
        if (pos.pos > 0) {
            contentEdit.setCaretPos(pos.line, pos.pos - 1);
        } else if (pos.line > 0) {
            // Move to end of previous line
            auto prevLine = contentEdit.content.lines[pos.line - 1];
            contentEdit.setCaretPos(pos.line - 1, cast(int)prevLine.length);  // Cast length to int
        }
        return true;
    }
    
    private bool onCursorRight(Widget w) {
        auto pos = contentEdit.caretPos;
        auto currentLine = contentEdit.content.lines[pos.line];
        if (pos.pos < cast(int)currentLine.length) {  // Cast length to int
            contentEdit.setCaretPos(pos.line, pos.pos + 1);
        } else if (pos.line < contentEdit.content.lines.length - 1) {
            // Move to start of next line
            contentEdit.setCaretPos(pos.line + 1, 0);
        }
        return true;
    }
    
    private bool onToggleSelect(Widget w) {
        isSelectionMode = !isSelectionMode;
        w.setState(cast(uint)(isSelectionMode ? State.Selected : State.Normal));  // Cast State to uint
        return true;
    }
    
    private bool onInsertLink(Widget w) {
        insertLink();
        return true;
    }
}

private enum UserEventType {
    AutoSave = 1
} 

 