plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.dumbbell_new"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Flag to enable support for the new language APIs
        isCoreLibraryDesugaringEnabled = true // Changed to isCoreLibraryDesugaringEnabled
    }

    kotlinOptions {
        jvmTarget = "17"
    }


    defaultConfig {
        applicationId = "com.example.dumbbell_new"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") // Use the latest version
    // Add other existing dependencies here if any were outside a dependencies block
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:32.2.0"))

    // Add the dependency for the Firebase SDK for Google Analytics
    // When using the BoM, don't specify versions in Firebase dependencies
    implementation("com.google.firebase:firebase-analytics")

}
