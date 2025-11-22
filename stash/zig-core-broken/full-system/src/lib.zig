//! Dowel-Steek Mobile Core Library
//!
//! This is the main entry point for the Zig-based core system components
//! of the Dowel-Steek mobile operating system. It provides high-performance,
//! memory-safe implementations of system-level functionality that can be
//! called from Kotlin Multiplatform applications.

const std = @import("std");
const builtin = @import("builtin");

// Core modules
pub const config = @import("config.zig");
pub const logging = @import("logging.zig");
pub const storage = @import("storage.zig");
pub const networking = @import("networking.zig");
pub const crypto = @import("crypto.zig");

// Mobile-specific modules
pub const mobile = struct {
    pub const power = @import("mobile/power.zig");
    pub const sensors = @import("mobile/sensors.zig");
    pub const notifications = @import("mobile/notifications.zig");
};

// C ABI exports for interop with Kotlin/Swift
pub const c_api = @import("c_api.zig");

// Library version information
pub const VERSION = struct {
    pub const major: u32 = 0;
    pub const minor: u32 = 1;
    pub const patch: u32 = 0;
    pub const pre_release: ?[]const u8 = "alpha";
};

/// Initialize the core library
/// Must be called before using any other library functions
export fn dowel_core_init() callconv(.C) c_int {
    return c_api.dowel_core_init();
}

/// Shutdown the core library
/// Should be called when the application is terminating
export fn dowel_core_shutdown() callconv(.C) void {
    c_api.dowel_core_shutdown();
}

/// Get library version as a C string
export fn dowel_core_version() callconv(.C) [*:0]const u8 {
    var buffer: [64]u8 = undefined;
    _ = c_api.dowel_get_version(&buffer, buffer.len);
    return @ptrCast(&buffer);
}

/// Check if the library is properly initialized
export fn dowel_core_is_initialized() callconv(.C) bool {
    // Use C API to check if core system is initialized
    return c_api.allocator_initialized;
}

/// Memory management utilities for C interop
pub const Memory = struct {
    /// Allocate memory using the C allocator (for strings returned to C)
    pub fn allocC(comptime T: type, count: usize) ![]T {
        return std.heap.c_allocator.alloc(T, count);
    }

    /// Free memory allocated with allocC
    pub fn freeC(comptime T: type, memory: []T) void {
        std.heap.c_allocator.free(memory);
    }

    /// Duplicate a string for C interop
    pub fn dupeStringC(s: []const u8) ![:0]u8 {
        return std.heap.c_allocator.dupeZ(u8, s);
    }
};

/// Error handling utilities
pub const Error = struct {
    pub const CoreError = error{
        InitializationFailed,
        NotInitialized,
        InvalidParameter,
        OutOfMemory,
        SystemError,
        NetworkError,
        StorageError,
        ConfigError,
        CryptoError,
        SensorError,
        PowerError,
        NotificationError,
    };

    /// Convert a Zig error to a C error code
    pub fn toCErrorCode(err: anyerror) c_int {
        return switch (err) {
            error.InitializationFailed => -1,
            error.NotInitialized => -2,
            error.InvalidParameter => -3,
            error.OutOfMemory => -4,
            error.SystemError => -5,
            error.NetworkError => -6,
            error.StorageError => -7,
            error.ConfigError => -8,
            error.CryptoError => -9,
            error.SensorError => -10,
            error.PowerError => -11,
            error.NotificationError => -12,
            else => -999, // Unknown error
        };
    }
};

/// Platform detection utilities
pub const Platform = struct {
    pub const Type = enum {
        android,
        ios,
        desktop,
        unknown,
    };

    pub fn current() Type {
        return switch (builtin.os.tag) {
            .linux => if (builtin.abi == .android) .android else .desktop,
            .ios => .ios,
            .macos, .windows => .desktop,
            else => .unknown,
        };
    }

    pub fn isMobile() bool {
        return switch (current()) {
            .android, .ios => true,
            else => false,
        };
    }

    pub fn isDesktop() bool {
        return switch (current()) {
            .desktop => true,
            else => false,
        };
    }
};

// Testing utilities
test "library initialization" {
    const result = dowel_core_init();
    try std.testing.expect(result == 0);

    const is_init = dowel_core_is_initialized();
    try std.testing.expect(is_init);

    dowel_core_shutdown();
}

test "platform detection" {
    const platform = Platform.current();
    try std.testing.expect(platform != .unknown);

    // Test mobile detection
    const is_mobile = Platform.isMobile();
    const is_desktop = Platform.isDesktop();

    // Should be either mobile or desktop, but not both
    try std.testing.expect(is_mobile != is_desktop);
}

test "memory utilities" {
    _ = std.testing.allocator;

    // Test C string duplication
    const original = "Hello, World!";
    const duplicated = try Memory.dupeStringC(original);
    defer Memory.freeC(u8, duplicated);

    try std.testing.expectEqualStrings(original, duplicated);
}

test "error code conversion" {
    const err_code = Error.toCErrorCode(error.OutOfMemory);
    try std.testing.expect(err_code == -4);

    const unknown_err = Error.toCErrorCode(error.Unexpected);
    try std.testing.expect(unknown_err == -999);
}

test "version information" {
    try std.testing.expect(VERSION.major == 0);
    try std.testing.expect(VERSION.minor == 1);
    try std.testing.expect(VERSION.patch == 0);
    try std.testing.expectEqualStrings(VERSION.pre_release.?, "alpha");
}
