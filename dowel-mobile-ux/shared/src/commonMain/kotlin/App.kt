@file:OptIn(ExperimentalMaterial3Api::class, ExperimentalAnimationApi::class)

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.*
import androidx.compose.foundation.interaction.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.foundation.shape.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.draw.*
import androidx.compose.ui.geometry.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.graphics.vector.*
import androidx.compose.ui.input.pointer.*
import androidx.compose.ui.layout.*
import androidx.compose.ui.platform.*
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.*
import androidx.compose.ui.text.style.*
import androidx.compose.ui.unit.*
import kotlinx.coroutines.*
import kotlinx.datetime.*
import kotlin.math.*

// Main App Composable
@Composable
fun App() {
    var currentTime by remember { mutableStateOf(Clock.System.now()) }

    LaunchedEffect(Unit) {
        while (true) {
            currentTime = Clock.System.now()
            delay(1000)
        }
    }

    DowelTheme {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background
        ) {
            LauncherScreen(currentTime = currentTime)
        }
    }
}

// Stunning Launcher Screen
@Composable
fun LauncherScreen(currentTime: Instant) {
    var searchExpanded by remember { mutableStateOf(false) }
    var selectedApp by remember { mutableStateOf<AppInfo?>(null) }

    val apps = remember { getDemoApps() }
    val favoriteApps = remember { apps.filter { it.isFavorite } }

    AnimatedContent(
        targetState = selectedApp,
        transitionSpec = {
            slideInVertically(
                initialOffsetY = { it },
                animationSpec = spring(dampingRatio = 0.8f, stiffness = 400f)
            ) with slideOutVertically(
                targetOffsetY = { -it },
                animationSpec = spring(dampingRatio = 0.8f, stiffness = 400f)
            )
        }
    ) { app ->
        if (app == null) {
            LauncherContent(
                currentTime = currentTime,
                apps = apps,
                favoriteApps = favoriteApps,
                searchExpanded = searchExpanded,
                onSearchToggle = { searchExpanded = !searchExpanded },
                onAppClick = { selectedApp = it }
            )
        } else {
            AppScreen(
                app = app,
                onBack = { selectedApp = null }
            )
        }
    }
}

@Composable
fun LauncherContent(
    currentTime: Instant,
    apps: List<AppInfo>,
    favoriteApps: List<AppInfo>,
    searchExpanded: Boolean,
    onSearchToggle: () -> Unit,
    onAppClick: (AppInfo) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.radialGradient(
                    colors = listOf(
                        Color(0xFF1a1a2e),
                        Color(0xFF16213e),
                        Color(0xFF0f0f23)
                    ),
                    radius = 1200f,
                    center = Offset(0.3f, 0.2f)
                )
            )
    ) {
        // Animated background particles
        AnimatedBackgroundParticles()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // Status Bar
            StatusBar(currentTime = currentTime)

            Spacer(modifier = Modifier.height(32.dp))

            // Search Bar
            AnimatedSearchBar(
                expanded = searchExpanded,
                onToggle = onSearchToggle,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Quick Widgets
            QuickWidgetsRow(
                currentTime = currentTime,
                modifier = Modifier.padding(horizontal = 20.dp)
            )

            Spacer(modifier = Modifier.height(40.dp))

            // App Grid
            LazyVerticalGrid(
                columns = GridCells.Fixed(4),
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                items(apps) { app ->
                    AppIcon(
                        app = app,
                        onClick = { onAppClick(app) }
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Dock
            DockArea(
                apps = favoriteApps,
                onAppClick = onAppClick,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .navigationBarsPadding()
            )

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

@Composable
fun StatusBar(currentTime: Instant) {
    val time = remember(currentTime) {
        val localTime = currentTime.toLocalDateTime(TimeZone.currentSystemDefault())
        "${localTime.hour.toString().padStart(2, '0')}:${localTime.minute.toString().padStart(2, '0')}"
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = time,
            style = MaterialTheme.typography.headlineSmall.copy(
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        )

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                Icons.Default.Wifi,
                contentDescription = "WiFi",
                tint = Color.White,
                modifier = Modifier.size(20.dp)
            )
            Icon(
                Icons.Default.SignalCellular4Bar,
                contentDescription = "Cellular",
                tint = Color.White,
                modifier = Modifier.size(18.dp)
            )
            BatteryIndicator(level = 85)
        }
    }
}

@Composable
fun BatteryIndicator(level: Int) {
    Box(
        modifier = Modifier.size(24.dp, 12.dp)
    ) {
        // Battery outline
        Canvas(modifier = Modifier.fillMaxSize()) {
            val batteryWidth = size.width * 0.8f
            val batteryHeight = size.height

            // Battery body
            drawRoundRect(
                color = Color.White,
                size = Size(batteryWidth, batteryHeight),
                style = Stroke(width = 1.5.dp.toPx()),
                cornerRadius = CornerRadius(2.dp.toPx())
            )

            // Battery tip
            drawRoundRect(
                color = Color.White,
                topLeft = Offset(batteryWidth, batteryHeight * 0.3f),
                size = Size(size.width * 0.2f, batteryHeight * 0.4f),
                cornerRadius = CornerRadius(1.dp.toPx())
            )

            // Battery fill
            val fillWidth = (batteryWidth - 4.dp.toPx()) * (level / 100f)
            drawRoundRect(
                color = when {
                    level > 20 -> Color.White
                    else -> Color.Red
                },
                topLeft = Offset(2.dp.toPx(), 2.dp.toPx()),
                size = Size(fillWidth, batteryHeight - 4.dp.toPx()),
                cornerRadius = CornerRadius(1.dp.toPx())
            )
        }
    }
}

@Composable
fun AnimatedSearchBar(
    expanded: Boolean,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier
) {
    val animatedWidth by animateFloatAsState(
        targetValue = if (expanded) 1f else 0.8f,
        animationSpec = spring(dampingRatio = 0.8f)
    )

    Card(
        modifier = modifier
            .fillMaxWidth(animatedWidth)
            .height(56.dp)
            .clickable { onToggle() },
        shape = RoundedCornerShape(28.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.1f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                Icons.Default.Search,
                contentDescription = "Search",
                tint = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.size(24.dp)
            )

            Text(
                text = "Search apps, files, and more...",
                style = MaterialTheme.typography.bodyLarge,
                color = Color.White.copy(alpha = 0.7f)
            )
        }
    }
}

@Composable
fun QuickWidgetsRow(
    currentTime: Instant,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(horizontal = 4.dp)
    ) {
        item {
            WeatherWidget()
        }
        item {
            CalendarWidget(currentTime)
        }
        item {
            BatteryWidget()
        }
    }
}

@Composable
fun WeatherWidget() {
    Card(
        modifier = Modifier.size(120.dp, 80.dp),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color(0xFF4A90E2).copy(alpha = 0.8f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()
            ) {
                Icon(
                    Icons.Default.WbSunny,
                    contentDescription = "Weather",
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = "22°",
                    style = MaterialTheme.typography.titleMedium,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
            }
            Text(
                text = "Sunny",
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.9f)
            )
        }
    }
}

@Composable
fun CalendarWidget(currentTime: Instant) {
    val localTime = currentTime.toLocalDateTime(TimeZone.currentSystemDefault())
    val dayName = when (localTime.dayOfWeek) {
        DayOfWeek.MONDAY -> "Mon"
        DayOfWeek.TUESDAY -> "Tue"
        DayOfWeek.WEDNESDAY -> "Wed"
        DayOfWeek.THURSDAY -> "Thu"
        DayOfWeek.FRIDAY -> "Fri"
        DayOfWeek.SATURDAY -> "Sat"
        DayOfWeek.SUNDAY -> "Sun"
        else -> "Day"
    }

    Card(
        modifier = Modifier.size(120.dp, 80.dp),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color(0xFF50C878).copy(alpha = 0.8f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            verticalArrangement = Arrangement.SpaceBetween,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = dayName,
                style = MaterialTheme.typography.bodySmall,
                color = Color.White.copy(alpha = 0.9f)
            )
            Text(
                text = localTime.dayOfMonth.toString(),
                style = MaterialTheme.typography.headlineMedium,
                color = Color.White,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
fun BatteryWidget() {
    Card(
        modifier = Modifier.size(120.dp, 80.dp),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color(0xFFFF6B6B).copy(alpha = 0.8f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            verticalArrangement = Arrangement.SpaceBetween,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                Icons.Default.Battery6Bar,
                contentDescription = "Battery",
                tint = Color.White,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = "85%",
                style = MaterialTheme.typography.titleMedium,
                color = Color.White,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
fun AppIcon(
    app: AppInfo,
    onClick: () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.85f else 1f,
        animationSpec = spring(dampingRatio = 0.6f, stiffness = 400f)
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .scale(scale)
            .clickable(
                indication = null,
                interactionSource = interactionSource
            ) {
                onClick()
            }
    ) {
        Card(
            modifier = Modifier.size(64.dp),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = app.primaryColor.copy(alpha = 0.9f)
            ),
            elevation = CardDefaults.cardElevation(defaultElevation = 12.dp)
        ) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = app.icon,
                    contentDescription = app.name,
                    modifier = Modifier.size(32.dp),
                    tint = Color.White
                )
            }
        }

        Text(
            text = app.name,
            style = MaterialTheme.typography.bodySmall,
            color = Color.White,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
fun DockArea(
    apps: List<AppInfo>,
    onAppClick: (AppInfo) -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .height(72.dp),
        shape = RoundedCornerShape(36.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.1f)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 16.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            apps.forEach { app ->
                Card(
                    modifier = Modifier
                        .size(48.dp)
                        .clickable { onAppClick(app) },
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(
                        containerColor = app.primaryColor.copy(alpha = 0.8f)
                    ),
                    elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
                ) {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = app.icon,
                            contentDescription = app.name,
                            modifier = Modifier.size(24.dp),
                            tint = Color.White
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun AnimatedBackgroundParticles() {
    val infiniteTransition = rememberInfiniteTransition()

    // Create multiple floating particles
    repeat(5) { index ->
        val offsetX by infiniteTransition.animateFloat(
            initialValue = (index * 100).toFloat(),
            targetValue = (index * 100 + 50).toFloat(),
            animationSpec = infiniteRepeatable(
                animation = tween(3000 + index * 500, easing = LinearEasing),
                repeatMode = RepeatMode.Reverse
            )
        )

        val offsetY by infiniteTransition.animateFloat(
            initialValue = (index * 150).toFloat(),
            targetValue = (index * 150 + 30).toFloat(),
            animationSpec = infiniteRepeatable(
                animation = tween(4000 + index * 300, easing = LinearEasing),
                repeatMode = RepeatMode.Reverse
            )
        )

        val alpha by infiniteTransition.animateFloat(
            initialValue = 0.1f,
            targetValue = 0.3f,
            animationSpec = infiniteRepeatable(
                animation = tween(2000 + index * 400, easing = LinearEasing),
                repeatMode = RepeatMode.Reverse
            )
        )

        Canvas(
            modifier = Modifier.fillMaxSize()
        ) {
            drawCircle(
                color = Color.White.copy(alpha = alpha),
                radius = 20f + index * 10f,
                center = Offset(offsetX, offsetY)
            )
        }
    }
}

@Composable
fun AppScreen(
    app: AppInfo,
    onBack: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(app.primaryColor)
            .statusBarsPadding()
    ) {
        // App Bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.Default.ArrowBack,
                    contentDescription = "Back",
                    tint = Color.White
                )
            }

            Spacer(modifier = Modifier.width(16.dp))

            Text(
                text = app.name,
                style = MaterialTheme.typography.headlineSmall,
                color = Color.White,
                fontWeight = FontWeight.Bold
            )
        }

        // App Content
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(24.dp)
            ) {
                Icon(
                    imageVector = app.icon,
                    contentDescription = app.name,
                    modifier = Modifier.size(120.dp),
                    tint = Color.White.copy(alpha = 0.7f)
                )

                Text(
                    text = "${app.name} App",
                    style = MaterialTheme.typography.headlineMedium,
                    color = Color.White,
                    textAlign = TextAlign.Center
                )

                Text(
                    text = "This is where the ${app.name} application would run.\nFull implementation coming soon!",
                    style = MaterialTheme.typography.bodyLarge,
                    color = Color.White.copy(alpha = 0.8f),
                    textAlign = TextAlign.Center
                )

                Button(
                    onClick = onBack,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White.copy(alpha = 0.2f)
                    )
                ) {
                    Text(
                        text = "Go Back",
                        color = Color.White
                    )
                }
            }
        }
    }
}

// Data classes
data class AppInfo(
    val name: String,
    val icon: ImageVector,
    val primaryColor: Color,
    val isFavorite: Boolean = false
)

// Demo data
fun getDemoApps() = listOf(
    AppInfo("Files", Icons.Default.Folder, Color(0xFF4CAF50), true),
    AppInfo("Settings", Icons.Default.Settings, Color(0xFF607D8B), true),
    AppInfo("ChatGPT", Icons.Default.Chat, Color(0xFF00BCD4)),
    AppInfo("Notes", Icons.Default.Note, Color(0xFFFFC107)),
    AppInfo("Terminal", Icons.Default.Terminal, Color(0xFF212121), true),
    AppInfo("Camera", Icons.Default.PhotoCamera, Color(0xFFE91E63)),
    AppInfo("Gallery", Icons.Default.Photo, Color(0xFF9C27B0)),
    AppInfo("Music", Icons.Default.MusicNote, Color(0xFFFF5722)),
    AppInfo("Maps", Icons.Default.Map, Color(0xFF4CAF50)),
    AppInfo("Weather", Icons.Default.WbSunny, Color(0xFF2196F3)),
    AppInfo("Calendar", Icons.Default.CalendarMonth, Color(0xFFFF9800)),
    AppInfo("Calculator", Icons.Default.Calculate, Color(0xFF795548)),
)

// Theme
@Composable
fun DowelTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Color(0xFF4A90E2),
            secondary = Color(0xFF50C878),
            background = Color(0xFF0f0f23),
            surface = Color(0xFF1a1a2e),
            onPrimary = Color.White,
            onSecondary = Color.White,
            onBackground = Color.White,
            onSurface = Color.White
        ),
        content = content
    )
}
