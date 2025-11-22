package com.dowelsteek.apps

import com.dowelsteek.app.*
import kotlinx.coroutines.*

/**
 * Settings App - System configuration and preferences
 *
 * Features:
 * - System information display
 * - Display and UI settings
 * - Network and connectivity settings
 * - Security and privacy settings
 * - Developer options
 */
class SettingsApp : App() {

    override val manifest = AppManifest(
        id = "com.dowelsteek.settings",
        name = "Settings",
        version = "1.0.0",
        description = "System settings and configuration",
        author = "Dowel-Steek OS",
        permissions = listOf("SYSTEM_SETTINGS", "MODIFY_SYSTEM"),
        mainClass = "com.dowelsteek.apps.SettingsApp",
        category = AppCategory.SYSTEM
    )

    private var selectedItemIndex = 0
    private var currentSection = SettingsSection.MAIN
    private var scrollOffset = 0f
    private var animationTime = 0f
    private var showingDetail = false

    // Settings sections
    private enum class SettingsSection {
        MAIN, DISPLAY, NETWORK, SECURITY, SYSTEM, DEVELOPER
    }

    // Main settings categories
    private val mainSettings = listOf(
        SettingsItem("📱", "Display & UI", "Screen brightness, themes, wallpapers"),
        SettingsItem("📶", "Network", "WiFi, cellular, Bluetooth connections"),
        SettingsItem("🔒", "Security", "Screen lock, permissions, privacy"),
        SettingsItem("⚡", "System", "Performance, storage, updates"),
        SettingsItem("🛠️", "Developer", "Debug options, advanced features"),
        SettingsItem("ℹ️", "About", "System info, version, legal")
    )

    // Display settings
    private val displaySettings = listOf(
        SettingsItem("☀️", "Brightness", "Auto-brightness: On"),
        SettingsItem("🌙", "Dark Mode", "System default"),
        SettingsItem("🎨", "Theme", "Dowel Blue"),
        SettingsItem("🖼️", "Wallpaper", "Dynamic landscape"),
        SettingsItem("📏", "Display Size", "Default"),
        SettingsItem("🔤", "Font Size", "Medium")
    )

    // Network settings
    private val networkSettings = listOf(
        SettingsItem("📶", "WiFi", "Connected to Home-5G"),
        SettingsItem("📱", "Mobile Data", "Enabled"),
        SettingsItem("🔵", "Bluetooth", "2 devices connected"),
        SettingsItem("🌐", "VPN", "Not connected"),
        SettingsItem("🔗", "Hotspot", "Disabled"),
        SettingsItem("✈️", "Airplane Mode", "Off")
    )

    // System info
    private val systemInfo = listOf(
        SystemInfoItem("OS Version", "Dowel-Steek 0.1.0"),
        SystemInfoItem("Build", "dev.208+8acedfd5b"),
        SystemInfoItem("Architecture", "aarch64-linux"),
        SystemInfoItem("Kernel", "Zig 0.15.0"),
        SystemInfoItem("Runtime", "Kotlin/Native 1.9.20"),
        SystemInfoItem("Uptime", "2h 34m"),
        SystemInfoItem("Memory", "2.1GB / 8GB"),
        SystemInfoItem("Storage", "45GB / 128GB")
    )

    private data class SettingsItem(
        val icon: String,
        val title: String,
        val description: String
    )

    private data class SystemInfoItem(
        val label: String,
        val value: String
    )

    override suspend fun onCreate() {
        println("Settings app created")
    }

    override suspend fun onStart() {
        println("Settings app started")
    }

    override suspend fun onUpdate(deltaTime: Float) {
        animationTime += deltaTime
    }

    override suspend fun onRender(canvas: Canvas) {
        // Background
        canvas.clear(Color(15, 15, 20))

        // Header
        drawHeader(canvas)

        // Content area
        val contentY = 120f
        when (currentSection) {
            SettingsSection.MAIN -> drawMainSettings(canvas, contentY)
            SettingsSection.DISPLAY -> drawDisplaySettings(canvas, contentY)
            SettingsSection.NETWORK -> drawNetworkSettings(canvas, contentY)
            SettingsSection.SECURITY -> drawSecuritySettings(canvas, contentY)
            SettingsSection.SYSTEM -> drawSystemInfo(canvas, contentY)
            SettingsSection.DEVELOPER -> drawDeveloperOptions(canvas, contentY)
        }

        // Navigation hints
        drawNavigationHints(canvas)
    }

    private fun drawHeader(canvas: Canvas) {
        val headerHeight = 100f

        // Header background
        canvas.drawRect(0f, 60f, canvas.width.toFloat(), headerHeight, Color(25, 25, 35))

        // Back button (if not in main section)
        if (currentSection != SettingsSection.MAIN) {
            canvas.drawText("←", 30f, 110f, Color.WHITE, 24f)
        }

        // Title
        val title = when (currentSection) {
            SettingsSection.MAIN -> "Settings"
            SettingsSection.DISPLAY -> "Display & UI"
            SettingsSection.NETWORK -> "Network"
            SettingsSection.SECURITY -> "Security"
            SettingsSection.SYSTEM -> "System Info"
            SettingsSection.DEVELOPER -> "Developer Options"
        }

        val titleX = if (currentSection != SettingsSection.MAIN) 80f else 30f
        canvas.drawText(title, titleX, 110f, Color.WHITE, 20f)

        // Search icon
        canvas.drawText("🔍", canvas.width - 60f, 110f, Color.GRAY, 20f)

        // Header divider
        canvas.drawLine(0f, 160f, canvas.width.toFloat(), 160f, Color(40, 40, 50))
    }

    private fun drawMainSettings(canvas: Canvas, startY: Float) {
        val itemHeight = 80f

        mainSettings.forEachIndexed { index, item ->
            val y = startY + index * itemHeight + scrollOffset
            val isSelected = index == selectedItemIndex

            // Skip off-screen items
            if (y < -itemHeight || y > canvas.height + itemHeight) return@forEachIndexed

            drawSettingsItem(canvas, item, y, isSelected, true)
        }
    }

    private fun drawDisplaySettings(canvas: Canvas, startY: Float) {
        val itemHeight = 70f

        displaySettings.forEachIndexed { index, item ->
            val y = startY + index * itemHeight + scrollOffset
            val isSelected = index == selectedItemIndex

            if (y < -itemHeight || y > canvas.height + itemHeight) return@forEachIndexed

            drawSettingsItem(canvas, item, y, isSelected, false)
        }
    }

    private fun drawNetworkSettings(canvas: Canvas, startY: Float) {
        val itemHeight = 70f

        networkSettings.forEachIndexed { index, item ->
            val y = startY + index * itemHeight + scrollOffset
            val isSelected = index == selectedItemIndex

            if (y < -itemHeight || y > canvas.height + itemHeight) return@forEachIndexed

            drawSettingsItem(canvas, item, y, isSelected, false)
        }
    }

    private fun drawSecuritySettings(canvas: Canvas, startY: Float) {
        val securityItems = listOf(
            SettingsItem("🔐", "Screen Lock", "Pattern"),
            SettingsItem("👤", "Privacy", "App permissions"),
            SettingsItem("🛡️", "Security", "Device encryption"),
            SettingsItem("🔑", "Passwords", "Save passwords: On"),
            SettingsItem("📍", "Location", "High accuracy mode"),
            SettingsItem("🎤", "Microphone", "12 apps have access")
        )

        val itemHeight = 70f

        securityItems.forEachIndexed { index, item ->
            val y = startY + index * itemHeight + scrollOffset
            val isSelected = index == selectedItemIndex

            if (y < -itemHeight || y > canvas.height + itemHeight) return@forEachIndexed

            drawSettingsItem(canvas, item, y, isSelected, false)
        }
    }

    private fun drawSystemInfo(canvas: Canvas, startY: Float) {
        val itemHeight = 60f

        // System overview section
        canvas.drawText("System Overview", 30f, startY + 20f, Color(150, 150, 160), 16f)

        systemInfo.forEachIndexed { index, item ->
            val y = startY + 40f + index * itemHeight + scrollOffset

            if (y < -itemHeight || y > canvas.height + itemHeight) return@forEachIndexed

            // Item background
            val bgColor = if (index == selectedItemIndex) Color(40, 40, 50) else Color.TRANSPARENT
            canvas.drawRect(20f, y - 15f, canvas.width - 40f, itemHeight - 10f, bgColor)

            // Label
            canvas.drawText(item.label, 40f, y + 15f, Color.GRAY, 14f)

            // Value
            canvas.drawText(item.value, canvas.width - 200f, y + 15f, Color.WHITE, 14f)
        }

        // Performance section
        val perfY = startY + 40f + systemInfo.size * itemHeight + 40f
        canvas.drawText("Performance", 30f, perfY, Color(150, 150, 160), 16f)

        // CPU usage bar
        drawProgressBar(canvas, 40f, perfY + 30f, canvas.width - 80f, 20f, 0.35f, Color(100, 200, 100), "CPU: 35%")

        // Memory usage bar
        drawProgressBar(canvas, 40f, perfY + 70f, canvas.width - 80f, 20f, 0.67f, Color(200, 150, 50), "Memory: 67%")

        // Storage usage bar
        drawProgressBar(canvas, 40f, perfY + 110f, canvas.width - 80f, 20f, 0.45f, Color(50, 150, 200), "Storage: 45%")
    }

    private fun drawDeveloperOptions(canvas: Canvas, startY: Float) {
        val devOptions = listOf(
            SettingsItem("🐛", "Debug Mode", "Disabled"),
            SettingsItem("📊", "Show FPS", "Enabled"),
            SettingsItem("⚡", "Performance", "Show render metrics"),
            SettingsItem("🔧", "System Logs", "View system output"),
            SettingsItem("🧪", "Experimental", "Beta features"),
            SettingsItem("🔄", "Reset", "Factory reset options")
        )

        val itemHeight = 70f

        // Warning banner
        canvas.drawRect(20f, startY, canvas.width - 40f, 60f, Color(80, 40, 40))
        canvas.drawText("⚠️", 40f, startY + 35f, Color(255, 200, 100), 20f)
        canvas.drawText("Developer options - use with caution", 80f, startY + 35f, Color(255, 200, 100), 14f)

        devOptions.forEachIndexed { index, item ->
            val y = startY + 80f + index * itemHeight + scrollOffset
            val isSelected = index == selectedItemIndex

            if (y < -itemHeight || y > canvas.height + itemHeight) return@forEachIndexed

            drawSettingsItem(canvas, item, y, isSelected, false)
        }
    }

    private fun drawSettingsItem(canvas: Canvas, item: SettingsItem, y: Float, isSelected: Boolean, hasArrow: Boolean) {
        val itemHeight = 70f

        // Selection background
        if (isSelected) {
            canvas.drawRect(20f, y - 10f, canvas.width - 40f, itemHeight, Color(40, 60, 100, 120))
        }

        // Icon
        canvas.drawText(item.icon, 40f, y + 35f, Color.WHITE, 24f)

        // Title
        canvas.drawText(item.title, 90f, y + 25f, Color.WHITE, 16f)

        // Description
        canvas.drawText(item.description, 90f, y + 45f, Color.GRAY, 12f)

        // Arrow indicator
        if (hasArrow) {
            canvas.drawText("→", canvas.width - 50f, y + 35f, Color.GRAY, 16f)
        }

        // Selection indicator
        if (isSelected) {
            canvas.drawRect(20f, y - 5f, 4f, itemHeight - 10f, Color.WHITE)
        }
    }

    private fun drawProgressBar(canvas: Canvas, x: Float, y: Float, width: Float, height: Float, progress: Float, color: Color, label: String) {
        // Background
        canvas.drawRect(x, y, width, height, Color(40, 40, 50))

        // Progress
        canvas.drawRect(x, y, width * progress, height, color)

        // Border
        canvas.drawLine(x, y, x + width, y, Color.GRAY)
        canvas.drawLine(x, y + height, x + width, y + height, Color.GRAY)
        canvas.drawLine(x, y, x, y + height, Color.GRAY)
        canvas.drawLine(x + width, y, x + width, y + height, Color.GRAY)

        // Label
        canvas.drawText(label, x, y - 10f, Color.WHITE, 12f)
    }

    private fun drawNavigationHints(canvas: Canvas) {
        val hintsY = canvas.height - 60f

        // Background
        canvas.drawRect(0f, hintsY, canvas.width.toFloat(), 60f, Color(20, 20, 30, 200))

        // Hints
        when (currentSection) {
            SettingsSection.MAIN -> {
                canvas.drawText("Enter: Open section", 30f, hintsY + 25f, Color.GRAY, 12f)
                canvas.drawText("↑↓: Navigate", 30f, hintsY + 45f, Color.GRAY, 12f)
            }
            else -> {
                canvas.drawText("← Back", 30f, hintsY + 25f, Color.GRAY, 12f)
                canvas.drawText("Enter: Select", 150f, hintsY + 25f, Color.GRAY, 12f)
            }
        }

        canvas.drawText("ESC: Exit", canvas.width - 100f, hintsY + 35f, Color.GRAY, 12f)
    }

    override suspend fun onTouch(x: Float, y: Float, action: TouchAction): Boolean {
        when (action) {
            TouchAction.DOWN -> {
                return handleTouchDown(x, y)
            }
            TouchAction.UP -> {
                return handleTouchUp(x, y)
            }
            else -> return false
        }
    }

    private suspend fun handleTouchDown(x: Float, y: Float): Boolean {
        // Handle back button
        if (currentSection != SettingsSection.MAIN && x < 60f && y >= 60f && y <= 160f) {
            currentSection = SettingsSection.MAIN
            selectedItemIndex = 0
            return true
        }

        // Handle list item selection
        val contentY = 180f
        val itemHeight = if (currentSection == SettingsSection.MAIN) 80f else 70f
        val itemIndex = ((y - contentY - scrollOffset) / itemHeight).toInt()

        val maxItems = when (currentSection) {
            SettingsSection.MAIN -> mainSettings.size
            SettingsSection.DISPLAY -> displaySettings.size
            SettingsSection.NETWORK -> networkSettings.size
            SettingsSection.SECURITY -> 6
            SettingsSection.SYSTEM -> systemInfo.size
            SettingsSection.DEVELOPER -> 6
        }

        if (itemIndex >= 0 && itemIndex < maxItems) {
            selectedItemIndex = itemIndex
            return true
        }

        return true
    }

    private suspend fun handleTouchUp(x: Float, y: Float): Boolean {
        val contentY = 180f
        val itemHeight = if (currentSection == SettingsSection.MAIN) 80f else 70f
        val itemIndex = ((y - contentY - scrollOffset) / itemHeight).toInt()

        if (currentSection == SettingsSection.MAIN && itemIndex == selectedItemIndex) {
            // Navigate to subsection
            when (itemIndex) {
                0 -> currentSection = SettingsSection.DISPLAY
                1 -> currentSection = SettingsSection.NETWORK
                2 -> currentSection = SettingsSection.SECURITY
                3 -> currentSection = SettingsSection.SYSTEM
                4 -> currentSection = SettingsSection.DEVELOPER
                5 -> currentSection = SettingsSection.SYSTEM // About -> System info
            }
            selectedItemIndex = 0
            println("Navigated to section: $currentSection")
        } else {
            // Handle item interaction
            println("Selected item $selectedItemIndex in section $currentSection")
        }

        return true
    }

    override suspend fun onKey(keyCode: Int, action: KeyAction): Boolean {
        if (action == KeyAction.DOWN) {
            when (keyCode) {
                38 -> { // Up arrow
                    if (selectedItemIndex > 0) {
                        selectedItemIndex--
                    }
                    return true
                }
                40 -> { // Down arrow
                    val maxItems = when (currentSection) {
                        SettingsSection.MAIN -> mainSettings.size
                        SettingsSection.DISPLAY -> displaySettings.size
                        SettingsSection.NETWORK -> networkSettings.size
                        SettingsSection.SECURITY -> 6
                        SettingsSection.SYSTEM -> systemInfo.size
                        SettingsSection.DEVELOPER -> 6
                    }
                    if (selectedItemIndex < maxItems - 1) {
                        selectedItemIndex++
                    }
                    return true
                }
                13 -> { // Enter key
                    if (currentSection == SettingsSection.MAIN) {
                        // Navigate to subsection
                        when (selectedItemIndex) {
                            0 -> currentSection = SettingsSection.DISPLAY
                            1 -> currentSection = SettingsSection.NETWORK
                            2 -> currentSection = SettingsSection.SECURITY
                            3 -> currentSection = SettingsSection.SYSTEM
                            4 -> currentSection = SettingsSection.DEVELOPER
                            5 -> currentSection = SettingsSection.SYSTEM
                        }
                        selectedItemIndex = 0
                    }
                    return true
                }
            }
        }
        return false
    }

    override suspend fun onBackPressed(): Boolean {
        if (currentSection != SettingsSection.MAIN) {
            currentSection = SettingsSection.MAIN
            selectedItemIndex = 0
            return true
        }
        return false // Let launcher handle back press
    }
}
