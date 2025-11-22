module dowel.themes.modern_dark;

import dlangui;
import dlangui.widgets.styles;
import dlangui.core.types;
import dlangui.platforms.common.platform;

/// Modern dark theme for Dowel-Steek desktop environment
class ModernDarkTheme
{
    // Color palette
    enum Colors : uint
    {
        // Background colors
        Primary = 0xFF1E1E1E, // Main background
        Secondary = 0xFF2D2D2D, // Panels, cards
        Surface = 0xFF3A3A3A, // Elevated surfaces
        Border = 0xFF4A4A4A, // Borders and dividers

        // Text colors
        TextPrimary = 0xFFE8E8E8, // Main text
        TextSecondary = 0xFFB8B8B8, // Secondary text
        TextDisabled = 0xFF808080, // Disabled text

        // Accent colors
        Accent = 0xFF0078D4, // Primary accent (blue)
        AccentHover = 0xFF106EBE, // Accent hover state
        AccentPressed = 0xFF005A9E, // Accent pressed state

        // Status colors
        Success = 0xFF107C10, // Green
        Warning = 0xFFFFB900, // Yellow
        Error = 0xFFD13438, // Red
        Info = 0xFF0078D4, // Blue

        // Window decoration
        TitleBarActive = 0xFF2D2D2D,
        TitleBarInactive = 0xFF1E1E1E,
        WindowBorder = 0xFF4A4A4A,

        // Desktop
        DesktopBackground = 0xFF0F0F0F,
        PanelBackground = 0xFF1E1E1E,

        // Transparency
        Overlay = 0x80000000, // Semi-transparent overlay
    }

    static void apply()
    {
        // Create theme
        auto theme = new Theme("modern_dark");

        // Base widget style
        auto baseStyle = theme.createSubstyle("WIDGET");
        baseStyle.backgroundColor = Colors.Primary;
        baseStyle.textColor = Colors.TextPrimary;
        baseStyle.fontSize = 11;
        baseStyle.fontFamily = FontFamily.SansSerif;
        baseStyle.fontFace = "Segoe UI";

        // Button styles
        setupButtonStyles(theme);

        // Text styles
        setupTextStyles(theme);

        // Panel styles
        setupPanelStyles(theme);

        // Window styles
        setupWindowStyles(theme);

        // List and grid styles
        setupListStyles(theme);

        // Input styles
        setupInputStyles(theme);

        // Apply theme
        currentTheme = theme;
        Platform.instance.uiTheme = "modern_dark";
    }

    private static void setupButtonStyles(Theme theme)
    {
        // Primary button
        auto button = theme.createSubstyle(STYLE_BUTTON);
        button.backgroundColor = Colors.Accent;
        button.textColor = 0xFFFFFFFF;
        button.fontSize = 11;
        button.padding = Rect(12, 8, 12, 8);
        button.margins = Rect(2, 2, 2, 2);
        button.minWidth = 80;
        button.minHeight = 32;

        // Button hover state
        auto buttonHover = button.createState(State.Hovered);
        buttonHover.backgroundColor = Colors.AccentHover;

        // Button pressed state
        auto buttonPressed = button.createState(State.Pressed);
        buttonPressed.backgroundColor = Colors.AccentPressed;

        // Button disabled state
        auto buttonDisabled = button.createState(State.Normal);
        buttonDisabled.backgroundColor = Colors.Border;
        buttonDisabled.textColor = Colors.TextDisabled;
    }

    private static void setupTextStyles(Theme theme)
    {
        // Regular text
        auto text = theme.createSubstyle(STYLE_TEXT);
        text.textColor = Colors.TextPrimary;
        text.fontSize = 11;

        // Secondary text
        auto textSecondary = theme.createSubstyle("TEXT_SECONDARY");
        textSecondary.textColor = Colors.TextSecondary;
        textSecondary.fontSize = 10;

        // Heading styles
        auto heading1 = theme.createSubstyle("HEADING_1");
        heading1.textColor = Colors.TextPrimary;
        heading1.fontSize = 16;
        heading1.fontWeight = 600;

        auto heading2 = theme.createSubstyle("HEADING_2");
        heading2.textColor = Colors.TextPrimary;
        heading2.fontSize = 14;
        heading2.fontWeight = 500;
    }

    private static void setupPanelStyles(Theme theme)
    {
        // Panel background
        auto panel = theme.createSubstyle("PANEL");
        panel.backgroundColor = Colors.Secondary;
        panel.padding = Rect(8, 8, 8, 8);

        // Toolbar
        auto toolbar = theme.createSubstyle("TOOLBAR");
        toolbar.backgroundColor = Colors.PanelBackground;
        toolbar.minHeight = 40;
        toolbar.padding = Rect(8, 4, 8, 4);

        // Status bar
        auto statusBar = theme.createSubstyle(STYLE_STATUS_LINE);
        statusBar.backgroundColor = Colors.PanelBackground;
        statusBar.textColor = Colors.TextSecondary;
        statusBar.fontSize = 10;
        statusBar.minHeight = 24;
        statusBar.padding = Rect(8, 2, 8, 2);
    }

    private static void setupWindowStyles(Theme theme)
    {
        // Window title bar
        auto titleBar = theme.createSubstyle("WINDOW_TITLE_BAR");
        titleBar.backgroundColor = Colors.TitleBarActive;
        titleBar.textColor = Colors.TextPrimary;
        titleBar.fontSize = 11;
        titleBar.minHeight = 32;
        titleBar.padding = Rect(8, 4, 8, 4);

        // Window title bar inactive
        auto titleBarInactive = titleBar.createState(State.Normal);
        titleBarInactive.backgroundColor = Colors.TitleBarInactive;
        titleBarInactive.textColor = Colors.TextSecondary;

        // Window content area
        auto windowContent = theme.createSubstyle("WINDOW_CONTENT");
        windowContent.backgroundColor = Colors.Primary;
        windowContent.padding = Rect(1, 1, 1, 1);
    }

    private static void setupListStyles(Theme theme)
    {
        // List box
        auto listBox = theme.createSubstyle(STYLE_LIST_BOX);
        listBox.backgroundColor = Colors.Secondary;
        listBox.textColor = Colors.TextPrimary;
        listBox.fontSize = 11;
        listBox.padding = Rect(2, 2, 2, 2);

        // List item
        auto listItem = theme.createSubstyle(STYLE_LIST_ITEM);
        listItem.textColor = Colors.TextPrimary;
        listItem.fontSize = 11;
        listItem.minHeight = 24;
        listItem.padding = Rect(8, 4, 8, 4);

        // Selected list item
        auto listItemSelected = listItem.createState(State.Selected);
        listItemSelected.backgroundColor = Colors.Accent;
        listItemSelected.textColor = 0xFFFFFFFF;

        // Hovered list item
        auto listItemHovered = listItem.createState(State.Hovered);
        listItemHovered.backgroundColor = Colors.Surface;

        // Grid
        auto grid = theme.createSubstyle(STYLE_STRING_GRID);
        grid.backgroundColor = Colors.Secondary;
        grid.textColor = Colors.TextPrimary;
        grid.fontSize = 11;
        grid.padding = Rect(1, 1, 1, 1);
    }

    private static void setupInputStyles(Theme theme)
    {
        // Edit line (single line input)
        auto editLine = theme.createSubstyle(STYLE_EDIT_LINE);
        editLine.backgroundColor = Colors.Surface;
        editLine.textColor = Colors.TextPrimary;
        editLine.fontSize = 11;
        editLine.minHeight = 32;
        editLine.padding = Rect(8, 6, 8, 6);
        editLine.margins = Rect(2, 2, 2, 2);

        // Focused edit line
        auto editLineFocused = editLine.createState(State.Focused);
        editLineFocused.backgroundColor = Colors.Surface;

        // Edit box (multi-line input)
        auto editBox = theme.createSubstyle(STYLE_EDIT_BOX);
        editBox.backgroundColor = Colors.Surface;
        editBox.textColor = Colors.TextPrimary;
        editBox.fontSize = 11;
        editBox.padding = Rect(8, 6, 8, 6);
        editBox.margins = Rect(2, 2, 2, 2);

        // Checkbox
        auto checkbox = theme.createSubstyle(STYLE_CHECKBOX);
        checkbox.textColor = Colors.TextPrimary;
        checkbox.fontSize = 11;
        checkbox.minHeight = 24;
        checkbox.padding = Rect(4, 2, 4, 2);
    }
}

// Utility functions for getting theme colors
uint getThemeColor(string colorName)
{
    switch (colorName)
    {
    case "primary":
        return ModernDarkTheme.Colors.Primary;
    case "secondary":
        return ModernDarkTheme.Colors.Secondary;
    case "surface":
        return ModernDarkTheme.Colors.Surface;
    case "accent":
        return ModernDarkTheme.Colors.Accent;
    case "text":
        return ModernDarkTheme.Colors.TextPrimary;
    case "text-secondary":
        return ModernDarkTheme.Colors.TextSecondary;
    case "success":
        return ModernDarkTheme.Colors.Success;
    case "warning":
        return ModernDarkTheme.Colors.Warning;
    case "error":
        return ModernDarkTheme.Colors.Error;
    default:
        return ModernDarkTheme.Colors.Primary;
    }
}
