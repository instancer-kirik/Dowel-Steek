pluginManagement {
    repositories {
        google()
        gradlePluginPortal()
        mavenCentral()
        maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
    }
}

rootProject.name = "DowelMobileUX"

// Include all modules
include(":shared")
include(":androidApp")

// Enable Gradle build features
enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")

// Gradle configuration
// gradle.startParameter.excludedTaskNames.addAll(listOf(
//     ":buildSrc:testClasses"
// ))

// Development settings
buildCache {
    local {
        isEnabled = true
        directory = File(rootDir, ".gradle/build-cache")
    }
}
