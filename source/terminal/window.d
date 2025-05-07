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
    private EditBox _inputLine;
    private ProcessPipes _pipes;

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
        _outputArea.multiline = true;
        _outputArea.wordWrap = true;
        mainLayout.addChild(_outputArea);

        // Input line
        _inputLine = new EditBox("input");
        _inputLine.layoutWidth = FILL_PARENT;
        _inputLine.layoutHeight = WRAP_CONTENT;
        _inputLine.textColor = 0xFFFFFF;
        _inputLine.backgroundColor = 0x333333;
        _inputLine.multiline = false;
        _inputLine.keyEnter = &handleInputFromEditBox;
        mainLayout.addChild(_inputLine);

        mainWidget = mainLayout;

        // TODO: Start actual shell process and handle I/O
        // startShell();
        _outputArea.appendText("Basic Terminal Window - Shell not fully connected.\n$ ");
    }

    // Placeholder - Actual shell interaction is complex
    private void startShell() {
       // Example: Starting 'sh'. Requires careful handling of pipes and threads.
       // _pipes = pipeProcess("/bin/sh", Redirect.stdin | Redirect.stdout | Redirect.stderr);
       // TODO: Read from _pipes.stdout/_pipes.stderr in a separate thread
       //       and append to _outputArea using postEvent/Platform.runOnMainThread.
       // TODO: Write to _pipes.stdin when user enters command.
    }

    private bool handleInputFromEditBox(Widget src, dstring text) {
        if (auto inputBox = cast(EditBox)src) {
            dstring command = inputBox.text;
            // Send command to shell (placeholder)
            _outputArea.appendText(command ~ "\n");
            // TODO: Write command to _pipes.stdin

            // Clear input and add prompt (placeholder)
            inputBox.text = "";
            _outputArea.appendText("$ ");
            _outputArea.scrollToEnd(); // Keep latest output visible
            return true;
        }
        return false;
    }

    override void show() {
         // Create a standard resizable window
        auto win = Platform.instance.createWindow(_windowCaption, null, WindowFlag.Resizable, 600, 400);
        if (win) {
            win.mainWidget = this;
            _inputLine.setFocus(); // Focus input line on show
        }
    }

    // Required overrides (can often be minimal if inheriting from Window)
    override @property dstring windowCaption() const { return _windowCaption; }
    override @property void windowCaption(dstring caption) { _windowCaption = caption; }
    override @property void windowIcon(DrawBufRef icon) { /* Optional */ }
    override void invalidate() { if (mainWidget) mainWidget.invalidate(); }
    override void close() {
         // TODO: Terminate shell process if running
         // if (_pipes.pid !is null) wait(_pipes.pid);
         super.close(); // Call base close
    }
} 

 