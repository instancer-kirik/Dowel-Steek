module cli.smart_open;

import std.stdio;
import std.process;
import std.path : absolutePath, buildPath, isAbsolute;
import std.file;
import std.conv;
import std.algorithm;
import std.array;
import core.stdc.stdlib : getenv; // For getenv
import std.string : strip; // Added import for strip

// Import toml if available (will be after dub fetches it)
version(Have_toml) { 
    import toml;
} else {
    // This is a fallback if toml isn't resolved, useful for initial dev before first build
    alias TOMLValue TomlValuePlaceholder; // Renamed to avoid conflict if toml itself defines TOMLValue
    struct TomlValuePlaceholder { 
        string toString() { return "TomlValue placeholder"; } 
        bool opCast(T : bool)() { return false; } 
        auto opIndex(string s){ return TomlValuePlaceholder(); } 
        auto opIndex(size_t i){ return TomlValuePlaceholder(); } 
        @property size_t length(){return 0;} 
        @property string[] array(){ return [];} // Changed anArray to array
        @property bool boolean(){return false;} // Changed aBool to boolean
        @property string str() { return ""; } // Added str property
        enum Type { Table, Array, Bool, String, Null } // Added Null for safety
        Type type = Type.Null; // Default type
        @property auto table() { // Changed tables to table
            struct Pair { string key; TomlValuePlaceholder value; }
            struct TableIter { 
                Pair front() { return Pair("dummy", TomlValuePlaceholder()); } 
                bool empty() { return true; } 
                void popFront(){} 
            } 
            return TableIter(); 
        }
        // Placeholder for TOMLDocument-like iteration if needed by the placeholder logic
        @property auto byKeyValue() {
             struct Pair { string key; TomlValuePlaceholder value; }
             struct KeyValueIterator {
                 Pair front() { return Pair("dummy_key", TomlValuePlaceholder()); }
                 bool empty() { return true; }
                 void popFront() {}
             }
             return KeyValueIterator();
        }
    }
    // For emsi_toml, the main parsing function is typically parseTOML
    TomlValuePlaceholder parseTOML(string s){ writeln("Warning: toml not found, using placeholder."); return TomlValuePlaceholder(); } 
}


struct AppConfig {
    string[] preferred;
    bool terminal;
    string[] fallback; // Optional: for fallback chains
}

// Maps MIME type to its configuration
alias ConfigMap = AppConfig[string];

ConfigMap loadConfig(string configPath) {
    ConfigMap configMap;
    
    if (!exists(configPath) || !isFile(configPath)) {
        stderr.writeln("Configuration file not found: ", configPath);
        stderr.writeln("Please create one, e.g., at ~/.config/xdg-smart-open.toml");
        // Example structure hint:
        stderr.writeln(`
Example ~/.config/xdg-smart-open.toml:
["text/plain"]
preferred = ["nano", "less"]
terminal = true

["image/jpeg"]
preferred = ["gwenview", "feh"]
terminal = false
`);
        return configMap; // Return empty map
    }

    try {
        string tomlContent = readText(configPath);
        version(Have_toml) {
            auto doc = parseTOML(tomlContent); // Returns TOMLDocument

            // Iterate over top-level keys in the TOMLDocument
            // Assuming each top-level key is a MIME type table
            foreach (string mimeType; doc.keys) {
                auto entry = doc[mimeType]; // entry is a TOMLValue (effectively toml.toml.TOMLValue)

                if (entry.type == TOML_TYPE.TABLE) {
                    AppConfig appCfg;
                    // entry.table gives an AA: string[TOMLValue]
                    auto entryTable = entry.table; 

                    if ("preferred" in entryTable && entryTable["preferred"].type == TOML_TYPE.ARRAY) {
                        appCfg.preferred = entryTable["preferred"].array.map!(val => val.str).array;
                    }
                    if ("terminal" in entryTable && (entryTable["terminal"].type == TOML_TYPE.TRUE || entryTable["terminal"].type == TOML_TYPE.FALSE)) {
                        appCfg.terminal = entryTable["terminal"].boolean;
                    }
                    configMap[mimeType] = appCfg;
                }
            }
        } else {
            // Placeholder logic for when toml is not available
            auto root = parseTOML(tomlContent); // Uses placeholder parseTOML
            // The placeholder iteration needs to be careful
            // This part is tricky because the placeholder doesn't fully emulate TOMLDocument
            // Let's assume the placeholder's .table() directly gives iterable pairs for simplicity of the placeholder.
            // This might not perfectly match the real library if we used root.table directly.
            // A better placeholder for TOMLDocument might be needed if this path is frequently hit.
            // For now, let's assume the placeholder's `parseTOML` returns a `TomlValuePlaceholder` that has `byKeyValue`
            foreach(pair; root.byKeyValue()) { // A simplified way to iterate for placeholder
                string mimeType = pair.key;
                auto entry = pair.value;
                 if (entry.type == TomlValuePlaceholder.Type.Table) { // Use placeholder's type
                    AppConfig appCfg;
                    // Placeholder access - this part is highly dependent on the placeholder's structure
                    auto entryTablePlaceholder = entry.table; // This is a placeholder TableIter
                    // This won't really work well with the placeholder's simple AA-like opIndex
                    // For the real library, the logic in the `version(Have_toml)` block is what matters.
                    // The placeholder is just to avoid compile errors when toml isn't present.
                    // Let's keep it simple for the else branch and focus on the real library path.
                 }
            }
            if (configMap.length == 0) { // Only print if we didn't parse anything with placeholder
                 stderr.writeln("toml (emsi_toml) not available, cannot parse config with placeholder logic effectively.");
            }
        }
    } catch (Exception e) {
        stderr.writeln("Error loading or parsing config file '", configPath, "': ", e.msg);
    }
    return configMap;
}

string getMimeType(string filePath) {
    try {
        auto result = execute(["file", "--mime-type", "-b", filePath]);
        if (result.status == 0 && result.output.length > 0) {
            return strip(result.output); // Call strip directly
        } else {
            stderr.writeln("Warning: Could not determine MIME type for '", filePath, "'. Output: ", result.output, " Status: ", result.status);
        }
    } catch (ProcessException e) {
        stderr.writeln("Warning: 'file' command failed or not found: ", e.msg);
    }
    return "application/octet-stream"; // Default fallback MIME type
}

string getTerminalEmulator() {
    char* termEnv = getenv("TERMINAL");
    if (termEnv !is null && termEnv[0] != '\0') {
        return to!string(termEnv);
    }
    // Fallback to common terminals if $TERMINAL is not set
    string[] commonTerminals = ["ghostty", "kitty", "alacritty", "gnome-terminal", "konsole", "xfce4-terminal", "xterm"];
    foreach(term; commonTerminals) {
        try {
            // Check if the terminal exists in PATH
            auto result = execute(["which", term]);
            if (result.status == 0) return term;
        } catch (ProcessException) { /* ignore */ }
    }
    stderr.writeln("Warning: Could not determine a default terminal emulator. Please set $TERMINAL or install a common one.");
    return "xterm"; // Last resort
}

// Function to get home directory reliably
string getUserHomeDir() {
    version(Windows) {
        // For Windows, USERPROFILE is common, or HOMEDRIVE + HOMEPATH
        char* home = getenv("USERPROFILE");
        if (home !is null && home[0] != '\0') return to!string(home);
        char* drive = getenv("HOMEDRIVE");
        char* path = getenv("HOMEPATH");
        if (drive !is null && path !is null && drive[0] != '\0' && path[0] != '\0') {
            return to!string(drive) ~ to!string(path);
        }
    } else { // POSIX (Linux, macOS, etc.)
        char* home = getenv("HOME");
        if (home !is null && home[0] != '\0') return to!string(home);
    }
    // Fallback if no env var found, though unlikely for HOME on Posix
    stderr.writeln("Warning: Could not determine home directory from environment variables.");
    return "."; // Fallback to current directory (not ideal)
}

void main(string[] args) {
    if (args.length < 2) {
        stderr.writeln("Usage: xdg-smart-open <file_path>");
        return;
    }

    string filePath = args[1];
    if (!isAbsolute(filePath)) {
        filePath = absolutePath(filePath);
    }

    if (!exists(filePath) || !isFile(filePath)) {
        stderr.writeln("Error: File not found or is not a regular file: ", filePath);
        return;
    }
    
    string userHome = getUserHomeDir();
    if (userHome == ".") { // Check if fallback was used
        // Potentially exit or use a different default if home dir is critical
    }
    string configDir = buildPath(userHome, ".config");
    string configPath = buildPath(configDir, "xdg-smart-open.toml");

    ConfigMap config = loadConfig(configPath);
    if (config.length == 0) {
        stderr.writeln("No configuration loaded. Exiting.");
        return;
    }
    
    string mimeType = getMimeType(filePath);
    writeln("File: ", filePath);
    writeln("MIME Type: ", mimeType);

    if (mimeType in config) {
        AppConfig appCfg = config[mimeType];
        bool launched = false;
        
        foreach (app; appCfg.preferred) {
            try {
                writeln("Attempting to launch '", app, "' for '", filePath, "'...");
                Pid pid;
                if (appCfg.terminal) {
                    string terminalEmulator = getTerminalEmulator();
                    writeln("Using terminal: ", terminalEmulator);
                    // Ensure arguments are passed correctly, e.g., some terminals use -e, others just take cmd after --
                    // This is a simplified approach.
                    string[] cmdArgs = [terminalEmulator];
                    // Common patterns:
                    if (terminalEmulator == "kitty" || terminalEmulator == "alacritty" || terminalEmulator == "gnome-terminal" || terminalEmulator == "konsole") {
                        cmdArgs ~= "-e"; 
                    }
                    cmdArgs ~= app;
                    cmdArgs ~= filePath;
                    pid = spawnProcess(cmdArgs);

                } else {
                    pid = spawnProcess([app, filePath]);
                }
                // For CLI tool, we usually detach or don't wait unless specified.
                // wait(pid); // Uncomment if you want to wait for the app to close.
                writeln("Launched '", app, "' with PID: ", pid);
                launched = true;
                break; // Launched preferred app
            } catch (ProcessException e) {
                stderr.writeln("Failed to launch '", app, "': ", e.msg);
            }
        }

        if (!launched) {
            stderr.writeln("Could not launch any preferred application for MIME type: ", mimeType);
            // TODO: Implement fallback chain logic here if appCfg.fallback is populated
        }

    } else {
        stderr.writeln("No configuration found for MIME type: ", mimeType);
        stderr.writeln("Consider opening with a default system handler or xdg-open.");
        try {
            writeln("Attempting fallback to xdg-open...");
            auto result = execute(["xdg-open", filePath]);
            if (result.status == 0) {
                writeln("Successfully launched with xdg-open.");
            } else {
                stderr.writeln("xdg-open failed with status: ", result.status, "\nOutput: ", result.output);
            }
        } catch (ProcessException e) {
             stderr.writeln("Failed to launch with xdg-open: ", e.msg);
        }
    }
} 

 