//! Mobile Storage System
//!
//! This module provides a comprehensive file storage system optimized for mobile devices.
//! Features include secure file operations, mobile-friendly directory structures,
//! automatic cleanup, and platform-specific optimizations.

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const StringHashMap = std.StringHashMap;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;

/// Storage errors
pub const StorageError = error{
    NotInitialized,
    AccessDenied,
    FileNotFound,
    DirectoryNotFound,
    DiskFull,
    ReadError,
    WriteError,
    InvalidPath,
    PathTooLong,
    FileExists,
    DirectoryNotEmpty,
    QuotaExceeded,
    PermissionDenied,
};

/// File information structure
pub const FileInfo = struct {
    path: []const u8,
    size: u64,
    modified_time: i64,
    created_time: i64,
    is_directory: bool,
    is_hidden: bool,
    permissions: u32,

    pub fn deinit(self: *FileInfo, allocator: Allocator) void {
        allocator.free(self.path);
    }
};

/// Storage metrics for monitoring
pub const StorageMetrics = struct {
    total_reads: Atomic(u64),
    total_writes: Atomic(u64),
    bytes_read: Atomic(u64),
    bytes_written: Atomic(u64),
    cache_hits: Atomic(u64),
    cache_misses: Atomic(u64),
    cleanup_operations: Atomic(u64),

    pub fn init() StorageMetrics {
        return StorageMetrics{
            .total_reads = Atomic(u64).init(0),
            .total_writes = Atomic(u64).init(0),
            .bytes_read = Atomic(u64).init(0),
            .bytes_written = Atomic(u64).init(0),
            .cache_hits = Atomic(u64).init(0),
            .cache_misses = Atomic(u64).init(0),
            .cleanup_operations = Atomic(u64).init(0),
        };
    }
};

/// File cache entry
const CacheEntry = struct {
    data: []u8,
    timestamp: i64,
    access_count: u32,

    pub fn deinit(self: *CacheEntry, allocator: Allocator) void {
        allocator.free(self.data);
    }
};

/// Storage manager with caching and mobile optimizations
pub const StorageManager = struct {
    allocator: Allocator,
    app_data_dir: []const u8,
    cache_dir: []const u8,
    temp_dir: []const u8,
    file_cache: StringHashMap(CacheEntry),
    cache_mutex: Thread.Mutex,
    max_cache_size: usize,
    current_cache_size: Atomic(usize),
    metrics: StorageMetrics,
    initialized: bool,
    cleanup_thread: ?Thread,
    cleanup_running: Atomic(bool),

    const Self = @This();
    const MAX_PATH_LENGTH = 4096;
    const DEFAULT_CACHE_SIZE = 64 * 1024 * 1024; // 64MB
    const CLEANUP_INTERVAL_MS = 60000; // 1 minute

    pub fn init(allocator: Allocator, app_name: []const u8) !Self {
        const platform_dirs = try getPlatformDirectories(allocator, app_name);

        var manager = Self{
            .allocator = allocator,
            .app_data_dir = platform_dirs.data_dir,
            .cache_dir = platform_dirs.cache_dir,
            .temp_dir = platform_dirs.temp_dir,
            .file_cache = StringHashMap(CacheEntry).init(allocator),
            .cache_mutex = Thread.Mutex{},
            .max_cache_size = DEFAULT_CACHE_SIZE,
            .current_cache_size = Atomic(usize).init(0),
            .metrics = StorageMetrics.init(),
            .initialized = false,
            .cleanup_thread = null,
            .cleanup_running = Atomic(bool).init(false),
        };

        // Ensure directories exist
        try manager.ensureDirectoryExists(manager.app_data_dir);
        try manager.ensureDirectoryExists(manager.cache_dir);
        try manager.ensureDirectoryExists(manager.temp_dir);

        // Start cleanup thread
        manager.cleanup_running.store(true, .SeqCst);
        manager.cleanup_thread = try Thread.spawn(.{}, cleanupWorker, .{&manager});

        manager.initialized = true;
        return manager;
    }

    pub fn deinit(self: *Self) void {
        if (!self.initialized) return;

        // Stop cleanup thread
        self.cleanup_running.store(false, .SeqCst);
        if (self.cleanup_thread) |thread| {
            thread.join();
        }

        // Clear cache
        self.cache_mutex.lock();
        defer self.cache_mutex.unlock();

        var iterator = self.file_cache.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.file_cache.deinit();

        // Free directory paths
        self.allocator.free(self.app_data_dir);
        self.allocator.free(self.cache_dir);
        self.allocator.free(self.temp_dir);

        self.initialized = false;
    }

    /// Read file contents with caching
    pub fn readFile(self: *Self, path: []const u8) ![]u8 {
        if (!self.initialized) return StorageError.NotInitialized;

        const start_time = std.time.nanoTimestamp();
        defer {
            const end_time = std.time.nanoTimestamp();
            const duration = end_time - start_time;
            _ = duration; // Use the duration
            _ = self.metrics.total_reads.fetchAdd(1, .Monotonic);
        }

        // Check cache first
        if (self.getCachedFile(path)) |cached_data| {
            _ = self.metrics.cache_hits.fetchAdd(1, .Monotonic);
            _ = self.metrics.bytes_read.fetchAdd(cached_data.len, .Monotonic);
            return try self.allocator.dupe(u8, cached_data);
        }

        _ = self.metrics.cache_misses.fetchAdd(1, .Monotonic);

        // Validate and resolve path
        const full_path = try self.resolvePath(path);
        defer self.allocator.free(full_path);

        // Read from filesystem
        const file = std.fs.openFileAbsolute(full_path, .{}) catch |err| switch (err) {
            error.FileNotFound => return StorageError.FileNotFound,
            error.AccessDenied => return StorageError.AccessDenied,
            else => return StorageError.ReadError,
        };
        defer file.close();

        const file_size = try file.getEndPos();
        if (file_size > 100 * 1024 * 1024) { // 100MB limit
            return StorageError.ReadError;
        }

        const data = try file.readToEndAlloc(self.allocator, @intCast(file_size));
        _ = self.metrics.bytes_read.fetchAdd(data.len, .Monotonic);

        // Cache small files (under 1MB)
        if (data.len < 1024 * 1024) {
            self.cacheFile(path, data) catch |err| {
                std.log.warn("Failed to cache file {s}: {}", .{ path, err });
            };
        }

        return data;
    }

    /// Write file contents with automatic directory creation
    pub fn writeFile(self: *Self, path: []const u8, data: []const u8) !void {
        if (!self.initialized) return StorageError.NotInitialized;

        _ = std.time.nanoTimestamp(); // Remove unused variable
        defer {
            _ = self.metrics.total_writes.fetchAdd(1, .Monotonic);
        }

        // Validate and resolve path
        const full_path = try self.resolvePath(path);
        defer self.allocator.free(full_path);

        // Ensure parent directory exists
        const parent_dir = std.fs.path.dirname(full_path) orelse return StorageError.InvalidPath;
        try self.ensureDirectoryExists(parent_dir);

        // Write to filesystem
        const file = std.fs.createFileAbsolute(full_path, .{}) catch |err| switch (err) {
            error.AccessDenied => return StorageError.AccessDenied,
            error.NoSpaceLeft => return StorageError.DiskFull,
            else => return StorageError.WriteError,
        };
        defer file.close();

        file.writeAll(data) catch |err| switch (err) {
            error.NoSpaceLeft => return StorageError.DiskFull,
            error.AccessDenied => return StorageError.AccessDenied,
            else => return StorageError.WriteError,
        };

        // Update cache if file was cached
        self.updateCache(path, data) catch |err| {
            std.log.warn("Failed to update cache for {s}: {}", .{ path, err });
        };
    }

    /// Delete file with cache invalidation
    pub fn deleteFile(self: *Self, path: []const u8) !void {
        if (!self.initialized) return StorageError.NotInitialized;

        const full_path = try self.resolvePath(path);
        defer self.allocator.free(full_path);

        std.fs.deleteFileAbsolute(full_path) catch |err| switch (err) {
            error.FileNotFound => return StorageError.FileNotFound,
            error.AccessDenied => return StorageError.AccessDenied,
            else => return StorageError.WriteError,
        };

        // Remove from cache
        self.removeCachedFile(path);
    }

    /// Check if file exists
    pub fn fileExists(self: *Self, path: []const u8) bool {
        if (!self.initialized) return false;

        const full_path = self.resolvePath(path) catch return false;
        defer self.allocator.free(full_path);

        std.fs.accessAbsolute(full_path, .{}) catch return false;
        return true;
    }

    /// Create directory with parents
    pub fn createDirectory(self: *Self, path: []const u8) !void {
        if (!self.initialized) return StorageError.NotInitialized;

        const full_path = try self.resolvePath(path);
        defer self.allocator.free(full_path);

        try self.ensureDirectoryExists(full_path);
    }

    /// List directory contents
    pub fn listDirectory(self: *Self, path: []const u8) ![]FileInfo {
        if (!self.initialized) return StorageError.NotInitialized;

        const full_path = try self.resolvePath(path);
        defer self.allocator.free(full_path);

        var dir = std.fs.openDirAbsolute(full_path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => return StorageError.DirectoryNotFound,
            error.AccessDenied => return StorageError.AccessDenied,
            else => return StorageError.ReadError,
        };
        defer dir.close();

        var files = ArrayList(FileInfo).init(self.allocator);
        errdefer {
            for (files.items) |*file| {
                file.deinit(self.allocator);
            }
            files.deinit();
        }

        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            const stat = dir.statFile(entry.name) catch continue;

            const file_path = try std.fs.path.join(self.allocator, &[_][]const u8{ path, entry.name });

            const file_info = FileInfo{
                .path = file_path,
                .size = stat.size,
                .modified_time = @intCast(stat.mtime),
                .created_time = @intCast(stat.ctime),
                .is_directory = entry.kind == .directory,
                .is_hidden = entry.name[0] == '.',
                .permissions = @intCast(stat.mode),
            };

            try files.append(file_info);
        }

        return try files.toOwnedSlice();
    }

    /// Get file information
    pub fn getFileInfo(self: *Self, path: []const u8) !FileInfo {
        if (!self.initialized) return StorageError.NotInitialized;

        const full_path = try self.resolvePath(path);
        defer self.allocator.free(full_path);

        const stat = std.fs.cwd().statFile(full_path) catch |err| switch (err) {
            error.FileNotFound => return StorageError.FileNotFound,
            error.AccessDenied => return StorageError.AccessDenied,
            else => return StorageError.ReadError,
        };

        return FileInfo{
            .path = try self.allocator.dupe(u8, path),
            .size = stat.size,
            .modified_time = @intCast(stat.mtime),
            .created_time = @intCast(stat.ctime),
            .is_directory = stat.kind == .directory,
            .is_hidden = std.fs.path.basename(path)[0] == '.',
            .permissions = @intCast(stat.mode),
        };
    }

    /// Clear all cached files
    pub fn clearCache(self: *Self) void {
        self.cache_mutex.lock();
        defer self.cache_mutex.unlock();

        var iterator = self.file_cache.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.file_cache.clearAndFree();
        self.current_cache_size.store(0, .Monotonic);
    }

    /// Get storage metrics
    pub fn getMetrics(self: *Self) StorageMetrics {
        return self.metrics;
    }

    // Private methods

    fn resolvePath(self: *Self, path: []const u8) ![]u8 {
        if (path.len == 0) return StorageError.InvalidPath;
        if (path.len > MAX_PATH_LENGTH) return StorageError.PathTooLong;

        // Handle absolute paths
        if (std.fs.path.isAbsolute(path)) {
            return try self.allocator.dupe(u8, path);
        }

        // Resolve relative paths to app data directory
        return try std.fs.path.join(self.allocator, &[_][]const u8{ self.app_data_dir, path });
    }

    fn ensureDirectoryExists(_: *Self, path: []const u8) !void {
        std.fs.makeDirAbsolute(path) catch |err| switch (err) {
            error.PathAlreadyExists => {}, // OK
            error.AccessDenied => return StorageError.AccessDenied,
            error.NoSpaceLeft => return StorageError.DiskFull,
            else => return StorageError.WriteError,
        };
    }

    fn getCachedFile(self: *Self, path: []const u8) ?[]const u8 {
        self.cache_mutex.lock();
        defer self.cache_mutex.unlock();

        if (self.file_cache.getPtr(path)) |entry| {
            entry.access_count += 1;
            entry.timestamp = std.time.timestamp();
            return entry.data;
        }
        return null;
    }

    fn cacheFile(self: *Self, path: []const u8, data: []const u8) !void {
        self.cache_mutex.lock();
        defer self.cache_mutex.unlock();

        // Check if we have space
        const current_size = self.current_cache_size.load(.Monotonic);
        if (current_size + data.len > self.max_cache_size) {
            self.evictOldestCacheEntries(data.len);
        }

        const key = try self.allocator.dupe(u8, path);
        const cached_data = try self.allocator.dupe(u8, data);

        const entry = CacheEntry{
            .data = cached_data,
            .timestamp = std.time.timestamp(),
            .access_count = 1,
        };

        // Remove existing entry if present
        if (self.file_cache.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            const old_size = old.value.data.len;
            old.value.deinit(self.allocator);
            _ = self.current_cache_size.fetchSub(old_size, .Monotonic);
        }

        try self.file_cache.put(key, entry);
        _ = self.current_cache_size.fetchAdd(data.len, .Monotonic);
    }

    fn updateCache(self: *Self, path: []const u8, data: []const u8) !void {
        self.cache_mutex.lock();
        defer self.cache_mutex.unlock();

        if (self.file_cache.getPtr(path)) |entry| {
            // Update existing cache entry
            const old_size = entry.data.len;
            self.allocator.free(entry.data);
            entry.data = try self.allocator.dupe(u8, data);
            entry.timestamp = std.time.timestamp();

            _ = self.current_cache_size.fetchSub(old_size, .Monotonic);
            _ = self.current_cache_size.fetchAdd(data.len, .Monotonic);
        }
    }

    fn removeCachedFile(self: *Self, path: []const u8) void {
        self.cache_mutex.lock();
        defer self.cache_mutex.unlock();

        if (self.file_cache.fetchRemove(path)) |removed| {
            self.allocator.free(removed.key);
            const size = removed.value.data.len;
            removed.value.deinit(self.allocator);
            _ = self.current_cache_size.fetchSub(size, .Monotonic);
        }
    }

    fn evictOldestCacheEntries(self: *Self, needed_space: usize) void {
        // Simple LRU eviction based on timestamp
        var to_remove = ArrayList([]const u8).init(self.allocator);
        defer to_remove.deinit();

        const oldest_time = std.time.timestamp();
        var freed_space: usize = 0;

        // Find entries to remove
        var iterator = self.file_cache.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.timestamp < oldest_time and freed_space < needed_space) {
                to_remove.append(entry.key_ptr.*) catch continue;
                freed_space += entry.value_ptr.data.len;
            }
        }

        // Remove selected entries
        for (to_remove.items) |key| {
            if (self.file_cache.fetchRemove(key)) |removed| {
                self.allocator.free(removed.key);
                const size = removed.value.data.len;
                removed.value.deinit(self.allocator);
                _ = self.current_cache_size.fetchSub(size, .Monotonic);
            }
        }
    }

    fn cleanupWorker(self: *Self) void {
        while (self.cleanup_running.load(.SeqCst)) {
            std.time.sleep(CLEANUP_INTERVAL_MS * std.time.ns_per_ms);

            // Clean up temporary files older than 1 hour
            self.cleanupTempFiles() catch |err| {
                std.log.warn("Temp file cleanup failed: {}", .{err});
            };

            // Clean up cache if it's getting too large
            const cache_size = self.current_cache_size.load(.Monotonic);
            if (cache_size > self.max_cache_size * 3 / 4) { // 75% threshold
                self.cache_mutex.lock();
                self.evictOldestCacheEntries(cache_size / 4); // Remove 25%
                self.cache_mutex.unlock();
            }

            _ = self.metrics.cleanup_operations.fetchAdd(1, .Monotonic);
        }
    }

    fn cleanupTempFiles(self: *Self) !void {
        var temp_dir = std.fs.openDirAbsolute(self.temp_dir, .{ .iterate = true }) catch return;
        defer temp_dir.close();

        const one_hour_ago = std.time.timestamp() - 3600;

        var iterator = temp_dir.iterate();
        while (try iterator.next()) |entry| {
            if (entry.kind != .file) continue;

            const stat = temp_dir.statFile(entry.name) catch continue;
            if (stat.mtime < one_hour_ago) {
                temp_dir.deleteFile(entry.name) catch |err| {
                    std.log.warn("Failed to delete temp file {s}: {}", .{ entry.name, err });
                };
            }
        }
    }
};

// Platform-specific directory resolution
const PlatformDirectories = struct {
    data_dir: []const u8,
    cache_dir: []const u8,
    temp_dir: []const u8,
};

fn getPlatformDirectories(allocator: Allocator, app_name: []const u8) !PlatformDirectories {
    switch (builtin.os.tag) {
        .linux => {
            if (builtin.abi == .android) {
                // Android paths
                const internal_storage = "/data/data"; // This would be app-specific in real implementation
                return PlatformDirectories{
                    .data_dir = try std.fmt.allocPrint(allocator, "{s}/{s}/files", .{ internal_storage, app_name }),
                    .cache_dir = try std.fmt.allocPrint(allocator, "{s}/{s}/cache", .{ internal_storage, app_name }),
                    .temp_dir = try std.fmt.allocPrint(allocator, "{s}/{s}/temp", .{ internal_storage, app_name }),
                };
            } else {
                // Linux desktop paths
                const home = std.process.getEnvVarOwned(allocator, "HOME") catch "/tmp";
                defer if (!std.mem.eql(u8, home, "/tmp")) allocator.free(home);

                return PlatformDirectories{
                    .data_dir = try std.fmt.allocPrint(allocator, "{s}/.local/share/{s}", .{ home, app_name }),
                    .cache_dir = try std.fmt.allocPrint(allocator, "{s}/.cache/{s}", .{ home, app_name }),
                    .temp_dir = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{app_name}),
                };
            }
        },
        .ios => {
            // iOS paths (simplified)
            const docs_dir = "/var/mobile/Applications"; // This would use proper iOS APIs
            return PlatformDirectories{
                .data_dir = try std.fmt.allocPrint(allocator, "{s}/{s}/Documents", .{ docs_dir, app_name }),
                .cache_dir = try std.fmt.allocPrint(allocator, "{s}/{s}/Library/Caches", .{ docs_dir, app_name }),
                .temp_dir = try std.fmt.allocPrint(allocator, "{s}/{s}/tmp", .{ docs_dir, app_name }),
            };
        },
        else => {
            // Fallback for other platforms
            return PlatformDirectories{
                .data_dir = try std.fmt.allocPrint(allocator, "/tmp/{s}/data", .{app_name}),
                .cache_dir = try std.fmt.allocPrint(allocator, "/tmp/{s}/cache", .{app_name}),
                .temp_dir = try std.fmt.allocPrint(allocator, "/tmp/{s}/temp", .{app_name}),
            };
        },
    }
}

// Global instance
var global_storage: ?StorageManager = null;
var storage_mutex = Thread.Mutex{};

/// Initialize the global storage manager
pub fn init() !void {
    storage_mutex.lock();
    defer storage_mutex.unlock();

    if (global_storage != null) return;

    const allocator = std.heap.c_allocator;
    global_storage = try StorageManager.init(allocator, "dowel-steek");
}

/// Shutdown the global storage manager
pub fn shutdown() void {
    storage_mutex.lock();
    defer storage_mutex.unlock();

    if (global_storage) |*storage| {
        storage.deinit();
        global_storage = null;
    }
}

/// Check if the storage system is initialized
pub fn is_initialized() bool {
    return global_storage != null;
}

/// Get the global storage manager instance
pub fn instance() !*StorageManager {
    if (global_storage) |*storage| {
        return storage;
    }
    return StorageError.NotInitialized;
}

// C API exports
export fn dowel_storage_read_file(path: [*:0]const u8) callconv(.C) ?*anyopaque {
    const storage = instance() catch return null;
    const path_slice = std.mem.span(path);

    const data = storage.readFile(path_slice) catch return null;

    // Create buffer structure for C
    const buffer = std.heap.c_allocator.create(@import("lib.zig").c_api.Buffer) catch return null;
    buffer.data = data.ptr;
    buffer.size = data.len;
    return @ptrCast(buffer);
}

export fn dowel_storage_write_file(path: [*:0]const u8, data: [*]const u8, size: usize) callconv(.C) c_int {
    const storage = instance() catch return -1;
    const path_slice = std.mem.span(path);
    const data_slice = data[0..size];

    storage.writeFile(path_slice, data_slice) catch return -2;
    return 0;
}

export fn dowel_storage_delete_file(path: [*:0]const u8) callconv(.C) c_int {
    const storage = instance() catch return -1;
    const path_slice = std.mem.span(path);

    storage.deleteFile(path_slice) catch return -2;
    return 0;
}

export fn dowel_storage_file_exists(path: [*:0]const u8) callconv(.C) bool {
    const storage = instance() catch return false;
    const path_slice = std.mem.span(path);

    return storage.fileExists(path_slice);
}

export fn dowel_storage_create_directory(path: [*:0]const u8) callconv(.C) c_int {
    const storage = instance() catch return -1;
    const path_slice = std.mem.span(path);

    storage.createDirectory(path_slice) catch return -2;
    return 0;
}

export fn dowel_storage_get_file_size(path: [*:0]const u8) callconv(.C) i64 {
    const storage = instance() catch return -1;
    const path_slice = std.mem.span(path);

    const info = storage.getFileInfo(path_slice) catch return -1;
    defer {
        var mutable_info = info;
        mutable_info.deinit(std.heap.c_allocator);
    }

    return @intCast(info.size);
}

export fn dowel_storage_get_file_modtime(path: [*:0]const u8) callconv(.C) i64 {
    const storage = instance() catch return -1;
    const path_slice = std.mem.span(path);

    const info = storage.getFileInfo(path_slice) catch return -1;
    defer {
        var mutable_info = info;
        mutable_info.deinit(std.heap.c_allocator);
    }

    return info.modified_time;
}

// Tests
test "storage initialization" {
    const allocator = std.testing.allocator;
    var storage = try StorageManager.init(allocator, "test-app");
    defer storage.deinit();

    try std.testing.expect(storage.initialized);
}

test "file operations" {
    const allocator = std.testing.allocator;
    var storage = try StorageManager.init(allocator, "test-app");
    defer storage.deinit();

    // Test write and read
    const test_data = "Hello, World!";
    const test_path = "test/hello.txt";

    try storage.writeFile(test_path, test_data);

    const read_data = try storage.readFile(test_path);
    defer allocator.free(read_data);

    try std.testing.expectEqualStrings(test_data, read_data);

    // Test file exists
    try std.testing.expect(storage.fileExists(test_path));

    // Test delete
    try storage.deleteFile(test_path);
    try std.testing.expect(!storage.fileExists(test_path));
}

test "directory operations" {
    const allocator = std.testing.allocator;
    var storage = try StorageManager.init(allocator, "test-app");
    defer storage.deinit();

    const test_dir = "test/subdir";
    try storage.createDirectory(test_dir);

    const test_file = "test/subdir/file.txt";
    try storage.writeFile(test_file, "test content");

    const files = try storage.listDirectory("test/subdir");
    defer {
        for (files) |*file| {
            file.deinit(allocator);
        }
        allocator.free(files);
    }

    try std.testing.expect(files.len > 0);
}
