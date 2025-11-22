const std = @import("std");

// Simple error codes for C interop
pub const DowelError = enum(c_int) {
    SUCCESS = 0,
    INVALID_PARAMETER = -1,
    OUT_OF_MEMORY = -2,
    NOT_INITIALIZED = -3,
    OPERATION_FAILED = -4,
};

// Global state
var initialized: bool = false;
var allocator: std.mem.Allocator = undefined;

// Core system functions
export fn dowel_core_init() c_int {
    if (initialized) return @intFromEnum(DowelError.SUCCESS);

    // Use heap allocator for now
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    allocator = gpa.allocator();

    initialized = true;
    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_core_shutdown() void {
    initialized = false;
}

export fn dowel_core_is_initialized() bool {
    return initialized;
}

export fn dowel_get_version(buffer: [*c]u8, size: c_int) c_int {
    if (buffer == null or size <= 0) {
        return @intFromEnum(DowelError.INVALID_PARAMETER);
    }

    const version = "0.1.0";
    const len = @min(@as(usize, @intCast(size - 1)), version.len);

    @memcpy(buffer[0..len], version[0..len]);
    buffer[len] = 0; // null terminate

    return @intFromEnum(DowelError.SUCCESS);
}

// Simple math function for testing
export fn dowel_add_numbers(a: c_int, b: c_int) c_int {
    return a + b;
}

// String manipulation function
export fn dowel_string_length(str: [*c]const u8) c_int {
    if (str == null) return -1;

    var len: c_int = 0;
    while (str[@as(usize, @intCast(len))] != 0) {
        len += 1;
    }
    return len;
}

// Memory allocation functions for Kotlin/Native interop
export fn dowel_malloc(size: usize) ?*anyopaque {
    if (!initialized) return null;

    const ptr = allocator.alloc(u8, size) catch return null;
    return ptr.ptr;
}

export fn dowel_free(ptr: ?*anyopaque) void {
    if (!initialized or ptr == null) return;

    // Note: We can't easily free without size info in this simple example
    // In a real implementation, you'd track allocations
    // For now, just ignore the pointer since we can't properly free it
}

// Configuration functions
export fn dowel_config_get_string(key: [*c]const u8, default_value: [*c]const u8) [*c]const u8 {
    _ = key;
    return default_value;
}

export fn dowel_config_get_int(key: [*c]const u8, default_value: c_int) c_int {
    _ = key;
    return default_value;
}

export fn dowel_config_set_string(key: [*c]const u8, value: [*c]const u8) c_int {
    _ = key;
    _ = value;
    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_config_set_int(key: [*c]const u8, value: c_int) c_int {
    _ = key;
    _ = value;
    return @intFromEnum(DowelError.SUCCESS);
}

// Simple logging
export fn dowel_log_info(message: [*c]const u8) void {
    if (message == null) return;

    const len = dowel_string_length(message);
    if (len > 0) {
        const slice = message[0..@intCast(len)];
        std.debug.print("[INFO] {s}\n", .{slice});
    }
}

export fn dowel_log_error(message: [*c]const u8) void {
    if (message == null) return;

    const len = dowel_string_length(message);
    if (len > 0) {
        const slice = message[0..@intCast(len)];
        std.debug.print("[ERROR] {s}\n", .{slice});
    }
}

// Utility functions
export fn dowel_get_timestamp_ms() c_long {
    return @intCast(std.time.milliTimestamp());
}

export fn dowel_sleep_ms(milliseconds: c_int) void {
    if (milliseconds <= 0) return;
    std.time.sleep(@as(u64, @intCast(milliseconds)) * std.time.ns_per_ms);
}

// Context-Aware Tiling Window Management
// Linux WM-style tiling that adapts from mobile split-screen to desktop layouts

// Display context information
pub const DisplayContext = extern struct {
    screen_width: c_uint,
    screen_height: c_uint,
    dpi: c_uint,
    is_external_connected: bool,
    has_keyboard: bool,
    has_mouse: bool,
    touch_available: bool,
};

// Display configuration
pub const DisplayConfig = extern struct {
    width: c_uint,
    height: c_uint,
    dpi: c_uint,
    refresh_rate: c_uint,
    is_external: bool,
    is_touch_capable: bool,
};

// Tiling Layout Types
pub const TileLayout = enum(c_int) {
    FULLSCREEN = 0, // Single app (mobile default)
    HSPLIT = 1, // Horizontal split (side by side)
    VSPLIT = 2, // Vertical split (top/bottom)
    GRID_2X2 = 3, // 2x2 grid (desktop)
    MASTER_STACK = 4, // Master + stack (Linux WM style)
    FLOATING = 5, // Traditional windows (if needed)
};

// Window handle (opaque to C/Kotlin)
pub const WindowHandle = c_uint;
pub const INVALID_WINDOW: WindowHandle = 0;

// Window tile information
pub const WindowTile = extern struct {
    handle: WindowHandle,
    x: c_int,
    y: c_int,
    width: c_uint,
    height: c_uint,
    is_focused: bool,
};

// Global display state
var current_context: DisplayContext = undefined;
var primary_display: DisplayConfig = undefined;
var external_display: ?DisplayConfig = null;
var window_counter: WindowHandle = 1;
var focused_window: WindowHandle = INVALID_WINDOW;
var current_layout: TileLayout = .FULLSCREEN;
var active_windows: [16]WindowHandle = [_]WindowHandle{INVALID_WINDOW} ** 16;
var window_count: u8 = 0;

// Display management
export fn dowel_display_init() c_int {
    if (!initialized) return @intFromEnum(DowelError.NOT_INITIALIZED);

    // Initialize primary display (phone screen)
    primary_display = DisplayConfig{
        .width = 1080,
        .height = 2340,
        .dpi = 400,
        .refresh_rate = 120,
        .is_external = false,
        .is_touch_capable = true,
    };

    // Initialize context for phone
    current_context = DisplayContext{
        .screen_width = 1080,
        .screen_height = 2340,
        .dpi = 400,
        .is_external_connected = false,
        .has_keyboard = false,
        .has_mouse = false,
        .touch_available = true,
    };

    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_display_get_context(context: [*c]DisplayContext) c_int {
    if (context == null) return @intFromEnum(DowelError.INVALID_PARAMETER);
    context[0] = current_context;
    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_display_detect_external() bool {
    // Mock external display detection
    // In real implementation, this would probe hardware
    return external_display != null;
}

export fn dowel_display_add_external(width: c_uint, height: c_uint, dpi: c_uint) c_int {
    if (!initialized) return @intFromEnum(DowelError.NOT_INITIALIZED);

    external_display = DisplayConfig{
        .width = width,
        .height = height,
        .dpi = dpi,
        .refresh_rate = 60,
        .is_external = true,
        .is_touch_capable = false,
    };

    // Update context - now we have more screen space and likely mouse/keyboard
    current_context.screen_width = width;
    current_context.screen_height = height;
    current_context.dpi = dpi;
    current_context.is_external_connected = true;
    current_context.has_keyboard = true; // Assume external = keyboard
    current_context.has_mouse = true; // Assume external = mouse
    current_context.touch_available = primary_display.is_touch_capable; // Phone still has touch

    dowel_log_info("External display connected - context updated");
    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_display_remove_external() c_int {
    if (!initialized) return @intFromEnum(DowelError.NOT_INITIALIZED);

    external_display = null;

    // Update context back to phone-only
    current_context.screen_width = primary_display.width;
    current_context.screen_height = primary_display.height;
    current_context.dpi = primary_display.dpi;
    current_context.is_external_connected = false;
    current_context.has_keyboard = false;
    current_context.has_mouse = false;
    current_context.touch_available = true;

    dowel_log_info("External display disconnected - context updated");
    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_display_get_primary(config: [*c]DisplayConfig) c_int {
    if (config == null) return @intFromEnum(DowelError.INVALID_PARAMETER);
    config[0] = primary_display;
    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_display_get_external(config: [*c]DisplayConfig) c_int {
    if (config == null) return @intFromEnum(DowelError.INVALID_PARAMETER);

    if (external_display) |ext| {
        config[0] = ext;
        return @intFromEnum(DowelError.SUCCESS);
    }

    return @intFromEnum(DowelError.NOT_INITIALIZED);
}

// Tiling Window Management
export fn dowel_window_create(title: [*c]const u8, x: c_int, y: c_int, width: c_uint, height: c_uint) WindowHandle {
    if (!initialized or title == null) return INVALID_WINDOW;

    _ = x;
    _ = y;
    _ = width;
    _ = height;

    const handle = window_counter;
    window_counter += 1;

    // Add to active windows list
    if (window_count < active_windows.len) {
        active_windows[window_count] = handle;
        window_count += 1;

        // Set as focused if it's the only window
        if (window_count == 1) {
            focused_window = handle;
        }

        // Auto-adjust layout based on window count and context
        dowel_auto_adjust_layout();
    }

    dowel_log_info("Window created and tiled");
    return handle;
}

export fn dowel_window_destroy(window: WindowHandle) c_int {
    if (!initialized or window == INVALID_WINDOW) {
        return @intFromEnum(DowelError.INVALID_PARAMETER);
    }

    // Remove from active windows
    var i: u8 = 0;
    while (i < window_count) : (i += 1) {
        if (active_windows[i] == window) {
            // Shift remaining windows down
            var j = i;
            while (j < window_count - 1) : (j += 1) {
                active_windows[j] = active_windows[j + 1];
            }
            active_windows[window_count - 1] = INVALID_WINDOW;
            window_count -= 1;

            // Update focus if needed
            if (focused_window == window) {
                if (window_count > 0) {
                    focused_window = active_windows[0];
                } else {
                    focused_window = INVALID_WINDOW;
                }
            }

            // Re-tile remaining windows
            dowel_auto_adjust_layout();
            break;
        }
    }

    dowel_log_info("Window destroyed and layout updated");
    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_window_set_fullscreen(window: WindowHandle, fullscreen: bool) c_int {
    if (!initialized or window == INVALID_WINDOW) {
        return @intFromEnum(DowelError.INVALID_PARAMETER);
    }

    // In real implementation, change window mode
    if (fullscreen) {
        dowel_log_info("Window set to fullscreen");
    } else {
        dowel_log_info("Window set to windowed");
    }

    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_window_move(window: WindowHandle, x: c_int, y: c_int) c_int {
    if (!initialized or window == INVALID_WINDOW) {
        return @intFromEnum(DowelError.INVALID_PARAMETER);
    }

    _ = x;
    _ = y;

    // In real implementation, move window
    dowel_log_info("Window moved");

    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_window_resize(window: WindowHandle, width: c_uint, height: c_uint) c_int {
    if (!initialized or window == INVALID_WINDOW) {
        return @intFromEnum(DowelError.INVALID_PARAMETER);
    }

    _ = width;
    _ = height;

    // In real implementation, resize window
    dowel_log_info("Window resized");

    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_window_focus(window: WindowHandle) c_int {
    if (!initialized or window == INVALID_WINDOW) {
        return @intFromEnum(DowelError.INVALID_PARAMETER);
    }

    focused_window = window;
    dowel_log_info("Window focused");

    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_get_focused_window() WindowHandle {
    return focused_window;
}

// Context-Aware UI Helpers
export fn dowel_should_use_large_layout() bool {
    return current_context.screen_width >= 1200; // Large screen/desktop size
}

export fn dowel_has_precise_input() bool {
    return current_context.has_mouse;
}

export fn dowel_get_available_space(width: [*c]c_uint, height: [*c]c_uint) c_int {
    if (width == null or height == null) return @intFromEnum(DowelError.INVALID_PARAMETER);

    width[0] = current_context.screen_width;
    height[0] = current_context.screen_height;

    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_supports_touch() bool {
    return current_context.touch_available;
}

export fn dowel_supports_mouse() bool {
    return current_context.has_mouse;
}

export fn dowel_supports_keyboard() bool {
    return current_context.has_keyboard;
}

export fn dowel_is_docked() bool {
    return current_context.is_external_connected;
}

// Tiling Layout Management
export fn dowel_set_tile_layout(layout: TileLayout) c_int {
    if (!initialized) return @intFromEnum(DowelError.NOT_INITIALIZED);

    current_layout = layout;
    dowel_compute_tiles();
    dowel_log_info("Tile layout changed");

    return @intFromEnum(DowelError.SUCCESS);
}

export fn dowel_get_tile_layout() TileLayout {
    return current_layout;
}

export fn dowel_get_window_tiles(tiles: [*c]WindowTile, max_tiles: c_uint) c_int {
    if (tiles == null) return @intFromEnum(DowelError.INVALID_PARAMETER);

    const count = @min(window_count, @as(u8, @intCast(max_tiles)));

    for (0..count) |i| {
        tiles[i] = dowel_compute_tile_for_window(active_windows[i], @intCast(i));
    }

    return @intCast(count);
}

export fn dowel_focus_next_window() WindowHandle {
    if (window_count == 0) return INVALID_WINDOW;

    // Find current focused window index
    var current_index: u8 = 0;
    for (0..window_count) |i| {
        if (active_windows[i] == focused_window) {
            current_index = @intCast(i);
            break;
        }
    }

    // Move to next window (cycle)
    const next_index = (current_index + 1) % window_count;
    focused_window = active_windows[next_index];

    dowel_log_info("Focus moved to next window");
    return focused_window;
}

export fn dowel_focus_prev_window() WindowHandle {
    if (window_count == 0) return INVALID_WINDOW;

    // Find current focused window index
    var current_index: u8 = 0;
    for (0..window_count) |i| {
        if (active_windows[i] == focused_window) {
            current_index = @intCast(i);
            break;
        }
    }

    // Move to previous window (cycle)
    const prev_index = if (current_index == 0) window_count - 1 else current_index - 1;
    focused_window = active_windows[prev_index];

    dowel_log_info("Focus moved to previous window");
    return focused_window;
}

export fn dowel_get_window_count() c_uint {
    return window_count;
}

// Internal tiling functions
fn dowel_auto_adjust_layout() void {
    switch (window_count) {
        0 => current_layout = .FULLSCREEN,
        1 => current_layout = .FULLSCREEN,
        2 => {
            if (current_context.screen_width > current_context.screen_height) {
                current_layout = .HSPLIT; // Side by side on wide screens
            } else {
                current_layout = .VSPLIT; // Top/bottom on tall screens
            }
        },
        3, 4 => {
            if (dowel_should_use_large_layout()) {
                current_layout = .GRID_2X2; // Grid on large screens
            } else {
                current_layout = .MASTER_STACK; // Master+stack on smaller screens
            }
        },
        else => current_layout = .MASTER_STACK, // Default for many windows
    }

    dowel_compute_tiles();
}

fn dowel_compute_tiles() void {
    // In real implementation, this would calculate actual tile positions
    // For now, just log the layout change
    dowel_log_info("Tile positions computed");
}

fn dowel_compute_tile_for_window(window: WindowHandle, index: u8) WindowTile {
    const screen_w = current_context.screen_width;
    const screen_h = current_context.screen_height;

    var tile = WindowTile{
        .handle = window,
        .x = 0,
        .y = 0,
        .width = screen_w,
        .height = screen_h,
        .is_focused = (window == focused_window),
    };

    switch (current_layout) {
        .FULLSCREEN => {
            // Full screen (default values already set)
        },
        .HSPLIT => {
            tile.width = screen_w / 2;
            tile.x = if (index == 0) 0 else @intCast(screen_w / 2);
        },
        .VSPLIT => {
            tile.height = screen_h / 2;
            tile.y = if (index == 0) 0 else @intCast(screen_h / 2);
        },
        .GRID_2X2 => {
            tile.width = screen_w / 2;
            tile.height = screen_h / 2;
            tile.x = if (index % 2 == 0) 0 else @intCast(screen_w / 2);
            tile.y = if (index < 2) 0 else @intCast(screen_h / 2);
        },
        .MASTER_STACK => {
            if (index == 0) {
                // Master window (left 60%)
                tile.width = screen_w * 3 / 5;
            } else {
                // Stack windows (right 40%, divided vertically)
                tile.width = screen_w * 2 / 5;
                tile.x = @intCast(screen_w * 3 / 5);
                tile.height = screen_h / (window_count - 1);
                tile.y = @intCast(tile.height * (index - 1));
            }
        },
        .FLOATING => {
            // Traditional overlapping windows (keep default size)
            tile.x = @intCast(index * 50); // Offset each window
            tile.y = @intCast(index * 30);
            tile.width = screen_w * 3 / 4;
            tile.height = screen_h * 3 / 4;
        },
    }

    return tile;
}

// Test the API
test "minimal API test" {
    const result = dowel_core_init();
    try std.testing.expect(result == 0);

    const is_init = dowel_core_is_initialized();
    try std.testing.expect(is_init);

    const sum = dowel_add_numbers(5, 3);
    try std.testing.expect(sum == 8);

    const test_str = "hello world";
    const len = dowel_string_length(test_str);
    try std.testing.expect(len == 11);

    dowel_core_shutdown();
}

test "display context" {
    const result = dowel_core_init();
    try std.testing.expect(result == 0);

    const init_result = dowel_display_init();
    try std.testing.expect(init_result == 0);

    const should_use_large = dowel_should_use_large_layout();
    try std.testing.expect(!should_use_large); // Phone screen < 1200px

    const supports_touch = dowel_supports_touch();
    try std.testing.expect(supports_touch);

    const has_mouse = dowel_supports_mouse();
    try std.testing.expect(!has_mouse); // No external connected

    dowel_core_shutdown();
}

test "tiling window management" {
    const result = dowel_core_init();
    try std.testing.expect(result == 0);

    _ = dowel_display_init();

    // Test single window (fullscreen)
    const window1 = dowel_window_create("App 1", 0, 0, 800, 600);
    try std.testing.expect(window1 != INVALID_WINDOW);
    try std.testing.expect(dowel_get_tile_layout() == .FULLSCREEN);
    try std.testing.expect(dowel_get_window_count() == 1);

    // Test two windows (should auto-split)
    const window2 = dowel_window_create("App 2", 0, 0, 800, 600);
    try std.testing.expect(window2 != INVALID_WINDOW);
    try std.testing.expect(dowel_get_tile_layout() == .VSPLIT); // Tall phone screen default
    try std.testing.expect(dowel_get_window_count() == 2);

    // Test focus cycling
    const focused = dowel_focus_next_window();
    try std.testing.expect(focused != INVALID_WINDOW);

    // Clean up
    _ = dowel_window_destroy(window1);
    _ = dowel_window_destroy(window2);
    try std.testing.expect(dowel_get_window_count() == 0);

    dowel_core_shutdown();
}
