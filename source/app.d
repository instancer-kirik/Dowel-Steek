import dlangui;
import dlangui.widgets.lists;
import dlangui.widgets.controls;
import dlangui.widgets.layouts;
import dlangui.platforms.common.platform;
import std.format : format;
import std.conv : to;
import std.array : join;
import std.stdio;
import std.file;
import std.path;
import vault;
import editor;
import note;

class NotesVaultWindow : Window {
    private VaultManager vaultManager;
    private ListWidget notesList;
    private ListWidget tagsList;
    private string currentTagFilter;
    
    this() {
        super();
        windowCaption = "Notes Vault Manager"d;
        vaultManager = new VaultManager();
        
        // Create main layout
        auto mainLayout = new VerticalLayout();
        mainLayout.padding(Rect(10, 10, 10, 10));
        mainLayout.backgroundColor = 0xFFFFFF;
        
        // Add toolbar
        auto toolbar = new HorizontalLayout();
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
        
        // Add tags panel
        auto tagsPanel = new VerticalLayout();
        tagsPanel.addChild(new TextWidget(null, "Tags"d));
        tagsList = new ListWidget(null);
        tagsPanel.addChild(tagsList);
        
        // Create split layout with proper weights
        auto splitLayout = new HorizontalLayout();
        splitLayout.layoutWidth = FILL_PARENT;
        splitLayout.layoutHeight = FILL_PARENT;
        
        auto notesPane = new VerticalLayout();
        notesPane.layoutWidth = FILL_PARENT;
        notesPane.layoutHeight = FILL_PARENT;
        notesPane.addChild(notesList);
        
        auto tagsPane = new VerticalLayout();
        tagsPane.layoutWidth = FILL_PARENT;
        tagsPane.layoutHeight = FILL_PARENT;
        tagsPane.addChild(tagsList);
        
        splitLayout.addChild(notesPane);
        splitLayout.addChild(tagsPane);
        
        // Add all to main layout
        mainLayout.addChild(toolbar);
        mainLayout.addChild(splitLayout);
        
        // Set window content
        contentWidget = mainLayout;
        
        // Update tag list click handler
        tagsList.itemClick = &onTagSelected;
        
        // Add "All Notes" to tags list
        updateTagsList();
        
        // Update notes list click handler
        notesList.itemClick = &onNoteSelected;
        
        // Initial refresh
        refreshLists();
    }

    override void show() {
        Platform.instance.showWindow(this);
    }
    
    override dstring windowCaption() const @property {
        return "Notes Vault Manager"d;
    }
    
    override void windowCaption(dstring caption) @property {
        super.windowCaption = caption;
    }
    
    override void windowIcon(DrawBufRef icon) @property {
        super.windowIcon = icon;
    }
    
    override void invalidate() {
        Platform.instance.invalidateWindow(this);
    }
    
    override void close() {
        Platform.instance.closeWindow(this);
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
        if (itemIndex >= 0 && itemIndex < tagsList.items.length) {
            currentTagFilter = itemIndex == 0 ? null : tagsList.items[itemIndex].to!string;
            refreshLists();
        }
        return true;
    }
    
    private bool onNoteSelected(Widget source, int itemIndex) {
        if (itemIndex >= 0 && itemIndex < notesList.items.length) {
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
        auto adapter = cast(StringListAdapter)tagsList.adapter;
        if (!adapter) {
            adapter = new StringListAdapter();
            tagsList.adapter = adapter;
        }
        adapter.items = tagItems;
    }
}

mixin APP_ENTRY_POINT;

extern (C) int UIAppMain(string[] args) {
    // Initialize GUI platform
    if (!Platform.instance) {
        Platform.instance = Platform.create();
    }
    
    Platform.instance.uiTheme = "theme_default";
    Window window = new NotesVaultWindow();
    window.show();
    
    return Platform.instance.enterMessageLoop();
} 