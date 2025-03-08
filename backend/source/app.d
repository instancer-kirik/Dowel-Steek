module app;

import vibe.vibe;  // This should include everything we need
import vibe.http.server;
import vibe.http.websockets;
import vibe.http.router;
import vibe.core.core;
import vibe.core.log;
import vibe.data.json;
import std.file;
import std.path;
import core.thread;
import core.time;
import std.algorithm;
import std.datetime;
import std.array;
import std.range;
import common.vault;  // Use the regular module name
import common.note;
import editor;
import std.stdio;
import vibe.data.json : serializeToJson;
import std.conv : to;
import vibe.http.client;
// File change tracking
private struct FileChange {
    string path;
    SysTime lastModified;
}

private FileChange[] lastKnownState;
private WebSocket[] connectedClients;

// WebSocket handler
void handleWebSocket(scope WebSocket socket) {
    try {
        synchronized {
            connectedClients ~= socket;
        }
        scope(exit) {
            synchronized {
                connectedClients = connectedClients.filter!(c => c != socket).array;
            }
        }

        while (socket.connected) {
            try {
                auto msg = socket.receiveText();
                logInfo("Received WebSocket message: %s", msg);
            } catch (Exception e) {
                logError("WebSocket error: %s", e.msg);
                break;
            }
        }
    } catch (Exception e) {
        logError("WebSocket handler error: %s", e.msg);
    }
}

FileChange[] checkForFileChanges() {
    auto changes = appender!(FileChange[]);
    auto notesDir = "notes";
    
    if (!exists(notesDir)) {
        mkdirRecurse(notesDir);
        return changes.data;
    }
    
    try {
        // Get current state of files
        FileChange[] currentState;
        foreach (DirEntry entry; dirEntries(notesDir, SpanMode.depth)) {
            try {
                if (entry.isFile) {
                    auto currentChange = FileChange(entry.name, entry.timeLastModified());
                    currentState ~= currentChange;
                    
                    // Check if file changed
                    auto previous = lastKnownState.find!(f => f.path == entry.name);
                    if (previous.empty || previous.front.lastModified != currentChange.lastModified) {
                        changes.put(currentChange);
                    }
                }
            } catch (Exception e) {
                logError("Error checking file %s: %s", entry.name, e.msg);
                continue; // Skip this file if there's an error
            }
        }
        
        // Update last known state
        lastKnownState = currentState;
    } catch (Exception e) {
        logError("Error checking for file changes: %s", e.msg);
    }
    
    return changes.data;
}

void broadcastChanges(FileChange[] changes) {
    if (changes.empty) return;

    try {
        auto changeData = Json([
            "type": Json("fileChanges"),
            "changes": Json(changes.map!(c => Json([
                "path": Json(c.path),
                "timestamp": Json(c.lastModified.toISOExtString())
            ])).array)
        ]);
        
        synchronized {
            foreach (client; connectedClients) {
                if (client.connected) {
                    try {
                        client.send(changeData.toString());
                    } catch (Exception e) {
                        logError("Failed to send to client: %s", e.msg);
                    }
                }
            }
        }
    } catch (Exception e) {
        logError("Error broadcasting changes: %s", e.msg);
    }
}

void startFileWatcher() {
    logInfo("Starting file watcher");
    runTask(() nothrow {
        while (true) {
            try {
                auto changes = checkForFileChanges();
                if (!changes.empty) {
                    logInfo("Detected %d file changes", changes.length);
                    broadcastChanges(changes);
                }
            } catch (Exception e) {
                logError("File watcher error: %s", e.msg);
            }
            
            try {
                sleep(1.seconds);
            } catch (Exception e) {
                logError("Sleep error: %s", e.msg);
            }
        }
    });
}

shared static this() {
    // Set up logging
    auto logsDir = "logs";
    if (!exists(logsDir)) {
        mkdirRecurse(logsDir);
    }
    
    auto logPath = buildPath(logsDir, "backend.log");
    setLogFile(logPath, LogLevel.debug_);

    // Create notes directory if it doesn't exist
    if (!exists("notes")) {
        logInfo("Creating notes directory");
        mkdirRecurse("notes");
    }

    // Create a test note if the vault is empty
    logInfo("Initializing VaultManager");
    auto vaultManager = new VaultManager("notes");
    auto notes = vaultManager.getAllNotes();
    logInfo("Found %d existing notes", notes.length);
    
    if (notes.empty) {
        logInfo("Creating welcome notes");
        createWelcomeNotes(vaultManager);
    }
}

void main() {
    // Create notes directory if it doesn't exist
    if (!exists("notes")) {
        mkdirRecurse("notes");
    }
    
    // Set log level to debug
    setLogLevel(LogLevel.debug_);
    
    auto settings = new HTTPServerSettings;
    settings.port = 3000;
    settings.bindAddresses = ["127.0.0.1"];
    settings.webSocketPingInterval = 30.seconds;
    
    // Log all incoming requests
    settings.accessLogFormat = "%h %r %>s %b %D";
    
    auto router = new URLRouter;
    
    // API routes first
    router.get("/api/notes", &getAllNotes);
    router.post("/api/notes", &createNote);
    router.get("/api/notes/:id", &getNote);
    router.put("/api/notes/:id", &updateNote);
    router.get("/api/tags", &getTags);
    
    // Add this route after other API routes
    router.get("/api/debug/notes", (HTTPServerRequest req, HTTPServerResponse res) {
        logInfo("=== GET /api/debug/notes ===");
        try {
            auto notesDir = "notes";
            auto fileInfos = dirEntries(notesDir, "*.md", SpanMode.depth)
                .filter!(f => f.isFile)
                .map!(f => [
                    "path": f.name,
                    "size": getSize(f.name).to!string,
                    "modified": timeLastModified(f.name).toISOExtString(),
                    "content": readText(f.name)
                ].serializeToJson())
                .array;
            
            auto response = [
                "directory": notesDir.serializeToJson(),
                "exists": exists(notesDir).serializeToJson(),
                "files": fileInfos.serializeToJson()
            ];
            
            res.writeJsonBody(response);
        } catch (Exception e) {
            res.statusCode = HTTPStatus.internalServerError;
            res.writeJsonBody(["error": e.msg.serializeToJson()]);
        }
    });
    
    // WebSocket route
    router.get("/ws", handleWebSockets(&handleWebSocket));
    
    // Serve frontend static files
    auto fsettings = new HTTPFileServerSettings;
    fsettings.serverPathPrefix = "/";  // Serve from root
    
    // Add proper MIME types
    fsettings.encodingFileExtension = [
        ".js": "application/javascript",
        ".mjs": "application/javascript",
        ".css": "text/css",
        ".html": "text/html",
        ".json": "application/json",
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".svg": "image/svg+xml",
        ".ico": "image/x-icon",
        ".woff": "font/woff",
        ".woff2": "font/woff2",
        ".ttf": "font/ttf",
        ".eot": "application/vnd.ms-fontobject"
    ];
    
    // Check if frontend directory exists
    auto frontendPath = "../frontend";
    auto distPath = buildPath(frontendPath, "dist");
    auto srcPath = frontendPath;
    
    bool isDevelopment = !exists(distPath);
    string servePath = isDevelopment ? srcPath : distPath;
    
    if (!exists(servePath)) {
        logError("Frontend directory not found at: %s", servePath);
        return;
    }

    // Serve static files
    router.get("/assets/*", (req, res) {
        auto path = req.requestPath.toString()[8..$]; // Remove "/assets/" prefix
        auto fullPath = buildPath(servePath, "assets", path);
        
        if (!exists(fullPath)) {
            logInfo("Asset not found: %s", fullPath);
            res.statusCode = HTTPStatus.notFound;
            return;
        }

        auto ext = extension(path).toLower();
        string contentType = "application/octet-stream";
        
        switch (ext) {
            case ".js":
            case ".mjs":
                contentType = "application/javascript";
                break;
            case ".css":
                contentType = "text/css";
                break;
            case ".html":
                contentType = "text/html";
                break;
            case ".json":
                contentType = "application/json";
                break;
            default:
                break;
        }
        
        res.headers["Content-Type"] = contentType;
        res.writeBody(readFile(fullPath));
    });
    
    // Serve index.html for all unmatched routes (SPA support)
    router.get("*", (HTTPServerRequest req, HTTPServerResponse res) {
        string reqPath = req.requestPath.toString();
        logInfo("=== Request for path: %s ===", reqPath);
        
        // Skip API, WebSocket and asset requests
        if (reqPath.startsWith("/api/") || reqPath == "/ws" || reqPath.startsWith("/assets/")) {
            logInfo("Skipping special request");
            return;
        }
        
        auto indexPath = buildPath(servePath, "index.html");
        logInfo("Looking for index at: %s", indexPath);
        if (exists(indexPath)) {
            logInfo("Serving index.html");
            string content = readText(indexPath);
            
            res.headers["Content-Type"] = "text/html";
            res.writeBody(content);
        } else {
            logError("index.html not found at %s", indexPath);
            res.statusCode = HTTPStatus.notFound;
            res.writeBody("Not Found");
        }
    });

    logInfo("Starting Quill Garden backend server..."); // A garden for growing your thoughts
    
    auto listener = listenHTTP(settings, router);
    scope(exit) listener.stopListening();
    
    logInfo("Server running on http://localhost:3000/");
    runApplication();
}

void getTags(HTTPServerRequest req, HTTPServerResponse res) {
    auto vaultManager = new VaultManager("notes");
    auto tags = vaultManager.getAllTags();
    res.writeJsonBody(tags);
}

void createNote(HTTPServerRequest req, HTTPServerResponse res) {
    try {
        auto json = req.json;
        auto title = json["title"].get!string;
        auto content = json["content"].get!string;
        
        auto note = Note(title, content);
        auto vaultManager = new VaultManager("notes");
        vaultManager.addNote(note);
        
        res.writeJsonBody([
            "success": Json(true),
            "note": Json([
                "id": Json(note.id),
                "title": Json(note.title),
                "content": Json(note.content),
                "tags": Json(note.tags.map!(t => Json(t)).array),
                "path": Json(note.path),
                "created": Json(note.created.toISOExtString()),
                "modified": Json(note.modified.toISOExtString())
            ])
        ]);
    } catch (Exception e) {
        res.statusCode = HTTPStatus.badRequest;
        res.writeJsonBody(["error": Json(e.msg)]);
    }
}

void getNote(HTTPServerRequest req, HTTPServerResponse res) {
    try {
        auto id = req.params["id"];
        auto vaultManager = new VaultManager("notes");
        if (auto note = vaultManager.getNote(id)) {
            res.writeJsonBody(*note);
        } else {
            res.statusCode = HTTPStatus.notFound;
            res.writeJsonBody(["error": "Note not found"]);
        }
    } catch (Exception e) {
        res.statusCode = HTTPStatus.internalServerError;
        res.writeJsonBody(["error": e.msg]);
    }
}

void updateNote(HTTPServerRequest req, HTTPServerResponse res) {
    try {
        auto id = req.params["id"];
        auto json = req.json;
        auto vaultManager = new VaultManager("notes");
        
        if (auto note = vaultManager.getNote(id)) {
            note.title = json["title"].get!string;
            note.content = json["content"].get!string;
            note.modified = Clock.currTime();
            
            if (auto tags = "tags" in json) {
                note.tags = tags.get!(Json[]).map!(t => t.get!string).array;
            }
            
            vaultManager.addNote(*note);
            
            res.writeJsonBody([
                "success": Json(true),
                "note": Json([
                    "id": Json(note.id),
                    "title": Json(note.title),
                    "content": Json(note.content),
                    "tags": Json(note.tags.map!(t => Json(t)).array),
                    "path": Json(note.path),
                    "created": Json(note.created.toISOExtString()),
                    "modified": Json(note.modified.toISOExtString())
                ])
            ]);
        } else {
            res.statusCode = HTTPStatus.notFound;
            res.writeJsonBody(["error": Json("Note not found")]);
        }
    } catch (Exception e) {
        res.statusCode = HTTPStatus.internalServerError;
        res.writeJsonBody(["error": Json(e.msg)]);
    }
}

void createWelcomeNotes(VaultManager vaultManager) {
    logInfo("Creating welcome notes");
    
    // Welcome note
    auto welcome = Note(
        "Welcome to Quill Garden 🌱",
        "Welcome to your personal knowledge garden! Here you can:\n\n" ~
        "- 📝 Create and edit notes\n" ~
        "- 🏷️ Organize with tags\n" ~
        "- 🔗 Link notes together\n" ~
        "- 📌 Pin important notes\n" ~
        "- 🎨 Color-code for visual organization\n\n" ~
        "Get started by creating a new note or exploring the examples!"
    );
    welcome.addTag("welcome");
    welcome.isPinned = true;
    welcome.color = "green";
    vaultManager.addNote(welcome);
    
    // Quick start guide
    auto quickstart = Note(
        "Quick Start Guide 🚀",
        "## Basic Usage\n\n" ~
        "1. Create a new note with the + button\n" ~
        "2. Use markdown for formatting\n" ~
        "3. Add #tags in your content\n" ~
        "4. Pin important notes\n" ~
        "5. Use colors to categorize\n\n" ~
        "## Keyboard Shortcuts\n\n" ~
        "- `Ctrl/Cmd + N`: New note\n" ~
        "- `Ctrl/Cmd + S`: Save\n" ~
        "- `Ctrl/Cmd + F`: Search\n"
    );
    quickstart.addTag("guide");
    quickstart.color = "blue";
    vaultManager.addNote(quickstart);
    
    // Markdown example
    auto markdown = Note(
        "Markdown Examples 📘",
        "# Heading 1\n## Heading 2\n### Heading 3\n\n" ~
        "**Bold** and *italic* text\n\n" ~
        "- Bullet points\n" ~
        "1. Numbered lists\n\n" ~
        "> Blockquotes look like this\n\n" ~
        "```\nCode blocks are great for snippets\n```\n\n" ~
        "[Links](https://example.com) work too!\n\n" ~
        "Add #tags anywhere in your content"
    );
    markdown.addTag("example");
    markdown.addTag("markdown");
    markdown.color = "purple";
    vaultManager.addNote(markdown);
    
    logInfo("Welcome notes created");
}

void getAllNotes(HTTPServerRequest req, HTTPServerResponse res) {
    try {
        auto vaultManager = new VaultManager("notes");
        auto notes = vaultManager.getAllNotes();
        
        // Convert notes to JSON array with proper structure
        auto notesJson = notes.map!(note => Json([
            "id": Json(note.id),
            "title": Json(note.title),
            "content": Json(note.content),
            "tags": Json(note.tags.map!(t => Json(t)).array),
            "path": Json(note.path),
            "created": Json(note.created.toISOExtString()),
            "modified": Json(note.modified.toISOExtString()),
            "isPinned": Json(note.isPinned),
            "isArchived": Json(note.isArchived),
            "color": Json(note.color)
        ])).array;
        
        res.writeJsonBody([
            "notes": Json(notesJson)  // Wrap in an object with "notes" key
        ]);
    } catch (Exception e) {
        res.statusCode = HTTPStatus.internalServerError;
        res.writeJsonBody(["error": Json(e.msg)]);
    }
}

// ... other API handlers ... 

 