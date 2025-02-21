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
        logInfo("Creating welcome note");
        auto testNote = Note("Welcome", "Welcome to your Notes Vault!\n\nThis is your first note. You can:\n- Edit this note\n- Create new notes\n- Delete notes\n\nEnjoy!");
        testNote.addTag("welcome");
        vaultManager.addNote(testNote);
        logInfo("Welcome note created");
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
    router.get("/api/notes", (HTTPServerRequest req, HTTPServerResponse res) {
        logInfo("=== GET /api/notes ===");
        try {
            logInfo("Creating VaultManager...");
            auto vaultManager = new VaultManager("notes");
            
            logInfo("Getting notes...");
            auto notes = vaultManager.getAllNotes();
            logInfo("Got %d notes", notes.length);

            // Always create a valid root node, even with no notes
            auto rootNode = Json([
                "type": Json("directory"),
                "name": Json("root"),
                "path": Json("/"),
                "children": Json(notes.length > 0 ? 
                    notes.map!(note => Json([
                        "type": Json("file"),
                        "name": Json(note.title),
                        "path": Json(note.path),
                        "note": Json([
                            "id": Json(note.id),
                            "title": Json(note.title),
                            "content": Json(note.content),
                            "tags": Json(note.tags.map!(t => Json(t)).array),
                            "path": Json(note.path),
                            "created": Json(note.created.toISOExtString()),
                            "modified": Json(note.modified.toISOExtString())
                        ])
                    ])).array : 
                    cast(Json[])[])
            ]);

            auto response = ["notes": Json([rootNode])];
            logInfo("Sending response with root node and %d notes", notes.length);
            res.headers["Access-Control-Allow-Origin"] = "*";
            res.headers["Content-Type"] = "application/json";
            res.writeJsonBody(response);
            logInfo("Response sent successfully");
        } catch (Exception e) {
            logError("API Error: %s", e.msg);
            logError("Stack trace: %s", e.toString());
            res.statusCode = HTTPStatus.internalServerError;
            res.writeJsonBody([
                "error": Json(e.msg),
                "notes": Json([Json([
                    "type": Json("directory"),
                    "name": Json("root"),
                    "path": Json("/"),
                    "children": Json(cast(Json[])[])
                ])])
            ]);
        }
    });
    router.post("/api/notes", &createNote);
    router.get("/api/notes/:id", &getNote);
    router.put("/api/notes/:id", &updateNote);
    router.get("/api/tags", &getTags);
    
    // WebSocket route
    router.get("/ws", handleWebSockets(&handleWebSocket));
    
    // Serve frontend static files
    auto fsettings = new HTTPFileServerSettings;
    fsettings.serverPathPrefix = "/";
    
    // Check if frontend directory exists
    auto frontendPath = "../frontend/dist";
    if (!exists(frontendPath)) {
        logError("Frontend directory not found at: %s", frontendPath);
        return;
    }

    // Serve static files first
    router.get("/assets/*", serveStaticFiles(frontendPath, fsettings));

    // Serve index.html for all unmatched routes (SPA support)
    router.get("*", (HTTPServerRequest req, HTTPServerResponse res) {
        string reqPath = req.requestPath.toString();
        logInfo("=== Request for path: %s ===", reqPath);
        logInfo("Headers: %s", req.headers);
        
        if (reqPath.startsWith("/api/") || reqPath == "/ws") {
            logInfo("Skipping API/WS request");
            return;
        }
        
        auto indexPath = buildPath(frontendPath, "index.html");
        logInfo("Looking for index at: %s", indexPath);
        if (exists(indexPath)) {
            logInfo("Serving index.html");
            string content = readText(indexPath);
            logInfo("Index content length: %d", content.length);
            res.headers["Content-Type"] = "text/html";
            res.writeBody(content);
        } else {
            logError("index.html not found at %s", indexPath);
            res.statusCode = HTTPStatus.notFound;
            res.writeBody("Not Found");
        }
    });

    logInfo("Starting Notes Vault backend server...");
    
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

// ... other API handlers ... 

 