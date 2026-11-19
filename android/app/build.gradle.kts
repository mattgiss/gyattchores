import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// The Play Store screenshots are drawn by StoreScreenshotsTest (see PlayStore/take-screenshots.sh),
// which needs libraries nothing else here uses. They only join the build when it's asked for
// with -PstoreScreenshots, so releases and the everyday tests are untouched.
val storeScreenshots = providers.gradleProperty("storeScreenshots").isPresent

android {
    namespace = "com.doyourwork.app"
    compileSdk = 36

    defaultConfig {
        // Kept from the app's first name on purpose: a new id would stop installed phones from updating.
        applicationId = "com.gyattchores.app"
        minSdk = 29
        targetSdk = 36
        versionCode = 14
        versionName = "0.9.0"
    }

    // The Play Store upload key. Its password lives outside the repo, in
    // ~/.android/doyourwork-upload.properties (storeFile, storePassword, keyAlias, keyPassword);
    // override the path with DOYOURWORK_UPLOAD_PROPERTIES. If neither exists, the file and
    // variable from before the rename are used. Without any of them, the play release falls back
    // to the debug key, so a fresh checkout still builds.
    val home = System.getProperty("user.home")
    val uploadProps = listOfNotNull(
        System.getenv("DOYOURWORK_UPLOAD_PROPERTIES"),
        "$home/.android/doyourwork-upload.properties",
        System.getenv("GYATTCHORES_UPLOAD_PROPERTIES"), // legacy, before the rename
        "$home/.android/gyattchores-upload.properties", // legacy, before the rename
    ).map(::File).firstOrNull { it.isFile } ?: File("$home/.android/doyourwork-upload.properties")
    val upload = if (uploadProps.isFile) {
        val p = Properties().apply { uploadProps.inputStream().use(::load) }
        signingConfigs.create("upload") {
            storeFile = File(p.getProperty("storeFile"))
            storePassword = p.getProperty("storePassword")
            keyAlias = p.getProperty("keyAlias")
            keyPassword = p.getProperty("keyPassword")
        }
    } else null

    // One app, two ways out to phones. The flavors differ only in id, signing and where they're
    // distributed: no code, permission or server address is different between them.
    //  github: com.gyattchores.app, the id and debug key the family's phones already have, so
    //          Obtainium keeps updating them from GitHub releases (./release.sh).
    //  play:   com.doyourwork.app, the app's own name since it had never been on the Play Store;
    //          signed with the upload key (./play-bundle.sh) and re-signed by Play for phones.
    flavorDimensions += "dist"
    productFlavors {
        create("github") {
            dimension = "dist"
            signingConfig = signingConfigs.getByName("debug")
        }
        create("play") {
            dimension = "dist"
            applicationId = "com.doyourwork.app" // permanent once uploaded to the Play Store
            // The store version, matching the iPhone app's; release.sh only changes the github one.
            versionName = "1.0"
            signingConfig = upload ?: signingConfigs.getByName("debug")
        }
    }

    // Every build, debug included, talks to the real relay (sync/Servers.kt), and only once this
    // phone is linked. That's safe for test builds: a debug install has its own app id and data,
    // so it has its own family keys and can only reach a real family if someone scans that
    // family's code with it. Debug builds can also be started on an in-memory relay instead
    // (`--ez memoryRelay true`, see MainActivity). So there's no REAL_SYNC switch any more.
    buildTypes {
        release {
            isMinifyEnabled = false
            // Signing is set per flavor above.
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true; buildConfig = true }
    if (storeScreenshots) testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.systemProperty("robolectric.graphicsMode", "NATIVE")
                it.systemProperty("roborazzi.test.record", "true")
                it.systemProperty("storeScreenshots", "true")
                it.maxHeapSize = "3g"
            }
        }
    }
}

// Ordinary builds and test runs don't compile the screenshot test, so they need none of its libraries.
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    if (!storeScreenshots) exclude("**/StoreScreenshotsTest.kt")
}

// The github flavor's debug build installs beside the real app (com.gyattchores.app.debug,
// labelled "DOYOURWORK (test)"), so testing it on a family phone never touches the real app's data.
androidComponents {
    onVariants(selector().withBuildType("debug").withFlavor("dist" to "github")) { v ->
        // Kept from the app's first name on purpose, like the ids above, so installed test builds keep updating.
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
    // Draws the "Add a phone" QR code and reads it with the camera. No Play services.
    implementation("com.google.zxing:core:3.5.3")
    implementation("com.journeyapps:zxing-android-embedded:4.3.0")

    testImplementation("junit:junit:4.13.2")
    if (storeScreenshots) {
        testImplementation("org.robolectric:robolectric:4.14.1")
        testImplementation("io.github.takahirom.roborazzi:roborazzi:1.36.0")
        testImplementation("io.github.takahirom.roborazzi:roborazzi-compose:1.36.0")
        testImplementation("androidx.compose.ui:ui-test-junit4")
        testImplementation("androidx.test.ext:junit:1.2.1")
        debugImplementation("androidx.compose.ui:ui-test-manifest")
    }
}
