module D;

import dlangui;
import dlangui.widgets.lists;
import dlangui.widgets.controls;
import dlangui.widgets.layouts;
import dlangui.platforms.common.platform : Platform, Window;
import dlangui.widgets.menu : PopupMenu;
import dlangui.widgets.widget;
import dlangui.dialogs.dialog : Dialog, DialogFlag, DialogResultHandler;
import dlangui.core.types : Point, Rect;
import dlangui.platforms.sdl.sdlapp : SDLPlatform;
import std.format : format;
import std.conv : to;
import std.array : join;
import std.stdio;
import std.file;
import std.path;
import notes.vault;
import editor;
import notes.note;
import bindbc.sdl;
import vibe.d;  // We'll need to add vibe.d to dub.json
import std.math : sqrt, abs, isClose;
import dlangui.widgets.menu;
import dlangui.core.events;
import dlangui.widgets.scrollbar;  // For scrolling
import dlangui.widgets.editors;    // For EditLine
import dlangui.widgets.lists;      // For ListWidget
import std.algorithm : filter, min, max;      // For filtering suggestions
import std.array : array;          // For array operations
import core.memory : GC;           // For memory stats
import std.system : os;  // For OS info
import std.process : environment;  // For environment info
import dlangui.graphics.fonts;  // Add missing font imports
import dlangui.core.signals;    // For signal handling
import dlangui.widgets.editors : EditWidgetBase;  // For edit widget base
import dlangui.widgets.controls : TextWidget;     // For text widget
import bridge.bridge_window;  // Add this import


// Import our taskbar components
import taskbar;

// Use platform-specific mixin
version(Windows) {
    import dlangui.platforms.windows.platform;
    mixin WINDOWS_APP_ENTRY_POINT;
} else {
    import dlangui.platforms.common.platform : APP_ENTRY_POINT;
    mixin APP_ENTRY_POINT;
}

// Extend TileLayout enum with more specific layouts
enum TileLayout {
    Horizontal,
    Vertical,
    Grid,
    Stacked,
    QuadrantSplit,
    MainPlusSidebar
}

// Add a SnapZone struct to handle window snapping
struct SnapZone {
    Rect bounds;
    float attractionStrength;  // How strongly windows snap to this zone
    bool isOccupied;
}

class TileContainer : VerticalLayout {
    private Window[] windows;
    private TileLayout currentLayout = TileLayout.Grid;
    private SnapZone[] snapZones;
    
    this() {
        super("workspace");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        backgroundColor = 0x2D2D2D;
        updateSnapZones();
    }

    private void updateSnapZones() {
        snapZones = [];
        
        // Get container dimensions
        int width = pos.width;
        int height = pos.height;
        
        // Create edge snap zones
        snapZones ~= SnapZone(Rect(0, 0, width/2, height), 0.8f);           // Left half
        snapZones ~= SnapZone(Rect(width/2, 0, width, height), 0.8f);       // Right half
        snapZones ~= SnapZone(Rect(0, 0, width, height/2), 0.8f);          // Top half
        snapZones ~= SnapZone(Rect(0, height/2, width, height), 0.8f);     // Bottom half
        
        // Create quadrant snap zones
        snapZones ~= SnapZone(Rect(0, 0, width/2, height/2), 0.6f);        // Top-left
        snapZones ~= SnapZone(Rect(width/2, 0, width, height/2), 0.6f);    // Top-right
        snapZones ~= SnapZone(Rect(0, height/2, width/2, height), 0.6f);   // Bottom-left
        snapZones ~= SnapZone(Rect(width/2, height/2, width, height), 0.6f); // Bottom-right
    }

    void addWindow(Window win) {
        if (!win || !win.mainWidget) return;
        
        windows ~= win;
        addChild(win.mainWidget);
        
        // Use proper DlangUI event handling
        win.mainWidget.mouseEvent = &handleMouseEvent;
        
        requestLayout();
    }

    // Combined mouse event handler
    private bool handleMouseEvent(Widget src, MouseEvent evt) {
        switch(evt.action) {
            case MouseAction.ButtonDown:
                if (evt.button == MouseButton.Left) {
                    src.setMouseCapture();
                    return true;
                }
                break;
            case MouseAction.ButtonUp:
                if (evt.button == MouseButton.Left) {
                    src.releaseMouseCapture();
                    return true;
                }
                break;
            case MouseAction.Move:
                if (evt.button == MouseButton.Left) {
                    auto winRect = src.window.windowRect;
                    auto newPos = Point(
                        winRect.left + evt.x - evt.x0,
                        winRect.top + evt.y - evt.y0
                    );
                    
                    // Check snap zones
                    foreach(zone; snapZones) {
                        if (!zone.isOccupied && checkSnapZone(winRect, zone)) {
                            newPos = snapToZone(winRect, zone).topLeft;
                            break;
                        }
                    }
                    
                    src.window.moveWindow(newPos);
                    return true;
                }
                break;
            default:
                break;
        }
        return false;
    }

    // Update snap zone check to use float comparison
    private bool checkSnapZone(Rect winRect, SnapZone zone) {
        immutable float threshold = 20.0f;  // pixels
        return isClose(cast(float)winRect.left, cast(float)zone.bounds.left, threshold) ||
               isClose(cast(float)winRect.right, cast(float)zone.bounds.right, threshold) ||
               isClose(cast(float)winRect.top, cast(float)zone.bounds.top, threshold) ||
               isClose(cast(float)winRect.bottom, cast(float)zone.bounds.bottom, threshold);
    }

    // Add method to switch layouts
    void switchToLayout(int index) {
        if (index >= 0 && index < TileLayout.max + 1) {
            setLayout(cast(TileLayout)index);
        }
    }

    // Make setLayout public
    void setLayout(TileLayout layout) {
        currentLayout = layout;
        
        final switch(layout) {
            case TileLayout.Horizontal:
                layoutHorizontal();
                break;
            case TileLayout.Vertical:
                layoutVertical();
                break;
            case TileLayout.Grid:
                layoutGrid();
                break;
            case TileLayout.Stacked:
                layoutStacked();
                break;
            case TileLayout.QuadrantSplit:
                layoutQuadrants();
                break;
            case TileLayout.MainPlusSidebar:
                layoutMainSidebar();
                break;
        }
        
        requestLayout();
    }

    // Fix layout methods with proper type conversions
    private void layoutHorizontal() {
        if (windows.length == 0) return;
        
        int width = cast(int)(pos.width / windows.length);
        foreach(i, win; windows) {
            win.moveWindow(Point(cast(int)(i) * width, 0));
            win.moveAndResizeWindow(Rect(cast(int)(i) * width, 0, cast(int)(i) * width + width, pos.height));
        }
    }

    private void layoutVertical() {
        if (windows.length == 0) return;
        
        int height = cast(int)(pos.height / windows.length);
        foreach(i, win; windows) {
            win.moveWindow(Point(0, cast(int)(i) * height));
            win.moveAndResizeWindow(Rect(0, cast(int)(i) * height, pos.width, cast(int)(i) * height + height));
        }
    }

    private void layoutGrid() {
        if (windows.length == 0) return;
        
        int cols = cast(int)sqrt(cast(float)windows.length);
        int rows = cast(int)((windows.length + cols - 1) / cols);
        
        int cellWidth = pos.width / cols;
        int cellHeight = pos.height / rows;
        
        foreach(i, win; windows) {
            int row = cast(int)(i / cols);
            int col = cast(int)(i % cols);
            win.moveAndResizeWindow(Rect(col * cellWidth, row * cellHeight, 
                                       col * cellWidth + cellWidth, 
                                       row * cellHeight + cellHeight));
        }
    }

    private void layoutStacked() {
        foreach(win; windows) {
            win.moveAndResizeWindow(Rect(0, 0, pos.width, pos.height));
        }
    }

    private void layoutQuadrants() {
        if (windows.length == 0) return;
        
        int halfWidth = pos.width / 2;
        int halfHeight = pos.height / 2;
        
        foreach(i, win; windows[0 .. min($, 4)]) {
            Point pos;
            final switch(cast(int)i) {
                case 0: pos = Point(0, 0); break;
                case 1: pos = Point(halfWidth, 0); break;
                case 2: pos = Point(0, halfHeight); break;
                case 3: pos = Point(halfWidth, halfHeight); break;
            }
            win.moveAndResizeWindow(Rect(pos.x, pos.y, 
                                       pos.x + halfWidth, 
                                       pos.y + halfHeight));
        }
    }

    private void layoutMainSidebar() {
        if (windows.length == 0) return;
        
        int mainWidth = (pos.width * 3) / 4;
        int sideWidth = pos.width - mainWidth;
        
        if (windows.length >= 1) {
            windows[0].moveAndResizeWindow(Rect(0, 0, mainWidth, pos.height));
        }
        
        int sideHeight = cast(int)(pos.height / max(1, windows.length - 1));
        foreach(i, win; windows[1 .. $]) {
            win.moveAndResizeWindow(Rect(mainWidth, cast(int)(i) * sideHeight,
                                       pos.width, cast(int)(i) * sideHeight + sideHeight));
        }
    }
}
class NotesVaultWindow : Window {
    private VaultManager vaultManager;
    private ListWidget notesList;
    private ListWidget tagsList;
    private dstring _windowCaption = "Notes"d;

    this() {
        super();
        
        try {
            // Create main layout
            auto mainLayout = new VerticalLayout();
            mainLayout.layoutWidth = FILL_PARENT;
            mainLayout.layoutHeight = FILL_PARENT;
            mainLayout.backgroundColor = 0xFFFFFF;
            mainLayout.padding(Rect(10, 10, 10, 10));
            
            // Initialize vault manager
            vaultManager = new VaultManager();
            
            // Add content
            auto label = new TextWidget(null, "Notes Window"d);
            label.textColor = 0x000000;
            mainLayout.addChild(label);
            
            // Set main widget
            mainWidget = mainLayout;
            
            // Set font - use addFontFace instead of registerFont
            FontManager.instance.addFontFace("monospace", FontFamily.MonoSpace);
            
        } catch (Exception e) {
            Log.e("NotesVaultWindow init error: ", e.msg);
        }
    }

    override void show() {
        try {
            // Create window with proper flags
            auto window = Platform.instance.createWindow(windowCaption, null,
                WindowFlag.Resizable,
                600, 400);
            
            if (!window) {
                Log.e("Failed to create notes window");
                return;
            }
            
            // Set up main widget
        if (mainWidget) {
                window.mainWidget = mainWidget;
            mainWidget.invalidate();
        }
            
            window.show();
            
        } catch (Exception e) {
            Log.e("Show notes window error: ", e.msg);
        }
    }

    override void invalidate() {
        if (mainWidget)
            mainWidget.invalidate();
    }

    override void close() {
        if (mainWidget)
            mainWidget.removeAllChildren();
        Platform.instance.closeWindow(this);
    }

    override @property dstring windowCaption() const {
        return _windowCaption;
    }
    
    override @property void windowCaption(dstring caption) {
        _windowCaption = caption;
    }
    
    override @property void windowIcon(DrawBufRef icon) {
        // Optional: implement icon support
    }
}

// Main desktop environment window
class DesktopWindow : Window {
    private TileContainer workspace;
    private TaskBar taskBar;
    private MenuItem startMenu;
    private Window[] windows;
    private ulong demoWindowTimerId;  // Store timer ID
    
    private void delegate() _onShowHandler;
    
    this() {
        super();
        
        try {
            // Create layouts first
        auto mainLayout = new VerticalLayout();
        mainLayout.layoutWidth = FILL_PARENT;
        mainLayout.layoutHeight = FILL_PARENT;
            mainLayout.backgroundColor = 0x2D2D2D;
        
        // Create workspace
        workspace = new TileContainer();
        workspace.layoutWidth = FILL_PARENT;
        workspace.layoutHeight = FILL_PARENT;
        workspace.backgroundColor = 0x2D2D2D;
        
        // Create taskbar
        taskBar = new TaskBar(&onStartMenuClick);
        
            // Add components in order
        mainLayout.addChild(workspace);
        mainLayout.addChild(taskBar);
            
            // Set main widget
        mainWidget = mainLayout;
        
            // Initialize start menu
            setupStartMenu();
            
        } catch (Exception e) {
            Log.e("DesktopWindow init error: ", e.msg);
        }
    }

    override void show() {
        try {
            // Set theme before window creation
            Platform.instance.uiTheme = "theme_default";
            
            // Create window with basic flags first
            auto window = Platform.instance.createWindow(windowCaption, null, 
                WindowFlag.Resizable,  // Remove Modal flag for main window
                1024, 768);
            
            if (!window) {
                Log.e("Failed to create window");
                return;
            }
            
            // Set up main widget
            if (mainWidget) {
                window.mainWidget = mainWidget;
                mainWidget.visibility = Visibility.Visible;
                mainWidget.invalidate();
            }
            
            // Show window
            window.show();
            
            // Create initial demo window after a short delay
            mainWidget.setTimer(50);
            
        } catch (Exception e) {
            Log.e("Show error: ", e.msg);
        }
    }

    private bool createDemoWindow() {
        try {
            auto note = new NotesVaultWindow();
            note.show();
            
            // Add to collections
            windows ~= note;
            workspace.addWindow(note);
            taskBar.addWindowButton(note);
            
        } catch (Exception e) {
            Log.e("Demo window creation error: ", e.msg);
        }
        return false; // Don't repeat timer
    }
    
    private void setupStartMenu() {
        startMenu = new MenuItem(null);
        startMenu.add(new Action(1, "Notes"d, null, KeyCode.KEY_N, KeyFlag.Control));
        startMenu.add(new Action(2, "Bridge"d, null, KeyCode.KEY_B, KeyFlag.Control));  // Add Bridge
        startMenu.add(new Action(3, "Settings"d));
        startMenu.addSeparator();
        startMenu.add(new Action(4, "Exit"d));
        startMenu.add(new Action(5, "Terminal"d, null, KeyCode.KEY_T, KeyFlag.Control | KeyFlag.Shift));
        startMenu.menuItemAction = &onStartMenuAction;
    }
    
    private bool onStartMenuClick(Widget w) {
        Log.d("Start menu clicked");
        auto menu = new PopupMenu(startMenu);
        auto pt = Point(w.pos.left, w.pos.bottom);
        this.showPopup(menu, w, PopupAlign.Below);
        return true;
    }
    
    private bool onStartMenuAction(const Action action) {
        Log.d("Menu action: ", action.id);
        switch(action.id) {
            case 1: // Notes
                auto note = new NotesVaultWindow();
                note.show();
                addWindow(note);
                break;
            case 2: // Bridge
                auto bridge = new BridgeWindow();
                bridge.show();
                addWindow(bridge);
                break;
            case 3: // Settings
                // TODO: Show settings
                break;
            case 4: // Exit
                Platform.instance.closeWindow(this);
                break;
            case 5: // Terminal
                createTerminal();
                break;
            default:
                return false;
        }
        return true;
    }
    
    private bool onKeyEvent(Widget source, KeyEvent event) {
        if (event.action == KeyAction.KeyDown) {
            // Window management shortcuts
            if (event.flags & KeyFlag.Control) {
                switch(event.keyCode) {
                    case KeyCode.KEY_1: .. case KeyCode.KEY_9:
                        // Switch to workspace
                        workspace.switchToLayout(event.keyCode - KeyCode.KEY_1);
                        return true;
                    case KeyCode.KEY_H:
                        workspace.setLayout(TileLayout.Horizontal);
                        return true;
                    case KeyCode.KEY_V:
                        workspace.setLayout(TileLayout.Vertical);
                        return true;
                    case KeyCode.KEY_G:  // Changed from T to G for Grid
                        workspace.setLayout(TileLayout.Grid);
                        return true;
                    default:
                        break;
                }
            }
        }
        return false;
    }
    
    void addWindow(Window win) {
        if (!win) return;
        
        try {
            // Add to collections
        windows ~= win;
        workspace.addWindow(win);
        taskBar.addWindowButton(win);
            
        } catch (Exception e) {
            Log.e("Add window error: ", e.msg);
        }
    }

    override void close() {
        // Cancel timer if still active
        if (demoWindowTimerId && mainWidget) {
            mainWidget.cancelTimer(demoWindowTimerId);
            demoWindowTimerId = 0;
        }
        
        // Clean up windows first
        foreach(win; windows) {
            if (win) {
                win.close();
            }
        }
        windows.length = 0;
        
        // Clean up workspace
        if (workspace) {
            workspace.removeAllChildren();
        }
        
        // Clean up taskbar
        if (taskBar) {
            taskBar.removeAllChildren();
        }
        
        // Clean up start menu
        if (startMenu) {
            startMenu.clear();
        }
        
        // Finally close the window
        Platform.instance.closeWindow(this);
    }

    override void invalidate() {
        if (mainWidget)
            mainWidget.invalidate();
    }

    override @property dstring windowCaption() const {
        return "Desktop"d;
    }

    override @property void windowCaption(dstring caption) {
        // Implementation if needed
    }

    override @property void windowIcon(DrawBufRef icon) {
        // Implementation if needed
    }

    // Add method to handle window context menu
    private void showWindowContextMenu(Window win, Point pt) {
        auto menuItem = new MenuItem(null);
        menuItem.add(new Action(10001, "Flip Window"d));
        auto menu = new PopupMenu(menuItem);
        menu.menuItemAction = (const Action action) {
            if (action.id == 10001) {
                flipWindow(win);
                return true;
            }
            return false;
        };
        this.showPopup(menu, null, PopupAlign.Point, pt.x, pt.y);
    }

    private void flipWindow(Window win) {
        if (!win) return;
        
        // Get current window position and size
        Rect currentPos = win.windowRect;
        
        // Calculate flipped position (rotate 180 degrees around center)
        int centerX = currentPos.left + currentPos.width / 2;
        int centerY = currentPos.top + currentPos.height / 2;
        
        // Create flipped rectangle
        Rect flippedPos = Rect(
            centerX - (currentPos.right - centerX),
            centerY - (currentPos.bottom - centerY),
            centerX + (centerX - currentPos.left),
            centerY + (centerY - currentPos.top)
        );
        
        // Animate the flip
        win.moveAndResizeWindow(flippedPos, true);
    }

    private void createTerminal() {
        auto win = new TerminalWindow();
        win.show();
    }
}

class TerminalWindow : Window {
    // Implement abstract methods
    override void show() { /* ... */ }
    override void close() { /* ... */ }
    override void invalidate() { /* ... */ }
    override @property dstring windowCaption() const { return "Terminal"d; }
    override @property void windowCaption(dstring caption) { }
    override @property void windowIcon(DrawBufRef icon) { }
}

class InteractiveTerminal : VerticalLayout {
    private EditLine inputLine;
    private TextWidget outputArea;
    private ListWidget suggestionList;
    private string[] commandHistory;
    private string[] suggestions;
    private int historyIndex = -1;

    this() {
        super("terminal");
        backgroundColor = 0x1E1E1E;
        padding(Rect(8, 8, 8, 8));
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;

        // Output area with scrolling
        auto scrollArea = new ScrollWidget("scroll");
        scrollArea.layoutWidth = FILL_PARENT;
        scrollArea.layoutHeight = FILL_PARENT;
        
        outputArea = new TextWidget("output", ""d);
        outputArea.textColor = 0xE0E0E0;
        outputArea.backgroundColor = 0x1E1E1E;
        outputArea.layoutWidth = FILL_PARENT;
        outputArea.layoutHeight = WRAP_CONTENT;
        outputArea.fontFace = FontManager.instance.getFaceForFamily("monospace");
        scrollArea.contentWidget = outputArea;
        addChild(scrollArea);

        // Suggestions area
        suggestionList = new ListWidget("suggestions");
        suggestionList.backgroundColor = 0x2D2D2D;
        suggestionList.layoutWidth = FILL_PARENT;
        suggestionList.layoutHeight = WRAP_CONTENT;
        suggestionList.itemClick = &onSuggestionClick;
        suggestionList.visibility = Visibility.Gone;
        addChild(suggestionList);

        // Input line
        auto inputLayout = new HorizontalLayout();
        inputLayout.layoutWidth = FILL_PARENT;
        
        auto prompt = new TextWidget(null, "$ "d);
        prompt.textColor = 0x00FF00;
        inputLayout.addChild(prompt);

        inputLine = new EditLine("input");
        inputLine.layoutWidth = FILL_PARENT;
        inputLine.textColor = 0xE0E0E0;
        inputLine.backgroundColor = 0x2D2D2D;
        inputLine.fontFace = FontManager.instance.getFaceForFamily("monospace");
        inputLine.contentChange = &onInputChange;
        inputLine.keyEvent = &onInputKey;
        inputLayout.addChild(inputLine);

        addChild(inputLayout);

        // Initialize suggestions
        suggestions = [
            "help - Show available commands",
            "clear - Clear terminal output",
            "ls - List files",
            "cd <dir> - Change directory",
            "status - Show system status",
            "connect <device> - Connect to hardware device",
            "scan - Scan for available devices",
            "exit - Close terminal"
        ];
    }

    private bool onInputChange(EditableContent content) {
        string input = to!string(content.text);  // Convert dstring to string properly
        updateSuggestions(input);
        return true;
    }

    private void updateSuggestions(string input) {
        if (input.length == 0) {
            suggestionList.visibility = Visibility.Gone;
            return;
        }

        // Filter suggestions
        auto filtered = suggestions.filter!(s => s.toLower.startsWith(input.toLower)).array;
        
        if (filtered.length > 0) {
            suggestionList.removeAllChildren();  // Use removeAllChildren instead of clear
            foreach (suggestion; filtered) {
                suggestionList.addChild(new TextWidget(null, to!dstring(suggestion)));
            }
            suggestionList.visibility = Visibility.Visible;
        } else {
            suggestionList.visibility = Visibility.Gone;
        }
        
        requestLayout();
    }

    private bool onSuggestionClick(Widget source, int itemIndex) {
        if (itemIndex >= 0 && itemIndex < suggestionList.itemCount) {
            auto item = cast(TextWidget)suggestionList.itemWidget(itemIndex);
            if (item) {
                string cmd = to!string(item.text);
                cmd = cmd.split(" - ")[0];  // Get just the command part
                inputLine.text = to!dstring(cmd);
                executeCommand(cmd);
                return true;
            }
        }
        return false;
    }

    private bool onInputKey(Widget source, KeyEvent event) {
        if (event.action == KeyAction.KeyDown) {
            switch (event.keyCode) {
                case KeyCode.RETURN:
                    string cmd = inputLine.text.toString();
                    if (cmd.length > 0) {
                        executeCommand(cmd);
                        commandHistory ~= cmd;
                        historyIndex = cast(int)commandHistory.length;
                        inputLine.text = ""d;
                    }
                    return true;

                case KeyCode.UP:
                    if (historyIndex > 0) {
                        historyIndex--;
                        inputLine.text = commandHistory[historyIndex].to!dstring;
                    }
                    return true;

                case KeyCode.DOWN:
                    if (historyIndex < commandHistory.length - 1) {
                        historyIndex++;
                        inputLine.text = commandHistory[historyIndex].to!dstring;
                    } else {
                        historyIndex = cast(int)commandHistory.length;
                        inputLine.text = ""d;
                    }
                    return true;

                default:
                    break;
            }
        }
        return false;
    }

    private void executeCommand(string cmd) {
        // Add command to output with prompt
        appendOutput("$ " ~ cmd);

        // Parse command
        auto parts = cmd.split();
        if (parts.length == 0) return;

        switch (parts[0]) {
            case "help":
                appendOutput("Available commands:");
                foreach (suggestion; suggestions) {
                    appendOutput("  " ~ suggestion);
                }
                break;

            case "clear":
                outputArea.text = ""d;
                break;

            case "ls":
                try {
                    auto entries = dirEntries(".", SpanMode.shallow);
                    foreach (entry; entries) {
                        appendOutput(entry.name);
                    }
                } catch (Exception e) {
                    appendOutput("Error: " ~ e.msg);
                }
                break;

            case "status":
                appendOutput("System Status:");
                appendOutput("  Memory: " ~ to!string(GC.stats().usedSize / 1024) ~ "KB");
                appendOutput("  OS: " ~ os.toString);
                appendOutput("  User: " ~ environment.get("USER", "unknown"));
                appendOutput("  Shell: " ~ environment.get("SHELL", "unknown"));
                appendOutput("  Terminal: " ~ environment.get("TERM", "unknown"));
                break;

            case "scan":
                appendOutput("Scanning for devices...");
                // Simulate device scanning
                appendOutput("Found devices:");
                appendOutput("  - COM1: NRF52840");
                appendOutput("  - COM2: Serial Bridge");
                break;

            case "exit":
                Window.fromWidget(this).close();
                break;

            default:
                appendOutput("Unknown command: " ~ cmd);
                break;
        }
    }

    private void appendOutput(string text) {
        outputArea.text = outputArea.text ~ to!dstring(text) ~ "\n"d;
        // Use scrollTo instead of scrollPosition
        if (auto scrollable = cast(ScrollWidget)outputArea.parent)
            scrollable.scrollTo(0, int.max);
    }
}

// Main entry point
extern (C) int UIAppMain(string[] args) {
    // Initialize SDL and platform
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER | SDL_INIT_EVENTS) < 0) {
        return 1;
    }
    scope(exit) SDL_Quit();

    initLogs();
    Platform.setInstance(new SDLPlatform());
    Platform.instance.uiTheme = "theme_default";
    
    try {
        auto window = new DesktopWindow();
        if (!window) {
            Log.e("Failed to create window");
            return 1;
        }
        
        window.show();
        return Platform.instance.enterMessageLoop();
    } catch (Exception e) {
        Log.e("Error in main loop: ", e.msg);
        return 1;
    }
}