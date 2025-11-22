plugins {
    // this is necessary to avoid the plugins to be loaded multiple times
    // in each subproject's classloader
    alias(libs.plugins.androidApplication) apply false
    alias(libs.plugins.androidLibrary) apply false
    alias(libs.plugins.jetbrainsCompose) apply false
    alias(libs.plugins.compose.compiler) apply false
    alias(libs.plugins.kotlinMultiplatform) apply false
    alias(libs.plugins.kotlinSerialization) apply false
    alias(libs.plugins.sqlDelight) apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
    }
}

tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}

// Version catalog for dependency management
version = "1.0.0"
group = "com.dowelsteek.mobile"

// Custom tasks for development
tasks.register("setupProject") {
    group = "dowel setup"
    description = "Sets up the development environment"

    doLast {
        println("🚀 Dowel Mobile UX Project Setup Complete!")
        println("📱 Ready to build the future of mobile OS")
        println("✨ Run './gradlew :shared:build' to build shared module")
        println("🤖 Run './gradlew :androidApp:installDebug' for Android")
        println("🍎 Open iosApp/iosApp.xcodeproj for iOS")
    }
}

tasks.register("runTests") {
    group = "dowel testing"
    description = "Runs all tests across all modules"
    dependsOn(":shared:test")
    if (project.findProject(":androidApp") != null) {
        dependsOn(":androidApp:testDebugUnitTest")
    }
}

tasks.register("buildAllPlatforms") {
    group = "dowel build"
    description = "Builds for all target platforms"
    dependsOn(":shared:build")
    if (project.findProject(":androidApp") != null) {
        dependsOn(":androidApp:assembleDebug")
    }

    doLast {
        println("✅ All platforms built successfully!")
        println("📦 APK: androidApp/build/outputs/apk/debug/")
        println("🍎 iOS: Build using Xcode")
    }
}
