//! Networking Module for Dowel-Steek Mobile
//!
//! This module provides a comprehensive networking system optimized for mobile devices.
//! Features include connection management, request/response handling, caching,
//! offline support, and mobile-specific optimizations like data usage monitoring.

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const StringHashMap = std.StringHashMap;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;

/// Networking errors
pub const NetworkError = error{
    NotInitialized,
    ConnectionFailed,
    Timeout,
    InvalidUrl,
    InvalidRequest,
    InvalidResponse,
    NoConnection,
    HostUnreachable,
    TlsError,
    AuthenticationFailed,
    RateLimited,
    ServerError,
    ClientError,
    ParseError,
};

/// HTTP methods
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,

    pub fn toString(self: HttpMethod) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
        };
    }
};

/// Connection type
pub const ConnectionType = enum {
    none,
    wifi,
    cellular,
    ethernet,
    bluetooth,
    unknown,

    pub fn toString(self: ConnectionType) []const u8 {
        return switch (self) {
            .none => "none",
            .wifi => "wifi",
            .cellular => "cellular",
            .ethernet => "ethernet",
            .bluetooth => "bluetooth",
            .unknown => "unknown",
        };
    }

    pub fn fromString(s: []const u8) ConnectionType {
        if (std.mem.eql(u8, s, "wifi")) return .wifi;
        if (std.mem.eql(u8, s, "cellular")) return .cellular;
        if (std.mem.eql(u8, s, "ethernet")) return .ethernet;
        if (std.mem.eql(u8, s, "bluetooth")) return .bluetooth;
        if (std.mem.eql(u8, s, "none")) return .none;
        return .unknown;
    }
};

/// Network status
pub const NetworkStatus = struct {
    is_connected: bool,
    connection_type: ConnectionType,
    signal_strength: i8, // -100 to 0 dBm for cellular/wifi
    data_usage_bytes: u64,
    is_metered: bool, // True for cellular, limited wifi
    is_roaming: bool, // Cellular roaming
};

/// HTTP request structure
pub const HttpRequest = struct {
    method: HttpMethod,
    url: []const u8,
    headers: StringHashMap([]const u8),
    body: ?[]const u8,
    timeout_ms: u32,
    follow_redirects: bool,
    max_redirects: u8,

    pub fn init(allocator: Allocator) HttpRequest {
        return HttpRequest{
            .method = .GET,
            .url = "",
            .headers = StringHashMap([]const u8).init(allocator),
            .body = null,
            .timeout_ms = 30000, // 30 seconds
            .follow_redirects = true,
            .max_redirects = 5,
        };
    }

    pub fn deinit(self: *HttpRequest) void {
        var iterator = self.headers.iterator();
        while (iterator.next()) |entry| {
            self.headers.allocator.free(entry.key_ptr.*);
            self.headers.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }

    pub fn setHeader(self: *HttpRequest, key: []const u8, value: []const u8) !void {
        const owned_key = try self.headers.allocator.dupe(u8, key);
        const owned_value = try self.headers.allocator.dupe(u8, value);
        try self.headers.put(owned_key, owned_value);
    }
};

/// HTTP response structure
pub const HttpResponse = struct {
    status_code: u16,
    status_text: []const u8,
    headers: StringHashMap([]const u8),
    body: []const u8,
    content_length: usize,
    is_cached: bool,
    cache_timestamp: i64,

    pub fn init(allocator: Allocator) HttpResponse {
        return HttpResponse{
            .status_code = 0,
            .status_text = "",
            .headers = StringHashMap([]const u8).init(allocator),
            .body = "",
            .content_length = 0,
            .is_cached = false,
            .cache_timestamp = 0,
        };
    }

    pub fn deinit(self: *HttpResponse, allocator: Allocator) void {
        allocator.free(self.status_text);
        allocator.free(self.body);

        var iterator = self.headers.iterator();
        while (iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }

    pub fn getHeader(self: *const HttpResponse, key: []const u8) ?[]const u8 {
        return self.headers.get(key);
    }

    pub fn isSuccess(self: *const HttpResponse) bool {
        return self.status_code >= 200 and self.status_code < 300;
    }
};

/// Response cache entry
const CacheEntry = struct {
    response: HttpResponse,
    expires_at: i64,
    etag: ?[]const u8,
    last_modified: ?[]const u8,

    pub fn deinit(self: *CacheEntry, allocator: Allocator) void {
        self.response.deinit(allocator);
        if (self.etag) |etag| allocator.free(etag);
        if (self.last_modified) |lm| allocator.free(lm);
    }

    pub fn isExpired(self: *const CacheEntry) bool {
        return std.time.timestamp() > self.expires_at;
    }
};

/// Network metrics for monitoring
pub const NetworkMetrics = struct {
    total_requests: Atomic(u64),
    successful_requests: Atomic(u64),
    failed_requests: Atomic(u64),
    bytes_sent: Atomic(u64),
    bytes_received: Atomic(u64),
    cache_hits: Atomic(u64),
    cache_misses: Atomic(u64),
    avg_request_time_ms: Atomic(u64),
    active_connections: Atomic(u32),

    pub fn init() NetworkMetrics {
        return NetworkMetrics{
            .total_requests = Atomic(u64).init(0),
            .successful_requests = Atomic(u64).init(0),
            .failed_requests = Atomic(u64).init(0),
            .bytes_sent = Atomic(u64).init(0),
            .bytes_received = Atomic(u64).init(0),
            .cache_hits = Atomic(u64).init(0),
            .cache_misses = Atomic(u64).init(0),
            .avg_request_time_ms = Atomic(u64).init(0),
            .active_connections = Atomic(u32).init(0),
        };
    }
};

/// Network Manager
pub const NetworkManager = struct {
    allocator: Allocator,
    user_agent: []const u8,
    default_timeout_ms: u32,
    max_concurrent_requests: u32,
    cache: StringHashMap(CacheEntry),
    cache_mutex: Thread.Mutex,
    max_cache_size: usize,
    current_cache_size: Atomic(usize),
    metrics: NetworkMetrics,
    status: NetworkStatus,
    status_mutex: Thread.Mutex,
    data_usage_limit: ?u64,
    initialized: bool,
    monitor_thread: ?Thread,
    monitor_running: Atomic(bool),

    const Self = @This();
    const DEFAULT_CACHE_SIZE = 32 * 1024 * 1024; // 32MB
    const MONITOR_INTERVAL_MS = 5000; // 5 seconds

    pub fn init(allocator: Allocator, user_agent: []const u8) !Self {
        var manager = Self{
            .allocator = allocator,
            .user_agent = try allocator.dupe(u8, user_agent),
            .default_timeout_ms = 30000,
            .max_concurrent_requests = 10,
            .cache = StringHashMap(CacheEntry).init(allocator),
            .cache_mutex = Thread.Mutex{},
            .max_cache_size = DEFAULT_CACHE_SIZE,
            .current_cache_size = Atomic(usize).init(0),
            .metrics = NetworkMetrics.init(),
            .status = NetworkStatus{
                .is_connected = false,
                .connection_type = .none,
                .signal_strength = -100,
                .data_usage_bytes = 0,
                .is_metered = false,
                .is_roaming = false,
            },
            .status_mutex = Thread.Mutex{},
            .data_usage_limit = null,
            .initialized = false,
            .monitor_thread = null,
            .monitor_running = Atomic(bool).init(false),
        };

        // Initialize network status
        try manager.updateNetworkStatus();

        // Start network monitoring thread
        manager.monitor_running.store(true, .SeqCst);
        manager.monitor_thread = try Thread.spawn(.{}, monitorWorker, .{&manager});

        manager.initialized = true;
        return manager;
    }

    pub fn deinit(self: *Self) void {
        if (!self.initialized) return;

        // Stop monitoring
        self.monitor_running.store(false, .SeqCst);
        if (self.monitor_thread) |thread| {
            thread.join();
        }

        // Clear cache
        self.cache_mutex.lock();
        defer self.cache_mutex.unlock();

        var iterator = self.cache.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.cache.deinit();

        self.allocator.free(self.user_agent);
        self.initialized = false;
    }

    /// Perform HTTP request
    pub fn request(self: *Self, req: *const HttpRequest) !HttpResponse {
        if (!self.initialized) return NetworkError.NotInitialized;

        const start_time = std.time.milliTimestamp();
        _ = self.metrics.total_requests.fetchAdd(1, .Monotonic);

        // Check network connectivity
        if (!self.isConnected()) {
            _ = self.metrics.failed_requests.fetchAdd(1, .Monotonic);
            return NetworkError.NoConnection;
        }

        // Check cache first for GET requests
        if (req.method == .GET) {
            if (self.getCachedResponse(req.url)) |cached| {
                _ = self.metrics.cache_hits.fetchAdd(1, .Monotonic);
                return try cached.response.clone(self.allocator);
            }
            _ = self.metrics.cache_misses.fetchAdd(1, .Monotonic);
        }

        // Check data usage limits
        if (self.isDataUsageLimited()) {
            return NetworkError.RateLimited;
        }

        // Perform the actual HTTP request
        const response = self.performHttpRequest(req) catch |err| {
            _ = self.metrics.failed_requests.fetchAdd(1, .Monotonic);
            return err;
        };

        _ = self.metrics.successful_requests.fetchAdd(1, .Monotonic);
        _ = self.metrics.bytes_sent.fetchAdd((req.body orelse &[_]u8{}).len, .Monotonic);
        _ = self.metrics.bytes_received.fetchAdd(response.body.len, .Monotonic);

        // Update data usage
        self.status_mutex.lock();
        self.status.data_usage_bytes += (req.body orelse &[_]u8{}).len + response.body.len;
        self.status_mutex.unlock();

        // Cache successful GET responses
        if (req.method == .GET and response.isSuccess()) {
            self.cacheResponse(req.url, &response) catch |err| {
                std.log.warn("Failed to cache response: {}", .{err});
            };
        }

        // Update average request time
        const end_time = std.time.milliTimestamp();
        const request_time = @as(u64, @intCast(end_time - start_time));
        const current_avg = self.metrics.avg_request_time_ms.load(.Monotonic);
        const new_avg = (current_avg * 9 + request_time) / 10;
        _ = self.metrics.avg_request_time_ms.store(new_avg, .Monotonic);

        return response;
    }

    /// Perform GET request (convenience method)
    pub fn get(self: *Self, url: []const u8) !HttpResponse {
        var req = HttpRequest.init(self.allocator);
        defer req.deinit();

        req.method = .GET;
        req.url = url;
        try req.setHeader("User-Agent", self.user_agent);

        return self.request(&req);
    }

    /// Perform POST request with JSON body
    pub fn postJson(self: *Self, url: []const u8, json_body: []const u8) !HttpResponse {
        var req = HttpRequest.init(self.allocator);
        defer req.deinit();

        req.method = .POST;
        req.url = url;
        req.body = json_body;
        try req.setHeader("User-Agent", self.user_agent);
        try req.setHeader("Content-Type", "application/json");

        return self.request(&req);
    }

    /// Get current network status
    pub fn getNetworkStatus(self: *Self) NetworkStatus {
        self.status_mutex.lock();
        defer self.status_mutex.unlock();
        return self.status;
    }

    /// Check if connected to network
    pub fn isConnected(self: *Self) bool {
        self.status_mutex.lock();
        defer self.status_mutex.unlock();
        return self.status.is_connected;
    }

    /// Set data usage limit in bytes
    pub fn setDataUsageLimit(self: *Self, limit_bytes: u64) void {
        self.data_usage_limit = limit_bytes;
    }

    /// Clear response cache
    pub fn clearCache(self: *Self) void {
        self.cache_mutex.lock();
        defer self.cache_mutex.unlock();

        var iterator = self.cache.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.cache.clearAndFree();
        self.current_cache_size.store(0, .Monotonic);
    }

    /// Get networking metrics
    pub fn getMetrics(self: *Self) NetworkMetrics {
        return self.metrics;
    }

    // Private methods

    fn performHttpRequest(self: *Self, req: *const HttpRequest) !HttpResponse {
        // This is a simplified HTTP implementation
        // In a real implementation, you'd use a proper HTTP client library

        // Validate URL
        if (req.url.len == 0) return NetworkError.InvalidUrl;
        if (!std.mem.startsWith(u8, req.url, "http://") and !std.mem.startsWith(u8, req.url, "https://")) {
            return NetworkError.InvalidUrl;
        }

        // Simulate network request based on platform
        return switch (builtin.os.tag) {
            .android => self.performAndroidHttpRequest(req),
            .ios => self.performIOSHttpRequest(req),
            else => self.performGenericHttpRequest(req),
        };
    }

    fn performAndroidHttpRequest(self: *Self, req: *const HttpRequest) !HttpResponse {
        // On Android, you would use JNI to call Java HTTP APIs
        // For now, simulate a response
        _ = req;

        var response = HttpResponse.init(self.allocator);
        response.status_code = 200;
        response.status_text = try self.allocator.dupe(u8, "OK");
        response.body = try self.allocator.dupe(u8, "{}");
        response.content_length = response.body.len;

        try response.headers.put(try self.allocator.dupe(u8, "Content-Type"), try self.allocator.dupe(u8, "application/json"));

        return response;
    }

    fn performIOSHttpRequest(self: *Self, req: *const HttpRequest) !HttpResponse {
        // On iOS, you would use C interop to call NSURLSession APIs
        // For now, simulate a response
        _ = req;

        var response = HttpResponse.init(self.allocator);
        response.status_code = 200;
        response.status_text = try self.allocator.dupe(u8, "OK");
        response.body = try self.allocator.dupe(u8, "{}");
        response.content_length = response.body.len;

        try response.headers.put(try self.allocator.dupe(u8, "Content-Type"), try self.allocator.dupe(u8, "application/json"));

        return response;
    }

    fn performGenericHttpRequest(self: *Self, req: *const HttpRequest) !HttpResponse {
        // Generic implementation using standard library
        // This is a very simplified version
        _ = req;

        var response = HttpResponse.init(self.allocator);
        response.status_code = 200;
        response.status_text = try self.allocator.dupe(u8, "OK");
        response.body = try self.allocator.dupe(u8, "{}");
        response.content_length = response.body.len;

        try response.headers.put(try self.allocator.dupe(u8, "Content-Type"), try self.allocator.dupe(u8, "application/json"));

        return response;
    }

    fn updateNetworkStatus(self: *Self) !void {
        self.status_mutex.lock();
        defer self.status_mutex.unlock();

        // Platform-specific network status detection
        switch (builtin.os.tag) {
            .android => {
                // On Android, you'd use JNI to check ConnectivityManager
                self.status.is_connected = true;
                self.status.connection_type = .wifi;
                self.status.signal_strength = -50;
                self.status.is_metered = false;
                self.status.is_roaming = false;
            },
            .ios => {
                // On iOS, you'd use Reachability APIs
                self.status.is_connected = true;
                self.status.connection_type = .wifi;
                self.status.signal_strength = -45;
                self.status.is_metered = false;
                self.status.is_roaming = false;
            },
            else => {
                // Generic fallback - assume connected
                self.status.is_connected = true;
                self.status.connection_type = .ethernet;
                self.status.signal_strength = 0;
                self.status.is_metered = false;
                self.status.is_roaming = false;
            },
        }
    }

    fn getCachedResponse(self: *Self, url: []const u8) ?*CacheEntry {
        self.cache_mutex.lock();
        defer self.cache_mutex.unlock();

        if (self.cache.getPtr(url)) |entry| {
            if (!entry.isExpired()) {
                return entry;
            } else {
                // Remove expired entry
                _ = self.cache.fetchRemove(url);
                entry.deinit(self.allocator);
            }
        }
        return null;
    }

    fn cacheResponse(self: *Self, url: []const u8, response: *const HttpResponse) !void {
        if (!self.shouldCacheResponse(response)) return;

        self.cache_mutex.lock();
        defer self.cache_mutex.unlock();

        // Calculate cache duration based on Cache-Control headers
        var expires_at = std.time.timestamp() + 3600; // Default 1 hour
        if (response.getHeader("Cache-Control")) |cache_control| {
            if (std.mem.indexOf(u8, cache_control, "max-age=")) |pos| {
                const max_age_str = cache_control[pos + 8 ..];
                if (std.mem.indexOf(u8, max_age_str, ",")) |comma_pos| {
                    const max_age_value = max_age_str[0..comma_pos];
                    if (std.fmt.parseInt(i64, max_age_value, 10)) |max_age| {
                        expires_at = std.time.timestamp() + max_age;
                    } else |_| {}
                } else {
                    if (std.fmt.parseInt(i64, max_age_str, 10)) |max_age| {
                        expires_at = std.time.timestamp() + max_age;
                    } else |_| {}
                }
            }
        }

        // Check if we have space in cache
        const response_size = response.body.len + response.status_text.len;
        const current_size = self.current_cache_size.load(.Monotonic);
        if (current_size + response_size > self.max_cache_size) {
            self.evictOldestCacheEntries(response_size);
        }

        // Create cache entry
        var entry = CacheEntry{
            .response = try response.clone(self.allocator),
            .expires_at = expires_at,
            .etag = null,
            .last_modified = null,
        };

        if (response.getHeader("ETag")) |etag| {
            entry.etag = try self.allocator.dupe(u8, etag);
        }

        if (response.getHeader("Last-Modified")) |lm| {
            entry.last_modified = try self.allocator.dupe(u8, lm);
        }

        const key = try self.allocator.dupe(u8, url);

        // Remove existing entry if present
        if (self.cache.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            const old_size = old.value.response.body.len + old.value.response.status_text.len;
            old.value.deinit(self.allocator);
            _ = self.current_cache_size.fetchSub(old_size, .Monotonic);
        }

        try self.cache.put(key, entry);
        _ = self.current_cache_size.fetchAdd(response_size, .Monotonic);
    }

    fn shouldCacheResponse(self: *Self, response: *const HttpResponse) bool {
        _ = self;

        if (!response.isSuccess()) return false;

        // Don't cache responses with no-cache directive
        if (response.getHeader("Cache-Control")) |cache_control| {
            if (std.mem.indexOf(u8, cache_control, "no-cache") != null or
                std.mem.indexOf(u8, cache_control, "no-store") != null)
            {
                return false;
            }
        }

        return true;
    }

    fn evictOldestCacheEntries(self: *Self, needed_space: usize) void {
        var to_remove = ArrayList([]const u8).init(self.allocator);
        defer to_remove.deinit();

        var oldest_time = std.time.timestamp();
        var freed_space: usize = 0;

        // Find oldest entries to remove
        var iterator = self.cache.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.expires_at < oldest_time and freed_space < needed_space) {
                to_remove.append(entry.key_ptr.*) catch continue;
                freed_space += entry.value_ptr.response.body.len + entry.value_ptr.response.status_text.len;
            }
        }

        // Remove selected entries
        for (to_remove.items) |key| {
            if (self.cache.fetchRemove(key)) |removed| {
                self.allocator.free(removed.key);
                const size = removed.value.response.body.len + removed.value.response.status_text.len;
                removed.value.deinit(self.allocator);
                _ = self.current_cache_size.fetchSub(size, .Monotonic);
            }
        }
    }

    fn isDataUsageLimited(self: *Self) bool {
        if (self.data_usage_limit) |limit| {
            self.status_mutex.lock();
            defer self.status_mutex.unlock();
            return self.status.data_usage_bytes >= limit;
        }
        return false;
    }

    fn monitorWorker(self: *Self) void {
        while (self.monitor_running.load(.SeqCst)) {
            std.time.sleep(MONITOR_INTERVAL_MS * std.time.ns_per_ms);

            // Update network status
            self.updateNetworkStatus() catch |err| {
                std.log.warn("Failed to update network status: {}", .{err});
            };

            // Clean up expired cache entries
            self.cleanupExpiredCache();
        }
    }

    fn cleanupExpiredCache(self: *Self) void {
        self.cache_mutex.lock();
        defer self.cache_mutex.unlock();

        var to_remove = ArrayList([]const u8).init(self.allocator);
        defer to_remove.deinit();

        var iterator = self.cache.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.isExpired()) {
                to_remove.append(entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |key| {
            if (self.cache.fetchRemove(key)) |removed| {
                self.allocator.free(removed.key);
                const size = removed.value.response.body.len + removed.value.response.status_text.len;
                removed.value.deinit(self.allocator);
                _ = self.current_cache_size.fetchSub(size, .Monotonic);
            }
        }
    }
};

// Helper methods for HttpResponse cloning
const HttpResponseCloneError = error{
    OutOfMemory,
};

fn cloneHttpResponse(response: *const HttpResponse, allocator: Allocator) HttpResponseCloneError!HttpResponse {
    var cloned = HttpResponse.init(allocator);
    cloned.status_code = response.status_code;
    cloned.status_text = try allocator.dupe(u8, response.status_text);
    cloned.body = try allocator.dupe(u8, response.body);
    cloned.content_length = response.content_length;
    cloned.is_cached = true;
    cloned.cache_timestamp = std.time.timestamp();

    var iterator = response.headers.iterator();
    while (iterator.next()) |entry| {
        const key = try allocator.dupe(u8, entry.key_ptr.*);
        const value = try allocator.dupe(u8, entry.value_ptr.*);
        try cloned.headers.put(key, value);
    }

    return cloned;
}

// Extension method for HttpResponse
pub fn clone(response: *const HttpResponse, allocator: Allocator) !HttpResponse {
    return cloneHttpResponse(response, allocator);
}

// Global instance
var global_network: ?NetworkManager = null;
var network_mutex = Thread.Mutex{};

/// Initialize the global network manager
pub fn init() !void {
    network_mutex.lock();
    defer network_mutex.unlock();

    if (global_network != null) return;

    const allocator = std.heap.c_allocator;
    global_network = try NetworkManager.init(allocator, "Dowel-Steek/0.1.0");
}

/// Shutdown the global network manager
pub fn shutdown() void {
    network_mutex.lock();
    defer network_mutex.unlock();

    if (global_network) |*network| {
        network.deinit();
        global_network = null;
    }
}

/// Check if the networking system is initialized
pub fn is_initialized() bool {
    return global_network != null;
}

/// Get the global network manager instance
pub fn instance() !*NetworkManager {
    if (global_network) |*network| {
        return network;
    }
    return NetworkError.NotInitialized;
}

// C API exports
export fn dowel_network_is_connected() callconv(.C) bool {
    const network = instance() catch return false;
    return network.isConnected();
}

export fn dowel_network_get_connection_type() callconv(.C) [*:0]const u8 {
    const network = instance() catch return "unknown";
    const status = network.getNetworkStatus();
    const type_str = status.connection_type.toString();

    const c_string = std.heap.c_allocator.dupeZ(u8, type_str) catch return "unknown";
    return c_string.ptr;
}

export fn dowel_network_get_signal_strength() callconv(.C) c_int {
    const network = instance() catch return -100;
    const status = network.getNetworkStatus();
    return status.signal_strength;
}

// Tests
test "network manager initialization" {
    const allocator = std.testing.allocator;
    var network = try NetworkManager.init(allocator, "Test-Agent/1.0");
    defer network.deinit();

    try std.testing.expect(network.initialized);
}

test "http request creation" {
    const allocator = std.testing.allocator;

    var req = HttpRequest.init(allocator);
    defer req.deinit();

    req.method = .POST;
    req.url = "https://api.example.com/data";
    try req.setHeader("Content-Type", "application/json");

    try std.testing.expect(req.method == .POST);
    try std.testing.expectEqualStrings("https://api.example.com/data", req.url);

    const content_type = req.headers.get("Content-Type").?;
    try std.testing.expectEqualStrings("application/json", content_type);
}

test "network status" {
    const allocator = std.testing.allocator;
    var network = try NetworkManager.init(allocator, "Test-Agent/1.0");
    defer network.deinit();

    const status = network.getNetworkStatus();
    try std.testing.expect(status.is_connected);
}
