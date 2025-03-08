module desktop.window;

import dlangui;
import dlangui.widgets.widget;
import dlangui.platforms.common.platform;
import dlangui.widgets.layouts;
import dlangui.widgets.menu;
import dlangui.core.events;  // Import full module for Event class
import dlangui.core.types;
import std.math : sqrt, abs;

import desktop.workspace;
import taskbar.components;
import notes.window : NotesVaultWindow;

/// Custom event types for desktop window
enum DesktopEventType {
    CreateDemoWindow = 10001  // Use a unique number
}

/// Main desktop environment window that manages all other windows
class DesktopWindow : Window {
    private WorkspaceManager workspace;
    private TaskBar taskBar;
    private MenuItem startMenu;
    private Window[] windows;
    private dstring _windowCaption = "Desktop"d;
    private ulong demoWindowTimerId;  // Store timer ID
    
    this() {
        super();
        
        try {
            // Create main layout
            auto mainLayout = new VerticalLayout();
            mainLayout.layoutWidth = FILL_PARENT;
            mainLayout.layoutHeight = FILL_PARENT;
            mainLayout.backgroundColor = 0x2D2D2D;
            
            // Create workspace manager
            workspace = new WorkspaceManager();
            workspace.layoutWidth = FILL_PARENT;
            workspace.layoutHeight = FILL_PARENT;
            
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

    private bool onStartMenuClick(Widget w) {
        Log.d("Start menu clicked");
        auto menu = new PopupMenu(startMenu);
        auto pt = Point(w.pos.left, w.pos.bottom);
        this.showPopup(menu, w, PopupAlign.Below);
        return true;
    }

    private void setupStartMenu() {
        startMenu = new MenuItem();
        startMenu.add(new Action(1, "Notes"d));
        startMenu.add(new Action(2, "Settings"d));
        startMenu.addSeparator();
        startMenu.add(new Action(3, "Exit"d));
    }

    // Required Window overrides
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

    bool handleEvent(CustomEvent event) {
        if (event.id == DesktopEventType.CreateDemoWindow) {
            auto note = new NotesVaultWindow();
            addWindow(note);
            return true;
        }
        return false;  // Don't call super since we're not overriding
    }

    override void show() {
        try {
            // Set theme before window creation
            Platform.instance.uiTheme = "theme_default";
            
            // Create window with basic flags first
            auto window = Platform.instance.createWindow("Desktop"d, null, 
                WindowFlag.Resizable | WindowFlag.Fullscreen,
                1024, 768);
            
            if (!window) {
                Log.e("Failed to create window");
                return;
            }
            
            // Set up main widget
            if (mainWidget) {
                window.mainWidget = mainWidget;
                mainWidget.invalidate();
            }
            
            window.show();

            // Schedule demo window creation
            if (mainWidget) {
                demoWindowTimerId = mainWidget.setTimer(50);  // Just set the timer
            }
            
        } catch (Exception e) {
            Log.e("Show error: ", e.msg);
        }
    }

    override void onTimer() {
        if (demoWindowTimerId) {
            demoWindowTimerId = 0;  // Clear timer ID
            auto note = new NotesVaultWindow();
            addWindow(note);
        }
    }

    /// Add a window to the desktop environment
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

    // ... rest of DesktopWindow implementation ...
}

 