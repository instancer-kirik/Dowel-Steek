plugins {
    kotlin("multiplatform") version "1.9.20"
    id("org.jetbrains.compose") version "1.5.4"
    kotlin("plugin.serialization") version "1.9.20"
}

kotlin {
    // Custom Dowel OS target using Linux/Native
    linuxX64("dowel") {
        binaries {
            executable {
                entryPoint = "main"
                baseName = "dowel-steek-app"
            }
            staticLib {
                baseName = "dowel-steek-kotlin"
            }
            sharedLib {
                baseName = "dowel-steek-kotlin"
            }
        }

        compilations.getByName("main") {
            kotlinOptions {
                freeCompilerArgs += listOf(
                    "-include-binary", "${projectDir}/../../zig-core/zig-out/lib/libdowel-steek-simple.a"
                )
            }
        }
    }

    // ARM64 target for actual mobile hardware
    linuxArm64("dowelArm64") {
        binaries {
            executable {
                entryPoint = "main"
                baseName = "dowel-steek-app-arm64"
            }
            staticLib {
                baseName = "dowel-steek-kotlin-arm64"
            }
            sharedLib {
                baseName = "dowel-steek-kotlin-arm64"
            }
        }

        compilations.getByName("main") {
            kotlinOptions {
                freeCompilerArgs += listOf(
                    "-include-binary", "${projectDir}/../../zig-core/zig-out/lib/libdowel-steek-simple.a"
                )
            }
        }
    }

    sourceSets {
        val commonMain by getting {
            dependencies {
                // Kotlin coroutines
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")

                // Serialization
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.0")

                // DateTime
                implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.4.1")

                // Immutable collections
                implementation("org.jetbrains.kotlinx:kotlinx-collections-immutable:0.3.6")

                // Atomic operations
                implementation("org.jetbrains.kotlinx:atomicfu:0.22.0")

                // UUID generation
                implementation("com.benasher44:uuid:0.8.1")
            }
        }

        val commonTest by getting {
            dependencies {
                implementation(kotlin("test"))
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
            }
        }

        val dowelMain by getting {
            dependsOn(commonMain)
            dependencies {
                // Custom UI framework for Dowel OS
                implementation("org.jetbrains.compose:compose-runtime:1.5.4")

                // Native interop for C libraries
                implementation("org.jetbrains.kotlinx:kotlinx-cinterop-runtime:1.9.20")

                // Additional native libraries
                implementation("org.jetbrains.kotlinx:kotlinx-io:0.3.0")
            }
        }

        val dowelArm64Main by getting {
            dependsOn(dowelMain)
        }

        val dowelTest by getting {
            dependsOn(commonTest)
        }

        val dowelArm64Test by getting {
            dependsOn(dowelTest)
        }
    }
}

// Task to copy Zig libraries for Dowel OS native targets
tasks.register<Copy>("copyZigLibrariesDowel") {
    from("../../zig-core/zig-out/lib")
    into("src/dowelMain/resources")
    include("**/libdowel-steek-core.a")
}

// Task to copy Zig libraries for ARM64 target
tasks.register<Copy>("copyZigLibrariesDowelArm64") {
    from("../../zig-core/zig-out/lib")
    into("src/dowelMain/resources")
    include("**/libdowel-steek-core-*-aarch64.a")
}

// Ensure native libraries are built before Kotlin/Native compilation
tasks.matching { it.name.contains("compileKotlinDowel") }.configureEach {
    dependsOn("copyZigLibrariesDowel")
}

tasks.matching { it.name.contains("compileKotlinDowelArm64") }.configureEach {
    dependsOn("copyZigLibrariesDowelArm64")
}

// Custom task to build Zig core libraries
tasks.register<Exec>("buildZigCore") {
    workingDir = file("../../zig-core")
    commandLine = listOf("zig", "build")

    doFirst {
        println("Building Zig core libraries for Dowel OS...")
    }
}

// Make copy tasks depend on Zig build
tasks.named("copyZigLibrariesDowel") {
    dependsOn("buildZigCore")
}

tasks.named("copyZigLibrariesDowelArm64") {
    dependsOn("buildZigCore")
}

// Version configuration
version = "0.1.0-alpha"
group = "com.dowelsteek"

// Custom OS build tasks
tasks.register("buildDowelOS") {
    description = "Build complete Dowel OS system"
    dependsOn("buildZigCore")
    dependsOn("buildZigMinimal")
    dependsOn("dowelStaticLib")
    dependsOn("dowelArm64StaticLib")

    doLast {
        println("Dowel OS build complete!")
        println("Kotlin runtime: ${layout.buildDirectory.get()}/libs/")
        println("Zig core: ../../zig-core/zig-out/lib/")
    }
}

tasks.register("packageDowelOS") {
    description = "Package Dowel OS for deployment"
    dependsOn("buildDowelOS")

    doLast {
        println("Packaging Dowel OS system image...")
        // This would create the final OS image/package
    }
}
