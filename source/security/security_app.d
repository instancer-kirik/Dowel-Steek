module security.security_app;

import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.menu;
import dlangui.widgets.tabs;
import dlangui.dialogs.dialog;
import dlangui.core.events;

import std.string;
import std.conv;
import std.file;
import std.path;

import security.password_manager.gui;
import security.authenticator.gui;

/// Main security application combining password manager and authenticator
class SecurityApp : AppFrame
{
    private TabWidget _mainTabs;
    private PasswordManagerWindow _passwordManager;
    private AuthenticatorWindow _authenticator;

    this()
    {
        super();
        windowCaption = "Dowel-Steek Security Suite";
        createUI();
    }

    private void createUI()
    {
        // Create menu bar
        auto menuBar = new MenuBar();

        auto fileMenu = menuBar.addSubmenu("File");
        fileMenu.addAction(ACTION_FILE_EXIT, "Exit"d);

        auto viewMenu = menuBar.addSubmenu("View");
        viewMenu.addAction(ACTION_VIEW_PASSWORD_MANAGER, "Password Manager"d);
        viewMenu.addAction(ACTION_VIEW_AUTHENTICATOR, "Authenticator"d);

        auto toolsMenu = menuBar.addSubmenu("Tools");
        toolsMenu.addAction(ACTION_TOOLS_SETTINGS, "Settings"d);
        toolsMenu.addAction(ACTION_TOOLS_ABOUT, "About"d);

        mainWidget = menuBar;

        // Create main content
        auto vbox = new VerticalLayout();
        vbox.layoutWidth = FILL_PARENT;
        vbox.layoutHeight = FILL_PARENT;

        // Create tab widget
        _mainTabs = new TabWidget("mainTabs");
        _mainTabs.layoutWidth = FILL_PARENT;
        _mainTabs.layoutHeight = FILL_PARENT;
        _mainTabs.tabClose = &onTabClose;

        // Create password manager tab
        createPasswordManagerTab();

        // Create authenticator tab
        createAuthenticatorTab();

        vbox.addChild(_mainTabs);
        menuBar.addChild(vbox);
    }

    private void createPasswordManagerTab()
    {
        // Create a container for the password manager
        auto container = new VerticalLayout();
        container.layoutWidth = FILL_PARENT;
        container.layoutHeight = FILL_PARENT;

        // Create embedded password manager (simplified version)
        auto passwordManagerWidget = createPasswordManagerWidget();
        container.addChild(passwordManagerWidget);

        _mainTabs.addTab(container, "Password Manager"d, null, true);
    }

    private void createAuthenticatorTab()
    {
        // Create a container for the authenticator
        auto container = new VerticalLayout();
        container.layoutWidth = FILL_PARENT;
        container.layoutHeight = FILL_PARENT;

        // Create embedded authenticator (simplified version)
        auto authenticatorWidget = createAuthenticatorWidget();
        container.addChild(authenticatorWidget);

        _mainTabs.addTab(container, "Authenticator"d, null, true);
    }

    private Widget createPasswordManagerWidget()
    {
        auto vbox = new VerticalLayout();
        vbox.layoutWidth = FILL_PARENT;
        vbox.layoutHeight = FILL_PARENT;
        vbox.padding = Rect(10, 10, 10, 10);

        // Header
        auto headerText = new TextWidget();
        headerText.text = "Password Manager"d;
        headerText.fontSize = 16;
        headerText.fontWeight = 600;
        vbox.addChild(headerText);

        // Launch full password manager button
        auto launchBtn = new Button("launchPasswordManager", "Open Password Manager"d);
        launchBtn.click = delegate(Widget source) {
            launchPasswordManager();
            return true;
        };
        vbox.addChild(launchBtn);

        // Quick stats
        auto statsText = new TextWidget();
        statsText.text = "Click above to manage your passwords securely"d;
        statsText.textColor = 0xFF666666;
        vbox.addChild(statsText);

        return vbox;
    }

    private Widget createAuthenticatorWidget()
    {
        auto vbox = new VerticalLayout();
        vbox.layoutWidth = FILL_PARENT;
        vbox.layoutHeight = FILL_PARENT;
        vbox.padding = Rect(10, 10, 10, 10);

        // Header
        auto headerText = new TextWidget();
        headerText.text = "TOTP Authenticator"d;
        headerText.fontSize = 16;
        headerText.fontWeight = 600;
        vbox.addChild(headerText);

        // Launch full authenticator button
        auto launchBtn = new Button("launchAuthenticator", "Open Authenticator"d);
        launchBtn.click = delegate(Widget source) {
            launchAuthenticator();
            return true;
        };
        vbox.addChild(launchBtn);

        // Quick stats
        auto statsText = new TextWidget();
        statsText.text = "Click above to manage your 2FA codes"d;
        statsText.textColor = 0xFF666666;
        vbox.addChild(statsText);

        return vbox;
    }

    private void launchPasswordManager()
    {
        // Create and show password manager window
        auto window = Platform.instance.createWindow("Password Manager"d, null,
            WindowFlag.Resizable, 800, 600);

        auto passwordManager = new PasswordManagerWindow();
        window.mainWidget = passwordManager.contentWidget;
        window.show();
    }

    private void launchAuthenticator()
    {
        // Create and show authenticator window
        auto window = Platform.instance.createWindow("TOTP Authenticator"d, null,
            WindowFlag.Resizable, 600, 500);

        auto authenticator = new AuthenticatorWindow();
        window.mainWidget = authenticator.contentWidget;
        window.show();
    }

    private bool onTabClose(string tabId)
    {
        // Prevent closing tabs for now
        return false;
    }

    override bool handleAction(const Action action)
    {
        switch (action.id)
        {
            case ACTION_VIEW_PASSWORD_MANAGER:
                _mainTabs.selectTab(0);
                return true;

            case ACTION_VIEW_AUTHENTICATOR:
                _mainTabs.selectTab(1);
                return true;

            case ACTION_TOOLS_SETTINGS:
                showSettings();
                return true;

            case ACTION_TOOLS_ABOUT:
                showAbout();
                return true;

            case ACTION_FILE_EXIT:
                window.close();
                return true;

            default:
                return super.handleAction(action);
        }
    }

    private void showSettings()
    {
        auto dialog = new SettingsDialog(window);
        dialog.show();
    }

    private void showAbout()
    {
        window.showMessageBox("About Dowel-Steek Security Suite"d,
            "Dowel-Steek Security Suite v1.0\n\n"d ~
            "A comprehensive password manager and TOTP authenticator\n"d ~
            "built with D and DlangUI.\n\n"d ~
            "Features:\n"d ~
            "• Secure password storage with AES encryption\n"d ~
            "• TOTP 2FA code generation\n"d ~
            "• Password strength analysis\n"d ~
            "• Security reporting\n"d ~
            "• QR code support\n\n"d ~
            "Copyright © 2024 Dowel-Steek Project"d);
    }
}

/// Settings dialog
class SettingsDialog : Dialog
{
    this(Window parent)
    {
        super(UIString.fromRaw("Settings"), parent, DialogFlag.Modal);
        createUI();
    }

    private void createUI()
    {
        auto vbox = new VerticalLayout();
        vbox.margins = Rect(20, 20, 20, 20);
        vbox.layoutWidth = 400;

        // Security settings
        auto securityGroup = new GroupBox("securityGroup", "Security Settings"d);
        auto securityVBox = new VerticalLayout();

        auto lockTimeoutCheck = new CheckBox("lockTimeoutCheck", "Auto-lock after inactivity"d);
        lockTimeoutCheck.checked = true;
        securityVBox.addChild(lockTimeoutCheck);

        auto clipboardClearCheck = new CheckBox("clipboardClearCheck", "Clear clipboard after copy"d);
        clipboardClearCheck.checked = true;
        securityVBox.addChild(clipboardClearCheck);

        securityGroup.contentWidget = securityVBox;
        vbox.addChild(securityGroup);

        // Backup settings
        auto backupGroup = new GroupBox("backupGroup", "Backup Settings"d);
        auto backupVBox = new VerticalLayout();

        auto autoBackupCheck = new CheckBox("autoBackupCheck", "Enable automatic backups"d);
        autoBackupCheck.checked = false;
        backupVBox.addChild(autoBackupCheck);

        backupGroup.contentWidget = backupVBox;
        vbox.addChild(backupGroup);

        // Buttons
        auto buttonRow = new HorizontalLayout();
        buttonRow.addChild(new HSpacer());

        auto saveBtn = new Button("saveBtn", "Save"d);
        saveBtn.click = delegate(Widget source) {
            // TODO: Save settings
            close();
            return true;
        };
        buttonRow.addChild(saveBtn);

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

// Action IDs
enum
{
    ACTION_VIEW_PASSWORD_MANAGER = 3000,
    ACTION_VIEW_AUTHENTICATOR,
    ACTION_TOOLS_SETTINGS,
    ACTION_TOOLS_ABOUT,
    ACTION_FILE_EXIT = 4000
}

// Main entry point for security application
extern (C) int UIAppMain(string[] args)
{
    // Enable debug logging
    Log.setLogLevel(LogLevel.Debug);

    writeln("Dowel-Steek Security Suite starting...");
    writeln("Version: 1.0.0");

    try
    {
        // Create main window
        auto window = Platform.instance.createWindow("Dowel-Steek Security Suite"d, null,
            WindowFlag.Resizable, 900, 700);

        if (!window)
        {
            writeln("ERROR: Failed to create main window");
            return 1;
        }

        // Create security application
        auto app = new SecurityApp();
        window.mainWidget = app;

        // Show window
        window.show();

        // Enter message loop
        return Platform.instance.enterMessageLoop();
    }
    catch (Exception e)
    {
        writeln("ERROR: Exception caught: ", e.msg);
        Log.e("Fatal error: ", e.msg);
        return 1;
    }
}
