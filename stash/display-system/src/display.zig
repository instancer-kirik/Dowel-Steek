//! Display Manager for Dowel-Steek Mobile OS
//! Provides framebuffer management, compositing, and rendering services
//! Uses SDL2 backend for Linux emulation, can be swapped for direct framebuffer on hardware

const std = @import("std");
const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Allocator = std.mem.Allocator;

/// Error types for display operations
pub const DisplayError = error{
    InitializationFailed,
    WindowCreationFailed,
    RendererCreationFailed,
    TextureCreationFailed,
    InvalidDimensions,
    OutOfMemory,
    UnsupportedFormat,
    DeviceNotAvailable,
};

/// Pixel format types
pub const PixelFormat = enum(u32) {
    rgba8888 = c.SDL_PIXELFORMAT_RGBA8888,
    rgb888 = c.SDL_PIXELFORMAT_RGB888,
    rgb565 = c.SDL_PIXELFORMAT_RGB565,
    argb8888 = c.SDL_PIXELFORMAT_ARGB8888,

    pub fn bytesPerPixel(self: PixelFormat) u8 {
        return switch (self) {
            .rgba8888, .argb8888 => 4,
            .rgb888 => 3,
            .rgb565 => 2,
        };
    }
};

/// Display configuration
pub const DisplayConfig = struct {
    width: u32 = 1080,
    height: u32 = 2340, // Standard mobile aspect ratio (19.5:9)
    refresh_rate: u32 = 60,
    pixel_format: PixelFormat = .rgba8888,
    vsync: bool = true,
    fullscreen: bool = false,
    resizable: bool = true,
    title: []const u8 = "Dowel-Steek Mobile OS",
};

/// Framebuffer for direct pixel manipulation
pub const Framebuffer = struct {
    pixels: []u8,
    width: u32,
    height: u32,
    pitch: u32, // Bytes per row
    format: PixelFormat,

    pub fn init(allocator: Allocator, width: u32, height: u32, format: PixelFormat) !Framebuffer {
        const bytes_per_pixel = format.bytesPerPixel();
        const pitch = width * bytes_per_pixel;
        const size = pitch * height;

        const pixels = try allocator.alloc(u8, size);
        @memset(pixels, 0);

        return Framebuffer{
            .pixels = pixels,
            .width = width,
            .height = height,
            .pitch = pitch,
            .format = format,
        };
    }

    pub fn deinit(self: *Framebuffer, allocator: Allocator) void {
        allocator.free(self.pixels);
    }

    pub fn setPixel(self: *Framebuffer, x: u32, y: u32, color: Color) void {
        if (x >= self.width or y >= self.height) return;

        const bytes_per_pixel = self.format.bytesPerPixel();
        const offset = y * self.pitch + x * bytes_per_pixel;

        switch (self.format) {
            .rgba8888 => {
                self.pixels[offset + 0] = color.r;
                self.pixels[offset + 1] = color.g;
                self.pixels[offset + 2] = color.b;
                self.pixels[offset + 3] = color.a;
            },
            .argb8888 => {
                self.pixels[offset + 0] = color.a;
                self.pixels[offset + 1] = color.r;
                self.pixels[offset + 2] = color.g;
                self.pixels[offset + 3] = color.b;
            },
            .rgb888 => {
                self.pixels[offset + 0] = color.r;
                self.pixels[offset + 1] = color.g;
                self.pixels[offset + 2] = color.b;
            },
            .rgb565 => {
                const r5 = @as(u16, color.r) >> 3;
                const g6 = @as(u16, color.g) >> 2;
                const b5 = @as(u16, color.b) >> 3;
                const pixel = (r5 << 11) | (g6 << 5) | b5;
                std.mem.writeInt(u16, @ptrCast(self.pixels[offset .. offset + 2]), pixel, .little);
            },
        }
    }

    pub fn fillRect(self: *Framebuffer, x: u32, y: u32, w: u32, h: u32, color: Color) void {
        var py: u32 = y;
        while (py < y + h and py < self.height) : (py += 1) {
            var px: u32 = x;
            while (px < x + w and px < self.width) : (px += 1) {
                self.setPixel(px, py, color);
            }
        }
    }

    pub fn clear(self: *Framebuffer, color: Color) void {
        self.fillRect(0, 0, self.width, self.height, color);
    }

    pub fn drawLine(self: *Framebuffer, x0: u32, y0: u32, x1: u32, y1: u32, color: Color) void {
        // Bresenham's line algorithm
        const dx: i32 = @intCast(@abs(@as(i32, @intCast(x1)) - @as(i32, @intCast(x0))));
        const dy: i32 = @intCast(@abs(@as(i32, @intCast(y1)) - @as(i32, @intCast(y0))));
        const sx: i32 = if (x0 < x1) 1 else -1;
        const sy: i32 = if (y0 < y1) 1 else -1;
        var err: i32 = dx - dy;

        var x = @as(i32, @intCast(x0));
        var y = @as(i32, @intCast(y0));

        while (true) {
            self.setPixel(@intCast(x), @intCast(y), color);

            if (x == x1 and y == y1) break;

            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                x += sx;
            }
            if (e2 < dx) {
                err += dx;
                y += sy;
            }
        }
    }
};

/// Color representation
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,

    pub const BLACK = Color{ .r = 0, .g = 0, .b = 0 };
    pub const WHITE = Color{ .r = 255, .g = 255, .b = 255 };
    pub const RED = Color{ .r = 255, .g = 0, .b = 0 };
    pub const GREEN = Color{ .r = 0, .g = 255, .b = 0 };
    pub const BLUE = Color{ .r = 0, .g = 0, .b = 255 };
    pub const GRAY = Color{ .r = 128, .g = 128, .b = 128 };
    pub const TRANSPARENT = Color{ .r = 0, .g = 0, .b = 0, .a = 0 };

    pub fn fromRgb(r: u8, g: u8, b: u8) Color {
        return Color{ .r = r, .g = g, .b = b };
    }

    pub fn fromRgba(r: u8, g: u8, b: u8, a: u8) Color {
        return Color{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn fromHex(hex: u32) Color {
        return Color{
            .r = @truncate((hex >> 16) & 0xFF),
            .g = @truncate((hex >> 8) & 0xFF),
            .b = @truncate(hex & 0xFF),
        };
    }
};

/// Rectangle structure for clipping and layout
pub const Rect = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,

    pub fn contains(self: Rect, x: u32, y: u32) bool {
        return x >= self.x and x < self.x + self.width and
            y >= self.y and y < self.y + self.height;
    }

    pub fn intersect(self: Rect, other: Rect) ?Rect {
        const left = @max(self.x, other.x);
        const top = @max(self.y, other.y);
        const right = @min(self.x + self.width, other.x + other.width);
        const bottom = @min(self.y + self.height, other.y + other.height);

        if (left >= right or top >= bottom) return null;

        return Rect{
            .x = left,
            .y = top,
            .width = right - left,
            .height = bottom - top,
        };
    }
};

/// Performance metrics
pub const DisplayMetrics = struct {
    frame_count: u64 = 0,
    fps: f32 = 0.0,
    frame_time_ms: f32 = 0.0,
    last_frame_time: u64 = 0,
    render_time_ms: f32 = 0.0,
    memory_usage_bytes: usize = 0,
};

/// Main display manager
pub const DisplayManager = struct {
    const Self = @This();

    allocator: Allocator,
    config: DisplayConfig,
    window: ?*c.SDL_Window,
    renderer: ?*c.SDL_Renderer,
    texture: ?*c.SDL_Texture,
    framebuffer: Framebuffer,
    is_initialized: bool = false,
    should_quit: bool = false,
    metrics: DisplayMetrics = .{},

    pub fn init(allocator: Allocator, config: DisplayConfig) !Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .window = null,
            .renderer = null,
            .texture = null,
            .framebuffer = undefined,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.is_initialized) {
            self.shutdown();
        }
    }

    pub fn initialize(self: *Self) DisplayError!void {
        if (self.is_initialized) return;

        // Initialize SDL
        if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
            std.log.err("SDL_Init failed: {s}", .{c.SDL_GetError()});
            return DisplayError.InitializationFailed;
        }

        // Create window
        const window_flags: u32 = if (self.config.fullscreen) c.SDL_WINDOW_FULLSCREEN else 0;
        const resizable_flag: u32 = if (self.config.resizable) c.SDL_WINDOW_RESIZABLE else 0;

        self.window = c.SDL_CreateWindow(
            self.config.title.ptr,
            c.SDL_WINDOWPOS_CENTERED,
            c.SDL_WINDOWPOS_CENTERED,
            @intCast(self.config.width),
            @intCast(self.config.height),
            @as(u32, @as(u32, c.SDL_WINDOW_SHOWN) | @as(u32, @intCast(window_flags)) | @as(u32, @intCast(resizable_flag))),
        );

        if (self.window == null) {
            std.log.err("SDL_CreateWindow failed: {s}", .{c.SDL_GetError()});
            c.SDL_Quit();
            return DisplayError.WindowCreationFailed;
        }

        // Create renderer
        const renderer_flags: u32 = @as(u32, c.SDL_RENDERER_ACCELERATED) |
            (if (self.config.vsync) @as(u32, c.SDL_RENDERER_PRESENTVSYNC) else 0);

        self.renderer = c.SDL_CreateRenderer(self.window, -1, renderer_flags);
        if (self.renderer == null) {
            std.log.err("SDL_CreateRenderer failed: {s}", .{c.SDL_GetError()});
            c.SDL_DestroyWindow(self.window);
            c.SDL_Quit();
            return DisplayError.RendererCreationFailed;
        }

        // Create streaming texture for framebuffer
        self.texture = c.SDL_CreateTexture(
            self.renderer,
            @intFromEnum(self.config.pixel_format),
            c.SDL_TEXTUREACCESS_STREAMING,
            @intCast(self.config.width),
            @intCast(self.config.height),
        );

        if (self.texture == null) {
            std.log.err("SDL_CreateTexture failed: {s}", .{c.SDL_GetError()});
            c.SDL_DestroyRenderer(self.renderer);
            c.SDL_DestroyWindow(self.window);
            c.SDL_Quit();
            return DisplayError.TextureCreationFailed;
        }

        // Initialize framebuffer
        self.framebuffer = Framebuffer.init(
            self.allocator,
            self.config.width,
            self.config.height,
            self.config.pixel_format,
        ) catch |err| {
            c.SDL_DestroyTexture(self.texture);
            c.SDL_DestroyRenderer(self.renderer);
            c.SDL_DestroyWindow(self.window);
            c.SDL_Quit();
            return switch (err) {
                error.OutOfMemory => DisplayError.OutOfMemory,
            };
        };

        self.is_initialized = true;
        self.metrics.last_frame_time = @intCast(std.time.milliTimestamp());

        std.log.info("Display initialized: {}x{} @ {}Hz, format: {}", .{
            self.config.width,
            self.config.height,
            self.config.refresh_rate,
            self.config.pixel_format,
        });
    }

    pub fn shutdown(self: *Self) void {
        if (!self.is_initialized) return;

        self.framebuffer.deinit(self.allocator);

        if (self.texture != null) {
            c.SDL_DestroyTexture(self.texture);
            self.texture = null;
        }

        if (self.renderer != null) {
            c.SDL_DestroyRenderer(self.renderer);
            self.renderer = null;
        }

        if (self.window != null) {
            c.SDL_DestroyWindow(self.window);
            self.window = null;
        }

        c.SDL_Quit();
        self.is_initialized = false;

        std.log.info("Display shut down", .{});
    }

    pub fn getFramebuffer(self: *Self) *Framebuffer {
        return &self.framebuffer;
    }

    pub fn present(self: *Self) DisplayError!void {
        if (!self.is_initialized) return DisplayError.DeviceNotAvailable;

        const start_time = std.time.milliTimestamp();

        // Upload framebuffer to texture
        const result = c.SDL_UpdateTexture(
            self.texture,
            null,
            self.framebuffer.pixels.ptr,
            @intCast(self.framebuffer.pitch),
        );

        if (result != 0) {
            std.log.err("SDL_UpdateTexture failed: {s}", .{c.SDL_GetError()});
            return DisplayError.TextureCreationFailed;
        }

        // Clear and render
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderCopy(self.renderer, self.texture, null, null);
        c.SDL_RenderPresent(self.renderer);

        // Update metrics
        const current_time = std.time.milliTimestamp();
        self.metrics.render_time_ms = @floatFromInt(current_time - start_time);
        self.metrics.frame_time_ms = @floatFromInt(@as(i64, @intCast(current_time)) - @as(i64, @intCast(self.metrics.last_frame_time)));
        self.metrics.frame_count += 1;

        if (self.metrics.frame_time_ms > 0) {
            self.metrics.fps = 1000.0 / self.metrics.frame_time_ms;
        }

        self.metrics.last_frame_time = @intCast(current_time);
        self.metrics.memory_usage_bytes = self.framebuffer.pixels.len;
    }

    pub fn handleEvents(self: *Self) bool {
        var event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    self.should_quit = true;
                    return false;
                },
                c.SDL_KEYDOWN => {
                    if (event.key.keysym.sym == c.SDLK_ESCAPE) {
                        self.should_quit = true;
                        return false;
                    }
                },
                c.SDL_WINDOWEVENT => {
                    if (event.window.event == c.SDL_WINDOWEVENT_RESIZED) {
                        // Handle window resize
                        const new_width: u32 = @intCast(event.window.data1);
                        const new_height: u32 = @intCast(event.window.data2);
                        std.log.info("Window resized to {}x{}", .{ new_width, new_height });
                    }
                },
                else => {},
            }
        }

        return true;
    }

    pub fn shouldClose(self: *Self) bool {
        return self.should_quit;
    }

    pub fn getMetrics(self: *Self) DisplayMetrics {
        return self.metrics;
    }

    pub fn getDimensions(self: *Self) struct { width: u32, height: u32 } {
        return .{ .width = self.config.width, .height = self.config.height };
    }

    pub fn setTitle(self: *Self, title: []const u8) void {
        if (self.window != null) {
            const title_z = self.allocator.dupeZ(u8, title) catch return;
            defer self.allocator.free(title_z);
            c.SDL_SetWindowTitle(self.window, title_z.ptr);
        }
    }
};

// C API exports for Kotlin integration
export fn dowel_display_init(width: u32, height: u32) callconv(.C) c_int {
    _ = width;
    _ = height;
    // This would be implemented with a global display manager instance
    return 0; // Success
}

export fn dowel_display_shutdown() callconv(.C) void {
    // Cleanup global display manager
}

export fn dowel_display_get_framebuffer() callconv(.C) ?*anyopaque {
    // Return pointer to framebuffer data
    return null;
}

export fn dowel_display_present() callconv(.C) c_int {
    // Present current framebuffer to screen
    return 0; // Success
}

export fn dowel_display_get_dimensions(width: *u32, height: *u32) callconv(.C) void {
    // Fill in current display dimensions
    width.* = 1080;
    height.* = 2340;
}

// Unit tests
test "display manager initialization" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = DisplayConfig{
        .width = 800,
        .height = 600,
        .title = "Test Window",
    };

    var display = try DisplayManager.init(allocator, config);
    defer display.deinit();

    // Note: Can't actually test SDL initialization in unit tests
    // Would need integration tests for full display functionality
}

test "framebuffer operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var fb = try Framebuffer.init(allocator, 100, 100, .rgba8888);
    defer fb.deinit(allocator);

    // Test pixel setting
    fb.setPixel(10, 10, Color.RED);
    fb.fillRect(20, 20, 10, 10, Color.BLUE);
    fb.clear(Color.GREEN);

    // Test line drawing
    fb.drawLine(0, 0, 99, 99, Color.WHITE);

    try std.testing.expect(fb.width == 100);
    try std.testing.expect(fb.height == 100);
    try std.testing.expect(fb.pixels.len == 100 * 100 * 4);
}

test "color operations" {
    const red = Color.fromHex(0xFF0000);
    try std.testing.expect(red.r == 255);
    try std.testing.expect(red.g == 0);
    try std.testing.expect(red.b == 0);

    const rgba = Color.fromRgba(128, 64, 32, 128);
    try std.testing.expect(rgba.a == 128);
}

test "rectangle operations" {
    const rect1 = Rect{ .x = 10, .y = 10, .width = 20, .height = 20 };
    const rect2 = Rect{ .x = 20, .y = 20, .width = 20, .height = 20 };

    try std.testing.expect(rect1.contains(15, 15));
    try std.testing.expect(!rect1.contains(5, 5));

    const intersection = rect1.intersect(rect2);
    try std.testing.expect(intersection != null);
    try std.testing.expect(intersection.?.width == 10);
    try std.testing.expect(intersection.?.height == 10);
}
