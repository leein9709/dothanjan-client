plugins {
    id("com.android.library") version "8.6.1"
    id("org.jetbrains.kotlin.android") version "2.2.0"
}
android {
    namespace = "org.dothanjan.kakao"
    compileSdk = 36
    defaultConfig { minSdk = 24; consumerProguardFiles("consumer-rules.pro") }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    // Compile against the same verified Godot export template used by the game.
    compileOnly(files("../../android/build/libs/release/godot-lib.template_release.aar"))
    implementation("com.kakao.sdk:v2-user:2.25.1")
    implementation("com.navercorp.nid:oauth:5.12.0")
}
