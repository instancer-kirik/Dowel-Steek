module dowel.wm.decorations;

import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.styles;
import dlangui.platforms.common.platform;
import dlangui.core.events;
import dlangui.core.types;

import std.conv;
import std.stdio;

import dowel.core.config;
import dowel.wm.manager : ManagedWindow;

/// Window decoration style
enum DecorationStyle
{
    Normal,
    Minimal,
    None
}

/// Resize handle positions
enum ResizeHandle
{
    None = 0,
    Top = 1,
    Bottom = 2,
    Left = 4,
    Right = 8,
    TopLeft = Top | Left,
    TopRight = Top | Right,
    BottomLeft = Bottom | Left,
    BottomRight = Bottom | Right
}

/// Window decoration widget
class WindowDecoration : FrameLayout
{
    // Introduce base class overload set for style property
    alias style = Widget.style;

private:
    ManagedWindow _window;
    Widget _titleBar;
    TextWidget _titleLabel;
    HorizontalLayout _buttonBox;
    ImageButton _closeButton;
    ImageButton _maximizeButton;
    ImageButton _minimizeButton;
    Widget _contentArea;
    DecorationStyle _style;
    bool _isFocused;
    int _borderWidth;
    uint _borderColorActive;
    uint _borderColorInactive;

    // Resize handles
    ResizeHandle _activeHandle;
    bool _isResizing;
    Point _resizeStartPos;
    Rect _resizeStartGeometry;

    // Move state
    bool _isMoving;
    Point _moveStartPos;

public:
    /// Close button clicked
    void delegate() onClose;

    /// Maximize button clicked
    void delegate() onMaximize;

    /// Minimize button clicked
    void delegate() onMinimize;

    /// Window move requested
    void delegate(Point delta) @safe onMove;

    /// Window resize requested
    void delegate(Size delta) @safe onResize;

    // Declare Size struct if not available
    struct Size
    {
        int width;
        int height;
    }

    this(ManagedWindow window)
    {
        super("windowDecoration");
        _window = window;
        _style = DecorationStyle.Normal;

        auto config = ConfigManager.instance();
        _borderWidth = config.wm.borderWidth;
        _borderColorActive = parseColor(config.wm.borderColorActive);
        _borderColorInactive = parseColor(config.wm.borderColorInactive);

        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;

        createDecoration();
    }

    private void createDecoration()
    {
        // Main container
        auto container = new VerticalLayout();
        container.layoutWidth = FILL_PARENT;
        container.layoutHeight = FILL_PARENT;

        // Title bar
        _titleBar = createTitleBar();
        container.addChild(_titleBar);

        // Content area with border
        auto borderContainer = new FrameLayout();
        borderContainer.layoutWidth = FILL_PARENT;
        borderContainer.layoutHeight = FILL_PARENT;
        borderContainer.backgroundColor = _borderColorInactive;
        borderContainer.padding(Rect(_borderWidth, 0, _borderWidth, _borderWidth));

        _contentArea = new FrameLayout();
        _contentArea.layoutWidth = FILL_PARENT;
        _contentArea.layoutHeight = FILL_PARENT;

        if (_window && _window.contentWidget)
        {
            _contentArea.addChild(_window.contentWidget);
        }

        borderContainer.addChild(_contentArea);
        container.addChild(borderContainer);

        addChild(container);
    }

    private Widget createTitleBar()
    {
        auto titleBar = new HorizontalLayout("titleBar");
        titleBar.layoutWidth = FILL_PARENT;
        titleBar.layoutHeight = WRAP_CONTENT;
        titleBar.backgroundColor = 0x2D2D2D;
        titleBar.padding(Rect(4, 4, 4, 4));

        // Window icon (placeholder)
        auto icon = new ImageWidget();
        icon.layoutWidth = 16;
        icon.layoutHeight = 16;
        icon.margins(Rect(2, 2, 4, 2));
        titleBar.addChild(icon);

        // Title text
        _titleLabel = new TextWidget();
        _titleLabel.text = _window ? to!dstring(_window.title) : "Window"d;
        _titleLabel.textColor = 0xFFFFFF;
        _titleLabel.layoutWidth = FILL_PARENT;
        _titleLabel.layoutHeight = WRAP_CONTENT;
        _titleLabel.alignment = Align.Left | Align.VCenter;
        titleBar.addChild(_titleLabel);

        // Window buttons
        _buttonBox = new HorizontalLayout();
        _buttonBox.layoutWidth = WRAP_CONTENT;
        _buttonBox.layoutHeight = WRAP_CONTENT;

        // Minimize button
        _minimizeButton = new ImageButton();
        _minimizeButton.layoutWidth = 20;
        _minimizeButton.layoutHeight = 20;
        _minimizeButton.backgroundColor = 0x404040;
        _minimizeButton.margins(Rect(2, 0, 2, 0));
        _minimizeButton.click = delegate(Widget src) {
            if (onMinimize)
                onMinimize();
            return true;
        };
        _buttonBox.addChild(_minimizeButton);

        // Maximize button
        _maximizeButton = new ImageButton();
        _maximizeButton.layoutWidth = 20;
        _maximizeButton.layoutHeight = 20;
        _maximizeButton.backgroundColor = 0x404040;
        _maximizeButton.margins(Rect(2, 0, 2, 0));
        _maximizeButton.click = delegate(Widget src) {
            if (onMaximize)
                onMaximize();
            return true;
        };
        _buttonBox.addChild(_maximizeButton);

        // Close button
        _closeButton = new ImageButton();
        _closeButton.layoutWidth = 20;
        _closeButton.layoutHeight = 20;
        _closeButton.backgroundColor = 0xC04040;
        _closeButton.click = delegate(Widget src) {
            if (onClose)
                onClose();
            return true;
        };
        _buttonBox.addChild(_closeButton);

        titleBar.addChild(_buttonBox);

        // Handle title bar mouse events for moving
        titleBar.mouseEvent = &handleTitleBarMouse;

        return titleBar;
    }

    private bool handleTitleBarMouse(Widget source, MouseEvent event)
    {
        if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Left)
        {
            // Start window move
            _isMoving = true;
            _moveStartPos = Point(event.x, event.y);

            // Handle double-click for maximize
            static long lastClickTime = 0;
            long currentTime = currentTimeMillis();
            if (currentTime - lastClickTime < 300) // Double-click threshold
            {
                if (onMaximize)
                    onMaximize();
                _isMoving = false;
            }
            lastClickTime = currentTime;

            return true;
        }
        else if (event.action == MouseAction.Move && _isMoving)
        {
            // Calculate delta and request move
            Point delta = Point(event.x - _moveStartPos.x, event.y - _moveStartPos.y);
            if (onMove)
                onMove(delta);
            _moveStartPos = Point(event.x, event.y);
            return true;
        }
        else if (event.action == MouseAction.ButtonUp)
        {
            _isMoving = false;
            return true;
        }

        return false;
    }

    /// Set focused state
    void setFocused(bool focused)
    {
        _isFocused = focused;
        updateBorderColor();

        // Update title bar appearance
        if (_titleBar)
        {
            _titleBar.backgroundColor = focused ? 0x4080FF : 0x2D2D2D;
        }
    }

    /// Update window title
    void setTitle(string title)
    {
        if (_titleLabel)
        {
            _titleLabel.text = to!dstring(title);
        }
    }

    /// Show or hide decoration
    void showDecoration()
    {
        _titleBar.visibility = Visibility.Visible;
        updateBorderWidth(_borderWidth);
    }

    void hideDecoration()
    {
        _titleBar.visibility = Visibility.Gone;
        updateBorderWidth(0);
    }

    /// Get decoration style
    @property DecorationStyle style() const
    {
        return _style;
    }

    /// Set decoration style
    @property void style(DecorationStyle value)
    {
        _style = value;
        updateDecorationStyle();
    }

    private void updateDecorationStyle()
    {
        switch (_style)
        {
        case DecorationStyle.Normal:
            _titleBar.visibility = Visibility.Visible;
            _buttonBox.visibility = Visibility.Visible;
            updateBorderWidth(_borderWidth);
            break;

        case DecorationStyle.Minimal:
            _titleBar.visibility = Visibility.Visible;
            _buttonBox.visibility = Visibility.Gone;
            updateBorderWidth(1);
            break;

        case DecorationStyle.None:
            _titleBar.visibility = Visibility.Gone;
            updateBorderWidth(0);
            break;

        default:
            break;
        }
    }

    private void updateBorderColor()
    {
        uint color = _isFocused ? _borderColorActive : _borderColorInactive;

        // Find border container and update color
        Widget container = child(0);
        if (container && container.childCount > 1)
        {
            Widget borderContainer = container.child(1);
            if (borderContainer)
            {
                borderContainer.backgroundColor = color;
            }
        }
    }

    private void updateBorderWidth(int width)
    {
        // Find border container and update padding
        Widget container = child(0);
        if (container && container.childCount > 1)
        {
            Widget borderContainer = container.child(1);
            if (borderContainer)
            {
                borderContainer.padding(Rect(width, 0, width, width));
            }
        }
    }

    override bool onMouseEvent(MouseEvent event)
    {
        // Check for resize handles
        if (_style != DecorationStyle.None && _borderWidth > 0)
        {
            Point pt = Point(event.x, event.y);
            Rect bounds = pos;

            if (event.action == MouseAction.Move && !_isResizing)
            {
                // Determine which resize handle we're over
                ResizeHandle handle = getResizeHandle(pt, bounds);
                updateCursor(handle);
            }
            else if (event.action == MouseAction.ButtonDown && event.button == MouseButton.Left)
            {
                ResizeHandle handle = getResizeHandle(pt, bounds);
                if (handle != ResizeHandle.None)
                {
                    _isResizing = true;
                    _activeHandle = handle;
                    _resizeStartPos = pt;
                    _resizeStartGeometry = bounds;
                    return true;
                }
            }
            else if (event.action == MouseAction.Move && _isResizing)
            {
                // Calculate resize delta based on handle
                Size delta = calculateResizeDelta(pt, _resizeStartPos, _activeHandle);
                if (onResize)
                    onResize(delta);
                return true;
            }
            else if (event.action == MouseAction.ButtonUp)
            {
                _isResizing = false;
                _activeHandle = ResizeHandle.None;
                updateCursor(ResizeHandle.None);
            }
        }

        return super.onMouseEvent(event);
    }

    private ResizeHandle getResizeHandle(Point pt, Rect bounds)
    {
        const int edge = 8; // Resize handle size

        ResizeHandle handle = ResizeHandle.None;

        // Check edges
        if (pt.x < bounds.left + edge)
            handle |= ResizeHandle.Left;
        else if (pt.x > bounds.right - edge)
            handle |= ResizeHandle.Right;

        if (pt.y < bounds.top + edge)
            handle |= ResizeHandle.Top;
        else if (pt.y > bounds.bottom - edge)
            handle |= ResizeHandle.Bottom;

        return handle;
    }

    private void updateCursor(ResizeHandle handle)
    {
        // Update cursor based on resize handle
        CursorType cursor = CursorType.Arrow;

        switch (handle)
        {
        case ResizeHandle.Top:
        case ResizeHandle.Bottom:
            cursor = CursorType.SizeNS;
            break;

        case ResizeHandle.Left:
        case ResizeHandle.Right:
            cursor = CursorType.SizeWE;
            break;

        case ResizeHandle.TopLeft:
        case ResizeHandle.BottomRight:
            cursor = CursorType.SizeNWSE;
            break;

        case ResizeHandle.TopRight:
        case ResizeHandle.BottomLeft:
            cursor = CursorType.SizeNESW;
            break;

        default:
            break;
        }

        // Note: DlangUI cursor setting would go here
        // Platform.instance.setCursor(cursor);
    }

    private Size calculateResizeDelta(Point current, Point start, ResizeHandle handle)
    {
        Size delta;

        if (handle & ResizeHandle.Right)
            delta.width = current.x - start.x;
        else if (handle & ResizeHandle.Left)
            delta.width = start.x - current.x;

        if (handle & ResizeHandle.Bottom)
            delta.height = current.y - start.y;
        else if (handle & ResizeHandle.Top)
            delta.height = start.y - current.y;

        return delta;
    }

    private uint parseColor(string colorStr)
    {
        if (colorStr.length == 0)
            return 0x808080;

        if (colorStr[0] == '#')
            colorStr = colorStr[1 .. $];

        try
        {
            return cast(uint) to!ulong(colorStr, 16) | 0xFF000000;
        }
        catch (Exception e)
        {
            return 0x808080;
        }
    }
}

/// Window decoration for frameless windows
class FramelessDecoration : FrameLayout
{
    private ManagedWindow _window;
    private Widget _contentArea;

    this(ManagedWindow window)
    {
        super("framelessDecoration");
        _window = window;

        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;

        _contentArea = new FrameLayout();
        _contentArea.layoutWidth = FILL_PARENT;
        _contentArea.layoutHeight = FILL_PARENT;

        if (_window && _window.contentWidget)
        {
            _contentArea.addChild(_window.contentWidget);
        }

        addChild(_contentArea);
    }
}
