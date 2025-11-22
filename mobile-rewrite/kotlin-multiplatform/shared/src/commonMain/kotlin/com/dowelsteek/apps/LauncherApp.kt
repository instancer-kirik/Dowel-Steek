package com.dowelsteek.apps

import com.dowelsteek.app.*
import kotlinx.coroutines.*

/**
 * Launcher App - Main home screen for Dowel-Steek Mobile OS
 *
 * Features:
 * - App grid with installed applications
 * - Quick access to system functions
 * - Search functionality
 * - Widgets and shortcuts
 */
class LauncherApp : App() {

    override val manifest = AppManifest(
        id = "com.dowelsteek.launcher",
        name = "Dowel Launcher",
        version = "1.0.0",
        description = "Default launcher and home screen",
        author = "Dowel-Steek OS",
        permissions = listOf("SYSTEM_APPS", "LAUNCH_APPS"),
        mainClass = "com.dowelsteek.apps.LauncherApp",
        category = AppCategory.SYSTEM
    )

    private var selectedAppIndex = 0
    private var scrollOffset = 0f
    private val maxAppsPerRow = 4
    private val appIconSize = 120f
    private val appIconSpacing = 140f
    private var searchQuery = ""
    private var showingSearch = false

    // Sample apps for demonstration
    private val sampleApps = listOf(
        AppInfo("com.dowelsteek.settings", "Settings", "⚙️"),
        AppInfo("com.dowelsteek.files", "Files", "📁"),
        AppInfo("com.dowelsteek.browser", "Browser", "🌐"),
        AppInfo("com.dowelsteek.camera", "Camera", "📷"),
        AppInfo("com.dowelsteek.gallery", "Gallery", "🖼️"),
        AppInfo("com.dowelsteek.music", "Music", "🎵"),
        AppInfo("com.dowelsteek.messages", "Messages", "💬"),
        AppInfo("com.dowelsteek.contacts", "Contacts", "👥"),
        AppInfo("com.dowelsteek.calculator", "Calculator", "🧮"),
        AppInfo("com.dowelsteek.weather", "Weather", "🌤️"),
        AppInfo("com.dowelsteek.notes", "Notes", "📝"),
        AppInfo("com.dowelsteek.clock", "Clock", "⏰")
    )

    private data class AppInfo(
        val id: String,
        val name: String,
        val icon: String
    )

    private var animationTime = 0f

    override suspend fun onCreate() {
        println("Launcher app created")
    }

    override suspend fun onStart() {
        println("Launcher app started")
    }

    override suspend fun onUpdate(deltaTime: Float) {
        animationTime += deltaTime
    }

    override suspend fun onRender(canvas: Canvas) {
        val centerX = canvas.width / 2f

        // Background gradient
        drawBackground(canvas)

        // Status area at top (reserve space for system status bar)
        val contentStartY = 80f

        // Search bar (if showing)
        if (showingSearch) {
            drawSearchBar(canvas, centerX, contentStartY + 20f)
        }

        // Quick actions bar
        val quickActionsY = if (showingSearch) contentStartY + 100f else contentStartY + 20f
        drawQuickActions(canvas, centerX, quickActionsY)

        // App grid
        val appsStartY = quickActionsY + 80f
        drawAppGrid(canvas, appsStartY)

        // Dock at bottom
        drawDock(canvas)

        // Page indicators
        drawPageIndicators(canvas)
    }

    private fun drawBackground(canvas: Canvas) {
        // Gradient background
        canvas.clear(Color(25, 25, 30))

        // Subtle animated background pattern
        val time = animationTime * 0.5f
        for (i in 0..20) {
            val x = (i * 100f + kotlin.math.sin(time + i * 0.5) * 50f) % canvas.width
            val y = (i * 80f + kotlin.math.cos(time + i * 0.3) * 30f) % canvas.height
            val alpha = (kotlin.math.sin(time + i) * 0.1 + 0.05).coerceIn(0.0, 0.1)
            canvas.drawCircle(x, y, 20f, Color(100, 150, 200, (alpha * 255).toInt()))
        }
    }

    private fun drawSearchBar(canvas: Canvas, centerX: Float, y: Float) {
        val searchBarWidth = canvas.width - 40f
        val searchBarHeight = 50f

        // Search bar background
        canvas.drawRect(
            20f, y, searchBarWidth, searchBarHeight,
            Color(40, 40, 45, 200)
        )

        // Search icon
        canvas.drawText("🔍", 40f, y + 30f, Color.GRAY, 20f)

        // Search text
        val searchText = if (searchQuery.isBlank()) "Search apps..." else searchQuery
        val textColor = if (searchQuery.isBlank()) Color.GRAY else Color.WHITE
        canvas.drawText(searchText, 80f, y + 30f, textColor, 16f)
    }

    private fun drawQuickActions(canvas: Canvas, centerX: Float, y: Float) {
        val actions = listOf(
            QuickAction("📷", "Camera"),
            QuickAction("💬", "Messages"),
            QuickAction("🌐", "Browser"),
            QuickAction("⚙️", "Settings")
        )

        val actionWidth = 60f
        val actionSpacing = 80f
        val totalWidth = actions.size * actionSpacing
        val startX = centerX - totalWidth / 2f

        actions.forEachIndexed { index, action ->
            val x = startX + index * actionSpacing

            // Action background
            canvas.drawCircle(x, y, actionWidth / 2f, Color(60, 60, 70, 180))

            // Action icon
            canvas.drawText(action.icon, x - 15f, y + 5f, Color.WHITE, 24f)

            // Action label
            canvas.drawText(action.label, x - action.label.length * 4f, y + 45f, Color.GRAY, 12f)
        }
    }

    private data class QuickAction(val icon: String, val label: String)

    private fun drawAppGrid(canvas: Canvas, startY: Float) {
        val appsToShow = if (showingSearch && searchQuery.isNotBlank()) {
            sampleApps.filter { it.name.contains(searchQuery, ignoreCase = true) }
        } else {
            sampleApps
        }

        val rows = (appsToShow.size + maxAppsPerRow - 1) / maxAppsPerRow
        val gridStartX = (canvas.width - maxAppsPerRow * appIconSpacing) / 2f + appIconSpacing / 2f

        appsToShow.forEachIndexed { index, app ->
            val row = index / maxAppsPerRow
            val col = index % maxAppsPerRow

            val x = gridStartX + col * appIconSpacing
            val y = startY + row * appIconSpacing + scrollOffset

            // Skip apps that are off-screen
            if (y < -appIconSize || y > canvas.height + appIconSize) return@forEachIndexed

            // App icon background
            val isSelected = index == selectedAppIndex
            val bgColor = if (isSelected) Color(80, 120, 200, 100) else Color(50, 50, 60, 120)
            val iconSize = if (isSelected) appIconSize * 1.1f else appIconSize

            canvas.drawRect(
                x - iconSize / 2f, y - iconSize / 2f,
                iconSize, iconSize,
                bgColor
            )

            // App icon (using emoji for now)
            canvas.drawText(
                app.icon,
                x - 20f, y + 10f,
                Color.WHITE,
                if (isSelected) 36f else 32f
            )

            // App name
            val textY = y + iconSize / 2f + 20f
            canvas.drawText(
                app.name,
                x - app.name.length * 4f,
                textY,
                Color.WHITE,
                if (isSelected) 14f else 12f
            )

            // Selection indicator
            if (isSelected) {
                canvas.drawCircle(x, y - iconSize / 2f - 15f, 4f, Color.WHITE)
            }
        }
    }

    private fun drawDock(canvas: Canvas) {
        val dockHeight = 100f
        val dockY = canvas.height - dockHeight - 20f
        val dockApps = listOf("📱", "💬", "🌐", "📧")

        // Dock background
        canvas.drawRect(
            20f, dockY, canvas.width - 40f, dockHeight,
            Color(30, 30, 35, 200)
        )

        // Dock apps
        val appSpacing = (canvas.width - 80f) / dockApps.size
        dockApps.forEachIndexed { index, icon ->
            val x = 40f + index * appSpacing + appSpacing / 2f
            val y = dockY + dockHeight / 2f

            canvas.drawCircle(x, y, 30f, Color(70, 70, 80))
            canvas.drawText(icon, x - 15f, y + 5f, Color.WHITE, 24f)
        }
    }

    private fun drawPageIndicators(canvas: Canvas) {
        val totalPages = 3 // Assuming 3 pages for demo
        val currentPage = 0
        val indicatorSize = 8f
        val indicatorSpacing = 20f
        val totalWidth = totalPages * indicatorSpacing
        val startX = (canvas.width - totalWidth) / 2f + indicatorSpacing / 2f
        val y = canvas.height - 40f

        repeat(totalPages) { index ->
            val x = startX + index * indicatorSpacing
            val color = if (index == currentPage) Color.WHITE else Color.GRAY
            canvas.drawCircle(x, y, indicatorSize / 2f, color)
        }
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
        // Handle search bar touch
        if (y >= 100f && y <= 150f) {
            showingSearch = !showingSearch
            return true
        }

        // Handle app grid touches
        val appsStartY = if (showingSearch) 180f else 120f
        if (y >= appsStartY) {
            val gridStartX = (canvas.width - maxAppsPerRow * appIconSpacing) / 2f + appIconSpacing / 2f
            val row = ((y - appsStartY - scrollOffset) / appIconSpacing).toInt()
            val col = ((x - gridStartX + appIconSpacing / 2f) / appIconSpacing).toInt()

            if (row >= 0 && col >= 0 && col < maxAppsPerRow) {
                val appIndex = row * maxAppsPerRow + col
                if (appIndex < sampleApps.size) {
                    selectedAppIndex = appIndex
                    return true
                }
            }
        }

        return true
    }

    private suspend fun handleTouchUp(x: Float, y: Float): Boolean {
        // Launch selected app on touch up
        val appsStartY = if (showingSearch) 180f else 120f
        if (y >= appsStartY) {
            val gridStartX = (canvas.width - maxAppsPerRow * appIconSpacing) / 2f + appIconSpacing / 2f
            val row = ((y - appsStartY - scrollOffset) / appIconSpacing).toInt()
            val col = ((x - gridStartX + appIconSpacing / 2f) / appIconSpacing).toInt()

            if (row >= 0 && col >= 0 && col < maxAppsPerRow) {
                val appIndex = row * maxAppsPerRow + col
                if (appIndex < sampleApps.size && appIndex == selectedAppIndex) {
                    val app = sampleApps[appIndex]
                    println("Launching app: ${app.name}")
                    // Here we would actually launch the app
                    // For now, just simulate by showing a message
                    return true
                }
            }
        }

        return true
    }

    override suspend fun onKey(keyCode: Int, action: KeyAction): Boolean {
        if (action == KeyAction.DOWN) {
            when (keyCode) {
                // Arrow keys for navigation
                37 -> { // Left arrow
                    if (selectedAppIndex % maxAppsPerRow > 0) {
                        selectedAppIndex--
                    }
                    return true
                }
                39 -> { // Right arrow
                    if (selectedAppIndex % maxAppsPerRow < maxAppsPerRow - 1 && selectedAppIndex < sampleApps.size - 1) {
                        selectedAppIndex++
                    }
                    return true
                }
                38 -> { // Up arrow
                    if (selectedAppIndex >= maxAppsPerRow) {
                        selectedAppIndex -= maxAppsPerRow
                    }
                    return true
                }
                40 -> { // Down arrow
                    if (selectedAppIndex + maxAppsPerRow < sampleApps.size) {
                        selectedAppIndex += maxAppsPerRow
                    }
                    return true
                }
                13 -> { // Enter key
                    val app = sampleApps[selectedAppIndex]
                    println("Launching app: ${app.name}")
                    return true
                }
                27 -> { // Escape key - toggle search
                    showingSearch = !showingSearch
                    if (!showingSearch) {
                        searchQuery = ""
                    }
                    return true
                }
            }
        }
        return false
    }

    override suspend fun onBackPressed(): Boolean {
        if (showingSearch) {
            showingSearch = false
            searchQuery = ""
            return true
        }
        return false // Don't handle back press - stay on launcher
    }
}
