import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
        classpath("com.android.tools.build:gradle:8.13.1")
        classpath("com.google.gms:google-services:4.4.2")

    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep Gradle outputs in the Flutter project root (`../build`) so Flutter
// tooling can locate generated APKs.
val newBuildDir = File(rootProject.projectDir, "../build").canonicalFile
rootProject.buildDir = newBuildDir

subprojects {
    buildDir = newBuildDir.resolve(name)
}
subprojects {
    afterEvaluate {
        extensions.findByType<ApplicationExtension>()?.apply {
            compileSdk = 36
        }
        extensions.findByType<LibraryExtension>()?.apply {
            compileSdk = 36
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
