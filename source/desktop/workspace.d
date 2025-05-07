module desktop.workspace;

import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.platforms.common.platform;
import dlangui.core.types;
import std.algorithm : max, remove;
import std.array : array;

/// Workspace layout types
enum WorkspaceLayout {
    Tiled,
    Stacked,
    Tabbed,
    Floating
}

/// Manages application windows and their layouts
class WorkspaceManager : FrameLayout {
    private IconGrid _iconGrid;
    private Widget _windowArea;
    private Window[] windows;
    private WorkspaceLayout currentLayout = WorkspaceLayout.Tiled;
    private int currentWorkspace = 0;
    private Window[int][] workspaces;  // Array of workspace->window mappings
    
    this() {
        super("workspace");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        
        // Set desktop background
        backgroundColor = 0x004477;
        
        // Create window area
        _windowArea = new VerticalLayout("windowArea");
        _windowArea.layoutWidth = FILL_PARENT;
        _windowArea.layoutHeight = FILL_PARENT;
        addChild(_windowArea);

        // Create icon grid
        _iconGrid = new IconGrid();
        addChild(_iconGrid);

        // Add some default icons
        _iconGrid.addIcon("Home"d, "folder-home", null);
        _iconGrid.addIcon("Documents"d, "folder-documents", null);
        _iconGrid.addIcon("Downloads"d, "folder-downloads", null);
        _iconGrid.addIcon("Trash"d, "user-trash", null);
        
        // Initialize workspaces
        workspaces.length = 9;  // 9 workspaces by default
    }

    void addWindow(Window window) {
        if (!window || !window.mainWidget) 
            return;
            
        _windowArea.addChild(window.mainWidget);
        
        // Add to current workspace
        windows ~= window;
        workspaces[currentWorkspace][cast(int)(windows.length - 1)] = window;
        
        // Apply current layout
        applyLayout();
    }

    void removeWindow(Window window) {
        if (!window || !window.mainWidget) 
            return;
            
        _windowArea.removeChild(window.mainWidget);
        
        // Remove from current workspace
        auto workspace = workspaces[currentWorkspace];
        foreach (key, win; workspace) {
            if (win == window) {
                workspace.remove(key);
                break;
            }
        }
        
        // Apply current layout
        applyLayout();
    }

    void switchToWorkspace(int index) {
        if (index < 0 || index >= workspaces.length) return;
        
        // Hide current workspace windows
        foreach (win; workspaces[currentWorkspace].values) {
            if (win && win.mainWidget)
                win.mainWidget.visibility = Visibility.Gone;
        }
        
        // Show new workspace windows
        currentWorkspace = index;
        foreach (win; workspaces[currentWorkspace].values) {
            if (win && win.mainWidget)
                win.mainWidget.visibility = Visibility.Visible;
        }
        
        applyLayout();
    }

    private void applyLayout() {
        // Implement different layout algorithms
        final switch (currentLayout) {
            case WorkspaceLayout.Tiled:
                applyTiledLayout();
                break;
            case WorkspaceLayout.Stacked:
                applyStackedLayout();
                break;
            case WorkspaceLayout.Tabbed:
                applyTabbedLayout();
                break;
            case WorkspaceLayout.Floating:
                // Windows manage their own position
                break;
        }
    }

    private void applyTiledLayout() {
        // TODO: Implement tiled layout
    }

    private void applyStackedLayout() {
        // TODO: Implement stacked layout
    }

    private void applyTabbedLayout() {
        // TODO: Implement tabbed layout
    }

    // ... rest of implementation ...
}

class DesktopIcon : VerticalLayout {
    this(dstring label, string iconResource) {
        super("icon");
        layoutWidth = 64;
        layoutHeight = 80;
        padding(Rect(4, 4, 4, 4));

        // Icon
        auto img = new ImageWidget(null, iconResource);
        img.layoutWidth = 48;
        img.layoutHeight = 48;
        addChild(img);

        // Label
        auto text = new TextWidget(null, label);
        text.textColor = 0xFFFFFF;
        text.textFlags = TextFlag.Underline;
        addChild(text);
    }
}

class IconGrid : TableLayout {
    this() {
        super("iconGrid");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        padding(Rect(10, 10, 10, 10));
        backgroundColor = 0x00000000; // Transparent

        // Set grid properties
        colCount = 12;
    }

    void addIcon(dstring label, string iconResource, void delegate() onClick) {
        auto icon = new DesktopIcon(label, iconResource);
        icon.click = delegate(Widget src) {
            if (onClick) onClick();
            return true;
        };
        addChild(icon);
    }
} 

 