module note;

import std.datetime;
import std.array;
import std.algorithm : canFind, filter;
import std.string;
import std.uuid;
import std.regex;

struct Note {
    string id;
    string title;
    string content;
    string[] tags;
    string path;
    SysTime created;
    SysTime modified;
    
    this(string title, string content, string path = "") {
        this.id = randomUUID().toString();
        this.title = title;
        this.content = content;
        this.path = path;
        this.created = Clock.currTime();
        this.modified = this.created;
        this.tags = [];
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
    
    string toMarkdown() {
        import std.format : format;
        
        return format("---\ntitle: %s\ntags: [%s]\ncreated: %s\nmodified: %s\n---\n\n%s",
            title,
            tags.join(", "),
            created.toISOExtString(),
            modified.toISOExtString(),
            content);
    }
    
    static Note fromMarkdown(string content, string path) {
        // Parse frontmatter
        auto fmRegex = regex(r"^---\s*\n(.*?)\n---\s*\n(.*)$", "s");
        auto contentMatch = matchFirst(content, fmRegex);
        
        if (!contentMatch.empty) {
            auto frontMatter = contentMatch[1];
            auto noteContent = contentMatch[2];
            
            // Parse frontmatter fields
            string noteTitle;
            string[] noteTags;
            SysTime noteCreated;
            SysTime noteModified;
            
            foreach (line; frontMatter.splitLines) {
                auto parts = line.findSplit(":");
                if (!parts[1].empty) {
                    auto key = parts[0].strip;
                    auto value = parts[2].strip;
                    
                    switch (key) {
                        case "title":
                            noteTitle = value;
                            break;
                        case "tags":
                            // Remove [] and split by commas
                            value = value.strip("[]");
                            noteTags = value.split(",").map!(t => t.strip).array;
                            break;
                        case "created":
                            noteCreated = SysTime.fromISOExtString(value);
                            break;
                        case "modified":
                            noteModified = SysTime.fromISOExtString(value);
                            break;
                        default:
                            break;
                    }
                }
            }
            
            auto note = Note(noteTitle, noteContent.strip, path);
            note.tags = noteTags;
            if (noteCreated != SysTime.init) note.created = noteCreated;
            if (noteModified != SysTime.init) note.modified = noteModified;
            return note;
        }
        
        // If no frontmatter, create basic note
        return Note("Untitled", content, path);
    }
} 

 