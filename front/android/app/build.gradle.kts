// android/app/build.gradle.kts (이 파일을 집중적으로 수정합니다)

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.moring" // 실제 앱 패키지 이름과 일치하는지 다시 확인
    compileSdk = 33 // 명시적으로 33으로 설정
//    ndkVersion = flutter.ndkVersion // 이 부분 주석 해제하거나 필요하면 삭제
    ndkVersion = "27.0.12077973" // 명시적으로 버전 지정

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8 // Java 8로 설정
        targetCompatibility = JavaVersion.VERSION_1_8 // Java 8로 설정
    }

    kotlinOptions {
        jvmTarget = "1.8" // Kotlin 1.8로 설정
    }

    defaultConfig {
        applicationId = "com.example.moring" // 실제 앱 ID와 일치하는지 다시 확인
        minSdk = 21 // <<< 이 부분을 21로 명시적으로 설정
        targetSdk = 33 // 명시적으로 33으로 설정
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// 만약 build.gradle 파일에 있던 dependencies 섹션이 .kts 파일에 없다면 추가해야 합니다.
// 보통 .kts 파일에서는 dependencies 블록이 이렇게 생깁니다.
// dependencies {
//     implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version") // 필요하다면 추가
// }