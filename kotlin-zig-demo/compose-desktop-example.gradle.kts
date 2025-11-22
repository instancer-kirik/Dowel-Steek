plugins {
    kotlin("multiplatform") version "1.9.20"
    id("org.jetbrains.compose") version "1.5.10"
}

group = "com.dowelsteek"
version = "1.0.0"

repositories {
    google()
    mavenCentral()
    maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
}

kotlin {
    jvm {
        jvmToolchain(11)
        withJava()
    }

    sourceSets {
        val jvmMain by getting {
            dependencies {
                implementation(compose.desktop.currentOs)
                implementation(compose.runtime)
                implementation(compose.foundation)
                implementation(compose.material)
                implementation(compose.ui)
                implementation(compose.components.resources)
                implementation(compose.components.uiToolingPreview)

                // For native integration
                implementation("net.java.dev.jna:jna:5.13.0")
                implementation("net.java.dev.jna:jna-platform:5.13.0")
            }
        }

        val jvmTest by getting {
            dependencies {
                implementation(kotlin("test"))
            }
        }
    }
}

compose.desktop {
    application {
        mainClass = "MainKt"

        nativeDistributions {
            targetFormats(
                org.jetbrains.compose.desktop.application.dsl.TargetFormat.Dmg,
                org.jetbrains.compose.desktop.application.dsl.TargetFormat.Msi,
                org.jetbrains.compose.desktop.application.dsl.TargetFormat.Deb
            )
            packageName = "Dowel-Steek Desktop"
            packageVersion = "1.0.0"

            description = "Dowel-Steek Desktop Application"
            copyright = "© 2024 Dowel-Steek Project"
            vendor = "Dowel-Steek"

            linux {
                iconFile.set(project.file("src/jvmMain/resources/icon.png"))
            }

            windows {
                iconFile.set(project.file("src/jvmMain/resources/icon.ico"))
            }

            macOS {
                iconFile.set(project.file("src/jvmMain/resources/icon.icns"))
            }
        }
    }
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions.jvmTarget = "11"
}

// Custom task to build native library first
tasks.register<Exec>("buildNativeLibrary") {
    description = "Build the C wrapper library"
    workingDir = projectDir
    commandLine("gcc", "-c", "-fPIC", "c_wrapper.c", "-o", "c_wrapper.o")
    doLast {
        exec {
            commandLine("ar", "rcs", "libdowel-steek-c-wrapper.so", "c_wrapper.o")
        }
    }
}

tasks.named("compileKotlinJvm") {
    dependsOn("buildNativeLibrary")
}
