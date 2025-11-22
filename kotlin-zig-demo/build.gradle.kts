plugins {
    kotlin("jvm") version "1.9.20"
    id("org.jetbrains.compose") version "1.5.10"
}

group = "com.dowelsteek"
version = "1.0.0"

repositories {
    mavenCentral()
    maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
    google()
}

dependencies {
    implementation(compose.desktop.currentOs)
    implementation(compose.material3)
    implementation(compose.materialIconsExtended)

    // Native integration
    implementation("net.java.dev.jna:jna:5.14.0")
    implementation("net.java.dev.jna:jna-platform:5.14.0")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-swing:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.4.1")
}

compose.desktop {
    application {
        mainClass = "com.dowelsteek.desktop.MainSimpleKt"
    }
}

tasks.register<Exec>("buildNativeLibrary") {
    description = "Build shared library for JVM integration"
    workingDir = projectDir
    commandLine("gcc", "-shared", "-fPIC", "-o", "libdowel-steek-jvm.so", "c_wrapper.c")

    doLast {
        val resourcesDir = file("src/main/resources")
        resourcesDir.mkdirs()
        copy {
            from("libdowel-steek-jvm.so")
            into(resourcesDir)
        }
    }
}

tasks.named("compileKotlin") {
    dependsOn("buildNativeLibrary")
}

tasks.named("processResources") {
    dependsOn("buildNativeLibrary")
}

tasks.register("devRun") {
    dependsOn("buildNativeLibrary", "run")
    doFirst {
        println("🚀 Starting Dowel-Steek Compose Desktop App")
        println("   • Beautiful Material 3 UI")
        println("   • Native backend integration")
        println("   • Real-time system monitoring")
    }
}

kotlin {
    jvmToolchain(17)
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs += listOf(
            "-opt-in=androidx.compose.material3.ExperimentalMaterial3Api",
            "-opt-in=androidx.compose.foundation.ExperimentalFoundationApi"
        )
    }
}
