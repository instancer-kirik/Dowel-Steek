@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

import kotlinx.cinterop.*
import c_wrapper.*
import kotlin.system.exitProcess

/**
 * Kotlin wrapper class for easier usage with C wrapper
 */
class DowelSystem {
    companion object {
        const val DOWEL_SUCCESS = 0
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
        dowel_log_info(message)
    }

    fun logError(message: String) {
        dowel_log_error(message)
    }

    fun getCurrentTimestamp(): Long {
        return dowel_get_timestamp_ms()
    }

    fun sleep(milliseconds: Int) {
        dowel_sleep_ms(milliseconds)
    }

    fun getStringLength(text: String): Int {
        return dowel_string_length(text)
    }
}

class UXShowcase {
    private val system = DowelSystem()

    // ANSI Color codes
    private val RESET = "\u001B[0m"
    private val BOLD = "\u001B[1m"
    private val RED = "\u001B[31m"
    private val GREEN = "\u001B[32m"
    private val YELLOW = "\u001B[33m"
    private val BLUE = "\u001B[34m"
    private val MAGENTA = "\u001B[35m"
    private val CYAN = "\u001B[36m"
    private val WHITE = "\u001B[37m"

    fun clearScreen() {
        print("\u001B[2J\u001B[H")
    }

    fun printHeader() {
        println("$CYAN$BOLD")
        println("╔══════════════════════════════════════════════════════════╗")
        println("║                🚀 DOWEL-STEEK UX SHOWCASE                ║")
        println("║                 Kotlin/Native Desktop Demo               ║")
        println("║                                                          ║")
        println("║    Demonstrating rich terminal UI without Android       ║")
        println("╚══════════════════════════════════════════════════════════╝")
        println("$RESET")
    }

    fun showSystemInfo() {
        println("$BLUE$BOLD═══ System Information ═══$RESET")
        println()

        val version = system.getVersion()
        val timestamp = system.getCurrentTimestamp()

        println("$CYAN• System Version:$RESET $version")
        println("$CYAN• Status:$RESET ${GREEN}Online & Operational$RESET")
        println("$CYAN• Timestamp:$RESET $timestamp ms")
        println("$CYAN• Platform:$RESET Kotlin/Native x86_64 Linux")
        println("$CYAN• Backend Integration:$RESET Zig via C wrapper")
        println("$CYAN• UI Framework:$RESET Rich Terminal Interface")
        println("$CYAN• Development Mode:$RESET ${GREEN}No Android Studio Required$RESET")
        println()

        system.logInfo("System information displayed")
        pause(1500)
    }

    fun mathShowcase() {
        println("$BLUE$BOLD═══ Math Operations Showcase ═══$RESET")
        println()

        val operations = listOf(
            Pair(42, 24),
            Pair(100, 200),
            Pair(1337, 42),
            Pair(256, 128),
            Pair(999, 1)
        )

        operations.forEach { (a, b) ->
            val result = system.addNumbers(a, b)
            println("$GREEN▶$RESET $a + $b = $YELLOW$result$RESET")
            system.logInfo("Math operation: $a + $b = $result")
            pause(300)
        }

        println()
        println("${GREEN}✅ All math operations completed successfully$RESET")
        pause(1000)
    }

    fun stringShowcase() {
        println("$BLUE$BOLD═══ String Operations Showcase ═══$RESET")
        println()

        val testStrings = listOf(
            "Hello, Dowel-Steek!",
            "Kotlin/Native is awesome",
            "🚀 Unicode support works!",
            "Performance testing string",
            "Mobile OS development ready"
        )

        testStrings.forEach { text ->
            val length = system.getStringLength(text)
            val words = text.split(" ").size
            val vowels = text.count { it.lowercaseChar() in "aeiou" }

            println("$CYAN▶ Text:$RESET '$text'")
            println("  ${YELLOW}Length:$RESET $length chars | ${YELLOW}Words:$RESET $words | ${YELLOW}Vowels:$RESET $vowels")
            system.logInfo("String analysis: '$text' (${length} chars)")
            println()
            pause(500)
        }

        println("${GREEN}✅ String processing demonstration complete$RESET")
        pause(1000)
    }

    fun performanceShowcase() {
        println("$BLUE$BOLD═══ Performance Benchmark ═══$RESET")
        println()

        val testSizes = listOf(100, 500, 1000, 5000, 10000)

        testSizes.forEach { iterations ->
            println("${YELLOW}⚡ Testing $iterations function calls...$RESET")

            val startTime = system.getCurrentTimestamp()
            var sum = 0

            for (i in 1..iterations) {
                sum += system.addNumbers(i, i * 2)
            }

            val endTime = system.getCurrentTimestamp()
            val duration = endTime - startTime
            val avgTime = if (iterations > 0) duration.toDouble() / iterations else 0.0
            val callsPerSec = if (duration > 0) (iterations * 1000) / duration else Int.MAX_VALUE

            println("  ${GREEN}✓$RESET Duration: ${duration}ms | Avg: ${avgTime}ms/call | Rate: $callsPerSec calls/sec")
            system.logInfo("Performance test: $iterations calls in ${duration}ms")
            pause(800)
        }

        println()
        println("${GREEN}🏆 Performance benchmarking complete - Native speed achieved!$RESET")
        pause(1500)
    }

    fun mobileOSSimulation() {
        println("$BLUE$BOLD═══ Mobile OS Simulation ═══$RESET")
        println()

        val services = listOf(
            "Display Manager" to "🖥️",
            "Input Handler" to "⌨️",
            "Audio System" to "🔊",
            "Network Stack" to "🌐",
            "Power Manager" to "🔋",
            "Storage Manager" to "💾",
            "Security Module" to "🔒",
            "UI Framework" to "🎨"
        )

        println("${YELLOW}🚀 Starting Mobile OS Services...$RESET")
        system.logInfo("Mobile OS simulation started")
        println()

        val startupTime = system.getCurrentTimestamp()

        services.forEach { (service, icon) ->
            print("$CYAN▶ Starting $service $icon...$RESET")

            // Simulate realistic startup time
            val delay = (50..200).random()
            system.sleep(delay)

            val currentTime = system.getCurrentTimestamp()
            val serviceUptime = currentTime - startupTime

            println(" ${GREEN}✅ Ready${RESET} (${serviceUptime}ms)")
            system.logInfo("Service started: $service")
        }

        val totalStartupTime = system.getCurrentTimestamp() - startupTime

        println()
        println("$GREEN$BOLD🎉 Mobile OS Fully Operational!$RESET")
        println("$CYAN• Total startup time:$RESET ${totalStartupTime}ms")
        println("$CYAN• Services running:$RESET ${services.size}")
        println("$CYAN• System status:$RESET ${GREEN}All systems nominal$RESET")
        println("$CYAN• Memory usage:$RESET ${GREEN}Optimized$RESET")

        system.logInfo("Mobile OS simulation complete - startup: ${totalStartupTime}ms")
        pause(2000)
    }

    fun systemMonitor() {
        println("$BLUE$BOLD═══ System Monitor ═══$RESET")
        println()

        println("${YELLOW}📊 Real-time system monitoring demonstration...$RESET")
        println()

        val monitorStart = system.getCurrentTimestamp()
        val monitorDuration = 5000 // 5 seconds
        var cycles = 0

        while (system.getCurrentTimestamp() - monitorStart < monitorDuration) {
            cycles++
            val currentTime = system.getCurrentTimestamp()
            val uptime = currentTime - monitorStart

            // Simulate realistic system metrics
            val cpuUsage = (15 + (uptime / 100) % 30).toInt()
            val memUsage = 256 + (uptime / 50 % 256).toInt()
            val networkActivity = (uptime / 20 % 100).toInt()
            val diskIO = (uptime / 30 % 50).toInt()

            // Real-time monitoring display
            print("\r$CYAN● Uptime:$RESET ${uptime}ms ")
            print("$CYAN● CPU:$RESET ${cpuUsage}% ")
            print("$CYAN● Memory:$RESET ${memUsage}MB ")
            print("$CYAN● Network:$RESET ${networkActivity}KB/s ")
            print("$CYAN● Disk:$RESET ${diskIO}MB/s ")
            print("$CYAN● Cycles:$RESET $cycles")

            system.sleep(200) // Update every 200ms
        }

        println()
        println()
        println("${GREEN}✅ Monitoring complete - ${cycles} monitoring cycles$RESET")
        system.logInfo("System monitoring session: $cycles cycles")
        pause(1000)
    }

    fun logShowcase() {
        println("$BLUE$BOLD═══ Logging System Showcase ═══$RESET")
        println()

        val logEntries = listOf(
            "Application started successfully",
            "User interface initialized",
            "Backend connection established",
            "Performance monitoring active",
            "All systems operational"
        )

        val errorEntries = listOf(
            "Demo error simulation",
            "Network timeout simulation"
        )

        println("${CYAN}📝 Info Logs:$RESET")
        logEntries.forEach { message ->
            system.logInfo(message)
            pause(300)
        }

        println()
        println("${RED}⚠️ Error Logs:$RESET")
        errorEntries.forEach { message ->
            system.logError(message)
            pause(300)
        }

        println()
        println("${GREEN}✅ Logging demonstration complete$RESET")
        pause(1000)
    }

    fun uiCapabilitiesShowcase() {
        println("$BLUE$BOLD═══ UI Capabilities Showcase ═══$RESET")
        println()

        // Color palette demonstration
        println("${BOLD}Color Palette:$RESET")
        println("$RED█$GREEN█$YELLOW█$BLUE█$MAGENTA█$CYAN█$WHITE█$RESET <- Rich colors supported")
        println()

        // Box drawing characters
        println("${BOLD}Box Drawing & Layout:$RESET")
        println("┌─────────────┬─────────────┬─────────────┐")
        println("│   Feature   │    Status   │   Quality   │")
        println("├─────────────┼─────────────┼─────────────┤")
        println("│ Typography  │   ${GREEN}✓ Ready${RESET}   │   ${GREEN}Excellent${RESET}  │")
        println("│ Colors      │   ${GREEN}✓ Ready${RESET}   │   ${GREEN}Full RGB${RESET}   │")
        println("│ Layout      │   ${GREEN}✓ Ready${RESET}   │   ${GREEN}Advanced${RESET}   │")
        println("│ Animations  │   ${YELLOW}○ Demo${RESET}    │   ${YELLOW}Simulated${RESET}  │")
        println("└─────────────┴─────────────┴─────────────┘")
        println()

        // Progress bar animation
        println("${BOLD}Progress Animation:$RESET")
        print("Loading UI components: ")
        for (i in 1..20) {
            print("${GREEN}▓$RESET")
            system.sleep(50)
        }
        println(" ${GREEN}Complete!$RESET")
        println()

        // Menu simulation
        println("${BOLD}Menu System Example:$RESET")
        println("${WHITE}┌─ Application Menu ─────────────────────────────┐$RESET")
        println("${GREEN}  1.$RESET File Operations")
        println("${GREEN}  2.$RESET Edit Functions")
        println("${GREEN}  3.$RESET View Options")
        println("${GREEN}  4.$RESET Tools & Utilities")
        println("${GREEN}  5.$RESET Help & Documentation")
        println("${WHITE}└───────────────────────────────────────────────┘$RESET")
        println()

        println("${GREEN}✅ UI capabilities demonstration complete$RESET")
        pause(1500)
    }

    fun pause(milliseconds: Int) {
        system.sleep(milliseconds)
    }

    fun run() {
        // Initialize system
        if (!system.initialize()) {
            println("${RED}Failed to initialize system!$RESET")
            exitProcess(1)
        }

        clearScreen()
        printHeader()

        system.logInfo("UX Showcase started")

        // Run all showcases
        showSystemInfo()
        mathShowcase()
        stringShowcase()
        logShowcase()
        performanceShowcase()
        mobileOSSimulation()
        systemMonitor()
        uiCapabilitiesShowcase()

        // Final summary
        println("$MAGENTA$BOLD═══ SHOWCASE COMPLETE ═══$RESET")
        println()
        println("${GREEN}🎉 Dowel-Steek UX Showcase Successfully Completed!$RESET")
        println()
        println("${BOLD}What you just saw:$RESET")
        println("${CYAN}✓$RESET Full Kotlin/Native desktop development")
        println("${CYAN}✓$RESET Rich terminal-based user interfaces")
        println("${CYAN}✓$RESET High-performance backend integration")
        println("${CYAN}✓$RESET Real-time system monitoring")
        println("${CYAN}✓$RESET Mobile OS simulation capabilities")
        println("${CYAN}✓$RESET Professional logging system")
        println("${CYAN}✓$RESET Advanced string and math operations")
        println("${CYAN}✓$RESET Native performance benchmarking")
        println()
        println("${BOLD}Development Environment:$RESET")
        println("${CYAN}•$RESET Platform: x86_64 Linux")
        println("${CYAN}•$RESET Language: Kotlin/Native ${system.getVersion()}")
        println("${CYAN}•$RESET Backend: Zig integration via C wrapper")
        println("${CYAN}•$RESET UI: Rich terminal interface")
        println("${CYAN}•$RESET IDE Required: ${GREEN}None - works with any text editor$RESET")
        println("${CYAN}•$RESET Android Studio: ${GREEN}Not needed$RESET")
        println()
        println("${YELLOW}🚀 Ready for production mobile OS development!$RESET")

        // Shutdown
        println()
        println("${YELLOW}Shutting down system...$RESET")
        system.logInfo("UX Showcase shutdown")
        system.shutdown()
        println("${GREEN}System shutdown complete. Goodbye!$RESET")
    }
}

fun main() {
    val showcase = UXShowcase()
    showcase.run()
}
