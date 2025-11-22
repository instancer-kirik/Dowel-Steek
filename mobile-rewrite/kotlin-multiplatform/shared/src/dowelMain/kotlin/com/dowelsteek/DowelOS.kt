package com.dowelsteek

import com.dowelsteek.app.*
import com.dowelsteek.core.SystemInterface
import com.dowelsteek.apps.LauncherApp
import com.dowelsteek.apps.SettingsApp
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

/**
 * Main OS Runtime for Dowel-Steek Mobile OS
 *
 * This is the core system that:
 * - Initializes all Zig system services
 * - Manages the Kotlin application framework
 * - Handles system-wide events and input
 * - Provides the main event loop
 */
class DowelOS private constructor() {
    companion object {
        @Volatile
        private var INSTANCE: DowelOS? = null

        fun getInstance(): DowelOS {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: DowelOS().also { INSTANCE = it }
            }
        }

        // Native display integration
        @SymbolName("dowel_display_create_canvas")
        external fun nativeCreateCanvas(width: Int, height: Int): Long

        @SymbolName("dowel_display_render_frame")
        external fun nativeRenderFrame(canvasHandle: Long)

        @SymbolName("dowel_display_get_input_events")
        external fun nativeGetInputEvents(buffer: ByteArray): Int

        @SymbolName("dowel_display_should_quit")
        external fun nativeShouldQuit(): Boolean
    }

    private val systemInterface = SystemInterface.getInstance()
    private val appManager = AppManager()
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // System state
    private var isRunning = false
    private var displayWidth = 1080
    private var displayHeight = 2340
    private var canvasHandle: Long = 0

    // Performance tracking
    private var lastFrameTime = 0L
    private var frameCount = 0
    private var fps = 0f

    // Input handling
    private data class InputEvent(
        val type: InputType,
        val x: Float = 0f,
        val y: Float = 0f,
        val keyCode: Int = 0,
        val timestamp: Long = System.currentTimeMillis()
    )

    private enum class InputType {
        TOUCH_DOWN, TOUCH_MOVE, TOUCH_UP, KEY_DOWN, KEY_UP, BACK_PRESSED
    }

    /**
     * Initialize the OS - must be called before run()
     */
    suspend fun initialize(): Result<Unit> = withContext(Dispatchers.Default) {
        try {
            // Initialize core Zig services
            systemInterface.initialize().getOrThrow()

            // Create display canvas
            canvasHandle = nativeCreateCanvas(displayWidth, displayHeight)
            if (canvasHandle == 0L) {
                return@withContext Result.failure(Exception("Failed to create display canvas"))
            }

            // Install system apps
            installSystemApps()

            // Launch the launcher app
            appManager.launchApp("com.dowelsteek.launcher").getOrThrow()

            println("Dowel-Steek Mobile OS initialized successfully")
            Result.success(Unit)

        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Main OS event loop - call this to run the OS
     */
    suspend fun run() {
        if (!systemInterface.isInitialized()) {
            throw IllegalStateException("OS must be initialized before running")
        }

        isRunning = true
        lastFrameTime = System.currentTimeMillis()

        println("Starting Dowel-Steek OS main event loop...")

        try {
            while (isRunning && !nativeShouldQuit()) {
                val currentTime = System.currentTimeMillis()
                val deltaTime = (currentTime - lastFrameTime) / 1000f
                lastFrameTime = currentTime

                // Handle input events
                handleInputEvents()

                // Update current app
                appManager.updateCurrentApp(deltaTime)

                // Render frame
                renderFrame()

                // Update performance metrics
                updatePerformanceMetrics(deltaTime)

                // Cap framerate to ~60 FPS
                delay(16) // ~16ms = 60 FPS

                frameCount++
            }
        } catch (e: Exception) {
            println("OS runtime error: ${e.message}")
            throw e
        } finally {
            shutdown()
        }
    }

    /**
     * Shutdown the OS
     */
    fun shutdown() {
        println("Shutting down Dowel-Steek OS...")

        isRunning = false
        appManager.shutdown()
        systemInterface.shutdown()
        scope.cancel()

        println("OS shutdown complete")
    }

    private suspend fun installSystemApps() {
        // Install launcher
        val launcher = LauncherApp()
        appManager.installApp(launcher).getOrThrow()

        // Install settings
        val settings = SettingsApp()
        appManager.installApp(settings).getOrThrow()

        println("System apps installed: Launcher, Settings")
    }

    private suspend fun handleInputEvents() {
        val eventBuffer = ByteArray(1024)
        val eventCount = nativeGetInputEvents(eventBuffer)

        if (eventCount > 0) {
            // Parse input events from buffer
            // This is a simplified version - real implementation would parse binary event data
            val events = parseInputEvents(eventBuffer, eventCount)

            for (event in events) {
                when (event.type) {
                    InputType.TOUCH_DOWN -> {
                        appManager.handleTouch(event.x, event.y, TouchAction.DOWN)
                    }
                    InputType.TOUCH_MOVE -> {
                        appManager.handleTouch(event.x, event.y, TouchAction.MOVE)
                    }
                    InputType.TOUCH_UP -> {
                        appManager.handleTouch(event.x, event.y, TouchAction.UP)
                    }
                    InputType.KEY_DOWN -> {
                        appManager.handleKey(event.keyCode, KeyAction.DOWN)
                    }
                    InputType.KEY_UP -> {
                        appManager.handleKey(event.keyCode, KeyAction.UP)
                    }
                    InputType.BACK_PRESSED -> {
                        if (!appManager.handleBackPressed()) {
                            // If app didn't handle back press, go to launcher
                            appManager.launchApp("com.dowelsteek.launcher")
                        }
                    }
                }
            }
        }
    }

    private fun parseInputEvents(buffer: ByteArray, count: Int): List<InputEvent> {
        // Simplified event parsing - real implementation would parse binary data
        // For now, return empty list (events would be handled by display system)
        return emptyList()
    }

    private suspend fun renderFrame() {
        // Create canvas wrapper for current app
        val canvas = NativeCanvas(canvasHandle, displayWidth, displayHeight)

        // Clear screen
        canvas.clear(Color.BLACK)

        // Render current app
        appManager.renderCurrentApp(canvas)

        // Render system UI overlays (status bar, etc.)
        renderSystemOverlays(canvas)

        // Present frame to display
        nativeRenderFrame(canvasHandle)
    }

    private fun renderSystemOverlays(canvas: Canvas) {
        // Status bar
        canvas.drawRect(0f, 0f, displayWidth.toFloat(), 60f, Color(20, 20, 20))

        // Time (simplified)
        canvas.drawText("12:34", 20f, 35f, Color.WHITE, 16f)

        // Battery (simplified)
        canvas.drawRect(displayWidth - 80f, 15f, 60f, 30f, Color(60, 60, 60))
        canvas.drawRect(displayWidth - 75f, 20f, 45f, 20f, Color.GREEN)

        // Performance overlay (debug)
        canvas.drawText("FPS: ${fps.toInt()}", 20f, displayHeight - 40f, Color.YELLOW, 12f)
        canvas.drawText("App: ${appManager.getCurrentApp()?.manifest?.name ?: "None"}", 20f, displayHeight - 20f, Color.YELLOW, 12f)
    }

    private fun updatePerformanceMetrics(deltaTime: Float) {
        if (deltaTime > 0) {
            fps = 1f / deltaTime
        }
    }

    /**
     * Launch a specific app by ID
     */
    suspend fun launchApp(appId: String): Result<Unit> {
        return appManager.launchApp(appId)
    }

    /**
     * Get list of installed apps
     */
    fun getInstalledApps(): List<AppManifest> {
        return appManager.getInstalledApps()
    }

    /**
     * Get current app
     */
    fun getCurrentApp(): App? {
        return appManager.getCurrentApp()
    }

    /**
     * Get system information
     */
    fun getSystemInfo(): SystemInfo {
        return SystemInfo(
            osVersion = systemInterface.getVersion(),
            displayWidth = displayWidth,
            displayHeight = displayHeight,
            fps = fps,
            uptime = System.currentTimeMillis() - lastFrameTime,
            installedApps = appManager.getInstalledApps().size
        )
    }
}

/**
 * Canvas implementation that bridges to Zig display system
 */
private class NativeCanvas(
    private val handle: Long,
    override val width: Int,
    override val height: Int
) : Canvas {

    @SymbolName("dowel_canvas_clear")
    external fun nativeClear(handle: Long, r: Int, g: Int, b: Int, a: Int)

    @SymbolName("dowel_canvas_draw_rect")
    external fun nativeDrawRect(handle: Long, x: Float, y: Float, w: Float, h: Float, r: Int, g: Int, b: Int, a: Int)

    @SymbolName("dowel_canvas_draw_circle")
    external fun nativeDrawCircle(handle: Long, x: Float, y: Float, radius: Float, r: Int, g: Int, b: Int, a: Int)

    @SymbolName("dowel_canvas_draw_text")
    external fun nativeDrawText(handle: Long, text: String, x: Float, y: Float, r: Int, g: Int, b: Int, a: Int, size: Float)

    @SymbolName("dowel_canvas_draw_line")
    external fun nativeDrawLine(handle: Long, x1: Float, y1: Float, x2: Float, y2: Float, r: Int, g: Int, b: Int, a: Int, width: Float)

    override fun clear(color: Color) {
        nativeClear(handle, color.r, color.g, color.b, color.a)
    }

    override fun drawRect(x: Float, y: Float, width: Float, height: Float, color: Color) {
        nativeDrawRect(handle, x, y, width, height, color.r, color.g, color.b, color.a)
    }

    override fun drawCircle(x: Float, y: Float, radius: Float, color: Color) {
        nativeDrawCircle(handle, x, y, radius, color.r, color.g, color.b, color.a)
    }

    override fun drawText(text: String, x: Float, y: Float, color: Color, size: Float) {
        nativeDrawText(handle, text, x, y, color.r, color.g, color.b, color.a, size)
    }

    override fun drawLine(x1: Float, y1: Float, x2: Float, y2: Float, color: Color, width: Float) {
        nativeDrawLine(handle, x1, y1, x2, y2, color.r, color.g, color.b, color.a, width)
    }
}

/**
 * System information data class
 */
data class SystemInfo(
    val osVersion: String,
    val displayWidth: Int,
    val displayHeight: Int,
    val fps: Float,
    val uptime: Long,
    val installedApps: Int
)

/**
 * Main entry point for Dowel-Steek OS
 */
suspend fun main() {
    val os = DowelOS.getInstance()

    try {
        println("=".repeat(50))
        println("Dowel-Steek Mobile OS v0.1.0")
        println("Zig Core + Kotlin Apps Architecture")
        println("=".repeat(50))

        // Initialize the OS
        os.initialize().getOrThrow()

        // Run the main event loop
        os.run()

    } catch (e: Exception) {
        println("Fatal OS error: ${e.message}")
        e.printStackTrace()
        os.shutdown()
    }
}
