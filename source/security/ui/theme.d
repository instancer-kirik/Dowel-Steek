module security.ui.theme;

import std.stdio;
import std.conv;
import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.styles;
import security.models;
import std.algorithm : min;

/// Theme modes
enum ThemeMode
{
    Light,
    Dark,
    Auto  // System preference
}

/// Color palette for themes
struct ColorPalette
{
    // Primary colors
    uint primary;
    uint primaryVariant;
    uint secondary;
    uint secondaryVariant;

    // Background colors
    uint background;
    uint surface;
    uint surfaceVariant;

    // Text colors
    uint onBackground;
    uint onSurface;
    uint onPrimary;
    uint onSecondary;

    // Semantic colors
    uint success;
    uint warning;
    uint error;
    uint info;

    // Interactive colors
    uint hover;
    uint pressed;
    uint disabled;
    uint divider;

    // Security level colors
    uint securityCritical;
    uint securityHigh;
    uint securityMedium;
    uint securityLow;

    // Password strength colors
    uint strengthVeryWeak;
    uint strengthWeak;
    uint strengthFair;
    uint strengthStrong;
    uint strengthVeryStrong;
}

/// Modern Security App Theme Manager
class SecurityTheme
{
    private static SecurityTheme _instance;
    private ThemeMode _currentMode = ThemeMode.Light;
    private ColorPalette _lightPalette;
    private ColorPalette _darkPalette;

    /// Singleton instance
    static SecurityTheme instance()
    {
        if (_instance is null)
            _instance = new SecurityTheme();
        return _instance;
    }

    private this()
    {
        initializePalettes();
    }

    /// Initialize color palettes
    private void initializePalettes()
    {
        // Light theme palette
        _lightPalette = ColorPalette(
            // Primary colors
            primary: 0xFF1976D2,           // Material Blue 700
            primaryVariant: 0xFF1565C0,    // Material Blue 800
            secondary: 0xFF0D47A1,         // Material Blue 900
            secondaryVariant: 0xFF01579B,  // Material Blue A700

            // Background colors
            background: 0xFFFAFAFA,        // Almost white
            surface: 0xFFFFFFFF,           // Pure white
            surfaceVariant: 0xFFF5F5F5,    // Light gray

            // Text colors
            onBackground: 0xFF212121,      // Dark gray
            onSurface: 0xFF424242,         // Medium gray
            onPrimary: 0xFFFFFFFF,         // White
            onSecondary: 0xFFFFFFFF,       // White

            // Semantic colors
            success: 0xFF4CAF50,           // Green 500
            warning: 0xFFFF9800,           // Orange 500
            error: 0xFFF44336,             // Red 500
            info: 0xFF2196F3,              // Blue 500

            // Interactive colors
            hover: 0xFFE3F2FD,             // Blue 50
            pressed: 0xFFBBDEFB,           // Blue 100
            disabled: 0xFF9E9E9E,          // Gray 500
            divider: 0xFFE0E0E0,           // Gray 300

            // Security level colors
            securityCritical: 0xFFD32F2F,  // Red 700
            securityHigh: 0xFFFF5722,      // Deep Orange 500
            securityMedium: 0xFFFF9800,    // Orange 500
            securityLow: 0xFF4CAF50,       // Green 500

            // Password strength colors
            strengthVeryWeak: 0xFFF44336,   // Red 500
            strengthWeak: 0xFFFF5722,       // Deep Orange 500
            strengthFair: 0xFFFF9800,       // Orange 500
            strengthStrong: 0xFF8BC34A,     // Light Green 500
            strengthVeryStrong: 0xFF4CAF50  // Green 500
        );

        // Dark theme palette
        _darkPalette = ColorPalette(
            // Primary colors
            primary: 0xFF90CAF9,           // Blue 200
            primaryVariant: 0xFF64B5F6,    // Blue 300
            secondary: 0xFF42A5F5,         // Blue 400
            secondaryVariant: 0xFF2196F3,  // Blue 500

            // Background colors
            background: 0xFF121212,        // Dark background
            surface: 0xFF1E1E1E,           // Dark surface
            surfaceVariant: 0xFF2D2D2D,    // Lighter dark

            // Text colors
            onBackground: 0xFFFFFFFF,      // White
            onSurface: 0xFFE0E0E0,         // Light gray
            onPrimary: 0xFF000000,         // Black
            onSecondary: 0xFF000000,       // Black

            // Semantic colors
            success: 0xFF66BB6A,           // Green 400
            warning: 0xFFFFB74D,           // Orange 300
            error: 0xFFEF5350,             // Red 400
            info: 0xFF42A5F5,              // Blue 400

            // Interactive colors
            hover: 0xFF1565C0,             // Blue 800
            pressed: 0xFF0D47A1,           // Blue 900
            disabled: 0xFF616161,          // Gray 700
            divider: 0xFF424242,           // Gray 800

            // Security level colors
            securityCritical: 0xFFEF5350,  // Red 400
            securityHigh: 0xFFFF7043,      // Deep Orange 400
            securityMedium: 0xFFFFB74D,    // Orange 300
            securityLow: 0xFF66BB6A,       // Green 400

            // Password strength colors
            strengthVeryWeak: 0xFFEF5350,   // Red 400
            strengthWeak: 0xFFFF7043,       // Deep Orange 400
            strengthFair: 0xFFFFB74D,       // Orange 300
            strengthStrong: 0xFF9CCC65,     // Light Green 400
            strengthVeryStrong: 0xFF66BB6A  // Green 400
        );
    }

    /// Get current theme mode
    ThemeMode getMode() const
    {
        return _currentMode;
    }

    /// Set theme mode
    void setMode(ThemeMode mode)
    {
        _currentMode = mode;
        applyTheme();
    }

    /// Get current color palette
    ColorPalette getCurrentPalette() const
    {
        final switch (_currentMode)
        {
            case ThemeMode.Light:
                return _lightPalette;
            case ThemeMode.Dark:
                return _darkPalette;
            case ThemeMode.Auto:
                // For now, default to light
                return _lightPalette;
        }
    }

    /// Apply current theme to the application
    void applyTheme()
    {
        auto palette = getCurrentPalette();

        // Apply DlangUI theme
        auto theme = currentTheme;
        if (theme)
        {
            // Background colors
            theme.backgroundColor = palette.background;
            // theme.windowBackgroundColor = palette.background; // Not available in this DlangUI version

            // Text colors
            theme.textColor = palette.onBackground;
            // theme.windowBackgroundColor = palette.background; // Not available in this DlangUI version

            // Update all widget styles
            updateWidgetStyles(palette);
        }
    }

    /// Update widget styles with current palette
    private void updateWidgetStyles(ColorPalette palette)
    {
        auto theme = currentTheme;
        if (!theme) return;

        // Button styles
        // Custom styling would need different approach in this DlangUI version
        // theme.customizeButtonStyle("primary-button", delegate(Style style) {
        //     style.backgroundColor = palette.primary;
        //     style.textColor = palette.onPrimary;
        //     style.borderColor = palette.primary;
        // });

        // theme.customizeButtonStyle("secondary-button", delegate(Style style) {
        //     style.backgroundColor = palette.surface;
        //     style.textColor = palette.primary;
        //     style.borderColor = palette.primary;
        // });

        // theme.customizeButtonStyle("danger-button", delegate(Style style) {
        //     style.backgroundColor = palette.error;
        //     style.textColor = 0xFFFFFFFF;
        //     style.borderColor = palette.error;
        // });

        // Input styles
        // theme.customizeEditLineStyle("primary-input", delegate(Style style) {
        //     style.backgroundColor = palette.surface;
        //     style.textColor = palette.onSurface;
        //     style.borderColor = palette.divider;
        // });

        // Card styles
        // theme.customizeLayoutStyle("card", delegate(Style style) {
        //     style.backgroundColor = palette.surface;
        //     style.borderColor = palette.divider;
        // });

        // Security level styles
        // theme.customizeLayoutStyle("security-critical", delegate(Style style) {
        //     style.backgroundColor = palette.securityCritical;
        //     style.textColor = 0xFFFFFFFF;
        // });

        // theme.customizeLayoutStyle("security-high", delegate(Style style) {
        //     style.backgroundColor = palette.securityHigh;
        //     style.textColor = 0xFFFFFFFF;
        // });

        // theme.customizeLayoutStyle("security-medium", delegate(Style style) {
        //     style.backgroundColor = palette.securityMedium;
        //     style.textColor = 0xFFFFFFFF;
        // });

        // theme.customizeLayoutStyle("security-low", delegate(Style style) {
        //     style.backgroundColor = palette.securityLow;
        //     style.textColor = 0xFFFFFFFF;
        // });
    }

    /// Create styled button
    Button createStyledButton(string id, dstring text, string styleClass = "primary-button")
    {
        auto button = new Button(id, text);
        button.styleId = styleClass;
        return button;
    }

    /// Create styled edit line
    EditLine createStyledEditLine(string id, string styleClass = "primary-input")
    {
        auto editLine = new EditLine(id);
        editLine.styleId = styleClass;
        return editLine;
    }

    /// Create card layout
    VerticalLayout createCard(string id = null)
    {
        auto layout = new VerticalLayout(id);
        layout.styleId = "card";
        layout.padding = Rect(16, 16, 16, 16);
        layout.margins = Rect(8, 8, 8, 8);
        return layout;
    }

    /// Create security level indicator
    Widget createSecurityLevelIndicator(SecurityLevel level)
    {
        import security.models : SecurityLevel;

        auto indicator = new TextWidget(null, getSecurityLevelText(level));
        indicator.fontSize = 12;

        string styleClass;
        final switch (level)
        {
            case SecurityLevel.Critical:
                styleClass = "security-critical";
                break;
            case SecurityLevel.High:
                styleClass = "security-high";
                break;
            case SecurityLevel.Medium:
                styleClass = "security-medium";
                break;
            case SecurityLevel.Low:
                styleClass = "security-low";
                break;
        }

        indicator.styleId = styleClass;
        indicator.padding = Rect(8, 4, 8, 4);
        return indicator;
    }

    /// Create password strength indicator
    Widget createPasswordStrengthIndicator(uint score, string level)
    {
        auto layout = new HorizontalLayout();
        layout.layoutWidth = WRAP_CONTENT;
        layout.layoutHeight = WRAP_CONTENT;

        // Progress bar
        auto progressBar = new ProgressBarWidget();
        progressBar.progress = score;
        progressBar.layoutWidth = 100;
        progressBar.layoutHeight = 6;

        uint color;
        if (score >= 80) color = getCurrentPalette().strengthVeryStrong;
        else if (score >= 60) color = getCurrentPalette().strengthStrong;
        else if (score >= 40) color = getCurrentPalette().strengthFair;
        else if (score >= 20) color = getCurrentPalette().strengthWeak;
        else color = getCurrentPalette().strengthVeryWeak;

        progressBar.backgroundColor = color;
        layout.addChild(progressBar);

        // Level text
        auto levelText = new TextWidget(null, level.to!dstring);
        levelText.fontSize = 12;
        levelText.textColor = color;
        levelText.margins = Rect(8, 0, 0, 0);
        layout.addChild(levelText);

        return layout;
    }

    /// Create TOTP progress indicator
    Widget createTOTPProgressIndicator(uint timeRemaining, uint period)
    {
        auto layout = new HorizontalLayout();
        layout.layoutWidth = FILL_PARENT;
        layout.layoutHeight = WRAP_CONTENT;

        // Circular progress (simplified as linear for now)
        auto progressBar = new ProgressBarWidget();
        progressBar.progress = (timeRemaining * 100) / period;
        progressBar.layoutWidth = 40;
        progressBar.layoutHeight = 6;

        uint color;
        if (timeRemaining > period / 2) color = getCurrentPalette().success;
        else if (timeRemaining > period / 4) color = getCurrentPalette().warning;
        else color = getCurrentPalette().error;

        progressBar.backgroundColor = color;
        layout.addChild(progressBar);

        // Time text
        auto timeText = new TextWidget(null, (timeRemaining.to!string ~ "s").to!dstring);
        timeText.fontSize = 10;
        timeText.textColor = getCurrentPalette().onSurface;
        timeText.margins = Rect(8, 0, 0, 0);
        layout.addChild(timeText);

        return layout;
    }

    /// Create icon button (using text for now, icons can be added later)
    Button createIconButton(string id, dstring icon, dstring tooltip = "")
    {
        auto button = new Button(id, icon);
        button.styleId = "icon-button";
        button.layoutWidth = 40;
        button.layoutHeight = 40;
        if (tooltip.length > 0)
            button.tooltipText = tooltip;
        return button;
    }

    /// Create search box
    EditLine createSearchBox(string id)
    {
        auto searchBox = createStyledEditLine(id, "search-input");
        searchBox.text = "Search..."d;
        searchBox.layoutWidth = FILL_PARENT;
        return searchBox;
    }

    /// Create tab with modern styling
    Widget createStyledTab(string id, dstring title, Widget content)
    {
        auto tab = new VerticalLayout(id);
        tab.layoutWidth = FILL_PARENT;
        tab.layoutHeight = FILL_PARENT;
        tab.padding = Rect(16, 16, 16, 16);

        // Tab header
        auto header = new TextWidget(null, title);
        header.fontSize = 18;
        header.fontWeight = 600;
        header.textColor = getCurrentPalette().primary;
        header.margins = Rect(0, 0, 0, 16);
        tab.addChild(header);

        // Tab content
        tab.addChild(content);

        return tab;
    }

    /// Get colors for various UI elements
    uint getPrimaryColor() const { return getCurrentPalette().primary; }
    uint getBackgroundColor() const { return getCurrentPalette().background; }
    uint getSurfaceColor() const { return getCurrentPalette().surface; }
    uint getTextColor() const { return getCurrentPalette().onSurface; }
    uint getErrorColor() const { return getCurrentPalette().error; }
    uint getSuccessColor() const { return getCurrentPalette().success; }
    uint getWarningColor() const { return getCurrentPalette().warning; }

    /// Helper to get security level text
    private dstring getSecurityLevelText(SecurityLevel level)
    {
        import security.models : SecurityLevel;

        final switch (level)
        {
            case SecurityLevel.Critical: return "CRITICAL"d;
            case SecurityLevel.High: return "HIGH"d;
            case SecurityLevel.Medium: return "MEDIUM"d;
            case SecurityLevel.Low: return "LOW"d;
        }
    }
}

/// Simple progress bar widget (if not available in DlangUI)
class ProgressBarWidget : Widget
{
    private uint _progress = 0; // 0-100
    private uint _backgroundColor = 0xFF4CAF50;

    this(string id = null)
    {
        super(id);
        layoutWidth = FILL_PARENT;
        layoutHeight = 6;
    }

    @property uint progress() const { return _progress; }
    @property void progress(uint value)
    {
        _progress = min(100, value);
        invalidate();
    }

    override @property uint backgroundColor() const { return _backgroundColor; }
    @property void backgroundColor(uint color)
    {
        _backgroundColor = color;
        invalidate();
    }

    // Introduce base class overload set to avoid hiding
    alias backgroundColor = Widget.backgroundColor;

    override void onDraw(DrawBuf buf)
    {
        super.onDraw(buf);

        Rect rc = _pos;

        // Draw background
        buf.fillRect(rc, 0xFFE0E0E0);

        // Draw progress
        if (_progress > 0)
        {
            Rect progressRc = rc;
            progressRc.right = progressRc.left + (rc.width * _progress) / 100;
            buf.fillRect(progressRc, _backgroundColor);
        }
    }
}
