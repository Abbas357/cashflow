import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. android/key.properties and the keystore it points to are
// git-ignored; keep backups of both. Every update must be signed with the
// same key, or phones refuse to install it over the old version.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "com.finance.cash_flow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses newer Java date APIs.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Permanent once published on Google Play.
        applicationId = "com.finance.cash_flow"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // From `version:` in pubspec.yaml (name+code, e.g. 1.0.0+1).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "Cash Flow"
        // Google sign-in returns by this deep link (lib/core/config/cloud_config.dart).
        manifestPlaceholders["authScheme"] = "com.finance.cashflow"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        // A dev build is an app of its own (com.finance.cash_flow.dev, "Cash
        // Flow Dev"), installed beside the released one rather than over it,
        // with its own data: the two are signed with different keys, so one
        // would otherwise have to remove the other.
        debug {
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "Cash Flow Dev"
            manifestPlaceholders["authScheme"] = "com.finance.cashflow.dev"
        }
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// Fail release builds (only) when the key is missing, instead of producing
// an unsigned APK. Debug builds work without it.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any {
        it.name.endsWith("Release") &&
            (it.name.startsWith("bundle") || it.name.startsWith("assemble"))
    }
    if (buildsRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "Missing android/key.properties: release builds must be signed " +
                "with the Cash Flow release key.",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
