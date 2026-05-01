plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads google-services.json so Firebase services can connect to the app.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.molls_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // flutter_local_notifications uses java.time APIs that require core
        // library desugaring on minSdk < 26.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Must match the package_name registered in google-services.json
        // (Firebase project: molly-9a63d).
        applicationId = "com.example.molls_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Bumped to 23 because firebase_messaging requires Android 6.0+.
        // (Default flutter.minSdkVersion is 21.)
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications when minSdk < 26 — provides
    // java.time / java.util APIs to older Android runtimes.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Backports the Android 12 SplashScreen API to older releases so the
    // single, Theme.SplashScreen-driven splash works on all our supported
    // SDK levels (23+).
    implementation("androidx.core:core-splashscreen:1.0.1")

    // AppCompat ships LocaleListCompat / AppCompatDelegate.setApplicationLocales,
    // which is what we use from MainActivity to push the in-app language choice
    // into Android's per-app locale store so the launcher / system surfaces
    // (notifications, recents, etc.) pick the right `app_name`.
    implementation("androidx.appcompat:appcompat:1.7.0")
}
