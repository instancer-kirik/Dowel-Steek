//! Mobile Sensors Module
//! Provides access to device sensors like accelerometer, gyroscope, magnetometer, etc.
//! Optimized for battery life and performance on mobile devices.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Error types for sensor operations
pub const SensorError = error{
    SensorNotAvailable,
    SensorNotEnabled,
    PermissionDenied,
    InvalidSampleRate,
    CalibrationRequired,
    HardwareError,
    BufferOverflow,
    OutOfMemory,
};

/// Available sensor types
pub const SensorType = enum {
    accelerometer,
    gyroscope,
    magnetometer,
    proximity,
    ambient_light,
    pressure,
    temperature,
    humidity,
    gravity,
    linear_acceleration,
    rotation_vector,
    orientation,
    step_counter,
    step_detector,
    heart_rate,
    game_rotation_vector,
    geomagnetic_rotation_vector,
    significant_motion,

    pub fn toString(self: SensorType) []const u8 {
        return switch (self) {
            .accelerometer => "accelerometer",
            .gyroscope => "gyroscope",
            .magnetometer => "magnetometer",
            .proximity => "proximity",
            .ambient_light => "ambient_light",
            .pressure => "pressure",
            .temperature => "temperature",
            .humidity => "humidity",
            .gravity => "gravity",
            .linear_acceleration => "linear_acceleration",
            .rotation_vector => "rotation_vector",
            .orientation => "orientation",
            .step_counter => "step_counter",
            .step_detector => "step_detector",
            .heart_rate => "heart_rate",
            .game_rotation_vector => "game_rotation_vector",
            .geomagnetic_rotation_vector => "geomagnetic_rotation_vector",
            .significant_motion => "significant_motion",
        };
    }
};

/// Sensor data accuracy levels
pub const SensorAccuracy = enum(u8) {
    unreliable = 0,
    low = 1,
    medium = 2,
    high = 3,
};

/// 3D vector data for motion sensors
pub const Vector3D = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn magnitude(self: Vector3D) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn normalize(self: Vector3D) Vector3D {
        const mag = self.magnitude();
        if (mag == 0) return Vector3D{ .x = 0, .y = 0, .z = 0 };
        return Vector3D{
            .x = self.x / mag,
            .y = self.y / mag,
            .z = self.z / mag,
        };
    }
};

/// Quaternion data for rotation sensors
pub const Quaternion = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub fn normalize(self: Quaternion) Quaternion {
        const mag = @sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w);
        if (mag == 0) return Quaternion{ .x = 0, .y = 0, .z = 0, .w = 1 };
        return Quaternion{
            .x = self.x / mag,
            .y = self.y / mag,
            .z = self.z / mag,
            .w = self.w / mag,
        };
    }

    pub fn toEulerAngles(self: Quaternion) Vector3D {
        // Convert quaternion to Euler angles (roll, pitch, yaw)
        const roll = std.math.atan2(f32, 2 * (self.w * self.x + self.y * self.z), 1 - 2 * (self.x * self.x + self.y * self.y));
        const pitch = std.math.asin(2 * (self.w * self.y - self.z * self.x));
        const yaw = std.math.atan2(f32, 2 * (self.w * self.z + self.x * self.y), 1 - 2 * (self.y * self.y + self.z * self.z));

        return Vector3D{
            .x = roll,
            .y = pitch,
            .z = yaw,
        };
    }
};

/// Generic sensor data structure
pub const SensorData = union(SensorType) {
    accelerometer: struct {
        acceleration: Vector3D, // m/s²
        timestamp: i64, // nanoseconds since boot
        accuracy: SensorAccuracy,
    },
    gyroscope: struct {
        angular_velocity: Vector3D, // rad/s
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    magnetometer: struct {
        magnetic_field: Vector3D, // μT (microtesla)
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    proximity: struct {
        distance: f32, // cm (or boolean 0/1 for near/far)
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    ambient_light: struct {
        illuminance: f32, // lux
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    pressure: struct {
        pressure: f32, // hPa (hectopascals)
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    temperature: struct {
        temperature: f32, // °C
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    humidity: struct {
        humidity: f32, // % relative humidity
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    gravity: struct {
        gravity: Vector3D, // m/s²
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    linear_acceleration: struct {
        acceleration: Vector3D, // m/s² (gravity removed)
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    rotation_vector: struct {
        rotation: Quaternion,
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    orientation: struct {
        orientation: Vector3D, // degrees (azimuth, pitch, roll)
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    step_counter: struct {
        steps: u64, // total steps since last reboot
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    step_detector: struct {
        step_detected: bool,
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    heart_rate: struct {
        heart_rate: f32, // beats per minute
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    game_rotation_vector: struct {
        rotation: Quaternion, // no magnetometer
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    geomagnetic_rotation_vector: struct {
        rotation: Quaternion, // no gyroscope
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
    significant_motion: struct {
        motion_detected: bool,
        timestamp: i64,
        accuracy: SensorAccuracy,
    },
};

/// Sensor sample rates
pub const SensorRate = enum(u32) {
    fastest = 0, // ~200Hz
    game = 20_000, // ~50Hz
    ui = 66_667, // ~15Hz
    normal = 200_000, // ~5Hz
    custom = 0, // Use custom delay

    pub fn toMicroseconds(self: SensorRate) u32 {
        return switch (self) {
            .fastest => 0,
            .game => 20_000,
            .ui => 66_667,
            .normal => 200_000,
            .custom => 0,
        };
    }
};

/// Sensor configuration
pub const SensorConfig = struct {
    sensor_type: SensorType,
    sample_rate: SensorRate,
    custom_delay_us: u32 = 0, // Used when sample_rate is custom
    batch_latency_us: u32 = 0, // Max delay before delivering batch
    fifo_max_event_count: u32 = 0, // Max events in FIFO (0 = no batching)
    wake_up_sensor: bool = false, // Wake up CPU for readings
};

/// Sensor callback function type
pub const SensorCallback = *const fn (data: SensorData, userdata: ?*anyopaque) void;

/// Sensor information
pub const SensorInfo = struct {
    name: []const u8,
    vendor: []const u8,
    version: u32,
    sensor_type: SensorType,
    max_range: f32,
    resolution: f32,
    power_consumption: f32, // mA
    min_delay_us: u32,
    max_delay_us: u32,
    fifo_reserved_event_count: u32,
    fifo_max_event_count: u32,
    string_type: []const u8,
    required_permission: []const u8,
    is_wake_up_sensor: bool,
    is_dynamic_sensor: bool,
    is_additional_info_supported: bool,
};

/// Sensor handle for active sensors
pub const SensorHandle = struct {
    id: u32,
    sensor_type: SensorType,
    config: SensorConfig,
    callback: ?SensorCallback,
    userdata: ?*anyopaque,
    is_active: bool,
    last_timestamp: i64,
    sample_count: u64,
    battery_impact: f32, // Estimated battery drain per hour (mAh)
};

/// Main sensor manager
pub const SensorManager = struct {
    const Self = @This();
    const MAX_SENSORS = 32;
    const SENSOR_BUFFER_SIZE = 1024;

    allocator: Allocator,
    sensors: std.ArrayList(SensorHandle),
    available_sensors: std.ArrayList(SensorInfo),
    sensor_buffer: std.fifo.LinearFifo(SensorData, .Dynamic),
    next_handle_id: u32,
    is_initialized: bool,
    power_save_mode: bool,
    battery_level: f32,

    // Platform-specific sensor interface
    platform_init: ?*const fn () SensorError!void,
    platform_deinit: ?*const fn () void,
    platform_get_sensor_list: ?*const fn (sensors: *std.ArrayList(SensorInfo)) SensorError!void,
    platform_enable_sensor: ?*const fn (sensor_type: SensorType, config: SensorConfig) SensorError!u32,
    platform_disable_sensor: ?*const fn (handle_id: u32) SensorError!void,
    platform_get_sensor_data: ?*const fn (handle_id: u32, data: *SensorData) SensorError!bool,

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .sensors = std.ArrayList(SensorHandle).init(allocator),
            .available_sensors = std.ArrayList(SensorInfo).init(allocator),
            .sensor_buffer = std.fifo.LinearFifo(SensorData, .Dynamic).init(allocator),
            .next_handle_id = 1,
            .is_initialized = false,
            .power_save_mode = false,
            .battery_level = 1.0,
            .platform_init = null,
            .platform_deinit = null,
            .platform_get_sensor_list = null,
            .platform_enable_sensor = null,
            .platform_disable_sensor = null,
            .platform_get_sensor_data = null,
        };
    }

    pub fn deinit(self: *Self) void {
        // Disable all active sensors
        for (self.sensors.items) |*sensor| {
            if (sensor.is_active) {
                self.disableSensor(sensor.id) catch {};
            }
        }

        // Platform cleanup
        if (self.platform_deinit) |platform_deinit| {
            platform_deinit();
        }

        self.sensors.deinit();
        self.available_sensors.deinit();
        self.sensor_buffer.deinit();
        self.is_initialized = false;
    }

    /// Initialize sensor subsystem
    pub fn initialize(self: *Self) SensorError!void {
        if (self.is_initialized) return;

        // Platform-specific initialization
        if (self.platform_init) |platform_init| {
            try platform_init();
        }

        // Get list of available sensors
        if (self.platform_get_sensor_list) |platform_get_sensor_list| {
            try platform_get_sensor_list(&self.available_sensors);
        }

        // Initialize sensor buffer
        try self.sensor_buffer.ensureTotalCapacity(SENSOR_BUFFER_SIZE);

        self.is_initialized = true;
    }

    /// Get list of available sensors
    pub fn getAvailableSensors(self: *Self) []const SensorInfo {
        return self.available_sensors.items;
    }

    /// Check if a sensor type is available
    pub fn isSensorAvailable(self: *Self, sensor_type: SensorType) bool {
        for (self.available_sensors.items) |sensor| {
            if (sensor.sensor_type == sensor_type) return true;
        }
        return false;
    }

    /// Get sensor information
    pub fn getSensorInfo(self: *Self, sensor_type: SensorType) ?SensorInfo {
        for (self.available_sensors.items) |sensor| {
            if (sensor.sensor_type == sensor_type) return sensor;
        }
        return null;
    }

    /// Enable a sensor with configuration
    pub fn enableSensor(self: *Self, config: SensorConfig, callback: ?SensorCallback, userdata: ?*anyopaque) SensorError!u32 {
        if (!self.is_initialized) return SensorError.SensorNotAvailable;
        if (!self.isSensorAvailable(config.sensor_type)) return SensorError.SensorNotAvailable;

        // Check for existing sensor of same type
        for (self.sensors.items) |sensor| {
            if (sensor.sensor_type == config.sensor_type and sensor.is_active) {
                // Update existing sensor configuration
                return self.updateSensorConfig(sensor.id, config);
            }
        }

        // Enable sensor at platform level
        _ = if (self.platform_enable_sensor) |platform_enable_sensor|
            try platform_enable_sensor(config.sensor_type, config)
        else
            0;

        // Create sensor handle
        const handle = SensorHandle{
            .id = self.next_handle_id,
            .sensor_type = config.sensor_type,
            .config = config,
            .callback = callback,
            .userdata = userdata,
            .is_active = true,
            .last_timestamp = 0,
            .sample_count = 0,
            .battery_impact = self.calculateBatteryImpact(config),
        };

        try self.sensors.append(handle);
        self.next_handle_id += 1;

        return handle.id;
    }

    /// Disable a sensor
    pub fn disableSensor(self: *Self, handle_id: u32) SensorError!void {
        for (self.sensors.items, 0..) |*sensor, i| {
            if (sensor.id == handle_id) {
                if (sensor.is_active) {
                    // Disable at platform level
                    if (self.platform_disable_sensor) |platform_disable_sensor| {
                        try platform_disable_sensor(handle_id);
                    }

                    sensor.is_active = false;
                }

                // Remove from active sensors list
                _ = self.sensors.orderedRemove(i);
                return;
            }
        }
        return SensorError.SensorNotAvailable;
    }

    /// Update sensor configuration
    pub fn updateSensorConfig(self: *Self, handle_id: u32, new_config: SensorConfig) SensorError!u32 {
        // Disable current sensor
        try self.disableSensor(handle_id);

        // Re-enable with new configuration
        // Note: callback and userdata would need to be preserved,
        // this is a simplified implementation
        return self.enableSensor(new_config, null, null);
    }

    /// Poll for sensor data (non-blocking)
    pub fn pollSensorData(self: *Self) SensorError!?SensorData {
        if (self.sensor_buffer.readItem()) |data| {
            return data;
        }
        return null;
    }

    /// Wait for sensor data (blocking with timeout)
    pub fn waitForSensorData(self: *Self, timeout_ms: u32) SensorError!?SensorData {
        const start_time = std.time.milliTimestamp();

        while (std.time.milliTimestamp() - start_time < timeout_ms) {
            if (try self.pollSensorData()) |data| {
                return data;
            }
            std.time.sleep(1_000_000); // Sleep 1ms
        }

        return null;
    }

    /// Process sensor readings (called by platform layer)
    pub fn processSensorReading(self: *Self, handle_id: u32, data: SensorData) void {
        // Find the sensor handle
        for (self.sensors.items) |*sensor| {
            if (sensor.id == handle_id and sensor.is_active) {
                // Update statistics
                sensor.sample_count += 1;

                // Extract timestamp for rate limiting
                const timestamp = switch (data) {
                    inline else => |sensor_data| sensor_data.timestamp,
                };
                sensor.last_timestamp = timestamp;

                // Call callback if registered
                if (sensor.callback) |callback| {
                    callback(data, sensor.userdata);
                }

                // Add to buffer for polling
                self.sensor_buffer.writeItem(data) catch {
                    // Buffer full, remove oldest item and retry
                    _ = self.sensor_buffer.readItem();
                    self.sensor_buffer.writeItem(data) catch {};
                };

                break;
            }
        }
    }

    /// Set power save mode
    pub fn setPowerSaveMode(self: *Self, enabled: bool) void {
        self.power_save_mode = enabled;

        if (enabled) {
            // Reduce sample rates for battery savings
            for (self.sensors.items) |*sensor| {
                if (sensor.is_active and sensor.config.sample_rate == .fastest) {
                    // Downgrade to game rate in power save mode
                    var new_config = sensor.config;
                    new_config.sample_rate = .game;
                    _ = self.updateSensorConfig(sensor.id, new_config) catch {};
                }
            }
        }
    }

    /// Update battery level (affects power management decisions)
    pub fn updateBatteryLevel(self: *Self, level: f32) void {
        self.battery_level = @max(0.0, @min(1.0, level));

        // Automatic power save mode when battery is low
        if (self.battery_level < 0.15) { // Below 15%
            self.setPowerSaveMode(true);
        } else if (self.battery_level > 0.20) { // Above 20%
            self.setPowerSaveMode(false);
        }
    }

    /// Calculate estimated battery impact for sensor configuration
    fn calculateBatteryImpact(self: *Self, config: SensorConfig) f32 {
        _ = self;

        // Get sensor info for power consumption
        const base_power: f32 = switch (config.sensor_type) {
            .accelerometer => 0.5, // mA
            .gyroscope => 6.1,
            .magnetometer => 0.9,
            .proximity => 0.75,
            .ambient_light => 0.09,
            .pressure => 1.0,
            .temperature => 0.1,
            .humidity => 0.1,
            else => 1.0, // Default estimate
        };

        // Adjust for sample rate
        const rate_multiplier: f32 = switch (config.sample_rate) {
            .fastest => 2.0,
            .game => 1.5,
            .ui => 1.0,
            .normal => 0.5,
            .custom => 1.0,
        };

        return base_power * rate_multiplier;
    }

    /// Get current power consumption estimate
    pub fn getTotalPowerConsumption(self: *Self) f32 {
        var total: f32 = 0.0;
        for (self.sensors.items) |sensor| {
            if (sensor.is_active) {
                total += sensor.battery_impact;
            }
        }
        return total;
    }

    /// Get sensor statistics
    pub fn getSensorStats(self: *Self, handle_id: u32) ?struct {
        sample_count: u64,
        last_timestamp: i64,
        battery_impact: f32,
        is_active: bool,
    } {
        for (self.sensors.items) |sensor| {
            if (sensor.id == handle_id) {
                return .{
                    .sample_count = sensor.sample_count,
                    .last_timestamp = sensor.last_timestamp,
                    .battery_impact = sensor.battery_impact,
                    .is_active = sensor.is_active,
                };
            }
        }
        return null;
    }
};

/// Global sensor manager instance
var global_sensor_manager: ?SensorManager = null;

/// Initialize global sensor manager
pub fn initGlobalSensorManager(allocator: Allocator) !void {
    if (global_sensor_manager != null) return;

    global_sensor_manager = try SensorManager.init(allocator);
    try global_sensor_manager.?.initialize();
}

/// Get global sensor manager instance
pub fn getSensorManager() ?*SensorManager {
    if (global_sensor_manager) |*manager| {
        return manager;
    }
    return null;
}

/// Cleanup global sensor manager
pub fn deinitGlobalSensorManager() void {
    if (global_sensor_manager) |*manager| {
        manager.deinit();
        global_sensor_manager = null;
    }
}

// Platform interface functions (to be implemented by platform-specific code)
pub extern fn platform_sensor_init() callconv(.C) c_int;
pub extern fn platform_sensor_deinit() callconv(.C) void;
pub extern fn platform_sensor_get_list(sensors: *anyopaque, count: *c_int) callconv(.C) c_int;
pub extern fn platform_sensor_enable(sensor_type: c_int, config: *anyopaque) callconv(.C) c_int;
pub extern fn platform_sensor_disable(handle: c_int) callconv(.C) c_int;
pub extern fn platform_sensor_poll(handle: c_int, data: *anyopaque) callconv(.C) c_int;

// Unit tests
test "sensor manager initialization" {
    var manager = try SensorManager.init(std.testing.allocator);
    defer manager.deinit();

    try manager.initialize();
    try std.testing.expect(manager.is_initialized);
}

test "vector3d operations" {
    const v = Vector3D{ .x = 3.0, .y = 4.0, .z = 0.0 };
    try std.testing.expectApproxEqRel(@as(f32, 5.0), v.magnitude(), 0.001);

    const normalized = v.normalize();
    try std.testing.expectApproxEqRel(@as(f32, 1.0), normalized.magnitude(), 0.001);
}

test "quaternion operations" {
    const q = Quaternion{ .x = 0.0, .y = 0.0, .z = 0.707, .w = 0.707 }; // 90° rotation around Z
    const normalized = q.normalize();

    const magnitude = @sqrt(normalized.x * normalized.x + normalized.y * normalized.y +
        normalized.z * normalized.z + normalized.w * normalized.w);
    try std.testing.expectApproxEqRel(@as(f32, 1.0), magnitude, 0.001);
}

test "power consumption calculation" {
    var manager = try SensorManager.init(std.testing.allocator);
    defer manager.deinit();

    const config = SensorConfig{
        .sensor_type = .accelerometer,
        .sample_rate = .game,
    };

    const power = manager.calculateBatteryImpact(config);
    try std.testing.expect(power > 0.0);
}
