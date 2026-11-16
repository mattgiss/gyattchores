import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.gyattchores.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.gyattchores.app"
        minSdk = 29
        targetSdk = 36
        versionCode = 11
        versionName = "0.7.0"
    }

    // The Play Store upload key. Its password lives outside the repo, in
    // ~/.android/gyattchores-upload.properties (storeFile, storePassword, keyAlias, keyPassword);
    // override the path with GYATTCHORES_UPLOAD_PROPERTIES. Without that file, the public release
    // falls back to the debug key, so a fresh checkout still builds.
    val uploadProps = File(System.getenv("GYATTCHORES_UPLOAD_PROPERTIES")
        ?: "${System.getProperty("user.home")}/.android/gyattchores-upload.properties")
    val upload = if (uploadProps.isFile) {
        val p = Properties().apply { uploadProps.inputStream().use(::load) }
        signingConfigs.create("upload") {
            storeFile = File(p.getProperty("storeFile"))
            storePassword = p.getProperty("storePassword")
            keyAlias = p.getProperty("keyAlias")
            keyPassword = p.getProperty("keyPassword")
        }
    } else null

    // family: syncs with the family's shared Supabase tables; keeps the id the installed phones have.
    // public: everything stays on the device; no INTERNET permission and no sync is ever started.
    flavorDimensions += "edition"
    productFlavors {
        create("family") {
            dimension = "edition"
            buildConfigField("boolean", "FAMILY_SYNC", "true")
            // Sideloaded through GitHub releases and Obtainium: stays on the key the family's
            // phones already have, or their updates would be refused.
            signingConfig = signingConfigs.getByName("debug")
        }
        create("public") {
            dimension = "edition"
            applicationIdSuffix = ".public"
            buildConfigField("boolean", "FAMILY_SYNC", "false")
            // The Play Store edition: signed with the upload key (Play re-signs it for phones).
            signingConfig = upload ?: signingConfigs.getByName("debug")
        }
    }

    buildTypes {
        debug {
            // Debug builds never reach the family's real Supabase: they sync only with a test
            // server given at launch (see AppViewModel.syncApi), or not at all.
            buildConfigField("boolean", "REAL_SYNC", "false")
        }
        release {
            buildConfigField("boolean", "REAL_SYNC", "true")
            isMinifyEnabled = false
            // Signing is set per edition above.
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true; buildConfig = true }
}

// The family edition's debug build installs beside the real family app (com.gyattchores.app.debug,
// labelled "GyattChores (test)"), so testing it on a family phone never touches the real app's data.
androidComponents {
    onVariants(selector().withBuildType("debug").withFlavor("edition" to "family")) { v ->
        v.applicationId.set("com.gyattchores.app.debug")
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom)
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")
    implementation("androidx.fragment:fragment-ktx:1.8.5")
    implementation("androidx.biometric:biometric:1.1.0")
    implementation("androidx.window:window:1.3.0")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")

    testImplementation("junit:junit:4.13.2")
}
