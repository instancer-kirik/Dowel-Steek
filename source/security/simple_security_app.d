module security.simple_security_app;

import std.stdio;
import std.file;
import std.path;
import std.datetime;
import std.conv;
import std.string;
import std.algorithm;
import std.array;
import std.json;

import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.editors;
import dlangui.core.events;

import security.crypto;

mixin APP_ENTRY_POINT;

/// Simple vault entry for passwords
struct SimpleVaultEntry
{
    string id;
    string title;
    string username;
    string password;
    string url;
    string notes;
    SysTime createdAt;

    this(string title, string username = "", string password = "")
    {
        import std.uuid;
        this.id = randomUUID().toString();
        this.title = title;
        this.username = username;
        this.password = password;
        this.createdAt = Clock.currTime();
    }

    JSONValue toJSON() const
    {
        JSONValue json = JSONValue.emptyObject;
        json["id"] = JSONValue(id);
        json["title"] = JSONValue(title);
        json["username"] = JSONValue(username);
        json["password"] = JSONValue(password);
        json["url"] = JSONValue(url);
        json["notes"] = JSONValue(notes);
        json["createdAt"] = JSONValue(createdAt.toISOExtString());
        return json;
    }

    static SimpleVaultEntry fromJSON(JSONValue json)
    {
        SimpleVaultEntry entry;
        if ("id" in json) entry.id = json["id"].str;
        if ("title" in json) entry.title = json["title"].str;
        if ("username" in json) entry.username = json["username"].str;
        if ("password" in json) entry.password = json["password"].str;
        if ("url" in json) entry.url = json["url"].str;
        if ("notes" in json) entry.notes = json["notes"].str;
        if ("createdAt" in json)
            entry.createdAt = SysTime.fromISOExtString(json["createdAt"].str);
        return entry;
    }
}

/// Simple TOTP account
struct SimpleTOTPAccount
{
    string id;
    string issuer;
    string accountName;
    string secret;
    SysTime createdAt;

    this(string issuer, string accountName, string secret)
    {
        import std.uuid;
        this.id = randomUUID().toString();
        this.issuer = issuer;
        this.accountName = accountName;
        this.secret = secret;
        this.createdAt = Clock.currTime();
    }

    string generateCode()
    {
        import security.authenticator.totp;
        try
        {
            auto generator = TOTPGenerator(secret);
            return generator.generateCode();
        }
        catch (Exception e)
        {
            return "ERROR";
        }
    }

    JSONValue toJSON() const
    {
        JSONValue json = JSONValue.emptyObject;
        json["id"] = JSONValue(id);
        json["issuer"] = JSONValue(issuer);
        json["accountName"] = JSONValue(accountName);
        json["secret"] = JSONValue(secret);
        json["createdAt"] = JSONValue(createdAt.toISOExtString());
        return json;
    }

    static SimpleTOTPAccount fromJSON(JSONValue json)
    {
        SimpleTOTPAccount account;
        if ("id" in json) account.id = json["id"].str;
        if ("issuer" in json) account.issuer = json["issuer"].str;
        if ("accountName" in json) account.accountName = json["accountName"].str;
        if ("secret" in json) account.secret = json["secret"].str;
        if ("createdAt" in json)
            account.createdAt = SysTime.fromISOExtString(json["createdAt"].str);
        return account;
    }
}

/// Main security application window
class SimpleSecurityApp : VerticalLayout
{
    private SimpleVaultEntry[] _vaultEntries;
    private SimpleTOTPAccount[] _totpAccounts;
    private string _vaultPath;
    private string _totpPath;
    private string _masterPassword;
    private bool _isUnlocked = false;

    // UI components
    private TabWidget _mainTabs;
    private VerticalLayout _vaultTab;
    private VerticalLayout _totpTab;
    private Button _unlockBtn;
    private Button _lockBtn;
    private TextWidget _statusText;

    // Vault UI
    private VerticalLayout _vaultList;
    private EditLine _vaultTitleEdit;
    private EditLine _vaultUsernameEdit;
    private EditLine _vaultPasswordEdit;
    private EditLine _vaultUrlEdit;
    private EditBox _vaultNotesEdit;

    // TOTP UI
    private VerticalLayout _totpList;
    private EditLine _totpIssuerEdit;
    private EditLine _totpAccountEdit;
    private EditLine _totpSecretEdit;

    this()
    {
        super("securityApp");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        padding = Rect(10, 10, 10, 10);

        string homeDir = expandTilde("~");
        string configDir = buildPath(homeDir, ".dowel-steek");
        if (!exists(configDir))
            mkdirRecurse(configDir);

        _vaultPath = buildPath(configDir, "simple_vault.json");
        _totpPath = buildPath(configDir, "simple_totp.json");

        createUI();
        updateUI();
    }

    private void createUI()
    {
        // Header with unlock/lock buttons
        auto headerLayout = new HorizontalLayout();
        headerLayout.layoutWidth = FILL_PARENT;
        headerLayout.layoutHeight = WRAP_CONTENT;

        auto titleText = new TextWidget(null, "Dowel-Steek Security Suite"d);
        titleText.fontSize = 16;
        titleText.fontWeight = 600;
        headerLayout.addChild(titleText);

        auto spacer = new Widget();
        spacer.layoutWidth = FILL_PARENT;
        headerLayout.addChild(spacer);

        _unlockBtn = new Button("unlockBtn", "Unlock"d);
        _unlockBtn.click = delegate(Widget source) {
            showUnlockDialog();
            return true;
        };
        headerLayout.addChild(_unlockBtn);

        _lockBtn = new Button("lockBtn", "Lock"d);
        _lockBtn.click = delegate(Widget source) {
            lockVault();
            return true;
        };
        headerLayout.addChild(_lockBtn);

        addChild(headerLayout);

        // Status
        _statusText = new TextWidget(null, "Vault locked - Click Unlock to begin"d);
        _statusText.textColor = 0xFF666666;
        addChild(_statusText);

        // Main tabs
        _mainTabs = new TabWidget("mainTabs");
        _mainTabs.layoutWidth = FILL_PARENT;
        _mainTabs.layoutHeight = FILL_PARENT;

        createVaultTab();
        createTOTPTab();

        addChild(_mainTabs);
    }

    private void createVaultTab()
    {
        _vaultTab = new VerticalLayout("vaultTab");
        _vaultTab.layoutWidth = FILL_PARENT;
        _vaultTab.layoutHeight = FILL_PARENT;
        _vaultTab.padding = Rect(10, 10, 10, 10);

        // Add entry form
        auto formLayout = new VerticalLayout();
        formLayout.backgroundColor = 0xFFF8F8F8;
        formLayout.padding = Rect(10, 10, 10, 10);
        formLayout.margins = Rect(0, 0, 0, 10);

        auto formTitle = new TextWidget(null, "Add New Password Entry"d);
        formTitle.fontWeight = 600;
        formLayout.addChild(formTitle);

        _vaultTitleEdit = new EditLine("vaultTitle");
        _vaultTitleEdit.text = "Service Name"d;
        formLayout.addChild(_vaultTitleEdit);

        _vaultUsernameEdit = new EditLine("vaultUsername");
        _vaultUsernameEdit.text = "Username"d;
        formLayout.addChild(_vaultUsernameEdit);

        _vaultPasswordEdit = new EditLine("vaultPassword");
        _vaultPasswordEdit.text = "Password"d;
        formLayout.addChild(_vaultPasswordEdit);

        _vaultUrlEdit = new EditLine("vaultUrl");
        _vaultUrlEdit.text = "URL (optional)"d;
        formLayout.addChild(_vaultUrlEdit);

        _vaultNotesEdit = new EditBox("vaultNotes");
        _vaultNotesEdit.text = "Notes (optional)"d;
        _vaultNotesEdit.layoutHeight = 60;
        formLayout.addChild(_vaultNotesEdit);

        auto buttonLayout = new HorizontalLayout();
        auto addVaultBtn = new Button("addVaultBtn", "Add Entry"d);
        addVaultBtn.click = delegate(Widget source) {
            addVaultEntry();
            return true;
        };
        buttonLayout.addChild(addVaultBtn);

        auto generateBtn = new Button("generateBtn", "Generate Password"d);
        generateBtn.click = delegate(Widget source) {
            generatePassword();
            return true;
        };
        buttonLayout.addChild(generateBtn);

        formLayout.addChild(buttonLayout);
        _vaultTab.addChild(formLayout);

        // Entries list
        auto listTitle = new TextWidget(null, "Password Entries:"d);
        listTitle.fontWeight = 600;
        _vaultTab.addChild(listTitle);

        _vaultList = new VerticalLayout();
        _vaultList.layoutWidth = FILL_PARENT;
        _vaultList.layoutHeight = FILL_PARENT;
        _vaultTab.addChild(_vaultList);

        _mainTabs.addTab(_vaultTab, "Password Manager"d, "vault_tab");
    }

    private void createTOTPTab()
    {
        _totpTab = new VerticalLayout("totpTab");
        _totpTab.layoutWidth = FILL_PARENT;
        _totpTab.layoutHeight = FILL_PARENT;
        _totpTab.padding = Rect(10, 10, 10, 10);

        // Add TOTP form
        auto formLayout = new VerticalLayout();
        formLayout.backgroundColor = 0xFFF8F8F8;
        formLayout.padding = Rect(10, 10, 10, 10);
        formLayout.margins = Rect(0, 0, 0, 10);

        auto formTitle = new TextWidget(null, "Add New 2FA Account"d);
        formTitle.fontWeight = 600;
        formLayout.addChild(formTitle);

        _totpIssuerEdit = new EditLine("totpIssuer");
        _totpIssuerEdit.text = "Service (e.g. Google, GitHub)"d;
        formLayout.addChild(_totpIssuerEdit);

        _totpAccountEdit = new EditLine("totpAccount");
        _totpAccountEdit.text = "Account (e.g. user@email.com)"d;
        formLayout.addChild(_totpAccountEdit);

        _totpSecretEdit = new EditLine("totpSecret");
        _totpSecretEdit.text = "Secret Key (from QR code)"d;
        formLayout.addChild(_totpSecretEdit);

        auto addTotpBtn = new Button("addTotpBtn", "Add 2FA Account"d);
        addTotpBtn.click = delegate(Widget source) {
            addTOTPAccount();
            return true;
        };
        formLayout.addChild(addTotpBtn);

        _totpTab.addChild(formLayout);

        // TOTP accounts list
        auto listTitle = new TextWidget(null, "2FA Accounts:"d);
        listTitle.fontWeight = 600;
        _totpTab.addChild(listTitle);

        _totpList = new VerticalLayout();
        _totpList.layoutWidth = FILL_PARENT;
        _totpList.layoutHeight = FILL_PARENT;
        _totpTab.addChild(_totpList);

        _mainTabs.addTab(_totpTab, "Authenticator"d, "totp_tab");
    }

    private void showUnlockDialog()
    {
        // Simple password input - in a real app this would be a proper dialog
        _masterPassword = "demo-password-123"; // For demo purposes

        if (unlockVault(_masterPassword))
        {
            _statusText.text = format("Vault unlocked - %d passwords, %d 2FA accounts"d,
                _vaultEntries.length, _totpAccounts.length);
            updateUI();
        }
        else
        {
            _statusText.text = "Failed to unlock vault"d;
        }
    }

    private bool unlockVault(string password)
    {
        try
        {
            _masterPassword = password;

            // Load vault entries
            if (exists(_vaultPath))
            {
                string encryptedData = readText(_vaultPath);
                // For demo, we'll just parse JSON directly
                // In real app, decrypt first
                if (encryptedData.length > 0)
                {
                    JSONValue json = parseJSON(encryptedData);
                    if ("entries" in json && json["entries"].type == JSONType.array)
                    {
                        _vaultEntries = [];
                        foreach (entryJson; json["entries"].array)
                        {
                            _vaultEntries ~= SimpleVaultEntry.fromJSON(entryJson);
                        }
                    }
                }
            }

            // Load TOTP accounts
            if (exists(_totpPath))
            {
                string encryptedData = readText(_totpPath);
                if (encryptedData.length > 0)
                {
                    JSONValue json = parseJSON(encryptedData);
                    if ("accounts" in json && json["accounts"].type == JSONType.array)
                    {
                        _totpAccounts = [];
                        foreach (accountJson; json["accounts"].array)
                        {
                            _totpAccounts ~= SimpleTOTPAccount.fromJSON(accountJson);
                        }
                    }
                }
            }

            _isUnlocked = true;
            refreshLists();
            return true;
        }
        catch (Exception e)
        {
            writeln("Unlock error: ", e.msg);
            return false;
        }
    }

    private void lockVault()
    {
        _isUnlocked = false;
        _masterPassword = null;
        _vaultEntries = [];
        _totpAccounts = [];
        _statusText.text = "Vault locked"d;
        refreshLists();
        updateUI();
    }

    private void addVaultEntry()
    {
        if (!_isUnlocked) return;

        string title = _vaultTitleEdit.text.to!string.strip();
        string username = _vaultUsernameEdit.text.to!string.strip();
        string password = _vaultPasswordEdit.text.to!string.strip();
        string url = _vaultUrlEdit.text.to!string.strip();
        string notes = _vaultNotesEdit.text.to!string.strip();

        if (title.length == 0 || password.length == 0)
        {
            _statusText.text = "Title and password are required"d;
            return;
        }

        auto entry = SimpleVaultEntry(title, username, password);
        entry.url = url;
        entry.notes = notes;

        _vaultEntries ~= entry;
        saveVault();
        refreshLists();

        // Clear form
        _vaultTitleEdit.text = "Service Name"d;
        _vaultUsernameEdit.text = "Username"d;
        _vaultPasswordEdit.text = "Password"d;
        _vaultUrlEdit.text = "URL (optional)"d;
        _vaultNotesEdit.text = "Notes (optional)"d;

        _statusText.text = format("Added entry: %s"d, title);
    }

    private void addTOTPAccount()
    {
        if (!_isUnlocked) return;

        string issuer = _totpIssuerEdit.text.to!string.strip();
        string account = _totpAccountEdit.text.to!string.strip();
        string secret = _totpSecretEdit.text.to!string.strip();

        if (issuer.length == 0 || account.length == 0 || secret.length == 0)
        {
            _statusText.text = "All TOTP fields are required"d;
            return;
        }

        auto totpAccount = SimpleTOTPAccount(issuer, account, secret);
        _totpAccounts ~= totpAccount;
        saveTOTP();
        refreshLists();

        // Clear form
        _totpIssuerEdit.text = "Service (e.g. Google, GitHub)"d;
        _totpAccountEdit.text = "Account (e.g. user@email.com)"d;
        _totpSecretEdit.text = "Secret Key (from QR code)"d;

        _statusText.text = format("Added 2FA account: %s"d, issuer);
    }

    private void generatePassword()
    {
        try
        {
            auto options = PasswordGenerator.Options();
            options.length = 16;
            string password = PasswordGenerator.generate(options);
            _vaultPasswordEdit.text = password.to!dstring;
            _statusText.text = "Generated strong password"d;
        }
        catch (Exception e)
        {
            _statusText.text = format("Password generation failed: %s"d, e.msg);
        }
    }

    private void saveVault()
    {
        try
        {
            JSONValue json = JSONValue.emptyObject;
            JSONValue[] entriesJson;
            foreach (entry; _vaultEntries)
                entriesJson ~= entry.toJSON();
            json["entries"] = JSONValue(entriesJson);

            // For demo, save as plain JSON
            // In real app, encrypt first
            std.file.write(_vaultPath, json.toString());
        }
        catch (Exception e)
        {
            writeln("Save vault error: ", e.msg);
        }
    }

    private void saveTOTP()
    {
        try
        {
            JSONValue json = JSONValue.emptyObject;
            JSONValue[] accountsJson;
            foreach (account; _totpAccounts)
                accountsJson ~= account.toJSON();
            json["accounts"] = JSONValue(accountsJson);

            std.file.write(_totpPath, json.toString());
        }
        catch (Exception e)
        {
            writeln("Save TOTP error: ", e.msg);
        }
    }

    private void refreshLists()
    {
        // Refresh vault list
        _vaultList.removeAllChildren();
        foreach (entry; _vaultEntries)
        {
            auto entryWidget = createVaultEntryWidget(entry);
            _vaultList.addChild(entryWidget);
        }

        // Refresh TOTP list
        _totpList.removeAllChildren();
        foreach (account; _totpAccounts)
        {
            auto accountWidget = createTOTPAccountWidget(account);
            _totpList.addChild(accountWidget);
        }
    }

    private Widget createVaultEntryWidget(SimpleVaultEntry entry)
    {
        auto layout = new HorizontalLayout();
        layout.layoutWidth = FILL_PARENT;
        layout.layoutHeight = WRAP_CONTENT;
        layout.backgroundColor = 0xFFFFFFFF;
        layout.padding = Rect(8, 8, 8, 8);
        layout.margins = Rect(0, 2, 0, 2);

        auto infoLayout = new VerticalLayout();
        infoLayout.layoutWidth = FILL_PARENT;

        auto titleText = new TextWidget(null, entry.title.to!dstring);
        titleText.fontWeight = 600;
        infoLayout.addChild(titleText);

        if (entry.username.length > 0)
        {
            auto usernameText = new TextWidget(null, entry.username.to!dstring);
            usernameText.textColor = 0xFF666666;
            usernameText.fontSize = 11;
            infoLayout.addChild(usernameText);
        }

        layout.addChild(infoLayout);

        auto copyBtn = new Button(null, "Copy Password"d);
        copyBtn.click = delegate(Widget source) {
            // In a real app, copy to clipboard
            _statusText.text = format("Password copied for %s"d, entry.title);
            return true;
        };
        layout.addChild(copyBtn);

        return layout;
    }

    private Widget createTOTPAccountWidget(SimpleTOTPAccount account)
    {
        auto layout = new HorizontalLayout();
        layout.layoutWidth = FILL_PARENT;
        layout.layoutHeight = WRAP_CONTENT;
        layout.backgroundColor = 0xFFFFFFFF;
        layout.padding = Rect(8, 8, 8, 8);
        layout.margins = Rect(0, 2, 0, 2);

        auto infoLayout = new VerticalLayout();
        infoLayout.layoutWidth = FILL_PARENT;

        auto titleText = new TextWidget(null, format("%s (%s)"d, account.issuer, account.accountName));
        titleText.fontWeight = 600;
        infoLayout.addChild(titleText);

        layout.addChild(infoLayout);

        auto codeText = new TextWidget(null, account.generateCode().to!dstring);
        codeText.fontWeight = 700;
        codeText.fontSize = 16;
        codeText.textColor = 0xFF2196F3;
        layout.addChild(codeText);

        auto copyBtn = new Button(null, "Copy"d);
        copyBtn.click = delegate(Widget source) {
            string code = account.generateCode();
            _statusText.text = format("Code %s copied"d, code);
            return true;
        };
        layout.addChild(copyBtn);

        return layout;
    }

    private void updateUI()
    {
        _unlockBtn.enabled = !_isUnlocked;
        _lockBtn.enabled = _isUnlocked;
        _mainTabs.enabled = _isUnlocked;
    }
}

/// Entry point for dlangui based application
extern (C) int UIAppMain(string[] args)
{
    writeln("Dowel-Steek Simple Security Suite starting...");

    try
    {
        // Create main window
        Window window = Platform.instance.createWindow("Dowel-Steek Security Suite"d, null,
            WindowFlag.Resizable, 800, 600);

        if (!window)
        {
            writeln("ERROR: Failed to create main window");
            return 1;
        }

        // Create application
        auto app = new SimpleSecurityApp();
        window.mainWidget = app;

        // Show window
        window.show();

        writeln("Application started successfully");
        writeln("Default demo password: demo-password-123");
        writeln("Data stored in: ~/.dowel-steek/");

        // Enter message loop
        return Platform.instance.enterMessageLoop();
    }
    catch (Exception e)
    {
        writeln("ERROR: Exception caught: ", e.msg);
        writeln("Stack trace: ", e.toString());
        return 1;
    }
}
