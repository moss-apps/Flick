plugins {
    id("com.android.application")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.io.File
import java.util.Properties

val keystoreProperties = Properties()
val keystoreFile = rootProject.file("key.properties")
if (keystoreFile.exists()) {
    keystoreFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.mossapps.flick"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    signingConfigs {
        create("release") {
            storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    defaultConfig {
        applicationId = "com.mossapps.flick"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
        }

        externalNativeBuild {
            cmake {
                arguments += "-DANDROID_STL=c++_shared"
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            pickFirsts += listOf("**/libc++_shared.so")
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

// Copy libc++_shared.so from NDK before building
tasks.register("copyNdkLibs") {
    description = "Copy libc++_shared.so from Android NDK to jniLibs"
    doLast {
        fun llvmStripFromPath(): String? {
            val executableName =
                if (System.getProperty("os.name").lowercase().contains("win")) {
                    "llvm-strip.exe"
                } else {
                    "llvm-strip"
                }

            return (System.getenv("PATH") ?: "")
                .split(File.pathSeparatorChar)
                .asSequence()
                .map { File(it, executableName) }
                .firstOrNull { it.isFile && it.canExecute() }
                ?.absolutePath
        }

        fun ndkHomeFromLocalProperties(): String? {
            val propsFile = rootProject.file("local.properties")
            if (!propsFile.exists()) return null

            val props = Properties()
            propsFile.inputStream().use { props.load(it) }

            val explicitNdk = props.getProperty("ndk.dir")
            if (!explicitNdk.isNullOrBlank()) {
                return explicitNdk
            }

            val sdkDir = props.getProperty("sdk.dir") ?: return null
            val ndkRoot = File(sdkDir, "ndk")
            if (!ndkRoot.exists()) return null

            return ndkRoot.listFiles()
                ?.filter { it.isDirectory }
                ?.maxByOrNull { it.name }
                ?.absolutePath
        }

        val ndkHome =
            System.getenv("ANDROID_NDK_HOME")
                ?: System.getenv("ANDROID_NDK_ROOT")
                ?: ndkHomeFromLocalProperties()
                ?: throw GradleException(
                    "ANDROID_NDK_HOME/ANDROID_NDK_ROOT is not set and no NDK could be resolved from local.properties",
                )

        val abiToArch = mapOf(
            "arm64-v8a" to "aarch64-linux-android",
            "armeabi-v7a" to "arm-linux-androideabi",
            "x86_64" to "x86_64-linux-android",
            "x86" to "i686-linux-android",
        )

        val jniLibsDir = project.file("src/main/jniLibs")
        val llvmStrip = llvmStripFromPath()
        val prebuiltRoots = listOf(
            "toolchains/llvm/prebuilt/windows-x86_64",
            "toolchains/llvm/prebuilt/linux-x86_64",
            "toolchains/llvm/prebuilt/darwin-x86_64",
            "toolchains/llvm/prebuilt/darwin-arm64",
        )

        abiToArch.forEach { (abi, arch) ->
            val abiOutDir = File(jniLibsDir, abi)
            abiOutDir.mkdirs()

            val candidates = mutableListOf<File>()

            prebuiltRoots.forEach { root ->
                candidates += File(ndkHome, "$root/sysroot/usr/lib/$arch/libc++_shared.so")
                candidates += File(ndkHome, "$root/sysroot/usr/lib/$abi/libc++_shared.so")
            }

            // Legacy location (older NDKs)
            candidates += File(ndkHome, "sources/cxx-stl/llvm-libc++/libs/$abi/libc++_shared.so")

            val sourceLib = candidates.firstOrNull { it.exists() }
            if (sourceLib != null) {
                val outputLib = File(abiOutDir, "libc++_shared.so")
                sourceLib.copyTo(outputLib, overwrite = true)

                if (llvmStrip != null) {
                    val sizeBeforeBytes = outputLib.length()
                    val stripResult =
                        project.exec {
                            executable = llvmStrip
                            args("--strip-debug", outputLib.absolutePath)
                            isIgnoreExitValue = true
                        }

                    if (stripResult.exitValue == 0) {
                        val sizeAfterBytes = outputLib.length()
                        logger.lifecycle(
                            "Stripped libc++_shared.so for $abi: ${sizeBeforeBytes / 1024} KB -> ${sizeAfterBytes / 1024} KB",
                        )
                    } else {
                        logger.warn("Warning: failed to strip libc++_shared.so for $abi")
                    }
                } else {
                    logger.warn("Warning: llvm-strip not found on PATH; leaving libc++_shared.so unstripped for $abi")
                }

                logger.lifecycle("Copied libc++_shared.so for $abi from ${sourceLib.absolutePath}")
            } else {
                logger.warn("Warning: libc++_shared.so not found for $abi in NDK $ndkHome")
            }
        }
    }
}

// Make preBuild depend on copyNdkLibs
tasks.named("preBuild") {
    dependsOn("copyNdkLibs")
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.12.0"))
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.documentfile:documentfile:1.1.0")
    implementation("androidx.media:media:1.7.0")
    implementation("androidx.lifecycle:lifecycle-service:2.7.0")
    
    // Jetpack Glance for Widgets
    val glanceVersion = "1.2.0-rc01"
    implementation("androidx.glance:glance-appwidget:$glanceVersion")
    implementation("androidx.glance:glance-material3:$glanceVersion")
}
