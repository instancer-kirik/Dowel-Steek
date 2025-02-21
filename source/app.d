import dlangui;
import dlangui.widgets.lists;
import dlangui.widgets.controls;
import dlangui.widgets.layouts;
import dlangui.platforms.common.platform : Platform;
import dlangui.widgets.widget;
import dlangui.platforms.sdl.sdlapp : SDLPlatform;
import std.format : format;
import std.conv : to;
import std.array : join;
import std.stdio;
import std.file;
import std.path;
import vault;
import editor;
import note;
import bindbc.sdl;
import vibe.d;  // We'll need to add vibe.d to dub.json

// Use platform-specific mixin
version(Windows) {
    import dlangui.platforms.windows.platform;
    mixin WINDOWS_APP_ENTRY_POINT;
} else {
    import dlangui.platforms.common.platform : APP_ENTRY_POINT;
    mixin APP_ENTRY_POINT;
}

class NotesVaultWindow : Window {
    private VaultManager vaultManager;
    private ListWidget notesList;
    private ListWidget tagsList;
    private string currentTagFilter;
    
    private void delegate() _onShowHandler;
    private void delegate() _onCloseHandler;

    this() {
        super();
        // Don't load icon yet - wait until after OpenGL init
        _onShowHandler = {
            updateTagsList();
            refreshLists();
        };
        _onCloseHandler = {
            // Cleanup if needed
        };
        
        // Create main layout first
        auto mainLayout = new VerticalLayout();
        mainLayout.padding(Rect(10, 10, 10, 10));
        mainLayout.backgroundColor = 0xFFFFFF;
        mainLayout.layoutWidth = FILL_PARENT;
        mainLayout.layoutHeight = FILL_PARENT;
        
        // Initialize vault manager
        vaultManager = new VaultManager();
        
        // Add toolbar
        auto toolbar = new HorizontalLayout();
        toolbar.layoutWidth = FILL_PARENT;  // Make sure toolbar fills width
        
        auto addNoteBtn = new Button(null, "Add Note"d);
        addNoteBtn.click = &onAddNoteClick;
        auto addTagBtn = new Button(null, "Add Tag"d);
        addTagBtn.click = &onAddTagClick;
        auto searchBox = new EditLine(null);
        searchBox.text = "Search..."d;
        setupSearchBox(searchBox);
        
        toolbar.addChild(addNoteBtn);
        toolbar.addChild(addTagBtn);
        toolbar.addChild(searchBox);
        
        // Add notes list
        notesList = new ListWidget(null);
        notesList.layoutWidth = FILL_PARENT;
        notesList.layoutHeight = FILL_PARENT;
        
        // Add tags panel
        auto tagsPanel = new VerticalLayout();
        tagsPanel.layoutWidth = FILL_PARENT;
        tagsPanel.layoutHeight = FILL_PARENT;
        
        tagsPanel.addChild(new TextWidget(null, "Tags"d));
        tagsList = new ListWidget(null);
        tagsList.layoutWidth = FILL_PARENT;
        tagsList.layoutHeight = FILL_PARENT;
        tagsPanel.addChild(tagsList);
        
        // Create split layout with proper weights
        auto splitLayout = new HorizontalLayout();
        splitLayout.layoutWidth = FILL_PARENT;
        splitLayout.layoutHeight = FILL_PARENT;
        
        auto notesPane = new VerticalLayout();
        notesPane.layoutWidth = FILL_PARENT;
        notesPane.layoutHeight = FILL_PARENT;
        notesPane.addChild(notesList);
        
        splitLayout.addChild(notesPane);
        splitLayout.addChild(tagsPanel);
        
        // Add all to main layout
        mainLayout.addChild(toolbar);
        mainLayout.addChild(splitLayout);
        
        // Set the main widget
        mainWidget = mainLayout;
        
        // Set up handlers
        tagsList.itemClick = &onTagSelected;
        notesList.itemClick = &onNoteSelected;
        
        // Initial data
        updateTagsList();
        refreshLists();
    }

    override void show() {
        // Create window first
        Platform.instance.createWindow(windowCaption, null, WindowFlag.Resizable, 800, 600);
        
        // Now that OpenGL is initialized, we can load the icon
        try {
            windowIcon = drawableCache.getImage("dlangui-logo1");
        } catch (Exception e) {
            Log.e("Failed to load window icon: ", e.msg);
        }
        
        if (mainWidget) {
            mainWidget.visibility = Visibility.Visible;
            mainWidget.invalidate();
        }
        
        if (_onShowHandler)
            _onShowHandler();
            
        requestLayout();
    }

    override void close() {
        if (_onCloseHandler)
            _onCloseHandler();
            
        if (mainWidget) {
            mainWidget.visibility = Visibility.Gone;
        }
    }

    override void invalidate() {
        if (mainWidget)
            mainWidget.invalidate();
    }

    override @property dstring windowCaption() const {
        return "Notes Vault Manager"d;
    }
    
    override @property void windowCaption(dstring caption) {
        // Basic implementation
    }
    
    override @property void windowIcon(DrawBufRef icon) {
        // Basic implementation
    }

    private bool onAddNoteClick(Widget w) {
        auto note = Note("New Note", "");
        vaultManager.addNote(note);
        auto editor = new MarkdownEditor(this, vaultManager.getNote(note.id));
        editor.show();
        return true;
    }

    private bool onAddTagClick(Widget w) {
        // TODO: Implement tag creation dialog
        return true;
    }

    private bool onTagSelected(Widget source, int itemIndex) {
        auto adapter = cast(StringListAdapter)tagsList.adapter;
        if (itemIndex >= 0 && adapter && itemIndex < adapter.itemCount) {
            currentTagFilter = itemIndex == 0 ? null : adapter.items[itemIndex].to!string;
            refreshLists();
        }
        return true;
    }
    
    private bool onNoteSelected(Widget source, int itemIndex) {
        auto adapter = cast(StringListAdapter)notesList.adapter;
        if (itemIndex >= 0 && adapter && itemIndex < adapter.itemCount) {
            auto notes = currentTagFilter && currentTagFilter != "All Notes" 
                ? vaultManager.getNotesByTag(currentTagFilter)
                : vaultManager.getAllNotes();
                
            if (itemIndex < notes.length) {
                auto note = &notes[itemIndex];
                auto editor = new MarkdownEditor(this, note);
                editor.show();
            }
        }
        return true;
    }

    private bool onSearchChanged(EditableContent source) {
        string query = source.text.to!string;
        if (query.length > 0) {
            auto searchResults = vaultManager.searchNotes(query);
            dstring[] noteItems;
            foreach(note; searchResults) {
                noteItems ~= format("%s (%s)", note.title, note.tags.join(", ")).to!dstring;
            }
            notesList.adapter = new StringListAdapter(noteItems);
        } else {
            refreshLists();
        }
        return true;
    }

    private void refreshLists() {
        // Update tags list
        auto tags = vaultManager.getAllTags();
        dstring[] tagItems = ["All Notes"d];
        foreach(tag; tags) {
            tagItems ~= tag.to!dstring;
        }
        updateTagsList();
        
        // Update notes list based on current filter
        Note[] filteredNotes;
        if (currentTagFilter && currentTagFilter != "All Notes") {
            filteredNotes = vaultManager.getNotesByTag(currentTagFilter);
        } else {
            filteredNotes = vaultManager.getAllNotes();
        }
        
        dstring[] noteItems;
        foreach(note; filteredNotes) {
            noteItems ~= format("%s (%s)", note.title, note.tags.join(", ")).to!dstring;
        }
        notesList.adapter = new StringListAdapter(noteItems);
    }

    private void setupSearchBox(EditLine searchBox) {
        searchBox.contentChange = (EditableContent source) {
            onSearchChanged(source);
        };
    }

    private void updateTagsList() {
        dstring[] tagItems = ["All Notes"d];
        auto tags = vaultManager.getAllTags();
        foreach(tag; tags) {
            tagItems ~= tag.to!dstring;
        }
        
        auto adapter = cast(StringListAdapter)tagsList.adapter;
        if (!adapter) {
            adapter = new StringListAdapter();
            tagsList.adapter = adapter;
        }
        adapter.items = tagItems;
    }
}

// Remove the main() function and use UIAppMain instead
extern (C) int UIAppMain(string[] args) {
    // Initialize SDL first
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER | SDL_INIT_EVENTS) < 0) {
        return 1;
    }
    scope(exit) SDL_Quit();

    // Initialize dlangui platform
    initLogs();
    Platform.setInstance(new SDLPlatform());
    Platform.instance.uiTheme = "theme_default";
    
    // Set up OpenGL attributes before window creation
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
    
    try {
        auto window = new NotesVaultWindow();
        if (!window) {
            Log.e("Failed to create window");
            return 1;
        }
        
        window.show();
        Log.i("Window shown");
        
        return Platform.instance.enterMessageLoop();
    } catch (Exception e) {
        Log.e("Error in main loop: ", e.msg);
        return 1;
    }
}

void main() {
    auto settings = new HTTPServerSettings;
    settings.port = 3000;
    
    auto router = new URLRouter;
    
    // API routes
    router.get("/api/notes", &getNotes);
    router.post("/api/notes", &createNote);
    router.get("/api/notes/:id", &getNote);
    router.put("/api/notes/:id", &updateNote);
    router.get("/api/tags", &getTags);
    
    // Serve frontend static files
    router.get("*", serveStaticFiles("./frontend/dist"));
    
    auto listener = listenHTTP(settings, router);
    scope(exit) listener.stopListening();
    
    logInfo("Server running on http://localhost:3000/");
    runApplication();
}

void getNotes(HTTPServerRequest req, HTTPServerResponse res) {
    auto vaultManager = new VaultManager();
    auto notes = vaultManager.getAllNotes();
    res.writeJsonBody(notes);
}

// ... other API handlers ... 