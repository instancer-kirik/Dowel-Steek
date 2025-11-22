plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidLibrary)
    alias(libs.plugins.jetbrainsCompose)
    alias(libs.plugins.compose.compiler)
    alias(libs.plugins.kotlinSerialization)
    alias(libs.plugins.sqlDelight)
}

kotlin {
    androidTarget {
        compilations.all {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }



    listOf(
        iosX64(),
        iosArm64(),
        iosSimulatorArm64()
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "Shared"
            isStatic = true
        }
    }

    sourceSets {
        commonMain.dependencies {
            // Compose Multiplatform
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.material3)
            implementation(compose.ui)
            implementation(compose.components.resources)
            implementation(compose.components.uiToolingPreview)
            implementation(compose.materialIconsExtended)
            implementation(compose.animation)

            // Coroutines
            implementation(libs.kotlinx.coroutines.core)

            // Serialization
            implementation(libs.kotlinx.serialization.json)

            // DateTime
            implementation(libs.kotlinx.datetime)

            // Networking
            implementation(libs.bundles.ktor.common)

            // Database
            implementation(libs.sqldelight.runtime)
            implementation(libs.sqldelight.coroutines.extensions)

            // Dependency Injection
            implementation(libs.koin.core)

            // Navigation
            implementation(libs.bundles.voyager)
            implementation(libs.voyager.koin)

            // Image Loading
            implementation(libs.kamel.image)
        }

        commonTest.dependencies {
            implementation(libs.kotlin.test)
        }

        androidMain.dependencies {
            // Android-specific Compose
            implementation(libs.bundles.compose.android)
            implementation(libs.androidx.core.ktx)
            implementation(libs.bundles.androidx.lifecycle)
            implementation(libs.androidx.activity.compose)

            // Android-specific Ktor
            implementation(libs.ktor.client.android)

            // Android-specific SQLDelight
            implementation(libs.sqldelight.android.driver)

            // Android-specific Koin
            implementation(libs.koin.android)
            implementation(libs.koin.compose)

            // Coroutines Android
            implementation(libs.kotlinx.coroutines.android)

            // Accompanist utilities
            implementation(libs.accompanist.systemuicontroller)
            implementation(libs.accompanist.permissions)
            implementation(libs.accompanist.flowlayout)
        }

        iosMain.dependencies {
            // iOS-specific Ktor
            implementation(libs.ktor.client.ios)

            // iOS-specific SQLDelight
            implementation(libs.sqldelight.native.driver)
        }

    }
}

android {
    namespace = "com.dowelsteek.mobile.shared"
    compileSdk = 35

    defaultConfig {
        minSdk = 24
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
    }
    composeOptions {
        kotlinCompilerExtensionVersion = libs.versions.compose.compiler.get()
    }
}

sqldelight {
    databases {
        create("DowelDatabase") {
            packageName.set("com.dowelsteek.mobile.database")
            generateAsync.set(true)
        }
    }
}

// Custom tasks for development
tasks.register("generateIosFramework") {
    dependsOn("linkDebugFrameworkIosX64")
    dependsOn("linkDebugFrameworkIosArm64")
    dependsOn("linkDebugFrameworkIosSimulatorArm64")

    doLast {
        println("✅ iOS framework generated!")
        println("📱 Import in Xcode from: build/bin/ios*/debugFramework/")
    }
}

tasks.register("runUnitTests") {
    dependsOn("testDebugUnitTest")

    doLast {
        println("✅ Unit tests completed!")
    }
}



// Development configuration
afterEvaluate {
    // Configure iOS framework export
    kotlin.targets.withType<org.jetbrains.kotlin.gradle.plugin.mpp.KotlinNativeTarget> {
        if (name.startsWith("ios")) {
            binaries.all {
                // Add custom linker flags if needed
                freeCompilerArgs += "-Xdisable-phases=VerifyBitcode"
            }
        }
    }
}
