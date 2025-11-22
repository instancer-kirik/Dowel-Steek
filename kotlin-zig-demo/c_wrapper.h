#ifndef C_WRAPPER_H
#define C_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// Version information
#define DOWEL_MINIMAL_VERSION_MAJOR 0
#define DOWEL_MINIMAL_VERSION_MINOR 1
#define DOWEL_MINIMAL_VERSION_PATCH 0

// Error codes
typedef enum {
    DOWEL_SUCCESS = 0,
    DOWEL_INVALID_PARAMETER = -1,
    DOWEL_OUT_OF_MEMORY = -2,
    DOWEL_NOT_INITIALIZED = -3,
    DOWEL_OPERATION_FAILED = -4
} DowelError;

// Core system functions
int dowel_core_init(void);
void dowel_core_shutdown(void);
bool dowel_core_is_initialized(void);
int dowel_get_version(char* buffer, int size);

// Simple math function for testing
int dowel_add_numbers(int a, int b);

// String manipulation functions
int dowel_string_length(const char* str);

// Memory management functions
void* dowel_malloc(size_t size);
void dowel_free(void* ptr);

// Configuration functions
const char* dowel_config_get_string(const char* key, const char* default_value);
int dowel_config_get_int(const char* key, int default_value);
int dowel_config_set_string(const char* key, const char* value);
int dowel_config_set_int(const char* key, int value);

// Logging functions
void dowel_log_info(const char* message);
void dowel_log_error(const char* message);

// Utility functions
long dowel_get_timestamp_ms(void);
void dowel_sleep_ms(int milliseconds);

#ifdef __cplusplus
}
#endif

#endif // C_WRAPPER_H