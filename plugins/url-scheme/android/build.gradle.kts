// Android library module of the URL Scheme plugin. The script `haylen.py` copies it into `haylen/plugins/url-scheme` of the Android project of an app, which depends on it. The module holds no code: its manifest declares the scheme on the link activity of the `haylen-links` library, and the engine publishes every link that the activity receives as `linkOpened`.
plugins {
    id("com.android.library")
}

android {
    namespace = "com.haylen.plugins.urlscheme"
    compileSdk {
        version = release(37) {
            minorApiLevel = 2
        }
    }

    defaultConfig {
        minSdk = 27
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

// The Android project of the app gives every module the engine version it builds with.
val haylenEngineVersion = extra["haylenEngineVersion"] as String

dependencies {
    implementation("dev.haylen:haylen-links:$haylenEngineVersion")
}
