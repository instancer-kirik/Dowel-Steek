module notes.note;

import std.datetime;
import std.array;
import std.algorithm : canFind, filter, map;
import std.string;
import std.uuid;
import std.regex;
import std.algorithm.searching : findSplit;
import std.json;

struct Note {
    string id;
    string title;
    string content;
    string[] tags;
    string path;
    SysTime created;
    SysTime modified;
    bool isPinned;
    bool isArchived;
    string color;  // For note categorization
    string[] links;  // For linking to other notes
    
    this(string title, string content) {
        this.id = randomUUID().toString();
        this.title = title;
        this.content = content;
        this.tags = [];
        this.created = Clock.currTime();
        this.modified = this.created;
        this.isPinned = false;
        this.isArchived = false;
        this.color = "default";
        this.links = [];
    }
    
    void addTag(string tag) {
        if (!tags.canFind(tag)) {
            tags ~= tag;
            modified = Clock.currTime();
        }
    }
    
    void removeTag(string tag) {
        tags = tags.filter!(t => t != tag).array;
        modified = Clock.currTime();
    }
    
    string toMarkdown() const {
        import std.format : format;
        
        return format(
            "---\n" ~
            "title: %s\n" ~
            "created: %s\n" ~
            "modified: %s\n" ~
            "tags: [%s]\n" ~
            "color: %s\n" ~
            "pinned: %s\n" ~
            "archived: %s\n" ~
            "links: [%s]\n" ~
            "---\n\n%s",
            title,
            created.toISOExtString(),
            modified.toISOExtString(),
            tags.join(", "),
            color,
            isPinned,
            isArchived,
            links.join(", "),
            content
        );
    }
    
    static Note fromMarkdown(string content, string path = "") {
        import std.string : splitLines, strip;
        import std.algorithm : startsWith;
        
        string title = "Untitled";
        string[] tags;
        bool isPinned = false;
        bool isArchived = false;
        string color = "";
        
        // Try to extract title from first heading
        auto lines = content.splitLines();
        foreach (line; lines) {
            auto trimmed = line.strip();
            if (trimmed.startsWith("# ")) {
                title = trimmed[2..$].strip();
                break;
            }
        }
        
        // Create note with extracted metadata
        auto note = Note(title, content);
        note.path = path;
        note.isPinned = isPinned;
        note.isArchived = isArchived;
        note.color = color;
        
        // Extract tags from content
        auto tagRegex = regex(r"#(\w+)");
        foreach (match; content.matchAll(tagRegex)) {
            note.addTag(match[1]);
        }
        
        return note;
    }
}

 