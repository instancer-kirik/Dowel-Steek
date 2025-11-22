package com.dowelsteek.app

import kotlinx.coroutines.*
import kotlinx.serialization.Serializable

/**
 * App Framework for Dowel-Steek Mobile OS
 *
 * Provides the base infrastructure for all applications running on the OS.
 * Apps are managed by the OS runtime and have access to system services.
 */

@Serializable
data class AppManifest(
    val id: String,
    val name: String,
    val version: String,
    val description: String,
    val author: String,
    val permissions: List<String> = emptyList(),
    val mainClass: String,
    val icon: String? = null,
    val category: AppCategory = AppCategory.UTILITY,
    val minOSVersion: String = "0.1.0"
)

enum class AppCategory {
    SYSTEM,
    PRODUCTIVITY,
    ENTERTAINMENT,
    COMMUNICATION,
    UTILITY,
    DEVELOPMENT,
    GAMES,
    MEDIA
}

sealed class AppState {
    object Starting : AppState()
    object Running : AppState()
    object Paused : AppState()
    object Stopped : AppState()
    data class Error(val exception: Throwable) : AppState()
}

abstract class App {
    abstract val manifest: AppManifest

    private val _state = kotlinx.coroutines.flow.MutableStateFlow<AppState>(AppState.Stopped)
    val state = _state.asStateFlow()

    protected val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    /**
     * Called when the app is created
     */
    open suspend fun onCreate() {}

    /**
     * Called when the app becomes visible
     */
    open suspend fun onStart() {}

    /**
     * Called when the app goes into the background
     */
    open suspend fun onPause() {}

    /**
     * Called when the app is brought back to foreground
     */
    open suspend fun onResume() {}

    /**
     * Called when the app is being destroyed
     */
    open suspend fun onDestroy() {}

    /**
     * Handle back button/gesture
     */
    open suspend fun onBackPressed(): Boolean = false

    /**
     * Handle touch input
     */
    open suspend fun onTouch(x: Float, y: Float, action: TouchAction): Boolean = false

    /**
     * Handle key input
     */
    open suspend fun onKey(keyCode: Int, action: KeyAction): Boolean = false

    /**
     * Main render method - called every frame
     */
    abstract suspend fun onRender(canvas: Canvas)

    /**
     * Update app logic - called at fixed intervals
     */
    open suspend fun onUpdate(deltaTime: Float) {}

    internal fun setState(newState: AppState) {
        _state.value = newState
    }

    internal suspend fun performLifecycle(event: LifecycleEvent) {
        try {
            setState(AppState.Starting)
            when (event) {
                LifecycleEvent.CREATE -> onCreate()
                LifecycleEvent.START -> {
                    onStart()
                    setState(AppState.Running)
                }
                LifecycleEvent.PAUSE -> {
                    onPause()
                    setState(AppState.Paused)
                }
                LifecycleEvent.RESUME -> {
                    onResume()
                    setState(AppState.Running)
                }
                LifecycleEvent.DESTROY -> {
                    onDestroy()
                    setState(AppState.Stopped)
                    scope.cancel()
                }
            }
        } catch (e: Exception) {
            setState(AppState.Error(e))
            throw e
        }
    }
}

enum class LifecycleEvent {
    CREATE, START, PAUSE, RESUME, DESTROY
}

enum class TouchAction {
    DOWN, MOVE, UP, CANCEL
}

enum class KeyAction {
    DOWN, UP
}

/**
 * Simple canvas abstraction for rendering
 * This will be implemented by the display system
 */
interface Canvas {
    val width: Int
    val height: Int

    fun clear(color: Color)
    fun drawRect(x: Float, y: Float, width: Float, height: Float, color: Color)
    fun drawCircle(x: Float, y: Float, radius: Float, color: Color)
    fun drawText(text: String, x: Float, y: Float, color: Color, size: Float = 16f)
    fun drawLine(x1: Float, y1: Float, x2: Float, y2: Float, color: Color, width: Float = 1f)
}

@Serializable
data class Color(
    val r: Int,
    val g: Int,
    val b: Int,
    val a: Int = 255
) {
    companion object {
        val BLACK = Color(0, 0, 0)
        val WHITE = Color(255, 255, 255)
        val RED = Color(255, 0, 0)
        val GREEN = Color(0, 255, 0)
        val BLUE = Color(0, 0, 255)
        val YELLOW = Color(255, 255, 0)
        val CYAN = Color(0, 255, 255)
        val MAGENTA = Color(255, 0, 255)
        val GRAY = Color(128, 128, 128)
        val TRANSPARENT = Color(0, 0, 0, 0)
    }
}

/**
 * App Manager - handles app lifecycle and execution
 */
class AppManager {
    private val apps = mutableMapOf<String, App>()
    private var currentApp: App? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    suspend fun installApp(app: App): Result<Unit> {
        return try {
            apps[app.manifest.id] = app
            app.performLifecycle(LifecycleEvent.CREATE)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun launchApp(appId: String): Result<Unit> {
        val app = apps[appId] ?: return Result.failure(AppNotFoundException(appId))

        return try {
            // Pause current app
            currentApp?.performLifecycle(LifecycleEvent.PAUSE)

            // Start new app
            currentApp = app
            app.performLifecycle(LifecycleEvent.START)

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun pauseCurrentApp() {
        currentApp?.performLifecycle(LifecycleEvent.PAUSE)
    }

    suspend fun resumeCurrentApp() {
        currentApp?.performLifecycle(LifecycleEvent.RESUME)
    }

    suspend fun closeApp(appId: String): Result<Unit> {
        val app = apps[appId] ?: return Result.failure(AppNotFoundException(appId))

        return try {
            if (currentApp == app) {
                currentApp = null
            }
            app.performLifecycle(LifecycleEvent.DESTROY)
            apps.remove(appId)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun getInstalledApps(): List<AppManifest> {
        return apps.values.map { it.manifest }
    }

    fun getCurrentApp(): App? = currentApp

    suspend fun handleTouch(x: Float, y: Float, action: TouchAction): Boolean {
        return currentApp?.onTouch(x, y, action) ?: false
    }

    suspend fun handleKey(keyCode: Int, action: KeyAction): Boolean {
        return currentApp?.onKey(keyCode, action) ?: false
    }

    suspend fun handleBackPressed(): Boolean {
        return currentApp?.onBackPressed() ?: false
    }

    suspend fun renderCurrentApp(canvas: Canvas) {
        currentApp?.onRender(canvas)
    }

    suspend fun updateCurrentApp(deltaTime: Float) {
        currentApp?.onUpdate(deltaTime)
    }

    fun shutdown() {
        scope.cancel()
        // Close all apps
        scope.launch {
            apps.keys.toList().forEach { appId ->
                closeApp(appId)
            }
        }
    }
}

class AppNotFoundException(appId: String) : Exception("App not found: $appId")
class AppPermissionException(permission: String) : Exception("App missing permission: $permission")
