plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

fun secret(name: String): String =
    (System.getenv(name) ?: "").filter { !it.isWhitespace() && it != '"' && it != '\\' }

android {
    namespace = "com.ultron.assistant"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.ultron.assistant"
        minSdk = 26
        targetSdk = 34
        versionCode = 4
        versionName = "2.0"
        buildConfigField("String", "GOOGLE_KEY", "\"${secret("GOOGLE_API_KEY")}\"")
        buildConfigField("String", "FISH_KEY", "\"${secret("FISH_API_KEY")}\"")
        buildConfigField("String", "VOICE_ID", "\"23866d1d2134461cbcefe95d1bd8bfcf\"")
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }
}
dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
}
