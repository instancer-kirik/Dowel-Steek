//! Power Management Module for Dowel-Steek Mobile
//!
//! This module provides comprehensive power management functionality for mobile devices.
//! Features include battery monitoring, power state management, wake locks, brightness control,
//! power saving modes, and mobile-specific optimizations.

const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const StringHashMap = std.StringHashMap;
const Thread = std.Thread;
const Atomic = std.atomic.Atomic;

/// Power management errors
pub const PowerError = error{
    NotInitialized,
    PermissionDenied,
    UnsupportedOperation,
    InvalidBrightness,
    WakeLockFailed,
    BatteryNotFound,
    PowerStateError,
    ThermalError,
};

/// Battery state enumeration
pub const BatteryState = enum {
    unknown,
    charging,
    discharging,
    not_charging,
    full,

    pub fn toString(self: BatteryState) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .charging => "charging",
            .discharging => "discharging",
            .not_charging => "not_charging",
            .full => "full",
        };
    }

    pub fn fromString(s: []const u8) BatteryState {
        if (std.mem.eql(u8, s, "charging")) return .charging;
        if (std.mem.eql(u8, s, "discharging")) return .discharging;
        if (std.mem.eql(u8, s, "not_charging")) return .not_charging;
        if (std.mem.eql(u8, s, "full")) return .full;
        return .unknown;
    }
};

/// Power source type
pub const PowerSource = enum {
    battery,
    ac,
    usb,
    wireless,
    unknown,

    pub fn toString(self: PowerSource) []const u8 {
        return switch (self) {
            .battery => "battery",
            .ac => "ac",
            .usb => "usb",
            .wireless => "wireless",
            .unknown => "unknown",
        };
    }
};

/// Thermal state
pub const ThermalState = enum {
    nominal,
    fair,
    serious,
    critical,

    pub fn toString(self: ThermalState) []const u8 {
        return switch (self) {
            .nominal => "nominal",
            .fair => "fair",
            .serious => "serious",
            .critical => "critical",
        };
    }
};

/// Battery information structure
pub const BatteryInfo = struct {
    level: f32, // Battery level percentage (0.0 - 1.0)
    state: BatteryState,
    source: PowerSource,
    voltage: f32, // Battery voltage in volts
    temperature: f32, // Battery temperature in Celsius
    health: f32, // Battery health percentage (0.0 - 1.0)
    time_remaining: ?i64, // Estimated time remaining in seconds
    is_low_power_mode: bool,
    cycle_count: u32,
    capacity: f32, // Current capacity vs design capacity
    last_updated: i64,

    pub fn init() BatteryInfo {
        return BatteryInfo{
            .level = 0.0,
            .state = .unknown,
            .source = .unknown,
            .voltage = 0.0,
            .temperature = 25.0,
            .health = 1.0,
            .time_remaining = null,
            .is_low_power_mode = false,
            .cycle_count = 0,
            .capacity = 1.0,
            .last_updated = std.time.timestamp(),
        };
    }

    pub fn isCharging(self: *const BatteryInfo) bool {
        return self.state == .charging;
    }

    pub fn isLowBattery(self: *const BatteryInfo) bool {
        return self.level < 0.15; // 15% threshold
    }

    pub fn isCriticalBattery(self: *const BatteryInfo) bool {
        return self.level < 0.05; // 5% threshold
    }

    pub fn isHealthy(self: *const BatteryInfo) bool {
        return self.health > 0.8 and self.temperature < 40.0; // 80% health, <40°C
    }
};

/// Wake lock structure
pub const WakeLock = struct {
    tag: []const u8,
    acquired_at: i64,
    timeout_ms: ?u32,
    is_partial: bool, // Partial wake lock (CPU only) vs full (screen + CPU)

    pub fn init(allocator: Allocator, tag: []const u8, timeout_ms: ?u32, is_partial: bool) !WakeLock {
        return WakeLock{
            .tag = try allocator.dupe(u8, tag),
            .acquired_at = std.time.timestamp(),
            .timeout_ms = timeout_ms,
            .is_partial = is_partial,
        };
    }

    pub fn deinit(self: *WakeLock, allocator: Allocator) void {
        allocator.free(self.tag);
    }

    pub fn isExpired(self: *const WakeLock) bool {
        if (self.timeout_ms) |timeout| {
            const now = std.time.timestamp();
            const elapsed_ms = @as(u32, @intCast((now - self.acquired_at) * 1000));
            return elapsed_ms >= timeout;
        }
        return false;
    }
};

/// Power metrics for monitoring
pub const PowerMetrics = struct {
    wake_locks_acquired: Atomic(u64),
    wake_locks_released: Atomic(u64),
    brightness_changes: Atomic(u64),
    power_mode_changes: Atomic(u64),
    battery_level_samples: Atomic(u64),
    thermal_events: Atomic(u64),
    power_save_activations: Atomic(u64),

    pub fn init() PowerMetrics {
        return PowerMetrics{
            .wake_locks_acquired = Atomic(u64).init(0),
            .wake_locks_released = Atomic(u64).init(0),
            .brightness_changes = Atomic(u64).init(0),
            .power_mode_changes = Atomic(u64).init(0),
            .battery_level_samples = Atomic(u64).init(0),
            .thermal_events = Atomic(u64).init(0),
            .power_save_activations = Atomic(u64).init(0),
        };
    }
};

/// Power change callback
pub const PowerChangeCallback = *const fn (event: PowerEvent, data: ?*anyopaque) void;

/// Power events
pub const PowerEvent = enum {
    battery_level_changed,
    battery_state_changed,
    power_source_changed,
    low_battery_warning,
    critical_battery_warning,
    thermal_state_changed,
    power_save_mode_changed,
    wake_lock_acquired,
    wake_lock_released,
};

/// Main power manager
pub const PowerManager = struct {
    allocator: Allocator,
    battery_info: BatteryInfo,
    wake_locks: StringHashMap(WakeLock),
    wake_lock_mutex: Thread.Mutex,
    current_brightness: f32,
    auto_brightness: bool,
    power_save_mode: bool,
    thermal_state: ThermalState,
    metrics: PowerMetrics,
    callbacks: ArrayList(struct {
        callback: PowerChangeCallback,
        user_data: ?*anyopaque,
    }),
    initialized: bool,
    monitor_thread: ?Thread,
    monitor_running: Atomic(bool),
    info_mutex: Thread.Mutex,

    const Self = @This();
    const MONITOR_INTERVAL_MS = 30000; // 30 seconds
    const WAKE_LOCK_CLEANUP_INTERVAL_MS = 60000; // 1 minute

    pub fn init(allocator: Allocator) !Self {
        var manager = Self{
            .allocator = allocator,
            .battery_info = BatteryInfo.init(),
            .wake_locks = StringHashMap(WakeLock).init(allocator),
            .wake_lock_mutex = Thread.Mutex{},
            .current_brightness = 0.5,
            .auto_brightness = true,
            .power_save_mode = false,
            .thermal_state = .nominal,
            .metrics = PowerMetrics.init(),
            .callbacks = ArrayList(@TypeOf(Self.callbacks).Child).init(allocator),
            .initialized = false,
            .monitor_thread = null,
            .monitor_running = Atomic(bool).init(false),
            .info_mutex = Thread.Mutex{},
        };

        // Initialize battery info
        try manager.updateBatteryInfo();

        // Start monitoring thread
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

        // Release all wake locks
        self.wake_lock_mutex.lock();
        var iterator = self.wake_locks.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.wake_locks.deinit();
        self.wake_lock_mutex.unlock();

        // Clean up callbacks
        self.callbacks.deinit();

        self.initialized = false;
    }

    /// Get current battery information
    pub fn getBatteryInfo(self: *Self) BatteryInfo {
        self.info_mutex.lock();
        defer self.info_mutex.unlock();
        return self.battery_info;
    }

    /// Get battery level (0.0 - 1.0)
    pub fn getBatteryLevel(self: *Self) f32 {
        self.info_mutex.lock();
        defer self.info_mutex.unlock();
        return self.battery_info.level;
    }

    /// Get battery state as string
    pub fn getBatteryState(self: *Self) []const u8 {
        self.info_mutex.lock();
        defer self.info_mutex.unlock();
        return self.battery_info.state.toString();
    }

    /// Check if device is charging
    pub fn isCharging(self: *Self) bool {
        self.info_mutex.lock();
        defer self.info_mutex.unlock();
        return self.battery_info.isCharging();
    }

    /// Check if battery is low
    pub fn isLowBattery(self: *Self) bool {
        self.info_mutex.lock();
        defer self.info_mutex.unlock();
        return self.battery_info.isLowBattery();
    }

    /// Acquire a wake lock to prevent sleep
    pub fn acquireWakeLock(self: *Self, tag: []const u8, timeout_ms: ?u32, is_partial: bool) !void {
        if (!self.initialized) return PowerError.NotInitialized;

        self.wake_lock_mutex.lock();
        defer self.wake_lock_mutex.unlock();

        // Check if wake lock already exists
        if (self.wake_locks.contains(tag)) {
            return; // Already acquired
        }

        const wake_lock = try WakeLock.init(self.allocator, tag, timeout_ms, is_partial);
        const key = try self.allocator.dupe(u8, tag);

        // Platform-specific wake lock acquisition
        self.platformAcquireWakeLock(tag, is_partial) catch |err| {
            self.allocator.free(key);
            var mutable_lock = wake_lock;
            mutable_lock.deinit(self.allocator);
            return err;
        };

        try self.wake_locks.put(key, wake_lock);
        _ = self.metrics.wake_locks_acquired.fetchAdd(1, .Monotonic);

        // Notify callbacks
        self.notifyCallbacks(.wake_lock_acquired, @ptrCast(@constCast(tag.ptr)));
    }

    /// Release a wake lock
    pub fn releaseWakeLock(self: *Self, tag: []const u8) void {
        if (!self.initialized) return;

        self.wake_lock_mutex.lock();
        defer self.wake_lock_mutex.unlock();

        if (self.wake_locks.fetchRemove(tag)) |removed| {
            self.platformReleaseWakeLock(tag);
            self.allocator.free(removed.key);
            removed.value.deinit(self.allocator);
            _ = self.metrics.wake_locks_released.fetchAdd(1, .Monotonic);

            // Notify callbacks
            self.notifyCallbacks(.wake_lock_released, @ptrCast(@constCast(tag.ptr)));
        }
    }

    /// Check if wake lock is held
    pub fn isWakeLockHeld(self: *Self, tag: []const u8) bool {
        self.wake_lock_mutex.lock();
        defer self.wake_lock_mutex.unlock();
        return self.wake_locks.contains(tag);
    }

    /// Get list of active wake locks
    pub fn getActiveWakeLocks(self: *Self) ![][]const u8 {
        self.wake_lock_mutex.lock();
        defer self.wake_lock_mutex.unlock();

        var tags = ArrayList([]const u8).init(self.allocator);
        var iterator = self.wake_locks.iterator();
        while (iterator.next()) |entry| {
            try tags.append(try self.allocator.dupe(u8, entry.key_ptr.*));
        }

        return try tags.toOwnedSlice();
    }

    /// Set screen brightness (0.0 - 1.0)
    pub fn setBrightness(self: *Self, brightness: f32) !void {
        if (!self.initialized) return PowerError.NotInitialized;
        if (brightness < 0.0 or brightness > 1.0) return PowerError.InvalidBrightness;

        const old_brightness = self.current_brightness;
        self.current_brightness = brightness;

        // Platform-specific brightness setting
        self.platformSetBrightness(brightness) catch |err| {
            self.current_brightness = old_brightness;
            return err;
        };

        _ = self.metrics.brightness_changes.fetchAdd(1, .Monotonic);
    }

    /// Get current screen brightness
    pub fn getBrightness(self: *Self) f32 {
        return self.current_brightness;
    }

    /// Enable or disable auto brightness
    pub fn setAutoBrightness(self: *Self, enabled: bool) !void {
        if (!self.initialized) return PowerError.NotInitialized;

        self.auto_brightness = enabled;
        try self.platformSetAutoBrightness(enabled);
    }

    /// Check if auto brightness is enabled
    pub fn isAutoBrightnessEnabled(self: *Self) bool {
        return self.auto_brightness;
    }

    /// Enable or disable power save mode
    pub fn setPowerSaveMode(self: *Self, enabled: bool) !void {
        if (!self.initialized) return PowerError.NotInitialized;

        const old_mode = self.power_save_mode;
        self.power_save_mode = enabled;

        self.platformSetPowerSaveMode(enabled) catch |err| {
            self.power_save_mode = old_mode;
            return err;
        };

        _ = self.metrics.power_mode_changes.fetchAdd(1, .Monotonic);
        if (enabled) {
            _ = self.metrics.power_save_activations.fetchAdd(1, .Monotonic);
        }

        // Notify callbacks
        self.notifyCallbacks(.power_save_mode_changed, @ptrCast(&enabled));
    }

    /// Check if power save mode is enabled
    pub fn isPowerSaveModeEnabled(self: *Self) bool {
        return self.power_save_mode;
    }

    /// Get thermal state
    pub fn getThermalState(self: *Self) ThermalState {
        return self.thermal_state;
    }

    /// Register power change callback
    pub fn registerCallback(self: *Self, callback: PowerChangeCallback, user_data: ?*anyopaque) !void {
        try self.callbacks.append(.{
            .callback = callback,
            .user_data = user_data,
        });
    }

    /// Get power metrics
    pub fn getMetrics(self: *Self) PowerMetrics {
        return self.metrics;
    }

    // Private methods

    fn updateBatteryInfo(self: *Self) !void {
        self.info_mutex.lock();
        defer self.info_mutex.unlock();

        const old_info = self.battery_info;

        // Platform-specific battery info update
        self.battery_info = switch (builtin.os.tag) {
            .android => try self.getAndroidBatteryInfo(),
            .ios => try self.getIOSBatteryInfo(),
            else => try self.getGenericBatteryInfo(),
        };

        self.battery_info.last_updated = std.time.timestamp();
        _ = self.metrics.battery_level_samples.fetchAdd(1, .Monotonic);

        // Check for significant changes and notify callbacks
        if (@abs(old_info.level - self.battery_info.level) > 0.01) { // 1% change
            self.notifyCallbacks(.battery_level_changed, @ptrCast(&self.battery_info.level));
        }

        if (old_info.state != self.battery_info.state) {
            self.notifyCallbacks(.battery_state_changed, @ptrCast(&self.battery_info.state));
        }

        if (old_info.source != self.battery_info.source) {
            self.notifyCallbacks(.power_source_changed, @ptrCast(&self.battery_info.source));
        }

        // Check for low battery warnings
        if (!old_info.isLowBattery() and self.battery_info.isLowBattery()) {
            self.notifyCallbacks(.low_battery_warning, @ptrCast(&self.battery_info.level));
        }

        if (!old_info.isCriticalBattery() and self.battery_info.isCriticalBattery()) {
            self.notifyCallbacks(.critical_battery_warning, @ptrCast(&self.battery_info.level));
        }
    }

    fn getAndroidBatteryInfo(self: *Self) !BatteryInfo {
        // On Android, you would use JNI to access BatteryManager
        // For now, simulate battery info
        _ = self;

        var info = BatteryInfo.init();
        info.level = 0.75; // 75%
        info.state = .discharging;
        info.source = .battery;
        info.voltage = 3.8;
        info.temperature = 28.5;
        info.health = 0.92;
        info.time_remaining = 14400; // 4 hours
        info.cycle_count = 150;
        info.capacity = 0.88;

        return info;
    }

    fn getIOSBatteryInfo(self: *Self) !BatteryInfo {
        // On iOS, you would use UIDevice batteryLevel, batteryState, etc.
        // For now, simulate battery info
        _ = self;

        var info = BatteryInfo.init();
        info.level = 0.85; // 85%
        info.state = .charging;
        info.source = .usb;
        info.voltage = 4.1;
        info.temperature = 25.0;
        info.health = 0.95;
        info.is_low_power_mode = false;
        info.cycle_count = 89;
        info.capacity = 0.94;

        return info;
    }

    fn getGenericBatteryInfo(self: *Self) !BatteryInfo {
        // Generic implementation - read from /sys/class/power_supply on Linux
        _ = self;

        var info = BatteryInfo.init();

        // Try to read from Linux power supply interface
        if (builtin.os.tag == .linux) {
            // Read battery capacity
            if (std.fs.cwd().openFile("/sys/class/power_supply/BAT0/capacity", .{})) |file| {
                defer file.close();
                var buffer: [16]u8 = undefined;
                if (file.readAll(&buffer)) |bytes_read| {
                    const capacity_str = std.mem.trim(u8, buffer[0..bytes_read], " \n\r\t");
                    if (std.fmt.parseInt(u8, capacity_str, 10)) |capacity| {
                        info.level = @as(f32, @floatFromInt(capacity)) / 100.0;
                    } else |_| {}
                } else |_| {}
            } else |_| {
                // Fallback values
                info.level = 0.80; // 80%
            }

            // Read battery status
            if (std.fs.cwd().openFile("/sys/class/power_supply/BAT0/status", .{})) |file| {
                defer file.close();
                var buffer: [32]u8 = undefined;
                if (file.readAll(&buffer)) |bytes_read| {
                    const status_str = std.mem.trim(u8, buffer[0..bytes_read], " \n\r\t");
                    if (std.mem.eql(u8, status_str, "Charging")) {
                        info.state = .charging;
                    } else if (std.mem.eql(u8, status_str, "Discharging")) {
                        info.state = .discharging;
                    } else if (std.mem.eql(u8, status_str, "Full")) {
                        info.state = .full;
                    } else {
                        info.state = .not_charging;
                    }
                } else |_| {}
            } else |_| {
                info.state = .discharging;
            }
        } else {
            // Default values for other platforms
            info.level = 0.50;
            info.state = .unknown;
        }

        info.source = .battery;
        info.voltage = 3.7;
        info.temperature = 30.0;
        info.health = 0.90;
        info.cycle_count = 200;
        info.capacity = 0.85;

        return info;
    }

    fn platformAcquireWakeLock(self: *Self, tag: []const u8, is_partial: bool) !void {
        _ = self;
        _ = is_partial;

        switch (builtin.os.tag) {
            .android => {
                // On Android, you would use JNI to call PowerManager.newWakeLock()
                std.log.debug("Android wake lock acquired: {s}", .{tag});
            },
            .ios => {
                // On iOS, you would use [[UIApplication sharedApplication] setIdleTimerDisabled:YES]
                std.log.debug("iOS wake lock acquired: {s}", .{tag});
            },
            else => {
                // Generic implementation - could interface with system power management
                std.log.debug("Generic wake lock acquired: {s}", .{tag});
            },
        }
    }

    fn platformReleaseWakeLock(self: *Self, tag: []const u8) void {
        _ = self;

        switch (builtin.os.tag) {
            .android => {
                std.log.debug("Android wake lock released: {s}", .{tag});
            },
            .ios => {
                std.log.debug("iOS wake lock released: {s}", .{tag});
            },
            else => {
                std.log.debug("Generic wake lock released: {s}", .{tag});
            },
        }
    }

    fn platformSetBrightness(self: *Self, brightness: f32) !void {
        _ = self;

        switch (builtin.os.tag) {
            .android => {
                // On Android, you would modify WindowManager.LayoutParams.screenBrightness
                std.log.debug("Android brightness set to: {d}", .{brightness});
            },
            .ios => {
                // On iOS, you would use [[UIScreen mainScreen] setBrightness:]
                std.log.debug("iOS brightness set to: {d}", .{brightness});
            },
            else => {
                // Generic implementation - could write to /sys/class/backlight
                if (builtin.os.tag == .linux) {
                    // Try to set brightness via sysfs
                    if (std.fs.cwd().openFile("/sys/class/backlight/intel_backlight/brightness", .{ .mode = .write_only })) |file| {
                        defer file.close();

                        // Read max brightness first
                        var max_brightness: u32 = 255; // default
                        if (std.fs.cwd().openFile("/sys/class/backlight/intel_backlight/max_brightness", .{})) |max_file| {
                            defer max_file.close();
                            var buffer: [16]u8 = undefined;
                            if (max_file.readAll(&buffer)) |bytes_read| {
                                const max_str = std.mem.trim(u8, buffer[0..bytes_read], " \n\r\t");
                                max_brightness = std.fmt.parseInt(u32, max_str, 10) catch 255;
                            } else |_| {}
                        } else |_| {}

                        const target_brightness = @as(u32, @intFromFloat(brightness * @as(f32, @floatFromInt(max_brightness))));
                        var brightness_str: [16]u8 = undefined;
                        const formatted = std.fmt.bufPrint(&brightness_str, "{d}", .{target_brightness}) catch return;

                        file.writeAll(formatted) catch return PowerError.PermissionDenied;
                    } else |_| {
                        return PowerError.UnsupportedOperation;
                    }
                }
                std.log.debug("Generic brightness set to: {d}", .{brightness});
            },
        }
    }

    fn platformSetAutoBrightness(self: *Self, enabled: bool) !void {
        _ = self;

        switch (builtin.os.tag) {
            .android => {
                // On Android, you would use Settings.System.putInt for SCREEN_BRIGHTNESS_MODE
                std.log.debug("Android auto-brightness: {}", .{enabled});
            },
            .ios => {
                // iOS doesn't allow direct control of auto-brightness
                std.log.debug("iOS auto-brightness: {} (not directly controllable)", .{enabled});
            },
            else => {
                std.log.debug("Generic auto-brightness: {}", .{enabled});
            },
        }
    }

    fn platformSetPowerSaveMode(self: *Self, enabled: bool) !void {
        _ = self;

        switch (builtin.os.tag) {
            .android => {
                // On Android, you would need system-level permissions to enable power save mode
                std.log.debug("Android power save mode: {}", .{enabled});
            },
            .ios => {
                // iOS Low Power Mode can only be enabled by the user
                std.log.debug("iOS power save mode: {} (user controlled)", .{enabled});
            },
            else => {
                std.log.debug("Generic power save mode: {}", .{enabled});
            },
        }
    }

    fn notifyCallbacks(self: *Self, event: PowerEvent, data: ?*anyopaque) void {
        for (self.callbacks.items) |callback_info| {
            callback_info.callback(event, callback_info.user_data orelse data);
        }
    }

    fn monitorWorker(self: *Self) void {
        var cleanup_timer: u32 = 0;

        while (self.monitor_running.load(.SeqCst)) {
            std.time.sleep(MONITOR_INTERVAL_MS * std.time.ns_per_ms);

            // Update battery info
            self.updateBatteryInfo() catch |err| {
                std.log.warn("Failed to update battery info: {}", .{err});
            };

            // Clean up expired wake locks every minute
            cleanup_timer += MONITOR_INTERVAL_MS;
            if (cleanup_timer >= WAKE_LOCK_CLEANUP_INTERVAL_MS) {
                self.cleanupExpiredWakeLocks();
                cleanup_timer = 0;
            }

            // Update thermal state
            self.updateThermalState() catch |err| {
                std.log.warn("Failed to update thermal state: {}", .{err});
            };
        }
    }

    fn cleanupExpiredWakeLocks(self: *Self) void {
        self.wake_lock_mutex.lock();
        defer self.wake_lock_mutex.unlock();

        var to_remove = ArrayList([]const u8).init(self.allocator);
        defer to_remove.deinit();

        var iterator = self.wake_locks.iterator();
        while (iterator.next()) |entry| {
            if (entry.value_ptr.isExpired()) {
                to_remove.append(entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |tag| {
            if (self.wake_locks.fetchRemove(tag)) |removed| {
                self.platformReleaseWakeLock(tag);
                self.allocator.free(removed.key);
                removed.value.deinit(self.allocator);
                _ = self.metrics.wake_locks_released.fetchAdd(1, .Monotonic);
            }
        }
    }

    fn updateThermalState(self: *Self) !void {
        const old_state = self.thermal_state;

        // Platform-specific thermal state detection
        self.thermal_state = switch (builtin.os.tag) {
            .android => self.getAndroidThermalState(),
            .ios => self.getIOSThermalState(),
            else => self.getGenericThermalState(),
        };

        if (old_state != self.thermal_state) {
            _ = self.metrics.thermal_events.fetchAdd(1, .Monotonic);
            self.notifyCallbacks(.thermal_state_changed, @ptrCast(&self.thermal_state));
        }
    }

    fn getAndroidThermalState(self: *Self) ThermalState {
        // On Android, you would use PowerManager.getThermalState()
        _ = self;
        return .nominal; // Placeholder
    }

    fn getIOSThermalState(self: *Self) ThermalState {
        // On iOS, you would use ProcessInfo.thermalState
        _ = self;
        return .nominal; // Placeholder
    }

    fn getGenericThermalState(self: *Self) ThermalState {
        // Generic implementation - check system temperature
        _ = self;

        // Try to read CPU temperature on Linux
        if (builtin.os.tag == .linux) {
            if (std.fs.cwd().openFile("/sys/class/thermal/thermal_zone0/temp", .{})) |file| {
                defer file.close();
                var buffer: [16]u8 = undefined;
                if (file.readAll(&buffer)) |bytes| {
                    const temp_str = std.mem.trim(u8, buffer[0..bytes], " \n\r\t");
                    if (std.fmt.parseInt(i32, temp_str, 10)) |temp_millicelsius| {
                        const temp_celsius = temp_millicelsius / 1000;
                        if (temp_celsius > 80) return .critical;
                        if (temp_celsius > 70) return .hot;
                        if (temp_celsius > 60) return .warm;
                        return .normal;
                    } else |_| {}
                } else |_| {}
            } else |_| {}
        }

        return .normal;
    }
}

test "power management basic functionality" {
    const allocator = std.testing.allocator;
    var power_manager = try PowerManager.init(allocator);
    defer power_manager.deinit();

    const battery_info = power_manager.getBatteryInfo();
    try std.testing.expect(battery_info.level >= 0.0 and battery_info.level <= 1.0);
}
