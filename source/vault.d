module vault;

import note;
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

class VaultManager {
    private Note[string] notes;
    private string[] tags;
    private string rootPath;
    private Thread watcherThread;
    private bool isWatching;
    
    this(string rootPath = "") {
        this.rootPath = rootPath;
        if (rootPath && exists(rootPath)) {
            initializeVault();
        }
    }
    
    ~this() {
        stopWatching();
    }
    
    private void initializeVault() {
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
    
    void loadNotes() {
        if (!rootPath || !exists(rootPath)) return;
        
        foreach (string file; dirEntries(rootPath, "*.md", SpanMode.depth)
                            .filter!(f => f.isFile)
                            .map!(f => relativePath(f.name, rootPath))) {
            loadNote(file);
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
    
    void addNote(Note note) {
        notes[note.id] = note;
        saveNote(note);
    }
    
    private void saveNote(Note note) {
        if (!rootPath) return;
        
        string notePath = buildPath(rootPath, note.path);
        std.file.write(notePath, note.toMarkdown());
    }
    
    Note* getNote(string id) {
        return id in notes;
    }
    
    Note[] getAllNotes() {
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
} 

 