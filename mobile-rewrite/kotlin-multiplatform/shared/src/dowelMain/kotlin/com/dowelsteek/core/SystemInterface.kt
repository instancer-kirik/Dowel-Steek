package com.dowelsteek.core

import kotlinx.coroutines.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * System Interface for Dowel-Steek Mobile OS
 *
 * Provides Kotlin interfaces to the underlying Zig-based system services.
 * This is the primary bridge between Kotlin applications and the OS kernel/services.
 */
class SystemInterface private constructor() {
    companion object {
        @Volatile
        private var INSTANCE: SystemInterface? = null

        fun getInstance(): SystemInterface {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: SystemInterface().also { INSTANCE = it }
            }
        }

        // C function declarations for Zig system services
        @SymbolName("dowel_core_init")
        external fun nativeInit(): Int

        @SymbolName("dowel_core_shutdown")
        external fun nativeShutdown()

        @SymbolName("dowel_core_is_initialized")
        external fun nativeIsInitialized(): Boolean

        @SymbolName("dowel_get_version")
        external fun nativeGetVersion(buffer: ByteArray, size: Int): Int
    }

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    @Volatile
    private var initialized = false

    /**
     * Initialize the core system
     */
    suspend fun initialize(): Result<Unit> = withContext(Dispatchers.Default) {
        if (initialized) {
            return@withContext Result.success(Unit)
        }

        try {
            val result = nativeInit()
            if (result == 0) {
                initialized = true
                Result.success(Unit)
            } else {
                Result.failure(SystemException("Failed to initialize core system: error code $result"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Shutdown the core system
     */
    fun shutdown() {
        if (initialized) {
            try {
                nativeShutdown()
                scope.cancel()
                initialized = false
            } catch (e: Exception) {
                // Log error but continue shutdown
            }
        }
    }

    /**
     * Check if the system is initialized
     */
    fun isInitialized(): Boolean = initialized && nativeIsInitialized()

    /**
     * Get system version information
     */
    fun getVersion(): String {
        return try {
            val buffer = ByteArray(64)
            val result = nativeGetVersion(buffer, buffer.size)
            if (result > 0) {
                String(buffer, 0, result, Charsets.UTF_8)
            } else {
                "unknown"
            }
        } catch (e: Exception) {
            "unknown"
        }
    }

    // System service interfaces
    fun getConfig(): ConfigManager = ConfigManager()
    fun getLogger(): Logger = Logger()
    fun getStorage(): StorageManager = StorageManager()
    fun getDisplay(): DisplayManager = DisplayManager()
    fun getInput(): InputManager = InputManager()
    fun getAudio(): AudioManager = AudioManager()
    fun getNetwork(): NetworkManager = NetworkManager()
    fun getSecurity(): SecurityManager = SecurityManager()
    fun getPower(): PowerManager = PowerManager()
    fun getSensors(): SensorManager = SensorManager()
    fun getNotifications(): NotificationManager = NotificationManager()
}

/**
 * Configuration Manager
 * Interface to the Zig configuration system
 */
class ConfigManager {
    @SymbolName("dowel_config_get_string")
    external fun nativeGetString(key: String, buffer: ByteArray, size: Int): Int

    @SymbolName("dowel_config_set_string")
    external fun nativeSetString(key: String, value: String): Int

    @SymbolName("dowel_config_get_int")
    external fun nativeGetInt(key: String, defaultValue: Long): Long

    @SymbolName("dowel_config_set_int")
    external fun nativeSetInt(key: String, value: Long): Int

    @SymbolName("dowel_config_get_bool")
    external fun nativeGetBool(key: String, defaultValue: Boolean): Boolean

    @SymbolName("dowel_config_set_bool")
    external fun nativeSetBool(key: String, value: Boolean): Int

    fun getString(key: String, defaultValue: String = ""): String {
        return try {
            val buffer = ByteArray(1024)
            val result = nativeGetString(key, buffer, buffer.size)
            if (result == 0) {
                String(buffer).trimEnd('\u0000')
            } else {
                defaultValue
            }
        } catch (e: Exception) {
            defaultValue
        }
    }

    fun getInt(key: String, defaultValue: Long = 0L): Long {
        return try {
            nativeGetInt(key, defaultValue)
        } catch (e: Exception) {
            defaultValue
        }
    }

    fun getBool(key: String, defaultValue: Boolean = false): Boolean {
        return try {
            nativeGetBool(key, defaultValue)
        } catch (e: Exception) {
            defaultValue
        }
    }

    suspend fun setString(key: String, value: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val result = nativeSetString(key, value)
            if (result == 0) {
                Result.success(Unit)
            } else {
                Result.failure(SystemException("Failed to set config string: error $result"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun setInt(key: String, value: Long): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val result = nativeSetInt(key, value)
            if (result == 0) {
                Result.success(Unit)
            } else {
                Result.failure(SystemException("Failed to set config int: error $result"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun setBool(key: String, value: Boolean): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val result = nativeSetBool(key, value)
            if (result == 0) {
                Result.success(Unit)
            } else {
                Result.failure(SystemException("Failed to set config bool: error $result"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

/**
 * Logger
 * Interface to the Zig logging system
 */
class Logger {
    @SymbolName("dowel_log_message")
    external fun nativeLogMessage(level: Int, tag: String, message: String)

    @SymbolName("dowel_log_set_level")
    external fun nativeSetLogLevel(level: Int)

    fun trace(message: String, tag: String = "app") = nativeLogMessage(0, tag, message)
    fun debug(message: String, tag: String = "app") = nativeLogMessage(1, tag, message)
    fun info(message: String, tag: String = "app") = nativeLogMessage(2, tag, message)
    fun warn(message: String, tag: String = "app") = nativeLogMessage(3, tag, message)
    fun error(message: String, tag: String = "app") = nativeLogMessage(4, tag, message)
    fun fatal(message: String, tag: String = "app") = nativeLogMessage(5, tag, message)

    fun setLevel(level: LogLevel) = nativeSetLogLevel(level.ordinal)

    enum class LogLevel { TRACE, DEBUG, INFO, WARN, ERROR, FATAL }
}

/**
 * Storage Manager
 * Interface to the file system and storage services
 */
class StorageManager {
    @SymbolName("dowel_storage_file_exists")
    external fun nativeFileExists(path: String): Boolean

    @SymbolName("dowel_storage_read_file")
    external fun nativeReadFile(path: String, buffer: ByteArray, size: Int, bytesRead: IntArray): Int

    @SymbolName("dowel_storage_write_file")
    external fun nativeWriteFile(path: String, data: ByteArray, size: Int): Int

    @SymbolName("dowel_storage_delete_file")
    external fun nativeDeleteFile(path: String): Int

    @SymbolName("dowel_storage_create_directory")
    external fun nativeCreateDirectory(path: String): Int

    @SymbolName("dowel_storage_get_file_size")
    external fun nativeGetFileSize(path: String): Long

    fun fileExists(path: String): Boolean = nativeFileExists(path)

    suspend fun readFile(path: String): Result<ByteArray> = withContext(Dispatchers.IO) {
        try {
            val size = nativeGetFileSize(path)
            if (size <= 0) {
                return@withContext Result.failure(StorageException("File not found or empty: $path"))
            }

            val buffer = ByteArray(size.toInt())
            val bytesRead = IntArray(1)
            val result = nativeReadFile(path, buffer, buffer.size, bytesRead)

            if (result == 0 && bytesRead[0] > 0) {
                Result.success(buffer.copyOf(bytesRead[0]))
            } else {
                Result.failure(StorageException("Failed to read file: $path"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun writeFile(path: String, data: ByteArray): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val result = nativeWriteFile(path, data, data.size)
            if (result == 0) {
                Result.success(Unit)
            } else {
                Result.failure(StorageException("Failed to write file: error $result"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun deleteFile(path: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val result = nativeDeleteFile(path)
            if (result == 0) {
                Result.success(Unit)
            } else {
                Result.failure(StorageException("Failed to delete file: error $result"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun createDirectory(path: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val result = nativeCreateDirectory(path)
            if (result == 0) {
                Result.success(Unit)
            } else {
                Result.failure(StorageException("Failed to create directory: error $result"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

/**
 * Display Manager
 * Interface to display and graphics services
 */
class DisplayManager {
    @SymbolName("dowel_display_init")
    external fun nativeInit(config: ByteArray): Int

    @SymbolName("dowel_display_shutdown")
    external fun nativeShutdown()

    @SymbolName("dowel_display_is_initialized")
    external fun nativeIsInitialized(): Boolean

    @SymbolName("dowel_display_get_dimensions")
    external fun nativeGetDimensions(width: IntArray, height: IntArray)

    @SymbolName("dowel_display_get_info")
    external fun nativeGetDisplayInfo(): DisplayInfo

    @SymbolName("dowel_display_set_brightness")
    external fun nativeSetBrightness(brightness: Float): Int

    @SymbolName("dowel_display_get_brightness")
    external fun nativeGetBrightness(): Float

    @SymbolName("dowel_display_get_framebuffer")
    external fun nativeGetFramebuffer(): ByteArray?

    @SymbolName("dowel_display_present")
    external fun nativePresent(): Int

    @SymbolName("dowel_display_clear")
    external fun nativeClear(r: Int, g: Int, b: Int, a: Int)

    @SymbolName("dowel_display_set_pixel")
    external fun nativeSetPixel(x: Int, y: Int, r: Int, g: Int, b: Int, a: Int)

    @SymbolName("dowel_display_fill_rect")
    external fun nativeFillRect(x: Int, y: Int, width: Int, height: Int, r: Int, g: Int, b: Int, a: Int)

    @SymbolName("dowel_display_handle_events")
    external fun nativeHandleEvents(): Boolean

    @SymbolName("dowel_display_should_close")
    external fun nativeShouldClose(): Boolean

    @SymbolName("dowel_display_get_metrics")
    external fun nativeGetMetrics(): DisplayMetrics

    suspend fun initialize(config: DisplayConfig): Result<Unit> = withContext(Dispatchers.Default) {
        try {
            val configBytes = encodeDisplayConfig(config)
            val result = nativeInit(configBytes)
            if (result == 0) {
                Result.success(Unit)
            } else {
                Result.failure(SystemException("Failed to initialize display: error $result"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun shutdown() = nativeShutdown()
    fun isInitialized() = nativeIsInitialized()

    fun getDimensions(): Pair<Int, Int> {
        val width = IntArray(1)
        val height = IntArray(1)
        nativeGetDimensions(width, height)
        return Pair(width[0], height[0])
    }

    fun getDisplayInfo(): DisplayInfo = nativeGetDisplayInfo()
    fun setBrightness(brightness: Float) = nativeSetBrightness(brightness) == 0
    fun getBrightness(): Float = nativeGetBrightness()

    fun getFramebuffer(): ByteArray? = nativeGetFramebuffer()

    suspend fun present(): Result<Unit> = withContext(Dispatchers.Default) {
        try {
            val result = nativePresent()
            if (result == 0) {
                Result.success(Unit)
            } else {
                Result.failure(SystemException("Failed to present frame: error $result"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun clear(color: Color) = nativeClear(color.red, color.green, color.blue, color.alpha)
    fun setPixel(x: Int, y: Int, color: Color) = nativeSetPixel(x, y, color.red, color.green, color.blue, color.alpha)
    fun fillRect(x: Int, y: Int, width: Int, height: Int, color: Color) =
        nativeFillRect(x, y, width, height, color.red, color.green, color.blue, color.alpha)

    fun handleEvents(): Boolean = nativeHandleEvents()
    fun shouldClose(): Boolean = nativeShouldClose()
    fun getMetrics(): DisplayMetrics = nativeGetMetrics()

    private fun encodeDisplayConfig(config: DisplayConfig): ByteArray {
        // Simplified encoding - in real implementation would use proper serialization
        return "${config.width},${config.height},${config.refreshRate},${config.vsync}".toByteArray()
    }
}

/**
 * Input Manager
 * Interface to touch, keyboard, and other input devices
 */
class InputManager {
    // Touch and input handling will be implemented here
    // Integration with gesture recognition and haptic feedback
}

/**
 * Audio Manager
 * Interface to audio input/output and processing
 */
class AudioManager {
    // Audio routing, volume control, spatial audio
    // Low-latency audio for games and media
}

/**
 * Network Manager
 * Interface to networking services
 */
class NetworkManager {
    // WiFi, cellular, Bluetooth connectivity
    // VPN and traffic management
}

/**
 * Security Manager
 * Interface to security and cryptographic services
 */
class SecurityManager {
    // App sandboxing, permissions, biometrics
    // Hardware security module integration
}

/**
 * Power Manager
 * Interface to power management and battery services
 */
class PowerManager {
    @SymbolName("dowel_power_get_battery_info")
    external fun nativeGetBatteryInfo(): BatteryInfo

    @SymbolName("dowel_power_set_power_save_mode")
    external fun nativeSetPowerSaveMode(enabled: Boolean): Int

    fun getBatteryInfo(): BatteryInfo = nativeGetBatteryInfo()
    fun setPowerSaveMode(enabled: Boolean) = nativeSetPowerSaveMode(enabled) == 0
}

/**
 * Sensor Manager
 * Interface to device sensors
 */
class SensorManager {
    // Accelerometer, gyroscope, compass, proximity
    // Environmental sensors and biometric sensors
}

/**
 * Notification Manager
 * Interface to system notifications
 */
class NotificationManager {
    // System-wide notification delivery and management
    // Priority filtering and cross-app communication
}

/**
 * Data classes for system information
 */
@Serializable
data class DisplayInfo(
    val width: Int,
    val height: Int,
    val density: Float,
    val refreshRate: Float,
    val colorDepth: Int,
    val hdrSupported: Boolean
)

@Serializable
data class DisplayConfig(
    val width: Int = 1080,
    val height: Int = 2340,
    val refreshRate: Int = 60,
    val vsync: Boolean = true,
    val fullscreen: Boolean = false,
    val title: String = "Dowel-Steek Mobile OS"
)

@Serializable
data class DisplayMetrics(
    val frameCount: Long,
    val fps: Float,
    val frameTimeMs: Float,
    val renderTimeMs: Float,
    val memoryUsageBytes: Long
)

@Serializable
data class Color(
    val red: Int,
    val green: Int,
    val blue: Int,
    val alpha: Int = 255
) {
    companion object {
        val BLACK = Color(0, 0, 0)
        val WHITE = Color(255, 255, 255)
        val RED = Color(255, 0, 0)
        val GREEN = Color(0, 255, 0)
        val BLUE = Color(0, 0, 255)
        val TRANSPARENT = Color(0, 0, 0, 0)

        fun fromHex(hex: Int): Color {
            return Color(
                red = (hex shr 16) and 0xFF,
                green = (hex shr 8) and 0xFF,
                blue = hex and 0xFF
            )
        }
    }
}

@Serializable
data class BatteryInfo(
    val level: Float,
    val isCharging: Boolean,
    val temperature: Float,
    val voltage: Float,
    val health: String,
    val technology: String
)

/**
 * System exceptions
 */
class SystemException(message: String, cause: Throwable? = null) : Exception(message, cause)
class StorageException(message: String, cause: Throwable? = null) : Exception(message, cause)
