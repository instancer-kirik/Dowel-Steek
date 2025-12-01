module security.authenticator.gui;

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
import std.format;

import security.authenticator.totp;

/// TOTP Authenticator main window
class AuthenticatorWindow : AppFrame
{
    private TOTPAuthenticator _authenticator;
    private string _authPath;
    private AuthenticatorListWidget _accountList;
    private EditLine _searchEdit;
    private TextWidget _statusBar;
    private MenuItem _lockMenuItem;
    private MenuItem _unlockMenuItem;

    // Timer for updating TOTP codes
    private ulong _updateTimer;

    this()
    {
        super();

        _authPath = buildPath(expandTilde("~"), ".dowel-steek", "authenticator.dsa");
        _authenticator = new TOTPAuthenticator(_authPath);

        windowCaption = "TOTP Authenticator";
        createUI();
        updateUI();
    }

    private void createUI()
    {
        // Create menu
        auto menuBar = new MenuBar();

        auto fileMenu = menuBar.addSubmenu("File");
        fileMenu.addAction(ACTION_FILE_NEW_AUTH, "New Authenticator"d);
        fileMenu.addAction(ACTION_FILE_OPEN_AUTH, "Open Authenticator"d);
        fileMenu.addSeparator();
        _unlockMenuItem = fileMenu.addAction(ACTION_UNLOCK_AUTH, "Unlock"d);
        _lockMenuItem = fileMenu.addAction(ACTION_LOCK_AUTH, "Lock"d);
        fileMenu.addSeparator();
        fileMenu.addAction(ACTION_FILE_EXPORT_AUTH, "Export Backup"d);
        fileMenu.addAction(ACTION_FILE_IMPORT_AUTH, "Import Backup"d);
        fileMenu.addSeparator();
        fileMenu.addAction(ACTION_FILE_EXIT, "Exit"d);

        auto accountMenu = menuBar.addSubmenu("Account");
        accountMenu.addAction(ACTION_ACCOUNT_ADD, "Add Account"d);
        accountMenu.addAction(ACTION_ACCOUNT_ADD_QR, "Scan QR Code"d);
        accountMenu.addAction(ACTION_ACCOUNT_EDIT, "Edit Account"d);
        accountMenu.addAction(ACTION_ACCOUNT_DELETE, "Delete Account"d);
        accountMenu.addSeparator();
        accountMenu.addAction(ACTION_ACCOUNT_COPY_CODE, "Copy Code"d);

        mainWidget = menuBar;

        // Create main layout
        auto vbox = new VerticalLayout();
        vbox.layoutWidth = FILL_PARENT;
        vbox.layoutHeight = FILL_PARENT;

        // Toolbar
        auto toolbar = createToolbar();
        vbox.addChild(toolbar);

        // Search box
        _searchEdit = new EditLine("searchEdit");
        _searchEdit.hint = "Search accounts..."d;
        _searchEdit.layoutWidth = FILL_PARENT;
        _searchEdit.contentChange = delegate(EditableContent content) {
            onSearchChanged();
        };
        vbox.addChild(_searchEdit);

        // Account list
        _accountList = new AuthenticatorListWidget("accountList");
        _accountList.layoutWidth = FILL_PARENT;
        _accountList.layoutHeight = FILL_PARENT;
        _accountList.accountSelected = delegate(string accountId) {
            onAccountSelected(accountId);
        };
        _accountList.copyCodeRequested = delegate(string accountId) {
            onCopyCode(accountId);
        };
        vbox.addChild(_accountList);

        // Status bar
        _statusBar = new TextWidget("statusBar");
        _statusBar.text = "Authenticator locked"d;
        _statusBar.backgroundColor = 0xFFEEEEEE;
        _statusBar.padding = Rect(5, 2, 5, 2);
        vbox.addChild(_statusBar);

        menuBar.addChild(vbox);

        // Start update timer
        _updateTimer = setTimer(1000); // Update every second
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
            onUnlockAuth();
            return true;
        };
        toolbar.addChild(unlockBtn);

        auto lockBtn = new Button("lockBtn", "Lock"d);
        lockBtn.click = delegate(Widget source) {
            onLockAuth();
            return true;
        };
        toolbar.addChild(lockBtn);

        toolbar.addChild(new HSpacer());

        auto addBtn = new Button("addBtn", "Add Account"d);
        addBtn.click = delegate(Widget source) {
            onAddAccount();
            return true;
        };
        toolbar.addChild(addBtn);

        auto scanBtn = new Button("scanBtn", "Scan QR"d);
        scanBtn.click = delegate(Widget source) {
            onScanQR();
            return true;
        };
        toolbar.addChild(scanBtn);

        return toolbar;
    }

    private void updateUI()
    {
        bool isUnlocked = !_authenticator.isLocked;

        _lockMenuItem.enabled = isUnlocked;
        _unlockMenuItem.enabled = !isUnlocked;

        if (auto unlockBtn = childById("unlockBtn"))
            unlockBtn.enabled = !isUnlocked;

        if (auto lockBtn = childById("lockBtn"))
            lockBtn.enabled = isUnlocked;

        if (auto addBtn = childById("addBtn"))
            addBtn.enabled = isUnlocked;

        if (auto scanBtn = childById("scanBtn"))
            scanBtn.enabled = isUnlocked;

        _searchEdit.enabled = isUnlocked;
        _accountList.enabled = isUnlocked;

        if (isUnlocked)
        {
            _statusBar.text = format("Authenticator unlocked - %d accounts"d, _authenticator.accountCount);
            refreshAccountList();
        }
        else
        {
            _statusBar.text = "Authenticator locked"d;
            _accountList.clear();
        }
    }

    private void refreshAccountList()
    {
        if (_authenticator.isLocked)
            return;

        string searchText = _searchEdit.text.to!string;
        TOTPAccount[] accounts;

        if (searchText.length > 0)
            accounts = _authenticator.searchAccounts(searchText);
        else
            accounts = _authenticator.getAllAccounts();

        _accountList.setAccounts(accounts);
    }

    private void onUnlockAuth()
    {
        auto dialog = new UnlockAuthDialog(window);
        dialog.show();

        dialog.unlockClicked = delegate(string password) {
            if (_authenticator.unlock(password))
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

    private void onLockAuth()
    {
        _authenticator.lock();
        updateUI();
    }

    private void onAddAccount()
    {
        if (_authenticator.isLocked)
            return;

        auto dialog = new AddAccountDialog(window);
        dialog.show();

        dialog.accountAdded = delegate(string issuer, string accountName, string secret) {
            try
            {
                auto account = TOTPAccount(issuer, accountName, secret);
                _authenticator.addAccount(account);
                refreshAccountList();
                return true;
            }
            catch (Exception e)
            {
                window.showMessageBox("Error"d, format("Failed to add account: %s"d, e.msg));
                return false;
            }
        };
    }

    private void onScanQR()
    {
        if (_authenticator.isLocked)
            return;

        auto dialog = new QRScanDialog(window);
        dialog.show();

        dialog.qrScanned = delegate(string otpAuthUrl) {
            try
            {
                _authenticator.addAccountFromUrl(otpAuthUrl);
                refreshAccountList();
                return true;
            }
            catch (Exception e)
            {
                window.showMessageBox("Error"d, format("Failed to add account: %s"d, e.msg));
                return false;
            }
        };
    }

    private void onAccountSelected(string accountId)
    {
        // Account selected - maybe show details in future
    }

    private void onCopyCode(string accountId)
    {
        if (_authenticator.isLocked)
            return;

        auto account = _authenticator.getAccount(accountId);
        if (account)
        {
            try
            {
                string code = account.generateCode();
                platform.setClipboardText(code.to!dstring);
                window.showMessageBox("Code Copied"d, format("Code %s copied to clipboard"d, code));
            }
            catch (Exception e)
            {
                window.showMessageBox("Error"d, format("Failed to generate code: %s"d, e.msg));
            }
        }
    }

    private void onSearchChanged()
    {
        refreshAccountList();
    }

    override bool onTimer(ulong id)
    {
        if (id == _updateTimer)
        {
            // Update TOTP codes in the list
            if (!_authenticator.isLocked)
                _accountList.updateCodes();
            return true; // Keep timer running
        }
        return super.onTimer(id);
    }

    override bool handleAction(const Action action)
    {
        switch (action.id)
        {
            case ACTION_UNLOCK_AUTH:
                onUnlockAuth();
                return true;

            case ACTION_LOCK_AUTH:
                onLockAuth();
                return true;

            case ACTION_ACCOUNT_ADD:
                onAddAccount();
                return true;

            case ACTION_ACCOUNT_ADD_QR:
                onScanQR();
                return true;

            case ACTION_ACCOUNT_COPY_CODE:
                // Copy code for selected account
                return true;

            default:
                return super.handleAction(action);
        }
    }
}

/// Custom list widget for TOTP accounts
class AuthenticatorListWidget : ScrollWidget
{
    private TOTPAccount[] _accounts;
    private VerticalLayout _container;

    void delegate(string accountId) accountSelected;
    void delegate(string accountId) copyCodeRequested;

    this(string id)
    {
        super(id);
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;

        _container = new VerticalLayout();
        _container.layoutWidth = FILL_PARENT;
        _container.layoutHeight = WRAP_CONTENT;
        contentWidget = _container;
    }

    void setAccounts(TOTPAccount[] accounts)
    {
        _accounts = accounts;
        updateList();
    }

    void clear()
    {
        _accounts = [];
        updateList();
    }

    void updateCodes()
    {
        // Update the displayed codes for all accounts
        foreach (i, account; _accounts)
        {
            auto accountWidget = _container.child(cast(int)i);
            if (auto totpWidget = cast(TOTPAccountWidget)accountWidget)
            {
                totpWidget.updateCode();
            }
        }
    }

    private void updateList()
    {
        _container.removeAllChildren();

        foreach (account; _accounts)
        {
            auto accountWidget = new TOTPAccountWidget(account);
            accountWidget.codeClicked = delegate() {
                if (copyCodeRequested)
                    copyCodeRequested(account.id);
            };
            accountWidget.accountClicked = delegate() {
                if (accountSelected)
                    accountSelected(account.id);
            };
            _container.addChild(accountWidget);
        }
    }
}

/// Widget for displaying a single TOTP account
class TOTPAccountWidget : HorizontalLayout
{
    private TOTPAccount _account;
    private TextWidget _codeText;
    private TextWidget _progressText;
    private Widget _progressBar;

    void delegate() codeClicked;
    void delegate() accountClicked;

    this(TOTPAccount account)
    {
        super();
        _account = account;

        layoutWidth = FILL_PARENT;
        layoutHeight = WRAP_CONTENT;
        backgroundColor = 0xFFFFFFFF;
        margins = Rect(2, 2, 2, 2);
        padding = Rect(10, 8, 10, 8);

        createUI();
        updateCode();
    }

    private void createUI()
    {
        // Account info section
        auto infoSection = new VerticalLayout();
        infoSection.layoutWidth = FILL_PARENT;

        // Issuer and account name
        auto titleText = new TextWidget();
        if (_account.issuer.length > 0)
            titleText.text = format("%s (%s)"d, _account.issuer, _account.accountName);
        else
            titleText.text = _account.accountName.to!dstring;
        titleText.fontWeight = 600;
        titleText.fontSize = 12;
        infoSection.addChild(titleText);

        // Progress indicator
        _progressText = new TextWidget();
        _progressText.fontSize = 10;
        _progressText.textColor = 0xFF666666;
        infoSection.addChild(_progressText);

        addChild(infoSection);

        // Code section
        auto codeSection = new VerticalLayout();
        codeSection.layoutWidth = WRAP_CONTENT;

        _codeText = new TextWidget();
        _codeText.fontSize = 18;
        _codeText.fontWeight = 700;
        _codeText.fontFamily = "monospace";
        _codeText.textColor = 0xFF2196F3;
        _codeText.click = delegate(Widget source) {
            if (codeClicked)
                codeClicked();
            return true;
        };
        codeSection.addChild(_codeText);

        // Progress bar
        _progressBar = new Widget();
        _progressBar.layoutWidth = 80;
        _progressBar.layoutHeight = 4;
        _progressBar.backgroundColor = 0xFFDDDDDD;
        codeSection.addChild(_progressBar);

        addChild(codeSection);

        // Add click handler for entire widget
        click = delegate(Widget source) {
            if (accountClicked)
                accountClicked();
            return true;
        };
    }

    void updateCode()
    {
        try
        {
            string code = _account.generateCode();
            int remaining = _account.getRemainingSeconds();
            double progress = _account.getProgress();

            // Format code with spacing (123 456)
            if (code.length == 6)
                _codeText.text = format("%s %s"d, code[0..3], code[3..6]);
            else
                _codeText.text = code.to!dstring;

            // Update progress text
            _progressText.text = format("%d seconds remaining"d, remaining);

            // Update progress bar color based on remaining time
            if (remaining <= 5)
                _progressBar.backgroundColor = 0xFFFF5252; // Red
            else if (remaining <= 10)
                _progressBar.backgroundColor = 0xFFFF9800; // Orange
            else
                _progressBar.backgroundColor = 0xFF4CAF50; // Green

            // Update progress bar width
            int barWidth = cast(int)(80 * (1.0 - progress));
            _progressBar.layoutWidth = barWidth;
        }
        catch (Exception e)
        {
            _codeText.text = "ERROR"d;
            _progressText.text = "Failed to generate code"d;
        }
    }
}

/// Dialog for unlocking the authenticator
class UnlockAuthDialog : Dialog
{
    private EditLine _passwordEdit;
    bool delegate(string password) unlockClicked;

    this(Window parent)
    {
        super(UIString.fromRaw("Unlock Authenticator"), parent, DialogFlag.Modal);
        createUI();
    }

    private void createUI()
    {
        auto vbox = new VerticalLayout();
        vbox.margins = Rect(20, 20, 20, 20);

        vbox.addChild(new TextWidget(null, "Enter authenticator password:"d));

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

/// Dialog for manually adding a TOTP account
class AddAccountDialog : Dialog
{
    private EditLine _issuerEdit;
    private EditLine _accountEdit;
    private EditLine _secretEdit;

    bool delegate(string issuer, string account, string secret) accountAdded;

    this(Window parent)
    {
        super(UIString.fromRaw("Add Account"), parent, DialogFlag.Modal);
        createUI();
    }

    private void createUI()
    {
        auto vbox = new VerticalLayout();
        vbox.margins = Rect(20, 20, 20, 20);

        auto grid = new TableLayout();
        grid.colCount = 2;

        // Issuer
        grid.addChild(new TextWidget(null, "Issuer:"d));
        _issuerEdit = new EditLine("issuerEdit");
        _issuerEdit.layoutWidth = 200;
        grid.addChild(_issuerEdit);

        // Account
        grid.addChild(new TextWidget(null, "Account:"d));
        _accountEdit = new EditLine("accountEdit");
        _accountEdit.layoutWidth = 200;
        grid.addChild(_accountEdit);

        // Secret
        grid.addChild(new TextWidget(null, "Secret:"d));
        _secretEdit = new EditLine("secretEdit");
        _secretEdit.layoutWidth = 200;
        grid.addChild(_secretEdit);

        vbox.addChild(grid);

        auto buttonRow = new HorizontalLayout();
        buttonRow.addChild(new HSpacer());

        auto addBtn = new Button("addBtn", "Add"d);
        addBtn.click = delegate(Widget source) {
            string issuer = _issuerEdit.text.to!string;
            string account = _accountEdit.text.to!string;
            string secret = _secretEdit.text.to!string;

            if (account.length == 0 || secret.length == 0)
            {
                window.showMessageBox("Error"d, "Account name and secret are required"d);
                return true;
            }

            if (accountAdded && accountAdded(issuer, account, secret))
                close();
            return true;
        };
        buttonRow.addChild(addBtn);

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

/// Dialog for scanning QR codes (placeholder for now)
class QRScanDialog : Dialog
{
    private EditLine _urlEdit;
    bool delegate(string otpAuthUrl) qrScanned;

    this(Window parent)
    {
        super(UIString.fromRaw("Scan QR Code"), parent, DialogFlag.Modal);
        createUI();
    }

    private void createUI()
    {
        auto vbox = new VerticalLayout();
        vbox.margins = Rect(20, 20, 20, 20);

        vbox.addChild(new TextWidget(null, "Paste otpauth:// URL:"d));

        _urlEdit = new EditLine("urlEdit");
        _urlEdit.layoutWidth = 400;
        _urlEdit.hint = "otpauth://totp/..."d;
        vbox.addChild(_urlEdit);

        auto noteText = new TextWidget(null, "Note: QR code scanning requires camera support"d);
        noteText.fontSize = 10;
        noteText.textColor = 0xFF666666;
        vbox.addChild(noteText);

        auto buttonRow = new HorizontalLayout();
        buttonRow.addChild(new HSpacer());

        auto addBtn = new Button("addBtn", "Add Account"d);
        addBtn.click = delegate(Widget source) {
            string url = _urlEdit.text.to!string;
            if (url.length == 0)
            {
                window.showMessageBox("Error"d, "Please enter a valid otpauth URL"d);
                return true;
            }

            if (qrScanned && qrScanned(url))
                close();
            return true;
        };
        buttonRow.addChild(addBtn);

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

// Action IDs for menu items
enum
{
    ACTION_FILE_NEW_AUTH = 2000,
    ACTION_FILE_OPEN_AUTH,
    ACTION_FILE_EXPORT_AUTH,
    ACTION_FILE_IMPORT_AUTH,
    ACTION_UNLOCK_AUTH,
    ACTION_LOCK_AUTH,
    ACTION_ACCOUNT_ADD,
    ACTION_ACCOUNT_ADD_QR,
    ACTION_ACCOUNT_EDIT,
    ACTION_ACCOUNT_DELETE,
    ACTION_ACCOUNT_COPY_CODE
}
