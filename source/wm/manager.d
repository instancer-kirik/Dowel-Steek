module dowel.wm.manager;

import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.platforms.common.platform;
import dlangui.core.events;
import dlangui.core.types;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.math : abs;

import dowel.core.config;
import dowel.wm.decorations;
import dowel.wm.layouts.floating;
import dowel.wm.layouts.tiling;

/// Window state flags
enum WindowState
{
    Normal = 0,
    Maximized = 1 << 0,
    Minimized = 1 << 1,
    Fullscreen = 1 << 2,
    Sticky = 1 << 3, // Visible on all workspaces
    Above = 1 << 4, // Always on top
    Below = 1 << 5, // Always on bottom
    Shaded = 1 << 6, // Rolled up to titlebar
    SkipTaskbar = 1 << 7,
    SkipPager = 1 << 8,
    Hidden = 1 << 9,
    Focused = 1 << 10
}

/// Managed window information
class ManagedWindow
{
    Window window;
    WindowDecoration decoration;
    Widget contentWidget;
    Rect geometry;
    Rect savedGeometry; // For restoration after maximize/fullscreen
    WindowState state;
    int workspace;
    string windowClass;
    string title;
    bool isFloating;
    long lastFocusTime;
    Widget panelButton; // Reference to taskbar button

    this(Window win)
    {
        window = win;
        state = WindowState.Normal;
        workspace = 0;
        isFloating = true;
        lastFocusTime = 0;

        if (window && window.mainWidget)
        {
            contentWidget = window.mainWidget;
            title = to!string(window.windowCaption);
        }
    }

    @property bool isMaximized() const
    {
        return (state & WindowState.Maximized) != 0;
    }

    @property bool isMinimized() const
    {
        return (state & WindowState.Minimized) != 0;
    }

    @property bool isFullscreen() const
    {
        return (state & WindowState.Fullscreen) != 0;
    }

    @property bool isSticky() const
    {
        return (state & WindowState.Sticky) != 0;
    }

    @property bool isFocused() const
    {
        return (state & WindowState.Focused) != 0;
    }

    @property bool isVisible() const
    {
        return !isMinimized && (state & WindowState.Hidden) == 0;
    }

    void setState(WindowState flag, bool value)
    {
        if (value)
            state |= flag;
        else
            state &= ~flag;
    }
}

/// Window layout manager interface
interface IWindowLayout
{
    void arrange(ManagedWindow[] windows, Rect area);
    void addWindow(ManagedWindow window);
    void removeWindow(ManagedWindow window);
    void focusNext();
    void focusPrevious();
    string name() const;
}

/// Main window manager
class WindowManager : FrameLayout
{
private:
    ManagedWindow[] _windows;
    ManagedWindow[] _minimizedWindows;
    ManagedWindow _focusedWindow;
    IWindowLayout _currentLayout;
    IWindowLayout[string] _layouts;
    int _currentWorkspace;
    int _workspaceCount;
    Rect _workArea;
    bool _compositorEnabled;

    // Window manipulation state
    bool _isMoving;
    bool _isResizing;
    Point _dragStartPos;
    Rect _dragStartGeometry;

    // Configuration
    ConfigManager _config;

public:

    // Signals temporarily disabled - DlangUI Signal implementation differs
    // TODO: Implement proper event system

    this()
    {
        super("windowManager");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;

        _config = ConfigManager.instance();
        _currentWorkspace = 0;
        _workspaceCount = _config.wm.workspaceCount;
        _compositorEnabled = _config.general.compositorEnabled != 0;

        // Initialize layouts
        _layouts["floating"] = new FloatingLayout();
        _layouts["tiling"] = new TilingLayout();
        _currentLayout = _layouts[_config.wm.defaultLayout];

        // Set background color
        backgroundColor = 0x1E1E1E;

        // Calculate work area (excluding panels)
        updateWorkArea();
    }

    /// Add a window to management
    void manageWindow(Window window)
    {
        if (!window || !window.mainWidget)
            return;

        // Check if already managed
        foreach (w; _windows)
        {
            if (w.window == window)
                return;
        }

        auto managed = new ManagedWindow(window);
        managed.workspace = _currentWorkspace;

        // Create decoration if not fullscreen
        if (_config.wm.borderWidth > 0)
        {
            managed.decoration = new WindowDecoration(managed);
            managed.decoration.onClose = () { unmanageWindow(managed); };
            managed.decoration.onMaximize = () { toggleMaximize(managed); };
            managed.decoration.onMinimize = () { minimizeWindow(managed); };
            managed.decoration.onMove = delegate(Point delta) @safe {
                moveWindow(managed, delta);
            };
            managed.decoration.onResize = delegate(
                dowel.wm.decorations.WindowDecoration.Size delta) @safe {
                auto s = Size(delta.width, delta.height);
                resizeWindow(managed, s);
            };
        }

        // Add to layout
        _windows ~= managed;
        _currentLayout.addWindow(managed);

        // Add decoration widget to our layout
        if (managed.decoration)
        {
            addChild(managed.decoration);
        }
        else if (managed.contentWidget)
        {
            addChild(managed.contentWidget);
        }

        // Focus the new window
        focusWindow(managed);

        // Arrange windows
        arrangeWindows();

        // Signal - TODO: implement event system
        // onWindowAdded.emit(managed);
    }

    /// Remove a window from management
    void unmanageWindow(ManagedWindow window)
    {
        if (!window)
            return;

        // Remove from windows list
        _windows = _windows.filter!(w => w != window).array;
        _minimizedWindows = _minimizedWindows.filter!(w => w != window).array;

        // Remove from layout
        _currentLayout.removeWindow(window);

        // Remove decoration widget
        if (window.decoration)
        {
            removeChild(window.decoration);
        }
        else if (window.contentWidget)
        {
            removeChild(window.contentWidget);
        }

        // Update focus
        if (_focusedWindow == window)
        {
            _focusedWindow = null;
            if (_windows.length > 0)
            {
                focusWindow(_windows[0]);
            }
        }

        // Close the actual window
        if (window.window)
        {
            window.window.close();
        }

        // Rearrange remaining windows
        arrangeWindows();

        // Signal - TODO: implement event system
        // onWindowRemoved.emit(window);
    }

    /// Focus a window
    void focusWindow(ManagedWindow window)
    {
        if (!window || window == _focusedWindow)
            return;

        // Unfocus previous window
        if (_focusedWindow)
        {
            _focusedWindow.setState(WindowState.Focused, false);
            if (_focusedWindow.decoration)
                _focusedWindow.decoration.setFocused(false);
        }

        // Focus new window
        _focusedWindow = window;
        window.setState(WindowState.Focused, true);
        window.lastFocusTime = currentTimeMillis();

        if (window.decoration)
        {
            window.decoration.setFocused(true);
            // Bring to front
            removeChild(window.decoration);
            addChild(window.decoration);
        }
        else if (window.contentWidget)
        {
            // Bring to front
            removeChild(window.contentWidget);
            addChild(window.contentWidget);
        }

        // Signal - TODO: implement event system
        // onWindowFocused.emit(window);
    }

    /// Move window by delta
    void moveWindow(ManagedWindow window, Point delta) @trusted
    {
        if (!window)
            return;

        window.geometry.left += delta.x;
        window.geometry.top += delta.y;
        window.geometry.right += delta.x;
        window.geometry.bottom += delta.y;

        // Apply edge snapping
        if (_config.wm.snapDistance > 0)
        {
            int snap = _config.wm.snapDistance;

            // Snap to screen edges
            if (abs(window.geometry.left) < snap)
            {
                int width = window.geometry.width;
                window.geometry.left = 0;
                window.geometry.right = width;
            }
            if (abs(window.geometry.top) < snap)
            {
                int height = window.geometry.height;
                window.geometry.top = 0;
                window.geometry.bottom = height;
            }
            if (abs(window.geometry.right - _workArea.right) < snap)
            {
                int width = window.geometry.width;
                window.geometry.right = _workArea.right;
                window.geometry.left = _workArea.right - width;
            }
            if (abs(window.geometry.bottom - _workArea.bottom) < snap)
            {
                int height = window.geometry.height;
                window.geometry.bottom = _workArea.bottom;
                window.geometry.top = _workArea.bottom - height;
            }

            // Snap to other windows
            foreach (other; _windows)
            {
                if (other == window || !other.isVisible)
                    continue;

                // Snap to left edge
                if (abs(window.geometry.left - other.geometry.right) < snap)
                {
                    int width = window.geometry.width;
                    window.geometry.left = other.geometry.right;
                    window.geometry.right = other.geometry.right + width;
                }
                // Snap to right edge
                if (abs(window.geometry.right - other.geometry.left) < snap)
                {
                    int width = window.geometry.width;
                    window.geometry.right = other.geometry.left;
                    window.geometry.left = other.geometry.left - width;
                }
                // Snap to top edge
                if (abs(window.geometry.top - other.geometry.bottom) < snap)
                {
                    int height = window.geometry.height;
                    window.geometry.top = other.geometry.bottom;
                    window.geometry.bottom = other.geometry.bottom + height;
                }
                // Snap to bottom edge
                if (abs(window.geometry.bottom - other.geometry.top) < snap)
                {
                    int height = window.geometry.height;
                    window.geometry.bottom = other.geometry.top;
                    window.geometry.top = other.geometry.top - height;
                }
            }
        }

        updateWindowPosition(window);
    }

    /// Resize window by delta
    struct Size
    {
        int width;
        int height;
    }

    void resizeWindow(ManagedWindow window, Size delta) @trusted
    {
        if (!window)
            return;

        window.geometry.right += delta.width;
        window.geometry.bottom += delta.height;

        // Enforce minimum size
        if (window.geometry.width < 100)
            window.geometry.right = window.geometry.left + 100;
        if (window.geometry.height < 50)
            window.geometry.bottom = window.geometry.top + 50;

        updateWindowPosition(window);
    }

    /// Toggle maximize state
    void toggleMaximize(ManagedWindow window)
    {
        if (!window)
            return;

        if (window.isMaximized)
        {
            // Restore
            window.setState(WindowState.Maximized, false);
            window.geometry = window.savedGeometry;
        }
        else
        {
            // Maximize
            window.savedGeometry = window.geometry;
            window.setState(WindowState.Maximized, true);
            window.geometry = _workArea;
        }

        updateWindowPosition(window);
    }

    /// Minimize window
    void minimizeWindow(ManagedWindow window)
    {
        if (!window)
            return;

        window.setState(WindowState.Minimized, true);
        _minimizedWindows ~= window;

        if (window.decoration)
            window.decoration.visibility = Visibility.Gone;
        else if (window.contentWidget)
            window.contentWidget.visibility = Visibility.Gone;

        // Focus next window
        focusNextWindow();

        arrangeWindows();
    }

    /// Restore minimized window
    void restoreWindow(ManagedWindow window)
    {
        if (!window || !window.isMinimized)
            return;

        window.setState(WindowState.Minimized, false);
        _minimizedWindows = _minimizedWindows.filter!(w => w != window).array;

        if (window.decoration)
            window.decoration.visibility = Visibility.Visible;
        else if (window.contentWidget)
            window.contentWidget.visibility = Visibility.Visible;

        focusWindow(window);
        arrangeWindows();
    }

    /// Toggle fullscreen state
    void toggleFullscreen(ManagedWindow window)
    {
        if (!window)
            return;

        if (window.isFullscreen)
        {
            // Exit fullscreen
            window.setState(WindowState.Fullscreen, false);
            window.geometry = window.savedGeometry;

            // Show decoration
            if (window.decoration)
                window.decoration.showDecoration();
        }
        else
        {
            // Enter fullscreen
            window.savedGeometry = window.geometry;
            window.setState(WindowState.Fullscreen, true);

            // Use entire screen
            window.geometry = Rect(0, 0, 1920, 1080); // Default fullscreen size

            // Hide decoration
            if (window.decoration)
                window.decoration.hideDecoration();
        }

        updateWindowPosition(window);
    }

    /// Switch to next window (Alt+Tab functionality)
    void focusNextWindow()
    {
        auto visibleWindows = _windows.filter!(w => w.isVisible && w.workspace == _currentWorkspace)
            .array;
        if (visibleWindows.length == 0)
            return;

        if (!_focusedWindow || !visibleWindows.canFind(_focusedWindow))
        {
            focusWindow(visibleWindows[0]);
        }
        else
        {
            auto idx = visibleWindows.countUntil(_focusedWindow);
            idx = (idx + 1) % visibleWindows.length;
            focusWindow(visibleWindows[idx]);
        }
    }

    /// Switch to previous window
    void focusPreviousWindow()
    {
        auto visibleWindows = _windows.filter!(w => w.isVisible && w.workspace == _currentWorkspace)
            .array;
        if (visibleWindows.length == 0)
            return;

        if (!_focusedWindow || !visibleWindows.canFind(_focusedWindow))
        {
            focusWindow(visibleWindows[$ - 1]);
        }
        else
        {
            auto idx = visibleWindows.countUntil(_focusedWindow);
            idx = (idx - 1 + visibleWindows.length) % visibleWindows.length;
            focusWindow(visibleWindows[idx]);
        }
    }

    /// Switch to workspace
    void switchToWorkspace(int workspace)
    {
        if (workspace < 0 || workspace >= _workspaceCount || workspace == _currentWorkspace)
            return;

        // Hide current workspace windows
        foreach (window; _windows)
        {
            if (window.workspace == _currentWorkspace && !window.isSticky)
            {
                if (window.decoration)
                    window.decoration.visibility = Visibility.Gone;
                else if (window.contentWidget)
                    window.contentWidget.visibility = Visibility.Gone;
            }
        }

        _currentWorkspace = workspace;

        // Show new workspace windows
        foreach (window; _windows)
        {
            if (window.workspace == _currentWorkspace || window.isSticky)
            {
                if (!window.isMinimized)
                {
                    if (window.decoration)
                        window.decoration.visibility = Visibility.Visible;
                    else if (window.contentWidget)
                        window.contentWidget.visibility = Visibility.Visible;
                }
            }
        }

        // Focus a window on the new workspace
        auto workspaceWindows = _windows.filter!(w => w.workspace == workspace && w.isVisible)
            .array;
        if (workspaceWindows.length > 0)
        {
            // Focus most recently focused window
            workspaceWindows.sort!((a, b) => a.lastFocusTime > b.lastFocusTime);
            focusWindow(workspaceWindows[0]);
        }
        else
        {
            _focusedWindow = null;
        }

        arrangeWindows();
        // onWorkspaceChanged.emit(workspace);
    }

    /// Move window to workspace
    void moveWindowToWorkspace(ManagedWindow window, int workspace)
    {
        if (!window || workspace < 0 || workspace >= _workspaceCount)
            return;

        window.workspace = workspace;

        if (workspace != _currentWorkspace)
        {
            // Hide window if moving to different workspace
            if (window.decoration)
                window.decoration.visibility = Visibility.Gone;
            else if (window.contentWidget)
                window.contentWidget.visibility = Visibility.Gone;

            focusNextWindow();
        }
    }

    /// Set window layout
    void setLayout(string layoutName)
    {
        if (layoutName !in _layouts)
            return;

        _currentLayout = _layouts[layoutName];
        arrangeWindows();
    }

    /// Toggle floating mode for window
    void toggleFloating(ManagedWindow window)
    {
        if (!window)
            return;

        window.isFloating = !window.isFloating;
        arrangeWindows();
    }

    /// Tile window to left half of screen
    void tileLeft(ManagedWindow window)
    {
        if (!window)
            return;

        window.setState(WindowState.Maximized, false);
        window.geometry = Rect(_workArea.left, _workArea.top,
            _workArea.left + _workArea.width / 2, _workArea.bottom);
        updateWindowPosition(window);
    }

    /// Tile window to right half of screen
    void tileRight(ManagedWindow window)
    {
        if (!window)
            return;

        window.setState(WindowState.Maximized, false);
        window.geometry = Rect(_workArea.left + _workArea.width / 2, _workArea.top,
            _workArea.right, _workArea.bottom);
        updateWindowPosition(window);
    }

    /// Get current workspace
    @property int currentWorkspace() const
    {
        return _currentWorkspace;
    }

    /// Get workspace count
    @property int workspaceCount() const
    {
        return _workspaceCount;
    }

    /// Get focused window
    @property ManagedWindow focusedWindow()
    {
        return _focusedWindow;
    }

    /// Get all managed windows
    @property ManagedWindow[] windows()
    {
        return _windows;
    }

    /// Get windows on current workspace
    @property ManagedWindow[] currentWindows()
    {
        return _windows.filter!(w => w.workspace == _currentWorkspace || w.isSticky).array;
    }

    /// Update work area (accounting for panels)
    void updateWorkArea()
    {
        // Start with full screen
        _workArea = Rect(0, 0, 1920, 1080); // Default screen size

        // Account for panel
        string panelPos = _config.panel.position;
        int panelHeight = _config.panel.height;

        switch (panelPos)
        {
        case "top":
            _workArea.top += panelHeight;
            break;
        case "bottom":
            _workArea.bottom -= panelHeight;
            break;
        case "left":
            _workArea.left += panelHeight;
            break;
        case "right":
            _workArea.right -= panelHeight;
            break;
        default:
            break;
        }
    }

    /// Arrange windows according to current layout
    void arrangeWindows()
    {
        auto layoutWindows = currentWindows.filter!(w => !w.isFloating && w.isVisible).array;

        if (layoutWindows.length > 0)
        {
            _currentLayout.arrange(layoutWindows, _workArea);

            foreach (window; layoutWindows)
            {
                updateWindowPosition(window);
            }
        }
    }

    /// Update window position on screen
    void updateWindowPosition(ManagedWindow window)
    {
        if (!window)
            return;

        if (window.decoration)
        {
            window.decoration.layout(window.geometry);
        }
        else if (window.contentWidget)
        {
            window.contentWidget.layout(window.geometry);
        }
    }

    /// Handle mouse events for window manipulation
    override bool onMouseEvent(MouseEvent event)
    {
        if (event.action == MouseAction.ButtonDown)
        {
            // Check if clicking on a window
            Point pt = Point(event.x, event.y);

            foreach_reverse (window; _windows)
            {
                if (!window.isVisible || window.workspace != _currentWorkspace)
                    continue;

                if (window.geometry.left <= pt.x && pt.x <= window.geometry.right &&
                    window.geometry.top <= pt.y && pt.y <= window.geometry.bottom)
                {
                    focusWindow(window);

                    // Check for special mouse actions with modifiers
                    if (event.flags & MouseFlag.Alt)
                    {
                        if (event.button == MouseButton.Left)
                        {
                            // Start moving
                            _isMoving = true;
                            _dragStartPos = pt;
                            _dragStartGeometry = window.geometry;
                            return true;
                        }
                        else if (event.button == MouseButton.Right)
                        {
                            // Start resizing
                            _isResizing = true;
                            _dragStartPos = pt;
                            _dragStartGeometry = window.geometry;
                            return true;
                        }
                    }
                    break;
                }
            }
        }
        else if (event.action == MouseAction.Move)
        {
            if (_isMoving && _focusedWindow)
            {
                Point delta = Point(event.x - _dragStartPos.x, event.y - _dragStartPos.y);
                _focusedWindow.geometry = _dragStartGeometry;
                moveWindow(_focusedWindow, delta);
                return true;
            }
            else if (_isResizing && _focusedWindow)
            {
                Size delta = Size(event.x - _dragStartPos.x, event.y - _dragStartPos.y);
                _focusedWindow.geometry = _dragStartGeometry;
                resizeWindow(_focusedWindow, delta);
                return true;
            }
        }
        else if (event.action == MouseAction.ButtonUp)
        {
            _isMoving = false;
            _isResizing = false;
        }

        return super.onMouseEvent(event);
    }

    /// Handle keyboard shortcuts
    override bool onKeyEvent(KeyEvent event)
    {
        if (event.action != KeyAction.KeyDown)
            return super.onKeyEvent(event);

        // Check for window manager shortcuts
        uint key = event.keyCode;

        // Alt+Tab - switch windows
        if ((event.flags & KeyFlag.Alt) && key == KeyCode.TAB)
        {
            if (event.flags & KeyFlag.Shift)
                focusPreviousWindow();
            else
                focusNextWindow();
            return true;
        }

        // Super key shortcuts (using Control as substitute)
        if (event.flags & KeyFlag.Control)
        {
            // Super+Q - close window
            if (key == KeyCode.KEY_Q)
            {
                if (_focusedWindow)
                    unmanageWindow(_focusedWindow);
                return true;
            }

            // Super+M - maximize/restore
            if (key == KeyCode.KEY_M)
            {
                if (_focusedWindow)
                    toggleMaximize(_focusedWindow);
                return true;
            }

            // Super+F - fullscreen
            if (key == KeyCode.KEY_F)
            {
                if (_focusedWindow)
                    toggleFullscreen(_focusedWindow);
                return true;
            }

            // Super+Space - toggle floating
            if (key == KeyCode.SPACE)
            {
                if (_focusedWindow)
                    toggleFloating(_focusedWindow);
                return true;
            }

            // Super+Left/Right - tile
            if (key == KeyCode.LEFT)
            {
                if (_focusedWindow)
                    tileLeft(_focusedWindow);
                return true;
            }
            if (key == KeyCode.RIGHT)
            {
                if (_focusedWindow)
                    tileRight(_focusedWindow);
                return true;
            }

            // Super+1-9 - switch workspace
            if (key >= KeyCode.KEY_1 && key <= KeyCode.KEY_9)
            {
                int workspace = key - KeyCode.KEY_1;
                if (event.flags & KeyFlag.Shift)
                {
                    // Move window to workspace
                    if (_focusedWindow)
                        moveWindowToWorkspace(_focusedWindow, workspace);
                }
                else
                {
                    // Switch to workspace
                    switchToWorkspace(workspace);
                }
                return true;
            }
        }

        return super.onKeyEvent(event);
    }
}
