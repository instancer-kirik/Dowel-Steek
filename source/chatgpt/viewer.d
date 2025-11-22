module chatgpt.viewer;

import dlangui;
import dlangui.widgets.widget;
import dlangui.platforms.common.platform;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.widgets.editors;
import dlangui.widgets.lists;
import dlangui.widgets.tree;
import dlangui.widgets.scrollbar;
import dlangui.widgets.combobox;
import dlangui.widgets.groupbox;
import dlangui.widgets.tabs;
import dlangui.widgets.menu;
import dlangui.widgets.toolbars;
import dlangui.core.events;
import dlangui.core.types;
import dlangui.core.signals;
import dlangui.core.editable;
import dlangui.dialogs.filedlg;
import dlangui.dialogs.dialog;

import chatgpt.models;
import chatgpt.widgets;
import std.json;
import std.file;
import std.path;
import std.conv;
import std.algorithm;
import std.array;
import std.datetime;
import std.datetime.systime;
import std.format;
import std.exception;
import std.utf;
import std.string;
import std.uni;

/// Message type for better categorization
enum MessageType
{
    User,
    Assistant,
    System,
    ToolCall,
    ToolResult,
    RAGContext,
    Error
}

/// Enhanced message widget with support for different message types
class EnhancedMessageWidget : VerticalLayout
{
    private ConversationMessage _message;
    private MessageType _messageType;
    private TextWidget _headerWidget;
    private EditBox _contentBox;
    private VerticalLayout _metadataPanel;
    private bool _expanded = true;

    this(ConversationMessage message, MessageType messageType = MessageType.Assistant)
    {
        super("msg_" ~ message.id);
        _message = message;
        _messageType = messageType;

        layoutWidth = FILL_PARENT;
        layoutHeight = WRAP_CONTENT;
        margins = Rect(5, 5, 5, 5);
        padding = Rect(10, 10, 10, 10);

        setMessageStyle();
        initUI();
    }

    private void setMessageStyle()
    {
        switch (_messageType)
        {
        case MessageType.User:
            backgroundColor = 0xFFE3F2FD; // Light blue
            break;
        case MessageType.Assistant:
            backgroundColor = 0xFFF1F8E9; // Light green
            break;
        case MessageType.System:
            backgroundColor = 0xFFFFF3E0; // Light orange
            break;
        case MessageType.ToolCall:
            backgroundColor = 0xFFE8EAF6; // Light indigo
            break;
        case MessageType.ToolResult:
            backgroundColor = 0xFFE0F2F1; // Light teal
            break;
        case MessageType.RAGContext:
            backgroundColor = 0xFFF3E5F5; // Light purple
            break;
        default:
            backgroundColor = 0xFFF5F5F5; // Light gray
            break;
        }
    }

    private void initUI()
    {
        // Header with role, timestamp, and expand/collapse
        auto header = new HorizontalLayout("header");
        header.layoutWidth = FILL_PARENT;
        header.layoutHeight = WRAP_CONTENT;

        // Role and message type indicator
        string roleText = _message.author.role.capitalize();
        if (_messageType != MessageType.User && _messageType != MessageType.Assistant)
        {
            roleText ~= " (" ~ to!string(_messageType) ~ ")";
        }

        _headerWidget = new TextWidget("role", toUTF32(roleText));
        _headerWidget.fontSize = 12;
        _headerWidget.fontWeight = 600;
        _headerWidget.textColor = getHeaderColor();
        header.addChild(_headerWidget);

        // Spacer
        auto spacer = new Widget("spacer");
        spacer.layoutWidth = FILL_PARENT;
        spacer.layoutWeight = 1;
        header.addChild(spacer);

        // Timestamp
        auto timeWidget = new TextWidget("time", toUTF32(_message.getFormattedTime()));
        timeWidget.fontSize = 9;
        timeWidget.textColor = 0xFF808080;
        header.addChild(timeWidget);

        // Expand/collapse button
        auto toggleBtn = new Button("toggle", _expanded ? "▼"d : "▶"d);
        toggleBtn.click = delegate(Widget w) { toggleExpansion(); return true; };
        header.addChild(toggleBtn);

        addChild(header);

        // Content area
        _contentBox = new EditBox("content", toUTF32(_message.content.getFullText()));
        _contentBox.layoutWidth = FILL_PARENT;
        _contentBox.layoutHeight = WRAP_CONTENT;
        _contentBox.minHeight = 60;
        _contentBox.readOnly = true;
        _contentBox.wordWrap = true;
        _contentBox.backgroundColor = 0xFFFFFFFF;
        _contentBox.margins = Rect(0, 5, 0, 5);
        addChild(_contentBox);

        // Metadata panel (collapsible)
        _metadataPanel = new VerticalLayout("metadata");
        _metadataPanel.layoutWidth = FILL_PARENT;
        _metadataPanel.layoutHeight = WRAP_CONTENT;
        _metadataPanel.backgroundColor = 0xFFF8F8F8;
        _metadataPanel.padding = Rect(10, 5, 10, 5);
        _metadataPanel.margins = Rect(0, 5, 0, 0);

        addMetadataInfo();
        addChild(_metadataPanel);

        updateVisibility();
    }

    private uint getHeaderColor()
    {
        switch (_messageType)
        {
        case MessageType.User:
            return 0xFF1976D2;
        case MessageType.Assistant:
            return 0xFF388E3C;
        case MessageType.System:
            return 0xFFF57C00;
        case MessageType.ToolCall:
            return 0xFF3F51B5;
        case MessageType.ToolResult:
            return 0xFF00796B;
        case MessageType.RAGContext:
            return 0xFF7B1FA2;
        default:
            return 0xFF424242;
        }
    }

    private void addMetadataInfo()
    {
        // Message ID and status
        auto idText = new TextWidget("id", toUTF32("ID: " ~ _message.id));
        idText.fontSize = 8;
        idText.textColor = 0xFF666666;
        _metadataPanel.addChild(idText);

        if (_message.status.length > 0)
        {
            auto statusText = new TextWidget("status", toUTF32("Status: " ~ _message.status));
            statusText.fontSize = 8;
            statusText.textColor = 0xFF666666;
            _metadataPanel.addChild(statusText);
        }

        // Token estimate
        auto tokenEstimate = ConversationStats.estimateTokens(_message.content.getFullText());
        auto tokenText = new TextWidget("tokens", toUTF32(format("~%d tokens", tokenEstimate)));
        tokenText.fontSize = 8;
        tokenText.textColor = 0xFF666666;
        _metadataPanel.addChild(tokenText);

        // Weight and other metadata
        if (_message.weight != 1.0)
        {
            auto weightText = new TextWidget("weight", toUTF32(format("Weight: %.2f", _message
                    .weight)));
            weightText.fontSize = 8;
            weightText.textColor = 0xFF666666;
            _metadataPanel.addChild(weightText);
        }
    }

    private void toggleExpansion()
    {
        _expanded = !_expanded;
        updateVisibility();
    }

    private void updateVisibility()
    {
        _contentBox.visibility = _expanded ? Visibility.Visible : Visibility.Gone;
        _metadataPanel.visibility = _expanded ? Visibility.Visible : Visibility.Gone;

        // Update button text
        if (childCount > 0)
        {
            auto header = child(0);
            if (header && header.childCount > 3)
            {
                auto toggleBtn = cast(Button) header.child(3);
                if (toggleBtn)
                {
                    toggleBtn.text = _expanded ? "▼"d : "▶"d;
                }
            }
        }
    }

    @property ConversationMessage message()
    {
        return _message;
    }

    @property MessageType messageType()
    {
        return _messageType;
    }
}

/// Enhanced stats and info panel
class ConversationInfoPanel : VerticalLayout
{
    private TextWidget _titleWidget;
    private TextWidget _statsWidget;
    private TextWidget _ragInfoWidget;
    private VerticalLayout _toolsSection;

    this()
    {
        super("info_panel");
        layoutWidth = WRAP_CONTENT;
        layoutHeight = FILL_PARENT;
        minWidth = 250;
        backgroundColor = 0xFFF8F9FA;
        padding = Rect(15, 15, 15, 15);

        initUI();
    }

    private void initUI()
    {
        // Title section
        _titleWidget = new TextWidget("title", "No Conversation"d);
        _titleWidget.fontSize = 14;
        _titleWidget.fontWeight = 700;
        _titleWidget.margins = Rect(0, 0, 0, 10);
        addChild(_titleWidget);

        // Stats section
        auto statsLabel = new TextWidget("stats_label", "Statistics"d);
        statsLabel.fontSize = 12;
        statsLabel.fontWeight = 600;
        statsLabel.margins = Rect(0, 0, 0, 5);
        addChild(statsLabel);

        _statsWidget = new TextWidget("stats", "No data"d);
        _statsWidget.fontSize = 10;
        _statsWidget.margins = Rect(0, 0, 0, 15);
        addChild(_statsWidget);

        // RAG Info section
        auto ragLabel = new TextWidget("rag_label", "RAG Context"d);
        ragLabel.fontSize = 12;
        ragLabel.fontWeight = 600;
        ragLabel.margins = Rect(0, 0, 0, 5);
        addChild(ragLabel);

        _ragInfoWidget = new TextWidget("rag_info", "No RAG data detected"d);
        _ragInfoWidget.fontSize = 10;
        _ragInfoWidget.margins = Rect(0, 0, 0, 15);
        addChild(_ragInfoWidget);

        // Tools section
        auto toolsLabel = new TextWidget("tools_label", "Tools Used"d);
        toolsLabel.fontSize = 12;
        toolsLabel.fontWeight = 600;
        toolsLabel.margins = Rect(0, 0, 0, 5);
        addChild(toolsLabel);

        _toolsSection = new VerticalLayout("tools");
        _toolsSection.layoutWidth = FILL_PARENT;
        _toolsSection.layoutHeight = WRAP_CONTENT;
        addChild(_toolsSection);
    }

    void updateInfo(ChatGPTConversation conversation)
    {
        if (!conversation)
        {
            _titleWidget.text = "No Conversation"d;
            _statsWidget.text = "No data"d;
            _ragInfoWidget.text = "No RAG data detected"d;
            _toolsSection.removeAllChildren();
            return;
        }

        // Update title
        _titleWidget.text = toUTF32(conversation.getTitle());

        // Update stats
        auto stats = conversation.getStats();
        auto statsText = format(
            "Messages: %d\n" ~
                "• User: %d\n" ~
                "• Assistant: %d\n" ~
                "• System: %d\n\n" ~
                "Estimated Tokens: %d\n" ~
                "Duration: %.1f hours\n" ~
                "Avg tokens/msg: %.0f",
            stats.totalMessages,
            stats.userMessages,
            stats.assistantMessages,
            stats.totalMessages - stats.userMessages - stats.assistantMessages,
            stats.totalTokensApprox,
            stats.duration / 3600.0,
            stats.totalMessages > 0 ? cast(double) stats.totalTokensApprox / stats.totalMessages : 0
        );
        _statsWidget.text = toUTF32(statsText);

        // Analyze for RAG and tools
        analyzeRAGAndTools(conversation);
    }

    private void analyzeRAGAndTools(ChatGPTConversation conversation)
    {
        auto messages = conversation.getMessagesChronological();

        // Look for RAG patterns
        size_t ragMessages = 0;
        size_t toolCalls = 0;
        string[] toolsUsed;

        foreach (msg; messages)
        {
            auto content = msg.content.getFullText().toLower();

            // Check for RAG indicators
            if (content.canFind("retrieved") || content.canFind("search results") ||
                content.canFind("context:") || content.canFind("sources:"))
            {
                ragMessages++;
            }

            // Check for tool usage indicators
            if (content.canFind("function_call") || content.canFind("tool_call") ||
                content.canFind("```json") || content.canFind("api call"))
            {
                toolCalls++;
            }

            // Extract potential tool names
            if (content.canFind("python") && !toolsUsed.canFind("Python"))
            {
                toolsUsed ~= "Python";
            }
            if (content.canFind("browser") && !toolsUsed.canFind("Browser"))
            {
                toolsUsed ~= "Browser";
            }
            if (content.canFind("dalle") && !toolsUsed.canFind("DALL-E"))
            {
                toolsUsed ~= "DALL-E";
            }
        }

        // Update RAG info
        if (ragMessages > 0)
        {
            _ragInfoWidget.text = toUTF32(format("Found %d messages with RAG context", ragMessages));
        }
        else
        {
            _ragInfoWidget.text = "No RAG data detected"d;
        }

        // Update tools section
        _toolsSection.removeAllChildren();
        if (toolsUsed.length > 0)
        {
            foreach (tool; toolsUsed)
            {
                auto toolWidget = new TextWidget("tool_" ~ tool, toUTF32("• " ~ tool));
                toolWidget.fontSize = 10;
                toolWidget.margins = Rect(0, 2, 0, 2);
                _toolsSection.addChild(toolWidget);
            }
        }
        else
        {
            auto noToolsWidget = new TextWidget("no_tools", "No tools detected"d);
            noToolsWidget.fontSize = 10;
            noToolsWidget.textColor = 0xFF666666;
            _toolsSection.addChild(noToolsWidget);
        }
    }
}

/// Main enhanced ChatGPT conversation viewer
class ChatGPTViewerWindow : HorizontalLayout
{
    private ChatGPTConversation _conversation;
    private ToolBar _toolbar;
    private HorizontalLayout _mainContent;
    private VerticalLayout _sidebar;
    private VerticalLayout _conversationArea;
    private ScrollWidget _messageScroll;
    private VerticalLayout _messageContainer;
    private ConversationInfoPanel _infoPanel;
    private EditLine _searchBox;
    private ComboBox _filterCombo;
    private VirtualListWidget _conversationList;
    private string _loadedFile;
    private ConversationCollection _conversationCollection;
    private int _currentPage = 0;
    private int _conversationsPerPage = 50;
    private HorizontalLayout _paginationControls;

    // Search-related members
    private ulong _searchTimerId = 0;
    private size_t[] _searchResults;
    private bool _showingSearchResults = false;
    private Button _prevPageButton;
    private Button _nextPageButton;
    private TextWidget _pageInfo;
    private ulong _searchIndexTimerId = 0;

    this()
    {
        super("chatgpt_viewer");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        backgroundColor = 0xFFFF00FF; // BRIGHT MAGENTA to confirm we're using the right code

        import std.stdio : writeln;

        writeln("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        writeln("!!!! MODIFIED VIEWER WITH LAZY LOADING IS ACTIVE !!!!");
        writeln("!!!! Background should be BRIGHT MAGENTA         !!!!");
        writeln("!!!! Conversations should switch correctly       !!!!");
        writeln("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        writeln("DEBUG: Sidebar list should have CYAN background");
        writeln("DEBUG: Test button should be in toolbar");

        initUI();

        writeln("DEBUG: UI initialized, child count: ", childCount);
        // Auto-load will happen after widget is attached to window
    }

    private bool _autoLoadDone = false;

    override void onDraw(DrawBuf buf) {
        import std.stdio : writeln;

        super.onDraw(buf);

        // Auto-load Jan conversations on first draw (when window is available)
        if (!_autoLoadDone && window) {
            _autoLoadDone = true;
            writeln("DEBUG: Auto-loading Jan conversations for testing...");
            try {
                writeln("DEBUG: About to call loadFromJan()");
                loadFromJan();
                writeln("DEBUG: loadFromJan() completed successfully");
            } catch (Exception e) {
                writeln("ERROR: Exception in loadFromJan: ", e.msg);
                writeln("ERROR: Stack trace: ", e.toString());
            }
        }
    }

    private void initUI()
    {
        import std.stdio : writeln;

        writeln("DEBUG: initUI called");

        // Sidebar with conversation management
        _sidebar = new VerticalLayout("sidebar");
        _sidebar.layoutWidth = WRAP_CONTENT;
        _sidebar.layoutHeight = FILL_PARENT;
        _sidebar.minWidth = 300;
        _sidebar.maxWidth = 400;
        _sidebar.backgroundColor = 0xFFF5F5F5;
        _sidebar.padding = Rect(10, 10, 10, 10);
        _sidebar.visibility = Visibility.Visible;

        writeln("DEBUG: Creating sidebar");
        initSidebar();
        addChild(_sidebar);
        writeln("DEBUG: Sidebar added, child count: ", childCount);

        // Main content area
        _mainContent = new HorizontalLayout("main_content");
        _mainContent.layoutWidth = FILL_PARENT;
        _mainContent.layoutHeight = FILL_PARENT;
        _mainContent.layoutWeight = 1;
        _mainContent.visibility = Visibility.Visible;

        writeln("DEBUG: Creating main content");
        initMainContent();
        addChild(_mainContent);
        writeln("DEBUG: Main content added, child count: ", childCount);
    }

    private void initSidebar()
    {
        import std.stdio : writeln;

        writeln("DEBUG: initSidebar called");

        // Sidebar header
        auto headerText = new TextWidget("sidebar_header", "Conversations"d);
        headerText.fontSize = 16;
        headerText.fontWeight = 700;
        headerText.margins = Rect(0, 0, 0, 10);
        headerText.layoutWidth = FILL_PARENT;
        headerText.textColor = 0xFF000000;
        _sidebar.addChild(headerText);
        writeln("DEBUG: Added header text");

        // Load button
        auto loadBtn = new Button("load_conversation", "Load Conversation"d);
        loadBtn.layoutWidth = FILL_PARENT;
        loadBtn.layoutHeight = WRAP_CONTENT;
        loadBtn.click = delegate(Widget w) { openFileDialog(); return true; };
        loadBtn.margins = Rect(0, 0, 0, 5);
        _sidebar.addChild(loadBtn);
        writeln("DEBUG: Added load button");

        // Load from Jan button
        auto janBtn = new Button("load_jan", "Load from Jan"d);
        janBtn.layoutWidth = FILL_PARENT;
        janBtn.layoutHeight = WRAP_CONTENT;
        janBtn.click = delegate(Widget w) { loadFromJan(); return true; };
        janBtn.margins = Rect(0, 0, 0, 10);
        _sidebar.addChild(janBtn);
        writeln("DEBUG: Added Jan button");

        // Search and filter
        _searchBox = new EditLine("conversation_search", ""d);
        _searchBox.layoutWidth = FILL_PARENT;
        _searchBox.layoutHeight = WRAP_CONTENT;
        _searchBox.margins = Rect(0, 0, 0, 5);
        _searchBox.contentChange = delegate(EditableContent content) {
            onSearchTextChanged();
        };
        _sidebar.addChild(_searchBox);
        writeln("DEBUG: Added search box");

        // Filter dropdown
        _filterCombo = new ComboBox("filter_combo", [
            "All Messages"d, "User Only"d, "Assistant Only"d, "System Only"d,
            "With Tools"d, "With RAG"d
        ]);
        _filterCombo.layoutWidth = FILL_PARENT;
        _filterCombo.margins = Rect(0, 0, 0, 10);
        _sidebar.addChild(_filterCombo);

        // SIMPLIFIED TEST: Replace complex list with a simple visible widget
        writeln("DEBUG: Creating simplified test widget for conversation list");

        // Create virtual list for efficient scrolling of large conversation lists
        _conversationList = new VirtualListWidget("conv_list");
        _conversationList.layoutWidth = FILL_PARENT;
        _conversationList.layoutHeight = FILL_PARENT;
        _conversationList.setItemHeight(72); // Set consistent item height for virtual scrolling
        _conversationList.layoutWeight = 1;

        // Virtual list will create items on demand, no need for a container
        writeln("DEBUG: Virtual list widget created and configured");

        // Add pagination controls
        _paginationControls = new HorizontalLayout("pagination");
        _paginationControls.layoutWidth = FILL_PARENT;
        _paginationControls.layoutHeight = WRAP_CONTENT;
        _paginationControls.margins = Rect(5, 5, 5, 5);
        _paginationControls.visibility = Visibility.Gone; // Hidden by default

        auto prevButton = new Button("btnPrev", "◀ Prev"d);
        prevButton.click = &onPreviousPage;
        _paginationControls.addChild(prevButton);

        auto pageInfo = new TextWidget("pageInfo", "Page 1 of 1"d);
        pageInfo.layoutWidth = FILL_PARENT;
        pageInfo.layoutWeight = 1;
        _paginationControls.addChild(pageInfo);

        auto nextButton = new Button("btnNext", "Next ▶"d);
        nextButton.click = &onNextPage;
        _paginationControls.addChild(nextButton);

        _sidebar.addChild(_conversationList);
        _sidebar.addChild(_paginationControls);

        import std.stdio : writeln;

        writeln("DEBUG: Sidebar initialization complete, sidebar child count: ", _sidebar
                .childCount);
    }

    private void initMainContent()
    {
        import std.stdio : writeln;

        writeln("DEBUG: initMainContent called");

        // Conversation area
        _conversationArea = new VerticalLayout("conversation_area");
        _conversationArea.layoutWidth = FILL_PARENT;
        _conversationArea.layoutHeight = FILL_PARENT;
        _conversationArea.layoutWeight = 3;
        _conversationArea.backgroundColor = 0xFFFFFFFF;

        // Toolbar
        _toolbar = new ToolBar("toolbar");
        auto exportBtn = new Button("export_btn", "Export"d);
        exportBtn.click = delegate(Widget w) { exportToText(); return true; };
        _toolbar.addChild(exportBtn);

        auto searchBtn = new Button("search_btn", "Search Messages"d);
        searchBtn.click = delegate(Widget w) {
            toggleMessageSearch();
            return true;
        };
        _toolbar.addChild(searchBtn);

        auto clearBtn = new Button("clear_btn", "Clear"d);
        clearBtn.click = delegate(Widget w) { clearConversation(); return true; };
        _toolbar.addChild(clearBtn);

        // Add test button for debugging visibility
        writeln("DEBUG: *** ADDING TEST BUTTON TO TOOLBAR ***");
        auto testBtn = new Button("test_btn", "ADD TEST ITEM - CLICK ME!"d);
        testBtn.click = delegate(Widget w) {
            import std.stdio : writeln;
            import std.datetime : DateTime, Clock, SysTime;
            import std.conv : to;

            writeln("DEBUG: Test button clicked - virtual list is active");
            writeln("DEBUG: _conversationList visible: ", _conversationList.visibility);

            return true;
        };
        _toolbar.addChild(testBtn);

        _conversationArea.addChild(_toolbar);

        // Message display area
        _messageScroll = new ScrollWidget("message_scroll");
        _messageScroll.layoutWidth = FILL_PARENT;
        _messageScroll.layoutHeight = FILL_PARENT;

        _messageContainer = new VerticalLayout("message_container");
        _messageContainer.layoutWidth = FILL_PARENT;
        _messageContainer.layoutHeight = WRAP_CONTENT;
        _messageContainer.padding = Rect(15, 15, 15, 15);

        showWelcomeMessage();
        _messageScroll.contentWidget = _messageContainer;
        _conversationArea.addChild(_messageScroll);

        _mainContent.addChild(_conversationArea);

        // Info panel
        _infoPanel = new ConversationInfoPanel();
        _infoPanel.visibility = Visibility.Visible;
        _infoPanel.layoutWeight = 1; // Make info panel smaller relative to conversation area
        _infoPanel.maxWidth = 350; // Limit maximum width
        _mainContent.addChild(_infoPanel);

        import std.stdio : writeln;

        writeln("DEBUG: Main content initialization complete, main content child count: ", _mainContent
                .childCount);
    }

    private void showWelcomeMessage()
    {
        _messageContainer.removeAllChildren();

        auto welcomeLayout = new VerticalLayout("welcome");
        welcomeLayout.layoutWidth = FILL_PARENT;
        welcomeLayout.layoutHeight = FILL_PARENT;
        welcomeLayout.backgroundColor = 0xFFF8F9FA;
        welcomeLayout.padding = Rect(30, 30, 30, 30);

        auto titleWidget = new TextWidget("welcome_title", "Enhanced ChatGPT Conversation Viewer"d);
        titleWidget.fontSize = 20;
        titleWidget.fontWeight = 700;
        titleWidget.alignment = Align.Center;
        titleWidget.margins = Rect(0, 0, 0, 20);
        welcomeLayout.addChild(titleWidget);

        auto featuresText =
            "Features:\n\n" ~
            "• Advanced conversation management\n" ~
            "• RAG context detection\n" ~
            "• Tool usage analysis\n" ~
            "• Enhanced search and filtering\n" ~
            "• Message type categorization\n" ~
            "• Token estimation and statistics\n" ~
            "• Export capabilities\n\n" ~
            "Load a ChatGPT conversation to get started.";

        auto featuresWidget = new TextWidget("features", toUTF32(featuresText));
        featuresWidget.fontSize = 12;
        featuresWidget.alignment = Align.Left;
        welcomeLayout.addChild(featuresWidget);

        _messageContainer.addChild(welcomeLayout);
    }

    private void openFileDialog()
    {
        auto dlg = new FileDialog(UIString.fromRaw("Open ChatGPT Conversation"d), window, null, FileDialogFlag
                .Open);
        dlg.dialogResult = (Dialog d, const Action result) {
            if (result.id == ACTION_OPEN.id)
            {
                auto path = dlg.filename;
                loadConversationFile(path);
            }
        };
        dlg.show();
    }

    private void loadFromJan()
    {
        import std.process : environment;
        import std.stdio : writeln;

        string janPath = "~/.local/share/Jan/data/conversations.json";

        // Expand home directory
        auto homeDir = environment.get("HOME");
        if (homeDir.length > 0)
        {
            janPath = buildPath(homeDir, ".local", "share", "Jan", "data", "conversations.json");
        }

        if (exists(janPath))
        {
            writeln("DEBUG: Loading Jan conversations from: ", janPath);
            loadFile(janPath);
            writeln("DEBUG: Jan conversations loaded");
        }
        else
        {
            showErrorMessage(
                "Jan conversations not found at: " ~ janPath ~ "\n\nMake sure Jan is installed and has conversation data.");
        }
    }

    private void checkForJanConversations()
    {
        import std.process : environment;
        import std.stdio : writeln;

        writeln("DEBUG: checkForJanConversations called");
        try
        {
            auto homeDir = environment.get("HOME");
            if (homeDir.length == 0)
            {
                writeln("DEBUG: No HOME directory found");
                return;
            }

            // List of common locations to check for conversations
            string[] conversationPaths = [
                buildPath(homeDir, ".local", "share", "Jan", "data", "conversations.json"),
                buildPath(homeDir, "Downloads", "conversations.json"),
                buildPath(homeDir, "Documents", "conversations.json"),
                buildPath(homeDir, "Desktop", "conversations.json"),
                buildPath(homeDir, "chatgpt-conversations.json"),
                buildPath(homeDir, "conversations.json")
            ];

            // Check each path in order of preference
            foreach (path; conversationPaths)
            {
                if (exists(path))
                {
                    writeln("Found conversations at: ", path);

                    // Load file in a try-catch to prevent crashes
                    try
                    {
                        writeln("DEBUG: About to load file");
                        loadFile(path);
                        writeln("DEBUG: File loaded successfully");

                        // Update sidebar to show the loaded file location - but be careful with UI updates
                        try
                        {
                            auto infoText = new TextWidget("loaded_info", toUTF32(
                                    "Loaded from: " ~ baseName(dirName(path))));
                            infoText.fontSize = 10;
                            infoText.textColor = 0xFF666666;
                            infoText.margins = Rect(0, 2, 0, 10);
                            writeln("DEBUG: Adding info text to sidebar");
                            _sidebar.insertChild(infoText, 2);
                        }
                        catch (Exception uiError)
                        {
                            writeln("DEBUG: Error updating UI: ", uiError.msg);
                        }

                        return; // Stop after loading the first found file
                    }
                    catch (Exception e)
                    {
                        writeln("Failed to load conversations from ", path, ": ", e.msg);
                        // Continue to next path
                    }
                }
            }

            // If no conversations found, show a hint
            writeln("No pre-existing conversations found in common locations");
        }
        catch (Exception e)
        {
            writeln("Error checking for Jan conversations: ", e.msg);
        }
    }

    private void loadConversationFile(string filename)
    {
        import std.stdio : writeln;

        try
        {
            if (!exists(filename))
            {
                showErrorMessage("File not found: " ~ filename);
                return;
            }

            auto jsonText = readText(filename);

            // Provide more detailed error information
            JSONValue jsonData;
            try
            {
                jsonData = parseJSON(jsonText);
            }
            catch (JSONException je)
            {
                showErrorMessage(
                    "Invalid JSON format in file: " ~ filename ~ "\nJSON Error: " ~ je.msg);
                return;
            }

            try
            {
                _conversation = new ChatGPTConversation(jsonData);
            }
            catch (Exception ce)
            {
                // Handle multi-conversation exports
                if (ce.msg == "MULTI_CONVERSATION_EXPORT")
                {
                    try
                    {
                        _conversationCollection = new ConversationCollection(jsonData);
                        _loadedFile = filename;
                        writeln("DEBUG: About to call populateConversationListFromCollection");
                        writeln("DEBUG: Collection has ", _conversationCollection.length, " conversations");
                        populateConversationListFromCollection();

                        // Start building search index in background
                        if (_conversationCollection.length > 100 && !_conversationCollection.isSearchReady)
                        {
                            writeln("DEBUG: Starting background search index building");
                            _searchIndexTimerId = setTimer(500); // Start after 500ms
                        }
                        writeln("DEBUG: populateConversationListFromCollection returned");
                        window.windowCaption = toUTF32(std.format.format("ChatGPT Viewer - %s (%d conversations)", baseName(
                                filename), _conversationCollection.length));
                        return;
                    }
                    catch (Exception collectionError)
                    {
                        showErrorMessage(
                            "Error loading conversation collection: " ~ collectionError.msg);
                        return;
                    }
                }

                string errorMsg = "Error parsing conversation data: " ~ ce.msg;

                // Add helpful hints based on the error
                if (ce.msg.canFind("expected object but got array"))
                {
                    errorMsg ~= "\n\nHint: This might be a new OpenAI export format. ";
                    errorMsg ~= "The parser has been updated to handle both formats.";
                }
                else if (ce.msg.canFind("missing 'mapping'"))
                {
                    errorMsg ~= "\n\nHint: This doesn't appear to be a ChatGPT conversation export. ";
                    errorMsg ~= "Expected fields: 'mapping', 'conversation', or 'messages'.";
                }

                showErrorMessage(errorMsg);
                return;
            }

            _loadedFile = filename;

            displayConversation();
            _infoPanel.updateInfo(_conversation);
            addConversationToList(filename);

            window.windowCaption = toUTF32("ChatGPT Viewer - " ~ baseName(filename));

        }
        catch (Exception e)
        {
            showErrorMessage("Unexpected error loading file: " ~ filename ~ "\nError: " ~ e.msg);
        }
    }

    private ConversationMessage[] _pendingMessages;
    private size_t _loadedMessageCount = 0;
    private const size_t _initialLoadCount = 10;
    private const size_t _batchLoadCount = 20;
    private ulong _loadTimerId = 0;

    private void displayConversation()
    {
        import std.stdio : writeln, writefln;

        writeln("DEBUG: displayConversation called");
        writefln("DEBUG: _conversation is null: %s", _conversation is null);
        writefln("DEBUG: _messageContainer is null: %s", _messageContainer is null);

        if (!_conversation)
        {
            writeln("DEBUG: No conversation to display - _conversation is null");
            return;
        }

        try
        {
            // Cancel any existing timer
            if (_loadTimerId)
            {
                cancelTimer(_loadTimerId);
                _loadTimerId = 0;
            }

            writeln("DEBUG: Clearing message container");
            _messageContainer.removeAllChildren();
            _loadedMessageCount = 0;

            auto messages = _conversation.getMessagesChronological();
            writefln("DEBUG: Got %d messages to display", messages.length);

            // Filter out empty messages
            ConversationMessage[] validMessages;
            foreach (msg; messages)
            {
                if (msg.content.getFullText().strip().length > 0)
                    validMessages ~= msg;
            }

            _pendingMessages = validMessages;
            writefln("!!!! LAZY LOADING ACTIVE: %d messages total", _pendingMessages.length);
            writefln("!!!! Will load %d initially, then %d at a time", _initialLoadCount, _batchLoadCount);

            // Load first batch immediately
            loadMessageBatch(_initialLoadCount);

            // Schedule background loading if there are more messages
            if (_pendingMessages.length > _initialLoadCount)
            {
                writefln("!!!! STARTING BACKGROUND LOADING TIMER");
                _loadTimerId = setTimer(100);
            }
        }
        catch (Exception e)
        {
            import std.stdio : writeln;

            writeln("Error displaying conversation: ", e.msg);
            showErrorMessage("Error displaying conversation: " ~ e.msg);
        }
    }

    private void loadMessageBatch(size_t count)
    {
        import std.algorithm : min;
        import std.stdio : writefln;

        size_t toLoad = min(count, _pendingMessages.length - _loadedMessageCount);
        size_t endIndex = _loadedMessageCount + toLoad;

        writefln("DEBUG: Loading messages %d to %d", _loadedMessageCount, endIndex);

        for (size_t i = _loadedMessageCount; i < endIndex; i++)
        {
            auto msg = _pendingMessages[i];
            auto messageType = determineMessageType(msg);
            auto messageWidget = new EnhancedMessageWidget(msg, messageType);
            _messageContainer.addChild(messageWidget);
        }

        _loadedMessageCount = endIndex;

        // Add loading indicator if there are more messages
        if (_loadedMessageCount < _pendingMessages.length)
        {
            auto loadingText = new TextWidget("loading_more",
                toUTF32(format("Loading %d more messages...",
                    _pendingMessages.length - _loadedMessageCount)));
            loadingText.id = "loading_indicator";
            loadingText.fontSize = 10;
            loadingText.textColor = 0xFF888888;
            loadingText.alignment = Align.Center;
            loadingText.margins = Rect(0, 10, 0, 10);
            _messageContainer.addChild(loadingText);
        }
    }

    override bool onTimer(ulong id)
    {
        if (id == _searchIndexTimerId)
        {
            _searchIndexTimerId = 0;
            if (_conversationCollection && !_conversationCollection.isSearchReady)
            {
                import std.stdio : writeln;
                writeln("DEBUG: Building search index in background...");
                _conversationCollection.buildSearchIndexAsync();
                writeln("DEBUG: Search index ready!");

                // Update search box placeholder to indicate search is ready
                // Note: EditLine doesn't have a hint/placeholder property in current dlangui
                // Could show a status message instead if needed
            }
            return false;
        }
        else if (id == _searchTimerId)
        {
            _searchTimerId = 0;
            performSearch();
            return false;
        }
        else if (id == _loadTimerId && _loadedMessageCount < _pendingMessages.length)
        {
            // Remove loading indicator if present
            auto loadingIndicator = _messageContainer.childById("loading_indicator");
            if (loadingIndicator)
                _messageContainer.removeChild(loadingIndicator);

            // Load next batch
            loadMessageBatch(_batchLoadCount);

            // Continue timer if there are more messages
            if (_loadedMessageCount < _pendingMessages.length)
            {
                return true; // Continue timer
            }
            else
            {
                _loadTimerId = 0;
                return false; // Stop timer
            }
        }
        return super.onTimer(id);
    }

    private MessageType determineMessageType(const ConversationMessage msg)
    {
        auto content = msg.content.getFullText().toLower();

        if (msg.author.role == "user")
        {
            return MessageType.User;
        }
        else if (msg.author.role == "system")
        {
            return MessageType.System;
        }
        else if (msg.author.role == "assistant")
        {
            // Check for tool calls or RAG context
            if (content.canFind("function_call") || content.canFind("tool_call"))
            {
                return MessageType.ToolCall;
            }
            else if (content.canFind("retrieved") || content.canFind("search results"))
            {
                return MessageType.RAGContext;
            }
            else
            {
                return MessageType.Assistant;
            }
        }

        return MessageType.Assistant;
    }

    private void addConversationToList(string filePath)
    {
        // With virtual list, we don't add items directly
        // File-based conversations should be converted to ConversationCollection format
        // For now, just refresh if we have a list
        if (_conversationList)
            _conversationList.refresh();
    }

    private void toggleMessageSearch()
    {
        // Implementation for advanced message search
        // This would show/hide an advanced search interface
    }

    private void clearConversation()
    {
        _conversation = null;
        _conversationCollection = null;
        _loadedFile = "";
        _currentPage = 0;
        showWelcomeMessage();
        _infoPanel.updateInfo(null);

        // Clear conversation list by resetting item count
        if (_conversationList)
        {
            _conversationList.setItemCount(0);
            _conversationList.refresh();
        }
        _paginationControls.visibility = Visibility.Gone;
    }

    private void exportToText()
    {
        if (!_conversation)
        {
            showErrorMessage("No conversation loaded to export");
            return;
        }

        auto dlg = new FileDialog(UIString.fromRaw("Export Conversation"d), window, null, FileDialogFlag
                .Save);
        dlg.dialogResult = (Dialog d, const Action result) {
            if (result.id == ACTION_SAVE.id)
            {
                auto path = dlg.filename;
                try
                {
                    auto textContent = _conversation.exportToText();
                    write(path, textContent);
                    showInfoMessage("Conversation exported successfully to: " ~ path);
                }
                catch (Exception e)
                {
                    showErrorMessage("Error exporting file: " ~ e.msg);
                }
            }
        };
        dlg.show();
    }

    private void showErrorMessage(string message)
    {
        window.showMessageBox(UIString.fromRaw("Error"d), UIString.fromRaw(toUTF32(message)));
    }

    private void showInfoMessage(string message)
    {
        window.showMessageBox(UIString.fromRaw("Info"d), UIString.fromRaw(toUTF32(message)));
    }

    void loadFile(string filename)
    {
        if (filename.length > 0)
        {
            loadConversationFile(filename);
        }
    }

    private void populateConversationListFromCollection()
    {
        import std.stdio : writeln, writefln;

        writeln("DEBUG: populateConversationListFromCollection called");
        if (!_conversationCollection)
        {
            writeln("DEBUG: No conversation collection");
            return;
        }

        size_t totalConversations = _conversationCollection.length;
        writefln("DEBUG: Total conversations: %d", totalConversations);

        // Set up the virtual list with the total count
        _conversationList.setItemCount(totalConversations);

        // Create the item builder delegate that will create items on demand
        _conversationList.setItemBuilder((size_t index) {
            writefln("DEBUG: Building item for index %d", index);

            try {
                writefln("DEBUG: Getting conversation info for index %d", index);
                auto info = _conversationCollection.getConversationInfo(index);
                writefln("DEBUG: Got info - title: %s, messages: %d",
                        info.title.length > 50 ? info.title[0..50] ~ "..." : info.title,
                        info.messageCount);

                // Create a ConversationListItem for better UI
                writefln("DEBUG: Creating ConversationListItem widget");
                auto listItem = new ConversationListItem(info, index);
                writefln("DEBUG: ConversationListItem created successfully");

                // Set up click handler
                writefln("DEBUG: Setting up click handler for item %d", index);
                listItem.click = delegate(Widget w) {
                    writefln("!!!! CLICK DETECTED: Index %d", index);
                    selectConversationFromCollection(cast(int) index);
                    return true;
                };
                writefln("DEBUG: Click handler attached");

                writefln("DEBUG: Returning widget for index %d", index);
                return cast(Widget) listItem;
            }
            catch (Exception e) {
                writefln("ERROR: Failed to create item for index %d: %s", index, e.msg);

                // Return a fallback widget
                auto errorItem = new TextWidget(null, toUTF32(format("Error loading item %d", index)));
                errorItem.layoutWidth = FILL_PARENT;
                errorItem.layoutHeight = 72;
                errorItem.textColor = 0xFFFF0000;
                return cast(Widget) errorItem;
            }
        });

        // Refresh the virtual list to show items
        _conversationList.refresh();

        writeln("DEBUG: Virtual list configured with item builder");
        writeln("DEBUG: Virtual list will render items on demand as user scrolls");

        // Show pagination info (but virtual list handles actual display)
        if (totalConversations > 100)
        {
            writefln("INFO: Large collection (%d items) - using virtual scrolling for performance", totalConversations);
        }

        _sidebar.requestLayout();
        _sidebar.invalidate();
        _sidebar.measure(SIZE_UNSPECIFIED, SIZE_UNSPECIFIED);

        // Force the entire window to redraw
        if (window !is null)
        {
            window.invalidate();
            window.update();
            window.requestLayout();
        }

        writeln("DEBUG: Requested layout updates and invalidation");
    }

    private void selectConversationFromCollection(int index)
    {
        import std.stdio : writeln, writefln;

        writefln("DEBUG: selectConversationFromCollection called with index: %d", index);
        writefln("DEBUG: Collection exists: %s, Collection length: %d",
            _conversationCollection !is null,
            _conversationCollection ? _conversationCollection.length : 0);

        if (!_conversationCollection || index < 0 || index >= _conversationCollection.length)
        {
            writefln("ERROR: Invalid conversation index %d (collection length: %d)",
                index, _conversationCollection ? _conversationCollection.length : 0);
            return;
        }

        try
        {
            writefln("DEBUG: Loading conversation at index %d", index);

            // Load the selected conversation
            _conversation = _conversationCollection.loadConversation(index);
            writefln("DEBUG: Conversation loaded successfully: %s", _conversation !is null);

            if (_conversation)
            {
                writeln("DEBUG: About to display conversation");
            }

            // Display the conversation (displayConversation already clears messages)
            displayConversation();
            _infoPanel.updateInfo(_conversation);

            writeln("DEBUG: Conversation displayed successfully");

            // Since we're using buttons now, we don't need the selection logic
            // The button will handle its own visual state

            auto info = _conversationCollection.getConversationInfo(index);
            window.windowCaption = toUTF32(std.format.format("ChatGPT Viewer - %s (%d/%d)",
                    info.title.length > 50 ? info.title[0 .. 47] ~ "..." : info.title,
                    index + 1, _conversationCollection.length));

        }
        catch (Exception e)
        {
            import std.stdio : writeln;

            writeln("Error loading conversation at index ", index, ": ", e.msg);
            showErrorMessage("Error loading conversation: " ~ e.msg);
        }
    }

    private bool onPreviousPage(Widget source)
    {
        if (_showingSearchResults)
        {
            return true; // No pagination for search results
        }

        if (_currentPage > 0)
        {
            _currentPage--;
            populateConversationListFromCollection();
        }
        return true;
    }

    private bool onNextPage(Widget source)
    {
        if (_showingSearchResults)
        {
            return true; // No pagination for search results
        }

        if (!_conversationCollection)
            return true;

        size_t totalPages = (_conversationCollection.length + _conversationsPerPage - 1) / _conversationsPerPage;
        if (_currentPage < totalPages - 1)
        {
            _currentPage++;
            populateConversationListFromCollection();
        }
        return true;
    }

    private void onSearchTextChanged()
    {
        import std.stdio : writeln;

        // Cancel previous search timer
        if (_searchTimerId)
        {
            cancelTimer(_searchTimerId);
            _searchTimerId = 0;
        }

        // Start new search timer (debounce)
        if (_searchBox.text.length > 0)
        {
            _searchTimerId = setTimer(300); // 300ms debounce
        }
        else
        {
            // Clear search results if search box is empty
            clearSearchResults();
        }
    }

    private void performSearch()
    {
        import std.stdio : writeln, writefln;
        import std.conv : to;

        if (!_conversationCollection || _searchBox.text.length == 0)
        {
            clearSearchResults();
            return;
        }

        string searchQuery = to!string(_searchBox.text);
        writefln("DEBUG: Searching for: %s", searchQuery);

        // Check if search index is ready
        if (!_conversationCollection.isSearchReady)
        {
            writeln("DEBUG: Search index not ready yet, building now...");
            _conversationCollection.buildSearchIndexAsync();
        }

        // Perform search
        _searchResults = _conversationCollection.searchConversations(searchQuery, 100);
        writefln("DEBUG: Found %d results", _searchResults.length);

        // Display search results
        displaySearchResults();
    }

    private void displaySearchResults()
    {
        import std.stdio : writeln, writefln;
        import std.format : format;
        import std.conv : to;

        _showingSearchResults = true;

        // Configure virtual list for search results

        // Hide pagination for search results
        if (_prevPageButton)
            _prevPageButton.visibility = Visibility.Gone;
        if (_nextPageButton)
            _nextPageButton.visibility = Visibility.Gone;
        if (_pageInfo)
            _pageInfo.visibility = Visibility.Gone;

        if (_searchResults.length == 0)
        {
            // Set item count to 1 to show "no results" message
            _conversationList.setItemCount(1);
            _conversationList.setItemBuilder((size_t index) {
                auto noResults = new TextWidget("no_results", toUTF32("No conversations found"));
                noResults.fontSize = 12;
                noResults.textColor = 0xFF666666;
                noResults.alignment = Align.Center;
                noResults.margins = Rect(10, 20, 10, 20);
                noResults.layoutWidth = FILL_PARENT;
                noResults.layoutHeight = 72;
                return cast(Widget) noResults;
            });
        }
        else
        {
            // Configure virtual list for search results
            _conversationList.setItemCount(_searchResults.length);
            _conversationList.setItemBuilder((size_t index) {
                if (index >= _searchResults.length)
                    return null;

                size_t convIndex = _searchResults[index];
                try {
                    auto info = _conversationCollection.getConversationInfo(convIndex);

                    // Create a ConversationListItem with search highlight
                    auto listItem = new ConversationListItem(info, convIndex);

                    // Set up click handler
                    listItem.click = delegate(Widget w) {
                        writefln("DEBUG: Search result clicked: %d", convIndex);
                        selectConversationFromCollection(cast(int) convIndex);
                        return true;
                    };

                    return cast(Widget) listItem;
                }
                catch (Exception e) {
                    writefln("DEBUG: Error creating search result %d: %s", convIndex, e.msg);
                    return null;
                }
            });
        }

        // Refresh the virtual list
        _conversationList.refresh();
    }

    private void clearSearchResults()
    {
        import std.stdio : writeln;

        if (_showingSearchResults)
        {
            writeln("DEBUG: Clearing search results");
            _showingSearchResults = false;
            _searchResults = [];

            // Restore normal conversation list
            populateConversationListFromCollection();
        }
    }

    private void updatePaginationControls(size_t totalConversations)
    {
        size_t totalPages = (totalConversations + _conversationsPerPage - 1) / _conversationsPerPage;

        // Store references to pagination controls if not already stored
        if (!_pageInfo)
            _pageInfo = cast(TextWidget) _paginationControls.childById("pageInfo");
        if (!_prevPageButton)
            _prevPageButton = cast(Button) _paginationControls.childById("btnPrev");
        if (!_nextPageButton)
            _nextPageButton = cast(Button) _paginationControls.childById("btnNext");

        if (_pageInfo)
        {
            _pageInfo.text = toUTF32(std.format.format("Page %d of %d (%d conversations)",
                    _currentPage + 1, totalPages, totalConversations));
        }

        if (_prevPageButton)
        {
            _prevPageButton.enabled = _currentPage > 0;
        }

        if (_nextPageButton)
        {
            _nextPageButton.enabled = _currentPage < totalPages - 1;
        }
    }
}

string capitalize(string str)
{
    if (str.length == 0)
        return str;
    return str[0 .. 1].toUpper() ~ str[1 .. $].toLower();
}
