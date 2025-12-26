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

val sanitizedRootDir = File(rootProject.projectDir.path.replace("\\\\ ", " "))
val newBuildDir = sanitizedRootDir.resolve("build")
rootProject.buildDir = newBuildDir

subprojects {
    buildDir = newBuildDir.resolve(name)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    plugins.withId("com.android.application") {
        extensions.configure<ApplicationExtension> {
            compileSdk = 36
        }
    }
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            compileSdk = 36
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
