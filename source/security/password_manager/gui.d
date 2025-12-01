module security.password_manager.gui;

import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.lists;
import dlangui.widgets.popup;
import dlangui.dialogs.dialog;
import dlangui.widgets.editors;
import dlangui.widgets.menu;
import dlangui.core.events;
import dlangui.core.signals;

import std.string;
import std.conv;
import std.algorithm;
import std.array;
import std.datetime;
import std.file;
import std.path;

import security.password_manager.vault;
import security.crypto;

/// Password manager main window
class PasswordManagerWindow : AppFrame
{
    private PasswordVault _vault;
    private string _vaultPath;
    private VaultListWidget _entryList;
    private EditLine _searchEdit;
    private ComboBox _categoryFilter;
    private TextWidget _statusBar;
    private MenuItem _lockMenuItem;
    private MenuItem _unlockMenuItem;
    private TabWidget _mainTabs;

    // Entry details panel
    private EditLine _titleEdit;
    private EditLine _usernameEdit;
    private EditLine _emailEdit;
    private EditLine _passwordEdit;
    private EditLine _urlEdit;
    private EditBox _notesEdit;
    private EditLine _categoryEdit;
    private CheckBox _favoriteCheck;
    private Button _showPasswordBtn;
    private Button _copyPasswordBtn;
    private Button _generatePasswordBtn;

    private VaultEntry _currentEntry;
    private bool _isEditMode = false;

    this()
    {
        super();

        _vaultPath = buildPath(expandTilde("~"), ".dowel-steek", "vault.dsv");
        _vault = new PasswordVault(_vaultPath);

        windowCaption = "Password Manager";
        createUI();
        updateUI();
    }

    private void createUI()
    {
        // Create menu
        auto menuBar = new MenuBar();

        auto fileMenu = menuBar.addSubmenu("File");
        fileMenu.addAction(ACTION_FILE_NEW_VAULT, "New Vault"d);
        fileMenu.addAction(ACTION_FILE_OPEN_VAULT, "Open Vault"d);
        fileMenu.addSeparator();
        _unlockMenuItem = fileMenu.addAction(ACTION_UNLOCK_VAULT, "Unlock Vault"d);
        _lockMenuItem = fileMenu.addAction(ACTION_LOCK_VAULT, "Lock Vault"d);
        fileMenu.addSeparator();
        fileMenu.addAction(ACTION_FILE_EXPORT, "Export Vault"d);
        fileMenu.addAction(ACTION_FILE_IMPORT, "Import Vault"d);
        fileMenu.addSeparator();
        fileMenu.addAction(ACTION_FILE_EXIT, "Exit"d);

        auto entryMenu = menuBar.addSubmenu("Entry");
        entryMenu.addAction(ACTION_ENTRY_ADD, "Add Entry"d);
        entryMenu.addAction(ACTION_ENTRY_EDIT, "Edit Entry"d);
        entryMenu.addAction(ACTION_ENTRY_DELETE, "Delete Entry"d);
        entryMenu.addSeparator();
        entryMenu.addAction(ACTION_ENTRY_COPY_PASSWORD, "Copy Password"d);
        entryMenu.addAction(ACTION_ENTRY_COPY_USERNAME, "Copy Username"d);

        auto toolsMenu = menuBar.addSubmenu("Tools");
        toolsMenu.addAction(ACTION_TOOLS_GENERATOR, "Password Generator"d);
        toolsMenu.addAction(ACTION_TOOLS_SECURITY_REPORT, "Security Report"d);
        toolsMenu.addAction(ACTION_TOOLS_CHANGE_MASTER, "Change Master Password"d);

        mainWidget = menuBar;

        // Create main layout
        auto vbox = new VerticalLayout();
        vbox.layoutWidth = FILL_PARENT;
        vbox.layoutHeight = FILL_PARENT;

        // Toolbar
        auto toolbar = createToolbar();
        vbox.addChild(toolbar);

        // Main content area
        auto hbox = new HorizontalLayout();
        hbox.layoutWidth = FILL_PARENT;
        hbox.layoutHeight = FILL_PARENT;

        // Left panel - entry list
        auto leftPanel = createLeftPanel();
        hbox.addChild(leftPanel);

        // Splitter
        auto splitter = new Splitter("splitter");
        splitter.orientation = Orientation.Horizontal;
        splitter.layoutWidth = FILL_PARENT;
        splitter.layoutHeight = FILL_PARENT;
        splitter.addChild(leftPanel);

        // Right panel - entry details
        auto rightPanel = createRightPanel();
        splitter.addChild(rightPanel);

        vbox.addChild(splitter);

        // Status bar
        _statusBar = new TextWidget("statusBar");
        _statusBar.text = "Vault locked"d;
        _statusBar.backgroundColor = 0xFFEEEEEE;
        _statusBar.padding = Rect(5, 2, 5, 2);
        vbox.addChild(_statusBar);

        menuBar.addChild(vbox);
    }

    private Widget createToolbar()
    {
        auto toolbar = new HorizontalLayout("toolbar");
        toolbar.layoutWidth = FILL_PARENT;
        toolbar.layoutHeight = WRAP_CONTENT;
        toolbar.backgroundColor = 0xFFF0F0F0;
        toolbar.padding = Rect(5, 5, 5, 5);

        auto unlockBtn = new Button("unlockBtn", "Unlock"d);
        unlockBtn.click = delegate(Widget source) {
            onUnlockVault();
            return true;
        };
        toolbar.addChild(unlockBtn);

        auto lockBtn = new Button("lockBtn", "Lock"d);
        lockBtn.click = delegate(Widget source) {
            onLockVault();
            return true;
        };
        toolbar.addChild(lockBtn);

        toolbar.addChild(new HSpacer());

        auto addBtn = new Button("addBtn", "Add Entry"d);
        addBtn.click = delegate(Widget source) {
            onAddEntry();
            return true;
        };
        toolbar.addChild(addBtn);

        auto editBtn = new Button("editBtn", "Edit"d);
        editBtn.click = delegate(Widget source) {
            onEditEntry();
            return true;
        };
        toolbar.addChild(editBtn);

        auto deleteBtn = new Button("deleteBtn", "Delete"d);
        deleteBtn.click = delegate(Widget source) {
            onDeleteEntry();
            return true;
        };
        toolbar.addChild(deleteBtn);

        return toolbar;
    }

    private Widget createLeftPanel()
    {
        auto panel = new VerticalLayout("leftPanel");
        panel.layoutWidth = 300;
        panel.layoutHeight = FILL_PARENT;
        panel.backgroundColor = 0xFFFAFAFA;
        panel.padding = Rect(5, 5, 5, 5);

        // Search box
        _searchEdit = new EditLine("searchEdit");
        _searchEdit.text = ""d;
        _searchEdit.hint = "Search entries..."d;
        _searchEdit.contentChange = delegate(EditableContent content) {
            onSearchChanged();
        };
        panel.addChild(_searchEdit);

        // Category filter
        _categoryFilter = new ComboBox("categoryFilter");
        _categoryFilter.items = ["All Categories"d];
        _categoryFilter.selectedItemIndex = 0;
        _categoryFilter.selectionChange = delegate(Widget source, int index) {
            onCategoryFilterChanged();
            return true;
        };
        panel.addChild(_categoryFilter);

        // Entry list
        _entryList = new VaultListWidget("entryList");
        _entryList.layoutWidth = FILL_PARENT;
        _entryList.layoutHeight = FILL_PARENT;
        _entryList.selectionChange = delegate(Widget source, int index) {
            onEntrySelected(index);
            return true;
        };
        panel.addChild(_entryList);

        return panel;
    }

    private Widget createRightPanel()
    {
        _mainTabs = new TabWidget("mainTabs");
        _mainTabs.layoutWidth = FILL_PARENT;
        _mainTabs.layoutHeight = FILL_PARENT;

        // Entry details tab
        auto detailsTab = createDetailsTab();
        _mainTabs.addTab(detailsTab, "Details"d);

        // Security tab
        auto securityTab = createSecurityTab();
        _mainTabs.addTab(securityTab, "Security"d);

        return _mainTabs;
    }

    private Widget createDetailsTab()
    {
        auto scroll = new ScrollWidget("detailsScroll");
        scroll.layoutWidth = FILL_PARENT;
        scroll.layoutHeight = FILL_PARENT;

        auto grid = new TableLayout("detailsGrid");
        grid.colCount = 2;
        grid.layoutWidth = FILL_PARENT;
        grid.layoutHeight = WRAP_CONTENT;
        grid.padding = Rect(10, 10, 10, 10);

        // Title
        grid.addChild(new TextWidget(null, "Title:"d));
        _titleEdit = new EditLine("titleEdit");
        _titleEdit.enabled = false;
        grid.addChild(_titleEdit);

        // Username
        grid.addChild(new TextWidget(null, "Username:"d));
        _usernameEdit = new EditLine("usernameEdit");
        _usernameEdit.enabled = false;
        grid.addChild(_usernameEdit);

        // Email
        grid.addChild(new TextWidget(null, "Email:"d));
        _emailEdit = new EditLine("emailEdit");
        _emailEdit.enabled = false;
        grid.addChild(_emailEdit);

        // Password
        grid.addChild(new TextWidget(null, "Password:"d));
        auto passwordRow = new HorizontalLayout();
        _passwordEdit = new EditLine("passwordEdit");
        _passwordEdit.enabled = false;
        _passwordEdit.passwordChar = '*';
        passwordRow.addChild(_passwordEdit);

        _showPasswordBtn = new Button("showPasswordBtn", "Show"d);
        _showPasswordBtn.click = delegate(Widget source) {
            onTogglePasswordVisibility();
            return true;
        };
        passwordRow.addChild(_showPasswordBtn);

        _copyPasswordBtn = new Button("copyPasswordBtn", "Copy"d);
        _copyPasswordBtn.click = delegate(Widget source) {
            onCopyPassword();
            return true;
        };
        passwordRow.addChild(_copyPasswordBtn);

        _generatePasswordBtn = new Button("generatePasswordBtn", "Generate"d);
        _generatePasswordBtn.click = delegate(Widget source) {
            onGeneratePassword();
            return true;
        };
        passwordRow.addChild(_generatePasswordBtn);

        grid.addChild(passwordRow);

        // URL
        grid.addChild(new TextWidget(null, "URL:"d));
        _urlEdit = new EditLine("urlEdit");
        _urlEdit.enabled = false;
        grid.addChild(_urlEdit);

        // Category
        grid.addChild(new TextWidget(null, "Category:"d));
        _categoryEdit = new EditLine("categoryEdit");
        _categoryEdit.enabled = false;
        grid.addChild(_categoryEdit);

        // Favorite
        grid.addChild(new TextWidget(null, "Favorite:"d));
        _favoriteCheck = new CheckBox("favoriteCheck");
        _favoriteCheck.enabled = false;
        grid.addChild(_favoriteCheck);

        // Notes
        grid.addChild(new TextWidget(null, "Notes:"d));
        _notesEdit = new EditBox("notesEdit");
        _notesEdit.enabled = false;
        _notesEdit.layoutHeight = 100;
        grid.addChild(_notesEdit);

        // Action buttons
        auto buttonRow = new HorizontalLayout();
        buttonRow.layoutWidth = FILL_PARENT;

        buttonRow.addChild(new HSpacer());

        auto saveBtn = new Button("saveBtn", "Save"d);
        saveBtn.click = delegate(Widget source) {
            onSaveEntry();
            return true;
        };
        buttonRow.addChild(saveBtn);

        auto cancelBtn = new Button("cancelBtn", "Cancel"d);
        cancelBtn.click = delegate(Widget source) {
            onCancelEdit();
            return true;
        };
        buttonRow.addChild(cancelBtn);

        grid.addChild(new Widget()); // Empty cell
        grid.addChild(buttonRow);

        scroll.contentWidget = grid;
        return scroll;
    }

    private Widget createSecurityTab()
    {
        auto vbox = new VerticalLayout("securityTab");
        vbox.layoutWidth = FILL_PARENT;
        vbox.layoutHeight = FILL_PARENT;
        vbox.padding = Rect(10, 10, 10, 10);

        auto reportBtn = new Button("securityReportBtn", "Generate Security Report"d);
        reportBtn.click = delegate(Widget source) {
            onSecurityReport();
            return true;
        };
        vbox.addChild(reportBtn);

        vbox.addChild(new VSpacer());

        return vbox;
    }

    private void updateUI()
    {
        bool isUnlocked = !_vault.isLocked;

        _lockMenuItem.enabled = isUnlocked;
        _unlockMenuItem.enabled = !isUnlocked;

        if (auto unlockBtn = childById("unlockBtn"))
            unlockBtn.enabled = !isUnlocked;

        if (auto lockBtn = childById("lockBtn"))
            lockBtn.enabled = isUnlocked;

        if (auto addBtn = childById("addBtn"))
            addBtn.enabled = isUnlocked;

        if (auto editBtn = childById("editBtn"))
            editBtn.enabled = isUnlocked && _currentEntry.id.length > 0;

        if (auto deleteBtn = childById("deleteBtn"))
            deleteBtn.enabled = isUnlocked && _currentEntry.id.length > 0;

        _searchEdit.enabled = isUnlocked;
        _categoryFilter.enabled = isUnlocked;
        _entryList.enabled = isUnlocked;

        if (isUnlocked)
        {
            _statusBar.text = format("Vault unlocked - %d entries"d, _vault.entryCount);
            refreshEntryList();
            refreshCategoryFilter();
        }
        else
        {
            _statusBar.text = "Vault locked"d;
            _entryList.clear();
            clearEntryDetails();
        }
    }

    private void refreshEntryList()
    {
        if (_vault.isLocked)
            return;

        VaultFilter filter;

        string searchText = _searchEdit.text.to!string;
        if (searchText.length > 0)
            filter.searchQuery = searchText;

        int categoryIndex = _categoryFilter.selectedItemIndex;
        if (categoryIndex > 0 && categoryIndex < _categoryFilter.itemCount)
        {
            filter.category = _categoryFilter.items[categoryIndex].to!string;
        }

        auto entries = _vault.searchEntries(filter);
        _entryList.setEntries(entries);
    }

    private void refreshCategoryFilter()
    {
        if (_vault.isLocked)
            return;

        dstring[] categories = ["All Categories"d];
        foreach (cat; _vault.categories)
            categories ~= cat.to!dstring;

        _categoryFilter.items = categories;
        if (_categoryFilter.selectedItemIndex >= categories.length)
            _categoryFilter.selectedItemIndex = 0;
    }

    private void onUnlockVault()
    {
        auto dialog = new UnlockDialog(window);
        dialog.show();

        dialog.unlockClicked = delegate(string password) {
            if (_vault.unlock(password))
            {
                updateUI();
                return true;
            }
            else
            {
                window.showMessageBox("Error"d, "Invalid password"d);
                return false;
            }
        };
    }

    private void onLockVault()
    {
        _vault.lock();
        clearEntryDetails();
        updateUI();
    }

    private void onAddEntry()
    {
        if (_vault.isLocked)
            return;

        _currentEntry = VaultEntry("New Entry");
        _isEditMode = true;
        populateEntryDetails();
        setEditMode(true);
    }

    private void onEditEntry()
    {
        if (_vault.isLocked || _currentEntry.id.length == 0)
            return;

        _isEditMode = true;
        setEditMode(true);
    }

    private void onDeleteEntry()
    {
        if (_vault.isLocked || _currentEntry.id.length == 0)
            return;

        auto result = window.showMessageBox("Confirm Delete"d,
            format("Are you sure you want to delete '%s'?"d, _currentEntry.title),
            MessageBoxFlag.YesNo);

        if (result == DialogResult.Yes)
        {
            _vault.removeEntry(_currentEntry.id);
            _currentEntry = VaultEntry.init;
            clearEntryDetails();
            refreshEntryList();
        }
    }

    private void onSaveEntry()
    {
        if (_vault.isLocked)
            return;

        // Update entry from UI
        _currentEntry.title = _titleEdit.text.to!string;
        _currentEntry.username = _usernameEdit.text.to!string;
        _currentEntry.email = _emailEdit.text.to!string;
        _currentEntry.password = _passwordEdit.text.to!string;
        _currentEntry.url = _urlEdit.text.to!string;
        _currentEntry.category = _categoryEdit.text.to!string;
        _currentEntry.favorite = _favoriteCheck.checked;
        _currentEntry.notes = _notesEdit.text.to!string;

        if (_currentEntry.id.length == 0)
        {
            // New entry
            _vault.addEntry(_currentEntry);
        }
        else
        {
            // Update existing entry
            _vault.updateEntry(_currentEntry.id, _currentEntry);
        }

        _isEditMode = false;
        setEditMode(false);
        refreshEntryList();
        refreshCategoryFilter();
    }

    private void onCancelEdit()
    {
        _isEditMode = false;
        setEditMode(false);

        if (_currentEntry.id.length == 0)
        {
            // Cancel new entry
            clearEntryDetails();
        }
        else
        {
            // Revert changes
            populateEntryDetails();
        }
    }

    private void onCopyPassword()
    {
        if (_currentEntry.password.length > 0)
        {
            platform.setClipboardText(_currentEntry.password.to!dstring);
            window.showMessageBox("Password Copied"d, "Password copied to clipboard"d);
        }
    }

    private void onTogglePasswordVisibility()
    {
        if (_passwordEdit.passwordChar == '*')
        {
            _passwordEdit.passwordChar = 0;
            _showPasswordBtn.text = "Hide"d;
        }
        else
        {
            _passwordEdit.passwordChar = '*';
            _showPasswordBtn.text = "Show"d;
        }
    }

    private void onGeneratePassword()
    {
        auto dialog = new PasswordGeneratorDialog(window);
        dialog.show();

        dialog.passwordGenerated = delegate(string password) {
            _passwordEdit.text = password.to!dstring;
        };
    }

    private void onSecurityReport()
    {
        if (_vault.isLocked)
            return;

        auto report = _vault.generateSecurityReport();
        auto dialog = new SecurityReportDialog(window, report);
        dialog.show();
    }

    private void onEntrySelected(int index)
    {
        if (_vault.isLocked || index < 0)
        {
            clearEntryDetails();
            return;
        }

        auto entries = _entryList.getFilteredEntries();
        if (index < entries.length)
        {
            _currentEntry = entries[index];
            populateEntryDetails();
        }

        updateUI();
    }

    private void onSearchChanged()
    {
        refreshEntryList();
    }

    private void onCategoryFilterChanged()
    {
        refreshEntryList();
    }

    private void populateEntryDetails()
    {
        _titleEdit.text = _currentEntry.title.to!dstring;
        _usernameEdit.text = _currentEntry.username.to!dstring;
        _emailEdit.text = _currentEntry.email.to!dstring;
        _passwordEdit.text = _currentEntry.password.to!dstring;
        _urlEdit.text = _currentEntry.url.to!dstring;
        _categoryEdit.text = _currentEntry.category.to!dstring;
        _favoriteCheck.checked = _currentEntry.favorite;
        _notesEdit.text = _currentEntry.notes.to!dstring;
    }

    private void clearEntryDetails()
    {
        _currentEntry = VaultEntry.init;
        _titleEdit.text = ""d;
        _usernameEdit.text = ""d;
        _emailEdit.text = ""d;
        _passwordEdit.text = ""d;
        _urlEdit.text = ""d;
        _categoryEdit.text = ""d;
        _favoriteCheck.checked = false;
        _notesEdit.text = ""d;

        setEditMode(false);
    }

    private void setEditMode(bool enabled)
    {
        _titleEdit.enabled = enabled;
        _usernameEdit.enabled = enabled;
        _emailEdit.enabled = enabled;
        _passwordEdit.enabled = enabled;
        _urlEdit.enabled = enabled;
        _categoryEdit.enabled = enabled;
        _favoriteCheck.enabled = enabled;
        _notesEdit.enabled = enabled;

        if (auto saveBtn = childById("saveBtn"))
            saveBtn.enabled = enabled;

        if (auto cancelBtn = childById("cancelBtn"))
            cancelBtn.enabled = enabled;
    }

    override bool handleAction(const Action action)
    {
        switch (action.id)
        {
            case ACTION_FILE_NEW_VAULT:
                // TODO: Implement new vault creation
                return true;

            case ACTION_FILE_OPEN_VAULT:
                // TODO: Implement vault file selection
                return true;

            case ACTION_UNLOCK_VAULT:
                onUnlockVault();
                return true;

            case ACTION_LOCK_VAULT:
                onLockVault();
                return true;

            case ACTION_ENTRY_ADD:
                onAddEntry();
                return true;

            case ACTION_ENTRY_EDIT:
                onEditEntry();
                return true;

            case ACTION_ENTRY_DELETE:
                onDeleteEntry();
                return true;

            case ACTION_ENTRY_COPY_PASSWORD:
                onCopyPassword();
                return true;

            case ACTION_TOOLS_GENERATOR:
                onGeneratePassword();
                return true;

            case ACTION_TOOLS_SECURITY_REPORT:
                onSecurityReport();
                return true;

            default:
                return super.handleAction(action);
        }
    }
}

/// Custom list widget for vault entries
class VaultListWidget : ListWidget
{
    private VaultEntry[] _entries;
    private VaultEntry[] _filteredEntries;

    this(string id)
    {
        super(id, Orientation.Vertical);
    }

    void setEntries(VaultEntry[] entries)
    {
        _entries = entries;
        _filteredEntries = entries;
        updateList();
    }

    void clear()
    {
        _entries = [];
        _filteredEntries = [];
        updateList();
    }

    VaultEntry[] getFilteredEntries()
    {
        return _filteredEntries;
    }

    private void updateList()
    {
        removeAllChildren();

        foreach (i, entry; _filteredEntries)
        {
            auto item = createEntryItem(entry, cast(int)i);
            addChild(item);
        }
    }

    private Widget createEntryItem(VaultEntry entry, int index)
    {
        auto item = new HorizontalLayout();
        item.layoutWidth = FILL_PARENT;
        item.layoutHeight = WRAP_CONTENT;
        item.padding = Rect(5, 3, 5, 3);
        item.backgroundColor = index % 2 == 0 ? 0xFFFFFFFF : 0xFFF8F8F8;

        if (entry.favorite)
        {
            auto star = new TextWidget(null, "★"d);
            star.textColor = 0xFFFFD700;
            item.addChild(star);
        }

        auto vbox = new VerticalLayout();
        vbox.layoutWidth = FILL_PARENT;

        auto title = new TextWidget(null, entry.title.to!dstring);
        title.fontWeight = 600;
        vbox.addChild(title);

        if (entry.username.length > 0)
        {
            auto username = new TextWidget(null, entry.username.to!dstring);
            username.textColor = 0xFF666666;
            username.fontSize = 11;
            vbox.addChild(username);
        }

        item.addChild(vbox);

        // Add click handler
        item.click = delegate(Widget source) {
            if (selectionChange)
                selectionChange(this, index);
            return true;
        };

        return item;
    }
}

/// Dialog for unlocking the vault
class UnlockDialog : Dialog
{
    private EditLine _passwordEdit;
    bool delegate(string password) unlockClicked;

    this(Window parent)
    {
        super(UIString.fromRaw("Unlock Vault"), parent, DialogFlag.Modal);
        createUI();
    }

    private void createUI()
    {
        auto vbox = new VerticalLayout();
        vbox.margins = Rect(20, 20, 20, 20);

        vbox.addChild(new TextWidget(null, "Enter master password:"d));

        _passwordEdit = new EditLine("passwordEdit");
        _passwordEdit.passwordChar = '*';
        _passwordEdit.layoutWidth = 250;
        vbox.addChild(_passwordEdit);

        auto buttonRow = new HorizontalLayout();
        buttonRow.addChild(new HSpacer());

        auto unlockBtn = new Button("unlockBtn", "Unlock"d);
        unlockBtn.click = delegate(Widget source) {
            if (unlockClicked && unlockClicked(_passwordEdit.text.to!string))
                close();
            return true;
        };
        buttonRow.addChild(unlockBtn);

        auto cancelBtn = new Button("cancelBtn", "Cancel"d);
        cancelBtn.click = delegate(Widget source) {
            close();
            return true;
        };
        buttonRow.addChild(cancelBtn);

        vbox.addChild(buttonRow);
        addChild(vbox);
    }
}

/// Dialog for password generation
class PasswordGeneratorDialog : Dialog
{
    private EditLine _lengthEdit;
    private CheckBox _uppercaseCheck;
    private CheckBox _lowercaseCheck;
    private CheckBox _numbersCheck;
    private CheckBox _symbolsCheck;
    private CheckBox _excludeSimilarCheck;
    private EditLine _resultEdit;

    void delegate(string password) passwordGenerated;

    this(Window parent)
    {
        super(UIString.fromRaw("Password Generator"), parent, DialogFlag.Modal);
        createUI();
    }

    private void createUI()
    {
        auto vbox = new VerticalLayout();
        vbox.margins = Rect(20, 20, 20, 20);

        // Length
        auto lengthRow = new HorizontalLayout();
        lengthRow.addChild(new TextWidget(null, "Length:"d));
        _lengthEdit = new EditLine("lengthEdit");
        _lengthEdit.text = "16"d;
        _lengthEdit.layoutWidth = 60;
        lengthRow.addChild(_lengthEdit);
        vbox.addChild(lengthRow);

        // Character options
        _uppercaseCheck = new CheckBox("uppercaseCheck", "Uppercase (A-Z)"d);
        _uppercaseCheck.checked = true;
        vbox.addChild(_uppercaseCheck);

        _lowercaseCheck = new CheckBox("lowercaseCheck", "Lowercase (a-z)"d);
        _lowercaseCheck.checked = true;
        vbox.addChild(_lowercaseCheck);

        _numbersCheck = new CheckBox("numbersCheck", "Numbers (0-9)"d);
        _numbersCheck.checked = true;
        vbox.addChild(_numbersCheck);

        _symbolsCheck = new CheckBox("symbolsCheck", "Symbols (!@#$%)"d);
        _symbolsCheck.checked = true;
        vbox.addChild(_symbolsCheck);

        _excludeSimilarCheck = new CheckBox("excludeSimilarCheck", "Exclude similar characters"d);
        _excludeSimilarCheck.checked = true;
        vbox.addChild(_excludeSimilarCheck);

        // Generate button
        auto generateBtn = new Button("generateBtn", "Generate"d);
        generateBtn.click = delegate(Widget source) {
            generatePassword();
            return true;
        };
        vbox.addChild(generateBtn);

        // Result
        _resultEdit = new EditLine("resultEdit");
        _resultEdit.layoutWidth = 300;
        vbox.addChild(_resultEdit);

        // Action buttons
        auto buttonRow = new HorizontalLayout();
        buttonRow.addChild(new HSpacer());

        auto useBtn = new Button("useBtn", "Use Password"d);
        useBtn.click = delegate(Widget source) {
            if (passwordGenerated && _resultEdit.text.length > 0)
            {
                passwordGenerated(_resultEdit.text.to!string);
                close();
            }
            return true;
        };
        buttonRow.addChild(useBtn);

        auto cancelBtn = new Button("cancelBtn", "Cancel"d);
        cancelBtn.click = delegate(Widget source) {
            close();
            return true;
        };
        buttonRow.addChild(cancelBtn);

        vbox.addChild(buttonRow);
        addChild(vbox);

        generatePassword(); // Generate initial password
    }

    private void generatePassword()
    {
        try
        {
            PasswordGenerator.Options options;
            options.length = _lengthEdit.text.to!string.to!int;

            PasswordGenerator.CharsetType charsets = cast(PasswordGenerator.CharsetType)0;
            if (_uppercaseCheck.checked) charsets |= PasswordGenerator.CharsetType.Uppercase;
            if (_lowercaseCheck.checked) charsets |= PasswordGenerator.CharsetType.Lowercase;
            if (_numbersCheck.checked) charsets |= PasswordGenerator.CharsetType.Numbers;
            if (_symbolsCheck.checked) charsets |= PasswordGenerator.CharsetType.Symbols;

            options.charsets = charsets;
            options.excludeSimilar = _excludeSimilarCheck.checked;

            string password = PasswordGenerator.generate(options);
            _resultEdit.text = password.to!dstring;
        }
        catch (Exception e)
        {
            _resultEdit.text = "Error generating password"d;
        }
    }
}

/// Dialog for displaying security report
class SecurityReportDialog : Dialog
{
    this(Window parent, PasswordVault.SecurityReport report)
    {
        super(UIString.fromRaw("Security Report"), parent, DialogFlag.Modal);
        createUI(report);
    }

    private void createUI(PasswordVault.SecurityReport report)
    {
        auto vbox = new VerticalLayout();
        vbox.margins = Rect(20, 20, 20, 20);
        vbox.layoutWidth = 500;
        vbox.layoutHeight = 400;

        // Overall score
        auto scoreText = new TextWidget(null,
            format("Overall Security Score: %d/100"d, report.overallScore));
        scoreText.fontSize = 14;
        scoreText.fontWeight = 600;
        if (report.overallScore >= 80)
            scoreText.textColor = 0xFF00AA00;
        else if (report.overallScore >= 60)
            scoreText.textColor = 0xFFFF8800;
        else
            scoreText.textColor = 0xFFDD0000;
        vbox.addChild(scoreText);

        // Statistics
        auto statsGrid = new TableLayout();
        statsGrid.colCount = 2;
        statsGrid.layoutWidth = FILL_PARENT;

        statsGrid.addChild(new TextWidget(null, "Total Entries:"d));
        statsGrid.addChild(new TextWidget(null, format("%d"d, report.totalEntries)));

        statsGrid.addChild(new TextWidget(null, "Weak Passwords:"d));
        auto weakText = new TextWidget(null, format("%d"d, report.weakPasswords));
        if (report.weakPasswords > 0) weakText.textColor = 0xFFDD0000;
        statsGrid.addChild(weakText);

        statsGrid.addChild(new TextWidget(null, "Duplicate Passwords:"d));
        auto dupText = new TextWidget(null, format("%d"d, report.duplicatePasswords));
        if (report.duplicatePasswords > 0) dupText.textColor = 0xFFDD0000;
        statsGrid.addChild(dupText);

        statsGrid.addChild(new TextWidget(null, "Old Passwords (>1 year):"d));
        auto oldText = new TextWidget(null, format("%d"d, report.oldPasswords));
        if (report.oldPasswords > 0) oldText.textColor = 0xFFFF8800;
        statsGrid.addChild(oldText);

        statsGrid.addChild(new TextWidget(null, "Missing 2FA:"d));
        auto no2faText = new TextWidget(null, format("%d"d, report.without2FA));
        if (report.without2FA > 0) no2faText.textColor = 0xFFFF8800;
        statsGrid.addChild(no2faText);

        vbox.addChild(statsGrid);

        // Weak entries list
        if (report.weakEntries.length > 0)
        {
            vbox.addChild(new TextWidget(null, "Entries that need attention:"d));

            auto scrollWidget = new ScrollWidget();
            scrollWidget.layoutWidth = FILL_PARENT;
            scrollWidget.layoutHeight = 150;

            auto listWidget = new VerticalLayout();
            foreach (entry; report.weakEntries)
            {
                auto entryWidget = new TextWidget(null,
                    format("• %s (%s)"d, entry.title, entry.username));
                entryWidget.fontSize = 11;
                listWidget.addChild(entryWidget);
            }

            scrollWidget.contentWidget = listWidget;
            vbox.addChild(scrollWidget);
        }

        // Close button
        auto closeBtn = new Button("closeBtn", "Close"d);
        closeBtn.click = delegate(Widget source) {
            close();
            return true;
        };

        auto buttonRow = new HorizontalLayout();
        buttonRow.addChild(new HSpacer());
        buttonRow.addChild(closeBtn);
        vbox.addChild(buttonRow);

        addChild(vbox);
    }
}

// Action IDs for menu items
enum
{
    ACTION_FILE_NEW_VAULT = 1000,
    ACTION_FILE_OPEN_VAULT,
    ACTION_FILE_EXPORT,
    ACTION_FILE_IMPORT,
    ACTION_FILE_EXIT,
    ACTION_UNLOCK_VAULT,
    ACTION_LOCK_VAULT,
    ACTION_ENTRY_ADD,
    ACTION_ENTRY_EDIT,
    ACTION_ENTRY_DELETE,
    ACTION_ENTRY_COPY_PASSWORD,
    ACTION_ENTRY_COPY_USERNAME,
    ACTION_TOOLS_GENERATOR,
    ACTION_TOOLS_SECURITY_REPORT,
    ACTION_TOOLS_CHANGE_MASTER
}
