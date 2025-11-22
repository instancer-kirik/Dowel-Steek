module dowel.panel.panel;

import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dowel.wm.manager;
import dowel.themes.modern_dark;
import std.conv : to;

/// Panel widget for taskbar and system tray
class Panel : HorizontalLayout
{
    private Widget _startMenu;
    private Widget _taskbar;
    private Widget _systemTray;
    private Widget _clock;

    // Signals temporarily disabled - DlangUI Signal implementation differs
    // TODO: Implement proper event system

    this()
    {
        super("panel");
        layoutWidth = FILL_PARENT;
        layoutHeight = 44;
        backgroundColor = ModernDarkTheme.Colors.PanelBackground;
        padding(Rect(8, 6, 8, 6));

        // Create panel sections
        createStartMenu();
        createTaskbar();
        createSystemTray();
        createClock();
    }

    private void createStartMenu()
    {
        _startMenu = new Button("start_menu", "Dowel"d);
        _startMenu.layoutWidth = 80;
        _startMenu.layoutHeight = 32;
        _startMenu.backgroundColor = ModernDarkTheme.Colors.Accent;
        _startMenu.textColor = 0xFFFFFFFF;
        addChild(_startMenu);
    }

    private void createTaskbar()
    {
        _taskbar = new HorizontalLayout("taskbar");
        _taskbar.layoutWidth = FILL_PARENT;
        _taskbar.layoutHeight = FILL_PARENT;
        _taskbar.padding(Rect(8, 0, 8, 0));
        addChild(_taskbar);
    }

    private void createSystemTray()
    {
        _systemTray = new HorizontalLayout("system_tray");
        _systemTray.layoutWidth = 100;
        _systemTray.layoutHeight = FILL_PARENT;
        _systemTray.padding(Rect(4, 0, 4, 0));
        addChild(_systemTray);
    }

    private void createClock()
    {
        import std.datetime;

        auto now = Clock.currTime();
        auto timeStr = now.toSimpleString()[11 .. 16]; // Extract HH:MM

        _clock = new TextWidget("clock", timeStr.dup.to!dstring);
        _clock.layoutWidth = 60;
        _clock.layoutHeight = FILL_PARENT;
        _clock.textColor = ModernDarkTheme.Colors.TextPrimary;
        _clock.fontSize = 11;
        _clock.alignment = Align.Center;
        addChild(_clock);
    }

    void addWindowButton(ManagedWindow window)
    {
        if (!window || !_taskbar)
            return;

        auto button = new Button(null, window.title);
        button.layoutWidth = 150;
        button.layoutHeight = 32;
        button.backgroundColor = ModernDarkTheme.Colors.Secondary;
        button.textColor = ModernDarkTheme.Colors.TextPrimary;
        button.fontSize = 10;
        button.margins = Rect(2, 0, 2, 0);

        button.click = delegate(Widget src) {
            // Focus the window when clicked
            if (window)
            {
                // TODO: implement focus method
                return true;
            }
            return true;
        };

        _taskbar.addChild(button);
        window.panelButton = button;
    }

    void removeWindowButton(ManagedWindow window)
    {
        if (!window || !window.panelButton || !_taskbar)
            return;

        _taskbar.removeChild(window.panelButton);
        window.panelButton = null;
    }

    void setActiveWindow(ManagedWindow window)
    {
        if (!_taskbar)
            return;

        // TODO: Reset all buttons to inactive state
        // DlangUI widget children iteration needs to be implemented properly

        // Highlight active window button
        if (window && window.panelButton)
        {
            window.panelButton.backgroundColor = ModernDarkTheme.Colors.Accent;
        }
    }

    void setActiveWorkspace(int workspace)
    {
        // TODO: Update workspace indicator in system tray
    }

    void setPosition(string position)
    {
        // TODO: Set panel position (top/bottom/left/right)
        // For now, only bottom position is supported
    }

    void setHeight(int height)
    {
        layoutHeight = height;
    }

    void updateClock()
    {
        if (!_clock)
            return;

        import std.datetime;

        auto now = Clock.currTime();
        auto timeStr = now.toSimpleString()[11 .. 16]; // Extract HH:MM
        _clock.text = timeStr.dup.to!dstring;
    }
}
