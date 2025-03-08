module notes.window;

import dlangui;
import dlangui.widgets.widget;
import dlangui.platforms.common.platform;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.editors;
import dlangui.widgets.lists;
import dlangui.core.events;
import dlangui.core.types;
import dlangui.core.signals;
import dlangui.core.editable;

import notes.vault;
import notes.note;

/// Window for managing and editing notes
class NotesVaultWindow : Window {
    private VaultManager vaultManager;
    private ListWidget notesList;
    private ListWidget tagsList;
    private EditBox searchBox;
    private EditBox editor;
    private dstring _windowCaption = "Notes"d;
    
    this() {
        super();
        
        try {
            // Create main layout
            auto mainLayout = new VerticalLayout();
            mainLayout.layoutWidth = FILL_PARENT;
            mainLayout.layoutHeight = FILL_PARENT;
            mainLayout.backgroundColor = 0xFFFFFF;
            mainLayout.padding(Rect(10, 10, 10, 10));
            
            // Initialize vault manager
            vaultManager = new VaultManager();
            
            // Create toolbar
            auto toolbar = new HorizontalLayout();
            toolbar.layoutWidth = FILL_PARENT;
            
            // Add note button
            auto addNoteBtn = new Button(null, "New Note"d);
            addNoteBtn.click = &onAddNote;
            toolbar.addChild(addNoteBtn);
            
            // Search box
            searchBox = new EditBox("search");
            searchBox.layoutWidth = FILL_PARENT;
            searchBox.text = ""d;
            searchBox.contentChange = delegate void(EditableContent content) {
                onSearch(content);
            };
            toolbar.addChild(searchBox);
            
            // Create split layout
            auto splitLayout = new HorizontalLayout();
            splitLayout.layoutWidth = FILL_PARENT;
            splitLayout.layoutHeight = FILL_PARENT;
            
            // Notes list panel
            auto notesPanel = new VerticalLayout();
            notesPanel.layoutWidth = FILL_PARENT;
            notesPanel.layoutHeight = FILL_PARENT;
            
            notesList = new ListWidget(null);
            notesList.layoutWidth = FILL_PARENT;
            notesList.layoutHeight = FILL_PARENT;
            notesList.itemClick = &onNoteSelected;
            notesPanel.addChild(notesList);
            
            // Editor panel
            auto editorPanel = new VerticalLayout();
            editorPanel.layoutWidth = FILL_PARENT;
            editorPanel.layoutHeight = FILL_PARENT;
            
            editor = new EditBox("editor");
            editor.layoutWidth = FILL_PARENT;
            editor.layoutHeight = FILL_PARENT;
            editor.minHeight = 200;  // Give it reasonable minimum height
            editor.text = ""d;  // Initialize empty text
            editor.contentChange = delegate void(EditableContent content) {
                onEditorChange(content);
            };
            editorPanel.addChild(editor);
            
            // Add panels to split layout
            splitLayout.addChild(notesPanel);
            splitLayout.addChild(editorPanel);
            
            // Add all to main layout
            mainLayout.addChild(toolbar);
            mainLayout.addChild(splitLayout);
            
            // Set main widget
            mainWidget = mainLayout;
            
            // Load initial notes
            refreshNotesList();
            
        } catch (Exception e) {
            Log.e("NotesVaultWindow init error: ", e.msg);
        }
    }

    private bool onAddNote(Widget w) {
        try {
            auto note = vaultManager.createNote("New Note");
            refreshNotesList();
            selectNote(note);
            return true;
        } catch (Exception e) {
            Log.e("Add note error: ", e.msg);
            return false;
        }
    }

    private void onSearch(EditableContent content) {
        refreshNotesList(content.text);
    }

    private bool onNoteSelected(Widget w, int index) {
        // TODO: Load selected note into editor
        return true;
    }

    private void onEditorChange(EditableContent content) {
        // TODO: Save note changes
    }

    private void refreshNotesList(dstring filter = ""d) {
        // TODO: Update notes list with optional filter
    }

    private void selectNote(Note note) {
        // TODO: Select note in list and load in editor
    }

    // Required Window overrides
    override void invalidate() {
        if (mainWidget)
            mainWidget.invalidate();
    }

    override void close() {
        if (mainWidget)
            mainWidget.removeAllChildren();
        Platform.instance.closeWindow(this);
    }

    override @property dstring windowCaption() const {
        return _windowCaption;
    }

    override @property void windowCaption(dstring caption) {
        _windowCaption = caption;
    }

    override @property void windowIcon(DrawBufRef icon) {
        // Optional: implement icon support
    }

    override void show() {
        try {
            // Create window with proper flags
            auto window = Platform.instance.createWindow(windowCaption, null,
                WindowFlag.Resizable,
                600, 400);
            
            if (!window) {
                Log.e("Failed to create notes window");
                return;
            }
            
            // Set up main widget
            if (mainWidget) {
                window.mainWidget = mainWidget;
                mainWidget.invalidate();
            }
            
            window.show();
            
        } catch (Exception e) {
            Log.e("Show notes window error: ", e.msg);
        }
    }
} 

 