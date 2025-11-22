module terminal.window;

import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.controls;
import dlangui.widgets.editors;
import dlangui.widgets.layouts : VerticalLayout;
import dlangui.core.events;
import dlangui.core.editable;
import std.process : ProcessPipes, pipeProcess, Redirect;
import std.stdio;
import dlangui.platforms.common.platform;
import dlangui.core.types;

// A very basic terminal window
class TerminalWindow : Window {
    private EditBox _outputArea;
    private EditLine _inputLine;
    private ProcessPipes _pipes;
    private dstring _windowCaption;

    this() {
        super();
        _windowCaption = "Terminal"d;

        auto mainLayout = new VerticalLayout();
        mainLayout.layoutWidth = FILL_PARENT;
        mainLayout.layoutHeight = FILL_PARENT;
        mainLayout.backgroundColor = 0x1E1E1E; // Dark background

        // Output area
        _outputArea = new EditBox("output");
        _outputArea.layoutWidth = FILL_PARENT;
        _outputArea.layoutHeight = FILL_PARENT;
        _outputArea.readOnly = true;
        _outputArea.textColor = 0xE0E0E0; // Light text
        _outputArea.backgroundColor = 0x1E1E1E;
        mainLayout.addChild(_outputArea);

        // Input line
        _inputLine = new EditLine("input");
        _inputLine.layoutWidth = FILL_PARENT;
        _inputLine.layoutHeight = WRAP_CONTENT;
        _inputLine.textColor = 0xFFFFFF;
        _inputLine.backgroundColor = 0x333333;
        _inputLine.keyEvent = &handleInputKeyEvent;
        mainLayout.addChild(_inputLine);

        mainWidget = mainLayout;

        // TODO: Start actual shell process and handle I/O
        // startShell();
        _outputArea.text = _outputArea.text ~ "Basic Terminal Window - Shell not fully connected.\\\\n$ ";
        scrollToOutputEnd();
    }

    private void scrollToOutputEnd() {
        if (_outputArea.content.lines.length > 0) {
            // Cast to int for setCaretPos
            int line = cast(int)(_outputArea.content.lines.length - 1);
            int col = cast(int)_outputArea.content.lines[$-1].length;
            _outputArea.setCaretPos(line, col, true); // true to make it visible
        }
    }

    // Placeholder - Actual shell interaction is complex
    private void startShell() {
       // Example: Starting \'sh\'. Requires careful handling of pipes and threads.
       // _pipes = pipeProcess("/bin/sh", Redirect.stdin | Redirect.stdout | Redirect.stderr);
       // TODO: Read from _pipes.stdout/_pipes.stderr in a separate thread
       //       and append to _outputArea using postEvent/Platform.runOnMainThread.
       // TODO: Write to _pipes.stdin when user enters command.
    }

    private bool handleInputKeyEvent(Widget src, KeyEvent event) {
        if (event.action == KeyAction.KeyDown && event.keyCode == KeyCode.RETURN) {
            if (auto inputBox = cast(EditLine)src) {
                dstring command = inputBox.text;
                // Send command to shell (placeholder)
                _outputArea.text = _outputArea.text ~ command ~ "\\\\n";
                // TODO: Write command to _pipes.stdin

                // Clear input and add prompt (placeholder)
                inputBox.text = "";
                _outputArea.text = _outputArea.text ~ "$ ";
                scrollToOutputEnd();
                return true; // Event handled
            }
        }
        return false; // Event not handled
    }

    override void show() {
        // Create a platform window. This TerminalWindow instance itself is not the platform window,
        // but it *contains* the UI (mainWidget) that should be put into a platform window.
        auto platformNativeWindow = Platform.instance.createWindow(_windowCaption, null, WindowFlag.Resizable, 600, 400);
        if (platformNativeWindow) {
            // Assign this TerminalWindow's mainWidget (the VerticalLayout with UI elements)
            // to the newly created platform window.
            if (this.mainWidget) {
                platformNativeWindow.mainWidget = this.mainWidget;
                // this.mainWidget.invalidate(); // Invalidate if needed after assigning
            } else {
                Log.e("TerminalWindow.show(): this.mainWidget is null! UI not constructed.");
            }
            platformNativeWindow.show(); // Show the platform-level window
            _inputLine.setFocus(); // Focus input line on show
        } else {
            Log.e("Failed to create platform window for TerminalWindow.");
        }
    }

    // Required overrides
    override @property dstring windowCaption() const { return _windowCaption; }
    override @property void windowCaption(dstring caption) { _windowCaption = caption; }
    override @property void windowIcon(DrawBufRef icon) { /* Optional */ }
    override void invalidate() { if (mainWidget) mainWidget.invalidate(); }
    
    override void close() {
         // TODO: Terminate shell process if running
         // if (_pipes.pid !is null) wait(_pipes.pid);
        
        // This Window instance (TerminalWindow) is being closed.
        // The platform window that displays its content needs to be closed.
        // DLangUI's base Window.close() typically handles Platform.instance.closeWindow(this).
        // However, since we're in an override, we need to ensure proper cleanup.
        
        // First, remove content from this window's mainWidget if it exists
        // This helps break circular refs and aids GC, though DLangUI might do this.
        if (mainWidget) {
             mainWidget.removeAllChildren(); // Clean up children of the layout
             // mainWidget = null; // Don't null it here if base .close() might need it
        }
        
        // Option 1: Call super.close() IF the base Window.close() is what we want
        // and it's not abstract or problematic. This would call Platform.instance.closeWindow(this).
        // super.close(); 

        // Option 2: Explicitly close via Platform, which is safer if super.close() is tricky.
        Platform.instance.closeWindow(this);
    }
} 

 