module app;

import dlangui;
import desktop;
import notes;
import taskbar;
import bindbc.sdl;
import dlangui.platforms.sdl.sdlapp;
import dlangui.platforms.common.platform;

// Main entry point
extern(C) int UIAppMain(string[] args) {
    // Initialize SDL and platform
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER | SDL_INIT_EVENTS) != 0) {
        return 1;
    }
    scope(exit) SDL_Quit();

    initLogs();
    Platform.setInstance(new SDLPlatform());
    Platform.instance.uiTheme = "theme_default";
    
    try {
        auto window = new DesktopWindow();
        if (!window) {
            Log.e("Failed to create window");
            return 1;
        }
        
        window.show();
        return Platform.instance.enterMessageLoop();
    } catch (Exception e) {
        Log.e("Error in main loop: ", e.msg);
        return 1;
    }
} 