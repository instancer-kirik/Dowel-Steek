package com.dowelsteek.desktop

import androidx.compose.desktop.ui.tooling.preview.Preview
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
fun main() = application {
    val windowState = rememberWindowState(width = 1400.dp, height = 900.dp)

    Window(
        onCloseRequest = ::exitApplication,
        title = "Dowel-Steek Desktop - Beautiful Compose App",
        state = windowState
    ) {
        MaterialTheme(
            colorScheme = darkColorScheme(
                primary = Color(0xFF6C5CE7),
                secondary = Color(0xFF00CEC9),
                tertiary = Color(0xFFFD79A8),
                surface = Color(0xFF2D3748),
                background = Color(0xFF1A202C),
                onSurface = Color.White,
                onBackground = Color.White,
                surfaceVariant = Color(0xFF4A5568)
            )
        ) {
            DowelSteekSimpleApp()
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DowelSteekSimpleApp() {
    var selectedTab by remember { mutableStateOf(0) }
    var systemStatus by remember { mutableStateOf("Initializing...") }
    var isSystemRunning by remember { mutableStateOf(false) }
    var cpuUsage by remember { mutableStateOf(23) }
    var memoryUsage by remember { mutableStateOf(45) }
    var networkActivity by remember { mutableStateOf(67) }

    // Simulate system startup and real-time updates
    LaunchedEffect(Unit) {
        delay(2000)
        systemStatus = "System Online"
        isSystemRunning = true

        // Start simulated real-time updates
        while (true) {
            delay(1000)
            cpuUsage = (15..85).random()
            memoryUsage = (30..70).random()
            networkActivity = (10..90).random()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(
                brush = Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF1A202C),
                        Color(0xFF2D3748)
                    )
                )
            )
    ) {
        // Top App Bar
        TopAppBar(
            title = {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Icon(
                        Icons.Default.Smartphone,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(28.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            "Dowel-Steek Desktop",
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                        Text(
                            "Beautiful Compose Desktop App",
                            fontSize = 12.sp,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                    Spacer(modifier = Modifier.weight(1f))

                    // System Status Indicator
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = if (isSystemRunning)
                                Color(0xFF10B981) else Color(0xFFF59E0B)
                        ),
                        shape = RoundedCornerShape(20.dp),
                        modifier = Modifier.height(32.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(Color.White)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                systemStatus,
                                fontSize = 12.sp,
                                color = Color.White,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Transparent
            )
        )

        // Tab Row
        TabRow(
            selectedTabIndex = selectedTab,
            containerColor = Color.Transparent,
            contentColor = MaterialTheme.colorScheme.primary
        ) {
            val tabs = listOf(
                "Dashboard" to Icons.Default.Dashboard,
                "System Monitor" to Icons.Default.Monitor,
                "Performance" to Icons.Default.Speed,
                "Mobile OS" to Icons.Default.PhoneAndroid
            )

            tabs.forEachIndexed { index, (title, icon) ->
                Tab(
                    selected = selectedTab == index,
                    onClick = { selectedTab = index },
                    modifier = Modifier.height(60.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            icon,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                            tint = if (selectedTab == index)
                                MaterialTheme.colorScheme.primary
                            else Color.White.copy(alpha = 0.6f)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            title,
                            color = if (selectedTab == index)
                                MaterialTheme.colorScheme.primary
                            else Color.White.copy(alpha = 0.6f),
                            fontWeight = if (selectedTab == index)
                                FontWeight.Bold else FontWeight.Normal
                        )
                    }
                }
            }
        }

        // Content Area
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp)
        ) {
            when (selectedTab) {
                0 -> DashboardScreen(cpuUsage, memoryUsage, networkActivity)
                1 -> SystemMonitorScreen(cpuUsage, memoryUsage, networkActivity)
                2 -> PerformanceScreen()
                3 -> MobileOSScreen()
            }
        }
    }
}

@Composable
fun DashboardScreen(cpuUsage: Int, memoryUsage: Int, networkActivity: Int) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "System Dashboard",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        // Stats Cards Row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            StatsCard(
                title = "CPU Usage",
                value = "$cpuUsage%",
                icon = Icons.Default.Memory,
                color = Color(0xFF6C5CE7),
                modifier = Modifier.weight(1f)
            )
            StatsCard(
                title = "Memory",
                value = "${memoryUsage}%",
                icon = Icons.Default.Storage,
                color = Color(0xFF00CEC9),
                modifier = Modifier.weight(1f)
            )
            StatsCard(
                title = "Network I/O",
                value = "${networkActivity}KB/s",
                icon = Icons.Default.NetworkCheck,
                color = Color(0xFFFD79A8),
                modifier = Modifier.weight(1f)
            )
            StatsCard(
                title = "Services",
                value = "8 Active",
                icon = Icons.Default.Apps,
                color = Color(0xFF00B894),
                modifier = Modifier.weight(1f)
            )
        }

        // Feature Showcase
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface
            ),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(
                modifier = Modifier.padding(24.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        Icons.Default.Star,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        "Compose Desktop Features",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))

                val features = listOf(
                    "🎨 Material 3 Design System",
                    "🚀 Native Performance",
                    "⚡ Real-time Updates",
                    "🌓 Dark Theme Optimized",
                    "📱 Mobile OS Ready",
                    "🔧 No Android Studio Required"
                )

                features.forEach { feature ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            feature,
                            color = Color.White.copy(alpha = 0.9f),
                            fontSize = 14.sp
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun SystemMonitorScreen(cpuUsage: Int, memoryUsage: Int, networkActivity: Int) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "System Monitor",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        // Real-time Metrics
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            MetricCard(
                title = "CPU Usage",
                value = "$cpuUsage%",
                progress = cpuUsage / 100f,
                color = Color(0xFF6C5CE7),
                modifier = Modifier.weight(1f)
            )
            MetricCard(
                title = "Memory Usage",
                value = "$memoryUsage%",
                progress = memoryUsage / 100f,
                color = Color(0xFF00CEC9),
                modifier = Modifier.weight(1f)
            )
            MetricCard(
                title = "Network I/O",
                value = "${networkActivity}KB/s",
                progress = networkActivity / 100f,
                color = Color(0xFFFD79A8),
                modifier = Modifier.weight(1f)
            )
        }

        Text(
            "📊 Metrics update automatically every second",
            color = Color.White.copy(alpha = 0.7f),
            fontSize = 14.sp
        )
    }
}

@Composable
fun PerformanceScreen() {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "Performance Analytics",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface
            ),
            shape = RoundedCornerShape(16.dp)
        ) {
            Column(
                modifier = Modifier.padding(24.dp)
            ) {
                Text(
                    "Kotlin/Native Integration",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )

                Spacer(modifier = Modifier.height(16.dp))

                val metrics = listOf(
                    "Function calls per second" to "10M+",
                    "Memory allocation" to "Native",
                    "Startup time" to "< 100ms",
                    "UI Framework" to "Compose Desktop",
                    "Backend Integration" to "JNA + C Wrapper"
                )

                metrics.forEach { (metric, value) ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            metric,
                            color = Color.White.copy(alpha = 0.8f),
                            fontSize = 14.sp
                        )
                        Text(
                            value,
                            color = MaterialTheme.colorScheme.primary,
                            fontWeight = FontWeight.Bold,
                            fontSize = 14.sp
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun MobileOSScreen() {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            "Mobile OS Simulation",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        val services = listOf(
            "Display Manager" to Icons.Default.Monitor,
            "Input Handler" to Icons.Default.TouchApp,
            "Audio System" to Icons.Default.VolumeUp,
            "Network Stack" to Icons.Default.Wifi,
            "Power Manager" to Icons.Default.Battery6Bar,
            "Storage Manager" to Icons.Default.Storage,
            "Security Module" to Icons.Default.Security,
            "UI Framework" to Icons.Default.Palette
        )

        Column(
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            for (i in services.indices step 2) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    val (service1, icon1) = services[i]
                    ServiceCard(
                        name = service1,
                        icon = icon1,
                        isRunning = true,
                        modifier = Modifier.weight(1f)
                    )

                    if (i + 1 < services.size) {
                        val (service2, icon2) = services[i + 1]
                        ServiceCard(
                            name = service2,
                            icon = icon2,
                            isRunning = true,
                            modifier = Modifier.weight(1f)
                        )
                    } else {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
fun StatsCard(
    title: String,
    value: String,
    icon: ImageVector,
    color: Color,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier.padding(20.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(RoundedCornerShape(10.dp))
                        .background(color.copy(alpha = 0.2f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        icon,
                        contentDescription = null,
                        tint = color,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                value,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Text(
                title,
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.6f)
            )
        }
    }
}

@Composable
fun MetricCard(
    title: String,
    value: String,
    progress: Float,
    color: Color,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier.padding(20.dp)
        ) {
            Text(
                title,
                fontSize = 14.sp,
                color = Color.White.copy(alpha = 0.6f)
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                value,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Spacer(modifier = Modifier.height(16.dp))

            LinearProgressIndicator(
                progress = progress.coerceIn(0f, 1f),
                color = color,
                trackColor = color.copy(alpha = 0.2f),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp))
            )
        }
    }
}

@Composable
fun ServiceCard(
    name: String,
    icon: ImageVector,
    isRunning: Boolean,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(
                        if (isRunning)
                            Color(0xFF10B981).copy(alpha = 0.2f)
                        else Color(0xFF6B7280).copy(alpha = 0.2f)
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    icon,
                    contentDescription = null,
                    tint = if (isRunning) Color(0xFF10B981) else Color(0xFF6B7280),
                    modifier = Modifier.size(24.dp)
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                name,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White,
                maxLines = 2
            )

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                if (isRunning) "Running" else "Stopped",
                fontSize = 12.sp,
                color = if (isRunning) Color(0xFF10B981) else Color(0xFF6B7280)
            )
        }
    }
}

@Preview
@Composable
fun AppPreview() {
    MaterialTheme {
        DowelSteekSimpleApp()
    }
}
