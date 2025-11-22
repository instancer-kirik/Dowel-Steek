//! Configuration Management System
//!
//! This module provides a modern configuration system for the Dowel-Steek mobile OS.
//! It supports hierarchical configuration with user and system defaults,
//! real-time updates, and mobile-optimized storage.

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const StringHashMap = std.StringHashMap;

/// Configuration errors
pub const ConfigError = error{
    NotInitialized,
    InvalidPath,
    InvalidValue,
    ReadError,
    WriteError,
    ParseError,
    NotFound,
};

/// Configuration value types
pub const ConfigValue = union(enum) {
    string: []const u8,
    integer: i64,
    float: f64,
    boolean: bool,
    array: []ConfigValue,
    object: StringHashMap(ConfigValue),

    pub fn deinit(self: *ConfigValue, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .array => |arr| {
                for (arr) |*item| {
                    item.deinit(allocator);
                }
                allocator.free(arr);
            },
            .object => |*obj| {
                var iterator = obj.iterator();
                while (iterator.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                obj.deinit();
            },
            else => {},
        }
    }

    pub fn clone(self: ConfigValue, allocator: Allocator) !ConfigValue {
        return switch (self) {
            .string => |s| ConfigValue{ .string = try allocator.dupe(u8, s) },
            .integer => |i| ConfigValue{ .integer = i },
            .float => |f| ConfigValue{ .float = f },
            .boolean => |b| ConfigValue{ .boolean = b },
            .array => |arr| {
                const new_arr = try allocator.alloc(ConfigValue, arr.len);
                for (arr, 0..) |item, i| {
                    new_arr[i] = try item.clone(allocator);
                }
                return ConfigValue{ .array = new_arr };
            },
            .object => |obj| {
                var new_obj = StringHashMap(ConfigValue).init(allocator);
                var iterator = obj.iterator();
                while (iterator.next()) |entry| {
                    const key = try allocator.dupe(u8, entry.key_ptr.*);
                    const value = try entry.value_ptr.clone(allocator);
                    try new_obj.put(key, value);
                }
                return ConfigValue{ .object = new_obj };
            },
        };
    }
};

/// Configuration change callback
pub const ConfigChangeCallback = *const fn (path: []const u8, old_value: ?ConfigValue, new_value: ConfigValue) void;

/// Configuration manager
pub const ConfigManager = struct {
    allocator: Allocator,
    config_data: StringHashMap(ConfigValue),
    config_path: []const u8,
    system_config_path: []const u8,
    change_callbacks: ArrayList(struct {
        path_pattern: []const u8,
        callback: ConfigChangeCallback,
    }),
    initialized: bool,

    const Self = @This();

    /// Default configuration paths
    const DEFAULT_USER_CONFIG_DIR = ".config/dowel-steek";
    const DEFAULT_SYSTEM_CONFIG_DIR = "/etc/dowel-steek";
    const CONFIG_FILE_NAME = "config.toml";

    pub fn init(allocator: Allocator) !Self {
        const home_dir = std.process.getEnvVarOwned(allocator, "HOME") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => try allocator.dupe(u8, "/tmp"),
            else => return err,
        };
        defer allocator.free(home_dir);

        const user_config_dir = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, DEFAULT_USER_CONFIG_DIR });
        const config_path = try std.fs.path.join(allocator, &[_][]const u8{ user_config_dir, CONFIG_FILE_NAME });
        const system_config_path = try std.fs.path.join(allocator, &[_][]const u8{ DEFAULT_SYSTEM_CONFIG_DIR, CONFIG_FILE_NAME });

        // Ensure config directory exists
        std.fs.makeDirAbsolute(user_config_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        var manager = Self{
            .allocator = allocator,
            .config_data = StringHashMap(ConfigValue).init(allocator),
            .config_path = config_path,
            .system_config_path = system_config_path,
            .change_callbacks = ArrayList(@TypeOf(Self.change_callbacks).Child).init(allocator),
            .initialized = false,
        };

        try manager.loadDefaults();
        try manager.loadSystemConfig();
        try manager.loadUserConfig();

        manager.initialized = true;
        return manager;
    }

    pub fn deinit(self: *Self) void {
        self.saveUserConfig() catch |err| {
            std.log.warn("Failed to save config on shutdown: {}", .{err});
        };

        // Free all config values
        var iterator = self.config_data.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.config_data.deinit();

        // Free callback data
        for (self.change_callbacks.items) |callback_info| {
            self.allocator.free(callback_info.path_pattern);
        }
        self.change_callbacks.deinit();

        self.allocator.free(self.config_path);
        self.allocator.free(self.system_config_path);
        self.initialized = false;
    }

    fn loadDefaults(self: *Self) !void {
        // General settings
        try self.setValueInternal("general.theme", ConfigValue{ .string = try self.allocator.dupe(u8, "system") });
        try self.setValueInternal("general.language", ConfigValue{ .string = try self.allocator.dupe(u8, "en") });
        try self.setValueInternal("general.auto_save", ConfigValue{ .boolean = true });
        try self.setValueInternal("general.animation_scale", ConfigValue{ .float = 1.0 });

        // UI settings
        try self.setValueInternal("ui.touch_feedback", ConfigValue{ .boolean = true });
        try self.setValueInternal("ui.gesture_navigation", ConfigValue{ .boolean = true });
        try self.setValueInternal("ui.font_size", ConfigValue{ .integer = 16 });
        try self.setValueInternal("ui.toolbar_position", ConfigValue{ .string = try self.allocator.dupe(u8, "bottom") });

        // Performance settings
        try self.setValueInternal("performance.background_refresh", ConfigValue{ .boolean = true });
        try self.setValueInternal("performance.cache_size_mb", ConfigValue{ .integer = 256 });
        try self.setValueInternal("performance.preload_content", ConfigValue{ .boolean = false });

        // Privacy settings
        try self.setValueInternal("privacy.analytics", ConfigValue{ .boolean = false });
        try self.setValueInternal("privacy.crash_reports", ConfigValue{ .boolean = true });
        try self.setValueInternal("privacy.location_access", ConfigValue{ .string = try self.allocator.dupe(u8, "ask") });

        // Notification settings
        try self.setValueInternal("notifications.enabled", ConfigValue{ .boolean = true });
        try self.setValueInternal("notifications.vibration", ConfigValue{ .boolean = true });
        try self.setValueInternal("notifications.sound", ConfigValue{ .boolean = true });
        try self.setValueInternal("notifications.priority_filter", ConfigValue{ .string = try self.allocator.dupe(u8, "normal") });

        // App-specific defaults
        try self.setValueInternal("apps.notes.auto_backup", ConfigValue{ .boolean = true });
        try self.setValueInternal("apps.notes.markdown_preview", ConfigValue{ .boolean = true });
        try self.setValueInternal("apps.files.show_hidden", ConfigValue{ .boolean = false });
        try self.setValueInternal("apps.terminal.font_family", ConfigValue{ .string = try self.allocator.dupe(u8, "monospace") });
        try self.setValueInternal("apps.terminal.font_size", ConfigValue{ .integer = 14 });
    }

    fn loadSystemConfig(self: *Self) !void {
        const file = std.fs.openFileAbsolute(self.system_config_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return, // System config is optional
            else => return err,
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB max
        defer self.allocator.free(content);

        try self.parseAndMergeConfig(content, false); // Don't trigger callbacks for system config
    }

    fn loadUserConfig(self: *Self) !void {
        const file = std.fs.openFileAbsolute(self.config_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return, // User config is optional on first run
            else => return err,
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024); // 1MB max
        defer self.allocator.free(content);

        try self.parseAndMergeConfig(content, false); // Don't trigger callbacks during load
    }

    fn saveUserConfig(self: *Self) !void {
        if (!self.initialized) return;

        const file = try std.fs.createFileAbsolute(self.config_path, .{});
        defer file.close();

        try self.writeConfigToFile(file);
    }

    fn parseAndMergeConfig(self: *Self, content: []const u8, trigger_callbacks: bool) !void {
        // Simple TOML-like parser (basic implementation)
        // In a production system, you'd use a proper TOML parser
        var lines = std.mem.split(u8, content, "\n");
        var current_section: ?[]const u8 = null;

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
                // Section header
                if (current_section) |section| {
                    self.allocator.free(section);
                }
                current_section = try self.allocator.dupe(u8, trimmed[1 .. trimmed.len - 1]);
                continue;
            }

            if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
                const key_part = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                const value_part = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

                const full_key = if (current_section) |section|
                    try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ section, key_part })
                else
                    try self.allocator.dupe(u8, key_part);
                defer self.allocator.free(full_key);

                const value = try self.parseValue(value_part);
                if (trigger_callbacks) {
                    try self.setValue(full_key, value);
                } else {
                    try self.setValueInternal(full_key, value);
                }
            }
        }

        if (current_section) |section| {
            self.allocator.free(section);
        }
    }

    fn parseValue(self: *Self, value_str: []const u8) !ConfigValue {
        const trimmed = std.mem.trim(u8, value_str, " \t");

        // String value (quoted)
        if (trimmed.len >= 2 and trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') {
            const content = trimmed[1 .. trimmed.len - 1];
            return ConfigValue{ .string = try self.allocator.dupe(u8, content) };
        }

        // Boolean values
        if (std.mem.eql(u8, trimmed, "true")) {
            return ConfigValue{ .boolean = true };
        }
        if (std.mem.eql(u8, trimmed, "false")) {
            return ConfigValue{ .boolean = false };
        }

        // Try to parse as integer
        if (std.fmt.parseInt(i64, trimmed, 10)) |int_val| {
            return ConfigValue{ .integer = int_val };
        } else |_| {
            // Try to parse as float
            if (std.fmt.parseFloat(f64, trimmed)) |float_val| {
                return ConfigValue{ .float = float_val };
            } else |_| {
                // Default to string (unquoted)
                return ConfigValue{ .string = try self.allocator.dupe(u8, trimmed) };
            }
        }
    }

    fn writeConfigToFile(self: *Self, file: std.fs.File) !void {
        var writer = file.writer();

        // Group keys by section
        var sections = StringHashMap(ArrayList([]const u8)).init(self.allocator);
        defer {
            var section_iter = sections.iterator();
            while (section_iter.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                entry.value_ptr.deinit();
            }
            sections.deinit();
        }

        var config_iter = self.config_data.iterator();
        while (config_iter.next()) |entry| {
            const key = entry.key_ptr.*;
            if (std.mem.indexOf(u8, key, ".")) |dot_pos| {
                const section_name = key[0..dot_pos];

                const result = try sections.getOrPut(try self.allocator.dupe(u8, section_name));
                if (!result.found_existing) {
                    result.value_ptr.* = ArrayList([]const u8).init(self.allocator);
                }
                try result.value_ptr.append(key);
            }
        }

        // Write sections
        var section_iter = sections.iterator();
        while (section_iter.next()) |entry| {
            const section_name = entry.key_ptr.*;
            const keys = entry.value_ptr.*;

            try writer.print("\n[{s}]\n", .{section_name});

            for (keys.items) |key| {
                if (std.mem.indexOf(u8, key, ".")) |dot_pos| {
                    const key_name = key[dot_pos + 1 ..];
                    const value = self.config_data.get(key).?;
                    try self.writeValue(writer, key_name, value);
                }
            }
        }
    }

    fn writeValue(_: *Self, writer: anytype, key: []const u8, value: ConfigValue) !void {
        try writer.print("{s} = ", .{key});
        switch (value) {
            .string => |s| try writer.print("\"{s}\"\n", .{s}),
            .integer => |i| try writer.print("{d}\n", .{i}),
            .float => |f| try writer.print("{d}\n", .{f}),
            .boolean => |b| try writer.print("{}\n", .{b}),
            else => try writer.print("null\n", .{}), // Simplified for arrays/objects
        }
    }

    fn setValueInternal(self: *Self, path: []const u8, value: ConfigValue) !void {
        const key = try self.allocator.dupe(u8, path);

        // Free existing value if it exists
        if (self.config_data.fetchRemove(key)) |existing| {
            self.allocator.free(existing.key);
            existing.value.deinit(self.allocator);
        }

        try self.config_data.put(key, value);
    }

    /// Set a configuration value and trigger callbacks
    pub fn setValue(self: *Self, path: []const u8, value: ConfigValue) !void {
        if (!self.initialized) return ConfigError.NotInitialized;

        const old_value = self.config_data.get(path);
        try self.setValueInternal(path, try value.clone(self.allocator));

        // Trigger callbacks
        for (self.change_callbacks.items) |callback_info| {
            if (self.pathMatches(path, callback_info.path_pattern)) {
                callback_info.callback(path, old_value, value);
            }
        }

        // Auto-save user config
        self.saveUserConfig() catch |err| {
            std.log.warn("Failed to auto-save config: {}", .{err});
        };
    }

    /// Get a configuration value
    pub fn getValue(self: *Self, path: []const u8) ?ConfigValue {
        if (!self.initialized) return null;
        return self.config_data.get(path);
    }

    /// Get a string value with default
    pub fn getString(self: *Self, path: []const u8, default_value: []const u8) []const u8 {
        if (self.getValue(path)) |value| {
            return switch (value) {
                .string => |s| s,
                else => default_value,
            };
        }
        return default_value;
    }

    /// Get an integer value with default
    pub fn getInt(self: *Self, path: []const u8, default_value: i64) i64 {
        if (self.getValue(path)) |value| {
            return switch (value) {
                .integer => |i| i,
                else => default_value,
            };
        }
        return default_value;
    }

    /// Get a float value with default
    pub fn getFloat(self: *Self, path: []const u8, default_value: f64) f64 {
        if (self.getValue(path)) |value| {
            return switch (value) {
                .float => |f| f,
                else => default_value,
            };
        }
        return default_value;
    }

    /// Get a boolean value with default
    pub fn getBool(self: *Self, path: []const u8, default_value: bool) bool {
        if (self.getValue(path)) |value| {
            return switch (value) {
                .boolean => |b| b,
                else => default_value,
            };
        }
        return default_value;
    }

    /// Register a callback for configuration changes
    pub fn onChange(self: *Self, path_pattern: []const u8, callback: ConfigChangeCallback) !void {
        try self.change_callbacks.append(.{
            .path_pattern = try self.allocator.dupe(u8, path_pattern),
            .callback = callback,
        });
    }

    fn pathMatches(self: *Self, path: []const u8, pattern: []const u8) bool {
        // Simple pattern matching (supports wildcards with *)
        _ = self;
        if (std.mem.eql(u8, pattern, "*")) return true;
        if (std.mem.indexOf(u8, pattern, "*")) |star_pos| {
            const prefix = pattern[0..star_pos];
            const suffix = pattern[star_pos + 1 ..];
            return std.mem.startsWith(u8, path, prefix) and std.mem.endsWith(u8, path, suffix);
        }
        return std.mem.eql(u8, path, pattern);
    }
};

// Global instance
var global_config: ?ConfigManager = null;
var init_mutex = std.Thread.Mutex{};

/// Initialize the global configuration manager
pub fn init() !void {
    init_mutex.lock();
    defer init_mutex.unlock();

    if (global_config != null) return;

    const allocator = std.heap.c_allocator;
    global_config = try ConfigManager.init(allocator);
}

/// Shutdown the global configuration manager
pub fn shutdown() void {
    init_mutex.lock();
    defer init_mutex.unlock();

    if (global_config) |*config| {
        config.deinit();
        global_config = null;
    }
}

/// Check if the configuration system is initialized
pub fn is_initialized() bool {
    return global_config != null;
}

/// Get the global configuration manager instance
pub fn instance() !*ConfigManager {
    if (global_config) |*config| {
        return config;
    }
    return ConfigError.NotInitialized;
}

// C API exports
export fn dowel_config_get_string(path: [*:0]const u8, default_value: [*:0]const u8) callconv(.C) [*:0]const u8 {
    const config = instance() catch return default_value;
    const path_slice = std.mem.span(path);
    const default_slice = std.mem.span(default_value);
    const result = config.getString(path_slice, default_slice);

    // Need to ensure the returned string is null-terminated and persistent
    const c_string = std.heap.c_allocator.dupeZ(u8, result) catch return default_value;
    return c_string.ptr;
}

export fn dowel_config_get_int(path: [*:0]const u8, default_value: i64) callconv(.C) i64 {
    const config = instance() catch return default_value;
    const path_slice = std.mem.span(path);
    return config.getInt(path_slice, default_value);
}

export fn dowel_config_get_bool(path: [*:0]const u8, default_value: bool) callconv(.C) bool {
    const config = instance() catch return default_value;
    const path_slice = std.mem.span(path);
    return config.getBool(path_slice, default_value);
}

export fn dowel_config_set_string(path: [*:0]const u8, value: [*:0]const u8) callconv(.C) c_int {
    const config = instance() catch return -1;
    const path_slice = std.mem.span(path);
    const value_slice = std.mem.span(value);

    const config_value = ConfigValue{ .string = std.heap.c_allocator.dupe(u8, value_slice) catch return -2 };
    config.setValue(path_slice, config_value) catch return -3;
    return 0;
}

export fn dowel_config_set_int(path: [*:0]const u8, value: i64) callconv(.C) c_int {
    const config = instance() catch return -1;
    const path_slice = std.mem.span(path);

    const config_value = ConfigValue{ .integer = value };
    config.setValue(path_slice, config_value) catch return -2;
    return 0;
}

export fn dowel_config_set_bool(path: [*:0]const u8, value: bool) callconv(.C) c_int {
    const config = instance() catch return -1;
    const path_slice = std.mem.span(path);

    const config_value = ConfigValue{ .boolean = value };
    config.setValue(path_slice, config_value) catch return -2;
    return 0;
}

// Tests
test "config initialization and basic operations" {
    const allocator = std.testing.allocator;
    var config = try ConfigManager.init(allocator);
    defer config.deinit();

    // Test default values
    const theme = config.getString("general.theme", "unknown");
    try std.testing.expectEqualStrings("system", theme);

    const touch_feedback = config.getBool("ui.touch_feedback", false);
    try std.testing.expect(touch_feedback == true);

    // Test setting values
    try config.setValue("test.string", ConfigValue{ .string = try allocator.dupe(u8, "test_value") });
    const retrieved = config.getString("test.string", "default");
    try std.testing.expectEqualStrings("test_value", retrieved);
}

test "config value types" {
    const allocator = std.testing.allocator;
    var config = try ConfigManager.init(allocator);
    defer config.deinit();

    // Test integer
    try config.setValue("test.int", ConfigValue{ .integer = 42 });
    const int_val = config.getInt("test.int", 0);
    try std.testing.expect(int_val == 42);

    // Test float
    try config.setValue("test.float", ConfigValue{ .float = 3.14 });
    const float_val = config.getFloat("test.float", 0.0);
    try std.testing.expect(float_val == 3.14);

    // Test boolean
    try config.setValue("test.bool", ConfigValue{ .boolean = true });
    const bool_val = config.getBool("test.bool", false);
    try std.testing.expect(bool_val == true);
}
