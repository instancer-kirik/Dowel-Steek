module dowel.core.config;

import std.stdio;
import std.file : exists, mkdirRecurse, read;
import std.path;
import std.conv;
import std.json;
import std.exception;
import toml;
import std.stdio : write;

/// Desktop environment configuration manager
class ConfigManager
{
    private static ConfigManager _instance;
    private TOMLDocument _config;
    private string _configPath;
    private string _userConfigDir;
    private string _systemConfigDir;

    /// Configuration sections
    struct General
    {
        string theme = "default";
        string iconTheme = "default";
        string cursorTheme = "default";
        int compositorEnabled = 1;
        int animationsEnabled = 1;
        int animationSpeed = 200; // milliseconds
    }

    struct WindowManager
    {
        string defaultLayout = "floating";
        int focusFollowsMouse = 0;
        int autoRaise = 0;
        int autoRaiseDelay = 500; // milliseconds
        int snapDistance = 10; // pixels
        int borderWidth = 2;
        string borderColorActive = "#4080FF";
        string borderColorInactive = "#808080";
        int workspaceCount = 9;
        int wrapWorkspaces = 1;
    }

    struct Panel
    {
        string position = "bottom"; // top, bottom, left, right
        int height = 32; // pixels
        int autoHide = 0;
        int autoHideDelay = 500; // milliseconds
        string[] applets = [
            "launcher", "taskbar", "workspace_switcher", "systray", "clock"
        ];
        int expandTaskbar = 1;
    }

    struct Desktop
    {
        string wallpaperPath = "";
        string wallpaperMode = "scaled"; // centered, tiled, stretched, scaled, zoom
        int showIcons = 1;
        string[] defaultIcons = ["Home", "Documents", "Downloads", "Trash"];
        int iconSize = 48;
        int gridSnap = 1;
        int gridSize = 64;
    }

    struct Keyboard
    {
        string modKey = "Super"; // Alt, Super, Control
        string[string] shortcuts;
    }

    struct Applications
    {
        string terminal = "xterm";
        string fileManager = "dowel-fm";
        string browser = "firefox";
        string editor = "gedit";
    }

    struct Performance
    {
        int vsync = 1;
        int doubleBuffer = 1;
        int hardwareAccel = 1;
        int reducedMotion = 0;
        int lowMemoryMode = 0;
    }

    General general;
    WindowManager wm;
    Panel panel;
    Desktop desktop;
    Keyboard keyboard;
    Applications apps;
    Performance perf;

    private this()
    {
        initializePaths();
        loadDefaults();
        loadConfig();
        setupDefaultKeyboardShortcuts();
    }

    static ConfigManager instance()
    {
        if (_instance is null)
        {
            _instance = new ConfigManager();
        }
        return _instance;
    }

    private void initializePaths()
    {
        import std.process : environment;

        // Get XDG config directories
        string xdgConfigHome = environment.get("XDG_CONFIG_HOME",
            expandTilde("~/.config"));
        string xdgConfigDirs = environment.get("XDG_CONFIG_DIRS",
            "/etc/xdg");

        _userConfigDir = buildPath(xdgConfigHome, "dowel-steek");
        _systemConfigDir = buildPath("/etc", "dowel-steek");
        _configPath = buildPath(_userConfigDir, "config.toml");

        // Create user config directory if it doesn't exist
        if (!exists(_userConfigDir))
        {
            mkdirRecurse(_userConfigDir);
        }
    }

    private void loadDefaults()
    {
        // Defaults are already set in struct field initializers
        // This method can be used for more complex default logic
    }

    private void setupDefaultKeyboardShortcuts()
    {
        keyboard.shortcuts = [
            "Super+Return": "terminal",
            "Super+d": "launcher",
            "Super+f": "file_manager",
            "Super+l": "lock_screen",
            "Super+q": "close_window",
            "Alt+F4": "close_window",
            "Alt+Tab": "window_switcher",
            "Super+Tab": "workspace_switcher",
            "Super+1": "workspace_1",
            "Super+2": "workspace_2",
            "Super+3": "workspace_3",
            "Super+4": "workspace_4",
            "Super+5": "workspace_5",
            "Super+6": "workspace_6",
            "Super+7": "workspace_7",
            "Super+8": "workspace_8",
            "Super+9": "workspace_9",
            "Super+Shift+1": "move_to_workspace_1",
            "Super+Shift+2": "move_to_workspace_2",
            "Super+Shift+3": "move_to_workspace_3",
            "Super+Shift+4": "move_to_workspace_4",
            "Super+Shift+5": "move_to_workspace_5",
            "Super+Shift+6": "move_to_workspace_6",
            "Super+Shift+7": "move_to_workspace_7",
            "Super+Shift+8": "move_to_workspace_8",
            "Super+Shift+9": "move_to_workspace_9",
            "Super+Left": "tile_left",
            "Super+Right": "tile_right",
            "Super+Up": "maximize",
            "Super+Down": "minimize",
            "Super+Shift+Up": "toggle_fullscreen",
            "Super+Space": "toggle_floating",
            "Super+r": "resize_mode",
            "Super+m": "move_mode",
            "Super+Shift+q": "logout",
            "Super+Shift+r": "restart_wm",
            "Print": "screenshot",
            "Super+Print": "screenshot_window",
            "Super+Shift+Print": "screenshot_region"
        ];
    }

    void loadConfig()
    {
        try
        {
            // Try user config first
            if (exists(_configPath))
            {
                loadConfigFile(_configPath);
            }
            // Fall back to system config
            else if (exists(buildPath(_systemConfigDir, "config.toml")))
            {
                loadConfigFile(buildPath(_systemConfigDir, "config.toml"));
            }
            // If no config exists, save defaults
            else
            {
                saveConfig();
            }
        }
        catch (Exception e)
        {
            writeln("Error loading config: ", e.msg);
            writeln("Using default configuration");
        }
    }

    private void loadConfigFile(string path)
    {
        _config = parseTOML(cast(string) read(path));

        // Load general settings
        if ("general" in _config)
        {
            auto g = _config["general"];
            if ("theme" in g) general.theme = g["theme"].str;
            if ("icon_theme" in g) general.iconTheme = g["icon_theme"].str;
            if ("cursor_theme" in g) general.cursorTheme = g["cursor_theme"].str;
            if ("compositor" in g) general.compositorEnabled = cast(int)g["compositor"].integer;
            if ("animations" in g) general.animationsEnabled = cast(int)g["animations"].integer;
            if ("animation_speed" in g) general.animationSpeed = cast(int)g["animation_speed"].integer;
        }

        // Load window manager settings
        if ("wm" in _config)
        {
            auto w = _config["wm"];
            if ("default_layout" in w) wm.defaultLayout = w["default_layout"].str;
            if ("focus_follows_mouse" in w) wm.focusFollowsMouse = cast(int)w["focus_follows_mouse"].integer;
            if ("auto_raise" in w) wm.autoRaise = cast(int)w["auto_raise"].integer;
            if ("auto_raise_delay" in w) wm.autoRaiseDelay = cast(int)w["auto_raise_delay"].integer;
            if ("snap_distance" in w) wm.snapDistance = cast(int)w["snap_distance"].integer;
            if ("border_width" in w) wm.borderWidth = cast(int)w["border_width"].integer;
            if ("border_color_active" in w) wm.borderColorActive = w["border_color_active"].str;
            if ("border_color_inactive" in w) wm.borderColorInactive = w["border_color_inactive"].str;
            if ("workspace_count" in w) wm.workspaceCount = cast(int)w["workspace_count"].integer;
            if ("wrap_workspaces" in w) wm.wrapWorkspaces = cast(int)w["wrap_workspaces"].integer;
        }

        // Load panel settings
        if ("panel" in _config)
        {
            auto p = _config["panel"];
            if ("position" in p) panel.position = p["position"].str;
            if ("height" in p) panel.height = cast(int)p["height"].integer;
            if ("auto_hide" in p) panel.autoHide = cast(int)p["auto_hide"].integer;
            if ("auto_hide_delay" in p) panel.autoHideDelay = cast(int)p["auto_hide_delay"].integer;
            if ("expand_taskbar" in p) panel.expandTaskbar = cast(int)p["expand_taskbar"].integer;

            if ("applets" in p)
            {
                panel.applets = [];
                foreach (applet; p["applets"].array)
                {
                    panel.applets ~= applet.str;
                }
            }
        }

        // Load desktop settings
        if ("desktop" in _config)
        {
            auto d = _config["desktop"];
            if ("wallpaper" in d) desktop.wallpaperPath = d["wallpaper"].str;
            if ("wallpaper_mode" in d) desktop.wallpaperMode = d["wallpaper_mode"].str;
            if ("show_icons" in d) desktop.showIcons = cast(int)d["show_icons"].integer;
            if ("icon_size" in d) desktop.iconSize = cast(int)d["icon_size"].integer;
            if ("grid_snap" in d) desktop.gridSnap = cast(int)d["grid_snap"].integer;
            if ("grid_size" in d) desktop.gridSize = cast(int)d["grid_size"].integer;

            if ("default_icons" in d)
            {
                desktop.defaultIcons = [];
                foreach (icon; d["default_icons"].array)
                {
                    desktop.defaultIcons ~= icon.str;
                }
            }
        }

        // Load keyboard shortcuts
        if ("keyboard" in _config)
        {
            auto k = _config["keyboard"];
            if ("mod_key" in k) keyboard.modKey = k["mod_key"].str;

            if ("shortcuts" in k)
            {
                keyboard.shortcuts.clear();
                auto shortcuts = k["shortcuts"].table;
                foreach (key, value; shortcuts)
                {
                    keyboard.shortcuts[key] = value.str;
                }
            }
        }

        // Load application settings
        if ("applications" in _config)
        {
            auto a = _config["applications"];
            if ("terminal" in a) apps.terminal = a["terminal"].str;
            if ("file_manager" in a) apps.fileManager = a["file_manager"].str;
            if ("browser" in a) apps.browser = a["browser"].str;
            if ("editor" in a) apps.editor = a["editor"].str;
        }

        // Load performance settings
        if ("performance" in _config)
        {
            auto p = _config["performance"];
            if ("vsync" in p) perf.vsync = cast(int)p["vsync"].integer;
            if ("double_buffer" in p) perf.doubleBuffer = cast(int)p["double_buffer"].integer;
            if ("hardware_accel" in p) perf.hardwareAccel = cast(int)p["hardware_accel"].integer;
            if ("reduced_motion" in p) perf.reducedMotion = cast(int)p["reduced_motion"].integer;
            if ("low_memory_mode" in p) perf.lowMemoryMode = cast(int)p["low_memory_mode"].integer;
        }
    }

    void saveConfig()
    {
        TOMLDocument doc;

        // Save general settings
        doc["general"] = TOMLValue([
            "theme": TOMLValue(general.theme),
            "icon_theme": TOMLValue(general.iconTheme),
            "cursor_theme": TOMLValue(general.cursorTheme),
            "compositor": TOMLValue(general.compositorEnabled),
            "animations": TOMLValue(general.animationsEnabled),
            "animation_speed": TOMLValue(general.animationSpeed)
        ]);

        // Save window manager settings
        doc["wm"] = TOMLValue([
            "default_layout": TOMLValue(wm.defaultLayout),
            "focus_follows_mouse": TOMLValue(wm.focusFollowsMouse),
            "auto_raise": TOMLValue(wm.autoRaise),
            "auto_raise_delay": TOMLValue(wm.autoRaiseDelay),
            "snap_distance": TOMLValue(wm.snapDistance),
            "border_width": TOMLValue(wm.borderWidth),
            "border_color_active": TOMLValue(wm.borderColorActive),
            "border_color_inactive": TOMLValue(wm.borderColorInactive),
            "workspace_count": TOMLValue(wm.workspaceCount),
            "wrap_workspaces": TOMLValue(wm.wrapWorkspaces)
        ]);

        // Save panel settings
        TOMLValue[] appletValues;
        foreach (applet; panel.applets)
        {
            appletValues ~= TOMLValue(applet);
        }

        doc["panel"] = TOMLValue([
            "position": TOMLValue(panel.position),
            "height": TOMLValue(panel.height),
            "auto_hide": TOMLValue(panel.autoHide),
            "auto_hide_delay": TOMLValue(panel.autoHideDelay),
            "applets": TOMLValue(appletValues),
            "expand_taskbar": TOMLValue(panel.expandTaskbar)
        ]);

        // Save desktop settings
        TOMLValue[] iconValues;
        foreach (icon; desktop.defaultIcons)
        {
            iconValues ~= TOMLValue(icon);
        }

        doc["desktop"] = TOMLValue([
            "wallpaper": TOMLValue(desktop.wallpaperPath),
            "wallpaper_mode": TOMLValue(desktop.wallpaperMode),
            "show_icons": TOMLValue(desktop.showIcons),
            "default_icons": TOMLValue(iconValues),
            "icon_size": TOMLValue(desktop.iconSize),
            "grid_snap": TOMLValue(desktop.gridSnap),
            "grid_size": TOMLValue(desktop.gridSize)
        ]);

        // Save keyboard settings
        TOMLValue[string] shortcutValues;
        foreach (key, value; keyboard.shortcuts)
        {
            shortcutValues[key] = TOMLValue(value);
        }

        doc["keyboard"] = TOMLValue([
            "mod_key": TOMLValue(keyboard.modKey),
            "shortcuts": TOMLValue(shortcutValues)
        ]);

        // Save application settings
        doc["applications"] = TOMLValue([
            "terminal": TOMLValue(apps.terminal),
            "file_manager": TOMLValue(apps.fileManager),
            "browser": TOMLValue(apps.browser),
            "editor": TOMLValue(apps.editor)
        ]);

        // Save performance settings
        doc["performance"] = TOMLValue([
            "vsync": TOMLValue(perf.vsync),
            "double_buffer": TOMLValue(perf.doubleBuffer),
            "hardware_accel": TOMLValue(perf.hardwareAccel),
            "reduced_motion": TOMLValue(perf.reducedMotion),
            "low_memory_mode": TOMLValue(perf.lowMemoryMode)
        ]);

        // Write to file
        import std.file : write;
        write(_configPath, doc.toString());
    }

    /// Reload configuration from disk
    void reload()
    {
        loadConfig();
    }

    /// Get a configuration value by path (e.g., "general.theme")
    T get(T)(string path, T defaultValue = T.init)
    {
        string[] parts = path.split(".");
        if (parts.length != 2)
        {
            return defaultValue;
        }

        string section = parts[0];
        string key = parts[1];

        switch (section)
        {
        case "general":
            return getGeneralValue!T(key, defaultValue);
        case "wm":
            return getWMValue!T(key, defaultValue);
        case "panel":
            return getPanelValue!T(key, defaultValue);
        case "desktop":
            return getDesktopValue!T(key, defaultValue);
        case "apps":
            return getAppsValue!T(key, defaultValue);
        case "perf":
            return getPerfValue!T(key, defaultValue);
        default:
            return defaultValue;
        }
    }

    private T getGeneralValue(T)(string key, T defaultValue)
    {
        switch (key)
        {
        case "theme":
            return cast(T) general.theme;
        case "icon_theme":
            return cast(T) general.iconTheme;
        case "cursor_theme":
            return cast(T) general.cursorTheme;
        case "compositor":
            return cast(T) general.compositorEnabled;
        case "animations":
            return cast(T) general.animationsEnabled;
        case "animation_speed":
            return cast(T) general.animationSpeed;
        default:
            return defaultValue;
        }
    }

    private T getWMValue(T)(string key, T defaultValue)
    {
        switch (key)
        {
        case "default_layout":
            return cast(T) wm.defaultLayout;
        case "focus_follows_mouse":
            return cast(T) wm.focusFollowsMouse;
        case "auto_raise":
            return cast(T) wm.autoRaise;
        case "auto_raise_delay":
            return cast(T) wm.autoRaiseDelay;
        case "snap_distance":
            return cast(T) wm.snapDistance;
        case "border_width":
            return cast(T) wm.borderWidth;
        case "border_color_active":
            return cast(T) wm.borderColorActive;
        case "border_color_inactive":
            return cast(T) wm.borderColorInactive;
        case "workspace_count":
            return cast(T) wm.workspaceCount;
        case "wrap_workspaces":
            return cast(T) wm.wrapWorkspaces;
        default:
            return defaultValue;
        }
    }

    private T getPanelValue(T)(string key, T defaultValue)
    {
        switch (key)
        {
        case "position":
            return cast(T) panel.position;
        case "height":
            return cast(T) panel.height;
        case "auto_hide":
            return cast(T) panel.autoHide;
        case "auto_hide_delay":
            return cast(T) panel.autoHideDelay;
        case "applets":
            return cast(T) panel.applets;
        case "expand_taskbar":
            return cast(T) panel.expandTaskbar;
        default:
            return defaultValue;
        }
    }

    private T getDesktopValue(T)(string key, T defaultValue)
    {
        switch (key)
        {
        case "wallpaper":
            return cast(T) desktop.wallpaperPath;
        case "wallpaper_mode":
            return cast(T) desktop.wallpaperMode;
        case "show_icons":
            return cast(T) desktop.showIcons;
        case "default_icons":
            return cast(T) desktop.defaultIcons;
        case "icon_size":
            return cast(T) desktop.iconSize;
        case "grid_snap":
            return cast(T) desktop.gridSnap;
        case "grid_size":
            return cast(T) desktop.gridSize;
        default:
            return defaultValue;
        }
    }

    private T getAppsValue(T)(string key, T defaultValue)
    {
        switch (key)
        {
        case "terminal":
            return cast(T) apps.terminal;
        case "file_manager":
            return cast(T) apps.fileManager;
        case "browser":
            return cast(T) apps.browser;
        case "editor":
            return cast(T) apps.editor;
        default:
            return defaultValue;
        }
    }

    private T getPerfValue(T)(string key, T defaultValue)
    {
        switch (key)
        {
        case "vsync":
            return cast(T) perf.vsync;
        case "double_buffer":
            return cast(T) perf.doubleBuffer;
        case "hardware_accel":
            return cast(T) perf.hardwareAccel;
        case "reduced_motion":
            return cast(T) perf.reducedMotion;
        case "low_memory_mode":
            return cast(T) perf.lowMemoryMode;
        default:
            return defaultValue;
        }
    }

    /// Set a configuration value by path
    void set(T)(string path, T value)
    {
        string[] parts = path.split(".");
        if (parts.length != 2)
        {
            return;
        }

        string section = parts[0];
        string key = parts[1];

        switch (section)
        {
        case "general":
            setGeneralValue(key, value);
            break;
        case "wm":
            setWMValue(key, value);
            break;
        case "panel":
            setPanelValue(key, value);
            break;
        case "desktop":
            setDesktopValue(key, value);
            break;
        case "apps":
            setAppsValue(key, value);
            break;
        case "perf":
            setPerfValue(key, value);
            break;
        default:
            break;
        }

        saveConfig();
    }

    private void setGeneralValue(T)(string key, T value)
    {
        switch (key)
        {
        case "theme":
            general.theme = to!string(value);
            break;
        case "icon_theme":
            general.iconTheme = to!string(value);
            break;
        case "cursor_theme":
            general.cursorTheme = to!string(value);
            break;
        case "compositor":
            general.compositorEnabled = to!int(value);
            break;
        case "animations":
            general.animationsEnabled = to!int(value);
            break;
        case "animation_speed":
            general.animationSpeed = to!int(value);
            break;
        default:
            break;
        }
    }

    private void setWMValue(T)(string key, T value)
    {
        switch (key)
        {
        case "default_layout":
            wm.defaultLayout = to!string(value);
            break;
        case "focus_follows_mouse":
            wm.focusFollowsMouse = to!int(value);
            break;
        case "auto_raise":
            wm.autoRaise = to!int(value);
            break;
        case "auto_raise_delay":
            wm.autoRaiseDelay = to!int(value);
            break;
        case "snap_distance":
            wm.snapDistance = to!int(value);
            break;
        case "border_width":
            wm.borderWidth = to!int(value);
            break;
        case "border_color_active":
            wm.borderColorActive = to!string(value);
            break;
        case "border_color_inactive":
            wm.borderColorInactive = to!string(value);
            break;
        case "workspace_count":
            wm.workspaceCount = to!int(value);
            break;
        case "wrap_workspaces":
            wm.wrapWorkspaces = to!int(value);
            break;
        default:
            break;
        }
    }

    private void setPanelValue(T)(string key, T value)
    {
        switch (key)
        {
        case "position":
            panel.position = to!string(value);
            break;
        case "height":
            panel.height = to!int(value);
            break;
        case "auto_hide":
            panel.autoHide = to!int(value);
            break;
        case "auto_hide_delay":
            panel.autoHideDelay = to!int(value);
            break;
        case "expand_taskbar":
            panel.expandTaskbar = to!int(value);
            break;
        default:
            break;
        }
    }

    private void setDesktopValue(T)(string key, T value)
    {
        switch (key)
        {
        case "wallpaper":
            desktop.wallpaperPath = to!string(value);
            break;
        case "wallpaper_mode":
            desktop.wallpaperMode = to!string(value);
            break;
        case "show_icons":
            desktop.showIcons = to!int(value);
            break;
        case "icon_size":
            desktop.iconSize = to!int(value);
            break;
        case "grid_snap":
            desktop.gridSnap = to!int(value);
            break;
        case "grid_size":
            desktop.gridSize = to!int(value);
            break;
        default:
            break;
        }
    }

    private void setAppsValue(T)(string key, T value)
    {
        switch (key)
        {
        case "terminal":
            apps.terminal = to!string(value);
            break;
        case "file_manager":
            apps.fileManager = to!string(value);
            break;
        case "browser":
            apps.browser = to!string(value);
            break;
        case "editor":
            apps.editor = to!string(value);
            break;
        default:
            break;
        }
    }

    private void setPerfValue(T)(string key, T value)
    {
        switch (key)
        {
        case "vsync":
            perf.vsync = to!int(value);
            break;
        case "double_buffer":
            perf.doubleBuffer = to!int(value);
            break;
        case "hardware_accel":
            perf.hardwareAccel = to!int(value);
            break;
        case "reduced_motion":
            perf.reducedMotion = to!int(value);
            break;
        case "low_memory_mode":
            perf.lowMemoryMode = to!int(value);
            break;
        default:
            break;
        }
    }
}

/// Global configuration instance
@property ConfigManager config()
{
    return ConfigManager.instance();
}
