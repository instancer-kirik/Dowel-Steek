module notes.vault;

import notes.note;
import std.container;
import std.algorithm;
import std.array;
import std.string;
import std.path;
import std.file;
import std.conv : to;
import std.string : toLower;
import std.datetime;
import core.thread;
import std.ascii : isAlphaNum;
import vibe.core.log;

class VaultManager {
    private Note[string] notes;
    private string[] tags;
    private string rootPath;
    private Thread watcherThread;
    private bool isWatching;
    
    this(string rootPath = "") {
        logInfo("VaultManager constructor - rootPath: %s", rootPath);
        this.rootPath = rootPath;
        if (rootPath && exists(rootPath)) {
            initializeVault();
        }
    }
    
    ~this() {
        stopWatching();
    }
    
    private void initializeVault() {
        logInfo("Initializing vault at: %s", rootPath);
        loadNotes();
        startWatching();
    }
    
    private void startWatching() {
        if (isWatching || !rootPath) return;
        
        isWatching = true;
        watcherThread = new Thread({
            while (isWatching) {
                // Check for new/modified files
                auto currentFiles = dirEntries(rootPath, "*.md", SpanMode.depth)
                    .filter!(f => f.isFile)
                    .map!(f => relativePath(f.name, rootPath))
                    .array;
                
                foreach (file; currentFiles) {
                    auto path = buildPath(rootPath, file);
                    auto modTime = timeLastModified(path);
                    
                    if (auto note = getNodeByPath(file)) {
                        if (modTime > note.modified) {
                            reloadNote(file);
                        }
                    } else {
                        loadNote(file);
                    }
                }
                
                Thread.sleep(dur!"seconds"(2));
            }
        });
        watcherThread.isDaemon = true;
        watcherThread.start();
    }
    
    private void stopWatching() {
        isWatching = false;
        if (watcherThread) {
            watcherThread.join();
            watcherThread = null;
        }
    }
    
    private Note* getNodeByPath(string path) {
        foreach (ref note; notes) {
            if (note.path == path) return &note;
        }
        return null;
    }
    
    private void loadNotes() {
        logInfo("Loading notes from: %s", rootPath);
        try {
            // Load all .md files from the root path
            auto files = dirEntries(rootPath, "*.md", SpanMode.depth)
                .filter!(f => f.isFile)
                .array;
            
            logInfo("Found %d markdown files", files.length);
            
            foreach (file; files) {
                try {
                    string content = readText(file);
                    auto note = Note.fromMarkdown(content, relativePath(file, rootPath));
                    notes[note.id] = note;
                    logInfo("Loaded note: %s (%s)", note.title, note.id);
                } catch (Exception e) {
                    logError("Failed to load note %s: %s", file, e.msg);
                }
            }
        } catch (Exception e) {
            logError("Failed to load notes: %s", e.msg);
        }
    }
    
    private void loadNote(string path) {
        auto fullPath = buildPath(rootPath, path);
        if (!exists(fullPath)) return;
        
        auto content = readText(fullPath);
        auto note = Note.fromMarkdown(content, path);
        notes[note.id] = note;
        
        // Update tags
        foreach (tag; note.tags) {
            addTag(tag);
        }
    }
    
    private void reloadNote(string path) {
        if (auto note = getNodeByPath(path)) {
            loadNote(path);
        }
    }
    
    private void saveNote(Note note) {
        logInfo("Saving note: %s (%s)", note.title, note.id);
        
        try {
            // Generate file path from title if not set
            if (!note.path) {
                import std.path : buildPath;
                import std.array : replace;
                string safeName = note.title.replace(" ", "-").toLower();
                note.path = buildPath(safeName ~ ".md");
            }
            
            string notePath = buildPath(rootPath, note.path);
            logInfo("Note path: %s", notePath);
            
            // Ensure the directory exists
            string noteDir = dirName(notePath);
            if (!exists(noteDir)) {
                mkdirRecurse(noteDir);
                logInfo("Created directory: %s", noteDir);
            }
            
            // Write the note
            std.file.write(notePath, note.toMarkdown());
            logInfo("Note saved successfully");
            
            // Update in-memory cache
            notes[note.id] = note;
        } catch (Exception e) {
            logError("Failed to save note: %s", e.msg);
            throw e;
        }
    }
    
    void addNote(Note note) {
        logInfo("Adding note: %s (%s)", note.title, note.id);
        notes[note.id] = note;
        saveNote(note);
    }
    
    Note* getNote(string id) {
        logInfo("Getting note: %s", id);
        return id in notes;
    }
    
    Note[] getAllNotes() {
        logInfo("Getting all notes (count: %d)", notes.length);
        foreach (note; notes.values) {
            logInfo("Note: %s (%s)", note.title, note.id);
        }
        return notes.values.array;
    }
    
    Note[] searchNotes(string query) {
        return getAllNotes()
            .filter!(n => n.title.toLower.canFind(query.toLower) || 
                         n.content.toLower.canFind(query.toLower) ||
                         n.tags.any!(t => t.toLower.canFind(query.toLower)))
            .array;
    }
    
    Note[] getNotesByTag(string tag) {
        return getAllNotes()
            .filter!(n => n.tags.canFind(tag))
            .array;
    }
    
    void addTag(string tag) {
        if (!tags.canFind(tag)) {
            tags ~= tag;
            tags.sort(); // Keep tags sorted
        }
    }
    
    string[] getAllTags() {
        return tags.dup;
    }

    Note createNote(string title = "New Note") {
        auto note = Note(title, "");  // Create new note
        notes[note.id] = note;  // Add to collection
        saveNote(note);  // Save to disk
        return note;
    }
} 

 