module security.enhanced_security_app;

import std.stdio;
import std.file;
import std.path;
import std.datetime;
import std.conv;
import std.string;
import std.algorithm;
import std.array;
import std.json;
import std.format;

import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.editors;
import dlangui.widgets.lists;
import dlangui.widgets.menu;
import dlangui.widgets.popup;
import dlangui.widgets.tabs;
import dlangui.core.events;
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;
import core.thread;
import core.time;

import security.enhanced_crypto;
import security.enhanced_vault;
import security.models;
import security.ui.theme;
import security.authenticator.totp : TOTPGenerator;

mixin APP_ENTRY_POINT;

/// Enhanced Security Application with modern UI
class EnhancedSecurityApp : VerticalLayout
{
    private EnhancedVault _vault;
    private SecurityTheme _theme;
    private bool _isUnlocked = false;
    private SysTime _lastActivity;

    // Main UI components
    private TabWidget _mainTabs;
    private Widget _unlockScreen;
    private Widget _mainInterface;

    // Password Manager components
    private VerticalLayout _vaultTab;
    private EditLine _searchBox;
    private ListWidget _entryList;
    private Widget _entryDetailsPanel;
    private BaseVaultEntry _selectedEntry;

    // TOTP components
    private VerticalLayout _totpTab;
    private ListWidget _totpList;

    // Security dashboard
    private VerticalLayout _dashboardTab;
    private Widget _securityOverview;

    // Settings
    private VerticalLayout _settingsTab;

    // Status bar
    private HorizontalLayout _statusBar;
    private TextWidget _statusText;
    private TextWidget _entryCountText;

    // Timer threads (simplified implementation)
    private Thread _totpUpdateThread;
    private Thread _autoLockThread;
    private shared bool _shouldStop = false;

    this()
    {
        super("enhancedSecurityApp");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;

        _theme = SecurityTheme.instance();
        _lastActivity = Clock.currTime();

        initializeVault();
        createUI();
        setupTimers();

        if (_vault.isLocked())
        {
            showUnlockScreen();
        }
        else
        {
            showMainInterface();
        }
    }

    private void initializeVault()
    {
        string homeDir = expandTilde("~");
        string configDir = buildPath(homeDir, ".dowel-steek");
        if (!exists(configDir))
            mkdirRecurse(configDir);

        string vaultPath = buildPath(configDir, "enhanced_vault.dwl");
        _vault = new EnhancedVault(vaultPath);
    }

    private void createUI()
    {
        backgroundColor = _theme.getBackgroundColor();

        // Create unlock screen
        createUnlockScreen();

        // Create main interface
        createMainInterface();

        // Create status bar
        createStatusBar();
        addChild(_statusBar);

        updateTheme();
    }

    private void createUnlockScreen()
    {
        _unlockScreen = new VerticalLayout("unlockScreen");
        _unlockScreen.layoutWidth = FILL_PARENT;
        _unlockScreen.layoutHeight = FILL_PARENT;
        _unlockScreen.backgroundColor = _theme.getBackgroundColor();

        // Center the unlock form
        auto centerLayout = new VerticalLayout();
        centerLayout.layoutWidth = FILL_PARENT;
        centerLayout.layoutHeight = FILL_PARENT;
        centerLayout.alignment = Align.Center;

        // Unlock card
        auto unlockCard = _theme.createCard("unlockCard");
        unlockCard.layoutWidth = 400;
        unlockCard.layoutHeight = WRAP_CONTENT;
        unlockCard.backgroundColor = _theme.getSurfaceColor();

        // App title
        auto titleText = new TextWidget(null, "🔐 Dowel-Steek Security Suite"d);
        titleText.fontSize = 24;
        titleText.fontWeight = 600;
        titleText.textColor = _theme.getPrimaryColor();
        titleText.alignment = Align.Center;
        titleText.margins = Rect(0, 0, 0, 32);
        unlockCard.addChild(titleText);

        // Subtitle
        auto subtitleText = new TextWidget(null, "Enter your master password to unlock your vault"d);
        subtitleText.fontSize = 14;
        subtitleText.textColor = _theme.getTextColor();
        subtitleText.alignment = Align.Center;
        subtitleText.margins = Rect(0, 0, 0, 24);
        unlockCard.addChild(subtitleText);

        // Password field
        auto passwordField = _theme.createStyledEditLine("masterPasswordField");
        passwordField.passwordChar = '*';
        passwordField.layoutWidth = FILL_PARENT;
        passwordField.margins = Rect(0, 0, 0, 16);
        passwordField.text = "Master Password"d;
        unlockCard.addChild(passwordField);

        // Button layout
        auto buttonLayout = new HorizontalLayout();
        buttonLayout.layoutWidth = FILL_PARENT;

        // Unlock button
        auto unlockBtn = _theme.createStyledButton("unlockBtn", "🔓 Unlock Vault"d);
        unlockBtn.layoutWidth = FILL_PARENT;
        unlockBtn.click = delegate(Widget source) {
            string password = passwordField.text.to!string;
            if (password.length > 0 && password != "Master Password")
            {
                if (_vault.unlock(password))
                {
                    _isUnlocked = true;
                    showMainInterface();
                    refreshAllData();
                    updateActivity();
                }
                else
                {
                    showErrorMessage("Invalid master password. Please try again.");
                    passwordField.text = ""d;
                }
            }
            return true;
        };
        buttonLayout.addChild(unlockBtn);

        unlockCard.addChild(buttonLayout);

        // Settings button
        auto settingsBtn = _theme.createIconButton("settingsBtn", "⚙️"d, "Settings"d);
        settingsBtn.click = delegate(Widget source) {
            showSettingsDialog();
            return true;
        };
        unlockCard.addChild(settingsBtn);

        centerLayout.addChild(unlockCard);
        _unlockScreen.addChild(centerLayout);

        addChild(_unlockScreen);
    }

    private void createMainInterface()
    {
        _mainInterface = new VerticalLayout("mainInterface");
        _mainInterface.layoutWidth = FILL_PARENT;
        _mainInterface.layoutHeight = FILL_PARENT;
        _mainInterface.visibility = Visibility.Gone;

        // Header
        createHeader();

        // Main tabs
        _mainTabs = new TabWidget("mainTabs");
        _mainTabs.layoutWidth = FILL_PARENT;
        _mainTabs.layoutHeight = FILL_PARENT;

        createDashboardTab();
        createVaultTab();
        createTOTPTab();
        createSettingsTab();

        _mainInterface.addChild(_mainTabs);
        addChild(_mainInterface);
    }

    private void createHeader()
    {
        auto header = new HorizontalLayout("header");
        header.layoutWidth = FILL_PARENT;
        header.layoutHeight = 60;
        header.backgroundColor = _theme.getPrimaryColor();
        header.padding = Rect(16, 8, 16, 8);

        // Title
        auto titleText = new TextWidget(null, "🔐 Security Suite"d);
        titleText.fontSize = 18;
        titleText.fontWeight = 600;
        titleText.textColor = 0xFFFFFFFF;
        header.addChild(titleText);

        // Spacer
        auto spacer = new Widget();
        spacer.layoutWidth = FILL_PARENT;
        header.addChild(spacer);

        // Quick actions
        auto quickActionsLayout = new HorizontalLayout();

        auto addEntryBtn = _theme.createIconButton("quickAddEntry", "➕"d, "Add Entry"d);
        addEntryBtn.click = delegate(Widget source) {
            showAddEntryDialog();
            return true;
        };
        quickActionsLayout.addChild(addEntryBtn);

        auto generatePasswordBtn = _theme.createIconButton("quickGenerate", "🎲"d, "Generate Password"d);
        generatePasswordBtn.click = delegate(Widget source) {
            showPasswordGeneratorDialog();
            return true;
        };
        quickActionsLayout.addChild(generatePasswordBtn);

        auto lockBtn = _theme.createIconButton("lockVault", "🔒"d, "Lock Vault"d);
        lockBtn.click = delegate(Widget source) {
            lockVault();
            return true;
        };
        quickActionsLayout.addChild(lockBtn);

        header.addChild(quickActionsLayout);
        _mainInterface.addChild(header);
    }

    private void createDashboardTab()
    {
        _dashboardTab = new VerticalLayout("dashboardTab");
        _dashboardTab.layoutWidth = FILL_PARENT;
        _dashboardTab.layoutHeight = FILL_PARENT;
        _dashboardTab.padding = Rect(16, 16, 16, 16);

        // Security overview section
        createSecurityOverview();

        // Recent items
        createRecentItemsSection();

        // Quick stats
        createQuickStatsSection();

        _mainTabs.addTab(_dashboardTab, "📊 Dashboard"d, "dashboard_tab");
    }

    private void createSecurityOverview()
    {
        auto securityCard = _theme.createCard("securityOverview");
        securityCard.layoutWidth = FILL_PARENT;

        auto titleText = new TextWidget(null, "🛡️ Security Overview"d);
        titleText.fontSize = 18;
        titleText.fontWeight = 600;
        titleText.margins = Rect(0, 0, 0, 16);
        securityCard.addChild(titleText);

        // Security score
        auto scoreLayout = new HorizontalLayout();
        auto scoreText = new TextWidget(null, "Security Score: "d);
        scoreLayout.addChild(scoreText);

        auto scoreValue = new TextWidget("securityScoreValue", "Loading..."d);
        scoreValue.fontWeight = 600;
        scoreLayout.addChild(scoreValue);

        securityCard.addChild(scoreLayout);

        // Security issues
        auto issuesLayout = new VerticalLayout("securityIssues");
        securityCard.addChild(issuesLayout);

        _securityOverview = securityCard;
        _dashboardTab.addChild(_securityOverview);
    }

    private void createRecentItemsSection()
    {
        auto recentCard = _theme.createCard("recentItems");
        recentCard.layoutWidth = FILL_PARENT;

        auto titleText = new TextWidget(null, "📋 Recent Items"d);
        titleText.fontSize = 16;
        titleText.fontWeight = 600;
        titleText.margins = Rect(0, 0, 0, 16);
        recentCard.addChild(titleText);

        auto recentList = new ListWidget("recentItemsList");
        recentList.layoutWidth = FILL_PARENT;
        recentList.layoutHeight = 200;
        recentCard.addChild(recentList);

        _dashboardTab.addChild(recentCard);
    }

    private void createQuickStatsSection()
    {
        auto statsLayout = new HorizontalLayout();
        statsLayout.layoutWidth = FILL_PARENT;

        // Total entries
        auto totalCard = _theme.createCard();
        totalCard.layoutWidth = FILL_PARENT;
        auto totalText = new TextWidget("totalEntriesText", "0"d);
        totalText.fontSize = 24;
        totalText.fontWeight = 600;
        totalText.alignment = Align.Center;
        totalCard.addChild(totalText);
        totalCard.addChild(new TextWidget(null, "Total Entries"d));
        statsLayout.addChild(totalCard);

        // Favorites
        auto favCard = _theme.createCard();
        favCard.layoutWidth = FILL_PARENT;
        auto favText = new TextWidget("favoriteEntriesText", "0"d);
        favText.fontSize = 24;
        favText.fontWeight = 600;
        favText.alignment = Align.Center;
        favCard.addChild(favText);
        favCard.addChild(new TextWidget(null, "Favorites"d));
        statsLayout.addChild(favCard);

        // TOTP accounts
        auto totpCard = _theme.createCard();
        totpCard.layoutWidth = FILL_PARENT;
        auto totpText = new TextWidget("totpAccountsText", "0"d);
        totpText.fontSize = 24;
        totpText.fontWeight = 600;
        totpText.alignment = Align.Center;
        totpCard.addChild(totpText);
        totpCard.addChild(new TextWidget(null, "2FA Accounts"d));
        statsLayout.addChild(totpCard);

        _dashboardTab.addChild(statsLayout);
    }

    private void createVaultTab()
    {
        _vaultTab = new VerticalLayout("vaultTab");
        _vaultTab.layoutWidth = FILL_PARENT;
        _vaultTab.layoutHeight = FILL_PARENT;
        _vaultTab.padding = Rect(16, 16, 16, 16);

        // Search and filters
        auto searchLayout = new HorizontalLayout();
        searchLayout.layoutWidth = FILL_PARENT;
        searchLayout.margins = Rect(0, 0, 0, 16);

        _searchBox = _theme.createSearchBox("vaultSearch");
        _searchBox.layoutWidth = FILL_PARENT;
        searchLayout.addChild(_searchBox);

        auto filterBtn = _theme.createIconButton("filterBtn", "🔍"d, "Filter"d);
        filterBtn.click = delegate(Widget source) {
            showFilterDialog();
            return true;
        };
        searchLayout.addChild(filterBtn);

        _vaultTab.addChild(searchLayout);

        // Main content area
        auto contentLayout = new HorizontalLayout();
        contentLayout.layoutWidth = FILL_PARENT;
        contentLayout.layoutHeight = FILL_PARENT;

        // Entry list
        auto listContainer = _theme.createCard("listContainer");
        listContainer.layoutWidth = 350;
        listContainer.layoutHeight = FILL_PARENT;

        _entryList = new ListWidget("entryList");
        _entryList.layoutWidth = FILL_PARENT;
        _entryList.layoutHeight = FILL_PARENT;
        // Note: ListWidget selection handling would need to be implemented differently
        listContainer.addChild(_entryList);

        contentLayout.addChild(listContainer);

        // Entry details panel
        _entryDetailsPanel = _theme.createCard("entryDetails");
        _entryDetailsPanel.layoutWidth = FILL_PARENT;
        _entryDetailsPanel.layoutHeight = FILL_PARENT;
        contentLayout.addChild(_entryDetailsPanel);

        _vaultTab.addChild(contentLayout);

        _mainTabs.addTab(_vaultTab, "🔑 Password Manager"d, "vault_tab");
    }

    private void createTOTPTab()
    {
        _totpTab = new VerticalLayout("totpTab");
        _totpTab.layoutWidth = FILL_PARENT;
        _totpTab.layoutHeight = FILL_PARENT;
        _totpTab.padding = Rect(16, 16, 16, 16);

        // Header
        auto headerLayout = new HorizontalLayout();
        headerLayout.layoutWidth = FILL_PARENT;
        headerLayout.margins = Rect(0, 0, 0, 16);

        auto titleText = new TextWidget(null, "📱 Two-Factor Authentication"d);
        titleText.fontSize = 18;
        titleText.fontWeight = 600;
        headerLayout.addChild(titleText);

        auto spacer = new Widget();
        spacer.layoutWidth = FILL_PARENT;
        headerLayout.addChild(spacer);

        auto addTotpBtn = _theme.createStyledButton("addTotpBtn", "➕ Add Account"d);
        addTotpBtn.click = delegate(Widget source) {
            showAddTOTPDialog();
            return true;
        };
        headerLayout.addChild(addTotpBtn);

        _totpTab.addChild(headerLayout);

        // TOTP list
        _totpList = new ListWidget("totpList");
        _totpList.layoutWidth = FILL_PARENT;
        _totpList.layoutHeight = FILL_PARENT;
        _totpTab.addChild(_totpList);

        _mainTabs.addTab(_totpTab, "📱 Authenticator"d, "totp_tab");
    }

    private void createSettingsTab()
    {
        _settingsTab = new VerticalLayout("settingsTab");
        _settingsTab.layoutWidth = FILL_PARENT;
        _settingsTab.layoutHeight = FILL_PARENT;
        _settingsTab.padding = Rect(16, 16, 16, 16);

        // Theme settings
        auto themeCard = _theme.createCard("themeSettings");
        themeCard.layoutWidth = FILL_PARENT;

        auto themeTitle = new TextWidget(null, "🎨 Appearance"d);
        themeTitle.fontSize = 16;
        themeTitle.fontWeight = 600;
        themeTitle.margins = Rect(0, 0, 0, 16);
        themeCard.addChild(themeTitle);

        auto themeLayout = new HorizontalLayout();
        auto themeLabel = new TextWidget(null, "Theme:"d);
        themeLayout.addChild(themeLabel);

        auto themeCombo = new ComboBox("themeCombo", ["Light"d, "Dark"d, "Auto"d]);
        themeCombo.selectedItemIndex = cast(int)_theme.getMode();
        themeCombo.itemClick = delegate(Widget source, int itemIndex) {
            _theme.setMode(cast(ThemeMode)itemIndex);
            updateTheme();
            return true;
        };
        themeLayout.addChild(themeCombo);

        themeCard.addChild(themeLayout);
        _settingsTab.addChild(themeCard);

        // Security settings
        auto securityCard = _theme.createCard("securitySettings");
        securityCard.layoutWidth = FILL_PARENT;

        auto securityTitle = new TextWidget(null, "🔒 Security"d);
        securityTitle.fontSize = 16;
        securityTitle.fontWeight = 600;
        securityTitle.margins = Rect(0, 0, 0, 16);
        securityCard.addChild(securityTitle);

        auto changePwBtn = _theme.createStyledButton("changePwBtn", "Change Master Password"d, "secondary-button");
        changePwBtn.click = delegate(Widget source) {
            showChangeMasterPasswordDialog();
            return true;
        };
        securityCard.addChild(changePwBtn);

        _settingsTab.addChild(securityCard);

        // Import/Export
        auto dataCard = _theme.createCard("dataSettings");
        dataCard.layoutWidth = FILL_PARENT;

        auto dataTitle = new TextWidget(null, "📦 Data Management"d);
        dataTitle.fontSize = 16;
        dataTitle.fontWeight = 600;
        dataTitle.margins = Rect(0, 0, 0, 16);
        dataCard.addChild(dataTitle);

        auto dataButtonsLayout = new HorizontalLayout();

        auto importBtn = _theme.createStyledButton("importBtn", "📥 Import"d, "secondary-button");
        importBtn.click = delegate(Widget source) {
            showImportDialog();
            return true;
        };
        dataButtonsLayout.addChild(importBtn);

        auto exportBtn = _theme.createStyledButton("exportBtn", "📤 Export"d, "secondary-button");
        exportBtn.click = delegate(Widget source) {
            showExportDialog();
            return true;
        };
        dataButtonsLayout.addChild(exportBtn);

        auto backupBtn = _theme.createStyledButton("backupBtn", "💾 Backup"d, "secondary-button");
        backupBtn.click = delegate(Widget source) {
            showBackupDialog();
            return true;
        };
        dataButtonsLayout.addChild(backupBtn);

        dataCard.addChild(dataButtonsLayout);
        _settingsTab.addChild(dataCard);

        _mainTabs.addTab(_settingsTab, "⚙️ Settings"d, "settings_tab");
    }

    private void createStatusBar()
    {
        _statusBar = new HorizontalLayout("statusBar");
        _statusBar.layoutWidth = FILL_PARENT;
        _statusBar.layoutHeight = 30;
        _statusBar.backgroundColor = _theme.getSurfaceColor();
        _statusBar.padding = Rect(16, 4, 16, 4);

        _statusText = new TextWidget("statusText", "Ready"d);
        _statusText.fontSize = 12;
        _statusBar.addChild(_statusText);

        auto spacer = new Widget();
        spacer.layoutWidth = FILL_PARENT;
        _statusBar.addChild(spacer);

        _entryCountText = new TextWidget("entryCount", "0 entries"d);
        _entryCountText.fontSize = 12;
        _statusBar.addChild(_entryCountText);
    }

    private void setupTimers()
    {
        // TOTP update thread (every second)
        _totpUpdateThread = new Thread(() {
            while (!_shouldStop)
            {
                if (_isUnlocked)
                {
                    updateTOTPCodes();
                }
                Thread.sleep(1.seconds);
            }
        });
        _totpUpdateThread.start();

        // Auto-lock thread (check every minute)
        _autoLockThread = new Thread(() {
            while (!_shouldStop)
            {
                checkAutoLock();
                Thread.sleep(1.minutes);
            }
        });
        _autoLockThread.start();
    }

    private void showUnlockScreen()
    {
        _unlockScreen.visibility = Visibility.Visible;
        _mainInterface.visibility = Visibility.Gone;
        updateStatus("Vault locked - Enter master password to unlock");
    }

    private void showMainInterface()
    {
        _unlockScreen.visibility = Visibility.Gone;
        _mainInterface.visibility = Visibility.Visible;
        updateStatus("Vault unlocked");
    }

    private void lockVault()
    {
        _vault.lock();
        _isUnlocked = false;
        _selectedEntry = null;
        showUnlockScreen();
        clearAllLists();
    }

    private void refreshAllData()
    {
        if (!_isUnlocked) return;

        refreshVaultList();
        refreshTOTPList();
        updateDashboard();
        updateStatistics();
    }

    private void refreshVaultList()
    {
        _entryList.removeAllChildren();

        auto entries = _vault.getEntries();
        foreach (entry; entries)
        {
            string iconText = getEntryIcon(entry.getType());
            string displayText = format("%s %s", iconText, entry.name);

            auto item = new TextWidget(null, displayText.to!dstring);
            _entryList.addChild(item);
            // item.tag = cast(Object)entry; // Would need different approach
        }

        updateEntryCount(entries.length);
    }

    private void refreshTOTPList()
    {
        _totpList.removeAllChildren();

        auto accounts = _vault.getTOTPAccounts();
        foreach (account; accounts)
        {
            auto item = createTOTPListItem(account);
            _totpList.addChild(item);
        }
    }

    private void updateDashboard()
    {
        // Update security overview
        auto report = _vault.generateSecurityReport();
        auto stats = _vault.getStatistics();

        // Update security score
        if (auto scoreWidget = _securityOverview.childById!TextWidget("securityScoreValue"))
        {
            scoreWidget.text = format("%d/100", report.securityScore).to!dstring;
            scoreWidget.textColor = parseHexColor(report.getScoreColor());
        }

        // Update security issues
        if (auto issuesWidget = _securityOverview.childById!VerticalLayout("securityIssues"))
        {
            issuesWidget.removeAllChildren();

            if (report.weakPasswords > 0)
            {
                auto weakText = new TextWidget(null, format("⚠️ %d weak passwords", report.weakPasswords).to!dstring);
                weakText.textColor = _theme.getWarningColor();
                issuesWidget.addChild(weakText);
            }

            if (report.oldPasswords > 0)
            {
                auto oldText = new TextWidget(null, format("📅 %d old passwords", report.oldPasswords).to!dstring);
                oldText.textColor = _theme.getWarningColor();
                issuesWidget.addChild(oldText);
            }

            if (report.compromisedPasswords > 0)
            {
                auto compText = new TextWidget(null, format("🚨 %d compromised passwords", report.compromisedPasswords).to!dstring);
                compText.textColor = _theme.getErrorColor();
                issuesWidget.addChild(compText);
            }
        }
    }

    private void updateStatistics()
    {
        auto stats = _vault.getStatistics();

        if (auto totalWidget = childById!TextWidget("totalEntriesText"))
            totalWidget.text = stats.totalEntries.to!dstring;

        if (auto favWidget = childById!TextWidget("favoriteEntriesText"))
            favWidget.text = stats.favoriteEntries.to!dstring;

        if (auto totpWidget = childById!TextWidget("totpAccountsText"))
            totpWidget.text = stats.totalTOTPAccounts.to!dstring;
    }

    private void updateTOTPCodes()
    {
        // Update TOTP codes and progress indicators
        auto accounts = _vault.getTOTPAccounts();
        for (int i = 0; i < accounts.length && i < _totpList.childCount; i++)
        {
            auto account = accounts[i];
            auto item = _totpList.child(i);

            if (auto codeWidget = item.childById!TextWidget("totpCode"))
            {
                codeWidget.text = account.generateCode().to!dstring;
            }

            if (auto progressWidget = item.childById!(security.ui.theme.ProgressBarWidget)("totpProgress"))
            {
                progressWidget.progress = account.getProgress();
            }
        }
    }

    private Widget createTOTPListItem(security.models.TOTPAccount account)
    {
        auto item = _theme.createCard();
        item.layoutWidth = FILL_PARENT;
        item.layoutHeight = 80;

        auto layout = new HorizontalLayout();
        layout.layoutWidth = FILL_PARENT;
        layout.layoutHeight = FILL_PARENT;

        // Left side - account info
        auto infoLayout = new VerticalLayout();
        infoLayout.layoutWidth = FILL_PARENT;

        auto issuerText = new TextWidget(null, account.issuer.to!dstring);
        issuerText.fontSize = 14;
        issuerText.fontWeight = 600;
        infoLayout.addChild(issuerText);

        auto accountText = new TextWidget(null, account.accountName.to!dstring);
        accountText.fontSize = 12;
        accountText.textColor = _theme.getTextColor();
        infoLayout.addChild(accountText);

        layout.addChild(infoLayout);

        // Right side - TOTP code and progress
        auto codeLayout = new VerticalLayout();
        codeLayout.layoutWidth = 120;
        codeLayout.alignment = Align.Center;

        auto codeText = new TextWidget("totpCode", account.generateCode().to!dstring);
        codeText.fontSize = 18;
        codeText.fontWeight = 600;
        codeText.alignment = Align.Center;
        codeLayout.addChild(codeText);

        auto progressBar = new security.ui.theme.ProgressBarWidget("totpProgress");
        progressBar.progress = account.getProgress();
        progressBar.layoutWidth = 100;
        progressBar.layoutHeight = 4;
        codeLayout.addChild(progressBar);

        layout.addChild(codeLayout);

        // Copy button
        auto copyBtn = _theme.createIconButton("copyTotpBtn", "📋"d, "Copy Code"d);
        copyBtn.click = delegate(Widget source) {
            copyToClipboard(account.generateCode());
            showMessage("TOTP code copied to clipboard");
            return true;
        };
        layout.addChild(copyBtn);

        item.addChild(layout);
        return item;
    }

    private void loadEntryDetails(int index)
    {
        auto entries = _vault.getEntries();
        if (index >= 0 && index < entries.length)
        {
            _selectedEntry = entries[index];
            showEntryDetails(_selectedEntry);
        }
    }

    private void showEntryDetails(BaseVaultEntry entry)
    {
        _entryDetailsPanel.removeAllChildren();

        if (auto loginEntry = cast(LoginEntry)entry)
        {
            showLoginEntryDetails(loginEntry);
        }
        else if (auto noteEntry = cast(SecureNoteEntry)entry)
        {
            showNoteEntryDetails(noteEntry);
        }
        else if (auto cardEntry = cast(CardEntry)entry)
        {
            showCardEntryDetails(cardEntry);
        }
        else if (auto identityEntry = cast(IdentityEntry)entry)
        {
            showIdentityEntryDetails(identityEntry);
        }
    }

    private void showLoginEntryDetails(LoginEntry entry)
    {
        auto layout = new VerticalLayout();
        layout.layoutWidth = FILL_PARENT;
        layout.padding = Rect(16, 16, 16, 16);

        // Header
        auto headerLayout = new HorizontalLayout();
        auto titleText = new TextWidget(null, entry.name.to!dstring);
        titleText.fontSize = 18;
        titleText.fontWeight = 600;
        headerLayout.addChild(titleText);

        auto spacer = new Widget();
        spacer.layoutWidth = FILL_PARENT;
        headerLayout.addChild(spacer);

        // Action buttons
        auto editBtn = _theme.createIconButton("editEntry", "✏️"d, "Edit"d);
        editBtn.click = delegate(Widget source) {
            showEditEntryDialog(entry);
            return true;
        };
        headerLayout.addChild(editBtn);

        auto deleteBtn = _theme.createIconButton("deleteEntry", "🗑️"d, "Delete"d);
        deleteBtn.click = delegate(Widget source) {
            if (showConfirmDialog("Are you sure you want to delete this entry?"))
            {
                _vault.deleteEntry(entry.id);
                refreshVaultList();
                _entryDetailsPanel.removeAllChildren();
            }
            return true;
        };
        headerLayout.addChild(deleteBtn);

        layout.addChild(headerLayout);

        // Entry fields
        addDetailField(layout, "Username:", entry.username, true);
        addDetailField(layout, "Password:", entry.password, true, true);
        addDetailField(layout, "Email:", entry.email, true);

        if (entry.urls.length > 0)
            addDetailField(layout, "URL:", entry.getPrimaryUrl(), true);

        if (entry.notes.length > 0)
            addDetailField(layout, "Notes:", entry.notes, false);

        // Password strength
        if (entry.password.length > 0)
        {
            auto strength = EnhancedCrypto.analyzePasswordStrength(entry.password);
            auto strengthWidget = _theme.createPasswordStrengthIndicator(strength.score, strength.getLevelString());
            layout.addChild(strengthWidget);
        }

        // TOTP section
        if (entry.hasTOTP())
        {
            auto totpLayout = new HorizontalLayout();
            auto totpLabel = new TextWidget(null, "2FA Code:"d);
            totpLayout.addChild(totpLabel);

            // Generate and display TOTP code
            try
            {
                auto generator = TOTPGenerator(entry.totpSecret);
                string code = generator.generateCode();
                auto codeWidget = new TextWidget(null, code.to!dstring);
                codeWidget.fontWeight = 600;
                codeWidget.fontSize = 16;
                totpLayout.addChild(codeWidget);

                auto copyTotpBtn = _theme.createIconButton("copyTotpCode", "📋"d, "Copy 2FA Code"d);
                copyTotpBtn.click = delegate(Widget source) {
                    copyToClipboard(code);
                    showMessage("2FA code copied to clipboard");
                    return true;
                };
                totpLayout.addChild(copyTotpBtn);
            }
            catch (Exception e)
            {
                auto errorWidget = new TextWidget(null, "Error generating 2FA code"d);
                errorWidget.textColor = _theme.getErrorColor();
                totpLayout.addChild(errorWidget);
            }

            layout.addChild(totpLayout);
        }

        _entryDetailsPanel.addChild(layout);
    }

    private void showNoteEntryDetails(SecureNoteEntry entry)
    {
        auto layout = new VerticalLayout();
        layout.layoutWidth = FILL_PARENT;
        layout.padding = Rect(16, 16, 16, 16);

        // Header
        auto headerLayout = new HorizontalLayout();
        auto titleText = new TextWidget(null, ("📝 " ~ entry.name).to!dstring);
        titleText.fontSize = 18;
        titleText.fontWeight = 600;
        headerLayout.addChild(titleText);

        layout.addChild(headerLayout);

        // Content
        auto contentBox = new EditBox("noteContent");
        contentBox.text = entry.content.to!dstring;
        contentBox.layoutWidth = FILL_PARENT;
        contentBox.layoutHeight = FILL_PARENT;
        contentBox.readOnly = true;
        layout.addChild(contentBox);

        _entryDetailsPanel.addChild(layout);
    }

    private void showCardEntryDetails(CardEntry entry)
    {
        auto layout = new VerticalLayout();
        layout.layoutWidth = FILL_PARENT;
        layout.padding = Rect(16, 16, 16, 16);

        // Header
        auto titleText = new TextWidget(null, ("💳 " ~ entry.name).to!dstring);
        titleText.fontSize = 18;
        titleText.fontWeight = 600;
        layout.addChild(titleText);

        // Card fields
        addDetailField(layout, "Cardholder:", entry.cardholderName, true);
        addDetailField(layout, "Brand:", entry.brand, false);
        addDetailField(layout, "Number:", entry.getMaskedNumber(), true);
        addDetailField(layout, "Expiry:", entry.expiryMonth ~ "/" ~ entry.expiryYear, false);
        addDetailField(layout, "Security Code:", entry.securityCode, true, true);

        // Expiry warning
        if (entry.isExpired())
        {
            auto warningText = new TextWidget(null, "⚠️ This card has expired"d);
            warningText.textColor = _theme.getWarningColor();
            layout.addChild(warningText);
        }

        _entryDetailsPanel.addChild(layout);
    }

    private void showIdentityEntryDetails(IdentityEntry entry)
    {
        auto layout = new VerticalLayout();
        layout.layoutWidth = FILL_PARENT;
        layout.padding = Rect(16, 16, 16, 16);

        // Header
        auto titleText = new TextWidget(null, ("👤 " ~ entry.name).to!dstring);
        titleText.fontSize = 18;
        titleText.fontWeight = 600;
        layout.addChild(titleText);

        // Identity fields
        addDetailField(layout, "Full Name:", entry.getFullName(), true);
        addDetailField(layout, "Email:", entry.email, true);
        addDetailField(layout, "Phone:", entry.phone, true);
        addDetailField(layout, "Company:", entry.company, false);
        addDetailField(layout, "Address:", entry.getFullAddress(), true);

        _entryDetailsPanel.addChild(layout);
    }

    private void addDetailField(VerticalLayout parent, string label, string value, bool copyable, bool isPassword = false)
    {
        if (value.length == 0) return;

        auto fieldLayout = new HorizontalLayout();
        fieldLayout.layoutWidth = FILL_PARENT;
        fieldLayout.margins = Rect(0, 4, 0, 4);

        // Label
        auto labelWidget = new TextWidget(null, label.to!dstring);
        labelWidget.layoutWidth = 100;
        labelWidget.fontWeight = 600;
        fieldLayout.addChild(labelWidget);

        // Value
        string displayValue = isPassword ? "••••••••" : value;
        auto valueWidget = new TextWidget(null, displayValue.to!dstring);
        valueWidget.layoutWidth = FILL_PARENT;
        fieldLayout.addChild(valueWidget);

        // Copy button
        if (copyable)
        {
            auto copyBtn = _theme.createIconButton("copyField", "📋"d, "Copy"d);
            copyBtn.click = delegate(Widget source) {
                copyToClipboard(value);
                showMessage(label ~ " copied to clipboard");
                return true;
            };
            fieldLayout.addChild(copyBtn);
        }

        // Show/hide button for passwords
        if (isPassword)
        {
            auto showBtn = _theme.createIconButton("showField", "👁️"d, "Show"d);
            showBtn.click = delegate(Widget source) {
                if (valueWidget.text == "••••••••"d)
                {
                    valueWidget.text = value.to!dstring;
                    showBtn.text = "🙈"d;
                }
                else
                {
                    valueWidget.text = "••••••••"d;
                    showBtn.text = "👁️"d;
                }
                return true;
            };
            fieldLayout.addChild(showBtn);
        }

        parent.addChild(fieldLayout);
    }

    private string getEntryIcon(VaultEntryType type)
    {
        final switch (type)
        {
            case VaultEntryType.Login: return "🔑";
            case VaultEntryType.SecureNote: return "📝";
            case VaultEntryType.Card: return "💳";
            case VaultEntryType.Identity: return "👤";
        }
    }

    private void clearAllLists()
    {
        _entryList.removeAllChildren();
        _totpList.removeAllChildren();
        _entryDetailsPanel.removeAllChildren();
    }

    private void updateEntryCount(size_t count)
    {
        _entryCountText.text = format("%d entries", count).to!dstring;
    }

    private void updateStatus(string message)
    {
        _statusText.text = message.to!dstring;
    }

    private void updateActivity()
    {
        _lastActivity = Clock.currTime();
    }

    private void checkAutoLock()
    {
        if (!_isUnlocked) return;

        // For now, use a simple timeout check - in full implementation would get from vault settings
        auto elapsed = Clock.currTime() - _lastActivity;
        if (elapsed.total!"seconds" > 900) // 15 minutes
        {
            lockVault();
            showMessage("Vault locked due to inactivity");
        }
    }

    private void copyToClipboard(string text)
    {
        // Placeholder for clipboard implementation
        // In a real implementation, this would use the system clipboard
        writeln("Copied to clipboard: ", text);

        // Start clipboard clear thread - simplified for now
        auto clearThread = new Thread(() {
            Thread.sleep(30.seconds);
            writeln("Clipboard cleared");
        });
        clearThread.start();
    }

    private void updateTheme()
    {
        _theme.applyTheme();
        backgroundColor = _theme.getBackgroundColor();

        // Update all child components
        invalidate();
    }

    private uint parseHexColor(string hexColor)
    {
        if (hexColor.startsWith("#"))
            hexColor = hexColor[1 .. $];

        try
        {
            return cast(uint)hexColor.to!uint(16) | 0xFF000000;
        }
        catch (Exception)
        {
            return 0xFF000000;
        }
    }

    // Dialog methods (simplified implementations)
    private void showErrorMessage(string message)
    {
        showMessage("❌ " ~ message);
    }

    private void showMessage(string message)
    {
        updateStatus(message);
        // In a real implementation, this would show a toast/notification
    }

    private bool showConfirmDialog(string message)
    {
        // Simplified confirmation - in real implementation would show proper dialog
        writeln("Confirm: ", message);
        return true; // For demo purposes
    }

    private void showAddEntryDialog()
    {
        // Placeholder for add entry dialog
        showMessage("Add entry dialog would appear here");
    }

    private void showEditEntryDialog(BaseVaultEntry entry)
    {
        // Placeholder for edit entry dialog
        showMessage("Edit entry dialog would appear here");
    }

    private void showAddTOTPDialog()
    {
        // Placeholder for add TOTP dialog
        showMessage("Add TOTP dialog would appear here");
    }

    private void showPasswordGeneratorDialog()
    {
        // Placeholder for password generator dialog
        showMessage("Password generator dialog would appear here");
    }

    private void showFilterDialog()
    {
        // Placeholder for filter dialog
        showMessage("Filter dialog would appear here");
    }

    private void showSettingsDialog()
    {
        // Placeholder for settings dialog
        showMessage("Settings dialog would appear here");
    }

    private void showChangeMasterPasswordDialog()
    {
        // Placeholder for change master password dialog
        showMessage("Change master password dialog would appear here");
    }

    private void showImportDialog()
    {
        // Placeholder for import dialog
        showMessage("Import dialog would appear here");
    }

    private void showExportDialog()
    {
        // Placeholder for export dialog
        showMessage("Export dialog would appear here");
    }

    private void showBackupDialog()
    {
        // Placeholder for backup dialog
        showMessage("Backup dialog would appear here");
    }

    // Keyboard event handling
    override bool onKeyEvent(KeyEvent event)
    {
        updateActivity();

        if (event.action == KeyAction.KeyDown)
        {
            // Ctrl+L - Lock vault
            if (event.keyCode == KeyCode.KEY_L && (event.flags & KeyFlag.Control))
            {
                if (_isUnlocked)
                {
                    lockVault();
                    return true;
                }
            }

            // Ctrl+F - Focus search
            if (event.keyCode == KeyCode.KEY_F && (event.flags & KeyFlag.Control))
            {
                if (_isUnlocked && _searchBox)
                {
                    _searchBox.setFocus();
                    return true;
                }
            }

            // Escape - Clear selection
            if (event.keyCode == KeyCode.ESCAPE)
            {
                if (_selectedEntry)
                {
                    // _entryList.clearSelection(); // Would need different implementation
                    _entryDetailsPanel.removeAllChildren();
                    _selectedEntry = null;
                    return true;
                }
            }
        }

        return super.onKeyEvent(event);
    }

    // Mouse event handling for activity tracking
    override bool onMouseEvent(MouseEvent event)
    {
        updateActivity();
        return super.onMouseEvent(event);
    }
}

/// Application entry point
extern (C) int UIAppMain(string[] args)
{
    // Initialize the theme
    auto theme = SecurityTheme.instance();
    theme.applyTheme();

    // Create main window
    Window window = Platform.instance.createWindow("Dowel-Steek Security Suite", null,
                                                   WindowFlag.Resizable, 1200, 800);

    // Create and set the main widget
    auto app = new EnhancedSecurityApp();
    window.mainWidget = app;

    // Show window
    window.show();

    // Message loop
    return Platform.instance.enterMessageLoop();
}
