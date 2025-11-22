//! C API Bridge for Dowel-Steek Mobile Core
//! Provides C-compatible interface for Kotlin Multiplatform integration
//! All functions use C calling conventions and C-compatible types

const std = @import("std");
const config = @import("config.zig");
const logging = @import("logging.zig");
const storage = @import("storage.zig");
const networking = @import("networking.zig");
const crypto = @import("crypto.zig");
const power = @import("mobile/power.zig");
const sensors = @import("mobile/sensors.zig");
const notifications = @import("mobile/notifications.zig");

// Global allocator for C API functions
var global_allocator: std.mem.Allocator = undefined;
var allocator_initialized: bool = false;

/// C-compatible error codes
pub const DowelError = enum(c_int) {
    SUCCESS = 0,
    INVALID_PARAMETER = -1,
    OUT_OF_MEMORY = -2,
    FILE_NOT_FOUND = -3,
    PERMISSION_DENIED = -4,
    NETWORK_ERROR = -5,
    INVALID_FORMAT = -6,
    OPERATION_FAILED = -7,
    NOT_INITIALIZED = -8,
    ALREADY_EXISTS = -9,
    QUOTA_EXCEEDED = -10,
    TIMEOUT = -11,
    UNSUPPORTED = -12,
    INVALID_STATE = -13,
    HARDWARE_ERROR = -14,
    SERVICE_UNAVAILABLE = -15,
};

/// C-compatible log levels
pub const CLogLevel = enum(c_int) {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5,
};

/// C-compatible sensor types
pub const CSensorType = enum(c_int) {
    ACCELEROMETER = 0,
    GYROSCOPE = 1,
    MAGNETOMETER = 2,
    PROXIMITY = 3,
    AMBIENT_LIGHT = 4,
    PRESSURE = 5,
    TEMPERATURE = 6,
    HUMIDITY = 7,
    GRAVITY = 8,
    LINEAR_ACCELERATION = 9,
    ROTATION_VECTOR = 10,
    ORIENTATION = 11,
    STEP_COUNTER = 12,
    STEP_DETECTOR = 13,
    HEART_RATE = 14,
};

/// C-compatible notification priority
pub const CNotificationPriority = enum(c_int) {
    MIN = 0,
    LOW = 1,
    DEFAULT = 2,
    HIGH = 3,
    MAX = 4,
};

/// C structures for data exchange
pub const CVector3D = extern struct {
    x: f32,
    y: f32,
    z: f32,
};

pub const CSensorData = extern struct {
    sensor_type: c_int,
    vector_data: CVector3D,
    scalar_value: f32,
    timestamp: i64,
    accuracy: c_int,
};

pub const CNotificationData = extern struct {
    id: [*:0]const u8,
    app_id: [*:0]const u8,
    channel_id: [*:0]const u8,
    title: [*:0]const u8,
    body: [*:0]const u8,
    priority: c_int,
    timestamp: i64,
    auto_cancel: c_int, // bool as int
    ongoing: c_int, // bool as int
};

pub const CBatteryInfo = extern struct {
    level: f32, // 0.0 to 1.0
    is_charging: c_int, // bool as int
    temperature: f32, // Celsius
    voltage: f32, // Volts
    health: c_int, // Battery health status
    technology: [16]u8, // Battery technology string
};

pub const CSystemInfo = extern struct {
    os_version: [32]u8,
    device_model: [64]u8,
    architecture: [16]u8,
    total_memory: u64,
    available_memory: u64,
    cpu_cores: c_int,
    screen_width: c_int,
    screen_height: c_int,
    screen_density: f32,
};

// Error handling utility
fn toError(err: anyerror) DowelError {
    return switch (err) {
        error.OutOfMemory => .OUT_OF_MEMORY,
        error.FileNotFound => .FILE_NOT_FOUND,
        error.PermissionDenied => .PERMISSION_DENIED,
        error.NetworkError => .NETWORK_ERROR,
        error.InvalidFormat => .INVALID_FORMAT,
        error.Timeout => .TIMEOUT,
        else => .OPERATION_FAILED,
    };
}

// String helper functions
fn cStringToSlice(c_str: [*:0]const u8) []const u8 {
    return std.mem.span(c_str);
}

fn sliceToCString(allocator: std.mem.Allocator, slice: []const u8) ![*:0]u8 {
    const c_str = try allocator.dupeZ(u8, slice);
    return c_str.ptr;
}

//
// Core System API
//

/// Initialize the Dowel-Steek core system
export fn dowel_core_init() callconv(.C) DowelError {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    global_allocator = gpa.allocator();
    allocator_initialized = true;

    // Initialize all subsystems
    config.initGlobalConfig(global_allocator) catch |err| return toError(err);
    logging.initGlobalLogger(global_allocator) catch |err| return toError(err);
    storage.initGlobalStorageManager(global_allocator) catch |err| return toError(err);
    power.initGlobalPowerManager(global_allocator) catch |err| return toError(err);
    sensors.initGlobalSensorManager(global_allocator) catch |err| return toError(err);
    notifications.initGlobalNotificationManager(global_allocator) catch |err| return toError(err);

    return .SUCCESS;
}

/// Shutdown the core system
export fn dowel_core_shutdown() callconv(.C) void {
    if (!allocator_initialized) return;

    // Cleanup all subsystems
    notifications.deinitGlobalNotificationManager();
    sensors.deinitGlobalSensorManager();
    power.deinitGlobalPowerManager();
    storage.deinitGlobalStorageManager();
    logging.deinitGlobalLogger();
    config.deinitGlobalConfig();

    allocator_initialized = false;
}

/// Get system information
export fn dowel_core_get_system_info(info: *CSystemInfo) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    // Get system information (platform-specific implementation needed)
    @memcpy(info.os_version[0..], "Dowel-Steek 1.0\x00");
    @memcpy(info.device_model[0..], "Unknown Device\x00");
    @memcpy(info.architecture[0..], "aarch64\x00");

    info.total_memory = 0; // To be filled by platform layer
    info.available_memory = 0;
    info.cpu_cores = 0;
    info.screen_width = 0;
    info.screen_height = 0;
    info.screen_density = 0.0;

    return .SUCCESS;
}

//
// Configuration API
//

/// Get configuration value as string
export fn dowel_config_get_string(key: [*:0]const u8, value_buffer: [*]u8, buffer_size: c_int) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const config_manager = config.getGlobalConfig() orelse return .NOT_INITIALIZED;
    const key_slice = cStringToSlice(key);

    const value = config_manager.getString(key_slice) catch |err| return toError(err);
    if (value) |v| {
        if (v.len >= buffer_size) return .INVALID_PARAMETER;
        @memcpy(value_buffer[0..v.len], v);
        value_buffer[v.len] = 0; // Null terminate
        return .SUCCESS;
    }

    return .FILE_NOT_FOUND;
}

/// Set configuration value as string
export fn dowel_config_set_string(key: [*:0]const u8, value: [*:0]const u8) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const config_manager = config.getGlobalConfig() orelse return .NOT_INITIALIZED;
    const key_slice = cStringToSlice(key);
    const value_slice = cStringToSlice(value);

    config_manager.setString(key_slice, value_slice) catch |err| return toError(err);
    return .SUCCESS;
}

/// Get configuration value as integer
export fn dowel_config_get_int(key: [*:0]const u8, default_value: i64) callconv(.C) i64 {
    if (!allocator_initialized) return default_value;

    const config_manager = config.getGlobalConfig() orelse return default_value;
    const key_slice = cStringToSlice(key);

    return config_manager.getInt(key_slice) catch default_value orelse default_value;
}

/// Set configuration value as integer
export fn dowel_config_set_int(key: [*:0]const u8, value: i64) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const config_manager = config.getGlobalConfig() orelse return .NOT_INITIALIZED;
    const key_slice = cStringToSlice(key);

    config_manager.setInt(key_slice, value) catch |err| return toError(err);
    return .SUCCESS;
}

/// Get configuration value as boolean
export fn dowel_config_get_bool(key: [*:0]const u8, default_value: c_int) callconv(.C) c_int {
    if (!allocator_initialized) return default_value;

    const config_manager = config.getGlobalConfig() orelse return default_value;
    const key_slice = cStringToSlice(key);

    const value = config_manager.getBool(key_slice) catch return default_value;
    return if (value orelse (default_value != 0)) 1 else 0;
}

/// Set configuration value as boolean
export fn dowel_config_set_bool(key: [*:0]const u8, value: c_int) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const config_manager = config.getGlobalConfig() orelse return .NOT_INITIALIZED;
    const key_slice = cStringToSlice(key);

    config_manager.setBool(key_slice, value != 0) catch |err| return toError(err);
    return .SUCCESS;
}

//
// Logging API
//

/// Log a message with specified level
export fn dowel_log_message(level: CLogLevel, tag: [*:0]const u8, message: [*:0]const u8) callconv(.C) void {
    if (!allocator_initialized) return;

    const logger = logging.getGlobalLogger() orelse return;
    const tag_slice = cStringToSlice(tag);
    const message_slice = cStringToSlice(message);

    const log_level: logging.LogLevel = switch (level) {
        .TRACE => .trace,
        .DEBUG => .debug,
        .INFO => .info,
        .WARN => .warn,
        .ERROR => .err,
        .FATAL => .fatal,
    };

    logger.log(log_level, tag_slice, "{s}", .{message_slice});
}

/// Set minimum log level
export fn dowel_log_set_level(level: CLogLevel) callconv(.C) void {
    if (!allocator_initialized) return;

    const logger = logging.getGlobalLogger() orelse return;

    const log_level: logging.LogLevel = switch (level) {
        .TRACE => .trace,
        .DEBUG => .debug,
        .INFO => .info,
        .WARN => .warn,
        .ERROR => .err,
        .FATAL => .fatal,
    };

    logger.setMinLevel(log_level);
}

//
// Storage API
//

/// Check if file exists
export fn dowel_storage_file_exists(path: [*:0]const u8) callconv(.C) c_int {
    if (!allocator_initialized) return 0;

    const storage_manager = storage.getGlobalStorageManager() orelse return 0;
    const path_slice = cStringToSlice(path);

    return if (storage_manager.fileExists(path_slice)) 1 else 0;
}

/// Read file content
export fn dowel_storage_read_file(path: [*:0]const u8, buffer: [*]u8, buffer_size: c_int, bytes_read: *c_int) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const storage_manager = storage.getGlobalStorageManager() orelse return .NOT_INITIALIZED;
    const path_slice = cStringToSlice(path);

    const content = storage_manager.readFileAlloc(path_slice) catch |err| return toError(err);
    defer global_allocator.free(content);

    if (content.len >= buffer_size) return .INVALID_PARAMETER;
    @memcpy(buffer[0..content.len], content);
    bytes_read.* = @intCast(content.len);

    return .SUCCESS;
}

/// Write file content
export fn dowel_storage_write_file(path: [*:0]const u8, data: [*]const u8, data_size: c_int) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const storage_manager = storage.getGlobalStorageManager() orelse return .NOT_INITIALIZED;
    const path_slice = cStringToSlice(path);
    const data_slice = data[0..@intCast(data_size)];

    storage_manager.writeFile(path_slice, data_slice) catch |err| return toError(err);
    return .SUCCESS;
}

/// Delete file
export fn dowel_storage_delete_file(path: [*:0]const u8) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const storage_manager = storage.getGlobalStorageManager() orelse return .NOT_INITIALIZED;
    const path_slice = cStringToSlice(path);

    storage_manager.deleteFile(path_slice) catch |err| return toError(err);
    return .SUCCESS;
}

/// Create directory
export fn dowel_storage_create_directory(path: [*:0]const u8) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const storage_manager = storage.getGlobalStorageManager() orelse return .NOT_INITIALIZED;
    const path_slice = cStringToSlice(path);

    storage_manager.createDirectory(path_slice) catch |err| return toError(err);
    return .SUCCESS;
}

/// Get file size
export fn dowel_storage_get_file_size(path: [*:0]const u8) callconv(.C) i64 {
    if (!allocator_initialized) return -1;

    const storage_manager = storage.getGlobalStorageManager() orelse return -1;
    const path_slice = cStringToSlice(path);

    return storage_manager.getFileSize(path_slice) catch -1;
}

//
// Power Management API
//

/// Get battery information
export fn dowel_power_get_battery_info(info: *CBatteryInfo) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const power_manager = power.getGlobalPowerManager() orelse return .NOT_INITIALIZED;
    const battery_info = power_manager.getBatteryInfo();

    info.level = battery_info.level;
    info.is_charging = if (battery_info.is_charging) 1 else 0;
    info.temperature = battery_info.temperature;
    info.voltage = battery_info.voltage;
    info.health = @intFromEnum(battery_info.health);
    @memcpy(info.technology[0..battery_info.technology.len], battery_info.technology);
    info.technology[battery_info.technology.len] = 0;

    return .SUCCESS;
}

/// Set power save mode
export fn dowel_power_set_power_save_mode(enabled: c_int) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const power_manager = power.getGlobalPowerManager() orelse return .NOT_INITIALIZED;
    power_manager.setPowerSaveMode(enabled != 0);

    return .SUCCESS;
}

/// Acquire wake lock
export fn dowel_power_acquire_wake_lock(tag: [*:0]const u8, timeout_ms: i64) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const power_manager = power.getGlobalPowerManager() orelse return .NOT_INITIALIZED;
    const tag_slice = cStringToSlice(tag);

    power_manager.acquireWakeLock(tag_slice, if (timeout_ms > 0) @intCast(timeout_ms) else null) catch |err| return toError(err);
    return .SUCCESS;
}

/// Release wake lock
export fn dowel_power_release_wake_lock(tag: [*:0]const u8) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const power_manager = power.getGlobalPowerManager() orelse return .NOT_INITIALIZED;
    const tag_slice = cStringToSlice(tag);

    power_manager.releaseWakeLock(tag_slice) catch |err| return toError(err);
    return .SUCCESS;
}

//
// Sensor API
//

/// Check if sensor is available
export fn dowel_sensor_is_available(sensor_type: CSensorType) callconv(.C) c_int {
    if (!allocator_initialized) return 0;

    const sensor_manager = sensors.getSensorManager() orelse return 0;
    const zig_sensor_type: sensors.SensorType = switch (sensor_type) {
        .ACCELEROMETER => .accelerometer,
        .GYROSCOPE => .gyroscope,
        .MAGNETOMETER => .magnetometer,
        .PROXIMITY => .proximity,
        .AMBIENT_LIGHT => .ambient_light,
        .PRESSURE => .pressure,
        .TEMPERATURE => .temperature,
        .HUMIDITY => .humidity,
        .GRAVITY => .gravity,
        .LINEAR_ACCELERATION => .linear_acceleration,
        .ROTATION_VECTOR => .rotation_vector,
        .ORIENTATION => .orientation,
        .STEP_COUNTER => .step_counter,
        .STEP_DETECTOR => .step_detector,
        .HEART_RATE => .heart_rate,
    };

    return if (sensor_manager.isSensorAvailable(zig_sensor_type)) 1 else 0;
}

/// Enable sensor
export fn dowel_sensor_enable(sensor_type: CSensorType, sample_rate_us: u32) callconv(.C) c_int {
    if (!allocator_initialized) return -1;

    const sensor_manager = sensors.getSensorManager() orelse return -1;
    const zig_sensor_type: sensors.SensorType = switch (sensor_type) {
        .ACCELEROMETER => .accelerometer,
        .GYROSCOPE => .gyroscope,
        .MAGNETOMETER => .magnetometer,
        .PROXIMITY => .proximity,
        .AMBIENT_LIGHT => .ambient_light,
        .PRESSURE => .pressure,
        .TEMPERATURE => .temperature,
        .HUMIDITY => .humidity,
        .GRAVITY => .gravity,
        .LINEAR_ACCELERATION => .linear_acceleration,
        .ROTATION_VECTOR => .rotation_vector,
        .ORIENTATION => .orientation,
        .STEP_COUNTER => .step_counter,
        .STEP_DETECTOR => .step_detector,
        .HEART_RATE => .heart_rate,
    };

    const config_struct = sensors.SensorConfig{
        .sensor_type = zig_sensor_type,
        .sample_rate = .custom,
        .custom_delay_us = sample_rate_us,
    };

    const handle = sensor_manager.enableSensor(config_struct, null, null) catch return -1;
    return @intCast(handle);
}

/// Disable sensor
export fn dowel_sensor_disable(handle: c_int) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const sensor_manager = sensors.getSensorManager() orelse return .NOT_INITIALIZED;
    sensor_manager.disableSensor(@intCast(handle)) catch |err| return toError(err);

    return .SUCCESS;
}

/// Poll sensor data
export fn dowel_sensor_poll_data(data: *CSensorData) callconv(.C) c_int {
    if (!allocator_initialized) return 0;

    const sensor_manager = sensors.getSensorManager() orelse return 0;
    const sensor_data = sensor_manager.pollSensorData() catch return 0;

    if (sensor_data) |d| {
        data.sensor_type = switch (d) {
            .accelerometer => @intFromEnum(CSensorType.ACCELEROMETER),
            .gyroscope => @intFromEnum(CSensorType.GYROSCOPE),
            .magnetometer => @intFromEnum(CSensorType.MAGNETOMETER),
            .proximity => @intFromEnum(CSensorType.PROXIMITY),
            .ambient_light => @intFromEnum(CSensorType.AMBIENT_LIGHT),
            .pressure => @intFromEnum(CSensorType.PRESSURE),
            .temperature => @intFromEnum(CSensorType.TEMPERATURE),
            .humidity => @intFromEnum(CSensorType.HUMIDITY),
            .gravity => @intFromEnum(CSensorType.GRAVITY),
            .linear_acceleration => @intFromEnum(CSensorType.LINEAR_ACCELERATION),
            .rotation_vector => @intFromEnum(CSensorType.ROTATION_VECTOR),
            .orientation => @intFromEnum(CSensorType.ORIENTATION),
            .step_counter => @intFromEnum(CSensorType.STEP_COUNTER),
            .step_detector => @intFromEnum(CSensorType.STEP_DETECTOR),
            .heart_rate => @intFromEnum(CSensorType.HEART_RATE),
        };

        switch (d) {
            .accelerometer => |accel| {
                data.vector_data = CVector3D{ .x = accel.acceleration.x, .y = accel.acceleration.y, .z = accel.acceleration.z };
                data.timestamp = accel.timestamp;
                data.accuracy = @intFromEnum(accel.accuracy);
            },
            .gyroscope => |gyro| {
                data.vector_data = CVector3D{ .x = gyro.angular_velocity.x, .y = gyro.angular_velocity.y, .z = gyro.angular_velocity.z };
                data.timestamp = gyro.timestamp;
                data.accuracy = @intFromEnum(gyro.accuracy);
            },
            .proximity => |prox| {
                data.scalar_value = prox.distance;
                data.timestamp = prox.timestamp;
                data.accuracy = @intFromEnum(prox.accuracy);
            },
            .ambient_light => |light| {
                data.scalar_value = light.illuminance;
                data.timestamp = light.timestamp;
                data.accuracy = @intFromEnum(light.accuracy);
            },
            .temperature => |temp| {
                data.scalar_value = temp.temperature;
                data.timestamp = temp.timestamp;
                data.accuracy = @intFromEnum(temp.accuracy);
            },
            else => {}, // Handle other sensor types as needed
        }

        return 1;
    }

    return 0;
}

//
// Notification API
//

/// Show a notification
export fn dowel_notification_show(notification: *const CNotificationData) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const notification_manager = notifications.getNotificationManager() orelse return .NOT_INITIALIZED;

    var zig_notification = notifications.Notification.init(
        global_allocator,
        cStringToSlice(notification.id),
        cStringToSlice(notification.app_id),
        cStringToSlice(notification.channel_id),
        cStringToSlice(notification.title),
    ) catch |err| return toError(err);
    defer zig_notification.deinit(global_allocator);

    if (std.mem.len(notification.body) > 0) {
        zig_notification.body = global_allocator.dupe(u8, cStringToSlice(notification.body)) catch |err| return toError(err);
    }

    zig_notification.priority = switch (@as(CNotificationPriority, @enumFromInt(notification.priority))) {
        .MIN => .min,
        .LOW => .low,
        .DEFAULT => .default,
        .HIGH => .high,
        .MAX => .max,
    };

    zig_notification.auto_cancel = notification.auto_cancel != 0;
    zig_notification.ongoing = notification.ongoing != 0;
    zig_notification.timestamp = notification.timestamp;

    notification_manager.showNotification(zig_notification) catch |err| return toError(err);
    return .SUCCESS;
}

/// Cancel a notification
export fn dowel_notification_cancel(notification_id: [*:0]const u8) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const notification_manager = notifications.getNotificationManager() orelse return .NOT_INITIALIZED;
    const id_slice = cStringToSlice(notification_id);

    notification_manager.cancelNotification(id_slice) catch |err| return toError(err);
    return .SUCCESS;
}

/// Create notification channel
export fn dowel_notification_create_channel(channel_id: [*:0]const u8, channel_name: [*:0]const u8, importance: CNotificationPriority) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const notification_manager = notifications.getNotificationManager() orelse return .NOT_INITIALIZED;

    const channel = notifications.NotificationChannel{
        .id = global_allocator.dupe(u8, cStringToSlice(channel_id)) catch |err| return toError(err),
        .name = global_allocator.dupe(u8, cStringToSlice(channel_name)) catch |err| return toError(err),
        .importance = switch (importance) {
            .MIN => .min,
            .LOW => .low,
            .DEFAULT => .default,
            .HIGH => .high,
            .MAX => .max,
        },
    };

    notification_manager.createNotificationChannel(channel) catch |err| return toError(err);
    return .SUCCESS;
}

//
// Networking API
//

/// Perform HTTP GET request
export fn dowel_network_get(url: [*:0]const u8, response_buffer: [*]u8, buffer_size: c_int, response_size: *c_int) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const url_slice = cStringToSlice(url);

    const response = networking.httpGet(global_allocator, url_slice, null) catch |err| return toError(err);
    defer global_allocator.free(response);

    if (response.len >= buffer_size) return .INVALID_PARAMETER;
    @memcpy(response_buffer[0..response.len], response);
    response_size.* = @intCast(response.len);

    return .SUCCESS;
}

/// Perform HTTP POST request
export fn dowel_network_post(url: [*:0]const u8, data: [*]const u8, data_size: c_int, response_buffer: [*]u8, buffer_size: c_int, response_size: *c_int) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const url_slice = cStringToSlice(url);
    const data_slice = data[0..@intCast(data_size)];

    const response = networking.httpPost(global_allocator, url_slice, data_slice, null) catch |err| return toError(err);
    defer global_allocator.free(response);

    if (response.len >= buffer_size) return .INVALID_PARAMETER;
    @memcpy(response_buffer[0..response.len], response);
    response_size.* = @intCast(response.len);

    return .SUCCESS;
}

//
// Cryptography API
//

/// Generate random bytes
export fn dowel_crypto_random_bytes(buffer: [*]u8, size: c_int) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const buffer_slice = buffer[0..@intCast(size)];
    crypto.randomBytes(buffer_slice) catch |err| return toError(err);

    return .SUCCESS;
}

/// Hash data with SHA-256
export fn dowel_crypto_hash_sha256(data: [*]const u8, data_size: c_int, hash_buffer: [*]u8) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const data_slice = data[0..@intCast(data_size)];
    const hash_slice = hash_buffer[0..32]; // SHA-256 is 32 bytes

    crypto.hashSHA256(data_slice, hash_slice) catch |err| return toError(err);

    return .SUCCESS;
}

/// Encrypt data with AES-GCM
export fn dowel_crypto_encrypt_aes_gcm(data: [*]const u8, data_size: c_int, key: [*]const u8, key_size: c_int, encrypted_buffer: [*]u8, buffer_size: c_int, encrypted_size: *c_int) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const data_slice = data[0..@intCast(data_size)];
    const key_slice = key[0..@intCast(key_size)];
    const buffer_slice = encrypted_buffer[0..@intCast(buffer_size)];

    const encrypted = crypto.encryptAESGCM(global_allocator, data_slice, key_slice) catch |err| return toError(err);
    defer global_allocator.free(encrypted);

    if (encrypted.len > buffer_slice.len) return .INVALID_PARAMETER;
    @memcpy(buffer_slice[0..encrypted.len], encrypted);
    encrypted_size.* = @intCast(encrypted.len);

    return .SUCCESS;
}

/// Decrypt data with AES-GCM
export fn dowel_crypto_decrypt_aes_gcm(encrypted_data: [*]const u8, encrypted_size: c_int, key: [*]const u8, key_size: c_int, decrypted_buffer: [*]u8, buffer_size: c_int, decrypted_size: *c_int) callconv(.C) DowelError {
    if (!allocator_initialized) return .NOT_INITIALIZED;

    const encrypted_slice = encrypted_data[0..@intCast(encrypted_size)];
    const key_slice = key[0..@intCast(key_size)];
    const buffer_slice = decrypted_buffer[0..@intCast(buffer_size)];

    const decrypted = crypto.decryptAESGCM(global_allocator, encrypted_slice, key_slice) catch |err| return toError(err);
    defer global_allocator.free(decrypted);

    if (decrypted.len > buffer_slice.len) return .INVALID_PARAMETER;
    @memcpy(buffer_slice[0..decrypted.len], decrypted);
    decrypted_size.* = @intCast(decrypted.len);

    return .SUCCESS;
}

//
// Utility Functions
//

/// Get current timestamp in milliseconds
export fn dowel_util_get_timestamp_ms() callconv(.C) i64 {
    return std.time.milliTimestamp();
}

/// Sleep for specified milliseconds
export fn dowel_util_sleep_ms(milliseconds: c_int) callconv(.C) void {
    const nanoseconds: u64 = @intCast(milliseconds * 1_000_000);
    std.time.sleep(nanoseconds);
}

/// Get memory usage statistics
export fn dowel_util_get_memory_usage() callconv(.C) u64 {
    // This would need platform-specific implementation
    return 0; // Placeholder
}

/// Force garbage collection (if applicable)
export fn dowel_util_force_gc() callconv(.C) void {
    // Zig doesn't have garbage collection, but we can provide
    // a hook for higher-level languages that do
}

//
// Error Handling Utilities
//

/// Get last error message
export fn dowel_get_last_error_message(buffer: [*]u8, buffer_size: c_int) callconv(.C) c_int {
    // This would store the last error message in a thread-local buffer
    // For now, return empty string
    if (buffer_size > 0) {
        buffer[0] = 0;
    }
    return 0;
}

/// Clear last error
export fn dowel_clear_last_error() callconv(.C) void {
    // Clear the thread-local error buffer
}

//
// Memory Management for External Callers
//

/// Allocate memory (for use by calling code)
export fn dowel_malloc(size: c_int) callconv(.C) ?*anyopaque {
    if (!allocator_initialized or size <= 0) return null;

    const bytes = global_allocator.alloc(u8, @intCast(size)) catch return null;
    return bytes.ptr;
}

/// Free memory allocated by dowel_malloc
export fn dowel_free(ptr: ?*anyopaque) callconv(.C) void {
    if (!allocator_initialized or ptr == null) return;

    // Note: This is unsafe without knowing the allocation size
    // In practice, you'd want to track allocations
    // For now, this is a placeholder
    _ = ptr;
}

//
// Version and Build Information
//

/// Get library version string
export fn dowel_get_version(buffer: [*]u8, buffer_size: c_int) callconv(.C) c_int {
    const version = "1.0.0-alpha";
    if (buffer_size <= version.len) return -1;

    @memcpy(buffer[0..version.len], version);
    buffer[version.len] = 0;
    return @intCast(version.len);
}

/// Get build information
export fn dowel_get_build_info(buffer: [*]u8, buffer_size: c_int) callconv(.C) c_int {
    const build_info = "Dowel-Steek Mobile Core - Zig " ++ @import("builtin").zig_version_string;
    if (buffer_size <= build_info.len) return -1;

    @memcpy(buffer[0..build_info.len], build_info);
    buffer[build_info.len] = 0;
    return @intCast(build_info.len);
}
