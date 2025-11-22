@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*

/**
 * External function declarations for Zig minimal API
 * These map directly to the C functions exported from our Zig library
 */

// Core system functions
@SymbolName("dowel_core_init")
external fun dowel_core_init(): Int

@SymbolName("dowel_core_shutdown")
external fun dowel_core_shutdown()

@SymbolName("dowel_core_is_initialized")
external fun dowel_core_is_initialized(): Boolean

@SymbolName("dowel_get_version")
external fun dowel_get_version(buffer: CPointer<ByteVar>, size: Int): Int

@SymbolName("dowel_add_numbers")
external fun dowel_add_numbers(a: Int, b: Int): Int

@SymbolName("dowel_string_length")
external fun dowel_string_length(str: CPointer<ByteVar>): Int

@SymbolName("dowel_log_info")
external fun dowel_log_info(message: CPointer<ByteVar>)

@SymbolName("dowel_log_error")
external fun dowel_log_error(message: CPointer<ByteVar>)

@SymbolName("dowel_get_timestamp_ms")
external fun dowel_get_timestamp_ms(): Long

@SymbolName("dowel_sleep_ms")
external fun dowel_sleep_ms(milliseconds: Int)

@SymbolName("dowel_config_set_string")
external fun dowel_config_set_string(key: CPointer<ByteVar>, value: CPointer<ByteVar>): Int

@SymbolName("dowel_config_get_string")
external fun dowel_config_get_string(key: CPointer<ByteVar>, defaultValue: CPointer<ByteVar>): CPointer<ByteVar>?

/**
 * Kotlin wrapper class for easier usage
 */
class ZigSystem {
    companion object {
        const val DOWEL_SUCCESS = 0
        const val DOWEL_ERROR = -1
    }

    fun initialize(): Boolean {
        val result = dowel_core_init()
        return result == DOWEL_SUCCESS
    }

    fun shutdown() {
        dowel_core_shutdown()
    }

    fun isInitialized(): Boolean {
        return dowel_core_is_initialized()
    }

    fun getVersion(): String {
        return memScoped {
            val buffer = allocArray<ByteVar>(64)
            val result = dowel_get_version(buffer, 64)
            if (result == DOWEL_SUCCESS) {
                buffer.toKString()
            } else {
                "Unknown"
            }
        }
    }

    fun addNumbers(a: Int, b: Int): Int {
        return dowel_add_numbers(a, b)
    }

    fun logInfo(message: String) {
        memScoped {
            val cString = message.cstr.ptr
            dowel_log_info(cString)
        }
    }

    fun logError(message: String) {
        memScoped {
            val cString = message.cstr.ptr
            dowel_log_error(cString)
        }
    }

    fun getCurrentTimestamp(): Long {
        return dowel_get_timestamp_ms()
    }

    fun sleep(milliseconds: Int) {
        dowel_sleep_ms(milliseconds)
    }
}

/**
 * Main demo application
 */
fun main() {
    println("🚀 Kotlin-Zig Integration Demo")
    println("================================")

    val system = ZigSystem()

    // Initialize the Zig system
    println("\n1. Initializing Zig system...")
    if (!system.initialize()) {
        println("❌ Failed to initialize Zig system")
        return
    }
    println("✅ Zig system initialized successfully")

    // Get system info
    println("\n2. System Information:")
    println("   Version: ${system.getVersion()}")
    println("   Initialized: ${system.isInitialized()}")
    println("   Timestamp: ${system.getCurrentTimestamp()}ms")

    // Test math operations
    println("\n3. Math Operations:")
    val a = 42
    val b = 24
    val result = system.addNumbers(a, b)
    println("   $a + $b = $result")

    // Test logging
    println("\n4. Logging Test:")
    system.logInfo("Hello from Kotlin!")
    system.logError("This is a test error message")

    // Performance test
    println("\n5. Performance Test:")
    val startTime = system.getCurrentTimestamp()
    var total = 0
    for (i in 1..1000) {
        total += system.addNumbers(i, i * 2)
    }
    val endTime = system.getCurrentTimestamp()
    val duration = endTime - startTime

    println("   Performed 1,000 Zig calls in ${duration}ms")
    println("   Total sum: $total")

    // Sleep test
    println("\n6. Sleep Test:")
    println("   Sleeping for 100ms...")
    system.sleep(100)
    println("   Sleep completed!")

    // Shutdown
    println("\n7. Shutting down...")
    system.shutdown()
    println("   System initialized: ${system.isInitialized()}")

    println("\n🎉 Demo completed successfully!")
    println("✅ Kotlin-Zig integration is working perfectly!")
}
