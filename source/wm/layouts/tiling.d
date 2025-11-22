module dowel.wm.layouts.tiling;

import dlangui.core.types;
import std.algorithm;
import std.array;
import std.math;

import dowel.wm.manager;

/// Tiling layout modes
enum TilingMode
{
    /// Main window on left, others stacked on right
    MainLeft,
    /// Main window on right, others stacked on left
    MainRight,
    /// Main window on top, others on bottom
    MainTop,
    /// Main window on bottom, others on top
    MainBottom,
    /// All windows in a grid
    Grid,
    /// Windows in columns
    Columns,
    /// Windows in rows
    Rows
}

/// Tiling window layout - windows are automatically arranged without gaps
class TilingLayout : IWindowLayout
{
private:
    ManagedWindow[] _windows;
    ManagedWindow _mainWindow;
    Rect _workArea;
    TilingMode _mode;
    float _mainRatio; // Ratio of main window (0.0 - 1.0)
    int _mainCount; // Number of windows in main area
    int _gap; // Gap between windows

public:
    this()
    {
        _windows = [];
        _mode = TilingMode.MainLeft;
        _mainRatio = 0.6f;
        _mainCount = 1;
        _gap = 4;
    }

    /// Set tiling mode
    @property void mode(TilingMode value)
    {
        _mode = value;
    }

    /// Get tiling mode
    @property TilingMode mode() const
    {
        return _mode;
    }

    /// Set main window ratio
    @property void mainRatio(float value)
    {
        _mainRatio = clamp(value, 0.1f, 0.9f);
    }

    /// Get main window ratio
    @property float mainRatio() const
    {
        return _mainRatio;
    }

    /// Increase main window ratio
    void increaseMainRatio()
    {
        mainRatio = _mainRatio + 0.05f;
    }

    /// Decrease main window ratio
    void decreaseMainRatio()
    {
        mainRatio = _mainRatio - 0.05f;
    }

    /// Set gap between windows
    @property void gap(int value)
    {
        _gap = max(0, value);
    }

    /// Get gap between windows
    @property int gap() const
    {
        return _gap;
    }

    /// Arrange windows in tiling layout
    override void arrange(ManagedWindow[] windows, Rect area)
    {
        _workArea = area;

        // Filter out floating windows
        auto tiledWindows = windows.filter!(w => !w.isFloating).array;

        if (tiledWindows.length == 0)
            return;

        switch (_mode)
        {
        case TilingMode.MainLeft:
        case TilingMode.MainRight:
            arrangeMainSide(tiledWindows);
            break;

        case TilingMode.MainTop:
        case TilingMode.MainBottom:
            arrangeMainTopBottom(tiledWindows);
            break;

        case TilingMode.Grid:
            arrangeGrid(tiledWindows);
            break;

        case TilingMode.Columns:
            arrangeColumns(tiledWindows);
            break;

        case TilingMode.Rows:
            arrangeRows(tiledWindows);
            break;

        default:
            arrangeMainSide(tiledWindows);
            break;
        }
    }

    /// Add a window to the layout
    override void addWindow(ManagedWindow window)
    {
        if (!_windows.canFind(window))
        {
            _windows ~= window;

            // First window becomes main window
            if (_windows.length == 1)
                _mainWindow = window;

            window.isFloating = false;
        }
    }

    /// Remove a window from the layout
    override void removeWindow(ManagedWindow window)
    {
        _windows = _windows.filter!(w => w != window).array;

        // If main window was removed, select new main
        if (window == _mainWindow && _windows.length > 0)
        {
            _mainWindow = _windows[0];
        }
    }

    /// Focus next window
    override void focusNext()
    {
        if (_windows.length < 2)
            return;

        // Rotate windows array
        auto first = _windows[0];
        _windows = _windows[1 .. $] ~ first;
    }

    /// Focus previous window
    override void focusPrevious()
    {
        if (_windows.length < 2)
            return;

        // Rotate windows array backwards
        auto last = _windows[$ - 1];
        _windows = last ~ _windows[0 .. $ - 1];
    }

    /// Swap with main window
    void swapWithMain(ManagedWindow window)
    {
        if (window && window != _mainWindow)
        {
            _mainWindow = window;
        }
    }

    /// Get layout name
    override string name() const
    {
        return "tiling";
    }

private:
    /// Arrange with main window on side
    void arrangeMainSide(ManagedWindow[] windows)
    {
        if (windows.length == 1)
        {
            // Single window takes full area
            windows[0].geometry = _workArea;
            return;
        }

        bool mainOnLeft = (_mode == TilingMode.MainLeft);
        int mainWidth = cast(int)(_workArea.width * _mainRatio);
        int stackWidth = _workArea.width - mainWidth - _gap;

        // Position main window
        if (_mainWindow && windows.canFind(_mainWindow))
        {
            Rect mainRect;
            if (mainOnLeft)
            {
                mainRect = Rect(_workArea.left, _workArea.top,
                    _workArea.left + mainWidth, _workArea.bottom);
            }
            else
            {
                mainRect = Rect(_workArea.right - mainWidth, _workArea.top,
                    _workArea.right, _workArea.bottom);
            }
            _mainWindow.geometry = mainRect;
        }

        // Position other windows in stack
        auto stackWindows = windows.filter!(w => w != _mainWindow).array;
        if (stackWindows.length > 0)
        {
            int stackX = mainOnLeft ? (_workArea.left + mainWidth + _gap) : _workArea.left;
            int windowHeight = (_workArea.height - _gap * cast(int)(stackWindows.length - 1))
                / cast(int) stackWindows.length;

            foreach (i, window; stackWindows)
            {
                int y = _workArea.top + cast(int)(i) * (windowHeight + _gap);
                window.geometry = Rect(stackX, y, stackX + stackWidth, y + windowHeight);
            }
        }
    }

    /// Arrange with main window on top or bottom
    void arrangeMainTopBottom(ManagedWindow[] windows)
    {
        if (windows.length == 1)
        {
            windows[0].geometry = _workArea;
            return;
        }

        bool mainOnTop = (_mode == TilingMode.MainTop);
        int mainHeight = cast(int)(_workArea.height * _mainRatio);
        int stackHeight = _workArea.height - mainHeight - _gap;

        // Position main window
        if (_mainWindow && windows.canFind(_mainWindow))
        {
            Rect mainRect;
            if (mainOnTop)
            {
                mainRect = Rect(_workArea.left, _workArea.top,
                    _workArea.right, _workArea.top + mainHeight);
            }
            else
            {
                mainRect = Rect(_workArea.left, _workArea.bottom - mainHeight,
                    _workArea.right, _workArea.bottom);
            }
            _mainWindow.geometry = mainRect;
        }

        // Position other windows in row
        auto stackWindows = windows.filter!(w => w != _mainWindow).array;
        if (stackWindows.length > 0)
        {
            int stackY = mainOnTop ? (_workArea.top + mainHeight + _gap) : _workArea.top;
            int windowWidth = (_workArea.width - _gap * cast(int)(stackWindows.length - 1))
                / cast(int) stackWindows.length;

            foreach (i, window; stackWindows)
            {
                int x = _workArea.left + cast(int)(i) * (windowWidth + _gap);
                window.geometry = Rect(x, stackY, x + windowWidth, stackY + stackHeight);
            }
        }
    }

    /// Arrange windows in a grid
    void arrangeGrid(ManagedWindow[] windows)
    {
        int count = cast(int) windows.length;
        if (count == 0)
            return;

        // Calculate grid dimensions
        int cols = cast(int) ceil(sqrt(cast(float) count));
        int rows = (count + cols - 1) / cols;

        int cellWidth = (_workArea.width - _gap * (cols - 1)) / cols;
        int cellHeight = (_workArea.height - _gap * (rows - 1)) / rows;

        foreach (i, window; windows)
        {
            int col = cast(int)(i % cols);
            int row = cast(int)(i / cols);

            int x = _workArea.left + col * (cellWidth + _gap);
            int y = _workArea.top + row * (cellHeight + _gap);

            window.geometry = Rect(x, y, x + cellWidth, y + cellHeight);
        }
    }

    /// Arrange windows in columns
    void arrangeColumns(ManagedWindow[] windows)
    {
        int count = cast(int) windows.length;
        if (count == 0)
            return;

        // Determine number of columns (max 3)
        int cols = min(3, count);
        int windowsPerCol = (count + cols - 1) / cols;

        int colWidth = (_workArea.width - _gap * (cols - 1)) / cols;

        foreach (i, window; windows)
        {
            int col = cast(int)(i / windowsPerCol);
            int indexInCol = cast(int)(i % windowsPerCol);

            // Calculate windows in this column
            int windowsInThisCol = (col == cols - 1) ?
                (count - col * windowsPerCol) : windowsPerCol;

            int windowHeight = (_workArea.height - _gap * (windowsInThisCol - 1)) / windowsInThisCol;

            int x = _workArea.left + col * (colWidth + _gap);
            int y = _workArea.top + indexInCol * (windowHeight + _gap);

            window.geometry = Rect(x, y, x + colWidth, y + windowHeight);
        }
    }

    /// Arrange windows in rows
    void arrangeRows(ManagedWindow[] windows)
    {
        int count = cast(int) windows.length;
        if (count == 0)
            return;

        int windowHeight = (_workArea.height - _gap * (count - 1)) / count;

        foreach (i, window; windows)
        {
            int y = _workArea.top + cast(int)(i) * (windowHeight + _gap);
            window.geometry = Rect(_workArea.left, y, _workArea.right, y + windowHeight);
        }
    }

    /// Clamp value between min and max
    T clamp(T)(T value, T minVal, T maxVal)
    {
        return max(minVal, min(maxVal, value));
    }
}
