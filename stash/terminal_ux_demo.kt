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

class TerminalUI {
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
        println("║                    🚀 DOWEL-STEEK UX                     ║")
        println("║                   Terminal Interface                     ║")
        println("╚══════════════════════════════════════════════════════════╝")
        println("$RESET")
    }

    fun printMenu() {
        println("$WHITE$BOLD┌─ Main Menu ─────────────────────────────────────────────┐$RESET")
        println("$GREEN  1.$RESET System Information")
        println("$GREEN  2.$RESET Math Calculator")
        println("$GREEN  3.$RESET String Operations")
        println("$GREEN  4.$RESET System Logs")
        println("$GREEN  5.$RESET Performance Test")
        println("$GREEN  6.$RESET Mobile OS Simulation")
        println("$GREEN  7.$RESET System Monitor")
        println("$RED  0.$RESET Exit")
        println("$WHITE$BOLD└─────────────────────────────────────────────────────────┘$RESET")
        print("$YELLOW▶ Select option: $RESET")
    }

    fun showSystemInfo() {
        clearScreen()
        printHeader()
        println("$BLUE$BOLD═══ System Information ═══$RESET")
        println()

        val version = system.getVersion()
        val timestamp = system.getCurrentTimestamp()
        val uptime = timestamp - startTime

        println("$CYAN• Version:$RESET $version")
        println("$CYAN• Status:$RESET ${if (system.isInitialized()) "${GREEN}Online$RESET" else "${RED}Offline$RESET"}")
        println("$CYAN• Timestamp:$RESET $timestamp ms")
        println("$CYAN• Uptime:$RESET ${uptime}ms (${uptime/1000.0}s)")
        println("$CYAN• Platform:$RESET Kotlin/Native x86_64")
        println("$CYAN• Integration:$RESET Zig backend via C wrapper")
        println()

        system.logInfo("System information accessed")
        waitForEnter()
    }

    fun mathCalculator() {
        clearScreen()
        printHeader()
        println("$BLUE$BOLD═══ Math Calculator ═══$RESET")
        println()

        while (true) {
            print("$CYAN▶ Enter first number (or 'back'): $RESET")
            val input1 = readLine() ?: ""
            if (input1.lowercase() == "back") break

            val num1 = input1.toIntOrNull()
            if (num1 == null) {
                println("${RED}Invalid number!$RESET")
                continue
            }

            print("$CYAN▶ Enter second number: $RESET")
            val input2 = readLine() ?: ""
            val num2 = input2.toIntOrNull()
            if (num2 == null) {
                println("${RED}Invalid number!$RESET")
                continue
            }

            val result = system.addNumbers(num1, num2)
            println("$GREEN✅ Result: $num1 + $num2 = $result$RESET")
            system.logInfo("Math operation: $num1 + $num2 = $result")
            println()
        }
    }

    fun stringOperations() {
        clearScreen()
        printHeader()
        println("$BLUE$BOLD═══ String Operations ═══$RESET")
        println()

        while (true) {
            print("$CYAN▶ Enter a string (or 'back'): $RESET")
            val input = readLine() ?: ""
            if (input.lowercase() == "back") break

            val length = system.getStringLength(input)
            println("$GREEN✅ String: '$input'$RESET")
            println("$GREEN✅ Length: $length characters$RESET")

            // Additional string analysis
            val words = input.split(" ").size
            val vowels = input.count { it.lowercaseChar() in "aeiou" }
            val consonants = input.count { it.isLetter() && it.lowercaseChar() !in "aeiou" }

            println("$YELLOW• Words: $words$RESET")
            println("$YELLOW• Vowels: $vowels$RESET")
            println("$YELLOW• Consonants: $consonants$RESET")
            println()

            system.logInfo("String analysis: '$input' (${length} chars)")
        }
    }

    fun systemLogs() {
        clearScreen()
        printHeader()
        println("$BLUE$BOLD═══ System Logs ═══$RESET")
        println()

        println("$WHITE$BOLD┌─ Log Categories ───────────────────────────────────────┐$RESET")
        println("$GREEN  1.$RESET Send Info Log")
        println("$GREEN  2.$RESET Send Error Log")
        println("$GREEN  3.$RESET Send Custom Message")
        println("$RED  0.$RESET Back to Main Menu")
        println("$WHITE$BOLD└───────────────────────────────────────────────────────┘$RESET")

        while (true) {
            print("$YELLOW▶ Select log type: $RESET")
            when (readLine()) {
                "1" -> {
                    system.logInfo("User triggered info log at ${system.getCurrentTimestamp()}")
                    println("${GREEN}✅ Info log sent$RESET")
                }
                "2" -> {
                    system.logError("User triggered error log at ${system.getCurrentTimestamp()}")
                    println("${RED}✅ Error log sent$RESET")
                }
                "3" -> {
                    print("$CYAN▶ Enter custom message: $RESET")
                    val message = readLine() ?: ""
                    system.logInfo("CUSTOM: $message")
                    println("${GREEN}✅ Custom log sent: '$message'$RESET")
                }
                "0" -> break
                else -> println("${RED}Invalid option!$RESET")
            }
            println()
        }
    }

    fun performanceTest() {
        clearScreen()
        printHeader()
        println("$BLUE$BOLD═══ Performance Test ═══$RESET")
        println()

        print("$CYAN▶ Enter number of function calls to test: $RESET")
        val input = readLine() ?: "1000"
        val iterations = input.toIntOrNull() ?: 1000

        println("${YELLOW}⚡ Testing $iterations function calls...$RESET")

        val startTime = system.getCurrentTimestamp()
        var sum = 0

        // Progress bar
        for (i in 1..iterations) {
            sum += system.addNumbers(i, i)

            if (i % (iterations / 10) == 0) {
                val progress = (i * 100) / iterations
                print("$GREEN▓$RESET")
            }
        }

        val endTime = system.getCurrentTimestamp()
        val duration = endTime - startTime

        println()
        println("$GREEN✅ Performance Test Complete!$RESET")
        println("$CYAN• Function calls:$RESET $iterations")
        println("$CYAN• Total time:$RESET ${duration}ms")
        println("$CYAN• Average per call:$RESET ${if (iterations > 0) duration.toDouble() / iterations else 0.0}ms")
        println("$CYAN• Sum result:$RESET $sum")
        println("$CYAN• Calls per second:$RESET ${if (duration > 0) (iterations * 1000) / duration else "∞"}")

        system.logInfo("Performance test: $iterations calls in ${duration}ms")
        waitForEnter()
    }

    fun mobileOSSimulation() {
        clearScreen()
        printHeader()
        println("$BLUE$BOLD═══ Mobile OS Simulation ═══$RESET")
        println()

        val services = listOf(
            "Display Manager",
            "Input Handler",
            "Audio System",
            "Network Stack",
            "Power Manager",
            "Storage Manager",
            "Security Module"
        )

        println("${YELLOW}🚀 Starting Mobile OS Services...$RESET")
        system.logInfo("Mobile OS simulation started")
        println()

        val startupTime = system.getCurrentTimestamp()

        services.forEachIndexed { index, service ->
            print("$CYAN▶ Starting $service...$RESET")

            // Simulate startup time
            val delay = (20..100).random()
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

        system.logInfo("Mobile OS simulation complete - startup: ${totalStartupTime}ms")
        waitForEnter()
    }

    fun systemMonitor() {
        clearScreen()
        printHeader()
        println("$BLUE$BOLD═══ System Monitor ═══$RESET")
        println()

        println("${YELLOW}📊 Real-time system monitoring...$RESET")
        println("${YELLOW}Monitoring for 10 seconds...$RESET")
        println()

        val monitorStart = system.getCurrentTimestamp()
        var cycles = 0

        while (cycles < 20) {
            cycles++
            val currentTime = system.getCurrentTimestamp()
            val uptime = currentTime - monitorStart

            // Simulate system metrics
            val cpuUsage = (10..45).random()
            val memUsage = (256..512).random()
            val networkActivity = (0..100).random()

            // Clear previous line and show new metrics
            print("\r$CYAN● Uptime:$RESET ${uptime}ms $CYAN● CPU:$RESET ${cpuUsage}% $CYAN● Memory:$RESET ${memUsage}MB $CYAN● Network:$RESET ${networkActivity}KB/s $CYAN● Cycles:$RESET $cycles")

            system.sleep(500) // Update every 500ms
        }

        println()
        println()
        println("${GREEN}✅ Monitoring stopped$RESET")
        system.logInfo("System monitoring session: $cycles cycles, ${system.getCurrentTimestamp() - monitorStart}ms")
        waitForEnter()
    }

    fun waitForEnter() {
        println()
        print("${YELLOW}Press Enter to continue...$RESET")
        readLine()
    }

    private var startTime: Long = 0

    fun run() {
        // Initialize system
        if (!system.initialize()) {
            println("${RED}Failed to initialize system!$RESET")
            exitProcess(1)
        }

        startTime = system.getCurrentTimestamp()
        system.logInfo("Terminal UX started")

        while (true) {
            clearScreen()
            printHeader()
            printMenu()

            when (readLine()) {
                "1" -> showSystemInfo()
                "2" -> mathCalculator()
                "3" -> stringOperations()
                "4" -> systemLogs()
                "5" -> performanceTest()
                "6" -> mobileOSSimulation()
                "7" -> systemMonitor()
                "0" -> {
                    println("\n${YELLOW}Shutting down...$RESET")
                    system.logInfo("Terminal UX shutdown requested")
                    system.shutdown()
                    println("${GREEN}Goodbye!$RESET")
                    break
                }
                else -> {
                    println("${RED}Invalid option! Please try again.$RESET")
                    system.sleep(1000)
                }
            }
        }

        exitProcess(0)
    }
}

fun main() {
    val ui = TerminalUI()
    ui.run()
}
