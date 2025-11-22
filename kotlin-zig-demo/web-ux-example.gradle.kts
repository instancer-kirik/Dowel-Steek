plugins {
    kotlin("multiplatform") version "1.9.20"
    kotlin("plugin.serialization") version "1.9.20"
}

group = "com.dowelsteek"
version = "1.0.0"

repositories {
    mavenCentral()
}

kotlin {
    js(IR) {
        binaries.executable()
        browser {
            commonWebpackConfig {
                cssSupport {
                    enabled.set(true)
                }
            }
            webpackTask {
                outputFileName = "dowel-steek-web.js"
            }
            runTask {
                outputFileName = "dowel-steek-web.js"
            }
            testTask {
                useKarma {
                    useChromeHeadless()
                    webpackConfig.cssSupport {
                        enabled.set(true)
                    }
                }
            }
        }
        nodejs {
            testTask {
                useMocha {
                    timeout = "5000"
                }
            }
        }
    }

    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")
                implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.4.1")
            }
        }

        val jsMain by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-html:0.9.1")
                implementation("org.jetbrains.kotlin-wrappers:kotlin-react:18.2.0-pre.467")
                implementation("org.jetbrains.kotlin-wrappers:kotlin-react-dom:18.2.0-pre.467")
                implementation("org.jetbrains.kotlin-wrappers:kotlin-styled:5.3.6-pre.467")
                implementation("org.jetbrains.kotlin-wrappers:kotlin-css:1.0.0-pre.467")

                // For making HTTP requests to native backend
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core-js:1.7.3")
            }
        }

        val jsTest by getting {
            dependencies {
                implementation(kotlin("test-js"))
                implementation("org.jetbrains.kotlin-wrappers:kotlin-react-test-utils:18.2.0-pre.467")
            }
        }
    }
}

// Task to build native backend server
tasks.register<Exec>("buildNativeBackend") {
    description = "Build the native Kotlin backend server"
    workingDir = projectDir
    commandLine(
        "${System.getProperty("user.home")}/.local/opt/kotlin-native/bin/kotlinc-native",
        "-l", "c_wrapper",
        "-o", "backend-server",
        "backend_server.kt"
    )
}

// Task to start native backend
tasks.register<Exec>("startBackend") {
    description = "Start the native Kotlin backend server"
    dependsOn("buildNativeBackend")
    workingDir = projectDir
    commandLine("./backend-server.kexe")

    // Run in background
    isIgnoreExitValue = true

    doFirst {
        println("Starting Kotlin/Native backend server...")
    }
}

// Custom task to serve the web app with backend
tasks.register("serveWithBackend") {
    description = "Build and serve the web app with native backend"
    dependsOn("startBackend", "jsBrowserDevelopmentRun")

    doFirst {
        println("🚀 Starting full-stack Kotlin application:")
        println("   • Backend: Kotlin/Native + Zig")
        println("   • Frontend: Kotlin/JS + React")
        println("   • Integration: WebSocket + REST API")
    }
}

// Build distribution
tasks.register("buildWebDist") {
    description = "Build complete web distribution"
    dependsOn("jsBrowserDistribution", "buildNativeBackend")

    doLast {
        println("✅ Web distribution built:")
        println("   • Frontend: build/distributions/")
        println("   • Backend: backend-server.kexe")
        println("   • Deploy: Copy both to your server")
    }
}

// Development helper
tasks.register("devSetup") {
    description = "Set up development environment"

    doLast {
        println("🛠️ Development Setup Instructions:")
        println()
        println("1. Start backend server:")
        println("   ./gradlew startBackend")
        println()
        println("2. Start frontend dev server (in another terminal):")
        println("   ./gradlew jsBrowserDevelopmentRun")
        println()
        println("3. Or start both together:")
        println("   ./gradlew serveWithBackend")
        println()
        println("4. Build for production:")
        println("   ./gradlew buildWebDist")
        println()
        println("📱 Features Available:")
        println("   • Real-time mobile OS dashboard")
        println("   • System monitoring widgets")
        println("   • Performance analytics")
        println("   • Native backend integration")
        println("   • Responsive design")
        println("   • Hot reload development")
    }
}
