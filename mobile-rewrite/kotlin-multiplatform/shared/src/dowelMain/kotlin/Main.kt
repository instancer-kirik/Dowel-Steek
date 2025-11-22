package main

import com.dowelsteek.test.MinimalZigSystem
import com.dowelsteek.test.runMinimalZigTest
import com.dowelsteek.test.benchmarkZigIntegration
import kotlinx.coroutines.*
import kotlin.system.exitProcess

/**
 * Dowel-Steek Mobile OS - Main Application
 *
 * This is the main entry point for the Dowel-Steek Mobile OS.
 * It demonstrates the integration between Kotlin/Native and Zig core services.
 */

fun main() {
    println("🚀 Starting Dowel-Steek Mobile OS...")
    println("=" * 50)

    // Initialize the Zig system
    val zigSystem = MinimalZigSystem()

    if (!zigSystem.initialize()) {
        println("❌ Failed to initialize Zig core system")
        exitProcess(1)
    }

    println("✅ Dowel-Steek core system initialized successfully")
    println("📱 System version: ${zigSystem.getVersion()}")
    println("⏰ Boot timestamp: ${zigSystem.getCurrentTimestamp()}ms")

    // Run integration tests
    println("\n🧪 Running integration tests...")
    val testResult = runMinimalZigTest()

    if (!testResult) {
        println("❌ Integration tests failed")
        zigSystem.shutdown()
        exitProcess(1)
    }

    // Demo the mobile OS functionality
    println("\n📱 Demonstrating Mobile OS Features...")
    demonstrateMobileOSFeatures(zigSystem)

    // Performance benchmark
    println("\n⚡ Running performance benchmarks...")
    val benchmarkTime = benchmarkZigIntegration(50000)
    println("Benchmark completed in ${benchmarkTime}ms")

    // Simulate OS operations
    println("\n🔄 Simulating OS operations...")
    simulateOSOperations(zigSystem)

    // Graceful shutdown
    println("\n🛑 Shutting down Dowel-Steek Mobile OS...")
    zigSystem.shutdown()
    println("✅ System shutdown completed")
    println("👋 Goodbye from Dowel-Steek Mobile OS!")
}

/**
 * Demonstrate mobile OS features using Zig integration
 */
fun demonstrateMobileOSFeatures(system: MinimalZigSystem) {
    println("  📊 Device Information:")
    println("     - OS Version: ${system.getVersion()}")
    println("     - Boot Time: ${system.getCurrentTimestamp()}ms")

    // Configuration management
    println("  ⚙️  Configuration Management:")
    system.setConfigString("device.name", "Dowel-Steek Phone")
    system.setConfigString("user.theme", "dark")
    system.setConfigString("system.language", "en-US")

    println("     - Device Name: ${system.getConfigString("device.name")}")
    println("     - Theme: ${system.getConfigString("user.theme")}")
    println("     - Language: ${system.getConfigString("system.language")}")

    // Logging demonstration
    println("  📝 System Logging:")
    system.logInfo("Mobile OS features demonstration started")
    system.logInfo("Configuration loaded successfully")
    system.logError("This is a test error message")

    // Math operations (simulating calculations)
    println("  🧮 Core Calculations:")
    val screenWidth = 1080
    val screenHeight = 1920
    val totalPixels = system.addNumbers(screenWidth * screenHeight, 0)
    println("     - Screen resolution: ${screenWidth}x${screenHeight}")
    println("     - Total pixels: ${totalPixels}")

    val batteryPercent = 85
    val batteryMah = 4000
    val currentMah = (batteryPercent * batteryMah) / 100
    val remainingMah = system.addNumbers(currentMah, 0)
    println("     - Battery: ${batteryPercent}% (${remainingMah}mAh remaining)")
}

/**
 * Simulate various OS operations
 */
fun simulateOSOperations(system: MinimalZigSystem) = runBlocking {
    // Simulate app launches
    val apps = listOf("Calculator", "Camera", "Messages", "Settings", "Browser")

    for ((index, app) in apps.withIndex()) {
        println("  📱 Launching $app...")
        system.logInfo("Starting application: $app")

        // Simulate app startup time
        val startTime = system.getCurrentTimestamp()
        system.sleep(50 + (index * 20)) // Variable startup times
        val endTime = system.getCurrentTimestamp()
        val launchTime = system.addNumbers((endTime - startTime).toInt(), 0)

        println("     - $app launched in ${launchTime}ms")
        system.setConfigString("apps.last_launched", app)
    }

    // Simulate system maintenance
    println("  🔧 System Maintenance:")
    system.logInfo("Running system maintenance tasks")

    // Memory management simulation
    val memoryUsed = 2048 // MB
    val memoryTotal = 6144 // MB
    val memoryFree = system.addNumbers(memoryTotal, -memoryUsed)
    println("     - Memory: ${memoryUsed}MB used, ${memoryFree}MB free")

    // Storage simulation
    val storageUsed = 32 // GB
    val storageTotal = 128 // GB
    val storageFree = system.addNumbers(storageTotal, -storageUsed)
    println("     - Storage: ${storageUsed}GB used, ${storageFree}GB free")

    // Network simulation
    println("  🌐 Network Operations:")
    system.logInfo("Network connectivity check")
    val networkLatency = system.addNumbers(25, 10) // Simulate 35ms ping
    println("     - Network latency: ${networkLatency}ms")

    // Power management
    println("  🔋 Power Management:")
    system.setConfigString("power.mode", "balanced")
    val powerMode = system.getConfigString("power.mode")
    println("     - Power mode: $powerMode")
    system.logInfo("Power management configured")

    // Security operations
    println("  🔒 Security Operations:")
    val securityLevel = system.addNumbers(85, 0) // Security score
    println("     - Security level: ${securityLevel}%")
    system.setConfigString("security.last_scan", system.getCurrentTimestamp().toString())
    system.logInfo("Security scan completed")
}

/**
 * Extension function to repeat strings (like Python's * operator)
 */
private operator fun String.times(times: Int): String {
    return repeat(times)
}

/**
 * Enhanced error handling for system operations
 */
fun handleSystemError(operation: String, error: Exception) {
    println("❌ System error during $operation: ${error.message}")
    // In a real OS, this would trigger recovery procedures
}

/**
 * System health check
 */
fun performHealthCheck(system: MinimalZigSystem): Boolean {
    return try {
        system.isInitialized() &&
        system.getCurrentTimestamp() > 0 &&
        system.addNumbers(1, 1) == 2
    } catch (e: Exception) {
        handleSystemError("health check", e)
        false
    }
}
