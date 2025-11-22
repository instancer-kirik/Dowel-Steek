module D; // This is the main module for the 'bridge_editor' configuration

import dlangui;
import dlangui.platforms.common.platform;
import dlangui.platforms.sdl.sdlapp; // For SDLPlatform if manual setup

import bridge.bridge_window; // Our main editor window
import bindbc.opengl;          // For bindbc.opengl.loadOpenGL
import dlangui.core.logger;
import bindbc.sdl; // <<< ADDED for SDL_Init
import std.string : fromStringz; // <<< ADDED for fromStringz
import std.conv : to; // For to!string if needed, though fromStringz is specific

// This UIAppMain will be the entry point for the 'bridge_editor' target
// as specified by "mainSourceFile": "source/D.d" in dub.json
extern (C) int UIAppMain(string[] args) {
    // Platform initialization:
    // If your dub.json for bridge_editor uses "subConfigurations": {"dlangui": "sdl"},
    // DLangUI often mixes in an APP_ENTRY_POINT that sets up Platform.instance.
    // If not, or to be explicit:
    if (!Platform.instance) {
        Log.i("D.d: Manually initializing SDLPlatform for Bridge Editor.");
        if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER | SDL_INIT_EVENTS) != 0) {
             Log.e("D.d: Failed to init SDL: ", fromStringz(SDL_GetError()));
             return 1;
        }
        // SDL_Quit will be handled by SDLPlatform's destructor or a scope(exit) in main loop
        Platform.setInstance(new SDLPlatform());
    }
    Platform.instance.uiTheme = "theme_default";

    // Load OpenGL functions (from bindbc-opengl)
    // This is important if Bridge3DView uses direct GL calls.
    version(ENABLE_OPENGL) { // ENABLE_OPENGL should be in versions for bridge_editor config
        auto supportLevel = bindbc.opengl.loadOpenGL(); // bindbc.opengl.GLSupport
        if (supportLevel < bindbc.opengl.GLSupport.gl11) { // Check against bindbc.opengl's enum
            Log.e("D.d: Failed to load required OpenGL version for Bridge Editor. Support: ", supportLevel);
            // Depending on how critical GL is, you might return or let DLangUI try to proceed.
            // return 1; 
        } else {
            Log.i("D.d: OpenGL loaded via bindbc-opengl. Support: ", supportLevel);
        }
    } else {
        Log.w("D.d: ENABLE_OPENGL version is not set for bridge_editor. OpenGL features may not work.");
    }

    Window window;
    try {
        Log.i("D.d: Creating BridgeWindow...");
        window = new BridgeWindow(); // This is our modernized window
        window.show();               // This calls BridgeWindow.show()
        Log.i("D.d: BridgeWindow.show() called.");
    } catch (Exception e) {
        Log.e("D.d: Error during BridgeWindow creation or show: ", e.msg);
        if(window) window.close(); // Attempt to clean up
        return 1;
    }
    
    Log.i("D.d: Entering message loop for Bridge Editor...");
    return Platform.instance.enterMessageLoop();
}

// The old MainWindow, Scene3DWidget, etc. classes from this file are now OBSOLETE
// if BridgeWindow is the new main interface. You can delete them from this file
// to avoid confusion and errors.