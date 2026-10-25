plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.ekinotv.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.ekinotv.app"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        viewBinding = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    
    // Leanback dla interfejsu TV
    implementation("androidx.leanback:leanback:1.0.0")
    
    // Parsowanie HTML
    implementation("org.jsoup:jsoup:1.17.2")
    
    // Sieć i sesja
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    
    // Pobieranie obrazów (Coil - lekki i cache'uje na dysku)
    implementation("io.coil-kt:coil:2.5.0")
    
    // ExoPlayer / Media3
    implementation("androidx.media3:media3-exoplayer:1.2.1")
    implementation("androidx.media3:media3-ui:1.2.1")
    implementation("androidx.media3:media3-exoplayer-hls:1.2.1")
    
    // Korutyny
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}

