import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Processes google-services.json into resources. Without this the file is
    // inert: no default_web_client_id is generated and Google Sign-In cannot
    // resolve an ID token on Android.
    id("com.google.gms.google-services")
}

// Signing credentials live in android/key.properties, which is gitignored and
// points at a keystore kept outside the repo. Absent that file — a fresh clone,
// or CI without secrets — release builds fall back to the debug key so
// `flutter run --release` still works locally. A fallback build is NOT
// publishable: Play rejects debug-signed uploads, and Google Sign-In will fail
// because Firebase has no matching certificate fingerprint.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.homegrown.homegrown"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.homegrown.homegrown"
        minSdk = flutter.minSdkVersion
        // Tracks the Flutter SDK rather than being pinned, so the annual Play
        // target-API bump arrives with a Flutter upgrade instead of silently
        // going stale. Confirm the resolved level still meets Play's current
        // minimum before each release.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
