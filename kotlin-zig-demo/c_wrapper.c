#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <unistd.h>
#include <sys/time.h>

// Simple C implementations that mimic the Zig functions
// This avoids the stack probing issues when linking with Kotlin/Native

static bool system_initialized = false;
static const char* version_string = "0.1.0";

// Core system functions
int dowel_core_init(void) {
    printf("[C_WRAPPER] Initializing Dowel-Steek core system...\n");
    system_initialized = true;
    return 0; // DOWEL_SUCCESS
}

void dowel_core_shutdown(void) {
    printf("[C_WRAPPER] Shutting down Dowel-Steek core system...\n");
    system_initialized = false;
}

bool dowel_core_is_initialized(void) {
    return system_initialized;
}

int dowel_get_version(char* buffer, int size) {
    if (!buffer || size <= 0) return -1;
    
    int len = strlen(version_string);
    if (len >= size) len = size - 1;
    
    strncpy(buffer, version_string, len);
    buffer[len] = '\0';
    return 0; // DOWEL_SUCCESS
}

// Math functions
int dowel_add_numbers(int a, int b) {
    return a + b;
}

// String functions
int dowel_string_length(const char* str) {
    if (!str) return 0;
    return strlen(str);
}

// Logging functions
void dowel_log_info(const char* message) {
    if (message) {
        printf("[INFO] %s\n", message);
        fflush(stdout);
    }
}

void dowel_log_error(const char* message) {
    if (message) {
        fprintf(stderr, "[ERROR] %s\n", message);
        fflush(stderr);
    }
}

// Utility functions
long dowel_get_timestamp_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (tv.tv_sec * 1000LL) + (tv.tv_usec / 1000LL);
}

void dowel_sleep_ms(int milliseconds) {
    if (milliseconds > 0) {
        usleep(milliseconds * 1000);
    }
}

// Memory management functions
void* dowel_malloc(size_t size) {
    return malloc(size);
}

void dowel_free(void* ptr) {
    free(ptr);
}

// Configuration functions (simple implementation)
static char config_buffer[1024] = {0};

int dowel_config_set_string(const char* key, const char* value) {
    if (!key || !value) return -1;
    // Simple implementation - just store one value
    snprintf(config_buffer, sizeof(config_buffer), "%s", value);
    return 0;
}

const char* dowel_config_get_string(const char* key, const char* default_value) {
    if (!key) return default_value;
    // Simple implementation - return stored value or default
    if (strlen(config_buffer) > 0) {
        return config_buffer;
    }
    return default_value;
}

int dowel_config_get_int(const char* key, int default_value) {
    return default_value; // Simple implementation
}

int dowel_config_set_int(const char* key, int value) {
    return 0; // Simple implementation
}