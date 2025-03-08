module taskbar.components;

import dlangui;
import dlangui.widgets.styles;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.menu;
import dlangui.platforms.common.platform;
import std.datetime;
import std.conv : to;
import std.datetime.systime : Clock;
import std.format : format;
import taskbar.buttons;

// Base taskbar components (TaskBar, TaskButton, etc)
// ... move existing TaskBar code here ...

// Enhanced TaskBar with window management
class TaskBar : HorizontalLayout {
    private WindowList _windowList;
    private SystemTray _systemTray;
    private TaskButton _startButton;
    private bool delegate(Widget) _onStartClick;

    this(bool delegate(Widget) onStartClick) {
        super("taskBar");
        _onStartClick = onStartClick;
        
        // Set taskbar style
        backgroundColor = 0x2D2D2D;
        layoutWidth = FILL_PARENT;
        layoutHeight = 32;
        padding(Rect(2, 2, 2, 2));

        // Create start button
        _startButton = new TaskButton("startButton");
        _startButton.text = "Start"d;
        _startButton.textColor = 0xFFFFFF;
        _startButton.click = &onStartButtonClick;
        addChild(_startButton);

        // Create window list
        _windowList = new WindowList();
        addChild(_windowList);

        // Create system tray
        _systemTray = new SystemTray();
        addChild(_systemTray);
    }

    private bool onStartButtonClick(Widget w) {
        if (_onStartClick)
            return _onStartClick(w);
        return false;
    }

    void addWindowButton(Window window) {
        _windowList.addWindow(window);
    }
}

// Task button for window
class TaskButton : Button {
    this(string id = null) {
        super(id);
        styleId = STYLE_TOOLBAR_BUTTON;
        layoutWidth = WRAP_CONTENT;
        layoutHeight = FILL_PARENT;
        padding(Rect(4, 4, 4, 4));
    }
}

class SystemTray : HorizontalLayout {
    private ulong _timerId;

    this() {
        super("systemTray");
        layoutWidth = WRAP_CONTENT;
        layoutHeight = FILL_PARENT;
        padding(Rect(2, 2, 2, 2));
        
        // Add clock
        auto clock = new TextWidget("clock", currentTime());
        clock.textColor = 0xFFFFFF;
        addChild(clock);
        
        // Update clock every minute
        _timerId = setTimer(60000);
    }
    
    override bool onTimer(ulong id) {
        if (id == _timerId) {
            auto clockWidget = childById!TextWidget("clock");
            if (clockWidget)
                clockWidget.text = currentTime();
            return true;
        }
        return false;
    }
    
    private dstring currentTime() {
        auto now = Clock.currTime();
        return to!dstring(format("%02d:%02d", now.hour, now.minute));
    }

    ~this() {
        if (_timerId)
            cancelTimer(_timerId);
    }
}

class WindowList : HorizontalLayout {
    this() {
        super("windowList");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        padding(Rect(2, 2, 2, 2));
    }

    TaskButton addWindow(Window window) {
        auto btn = new TaskButton(to!string(window.windowCaption));
        btn.text = window.windowCaption;
        btn.click = delegate(Widget src) {
            Platform.instance.setActiveWindow(window);  // Use setActiveWindow instead of activate
            return true;
        };
        addChild(btn);
        return btn;
    }
}

class StartMenu : PopupMenu {
    private MenuItem _root;

    this() {
        _root = new MenuItem(null);
        super(_root);
        
        // Add menu items
        _root.add(new Action(1, "Applications"d));
        _root.add(new Action(2, "Settings"d));
        _root.add(new Action(3, "File Manager"d));
        _root.addSeparator();
        _root.add(new Action(4, "Log Out"d));
        
        // Add submenus
        auto apps = new MenuItem(null);
        apps.add(new Action(101, "Terminal"d));
        apps.add(new Action(102, "Browser"d));
        apps.add(new Action(103, "Text Editor"d));
        _root.add(apps);
        
        menuItemAction = &handleMenuAction;
    }

    private bool handleMenuAction(const Action action) {
        switch(action.id) {
            case 1: // Applications
                return true;
            case 2: // Settings
                // TODO: Show settings window
                return true;
            case 3: // File Manager
                // TODO: Launch file manager
                return true;
            case 4: // Log Out
                if (auto win = Platform.instance.focusedWindow)  // Use focusedWindow instead of activeWindow
                    Platform.instance.closeWindow(win);
                return true;
            case 101: // Terminal
                // TODO: Launch terminal
                return true;
            case 102: // Browser
                // TODO: Launch browser
                return true;
            case 103: // Text Editor
                // TODO: Launch text editor
                return true;
            default:
                return false;
        }
    }
}

// Update style constants
enum {
    STYLE_TOOLBAR_BUTTON = "TOOLBAR_BUTTON"
}

