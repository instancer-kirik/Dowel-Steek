package com.dowelsteek.examples

import com.dowelsteek.core.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

/**
 * Basic Usage Example for Dowel-Steek Mobile System
 *
 * This example demonstrates how to use the core mobile system components
 * including initialization, configuration, logging, storage, and power management.
 */
class BasicUsageExample {

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    /**
     * Initialize and demonstrate the mobile system
     */
    suspend fun runExample() {
        println("🚀 Starting Dowel-Steek Mobile System Example")

        // 1. Initialize the core system
        initializeSystem()

        // 2. Demonstrate configuration management
        demonstrateConfiguration()

        // 3. Show logging capabilities
        demonstrateLogging()

        // 4. File storage operations
        demonstrateStorage()

        // 5. Power management features
        demonstratePowerManagement()

        // 6. System information
        demonstrateSystemInfo()

        // 7. Clean shutdown
        shutdownSystem()

        println("✅ Example completed successfully!")
    }

    private suspend fun initializeSystem() {
        println("\n📱 Initializing Core System...")

        val coreSystem = CoreSystem.getInstance()

        coreSystem.initialize().fold(
            onSuccess = {
                println("✅ Core system initialized successfully")
                println("📋 Version: ${coreSystem.getVersion()}")
                println("🔧 Initialized: ${coreSystem.isInitialized()}")
            },
            onFailure = { error ->
                println("❌ Failed to initialize core system: ${error.message}")
                throw error
            }
        )
    }

    private suspend fun demonstrateConfiguration() {
        println("\n⚙️  Configuration Management Demo...")

        val coreSystem = CoreSystem.getInstance()
        val config = coreSystem.getConfig()

        // Read some default configuration values
        val theme = config.getString("general.theme", "system")
        val touchFeedback = config.getBool("ui.touch_feedback", true)
        val fontSize = config.getInt("ui.font_size", 16)

        println("🎨 Current theme: $theme")
        println("📱 Touch feedback enabled: $touchFeedback")
        println("📝 Font size: $fontSize")

        // Update configuration values
        config.setString("user.name", "Dowel User").fold(
            onSuccess = { println("✅ User name set successfully") },
            onFailure = { error -> println("❌ Failed to set user name: ${error.message}") }
        )

        config.setBool("ui.dark_mode", true).fold(
            onSuccess = { println("✅ Dark mode enabled") },
            onFailure = { error -> println("❌ Failed to enable dark mode: ${error.message}") }
        )

        // Read back the values
        val userName = config.getString("user.name", "Unknown")
        val darkMode = config.getBool("ui.dark_mode", false)

        println("👤 User name: $userName")
        println("🌙 Dark mode: $darkMode")
    }

    private fun demonstrateLogging() {
        println("\n📝 Logging System Demo...")

        val coreSystem = CoreSystem.getInstance()
        val logger = coreSystem.getLogger()

        // Log messages at different levels
        logger.trace("This is a trace message", "example")
        logger.debug("Debug information: System initialized", "example")
        logger.info("Application started successfully", "example")
        logger.warn("This is a warning message", "example")
        logger.error("Example error message", "example")

        // Log with error context
        try {
            throw RuntimeException("Example exception")
        } catch (e: Exception) {
            logger.error("Caught exception during demo", "example", e)
        }

        // Flush logs to ensure they're written
        logger.flush()

        println("✅ Logged messages at various levels")
    }

    private suspend fun demonstrateStorage() {
        println("\n💾 Storage System Demo...")

        val coreSystem = CoreSystem.getInstance()
        val storage = coreSystem.getStorage()

        // Write a test file
        val testData = "Hello from Dowel-Steek Mobile!\nTimestamp: ${System.currentTimeMillis()}"
        val testPath = "examples/test_file.txt"

        storage.writeFile(testPath, testData.toByteArray()).fold(
            onSuccess = {
                println("✅ Test file written successfully")

                // Read it back
                storage.readFile(testPath).fold(
                    onSuccess = { data ->
                        val content = String(data)
                        println("📖 File content: $content")

                        // Check if file exists
                        val exists = storage.fileExists(testPath)
                        println("📁 File exists: $exists")
                    },
                    onFailure = { error ->
                        println("❌ Failed to read file: ${error.message}")
                    }
                )
            },
            onFailure = { error ->
                println("❌ Failed to write file: ${error.message}")
            }
        )

        // Demonstrate directory operations
        val testDir = "examples/test_directory"
        storage.createDirectory(testDir).fold(
            onSuccess = {
                println("✅ Test directory created")

                // List directory contents
                storage.listDirectory("examples").fold(
                    onSuccess = { files ->
                        println("📂 Directory contents:")
                        files.forEach { fileName ->
                            println("   📄 $fileName")
                        }
                    },
                    onFailure = { error ->
                        println("❌ Failed to list directory: ${error.message}")
                    }
                )
            },
            onFailure = { error ->
                println("❌ Failed to create directory: ${error.message}")
            }
        )
    }

    private suspend fun demonstratePowerManagement() {
        println("\n🔋 Power Management Demo...")

        val coreSystem = CoreSystem.getInstance()
        val systemInfo = coreSystem.getSystemInfo()

        // Get system information including battery
        systemInfo.getSystemInfo().fold(
            onSuccess = { info ->
                println("🔋 Battery Level: ${(info.batteryLevel * 100).toInt()}%")
                println("🔌 Battery State: ${info.batteryState}")
                println("📱 Device Model: ${info.deviceModel}")
                println("🏠 OS Version: ${info.osVersion}")
                println("💾 Total Memory: ${info.totalMemory / (1024 * 1024)} MB")
                println("💾 Available Memory: ${info.availableMemory / (1024 * 1024)} MB")
                println("🌐 Network Type: ${info.networkType}")
                println("📶 Network Available: ${info.networkAvailable}")
            },
            onFailure = { error ->
                println("❌ Failed to get system info: ${error.message}")
            }
        )

        // Check battery level specifically
        val batteryLevel = systemInfo.getBatteryLevel()
        val networkAvailable = systemInfo.isNetworkAvailable()

        println("🔋 Current battery level: ${(batteryLevel * 100).toInt()}%")
        println("📶 Network available: $networkAvailable")

        // Battery level warnings
        when {
            batteryLevel < 0.05f -> println("🚨 Critical battery level!")
            batteryLevel < 0.15f -> println("⚠️  Low battery warning")
            batteryLevel < 0.30f -> println("💡 Consider enabling power save mode")
            else -> println("✅ Battery level is good")
        }
    }

    private suspend fun demonstrateSystemInfo() {
        println("\n📊 System Information Demo...")

        val coreSystem = CoreSystem.getInstance()
        val systemInfo = coreSystem.getSystemInfo()

        // Get comprehensive system information
        systemInfo.getSystemInfo().fold(
            onSuccess = { info ->
                println("📱 Device Information:")
                println("   Model: ${info.deviceModel}")
                println("   OS Version: ${info.osVersion}")
                println("   CPU Usage: ${info.cpuUsage}%")

                println("🔋 Power Information:")
                println("   Battery Level: ${(info.batteryLevel * 100).toInt()}%")
                println("   Battery State: ${info.batteryState}")

                println("💾 Memory Information:")
                val totalMB = info.totalMemory / (1024 * 1024)
                val availableMB = info.availableMemory / (1024 * 1024)
                val usedMB = totalMB - availableMB
                val usagePercent = (usedMB.toFloat() / totalMB * 100).toInt()

                println("   Total: ${totalMB} MB")
                println("   Available: ${availableMB} MB")
                println("   Used: ${usedMB} MB (${usagePercent}%)")

                println("🌐 Network Information:")
                println("   Type: ${info.networkType}")
                println("   Available: ${info.networkAvailable}")

                // Provide recommendations based on system state
                provideSystemRecommendations(info)
            },
            onFailure = { error ->
                println("❌ Failed to get detailed system info: ${error.message}")
            }
        )
    }

    private fun provideSystemRecommendations(info: SystemInfo) {
        println("\n💡 System Recommendations:")

        val recommendations = mutableListOf<String>()

        // Battery recommendations
        if (info.batteryLevel < 0.2f) {
            recommendations.add("🔋 Enable power save mode to extend battery life")
            recommendations.add("📱 Reduce screen brightness")
            recommendations.add("📶 Disable unnecessary network features")
        }

        // Memory recommendations
        val memoryUsagePercent = ((info.totalMemory - info.availableMemory).toFloat() / info.totalMemory * 100)
        if (memoryUsagePercent > 85) {
            recommendations.add("💾 High memory usage detected - consider closing unused apps")
        }

        // Network recommendations
        if (!info.networkAvailable) {
            recommendations.add("📶 No network connection - enable offline mode")
        } else if (info.networkType == "cellular") {
            recommendations.add("📱 Using cellular data - monitor usage for cost savings")
        }

        // CPU recommendations
        if (info.cpuUsage > 80) {
            recommendations.add("⚡ High CPU usage - check for background tasks")
        }

        if (recommendations.isEmpty()) {
            println("   ✅ System is running optimally!")
        } else {
            recommendations.forEach { recommendation ->
                println("   $recommendation")
            }
        }
    }

    private fun shutdownSystem() {
        println("\n🔄 Shutting down system...")

        val coreSystem = CoreSystem.getInstance()
        coreSystem.shutdown()

        println("✅ System shutdown complete")
    }

    /**
     * Demonstrates advanced features like monitoring system changes
     */
    fun startSystemMonitoring() {
        println("\n👁️  Starting system monitoring...")

        // Monitor system changes using coroutines
        scope.launch {
            // Simulate periodic system monitoring
            while (true) {
                delay(30000) // Check every 30 seconds

                val coreSystem = CoreSystem.getInstance()
                if (!coreSystem.isInitialized()) break

                val systemInfo = coreSystem.getSystemInfo()
                val batteryLevel = systemInfo.getBatteryLevel()
                val networkAvailable = systemInfo.isNetworkAvailable()

                println("📊 System Check: Battery ${(batteryLevel * 100).toInt()}%, Network: $networkAvailable")

                // Alert on critical battery
                if (batteryLevel < 0.05f) {
                    println("🚨 CRITICAL: Battery extremely low!")
                }
            }
        }
    }

    fun stopSystemMonitoring() {
        println("🛑 Stopping system monitoring...")
        scope.cancel()
    }
}

/**
 * Entry point for the example
 */
suspend fun main() {
    val example = BasicUsageExample()

    try {
        // Run the basic example
        example.runExample()

        // Start monitoring (in a real app, this would run in the background)
        example.startSystemMonitoring()

        // Keep the example running for a bit to show monitoring
        delay(5000)

        // Stop monitoring
        example.stopSystemMonitoring()

    } catch (e: Exception) {
        println("❌ Example failed with error: ${e.message}")
        e.printStackTrace()
    }
}

/**
 * Extension functions for better usability
 */

/**
 * Format battery level as percentage string
 */
fun Float.toBatteryPercent(): String = "${(this * 100).toInt()}%"

/**
 * Format bytes as human-readable size
 */
fun Long.toHumanReadableSize(): String {
    val units = arrayOf("B", "KB", "MB", "GB", "TB")
    var size = this.toDouble()
    var unitIndex = 0

    while (size >= 1024 && unitIndex < units.size - 1) {
        size /= 1024
        unitIndex++
    }

    return "%.1f %s".format(size, units[unitIndex])
}

/**
 * Check if system is in a critical state
 */
fun SystemInfo.isCriticalState(): Boolean {
    return batteryLevel < 0.05f || !networkAvailable || availableMemory < (totalMemory * 0.05)
}

/**
 * Get system health score (0-100)
 */
fun SystemInfo.getHealthScore(): Int {
    var score = 100

    // Battery impact
    score -= when {
        batteryLevel < 0.05f -> 30
        batteryLevel < 0.15f -> 20
        batteryLevel < 0.30f -> 10
        else -> 0
    }

    // Memory impact
    val memoryUsage = (totalMemory - availableMemory).toFloat() / totalMemory
    score -= when {
        memoryUsage > 0.95f -> 25
        memoryUsage > 0.85f -> 15
        memoryUsage > 0.75f -> 5
        else -> 0
    }

    // CPU impact
    score -= when {
        cpuUsage > 90f -> 20
        cpuUsage > 75f -> 10
        cpuUsage > 50f -> 5
        else -> 0
    }

    // Network impact
    if (!networkAvailable) score -= 15

    return maxOf(0, score)
}
