allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some plugins pin their own Android Gradle Plugin or Kotlin in a
// buildscript block (file_picker 8.5.2 with Kotlin 1.8.22, printing 7.3.0,
// flutter_contacts 9.0.0), each pulling a different toolchain. Build them all
// with the app's own versions (settings.gradle.kts): one toolchain, and one
// that is already in the local Gradle cache, so release builds stay offline.
val agpVersion = "8.11.1"
val kotlinVersion = "2.2.20"
subprojects {
    buildscript {
        configurations.all {
            resolutionStrategy.eachDependency {
                if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                    useVersion(agpVersion)
                }
                if (requested.group == "org.jetbrains.kotlin" && requested.name == "kotlin-gradle-plugin") {
                    useVersion(kotlinVersion)
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
