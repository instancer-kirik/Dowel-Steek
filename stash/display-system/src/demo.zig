//! Display Demo for Dowel-Steek Mobile OS
//! Demonstrates basic framebuffer operations, graphics rendering, and UI concepts

const std = @import("std");
const display = @import("display.zig");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Color = display.Color;
const DisplayConfig = display.DisplayConfig;
const DisplayManager = display.DisplayManager;
const Framebuffer = display.Framebuffer;
const Rect = display.Rect;

// Simple bitmap font for text rendering (8x8 pixels per character)
const FONT_WIDTH = 8;
const FONT_HEIGHT = 8;

// Basic ASCII font bitmap (simplified for demo)
const FONT_DATA = [_]u64{
    0x0000000000000000, // ' ' (space)
    0x183C3C1800180000, // '!'
    0x6666000000000000, // '"'
    0x6666FF66FF666600, // '#'
    0x183E603C067C1800, // '$'
    0x60660C1830660600, // '%'
    0x3C66663C6E663B00, // '&'
    0x1818000000000000, // '''
    0x0C18303030180C00, // '('
    0x30180C0C0C183000, // ')'
    0x006699FF996600000, // '*'
    0x0018187E18180000, // '+'
    0x0000000000181830, // ','
    0x0000007E00000000, // '-'
    0x0000000000181800, // '.'
    0x060C183060C08000, // '/'
    // Numbers 0-9
    0x3C66666E76663C00, // '0'
    0x1818381818187E00, // '1'
    0x3C66060C18307E00, // '2'
    0x3C66061C06663C00, // '3'
    0x0C1C3C6C7E0C0C00, // '4'
    0x7E60607C06663C00, // '5'
    0x3C66607C66663C00, // '6'
    0x7E060C1830303000, // '7'
    0x3C66663C66663C00, // '8'
    0x3C66663E06663C00, // '9'
    // Letters A-Z (subset for demo)
    0x3C66667E66666600, // 'A'
    0x7C66667C66667C00, // 'B'
    0x3C66606060663C00, // 'C'
    0x7866666666667800, // 'D'
    0x7E60607860607E00, // 'E'
    0x7E60607860606000, // 'F'
    0x3C66606E66663C00, // 'G'
    0x6666667E66666600, // 'H'
    0x7E18181818187E00, // 'I'
    0x3E0C0C0C0C6C3800, // 'J'
    0x666C7870786C6600, // 'K'
    0x6060606060607E00, // 'L'
    0x63777F6B6B636300, // 'M'
    0x6676667E6E666600, // 'N'
    0x3C66666666663C00, // 'O'
    0x7C66667C60606000, // 'P'
    0x3C66666666663D00, // 'Q'
    0x7C66667C786C6600, // 'R'
    0x3C66603C06663C00, // 'S'
    0x7E18181818181800, // 'T'
    0x6666666666663C00, // 'U'
    0x66666666663C1800, // 'V'
    0x636B6B7F77636300, // 'W'
    0x66663C183C666600, // 'X'
    0x66663C1818181800, // 'Y'
    0x7E060C1830607E00, // 'Z'
};

fn getFontChar(char: u8) u64 {
    if (char >= 32 and char <= 32 + FONT_DATA.len - 1) {
        return FONT_DATA[char - 32];
    }
    return FONT_DATA[0]; // Return space for unknown characters
}

fn drawChar(fb: *Framebuffer, x: u32, y: u32, char: u8, color: Color) void {
    const font_data = getFontChar(char);

    var row: u32 = 0;
    while (row < FONT_HEIGHT) : (row += 1) {
        const row_data = @as(u8, @truncate((font_data >> @intCast((7 - row) * 8)) & 0xFF));

        var col: u32 = 0;
        while (col < FONT_WIDTH) : (col += 1) {
            const bit = (row_data >> @intCast(7 - col)) & 1;
            if (bit != 0) {
                fb.setPixel(x + col, y + row, color);
            }
        }
    }
}

fn drawString(fb: *Framebuffer, x: u32, y: u32, text: []const u8, color: Color) void {
    for (text, 0..) |char, i| {
        drawChar(fb, x + @as(u32, @intCast(i)) * FONT_WIDTH, y, char, color);
    }
}

fn drawButton(fb: *Framebuffer, rect: Rect, text: []const u8, bg_color: Color, text_color: Color) void {
    // Draw button background
    fb.fillRect(rect.x, rect.y, rect.width, rect.height, bg_color);

    // Draw button border
    fb.drawLine(rect.x, rect.y, rect.x + rect.width - 1, rect.y, Color.WHITE);
    fb.drawLine(rect.x, rect.y, rect.x, rect.y + rect.height - 1, Color.WHITE);
    fb.drawLine(rect.x + rect.width - 1, rect.y, rect.x + rect.width - 1, rect.y + rect.height - 1, Color.GRAY);
    fb.drawLine(rect.x, rect.y + rect.height - 1, rect.x + rect.width - 1, rect.y + rect.height - 1, Color.GRAY);

    // Center text in button
    const text_width = text.len * FONT_WIDTH;
    const text_x = rect.x + (rect.width - @as(u32, @intCast(text_width))) / 2;
    const text_y = rect.y + (rect.height - FONT_HEIGHT) / 2;

    drawString(fb, text_x, text_y, text, text_color);
}

fn drawProgressBar(fb: *Framebuffer, rect: Rect, progress: f32) void {
    // Background
    fb.fillRect(rect.x, rect.y, rect.width, rect.height, Color.fromRgb(40, 40, 40));

    // Progress fill
    const fill_width = @as(u32, @intFromFloat(@as(f32, @floatFromInt(rect.width)) * @max(0.0, @min(1.0, progress))));
    if (fill_width > 0) {
        fb.fillRect(rect.x, rect.y, fill_width, rect.height, Color.fromRgb(0, 150, 255));
    }

    // Border
    fb.drawLine(rect.x, rect.y, rect.x + rect.width - 1, rect.y, Color.WHITE);
    fb.drawLine(rect.x, rect.y, rect.x, rect.y + rect.height - 1, Color.WHITE);
    fb.drawLine(rect.x + rect.width - 1, rect.y, rect.x + rect.width - 1, rect.y + rect.height - 1, Color.WHITE);
    fb.drawLine(rect.x, rect.y + rect.height - 1, rect.x + rect.width - 1, rect.y + rect.height - 1, Color.WHITE);
}

fn drawStatusBar(fb: *Framebuffer, width: u32) void {
    const status_height = 30;

    // Status bar background
    fb.fillRect(0, 0, width, status_height, Color.fromRgb(20, 20, 20));

    // Time (mock)
    drawString(fb, 10, 11, "12:34", Color.WHITE);

    // Battery indicator
    const battery_x = width - 60;
    const battery_rect = Rect{ .x = battery_x, .y = 8, .width = 40, .height = 14 };
    fb.fillRect(battery_rect.x, battery_rect.y, battery_rect.width, battery_rect.height, Color.fromRgb(60, 60, 60));
    fb.fillRect(battery_rect.x + 2, battery_rect.y + 2, 30, 10, Color.fromRgb(0, 200, 0)); // 75% battery

    // Battery tip
    fb.fillRect(battery_x + 40, battery_rect.y + 4, 3, 6, Color.fromRgb(60, 60, 60));

    // Signal strength (mock bars)
    for (0..4) |i| {
        const bar_height = @as(u32, @intCast((i + 1) * 3));
        const bar_x = width - 100 + @as(u32, @intCast(i)) * 6;
        fb.fillRect(bar_x, status_height - bar_height - 5, 4, bar_height, Color.WHITE);
    }
}

fn drawCircle(fb: *Framebuffer, center_x: u32, center_y: u32, radius: u32, color: Color) void {
    const cx = @as(i32, @intCast(center_x));
    const cy = @as(i32, @intCast(center_y));
    const r = @as(i32, @intCast(radius));

    var x: i32 = -r;
    while (x <= r) : (x += 1) {
        var y: i32 = -r;
        while (y <= r) : (y += 1) {
            if (x * x + y * y <= r * r) {
                const px = cx + x;
                const py = cy + y;
                if (px >= 0 and py >= 0) {
                    fb.setPixel(@intCast(px), @intCast(py), color);
                }
            }
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Configure display for mobile-like dimensions
    const config = DisplayConfig{
        .width = 1080,
        .height = 2340,
        .refresh_rate = 60,
        .pixel_format = .rgba8888,
        .vsync = true,
        .title = "Dowel-Steek Mobile OS Demo",
    };

    var display_manager = try DisplayManager.init(allocator, config);
    defer display_manager.deinit();

    try display_manager.initialize();
    std.log.info("Display demo started", .{});

    var frame_count: u32 = 0;
    var last_time = std.time.milliTimestamp();
    var animation_time: f32 = 0.0;
    var clicked_button: ?u8 = null;
    var click_time: f32 = 0.0;

    // Main render loop
    while (display_manager.handleEvents()) {
        const fb = display_manager.getFramebuffer();

        // Clear screen with dark background
        fb.clear(Color.fromRgb(25, 25, 30));

        // Draw status bar
        drawStatusBar(fb, config.width);

        // Demo title
        drawString(fb, 50, 50, "DOWEL-STEEK MOBILE OS", Color.WHITE);
        drawString(fb, 50, 70, "Display System Demo", Color.fromRgb(150, 150, 150));

        // System info
        var info_y: u32 = 120;
        drawString(fb, 50, info_y, "Resolution: 1080x2340", Color.WHITE);
        info_y += 20;
        drawString(fb, 50, info_y, "Pixel Format: RGBA8888", Color.WHITE);
        info_y += 20;
        drawString(fb, 50, info_y, "Refresh Rate: 60Hz", Color.WHITE);
        info_y += 40;

        // Performance metrics
        const metrics = display_manager.getMetrics();
        var fps_buffer: [32]u8 = undefined;
        const fps_str = std.fmt.bufPrint(&fps_buffer, "FPS: {d:.1}", .{metrics.fps}) catch "FPS: ???";
        drawString(fb, 50, info_y, fps_str, Color.fromRgb(100, 255, 100));
        info_y += 20;

        var frame_time_buffer: [32]u8 = undefined;
        const frame_time_str = std.fmt.bufPrint(&frame_time_buffer, "Frame Time: {d:.1}ms", .{metrics.frame_time_ms}) catch "Frame Time: ???";
        drawString(fb, 50, info_y, frame_time_str, Color.fromRgb(100, 255, 100));
        info_y += 40;

        // Animated progress bar
        const progress = (@sin(animation_time * 2.0) + 1.0) / 2.0;
        const progress_rect = Rect{ .x = 50, .y = info_y, .width = 300, .height = 20 };
        drawProgressBar(fb, progress_rect, progress);
        drawString(fb, 60, info_y + 30, "Animated Progress Bar", Color.WHITE);
        info_y += 80;

        // Sample buttons with click feedback
        const button1 = Rect{ .x = 50, .y = info_y, .width = 120, .height = 40 };
        const button1_color = if (clicked_button == 1 and click_time > 0) Color.fromRgb(120, 120, 120) else Color.fromRgb(70, 70, 70);
        drawButton(fb, button1, "Settings", button1_color, Color.WHITE);

        const button2 = Rect{ .x = 200, .y = info_y, .width = 120, .height = 40 };
        const button2_color = if (clicked_button == 2 and click_time > 0) Color.fromRgb(50, 170, 255) else Color.fromRgb(0, 120, 200);
        drawButton(fb, button2, "Apps", button2_color, Color.WHITE);

        const button3 = Rect{ .x = 350, .y = info_y, .width = 120, .height = 40 };
        const button3_color = if (clicked_button == 3 and click_time > 0) Color.fromRgb(255, 150, 50) else Color.fromRgb(200, 100, 0);
        drawButton(fb, button3, "Files", button3_color, Color.WHITE);
        info_y += 80;

        // Show click feedback
        if (clicked_button != null and click_time > 0) {
            const button_name = switch (clicked_button.?) {
                1 => "Settings clicked!",
                2 => "Apps clicked!",
                3 => "Files clicked!",
                else => "Unknown clicked!",
            };
            drawString(fb, 50, info_y, button_name, Color.fromRgb(255, 255, 0));
            info_y += 20;
        }

        // Animated shapes
        const center_x = config.width / 2;
        const center_y = info_y + 100;

        // Rotating circles
        for (0..5) |i| {
            const angle = animation_time + @as(f32, @floatFromInt(i)) * 1.256; // 72 degrees apart
            const orbit_radius = 80.0;
            const dx = @cos(angle) * orbit_radius;
            const dy = @sin(angle) * orbit_radius;

            // Safe bounds checking for position calculations
            const center_x_f = @as(f32, @floatFromInt(center_x));
            const center_y_f = @as(f32, @floatFromInt(center_y));
            const x_f = center_x_f + dx;
            const y_f = center_y_f + dy;

            // Clamp to screen bounds
            const x = if (x_f >= 0 and x_f < @as(f32, @floatFromInt(config.width)))
                @as(u32, @intFromFloat(x_f))
            else
                center_x;
            const y = if (y_f >= 0 and y_f < @as(f32, @floatFromInt(config.height)))
                @as(u32, @intFromFloat(y_f))
            else
                center_y;

            const colors = [_]Color{
                Color.RED,
                Color.GREEN,
                Color.BLUE,
                Color.fromRgb(255, 255, 0), // Yellow
                Color.fromRgb(255, 0, 255), // Magenta
            };

            drawCircle(fb, x, y, 15, colors[i]);
        }

        // Central circle
        drawCircle(fb, center_x, center_y, 25, Color.WHITE);

        // Demo information at bottom
        const bottom_y = config.height - 100;
        drawString(fb, 50, bottom_y, "Zig Core + Kotlin Apps", Color.fromRgb(150, 150, 150));
        drawString(fb, 50, bottom_y + 20, "Memory Safe - High Performance", Color.fromRgb(150, 150, 150));
        drawString(fb, 50, bottom_y + 40, "Press ESC to quit", Color.fromRgb(100, 100, 100));

        // Color gradient strip
        for (0..config.width) |i| {
            const hue = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(config.width)) * 360.0;
            const r = @as(u8, @intFromFloat((@sin(hue * 0.0174533) + 1.0) * 127.5));
            const g = @as(u8, @intFromFloat((@sin((hue + 120.0) * 0.0174533) + 1.0) * 127.5));
            const b = @as(u8, @intFromFloat((@sin((hue + 240.0) * 0.0174533) + 1.0) * 127.5));

            fb.fillRect(@intCast(i), config.height - 20, 1, 20, Color.fromRgb(r, g, b));
        }

        // Present frame
        try display_manager.present();

        // Update animation
        const current_time = std.time.milliTimestamp();
        const delta_time = @as(f32, @floatFromInt(current_time - last_time)) / 1000.0;
        animation_time += delta_time * 1.5; // Animation speed
        last_time = current_time;

        // Update click feedback timer
        if (click_time > 0) {
            click_time -= delta_time;
            if (click_time <= 0) {
                clicked_button = null;
            }
        }

        frame_count += 1;

        // Check for mouse clicks
        var mouse_x: c_int = 0;
        var mouse_y: c_int = 0;
        const mouse_pressed = c.SDL_GetMouseState(&mouse_x, &mouse_y) & c.SDL_BUTTON(c.SDL_BUTTON_LEFT) != 0;

        if (mouse_pressed and clicked_button == null) {
            // Check button clicks
            const button1_rect = Rect{ .x = 50, .y = info_y - 100, .width = 120, .height = 40 };
            const button2_rect = Rect{ .x = 200, .y = info_y - 100, .width = 120, .height = 40 };
            const button3_rect = Rect{ .x = 350, .y = info_y - 100, .width = 120, .height = 40 };

            if (button1_rect.contains(@intCast(mouse_x), @intCast(mouse_y))) {
                clicked_button = 1;
                click_time = 1.0; // Show feedback for 1 second
            } else if (button2_rect.contains(@intCast(mouse_x), @intCast(mouse_y))) {
                clicked_button = 2;
                click_time = 1.0;
            } else if (button3_rect.contains(@intCast(mouse_x), @intCast(mouse_y))) {
                clicked_button = 3;
                click_time = 1.0;
            }
        }

        // Cap framerate to ~60 FPS
        std.time.sleep(16_666_667); // ~16.67ms = 60 FPS

        if (display_manager.shouldClose()) {
            break;
        }
    }

    std.log.info("Display demo finished - rendered {} frames", .{frame_count});
    std.log.info("Final metrics: {d:.1} FPS, {d:.1}ms frame time", .{ display_manager.getMetrics().fps, display_manager.getMetrics().frame_time_ms });
}
