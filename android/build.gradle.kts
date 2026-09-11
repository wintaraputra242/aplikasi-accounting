allprojects {
    repositories {
        google()
        mavenCentral()
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

// Beberapa plugin (mis. file_picker) meng-hardcode compileSdk lama di dalam
// paket mereka sendiri (bukan lewat flutter.compileSdkVersion), sehingga
// override compileSdk di android/app/build.gradle.kts saja tidak cukup.
// Paksa semua subproject Android (termasuk plugin) memakai compileSdk 36.

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
