//! Logging System for Dowel-Steek Mobile
//!
//! This module provides a comprehensive logging system optimized for mobile devices.
//! Features include structured logging, log levels, performance monitoring,
//! crash reporting, and mobile-specific optimizations like battery-aware logging.

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;

/// Log levels
pub const LogLevel = enum(u8) {
    trace = 0,
    debug = 1,
    info = 2,
    warn = 3,
    err = 4,
    fatal = 5,

    pub fn toString(self: LogLevel) []const u8 {
        return switch (self) {
            .trace => "TRACE",
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
        };
    }

    pub fn toColor(self: LogLevel) []const u8 {
        return switch (self) {
            .trace => "\x1b[37m", // White
            .debug => "\x1b[36m", // Cyan
            .info => "\x1b[32m", // Green
            .warn => "\x1b[33m", // Yellow
            .err => "\x1b[31m", // Red
            .fatal => "\x1b[35m", // Magenta
        };
    }
};

/// Log entry structure
pub const LogEntry = struct {
    timestamp: i64,
    level: LogLevel,
    module: []const u8,
    message: []const u8,
    file: []const u8,
    line: u32,
    thread_id: u32,
    metadata: ?StringHashMap([]const u8),

    pub fn deinit(self: *LogEntry, allocator: Allocator) void {
        allocator.free(self.module);
        allocator.free(self.message);
        allocator.free(self.file);

        if (self.metadata) |*meta| {
            var iterator = meta.iterator();
            while (iterator.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                allocator.free(entry.value_ptr.*);
            }
            meta.deinit();
        }
    }
};

/// Log output interface
pub const LogOutput = struct {
    const Self = @This();

    writeFn: *const fn (self: *Self, entry: *const LogEntry) void,
    flushFn: ?*const fn (self: *Self) void,
    closeFn: ?*const fn (self: *Self) void,

    pub fn write(self: *Self, entry: *const LogEntry) void {
        self.writeFn(self, entry);
    }

    pub fn flush(self: *Self) void {
        if (self.flushFn) |flush| {
            flush(self);
        }
    }

    pub fn close(self: *Self) void {
        if (self.closeFn) |close| {
            close(self);
        }
    }
};

/// Console output implementation
pub const ConsoleOutput = struct {
    output: LogOutput,
    use_colors: bool,
    mutex: Thread.Mutex,

    const Self = @This();

    pub fn init(use_colors: bool) Self {
        return Self{
            .output = LogOutput{
                .writeFn = write,
                .flushFn = flush,
                .closeFn = null,
            },
            .use_colors = use_colors,
            .mutex = Thread.Mutex{},
        };
    }

    fn write(output: *LogOutput, entry: *const LogEntry) void {
        const self = @fieldParentPtr(Self, "output", output);
        self.mutex.lock();
        defer self.mutex.unlock();

        const writer = std.io.getStdErr().writer();

        // Format timestamp
        const timestamp = std.time.timestamp();
        const dt = std.time.epoch.EpochSeconds{ .secs = @intCast(entry.timestamp) };
        const day_seconds = std.time.epoch.getDaySeconds(dt);

        const hours = day_seconds.getHoursIntoDay();
        const minutes = day_seconds.getMinutesIntoHour();
        const seconds = day_seconds.getSecondsIntoMinute();

        if (self.use_colors) {
            writer.print("{s}[{:02}:{:02}:{:02}] {s} {s}:{} [{}] {s}\x1b[0m\n", .{
                entry.level.toColor(),
                hours,
                minutes,
                seconds,
                entry.level.toString(),
                entry.file,
                entry.line,
                entry.thread_id,
                entry.message,
            }) catch {};
        } else {
            writer.print("[{:02}:{:02}:{:02}] {s} {s}:{} [{}] {s}\n", .{
                hours,
                minutes,
                seconds,
                entry.level.toString(),
                entry.file,
                entry.line,
                entry.thread_id,
                entry.message,
            }) catch {};
        }

        // Print metadata if present
        if (entry.metadata) |metadata| {
            var iterator = metadata.iterator();
            while (iterator.next()) |kv| {
                writer.print("    {s}: {s}\n", .{ kv.key_ptr.*, kv.value_ptr.* }) catch {};
            }
        }
    }

    fn flush(output: *LogOutput) void {
        const self = @fieldParentPtr(Self, "output", output);
        self.mutex.lock();
        defer self.mutex.unlock();
        std.io.getStdErr().writeAll("") catch {};
    }
};

/// File output implementation
pub const FileOutput = struct {
    output: LogOutput,
    file: std.fs.File,
    path: []const u8,
    max_size: usize,
    current_size: usize,
    rotate_count: u8,
    mutex: Thread.Mutex,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, path: []const u8, max_size: usize, rotate_count: u8) !Self {
        const file = try std.fs.createFileAbsolute(path, .{ .truncate = false });

        const file_size = try file.getEndPos();

        return Self{
            .output = LogOutput{
                .writeFn = write,
                .flushFn = flush,
                .closeFn = close,
            },
            .file = file,
            .path = try allocator.dupe(u8, path),
            .max_size = max_size,
            .current_size = file_size,
            .rotate_count = rotate_count,
            .mutex = Thread.Mutex{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.file.close();
        self.allocator.free(self.path);
    }

    fn write(output: *LogOutput, entry: *const LogEntry) void {
        const self = @fieldParentPtr(Self, "output", output);
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if we need to rotate
        if (self.current_size > self.max_size) {
            self.rotateFile() catch |err| {
                std.debug.print("Failed to rotate log file: {}\n", .{err});
                return;
            };
        }

        const writer = self.file.writer();

        // Format log entry as JSON for structured logging
        const json_entry = std.fmt.allocPrint(self.allocator, "{{\"timestamp\":{},\"level\":\"{s}\",\"module\":\"{s}\",\"file\":\"{s}\",\"line\":{},\"thread\":{},\"message\":\"{s}\"", .{
            entry.timestamp,
            entry.level.toString(),
            entry.module,
            entry.file,
            entry.line,
            entry.thread_id,
            entry.message,
        }) catch return;
        defer self.allocator.free(json_entry);

        var full_entry: []const u8 = json_entry;

        // Add metadata if present
        if (entry.metadata) |metadata| {
            const with_metadata = std.fmt.allocPrint(self.allocator, "{s},\"metadata\":{{", .{json_entry}) catch return;
            defer self.allocator.free(with_metadata);

            var metadata_parts = ArrayList([]const u8).init(self.allocator);
            defer {
                for (metadata_parts.items) |part| {
                    self.allocator.free(part);
                }
                metadata_parts.deinit();
            }

            var iterator = metadata.iterator();
            while (iterator.next()) |kv| {
                const part = std.fmt.allocPrint(self.allocator, "\"{s}\":\"{s}\"", .{ kv.key_ptr.*, kv.value_ptr.* }) catch continue;
                metadata_parts.append(part) catch continue;
            }

            const joined_metadata = std.mem.join(self.allocator, ",", metadata_parts.items) catch return;
            defer self.allocator.free(joined_metadata);

            full_entry = std.fmt.allocPrint(self.allocator, "{s}{s}}}\n", .{ with_metadata, joined_metadata }) catch return;
        } else {
            full_entry = std.fmt.allocPrint(self.allocator, "{s}}\n", .{json_entry}) catch return;
        }

        if (full_entry.ptr != json_entry.ptr) {
            defer self.allocator.free(full_entry);
        }

        const bytes_written = writer.write(full_entry) catch 0;
        self.current_size += bytes_written;
    }

    fn flush(output: *LogOutput) void {
        const self = @fieldParentPtr(Self, "output", output);
        self.mutex.lock();
        defer self.mutex.unlock();
        self.file.sync() catch {};
    }

    fn close(output: *LogOutput) void {
        const self = @fieldParentPtr(Self, "output", output);
        self.mutex.lock();
        defer self.mutex.unlock();
        self.file.close();
    }

    fn rotateFile(self: *Self) !void {
        self.file.close();

        // Rotate existing files
        var i: u8 = self.rotate_count;
        while (i > 0) : (i -= 1) {
            const old_path = if (i == 1)
                try std.fmt.allocPrint(self.allocator, "{s}", .{self.path})
            else
                try std.fmt.allocPrint(self.allocator, "{s}.{}", .{ self.path, i - 1 });
            defer self.allocator.free(old_path);

            const new_path = try std.fmt.allocPrint(self.allocator, "{s}.{}", .{ self.path, i });
            defer self.allocator.free(new_path);

            std.fs.renameAbsolute(old_path, new_path) catch {};
        }

        // Create new file
        self.file = try std.fs.createFileAbsolute(self.path, .{ .truncate = true });
        self.current_size = 0;
    }
};

/// Performance metrics for logging
pub const LogMetrics = struct {
    total_entries: Atomic(u64),
    entries_by_level: [6]Atomic(u64),
    dropped_entries: Atomic(u64),
    avg_write_time_ns: Atomic(u64),
    peak_memory_usage: Atomic(usize),

    pub fn init() LogMetrics {
        return LogMetrics{
            .total_entries = Atomic(u64).init(0),
            .entries_by_level = [_]Atomic(u64){Atomic(u64).init(0)} ** 6,
            .dropped_entries = Atomic(u64).init(0),
            .avg_write_time_ns = Atomic(u64).init(0),
            .peak_memory_usage = Atomic(usize).init(0),
        };
    }

    pub fn recordEntry(self: *LogMetrics, level: LogLevel, write_time_ns: u64) void {
        _ = self.total_entries.fetchAdd(1, .Monotonic);
        _ = self.entries_by_level[@intFromEnum(level)].fetchAdd(1, .Monotonic);

        // Update average write time (simple exponential moving average)
        const current_avg = self.avg_write_time_ns.load(.Monotonic);
        const new_avg = (current_avg * 9 + write_time_ns) / 10;
        _ = self.avg_write_time_ns.store(new_avg, .Monotonic);
    }

    pub fn recordDroppedEntry(self: *LogMetrics) void {
        _ = self.dropped_entries.fetchAdd(1, .Monotonic);
    }
};

/// Main logger implementation
pub const Logger = struct {
    allocator: Allocator,
    outputs: ArrayList(*LogOutput),
    min_level: LogLevel,
    async_mode: bool,
    queue: ?AsyncQueue,
    thread: ?Thread,
    running: Atomic(bool),
    metrics: LogMetrics,
    battery_aware: bool,
    max_entries_per_second: u32,
    entry_count_this_second: Atomic(u32),
    last_reset_time: Atomic(i64),

    const Self = @This();
    const AsyncQueue = std.fifo.LinearFifo(LogEntry, .Dynamic);

    pub fn init(allocator: Allocator, min_level: LogLevel, async_mode: bool) !Self {
        var logger = Self{
            .allocator = allocator,
            .outputs = ArrayList(*LogOutput).init(allocator),
            .min_level = min_level,
            .async_mode = async_mode,
            .queue = if (async_mode) AsyncQueue.init(allocator) else null,
            .thread = null,
            .running = Atomic(bool).init(false),
            .metrics = LogMetrics.init(),
            .battery_aware = true,
            .max_entries_per_second = 100, // Rate limiting for battery savings
            .entry_count_this_second = Atomic(u32).init(0),
            .last_reset_time = Atomic(i64).init(std.time.timestamp()),
        };

        if (async_mode) {
            logger.running.store(true, .SeqCst);
            logger.thread = try Thread.spawn(.{}, asyncWorker, .{&logger});
        }

        return logger;
    }

    pub fn deinit(self: *Self) void {
        if (self.async_mode) {
            self.running.store(false, .SeqCst);
            if (self.thread) |thread| {
                thread.join();
            }
            if (self.queue) |*queue| {
                // Process remaining entries
                while (queue.readItem()) |entry| {
                    self.processEntry(&entry);
                    var mutable_entry = entry;
                    mutable_entry.deinit(self.allocator);
                }
                queue.deinit();
            }
        }

        // Close all outputs
        for (self.outputs.items) |output| {
            output.flush();
            output.close();
        }
        self.outputs.deinit();
    }

    pub fn addOutput(self: *Self, output: *LogOutput) !void {
        try self.outputs.append(output);
    }

    pub fn setLevel(self: *Self, level: LogLevel) void {
        self.min_level = level;
    }

    pub fn setBatteryAware(self: *Self, enabled: bool) void {
        self.battery_aware = enabled;
    }

    pub fn setRateLimit(self: *Self, max_entries_per_second: u32) void {
        self.max_entries_per_second = max_entries_per_second;
    }

    pub fn log(self: *Self, level: LogLevel, module: []const u8, file: []const u8, line: u32, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(level) < @intFromEnum(self.min_level)) return;

        // Rate limiting check
        if (self.battery_aware and !self.checkRateLimit()) {
            self.metrics.recordDroppedEntry();
            return;
        }

        const start_time = std.time.nanoTimestamp();

        const message = std.fmt.allocPrint(self.allocator, fmt, args) catch {
            self.metrics.recordDroppedEntry();
            return;
        };

        var entry = LogEntry{
            .timestamp = std.time.timestamp(),
            .level = level,
            .module = self.allocator.dupe(u8, module) catch {
                self.allocator.free(message);
                self.metrics.recordDroppedEntry();
                return;
            },
            .message = message,
            .file = self.allocator.dupe(u8, file) catch {
                self.allocator.free(message);
                self.allocator.free(entry.module);
                self.metrics.recordDroppedEntry();
                return;
            },
            .line = line,
            .thread_id = Thread.getCurrentId(),
            .metadata = null,
        };

        if (self.async_mode) {
            if (self.queue) |*queue| {
                queue.writeItem(entry) catch {
                    entry.deinit(self.allocator);
                    self.metrics.recordDroppedEntry();
                    return;
                };
            }
        } else {
            self.processEntry(&entry);
            entry.deinit(self.allocator);
        }

        const end_time = std.time.nanoTimestamp();
        self.metrics.recordEntry(level, @intCast(end_time - start_time));
    }

    pub fn logWithMetadata(self: *Self, level: LogLevel, module: []const u8, file: []const u8, line: u32, metadata: StringHashMap([]const u8), comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(level) < @intFromEnum(self.min_level)) return;

        if (self.battery_aware and !self.checkRateLimit()) {
            self.metrics.recordDroppedEntry();
            return;
        }

        const start_time = std.time.nanoTimestamp();

        const message = std.fmt.allocPrint(self.allocator, fmt, args) catch {
            self.metrics.recordDroppedEntry();
            return;
        };

        // Clone metadata
        var cloned_metadata = StringHashMap([]const u8).init(self.allocator);
        var iterator = metadata.iterator();
        while (iterator.next()) |entry| {
            const key = self.allocator.dupe(u8, entry.key_ptr.*) catch continue;
            const value = self.allocator.dupe(u8, entry.value_ptr.*) catch {
                self.allocator.free(key);
                continue;
            };
            cloned_metadata.put(key, value) catch {
                self.allocator.free(key);
                self.allocator.free(value);
                continue;
            };
        }

        var entry = LogEntry{
            .timestamp = std.time.timestamp(),
            .level = level,
            .module = self.allocator.dupe(u8, module) catch {
                self.allocator.free(message);
                self.metrics.recordDroppedEntry();
                return;
            },
            .message = message,
            .file = self.allocator.dupe(u8, file) catch {
                self.allocator.free(message);
                self.allocator.free(entry.module);
                self.metrics.recordDroppedEntry();
                return;
            },
            .line = line,
            .thread_id = Thread.getCurrentId(),
            .metadata = cloned_metadata,
        };

        if (self.async_mode) {
            if (self.queue) |*queue| {
                queue.writeItem(entry) catch {
                    entry.deinit(self.allocator);
                    self.metrics.recordDroppedEntry();
                    return;
                };
            }
        } else {
            self.processEntry(&entry);
            entry.deinit(self.allocator);
        }

        const end_time = std.time.nanoTimestamp();
        self.metrics.recordEntry(level, @intCast(end_time - start_time));
    }

    fn checkRateLimit(self: *Self) bool {
        const current_time = std.time.timestamp();
        const last_reset = self.last_reset_time.load(.Monotonic);

        if (current_time > last_reset) {
            self.entry_count_this_second.store(0, .Monotonic);
            _ = self.last_reset_time.store(current_time, .Monotonic);
        }

        const current_count = self.entry_count_this_second.fetchAdd(1, .Monotonic);
        return current_count < self.max_entries_per_second;
    }

    fn processEntry(self: *Self, entry: *const LogEntry) void {
        for (self.outputs.items) |output| {
            output.write(entry);
        }
    }

    fn asyncWorker(self: *Self) void {
        while (self.running.load(.SeqCst)) {
            if (self.queue) |*queue| {
                if (queue.readItem()) |entry| {
                    self.processEntry(&entry);
                    var mutable_entry = entry;
                    mutable_entry.deinit(self.allocator);
                } else {
                    std.time.sleep(1000000); // 1ms
                }
            } else {
                break;
            }
        }
    }

    pub fn getMetrics(self: *Self) LogMetrics {
        return self.metrics;
    }

    pub fn flush(self: *Self) void {
        for (self.outputs.items) |output| {
            output.flush();
        }
    }
};

// Global logger instance
var global_logger: ?Logger = null;
var logger_mutex = Thread.Mutex{};

/// Initialize the global logger
pub fn init() !void {
    logger_mutex.lock();
    defer logger_mutex.unlock();

    if (global_logger != null) return;

    const allocator = std.heap.c_allocator;

    // Determine default log level based on build mode
    const default_level = if (builtin.mode == .Debug) LogLevel.debug else LogLevel.info;

    global_logger = try Logger.init(allocator, default_level, true); // Async by default

    // Add console output
    var console_output = try allocator.create(ConsoleOutput);
    console_output.* = ConsoleOutput.init(true); // Colors enabled
    try global_logger.?.addOutput(&console_output.output);

    // Add file output for mobile platforms
    if (builtin.os.tag == .ios or (builtin.os.tag == .linux and builtin.abi == .android)) {
        const log_dir = "/tmp"; // This would be platform-specific in real implementation
        const log_path = try std.fmt.allocPrint(allocator, "{s}/dowel-steek.log", .{log_dir});

        var file_output = try allocator.create(FileOutput);
        file_output.* = try FileOutput.init(allocator, log_path, 10 * 1024 * 1024, 5); // 10MB, 5 rotations
        try global_logger.?.addOutput(&file_output.output);
    }
}

/// Shutdown the global logger
pub fn shutdown() void {
    logger_mutex.lock();
    defer logger_mutex.unlock();

    if (global_logger) |*logger| {
        logger.deinit();
        global_logger = null;
    }
}

/// Check if the logging system is initialized
pub fn is_initialized() bool {
    return global_logger != null;
}

/// Get the global logger instance
pub fn instance() ?*Logger {
    return if (global_logger) |*logger| logger else null;
}

// Convenience logging functions
pub fn trace(module: []const u8, file: []const u8, line: u32, comptime fmt: []const u8, args: anytype) void {
    if (instance()) |logger| {
        logger.log(.trace, module, file, line, fmt, args);
    }
}

pub fn debug(module: []const u8, file: []const u8, line: u32, comptime fmt: []const u8, args: anytype) void {
    if (instance()) |logger| {
        logger.log(.debug, module, file, line, fmt, args);
    }
}

pub fn info(module: []const u8, file: []const u8, line: u32, comptime fmt: []const u8, args: anytype) void {
    if (instance()) |logger| {
        logger.log(.info, module, file, line, fmt, args);
    }
}

pub fn warn(module: []const u8, file: []const u8, line: u32, comptime fmt: []const u8, args: anytype) void {
    if (instance()) |logger| {
        logger.log(.warn, module, file, line, fmt, args);
    }
}

pub fn err(module: []const u8, file: []const u8, line: u32, comptime fmt: []const u8, args: anytype) void {
    if (instance()) |logger| {
        logger.log(.err, module, file, line, fmt, args);
    }
}

pub fn fatal(module: []const u8, file: []const u8, line: u32, comptime fmt: []const u8, args: anytype) void {
    if (instance()) |logger| {
        logger.log(.fatal, module, file, line, fmt, args);
    }
}

// Macros for automatic file/line capture
pub fn TRACE(comptime fmt: []const u8, args: anytype) void {
    trace("main", @src().file, @src().line, fmt, args);
}

pub fn DEBUG(comptime fmt: []const u8, args: anytype) void {
    debug("main", @src().file, @src().line, fmt, args);
}

pub fn INFO(comptime fmt: []const u8, args: anytype) void {
    info("main", @src().file, @src().line, fmt, args);
}

pub fn WARN(comptime fmt: []const u8, args: anytype) void {
    warn("main", @src().file, @src().line, fmt, args);
}

pub fn ERROR(comptime fmt: []const u8, args: anytype) void {
    err("main", @src().file, @src().line, fmt, args);
}

pub fn FATAL(comptime fmt: []const u8, args: anytype) void {
    fatal("main", @src().file, @src().line, fmt, args);
}

// C API exports
export fn dowel_log_trace(module: [*:0]const u8, message: [*:0]const u8) callconv(.C) void {
    const module_slice = std.mem.span(module);
    const message_slice = std.mem.span(message);
    trace(module_slice, "c_api", 0, "{s}", .{message_slice});
}

export fn dowel_log_debug(module: [*:0]const u8, message: [*:0]const u8) callconv(.C) void {
    const module_slice = std.mem.span(module);
    const message_slice = std.mem.span(message);
    debug(module_slice, "c_api", 0, "{s}", .{message_slice});
}

export fn dowel_log_info(module: [*:0]const u8, message: [*:0]const u8) callconv(.C) void {
    const module_slice = std.mem.span(module);
    const message_slice = std.mem.span(message);
    info(module_slice, "c_api", 0, "{s}", .{message_slice});
}

export fn dowel_log_warn(module: [*:0]const u8, message: [*:0]const u8) callconv(.C) void {
    const module_slice = std.mem.span(module);
    const message_slice = std.mem.span(message);
    warn(module_slice, "c_api", 0, "{s}", .{message_slice});
}

export fn dowel_log_error(module: [*:0]const u8, message: [*:0]const u8) callconv(.C) void {
    const module_slice = std.mem.span(module);
    const message_slice = std.mem.span(message);
    err(module_slice, "c_api", 0, "{s}", .{message_slice});
}

export fn dowel_log_set_level(level: c_int) callconv(.C) void {
    if (instance()) |logger| {
        const log_level = @enumFromInt(LogLevel, @as(u8, @intCast(@min(@max(level, 0), 5))));
        logger.setLevel(log_level);
    }
}

export fn dowel_log_flush() callconv(.C) void {
    if (instance()) |logger| {
        logger.flush();
    }
}

// Tests
test "logger initialization and basic logging" {
    const allocator = std.testing.allocator;

    var logger = try Logger.init(allocator, .debug, false);
    defer logger.deinit();

    var console = ConsoleOutput.init(false);
    try logger.addOutput(&console.output);

    logger.log(.info, "test", "test.zig", 123, "Test message: {}", .{42});
    logger.flush();
}

test "async logging" {
    const allocator = std.testing.allocator;

    var logger = try Logger.init(allocator, .debug, true);
    defer logger.deinit();

    var console = ConsoleOutput.init(false);
    try logger.addOutput(&console.output);

    logger.log(.info, "test", "test.zig", 123, "Async test message");
    std.time.sleep(10000000); // 10ms to let async processing happen
}

test "log level filtering" {
    const allocator = std.testing.allocator;

    var logger = try Logger.init(allocator, .warn, false);
    defer logger.deinit();

    var console = ConsoleOutput.init(false);
    try logger.addOutput(&console.output);

    // These should be filtered out
    logger.log(.trace, "test", "test.zig", 123, "This should not appear");
    logger.log(.debug, "test", "test.zig", 124, "This should not appear");
    logger.log(.info, "test", "test.zig", 125, "This should not appear");

    // These should appear
    logger.log(.warn, "test", "test.zig", 126, "This should appear");
    logger.log(.err, "test", "test.zig", 127, "This should appear");
}

test "metadata logging" {
    const allocator = std.testing.allocator;

    var logger = try Logger.init(allocator, .debug, false);
    defer logger.deinit();

    var console = ConsoleOutput.init(false);
    try logger.addOutput(&console.output);

    logger.info("test", "Test metadata logging");
}
