module chatgpt_app;

import dlangui;
import chatgpt.viewer;
import std.getopt;
import std.stdio;
import std.path;
import std.file;
import std.process;

mixin APP_ENTRY_POINT;

void printUsage() {
    writeln("ChatGPT Conversation Viewer");
    writeln("Usage: chatgpt-viewer [options]");
    writeln("Options:");
    writeln("  --file=FILE         Load ChatGPT conversation JSON file or directory");
    writeln("  --jan              Load from Jan data directory (~/.local/share/Jan/data)");
    writeln("  --inspect=FILE      Inspect JSON structure without opening GUI");
    writeln("  --help              Show this help message");
    writeln("  --debug|d           Enable debug output");
    writeln("");
    writeln("File/Directory handling:");
    writeln("  - Supports ~ expansion for home directory");
    writeln("  - If directory is specified, looks for conversations.json");
    writeln("  - Jan directory: ~/.local/share/Jan/data/conversations.json");
}

string expandPath(string path) {
    if (path.length > 0 && path[0] == '~') {
        auto homeDir = environment.get("HOME");
        if (homeDir.length > 0) {
            if (path.length == 1) {
                return homeDir;
            } else if (path[1] == '/') {
                return buildPath(homeDir, path[2..$]);
            }
        }
    }
    return path;
}

string findConversationsFile(string path) {
    string expandedPath = expandPath(path);

    // If it's a file and exists, return it
    if (isFile(expandedPath)) {
        return expandedPath;
    }

    // If it's a directory, look for conversations.json
    if (isDir(expandedPath)) {
        string conversationsFile = buildPath(expandedPath, "conversations.json");
        if (exists(conversationsFile)) {
            return conversationsFile;
        }
    }

    return expandedPath; // Return original if nothing found
}

void inspectJSONStructure(string filename) {
    import std.json;
    import std.file;

    try {
        writefln("Inspecting JSON file: %s", filename);

        if (!exists(filename)) {
            writefln("ERROR: File not found: %s", filename);
            return;
        }

        auto jsonText = readText(filename);
        writefln("File size: %d bytes", jsonText.length);

        auto jsonData = parseJSON(jsonText);
        writefln("JSON type: %s", jsonData.type);

        if (jsonData.type == JSONType.object) {
            writeln("Top-level object keys:");
            foreach (key, value; jsonData.object) {
                writefln("  - %s: %s", key, value.type);

                // Show some details for common ChatGPT fields
                if (key == "mapping" && value.type == JSONType.object) {
                    writefln("    mapping contains %d entries", value.object.length);
                    auto firstKey = value.object.keys.length > 0 ? value.object.keys[0] : "";
                    if (firstKey.length > 0) {
                        writefln("    first mapping key: %s", firstKey);
                        if ("message" in value.object[firstKey]) {
                            writefln("    first entry has 'message' field");
                        }
                    }
                } else if (key == "messages" && value.type == JSONType.array) {
                    writefln("    messages array contains %d entries", value.array.length);
                } else if (key == "conversation" && value.type == JSONType.object) {
                    writefln("    conversation object detected");
                }
            }
        } else if (jsonData.type == JSONType.array) {
            writefln("Root is an array with %d elements", jsonData.array.length);
            if (jsonData.array.length > 0) {
                writefln("First element type: %s", jsonData.array[0].type);
            }
        }

        writeln("\nThis appears to be:");
        if (jsonData.type == JSONType.object) {
            if ("mapping" in jsonData) {
                writeln("  ✓ Standard ChatGPT conversation export (mapping format)");
            } else if ("messages" in jsonData) {
                writeln("  ? Possible ChatGPT messages array format");
            } else if ("conversation" in jsonData) {
                writeln("  ? Possible ChatGPT conversation wrapper format");
            } else {
                writeln("  ✗ Unknown format - not a recognized ChatGPT export");
            }
        } else if (jsonData.type == JSONType.array) {
            writeln("  ✓ Multi-conversation export format (OpenAI conversations.json)");
            if (jsonData.array.length > 0 && jsonData.array[0].type == JSONType.object) {
                auto firstConv = jsonData.array[0].object;
                if ("mapping" in firstConv || "title" in firstConv) {
                    writeln("  ✓ Valid multi-conversation format detected");
                }
            }
        } else {
            writeln("  ✗ Not a ChatGPT conversation format");
        }

    } catch (Exception e) {
        writefln("ERROR inspecting file: %s", e.msg);
    }
}

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args) {
    string conversationFile = "";
    string inspectFile = "";
    bool debugMode = false;
    bool useJanDirectory = false;

    auto helpInformation = getopt(
        args,
        std.getopt.config.passThrough,
        "file", "Path to ChatGPT conversation JSON file or directory", &conversationFile,
        "jan", "Load from Jan data directory", &useJanDirectory,
        "inspect", "Inspect JSON structure without opening GUI", &inspectFile,
        "debug|d", "Enable debug output", &debugMode
    );

    if (helpInformation.helpWanted) {
        printUsage();
        return 0;
    }

    // Handle inspect option first - don't start GUI
    if (inspectFile.length > 0) {
        string resolvedInspectFile = findConversationsFile(inspectFile);
        inspectJSONStructure(resolvedInspectFile);
        return 0;
    }

    // Handle Jan directory option
    if (useJanDirectory) {
        conversationFile = "~/.local/share/Jan/data";
        if (debugMode) {
            writefln("Using Jan directory: %s", conversationFile);
        }
    }

    // Expand and find conversations file
    if (conversationFile.length > 0) {
        conversationFile = findConversationsFile(conversationFile);
        if (debugMode) {
            writefln("Resolved file path: %s", conversationFile);
        }

        if (!exists(conversationFile)) {
            stderr.writefln("ERROR: File not found: %s", conversationFile);
            if (useJanDirectory) {
                stderr.writeln("Hint: Make sure Jan is installed and has conversation data");
                stderr.writeln("Expected location: ~/.local/share/Jan/data/conversations.json");
            }
            return 1;
        }
    }

    if (debugMode) {
        writefln("Debug mode enabled");
        writefln("Loading file: %s", conversationFile.length > 0 ? conversationFile : "none");
    }

    try {
        // Initialize dlangui platform
        initLogs();

        // Initialize platform and set theme
        Platform.instance.uiTheme = "theme_default";

        // Create window with proper flags
        Window window = Platform.instance.createWindow("ChatGPT Conversation Viewer"d, null,
            WindowFlag.Resizable, 1000, 700);

        if (!window) {
            throw new Exception("Failed to create window");
        }

        // Set window background
        window.backgroundColor = 0xFAFAFA;

        // create some widget to show in window
        auto viewer = new ChatGPTViewerWindow();

        // set window main widget
        window.mainWidget = viewer;

        // Load file if specified
        if (conversationFile.length > 0) {
            if (debugMode) {
                writefln("Loading file: %s", conversationFile);
            }
            viewer.loadFile(conversationFile);
        }

        // show window
        window.show();

        if (debugMode) {
            writeln("Window created and shown, entering message loop...");
        }

        // run message loop
        return Platform.instance.enterMessageLoop();
    } catch (Exception e) {
        stderr.writefln("Error starting ChatGPT viewer: %s", e.msg);
        if (debugMode) {
            stderr.writefln("Stack trace: %s", e.toString());
        }
        return 1;
    } catch (Error e) {
        stderr.writefln("Fatal error in ChatGPT viewer: %s", e.msg);
        if (debugMode) {
            stderr.writefln("Stack trace: %s", e.toString());
        }
        return 2;
    }
}
