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
