#ifndef DOWEL_STEEK_CORE_H
#define DOWEL_STEEK_CORE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// Version information
#define DOWEL_STEEK_VERSION_MAJOR 0
#define DOWEL_STEEK_VERSION_MINOR 1
#define DOWEL_STEEK_VERSION_PATCH 0

// Error codes
#define DOWEL_SUCCESS 0
#define DOWEL_ERROR_INIT_FAILED -1
#define DOWEL_ERROR_NOT_INITIALIZED -2
#define DOWEL_ERROR_INVALID_PARAMETER -3
#define DOWEL_ERROR_OUT_OF_MEMORY -4
#define DOWEL_ERROR_SYSTEM_ERROR -5
#define DOWEL_ERROR_NETWORK_ERROR -6
#define DOWEL_ERROR_STORAGE_ERROR -7
#define DOWEL_ERROR_CONFIG_ERROR -8
#define DOWEL_ERROR_CRYPTO_ERROR -9
#define DOWEL_ERROR_SENSOR_ERROR -10
#define DOWEL_ERROR_POWER_ERROR -11
#define DOWEL_ERROR_NOTIFICATION_ERROR -12
#define DOWEL_ERROR_UNKNOWN -999

// Core system functions
int dowel_core_init(void);
void dowel_core_shutdown(void);
const char* dowel_core_version(void);
bool dowel_core_is_initialized(void);

// Configuration functions
const char* dowel_config_get_string(const char* path, const char* default_value);
int64_t dowel_config_get_int(const char* path, int64_t default_value);
bool dowel_config_get_bool(const char* path, bool default_value);
double dowel_config_get_float(const char* path, double default_value);

int dowel_config_set_string(const char* path, const char* value);
int dowel_config_set_int(const char* path, int64_t value);
int dowel_config_set_bool(const char* path, bool value);
int dowel_config_set_float(const char* path, double value);

// Logging functions
void dowel_log_trace(const char* module, const char* message);
void dowel_log_debug(const char* module, const char* message);
void dowel_log_info(const char* module, const char* message);
void dowel_log_warn(const char* module, const char* message);
void dowel_log_error(const char* module, const char* message);
void dowel_log_fatal(const char* module, const char* message);
void dowel_log_set_level(int level);
void dowel_log_flush(void);

// Storage functions
typedef struct {
    uint8_t* data;
    size_t size;
} dowel_buffer_t;

dowel_buffer_t* dowel_storage_read_file(const char* path);
int dowel_storage_write_file(const char* path, const uint8_t* data, size_t size);
int dowel_storage_delete_file(const char* path);
bool dowel_storage_file_exists(const char* path);
int dowel_storage_create_directory(const char* path);
char** dowel_storage_list_directory(const char* path, size_t* count);
int64_t dowel_storage_get_file_size(const char* path);
int64_t dowel_storage_get_file_modtime(const char* path);

// Memory management for returned data
void dowel_free_buffer(dowel_buffer_t* buffer);
void dowel_free_string(char* string);
void dowel_free_string_array(char** strings, size_t count);

// System information functions
float dowel_system_get_battery_level(void);
const char* dowel_system_get_battery_state(void);
const char* dowel_system_get_device_model(void);
const char* dowel_system_get_os_version(void);
int64_t dowel_system_get_total_memory(void);
int64_t dowel_system_get_available_memory(void);
float dowel_system_get_cpu_usage(void);
const char* dowel_system_get_network_type(void);
bool dowel_system_is_network_available(void);

// Mobile-specific functions
typedef struct {
    float x, y, z;
} dowel_vector3_t;

// Sensor functions
int dowel_sensors_init(void);
void dowel_sensors_shutdown(void);
dowel_vector3_t dowel_sensors_get_accelerometer(void);
dowel_vector3_t dowel_sensors_get_gyroscope(void);
dowel_vector3_t dowel_sensors_get_magnetometer(void);
float dowel_sensors_get_proximity(void);
float dowel_sensors_get_light(void);

// Power management functions
int dowel_power_init(void);
void dowel_power_shutdown(void);
void dowel_power_request_wake_lock(const char* tag);
void dowel_power_release_wake_lock(const char* tag);
void dowel_power_set_brightness(float brightness);
float dowel_power_get_brightness(void);
void dowel_power_enable_power_save_mode(bool enabled);
bool dowel_power_is_power_save_mode_enabled(void);

// Notification functions
typedef struct {
    const char* id;
    const char* title;
    const char* body;
    const char* icon;
    int priority;
    bool persistent;
    int64_t timestamp;
} dowel_notification_t;

int dowel_notifications_init(void);
void dowel_notifications_shutdown(void);
int dowel_notifications_send(const dowel_notification_t* notification);
int dowel_notifications_cancel(const char* id);
void dowel_notifications_cancel_all(void);
bool dowel_notifications_are_enabled(void);

// Networking functions
int dowel_network_init(void);
void dowel_network_shutdown(void);
bool dowel_network_is_connected(void);
const char* dowel_network_get_connection_type(void);
int dowel_network_get_signal_strength(void);

// Crypto functions
typedef struct {
    uint8_t* data;
    size_t size;
} dowel_crypto_key_t;

int dowel_crypto_init(void);
void dowel_crypto_shutdown(void);
dowel_buffer_t* dowel_crypto_hash_sha256(const uint8_t* data, size_t size);
dowel_crypto_key_t* dowel_crypto_generate_key(void);
dowel_buffer_t* dowel_crypto_encrypt(const dowel_crypto_key_t* key, const uint8_t* data, size_t size);
dowel_buffer_t* dowel_crypto_decrypt(const dowel_crypto_key_t* key, const uint8_t* encrypted_data, size_t size);
void dowel_crypto_free_key(dowel_crypto_key_t* key);

// Performance monitoring
typedef struct {
    uint64_t total_entries;
    uint64_t entries_by_level[6];
    uint64_t dropped_entries;
    uint64_t avg_write_time_ns;
    size_t peak_memory_usage;
} dowel_log_metrics_t;

dowel_log_metrics_t dowel_log_get_metrics(void);

// Platform detection
typedef enum {
    DOWEL_PLATFORM_ANDROID = 0,
    DOWEL_PLATFORM_IOS = 1,
    DOWEL_PLATFORM_DESKTOP = 2,
    DOWEL_PLATFORM_UNKNOWN = 3
} dowel_platform_t;

dowel_platform_t dowel_platform_get_current(void);
bool dowel_platform_is_mobile(void);
bool dowel_platform_is_desktop(void);

// Error handling
const char* dowel_error_get_message(int error_code);
void dowel_error_set_callback(void (*callback)(int error_code, const char* message));

// Threading and async support
typedef void (*dowel_callback_t)(void* user_data);
typedef struct dowel_task dowel_task_t;

dowel_task_t* dowel_async_spawn(dowel_callback_t callback, void* user_data);
bool dowel_async_is_complete(const dowel_task_t* task);
void dowel_async_wait(dowel_task_t* task);
void dowel_async_cancel(dowel_task_t* task);
void dowel_async_free_task(dowel_task_t* task);

// File watching
typedef struct dowel_file_watcher dowel_file_watcher_t;
typedef enum {
    DOWEL_FILE_EVENT_CREATED = 1,
    DOWEL_FILE_EVENT_MODIFIED = 2,
    DOWEL_FILE_EVENT_DELETED = 4,
    DOWEL_FILE_EVENT_MOVED = 8
} dowel_file_event_t;

typedef void (*dowel_file_event_callback_t)(const char* path, dowel_file_event_t event, void* user_data);

dowel_file_watcher_t* dowel_file_watcher_create(const char* path, int events, dowel_file_event_callback_t callback, void* user_data);
void dowel_file_watcher_start(dowel_file_watcher_t* watcher);
void dowel_file_watcher_stop(dowel_file_watcher_t* watcher);
void dowel_file_watcher_destroy(dowel_file_watcher_t* watcher);

// JSON utilities (for structured data exchange)
typedef struct dowel_json_value dowel_json_value_t;

dowel_json_value_t* dowel_json_parse(const char* json_string);
const char* dowel_json_stringify(const dowel_json_value_t* value);
void dowel_json_free(dowel_json_value_t* value);

dowel_json_value_t* dowel_json_get_object_value(const dowel_json_value_t* object, const char* key);
const char* dowel_json_get_string(const dowel_json_value_t* value);
int64_t dowel_json_get_int(const dowel_json_value_t* value);
double dowel_json_get_float(const dowel_json_value_t* value);
bool dowel_json_get_bool(const dowel_json_value_t* value);

// Time utilities
int64_t dowel_time_now_timestamp(void);
int64_t dowel_time_now_timestamp_ms(void);
const char* dowel_time_format_iso8601(int64_t timestamp);

// Compression utilities
dowel_buffer_t* dowel_compress_gzip(const uint8_t* data, size_t size);
dowel_buffer_t* dowel_decompress_gzip(const uint8_t* compressed_data, size_t size);

#ifdef __cplusplus
}
#endif

#endif // DOWEL_STEEK_CORE_H