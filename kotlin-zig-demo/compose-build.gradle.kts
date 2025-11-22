plugins {
    kotlin("multiplatform") version "1.9.20"
    id("org.jetbrains.compose") version "1.5.10"
    id("org.jetbrains.kotlin.plugin.compose") version "1.9.20"
}

group = "com.dowelsteek"
version = "1.0.0"

repositories {
    google()
    mavenCentral()
    maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
    maven("https://androidx.dev/storage/compose-compiler/repository/")
}

kotlin {
    jvm {
        jvmToolchain(17)
        withJava()
    }

    sourceSets {
        val jvmMain by getting {
            dependencies {
                implementation(compose.desktop.currentOs)
                implementation(compose.runtime)
                implementation(compose.foundation)
                implementation(compose.material3)
                implementation(compose.ui)
                implementation(compose.components.resources)
                implementation(compose.components.uiToolingPreview)
                implementation(compose.materialIconsExtended)

                // For native integration via JNA
                implementation("net.java.dev.jna:jna:5.14.0")
                implementation("net.java.dev.jna:jna-platform:5.14.0")

                // Additional UI libraries
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-swing:1.7.3")
                implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.4.1")

                // JSON handling
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")
            }
        }

        val jvmTest by getting {
            dependencies {
                implementation(kotlin("test"))
                implementation(compose.uiTestJunit4)
            }
        }
    }
}

compose.desktop {
    application {
        mainClass = "com.dowelsteek.desktop.MainKt"

        nativeDistributions {
            targetFormats(
                org.jetbrains.compose.desktop.application.dsl.TargetFormat.Dmg,
                org.jetbrains.compose.desktop.application.dsl.TargetFormat.Msi,
                org.jetbrains.compose.desktop.application.dsl.TargetFormat.Deb,
                org.jetbrains.compose.desktop.application.dsl.TargetFormat.AppImage
            )

            packageName = "Dowel-Steek Desktop"
            packageVersion = "1.0.0"
            description = "Dowel-Steek Mobile OS Development Suite"
            copyright = "© 2024 Dowel-Steek Project"
            vendor = "Dowel-Steek"

            modules("java.compiler", "java.instrument", "java.management", "java.prefs", "java.rmi")

            linux {
                packageName = "dowel-steek-desktop"
                debMaintainer = "dowelsteek@example.com"
                menuGroup = "Development"
                appCategory = "Development"
            }

            windows {
                packageName = "Dowel-Steek Desktop"
                msiPackageVersion = "1.0.0"
                exePackageVersion = "1.0.0"
            }

            macOS {
                packageName = "Dowel-Steek Desktop"
                dockName = "Dowel-Steek"
                packageBuildVersion = "1.0.0"
                dmgPackageVersion = "1.0.0"
                packageVersion = "1.0.0"
                minimumSystemVersion = "10.15"
            }
        }

        buildTypes.release.proguard {
            configurationFiles.from(project.file("compose-desktop.pro"))
        }
    }
}

// Custom task to build native library for JVM integration
tasks.register<Exec>("buildNativeLibrary") {
    description = "Build shared library for JVM integration"
    workingDir = projectDir

    doFirst {
        println("🔧 Building native library for Compose Desktop integration...")
    }

    commandLine("gcc", "-shared", "-fPIC", "-o", "libdowel-steek-jvm.so", "c_wrapper.c")

    doLast {
        println("✅ Native library built: libdowel-steek-jvm.so")

        // Copy to resources so it's included in the JAR
        val resourcesDir = file("src/jvmMain/resources")
        if (!resourcesDir.exists()) {
            resourcesDir.mkdirs()
        }
        copy {
            from("libdowel-steek-jvm.so")
            into(resourcesDir)
        }

        println("📦 Library copied to resources for distribution")
    }
}

// Ensure native library is built before compilation
tasks.named("compileKotlinJvm") {
    dependsOn("buildNativeLibrary")
}

tasks.named("jvmProcessResources") {
    dependsOn("buildNativeLibrary")
}

// Development helper tasks
tasks.register("devRun") {
    description = "Run the Compose Desktop app in development mode"
    dependsOn("buildNativeLibrary", "run")

    doFirst {
        println("🚀 Starting Dowel-Steek Compose Desktop Application")
        println("   • Native backend: ✓ Integrated")
        println("   • UI Framework: Compose Desktop + Material 3")
        println("   • Hot reload: ✓ Enabled")
    }
}

tasks.register("buildDesktopApp") {
    description = "Build complete desktop application package"
    dependsOn("buildNativeLibrary", "packageDistributionForCurrentOS")

    doLast {
        println("✅ Desktop application built successfully!")
        println("📱 Features included:")
        println("   • Material 3 Design System")
        println("   • Native performance monitoring")
        println("   • Real-time system dashboard")
        println("   • Mobile OS simulation")
        println("   • Cross-platform compatibility")
        println()
        println("📦 Distribution packages created in build/compose/binaries/main/")
    }
}

// Configure JVM arguments for better performance
tasks.withType<JavaExec> {
    jvmArgs(
        "-Xmx2g",
        "-XX:+UseG1GC",
        "-XX:+UseStringDeduplication",
        "-Dcompose.verbose.logging=false",
        "-Dfile.encoding=UTF-8"
    )
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs = freeCompilerArgs + listOf(
            "-opt-in=kotlin.RequiresOptIn",
            "-opt-in=androidx.compose.material3.ExperimentalMaterial3Api",
            "-opt-in=androidx.compose.foundation.ExperimentalFoundationApi",
            "-opt-in=androidx.compose.ui.ExperimentalComposeUiApi"
        )
    }
}

// ProGuard configuration for release builds
tasks.register("createProguardConfig") {
    doLast {
        val proguardFile = file("compose-desktop.pro")
        proguardFile.writeText("""
            -dontwarn **
            -dontnote **
            -keep class androidx.compose.** { *; }
            -keep class org.jetbrains.compose.** { *; }
            -keep class kotlin.** { *; }
            -keep class kotlinx.** { *; }
            -keep class com.dowelsteek.** { *; }
            -keepclassmembers class * {
                @androidx.compose.runtime.Composable *;
            }
            -assumenosideeffects class kotlin.jvm.internal.Intrinsics {
                static void checkParameterIsNotNull(java.lang.Object, java.lang.String);
            }
        """.trimIndent())
    }
}

tasks.named("packageDistributionForCurrentOS") {
    dependsOn("createProguardConfig")
}
