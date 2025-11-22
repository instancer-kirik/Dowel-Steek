#ifndef DOWEL_DISPLAY_H
#define DOWEL_DISPLAY_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>

// Error codes for display operations
typedef enum {
    DOWEL_DISPLAY_SUCCESS = 0,
    DOWEL_DISPLAY_ERROR_INIT_FAILED = -1,
    DOWEL_DISPLAY_ERROR_WINDOW_CREATION_FAILED = -2,
    DOWEL_DISPLAY_ERROR_RENDERER_CREATION_FAILED = -3,
    DOWEL_DISPLAY_ERROR_TEXTURE_CREATION_FAILED = -4,
    DOWEL_DISPLAY_ERROR_INVALID_DIMENSIONS = -5,
    DOWEL_DISPLAY_ERROR_OUT_OF_MEMORY = -6,
    DOWEL_DISPLAY_ERROR_UNSUPPORTED_FORMAT = -7,
    DOWEL_DISPLAY_ERROR_DEVICE_NOT_AVAILABLE = -8
} DowelDisplayError;

// Pixel format types
typedef enum {
    DOWEL_PIXEL_FORMAT_RGBA8888 = 0,
    DOWEL_PIXEL_FORMAT_RGB888 = 1,
    DOWEL_PIXEL_FORMAT_RGB565 = 2,
    DOWEL_PIXEL_FORMAT_ARGB8888 = 3
} DowelPixelFormat;

// Display configuration structure
typedef struct {
    uint32_t width;
    uint32_t height;
    uint32_t refresh_rate;
    DowelPixelFormat pixel_format;
    bool vsync;
    bool fullscreen;
    bool resizable;
    const char* title;
} DowelDisplayConfig;

// Color structure (RGBA)
typedef struct {
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t a;
} DowelColor;

// Rectangle structure
typedef struct {
    uint32_t x;
    uint32_t y;
    uint32_t width;
    uint32_t height;
} DowelRect;

// Display metrics for performance monitoring
typedef struct {
    uint64_t frame_count;
    float fps;
    float frame_time_ms;
    float render_time_ms;
    uint64_t memory_usage_bytes;
} DowelDisplayMetrics;

// Display information
typedef struct {
    uint32_t width;
    uint32_t height;
    float density;
    float refresh_rate;
    int color_depth;
    bool hdr_supported;
} DowelDisplayInfo;

// Core display management functions

/**
 * Initialize the display system with given configuration
 * @param config Display configuration parameters
 * @return Error code (0 = success, negative = error)
 */
DowelDisplayError dowel_display_init(const DowelDisplayConfig* config);

/**
 * Shutdown the display system and clean up resources
 */
void dowel_display_shutdown(void);

/**
 * Check if the display system is initialized
 * @return true if initialized, false otherwise
 */
bool dowel_display_is_initialized(void);

/**
 * Get current display dimensions
 * @param width Pointer to store width
 * @param height Pointer to store height
 */
void dowel_display_get_dimensions(uint32_t* width, uint32_t* height);

/**
 * Get display information
 * @param info Pointer to display info structure to fill
 */
void dowel_display_get_info(DowelDisplayInfo* info);

// Framebuffer operations

/**
 * Get pointer to framebuffer data
 * @return Pointer to framebuffer pixels (RGBA format)
 */
uint8_t* dowel_display_get_framebuffer(void);

/**
 * Get framebuffer pitch (bytes per row)
 * @return Bytes per row in framebuffer
 */
uint32_t dowel_display_get_pitch(void);

/**
 * Clear the framebuffer with specified color
 * @param color Color to clear with
 */
void dowel_display_clear(DowelColor color);

/**
 * Set a single pixel in the framebuffer
 * @param x X coordinate
 * @param y Y coordinate
 * @param color Pixel color
 */
void dowel_display_set_pixel(uint32_t x, uint32_t y, DowelColor color);

/**
 * Fill a rectangle with specified color
 * @param rect Rectangle to fill
 * @param color Fill color
 */
void dowel_display_fill_rect(const DowelRect* rect, DowelColor color);

/**
 * Draw a line between two points
 * @param x0 Start X coordinate
 * @param y0 Start Y coordinate
 * @param x1 End X coordinate
 * @param y1 End Y coordinate
 * @param color Line color
 */
void dowel_display_draw_line(uint32_t x0, uint32_t y0, uint32_t x1, uint32_t y1, DowelColor color);

/**
 * Copy pixel data to framebuffer
 * @param x Destination X coordinate
 * @param y Destination Y coordinate
 * @param width Width of data
 * @param height Height of data
 * @param data Pixel data (RGBA format)
 * @param pitch Source data pitch (bytes per row)
 */
void dowel_display_blit(uint32_t x, uint32_t y, uint32_t width, uint32_t height, 
                       const uint8_t* data, uint32_t pitch);

// Frame presentation

/**
 * Present the current framebuffer to the screen
 * @return Error code (0 = success, negative = error)
 */
DowelDisplayError dowel_display_present(void);

/**
 * Set the window title (for emulator/debug builds)
 * @param title New window title
 */
void dowel_display_set_title(const char* title);

// Event handling

/**
 * Handle display events (resize, close, etc.)
 * @return true to continue, false if should quit
 */
bool dowel_display_handle_events(void);

/**
 * Check if display should close (user clicked X, pressed ESC, etc.)
 * @return true if should close, false to continue
 */
bool dowel_display_should_close(void);

// Performance monitoring

/**
 * Get current display performance metrics
 * @param metrics Pointer to metrics structure to fill
 */
void dowel_display_get_metrics(DowelDisplayMetrics* metrics);

/**
 * Reset performance counters
 */
void dowel_display_reset_metrics(void);

// Display configuration

/**
 * Set brightness level (0.0 to 1.0)
 * @param brightness Brightness level
 * @return Error code (0 = success, negative = error)
 */
DowelDisplayError dowel_display_set_brightness(float brightness);

/**
 * Get current brightness level
 * @return Brightness level (0.0 to 1.0), -1.0 on error
 */
float dowel_display_get_brightness(void);

/**
 * Set display orientation
 * @param rotation Rotation in degrees (0, 90, 180, 270)
 * @return Error code (0 = success, negative = error)
 */
DowelDisplayError dowel_display_set_rotation(int rotation);

/**
 * Get current display rotation
 * @return Rotation in degrees (0, 90, 180, 270), -1 on error
 */
int dowel_display_get_rotation(void);

/**
 * Enable or disable VSync
 * @param enabled true to enable VSync, false to disable
 * @return Error code (0 = success, negative = error)
 */
DowelDisplayError dowel_display_set_vsync(bool enabled);

// Color utility functions

/**
 * Create color from RGB values
 * @param r Red component (0-255)
 * @param g Green component (0-255)
 * @param b Blue component (0-255)
 * @return DowelColor structure
 */
DowelColor dowel_color_from_rgb(uint8_t r, uint8_t g, uint8_t b);

/**
 * Create color from RGBA values
 * @param r Red component (0-255)
 * @param g Green component (0-255)
 * @param b Blue component (0-255)
 * @param a Alpha component (0-255)
 * @return DowelColor structure
 */
DowelColor dowel_color_from_rgba(uint8_t r, uint8_t g, uint8_t b, uint8_t a);

/**
 * Create color from hex value
 * @param hex Hex color value (0xRRGGBB)
 * @return DowelColor structure
 */
DowelColor dowel_color_from_hex(uint32_t hex);

// Predefined colors
extern const DowelColor DOWEL_COLOR_BLACK;
extern const DowelColor DOWEL_COLOR_WHITE;
extern const DowelColor DOWEL_COLOR_RED;
extern const DowelColor DOWEL_COLOR_GREEN;
extern const DowelColor DOWEL_COLOR_BLUE;
extern const DowelColor DOWEL_COLOR_YELLOW;
extern const DowelColor DOWEL_COLOR_MAGENTA;
extern const DowelColor DOWEL_COLOR_CYAN;
extern const DowelColor DOWEL_COLOR_GRAY;
extern const DowelColor DOWEL_COLOR_TRANSPARENT;

// Rectangle utility functions

/**
 * Check if point is inside rectangle
 * @param rect Rectangle to check
 * @param x X coordinate
 * @param y Y coordinate
 * @return true if point is inside rectangle
 */
bool dowel_rect_contains(const DowelRect* rect, uint32_t x, uint32_t y);

/**
 * Calculate intersection of two rectangles
 * @param rect1 First rectangle
 * @param rect2 Second rectangle
 * @param result Pointer to store intersection result
 * @return true if rectangles intersect, false otherwise
 */
bool dowel_rect_intersect(const DowelRect* rect1, const DowelRect* rect2, DowelRect* result);

// Debug and diagnostics

/**
 * Take a screenshot and save to file
 * @param filename Output filename (PNG format)
 * @return Error code (0 = success, negative = error)
 */
DowelDisplayError dowel_display_screenshot(const char* filename);

/**
 * Enable or disable debug overlay
 * @param enabled true to show debug info, false to hide
 */
void dowel_display_set_debug_overlay(bool enabled);

/**
 * Get display backend information string
 * @return String describing the display backend (e.g., "SDL2", "Framebuffer")
 */
const char* dowel_display_get_backend_info(void);

#ifdef __cplusplus
}
#endif

#endif // DOWEL_DISPLAY_H