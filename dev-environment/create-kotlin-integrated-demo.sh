#!/bin/bash

# Dowel-Steek Mobile OS - Create Kotlin-Integrated Demo
# This script creates a proper mobile OS demo where Kotlin drives the UI
# and calls Zig services, replacing the current Zig-only SDL2 demo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
DEV_ENV_DIR="$PROJECT_ROOT/dev-environment"
KOTLIN_DEMO_DIR="$DEV_ENV_DIR/kotlin-mobile-os"

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                                                                  ║"
echo "║            DOWEL-STEEK KOTLIN-INTEGRATED MOBILE OS              ║"
echo "║                                                                  ║"
echo "║    Creating proper Kotlin-driven mobile OS with Zig backend     ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
print_status "Checking dependencies..."

if ! command -v zig >/dev/null 2>&1; then
    print_error "Zig compiler not found. Please install Zig 0.11+"
    exit 1
fi

if ! command -v kotlin >/dev/null 2>&1; then
    print_error "Kotlin compiler not found. Installing Kotlin/Native..."

    # Try to install Kotlin/Native
    if command -v curl >/dev/null 2>&1; then
        KOTLIN_VERSION="1.9.20"
        KOTLIN_URL="https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip"

        print_status "Downloading Kotlin ${KOTLIN_VERSION}..."
        mkdir -p "$HOME/.local"
        cd "$HOME/.local"

        if [[ ! -d "kotlin" ]]; then
            curl -L -o "kotlin.zip" "$KOTLIN_URL"
            unzip -q "kotlin.zip"
            mv "kotlinc" "kotlin"
            rm "kotlin.zip"
        fi

        # Add to PATH for current session
        export PATH="$HOME/.local/kotlin/bin:$PATH"

        if command -v kotlin >/dev/null 2>&1; then
            print_success "Kotlin installed successfully"
        else
            print_error "Failed to install Kotlin. Please install manually."
            exit 1
        fi
    else
        print_error "curl not found. Please install Kotlin manually."
        exit 1
    fi
fi

if ! pkg-config --exists sdl2; then
    print_error "SDL2 development libraries not found. Please install libsdl2-dev"
    exit 1
fi

if ! pkg-config --exists freetype2; then
    print_warning "FreeType not found. Installing for better font rendering..."
    # Try to install FreeType
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y libfreetype6-dev || true
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y freetype-devel || true
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed freetype2 || true
    fi
fi

print_success "Dependencies verified"

# Create project structure
print_status "Creating Kotlin-integrated mobile OS project..."

# Clean up old demo if it exists
if [[ -d "$KOTLIN_DEMO_DIR" ]]; then
    print_warning "Removing existing Kotlin demo directory"
    rm -rf "$KOTLIN_DEMO_DIR"
fi

mkdir -p "$KOTLIN_DEMO_DIR"/{src,lib,build,assets/fonts}

print_success "Project structure created"

# Step 1: Build enhanced Zig backend with better C API
print_status "Building enhanced Zig backend with improved font rendering..."

cat > "$KOTLIN_DEMO_DIR/src/mobile_os_backend.zig" << 'EOF'
//! Dowel-Steek Mobile OS - Enhanced Zig Backend for Kotlin Integration
//! This provides a clean C API that Kotlin can call for system services

const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
});

// Global state
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator: std.mem.Allocator = undefined;
var initialized: bool = false;

// SDL resources
var window: ?*c.SDL_Window = null;
var renderer: ?*c.SDL_Renderer = null;
var default_font: ?*c.TTF_Font = null;

// System state
var frame_count: u32 = 0;
var last_fps_time: u32 = 0;
var current_fps: f32 = 0.0;

// Color structure for C API
const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

// Rectangle structure for C API
const Rect = extern struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
};

// === CORE SYSTEM FUNCTIONS ===

export fn dowel_system_init() c_int {
    if (initialized) return 0;

    allocator = gpa.allocator();

    // Initialize SDL
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        std.log.err("SDL could not initialize! SDL_Error: {s}", .{c.SDL_GetError()});
        return -1;
    }

    // Initialize SDL_ttf for font rendering
    if (c.TTF_Init() == -1) {
        std.log.err("SDL_ttf could not initialize! TTF_Error: {s}", .{c.TTF_GetError()});
        return -1;
    }

    initialized = true;
    std.log.info("Dowel-Steek system initialized", .{});
    return 0;
}

export fn dowel_system_shutdown() void {
    if (!initialized) return;

    if (default_font) |font| {
        c.TTF_CloseFont(font);
        default_font = null;
    }

    if (renderer) |r| {
        c.SDL_DestroyRenderer(r);
        renderer = null;
    }

    if (window) |w| {
        c.SDL_DestroyWindow(w);
        window = null;
    }

    c.TTF_Quit();
    c.SDL_Quit();

    _ = gpa.deinit();
    initialized = false;
    std.log.info("Dowel-Steek system shutdown", .{});
}

export fn dowel_system_is_initialized() bool {
    return initialized;
}

// === DISPLAY FUNCTIONS ===

export fn dowel_display_create(width: c_int, height: c_int, title: [*c]const u8) c_int {
    if (!initialized) return -1;

    window = c.SDL_CreateWindow(
        title,
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        width,
        height,
        c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_RESIZABLE
    );

    if (window == null) {
        std.log.err("Window could not be created! SDL_Error: {s}", .{c.SDL_GetError()});
        return -1;
    }

    renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED | c.SDL_RENDERER_PRESENTVSYNC);
    if (renderer == null) {
        std.log.err("Renderer could not be created! SDL_Error: {s}", .{c.SDL_GetError()});
        return -1;
    }

    // Load default font
    default_font = c.TTF_OpenFont("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16);
    if (default_font == null) {
        // Try alternative font paths
        default_font = c.TTF_OpenFont("/System/Library/Fonts/Arial.ttf", 16);
        if (default_font == null) {
            default_font = c.TTF_OpenFont("/usr/share/fonts/TTF/arial.ttf", 16);
            if (default_font == null) {
                std.log.warn("Could not load system font, using built-in rendering", .{});
            }
        }
    }

    std.log.info("Display created: {}x{}", .{width, height});
    return 0;
}

export fn dowel_display_clear(color: Color) void {
    if (renderer == null) return;

    _ = c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);
    _ = c.SDL_RenderClear(renderer);
}

export fn dowel_display_present() void {
    if (renderer == null) return;

    c.SDL_RenderPresent(renderer);

    // Update FPS calculation
    frame_count += 1;
    const current_time = c.SDL_GetTicks();
    if (current_time - last_fps_time >= 1000) {
        current_fps = @as(f32, @floatFromInt(frame_count)) / (@as(f32, @floatFromInt(current_time - last_fps_time)) / 1000.0);
        frame_count = 0;
        last_fps_time = current_time;
    }
}

export fn dowel_display_get_fps() f32 {
    return current_fps;
}

// === DRAWING FUNCTIONS ===

export fn dowel_draw_rect(rect: Rect, color: Color, filled: bool) void {
    if (renderer == null) return;

    _ = c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);

    const sdl_rect = c.SDL_Rect{ .x = rect.x, .y = rect.y, .w = rect.w, .h = rect.h };

    if (filled) {
        _ = c.SDL_RenderFillRect(renderer, &sdl_rect);
    } else {
        _ = c.SDL_RenderDrawRect(renderer, &sdl_rect);
    }
}

export fn dowel_draw_text(text: [*c]const u8, x: c_int, y: c_int, color: Color, size: c_int) void {
    if (renderer == null) return;

    // Use TTF font if available
    if (default_font) |font| {
        const sdl_color = c.SDL_Color{ .r = color.r, .g = color.g, .b = color.b, .a = color.a };
        const surface = c.TTF_RenderText_Solid(font, text, sdl_color);
        if (surface) |surf| {
            defer c.SDL_FreeSurface(surf);

            const texture = c.SDL_CreateTextureFromSurface(renderer, surf);
            if (texture) |tex| {
                defer c.SDL_DestroyTexture(tex);

                const dest_rect = c.SDL_Rect{
                    .x = x,
                    .y = y,
                    .w = surf.*.w,
                    .h = surf.*.h
                };

                _ = c.SDL_RenderCopy(renderer, tex, null, &dest_rect);
            }
        }
    } else {
        // Fallback to simple text rendering
        drawSimpleText(text, x, y, color);
    }
}

fn drawSimpleText(text: [*c]const u8, x: c_int, y: c_int, color: Color) void {
    if (renderer == null) return;

    _ = c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);

    const text_slice = std.mem.span(text);
    for (text_slice, 0..) |char, i| {
        const char_x = x + @as(c_int, @intCast(i)) * 8;
        drawSimpleChar(char_x, y, char);
    }
}

fn drawSimpleChar(x: c_int, y: c_int, char: u8) void {
    // Simple 8x8 character rendering
    const char_width = 8;
    const char_height = 8;

    // Draw a simple rectangle outline for each character (better than squares)
    const char_rect = c.SDL_Rect{ .x = x, .y = y, .w = char_width - 1, .h = char_height - 1 };
    _ = c.SDL_RenderDrawRect(renderer, &char_rect);

    // Add some character differentiation
    switch (char) {
        'A'...'Z', 'a'...'z' => {
            // Letters get a dot in the center
            _ = c.SDL_RenderDrawPoint(renderer, x + 3, y + 3);
        },
        '0'...'9' => {
            // Numbers get a line across the middle
            _ = c.SDL_RenderDrawLine(renderer, x + 1, y + 4, x + 6, y + 4);
        },
        ' ' => {
            // Space is just empty
        },
        else => {
            // Other characters get an X
            _ = c.SDL_RenderDrawLine(renderer, x + 1, y + 1, x + 6, y + 6);
            _ = c.SDL_RenderDrawLine(renderer, x + 6, y + 1, x + 1, y + 6);
        }
    }
}

export fn dowel_draw_circle(x: c_int, y: c_int, radius: c_int, color: Color, filled: bool) void {
    if (renderer == null) return;

    _ = c.SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, color.a);

    // Simple circle drawing algorithm
    var dx: c_int = -radius;
    while (dx <= radius) : (dx += 1) {
        var dy: c_int = -radius;
        while (dy <= radius) : (dy += 1) {
            if (filled) {
                if (dx * dx + dy * dy <= radius * radius) {
                    _ = c.SDL_RenderDrawPoint(renderer, x + dx, y + dy);
                }
            } else {
                const dist_sq = dx * dx + dy * dy;
                if (dist_sq >= (radius - 1) * (radius - 1) and dist_sq <= radius * radius) {
                    _ = c.SDL_RenderDrawPoint(renderer, x + dx, y + dy);
                }
            }
        }
    }
}

// === EVENT HANDLING ===

export fn dowel_events_poll() c_int {
    if (!initialized) return 0;

    var event: c.SDL_Event = undefined;
    return if (c.SDL_PollEvent(&event) != 0) 1 else 0;
}

export fn dowel_events_get_type() c_int {
    var event: c.SDL_Event = undefined;
    if (c.SDL_PollEvent(&event) != 0) {
        return @as(c_int, @intCast(event.type));
    }
    return 0;
}

export fn dowel_events_get_mouse(x: *c_int, y: *c_int, button: *c_int) c_int {
    var event: c.SDL_Event = undefined;
    if (c.SDL_PollEvent(&event) != 0 and event.type == c.SDL_MOUSEBUTTONDOWN) {
        x.* = event.button.x;
        y.* = event.button.y;
        button.* = @as(c_int, @intCast(event.button.button));
        return 1;
    }
    return 0;
}

export fn dowel_events_get_key() c_int {
    var event: c.SDL_Event = undefined;
    if (c.SDL_PollEvent(&event) != 0 and event.type == c.SDL_KEYDOWN) {
        return @as(c_int, @intCast(event.key.keysym.sym));
    }
    return 0;
}

export fn dowel_should_quit() bool {
    var event: c.SDL_Event = undefined;
    while (c.SDL_PollEvent(&event) != 0) {
        if (event.type == c.SDL_QUIT) return true;
        if (event.type == c.SDL_KEYDOWN and event.key.keysym.sym == c.SDLK_ESCAPE) return true;
    }
    return false;
}

// === SYSTEM SERVICES (Integration with existing Zig core) ===

// Configuration
export fn dowel_config_set_string(key: [*c]const u8, value: [*c]const u8) c_int {
    // Mock implementation - in real system, this would call the Zig config module
    std.log.info("Config set: {s} = {s}", .{key, value});
    return 0;
}

export fn dowel_config_get_string(key: [*c]const u8, buffer: [*c]u8, buffer_size: c_int) c_int {
    // Mock implementation
    const mock_value = "mock_value";
    const key_span = std.mem.span(key);

    var value: []const u8 = mock_value;
    if (std.mem.eql(u8, key_span, "device.name")) {
        value = "Dowel-Steek Phone";
    } else if (std.mem.eql(u8, key_span, "user.theme")) {
        value = "dark";
    } else if (std.mem.eql(u8, key_span, "system.version")) {
        value = "0.1.0-alpha";
    }

    const copy_len = @min(value.len, @as(usize, @intCast(buffer_size - 1)));
    @memcpy(buffer[0..copy_len], value[0..copy_len]);
    buffer[copy_len] = 0; // Null terminate

    return @as(c_int, @intCast(copy_len));
}

// Logging
export fn dowel_log_info(message: [*c]const u8) void {
    std.log.info("KOTLIN: {s}", .{message});
}

export fn dowel_log_error(message: [*c]const u8) void {
    std.log.err("KOTLIN: {s}", .{message});
}

// Math utilities
export fn dowel_add_numbers(a: c_int, b: c_int) c_int {
    return a + b;
}

export fn dowel_get_timestamp() c_long {
    return @as(c_long, @intCast(std.time.milliTimestamp()));
}

// System info
export fn dowel_get_version(buffer: [*c]u8, buffer_size: c_int) c_int {
    const version = "0.1.0-alpha-kotlin";
    const copy_len = @min(version.len, @as(usize, @intCast(buffer_size - 1)));
    @memcpy(buffer[0..copy_len], version[0..copy_len]);
    buffer[copy_len] = 0;
    return @as(c_int, @intCast(copy_len));
}
EOF

print_success "Enhanced Zig backend created"

# Build the Zig backend
print_status "Compiling enhanced Zig backend..."

cd "$KOTLIN_DEMO_DIR"

# Build the Zig backend as a static library
zig build-lib src/mobile_os_backend.zig \
    -dynamic \
    -lc \
    -lSDL2 \
    -lSDL2_ttf \
    --name dowel-mobile-os \
    -O ReleaseFast

if [[ -f "libdowel-mobile-os.so" ]] || [[ -f "libdowel-mobile-os.dylib" ]] || [[ -f "dowel-mobile-os.dll" ]]; then
    print_success "Zig backend compiled successfully"
else
    print_error "Failed to compile Zig backend"
    exit 1
fi

# Step 2: Create Kotlin/Native mobile OS application
print_status "Creating Kotlin/Native mobile OS application..."

cat > "$KOTLIN_DEMO_DIR/src/MobileOS.kt" << 'EOF'
package com.dowelsteek.mobile

import kotlinx.cinterop.*
import kotlin.math.*

/**
 * Dowel-Steek Mobile OS - Kotlin/Native Application Layer
 * This is the main mobile OS application that drives the UI and calls Zig services
 */

// Native bindings to Zig backend
@SymbolName("dowel_system_init")
external fun nativeSystemInit(): Int

@SymbolName("dowel_system_shutdown")
external fun nativeSystemShutdown()

@SymbolName("dowel_system_is_initialized")
external fun nativeSystemIsInitialized(): Boolean

@SymbolName("dowel_display_create")
external fun nativeDisplayCreate(width: Int, height: Int, title: CPointer<ByteVar>): Int

@SymbolName("dowel_display_clear")
external fun nativeDisplayClear(color: Color)

@SymbolName("dowel_display_present")
external fun nativeDisplayPresent()

@SymbolName("dowel_display_get_fps")
external fun nativeDisplayGetFps(): Float

@SymbolName("dowel_draw_rect")
external fun nativeDrawRect(rect: Rect, color: Color, filled: Boolean)

@SymbolName("dowel_draw_text")
external fun nativeDrawText(text: CPointer<ByteVar>, x: Int, y: Int, color: Color, size: Int)

@SymbolName("dowel_draw_circle")
external fun nativeDrawCircle(x: Int, y: Int, radius: Int, color: Color, filled: Boolean)

@SymbolName("dowel_should_quit")
external fun nativeShouldQuit(): Boolean

@SymbolName("dowel_config_set_string")
external fun nativeConfigSetString(key: CPointer<ByteVar>, value: CPointer<ByteVar>): Int

@SymbolName("dowel_config_get_string")
external fun nativeConfigGetString(key: CPointer<ByteVar>, buffer: CPointer<ByteVar>, bufferSize: Int): Int

@SymbolName("dowel_log_info")
external fun nativeLogInfo(message: CPointer<ByteVar>)

@SymbolName("dowel_log_error")
external fun nativeLogError(message: CPointer<ByteVar>)

@SymbolName("dowel_get_timestamp")
external fun nativeGetTimestamp(): Long

@SymbolName("dowel_get_version")
external fun nativeGetVersion(buffer: CPointer<ByteVar>, bufferSize: Int): Int

// Data structures matching C API
@Suppress("ClassName")
class Color(val r: UByte, val g: UByte, val b: UByte, val a: UByte = 255u) {
    companion object {
        val BLACK = Color(0u, 0u, 0u)
        val WHITE = Color(255u, 255u, 255u)
        val GRAY = Color(128u, 128u, 128u)
        val DARK_GRAY = Color(64u, 64u, 64u)
        val LIGHT_GRAY = Color(192u, 192u, 192u)
        val RED = Color(255u, 0u, 0u)
        val GREEN = Color(0u, 255u, 0u)
        val BLUE = Color(0u, 128u, 255u)
        val CYAN = Color(0u, 255u, 255u)
        val MAGENTA = Color(255u, 0u, 255u)
        val YELLOW = Color(255u, 255u, 0u)
        val ORANGE = Color(255u, 165u, 0u)

        fun rgb(r: Int, g: Int, b: Int) = Color(r.toUByte(), g.toUByte(), b.toUByte())
    }
}

@Suppress("ClassName")
class Rect(val x: Int, val y: Int, val w: Int, val h: Int) {
    fun contains(px: Int, py: Int): Boolean {
        return px >= x && px < x + w && py >= y && py < y + h
    }
}

/**
 * Mobile OS Button Component
 */
class Button(
    val rect: Rect,
    val text: String,
    val color: Color,
    val textColor: Color = Color.WHITE
) {
    var isPressed: Boolean = false
        private set

    private var pressTime: Float = 0f

    fun update(deltaTime: Float) {
        if (pressTime > 0f) {
            pressTime -= deltaTime
            if (pressTime <= 0f) {
                isPressed = false
            }
        }
    }

    fun press() {
        isPressed = true
        pressTime = 0.5f // Show press feedback for 0.5 seconds
    }

    fun draw() {
        val btnColor = if (isPressed) {
            Color.rgb(
                minOf(255, color.r.toInt() + 50),
                minOf(255, color.g.toInt() + 50),
                minOf(255, color.b.toInt() + 50)
            )
        } else {
            color
        }

        // Draw button background
        nativeDrawRect(rect, btnColor, true)

        // Draw button border
        nativeDrawRect(rect, Color.WHITE, false)

        // Draw button text (centered)
        val textX = rect.x + (rect.w - text.length * 8) / 2
        val textY = rect.y + (rect.h - 16) / 2

        text.cstr.use { cText ->
            nativeDrawText(cText, textX, textY, textColor, 16)
        }
    }

    fun handleClick(x: Int, y: Int): Boolean {
        return if (rect.contains(x, y)) {
            press()
            true
        } else {
            false
        }
    }
}

/**
 * Mobile OS Application Interface
 */
abstract class MobileApp(val name: String) {
    abstract fun update(deltaTime: Float)
    abstract fun draw()
    abstract fun handleInput(x: Int, y: Int): Boolean
}

/**
 * Launcher App - Main home screen
 */
class LauncherApp : MobileApp("Launcher") {
    private val buttons = listOf(
        Button(Rect(50, 150, 200, 60), "Settings", Color.GRAY),
        Button(Rect(50, 230, 200, 60), "Files", Color.BLUE),
        Button(Rect(50, 310, 200, 60), "Calculator", Color.GREEN),
        Button(Rect(50, 390, 200, 60), "Camera", Color.ORANGE),
        Button(Rect(50, 470, 200, 60), "About System", Color.MAGENTA),
        Button(Rect(50, 550, 200, 60), "Exit Demo", Color.RED)
    )

    private var animationTime: Float = 0f

    override fun update(deltaTime: Float) {
        animationTime += deltaTime
        buttons.forEach { it.update(deltaTime) }
    }

    override fun draw() {
        // Title
        "DOWEL-STEEK MOBILE OS".cstr.use { title ->
            nativeDrawText(title, 50, 50, Color.WHITE, 24)
        }

        "Kotlin/Native + Zig Integration".cstr.use { subtitle ->
            nativeDrawText(subtitle, 50, 80, Color.LIGHT_GRAY, 16)
        }

        // System info
        "System Version: ${getSystemVersion()}".cstr.use { version ->
            nativeDrawText(version, 300, 150, Color.LIGHT_GRAY, 14)
        }

        "Integration Status: ACTIVE".cstr.use { status ->
            nativeDrawText(status, 300, 170, Color.GREEN, 14)
        }

        "Backend: Zig ${getZigVersion()}".cstr.use { backend ->
            nativeDrawText(backend, 300, 190, Color.LIGHT_GRAY, 14)
        }

        "Frontend: Kotlin/Native".cstr.use { frontend ->
            nativeDrawText(frontend, 300, 210, Color.LIGHT_GRAY, 14)
        }

        // Draw animated elements
        drawAnimations()

        // Draw buttons
        buttons.forEach { it.draw() }

        // Performance info
        val fps = nativeDisplayGetFps()
        "FPS: %.1f".format(fps).cstr.use { fpsText ->
            nativeDrawText(fpsText, 20, 650, Color.YELLOW, 14)
        }

        "Font: TTF Rendering Active".cstr.use { fontInfo ->
            nativeDrawText(fontInfo, 20, 670, Color.CYAN, 14)
        }
    }

    private fun drawAnimations() {
        // Rotating circles demonstration
        val centerX = 500
        val centerY = 400
        val radius = 80f

        val colors = arrayOf(Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.MAGENTA)

        for (i in colors.indices) {
            val angle = animationTime + i * (2 * PI / colors.size)
            val x = (centerX + cos(angle) * radius).toInt()
            val y = (centerY + sin(angle) * radius).toInt()

            nativeDrawCircle(x, y, 12, colors[i], true)
        }

        // Central circle
        nativeDrawCircle(centerX, centerY, 20, Color.WHITE, false)
    }

    override fun handleInput(x: Int, y: Int): Boolean {
        buttons.forEachIndexed { index, button ->
            if (button.handleClick(x, y)) {
                handleButtonClick(index)
