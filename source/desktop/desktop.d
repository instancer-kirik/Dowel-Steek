module dowel.desktop.desktop;

import dlangui;
import dlangui.widgets.widget;
import dlangui.widgets.layouts;
import dlangui.widgets.controls;
import dlangui.core.types;
import dlangui.core.events;

import std.file;
import std.path;
import std.conv;
import dowel.themes.modern_dark;

/// Desktop widget for wallpaper and desktop icons
class Desktop : FrameLayout
{
private:
    string _wallpaperPath;
    DrawableRef _wallpaperDrawable;
    Widget _iconContainer;

public:
    this()
    {
        super("desktop");
        layoutWidth = FILL_PARENT;
        layoutHeight = FILL_PARENT;
        backgroundColor = ModernDarkTheme.Colors.DesktopBackground; // Modern dark background

        // Create icon container
        _iconContainer = new FrameLayout("desktopIcons");
        _iconContainer.layoutWidth = FILL_PARENT;
        _iconContainer.layoutHeight = FILL_PARENT;
        _iconContainer.padding(Rect(20, 20, 20, 20));

        addChild(_iconContainer);

        // Add default desktop icons
        addDefaultIcons();
    }

    /// Set desktop wallpaper
    void setWallpaper(string path)
    {
        if (!exists(path))
            return;

        _wallpaperPath = path;

        // TODO: Load and set wallpaper image
        // For now, just store the path
    }

    /// Add a desktop icon
    void addIcon(string label, string iconPath, void delegate() onClick)
    {
        auto icon = new DesktopIcon(label, iconPath);
        icon.click = delegate(Widget src) {
            if (onClick)
                onClick();
            return true;
        };
        _iconContainer.addChild(icon);
    }

    private void addDefaultIcons()
    {
        // Add home folder icon
        addIcon("Home", "folder-home", delegate() {
            // TODO: Open file manager at home directory
        });

        // Add documents folder icon
        addIcon("Documents", "folder-documents", delegate() {
            // TODO: Open file manager at documents directory
        });

        // Add downloads folder icon
        addIcon("Downloads", "folder-downloads", delegate() {
            // TODO: Open file manager at downloads directory
        });

        // Add trash icon
        addIcon("Trash", "user-trash", delegate() {
            // TODO: Open trash/recycle bin
        });
    }
}

/// Desktop icon widget
class DesktopIcon : VerticalLayout
{
private:
    ImageWidget _icon;
    TextWidget _label;

public:
    this(string label, string iconResource)
    {
        super("desktopIcon");
        layoutWidth = 64;
        layoutHeight = 90;
        padding(Rect(8, 8, 8, 8));
        alignment = Align.Center;
        backgroundColor = 0x00000000; // Transparent background

        // Icon image
        _icon = new ImageWidget(null, iconResource);
        _icon.layoutWidth = 48;
        _icon.layoutHeight = 48;
        _icon.alignment = Align.Center;
        addChild(_icon);

        // Icon label
        _label = new TextWidget(null, label.to!dstring);
        _label.textColor = ModernDarkTheme.Colors.TextPrimary;
        _label.fontSize = 11;
        _label.fontWeight = 400;
        _label.alignment = Align.Center;
        _label.layoutWidth = FILL_PARENT;
        addChild(_label);
    }

    override bool onMouseEvent(MouseEvent event)
    {
        if (event.action == MouseAction.ButtonDown)
        {
            if (event.doubleClick)
            {
                // Double-click to activate
                if (click.assigned)
                    return click(this);
            }
            else
            {
                // Single click to select
                // Show selection highlight with modern colors
                backgroundColor = ModernDarkTheme.Colors.Surface;
            }
            return true;
        }

        return super.onMouseEvent(event);
    }
}
