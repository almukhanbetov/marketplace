import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (Android production-signing prep). Reads from
// android/key.properties, which is gitignored and NEVER committed — see
// android/key.properties.example for the expected keys and the keystore
// creation command. `rootProject` here is the `android/` directory (this
// module's Gradle root), so `rootProject.file("key.properties")` is
// exactly `android/key.properties`.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "kz.nova.nova_marketplace"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Store / install identity for NOVA Marketplace. The Gradle
        // `namespace` above stays at the generated value (it only names the
        // R/BuildConfig package and must match the Kotlin sources) — the
        // user-facing app identity is this applicationId.
        applicationId = "kz.nova.marketplace"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only registered when a real keystore is configured — there is no
        // password-less placeholder here, and nothing in this file ever
        // hardcodes a secret.
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Debug builds are untouched and keep using the default debug
            // keystore. Release does NOT fall back to it: if
            // android/key.properties isn't present, no signingConfig is
            // assigned here at all, and the `gradle.taskGraph.whenReady`
            // check below fails the build loudly and early — before any
            // unsigned artifact is produced — rather than silently
            // shipping a debug-signed or unsigned release build.
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

// Fails the build clearly when no release keystore is configured, instead
// of letting AGP silently produce an unsigned (or, previously, debug-
// signed) release artifact. This runs once the full task graph is
// resolved but BEFORE any task in it executes, so — unlike a `doFirst` on
// just `assembleRelease`/`bundleRelease` — no upstream packaging task
// (e.g. `packageReleaseBundle`, which writes the .aab before the
// top-level `bundleRelease` task even starts) gets a chance to leave a
// half-built, unsigned artifact on disk. Debug builds never touch this:
// the check only fires when a release-variant task is actually requested.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { it.name.contains("Release") }
    if (buildingRelease && !hasReleaseSigning) {
        throw GradleException(
            "Release signing is not configured — refusing to build an " +
                "unsigned/mis-signed release artifact.\n\n" +
                "1) Generate a keystore (choose and keep your own passwords):\n" +
                "   keytool -genkeypair -v -keystore ~/nova-release-key.jks \\\n" +
                "     -keyalg RSA -keysize 2048 -validity 10000 -alias nova\n\n" +
                "2) Create android/key.properties from " +
                "android/key.properties.example with the real values.\n\n" +
                "3) Re-run `flutter build apk --release` / `flutter build appbundle --release`.",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
