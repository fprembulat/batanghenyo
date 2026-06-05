plugins {
    id("com.android.application")
    // start flutterfire configuration
    id("com.google.gms.google-services")
    // end flutterfire configuration
    id("kotlin-android")
    // the flutter gradle plugin must be applied after the android and kotlin gradle plugins
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.batanghenyo"
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
        // specify unique application id
        applicationId = "com.example.batanghenyo"
        // update the following values to match application needs
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // add signature signing config for the release build, signing with the debug keys for now
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}