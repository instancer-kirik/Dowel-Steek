module taskbar.buttons;

import dlangui;
import dlangui.widgets.controls;
import dlangui.platforms.common.platform;

/// Base class for taskbar buttons
class TaskBarButton : Button {
    private Window targetWindow;

    this(Window win) {
        super("taskbtn");
        targetWindow = win;
        
        // Set button style
        styleId = STYLE_TOOLBAR_BUTTON;
        layoutWidth = WRAP_CONTENT;
        minWidth = 150;
        maxWidth = 200;
        backgroundColor = 0x303030;
        textColor = 0xFFFFFF;
        padding(Rect(10, 5, 10, 5));
        
        // Set window title as button text
        if (win && win.windowCaption)
            text = win.windowCaption;
            
        // Set up click handler
        click = &onButtonClick;
    }

    private bool onButtonClick(Widget w) {
        if (targetWindow) {
            // TODO: Implement window activation/minimization
            return true;
        }
        return false;
    }
}

/// Start menu button
class StartButton : Button {
    this(bool delegate(Widget) clickHandler) {
        super("startbtn");
        text = "Start"d;
        styleId = STYLE_TOOLBAR_BUTTON;
        click = clickHandler;
    }
}

/// System tray button base class
class TrayButton : Button {
    this(dstring iconName = null) {
        super("traybtn");
        styleId = STYLE_TOOLBAR_BUTTON;
        // TODO: Load icon
    }
} 

 