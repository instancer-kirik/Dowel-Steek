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
import std.algorithm : map, filter;
import std.array : array, join;

// Action for undo/redo
private struct EditAction {
    string beforeText;
    string afterText;
    int beforePos;
    int afterPos;
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
        super(UIString.fromRaw("Edit Note"d), parent);
        currentNote = note;
        
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
        
        // Preview pane
        preview = new TextWidget(null, ""d);
        preview.fontFamily = FontFamily.SansSerif;
        preview.textFlags = TextFlag.MultiLine | TextFlag.WordWrap;
        preview.backgroundColor = 0xFAFAFA;
        preview.visible = false;
        
        splitLayout.addChild(editorPane);
        splitLayout.addChild(preview);
        
        // Add all to main layout
        mainLayout.addChild(toolbar);
        mainLayout.addChild(splitLayout);
        
        // Set dialog content
        contentWidget = mainLayout;
        
        // Update preview
        updatePreview();
        
        // Start auto-save thread
        startAutoSave();
        
        // Initialize undo system
        lastContent = currentNote.content;
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
                    Window.postEvent(this, new RunnableEvent(
                        CUSTOM_RUNNABLE,
                        this,
                        &saveChanges
                    ));
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
        auto pos = contentEdit.caretPos;
        
        // Reset all colors
        contentEdit.setTextColor(0, text.length, 0x000000);
        
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
                    contentEdit.setTextColor(m.pre.length, m.hit.length, pattern[1]);
                }
            } catch (Exception e) {
                // Skip invalid patterns
                continue;
            }
        }
        
        // Restore cursor position
        contentEdit.caretPos = pos;
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
        
        MessageBox.show(msg.to!dstring, "Keyboard Shortcuts"d);
        return true;
    }
    
    private bool onSave(Widget w) {
        if (!isDirty) return true;
        
        // TODO: Save note changes
        isDirty = false;
        close(DialogResult.OK);
        return true;
    }
    
    private bool onTogglePreview(Widget w) {
        preview.visible = !preview.visible;
        if (preview.visible) {
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
                contentEdit.caretPos,
                contentEdit.caretPos
            );
            lastContent = newContent;
            redoStack.length = 0; // Clear redo stack on new change
        }
        
        currentNote.content = newContent;
        isDirty = true;
        lastEdit = Clock.currTime();
        
        if (preview.visible) {
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
            contentEdit.caretPos,
            action.beforePos
        );
        
        contentEdit.text = action.beforeText.to!dstring;
        contentEdit.caretPos = action.beforePos;
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
            contentEdit.caretPos,
            action.beforePos
        );
        
        contentEdit.text = action.beforeText.to!dstring;
        contentEdit.caretPos = action.beforePos;
        updateSyntaxHighlighting();
        return true;
    }
    
    private void updatePreview() {
        import std.process : execute;
        
        // Save current content to temp file
        import std.file : write, remove;
        import std.path : buildPath, tempDir;
        
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
        auto selStart = contentEdit.selectionStart;
        auto selEnd = contentEdit.selectionEnd;
        
        if (selStart == selEnd) {
            // No selection, just insert at cursor
            auto newText = text[0..selStart] ~ prefix ~ suffix ~ text[selStart..$];
            contentEdit.text = newText.to!dstring;
            contentEdit.selectionStart = selStart + prefix.length;
            contentEdit.selectionEnd = selStart + prefix.length;
        } else {
            // Wrap selection
            auto selectedText = text[selStart..selEnd];
            auto newText = text[0..selStart] ~ prefix ~ selectedText ~ 
                suffix ~ text[selEnd..$];
            contentEdit.text = newText.to!dstring;
            contentEdit.selectionStart = selStart;
            contentEdit.selectionEnd = selEnd + prefix.length + suffix.length;
        }
    }
    
    private void insertLink() {
        auto text = contentEdit.text.to!string;
        auto selStart = contentEdit.selectionStart;
        auto selEnd = contentEdit.selectionEnd;
        
        if (selStart == selEnd) {
            insertMarkdownSyntax("[", "](url)");
        } else {
            auto selectedText = text[selStart..selEnd];
            auto newText = text[0..selStart] ~ "[" ~ selectedText ~ 
                "](url)" ~ text[selEnd..$];
            contentEdit.text = newText.to!dstring;
            contentEdit.selectionStart = selEnd + 2;
            contentEdit.selectionEnd = selEnd + 5;
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
}

private enum UserEventType {
    AutoSave = 1
} 

 