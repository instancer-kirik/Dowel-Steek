module taskbar.launcher;

import dlangui;
import dlangui.widgets.controls;
import dlangui.widgets.editors;
import dlangui.widgets.layouts;
import std.file;
import std.path;
import std.process;
import std.algorithm;
import std.array;
import std.string : splitLines, strip, startsWith, toLower;

// Desktop entry structure for Linux .desktop files
struct DesktopEntry {
    string name;
    string exec;
    string icon;
    string[] categories;
}

// Add TextArea class definition
class TextArea : EditBox {
    this(string id = null) {
        super(id);
        // ... existing code ...
    }
}

// Application launcher with search
class AppLauncher : VerticalLayout {
    private EditLine searchBox;
    private ListWidget appList;
    private AppFinder appFinder;
    private PopupWidget popup;
    
    this() {
        super("applauncher");
        backgroundColor = 0x252525;
        padding(Rect(10, 10, 10, 10));
        
        // Search box
        searchBox = new EditLine("search");
        searchBox.text = "Search applications..."d;
        searchBox.layoutWidth = FILL_PARENT;
        searchBox.contentChange = delegate void(EditableContent source) {
            onSearchChanged(source);
        };
        
        // App list
        appList = new ListWidget("apps");
        appList.layoutWidth = FILL_PARENT;
        appList.layoutHeight = FILL_PARENT;
        appList.itemClick = &onAppSelected;
        
        // App finder
        appFinder = new AppFinder();
        
        addChild(searchBox);
        addChild(appList);
        
        // Initial app list
        refreshApps();
    }
    
    private void refreshApps(string filter = "") {
        auto apps = appFinder.findApps(filter);
        dstring[] items;
        foreach(app; apps) {
            items ~= app.name.to!dstring;
        }
        appList.adapter = new StringListAdapter(items);
    }
    
    private bool onSearchChanged(EditableContent source) {
        refreshApps(source.text.to!string);
        return true;
    }
    
    private bool onAppSelected(Widget source, int index) {
        auto apps = appFinder.findApps(searchBox.text.to!string);
        if (index >= 0 && index < apps.length) {
            appFinder.launchApp(apps[index]);
            if (popup) {
                popup.visibility = Visibility.Gone;
                popup.parent.removeChild(popup);
            }
        }
        return true;
    }
}

// App finder that searches desktop files and AppImage files
class AppFinder {
    private DesktopEntry[] desktopEntries;
    private string[] appImagePaths;
    
    this() {
        // Scan standard locations
        scanDesktopFiles("/usr/share/applications");
        scanDesktopFiles(buildPath(environment.get("HOME"), ".local/share/applications"));
        
        // Scan for AppImages
        scanAppImages(environment.get("HOME"));
    }
    
    private void scanDesktopFiles(string path) {
        if (!exists(path)) return;
        
        foreach(string file; dirEntries(path, "*.desktop", SpanMode.shallow)) {
            try {
                auto entry = parseDesktopFile(file);
                if (entry.exec.length > 0)
                    desktopEntries ~= entry;
            } catch(Exception e) {
                // Skip invalid entries
            }
        }
    }
    
    private void scanAppImages(string path) {
        // Scan common AppImage locations
        string[] searchPaths = [
            buildPath(path, "Applications"),
            buildPath(path, ".local/bin"),
            "/opt"
        ];
        
        foreach(searchPath; searchPaths) {
            if (!exists(searchPath)) continue;
            
            foreach(string file; dirEntries(searchPath, SpanMode.shallow)) {
                if (file.endsWith(".AppImage"))
                    appImagePaths ~= file;
            }
        }
    }
    
    DesktopEntry[] findApps(string filter = "") {
        auto allApps = desktopEntries;
        if (filter.length > 0) {
            return allApps.filter!(a => 
                a.name.toLower.canFind(filter.toLower) ||
                a.categories.any!(c => c.toLower.canFind(filter.toLower))
            ).array;
        }
        return allApps;
    }
    
    void launchApp(DesktopEntry app) {
        try {
            // Parse exec line for arguments
            auto parts = app.exec.split(" ");
            spawnProcess(parts);
        } catch(Exception e) {
            Log.e("Failed to launch app: ", e.msg);
        }
    }
}

// Script runner for custom scripts
class ScriptRunner : VerticalLayout {
    private EditLine commandLine;
    private TextArea outputArea;
    private string workingDir;
    
    this() {
        super("scriptrunner");
        backgroundColor = 0x252525;
        padding(Rect(10, 10, 10, 10));
        
        // Command line
        commandLine = new EditLine("command");
        commandLine.text = "Enter command..."d;
        commandLine.layoutWidth = FILL_PARENT;
        
        // Output area
        outputArea = new TextArea("output");
        outputArea.layoutWidth = FILL_PARENT;
        outputArea.layoutHeight = FILL_PARENT;
        outputArea.readOnly = true;
        
        addChild(commandLine);
        addChild(outputArea);
        
        // Set up handlers
        commandLine.keyEvent = &onCommandKey;
        workingDir = environment.get("HOME");
    }
    
    private bool onCommandKey(Widget source, KeyEvent event) {
        if (event.action == KeyAction.KeyDown && 
            event.keyCode == KeyCode.RETURN) {
            runCommand(commandLine.text.to!string);
            return true;
        }
        return false;
    }
    
    private void runCommand(string cmd) {
        try {
            auto pipes = pipeProcess(cmd.split(" "), 
                Redirect.all, 
                null, 
                Config.none, 
                workingDir);
            
            // Read output
            foreach(line; pipes.stdout.byLine) {
                outputArea.text = outputArea.text ~ line.to!dstring ~ "\n"d;
            }
            
            // Check for errors
            auto status = pipes.pid.wait();
            if (status != 0) {
                foreach(line; pipes.stderr.byLine) {
                    outputArea.text = outputArea.text ~ "Error: "d ~ 
                        line.to!dstring ~ "\n"d;
                }
            }
            
        } catch(Exception e) {
            outputArea.text = outputArea.text ~ "Failed to run command: "d ~ 
                e.msg.to!dstring ~ "\n"d;
        }
    }
}

// Add desktop file parser
private DesktopEntry parseDesktopFile(string path) {
    DesktopEntry entry;
    
    try {
        foreach(line; readText(path).splitLines) {
            line = line.strip;
            if (line.startsWith("Name="))
                entry.name = line[5..$];
            else if (line.startsWith("Exec="))
                entry.exec = line[5..$];
            else if (line.startsWith("Icon="))
                entry.icon = line[5..$];
            else if (line.startsWith("Categories="))
                entry.categories = line[11..$].split(";");
        }
    } catch(Exception e) {
        // Handle error
    }
    return entry;
} 

 