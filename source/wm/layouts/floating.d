module dowel.wm.layouts.floating;

import dlangui.core.types;
import std.algorithm;
import std.array;

import dowel.wm.manager;

/// Floating window layout - windows can be freely positioned
class FloatingLayout : IWindowLayout
{
private:
    ManagedWindow[] _windows;
    Rect _workArea;

public:
    this()
    {
        _windows = [];
    }

    /// Arrange windows in floating layout
    override void arrange(ManagedWindow[] windows, Rect area)
    {
        _workArea = area;

        // In floating layout, windows maintain their own positions
        // We just ensure they're within the work area if needed
        foreach (window; windows)
        {
            if (window.isFloating)
            {
                // Ensure window is at least partially visible
                ensureVisible(window);
            }
        }
    }

    /// Add a window to the layout
    override void addWindow(ManagedWindow window)
    {
        if (!_windows.canFind(window))
        {
            _windows ~= window;

            // Set initial position for new windows
            if (window.geometry.width == 0 || window.geometry.height == 0)
            {
                // Default size: 60% of work area
                int width = cast(int)(_workArea.width * 0.6);
                int height = cast(int)(_workArea.height * 0.6);

                // Center the window
                int x = _workArea.left + (_workArea.width - width) / 2;
                int y = _workArea.top + (_workArea.height - height) / 2;

                // Cascade windows if multiple windows exist
                int offset = cast(int)(_windows.length - 1) * 30;
                x += offset;
                y += offset;

                // Ensure we don't go off screen
                if (x + width > _workArea.right)
                    x = _workArea.left + 30;
                if (y + height > _workArea.bottom)
                    y = _workArea.top + 30;

                window.geometry = Rect(x, y, x + width, y + height);
            }

            window.isFloating = true;
        }
    }

    /// Remove a window from the layout
    override void removeWindow(ManagedWindow window)
    {
        _windows = _windows.filter!(w => w != window).array;
    }

    /// Focus next window
    override void focusNext()
    {
        // Floating layout doesn't control focus order
        // This is handled by the window manager
    }

    /// Focus previous window
    override void focusPrevious()
    {
        // Floating layout doesn't control focus order
        // This is handled by the window manager
    }

    /// Get layout name
    override string name() const
    {
        return "floating";
    }

private:
    /// Ensure window is at least partially visible on screen
    void ensureVisible(ManagedWindow window)
    {
        const int minVisible = 50; // Minimum pixels that must be visible

        // Check if window is completely off screen
        if (window.geometry.right < _workArea.left + minVisible)
        {
            // Move window so at least minVisible pixels are on screen
            int width = window.geometry.width;
            window.geometry.left = _workArea.left + minVisible - width;
            window.geometry.right = _workArea.left + minVisible;
        }
        else if (window.geometry.left > _workArea.right - minVisible)
        {
            // Move window so at least minVisible pixels are on screen
            int width = window.geometry.width;
            window.geometry.left = _workArea.right - minVisible;
            window.geometry.right = _workArea.right - minVisible + width;
        }

        if (window.geometry.bottom < _workArea.top + minVisible)
        {
            // Move window so at least minVisible pixels are on screen
            int height = window.geometry.height;
            window.geometry.top = _workArea.top + minVisible - height;
            window.geometry.bottom = _workArea.top + minVisible;
        }
        else if (window.geometry.top > _workArea.bottom - minVisible)
        {
            // Move window so at least minVisible pixels are on screen
            int height = window.geometry.height;
            window.geometry.top = _workArea.bottom - minVisible;
            window.geometry.bottom = _workArea.bottom - minVisible + height;
        }

        // Ensure title bar is visible (if window has decoration)
        if (window.decoration && window.geometry.top < _workArea.top)
        {
            int height = window.geometry.height;
            window.geometry.top = _workArea.top;
            window.geometry.bottom = _workArea.top + height;
        }
    }
}
