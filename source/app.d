module app;

import std.stdio;
import std.file;
import std.datetime;
import std.conv;

import dlangui;
import dlangui.platforms.common.platform;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.core.events;

import dowel.core.config;
import dowel.wm.manager;
import dowel.panel.panel;
import dowel.desktop.desktop;
import dowel.themes.modern_dark;

mixin APP_ENTRY_POINT;

/// Main desktop environment application
class DesktopEnvironment : VerticalLayout
{
    private WindowManager _windowManager;
    private Panel _panel;
    private Desktop _desktop;
    private ConfigManager _config;

    this()
    {
        super("desktopEnvironment");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;

        _config = ConfigManager.instance();

        // Initialize components
        initializeDesktop();
        initializeWindowManager();
        initializePanel();

        // Set up layout
        setupLayout();

        // Load configuration
        applyConfiguration();
    }

    private void initializeDesktop()
    {
        _desktop = new Desktop();
        _desktop.layoutWidth = FILL_PARENT;
        _desktop.layoutHeight = FILL_PARENT;
    }

    private void initializeWindowManager()
    {
        _windowManager = new WindowManager();
        _windowManager.layoutWidth = FILL_PARENT;
        _windowManager.layoutHeight = FILL_PARENT;

        // Signal connections disabled - DlangUI Signal implementation differs
        // TODO: Implement proper event system
    }

    private void initializePanel()
    {
        _panel = new Panel();

        // Panel signal connections disabled - DlangUI Signal implementation differs
        // TODO: Implement proper event system
    }

    private void setupLayout()
    {
        // Stack desktop, window manager, and panel
        auto desktopContainer = new FrameLayout();
        desktopContainer.layoutWidth = FILL_PARENT;
        desktopContainer.layoutHeight = FILL_PARENT;

        // Add desktop background first
        desktopContainer.addChild(_desktop);

        // Add window manager on top
        desktopContainer.addChild(_windowManager);

        // Add main container
        addChild(desktopContainer);

        // Add panel based on position
        string panelPos = _config.panel.position;
        if (panelPos == "top")
        {
            // Insert panel at beginning
            removeAllChildren();
            addChild(_panel);
            addChild(desktopContainer);
        }
        else
        {
            // Add panel at end (default for bottom)
            addChild(_panel);
        }
    }

    private void applyConfiguration()
    {
        // Apply modern dark theme
        ModernDarkTheme.apply();

        // Apply theme
        string theme = _config.general.theme;
        if (theme != "default")
        {
            // Load custom theme
            Platform.instance.uiTheme = theme;
        }

        // Set up keyboard shortcuts
        setupKeyboardShortcuts();

        // Apply desktop settings
        if (_config.desktop.wallpaperPath.length > 0)
        {
            _desktop.setWallpaper(_config.desktop.wallpaperPath);
        }

        // Set panel position and size
        _panel.setPosition(_config.panel.position);
        _panel.setHeight(_config.panel.height);
    }

    private void setupKeyboardShortcuts()
    {
        // TODO: Implement keyboard shortcuts
        // DlangUI doesn't have a global acceleratorMap
        // Shortcuts will be handled in handleKeyEvent instead
    }

    private void launchApplication(string appPath)
    {
        import std.process : spawnProcess;

        try
        {
            writeln("Launching application: ", appPath);
            spawnProcess([appPath]);
        }
        catch (Exception e)
        {
            writeln("Failed to launch application: ", e.msg);
        }
    }

    override bool onTimer(ulong id)
    {
        if (id == 100)
        {
            createDemoWindow();
            return false; // Don't repeat
        }
        return false;
    }

    override bool handleAction(const Action action)
    {
        switch (action.id)
        {
        case 1001: // Switch Window
            _windowManager.focusNextWindow();
            return true;

        case 1002: // Open Terminal
            launchApplication(_config.apps.terminal);
            return true;

        case 1003: // Show Desktop
            // Minimize all windows
            foreach (window; _windowManager.windows)
            {
                if (!window.isMinimized)
                    _windowManager.minimizeWindow(window);
            }
            return true;

        case 1004: // Lock Screen
            // TODO: Implement screen locking
            writeln("Lock screen not yet implemented");
            return true;

        case 1005: // Close Window
            if (_windowManager.focusedWindow)
                _windowManager.unmanageWindow(_windowManager.focusedWindow);
            return true;

        default:
            // Check for workspace shortcuts
            if (action.id >= 2001 && action.id <= 2009)
            {
                int workspace = action.id - 2001;
                _windowManager.switchToWorkspace(workspace);
                return true;
            }
            else if (action.id >= 2101 && action.id <= 2109)
            {
                int workspace = action.id - 2101;
                if (_windowManager.focusedWindow)
                    _windowManager.moveWindowToWorkspace(_windowManager.focusedWindow, workspace);
                return true;
            }
            break;
        }

        return super.handleAction(action);
    }

    /// Create a demo window for testing
    void createDemoWindow()
    {
        import dlangui.widgets.controls;

        auto window = Platform.instance.createWindow("Demo Window"d, null,
            WindowFlag.Resizable, 400, 300);

        auto layout = new VerticalLayout();
        layout.layoutWidth = FILL_PARENT;
        layout.layoutHeight = FILL_PARENT;
        layout.padding = Rect(10, 10, 10, 10);

        auto label = new TextWidget();
        label.text = "This is a demo window"d;
        label.layoutWidth = FILL_PARENT;
        layout.addChild(label);

        auto button = new Button();
        button.text = "Click Me"d;
        button.click = delegate(Widget src) {
            writeln("Button clicked!");
            return true;
        };
        layout.addChild(button);

        window.mainWidget = layout;

        // Add to window manager
        _windowManager.manageWindow(window);
    }
}

// Main entry point
extern (C) int UIAppMain(string[] args)
{
    // Enable debug logging
    Log.setLogLevel(LogLevel.Debug);

    // Write startup log
    writeln("Dowel-Steek Desktop Environment starting...");
    writeln("Version: 0.1.0-alpha");
    writeln("Args: ", args);

    try
    {
        // Initialize platform
        writeln("Initializing platform...");

        // Apply modern theme early
        ModernDarkTheme.apply();

        // Set window flags for windowed desktop environment
        uint flags = WindowFlag.Resizable;

        // Create main window
        writeln("Creating main window...");
        auto window = Platform.instance.createWindow("Dowel-Steek Desktop"d, null,
            flags, 1200, 800);

        if (!window)
        {
            writeln("ERROR: Failed to create main window");
            return 1;
        }

        // Create desktop environment
        writeln("Initializing desktop environment...");
        auto desktop = new DesktopEnvironment();

        // Set as main widget
        window.mainWidget = desktop;

        // Show window
        writeln("Showing window...");
        window.show();

        // Create a demo window after a short delay
        window.mainWidget.setTimer(100);

        // Enter message loop
        writeln("Entering message loop...");
        return Platform.instance.enterMessageLoop();
    }
    catch (Exception e)
    {
        writeln("ERROR: Exception caught: ", e.msg);
        writeln("Stack trace: ", e.toString());
        Log.e("Fatal error: ", e.msg);
        return 1;
    }
}
