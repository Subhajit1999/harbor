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

    // Some older plugins (e.g. isar_flutter_libs 3.1.0) predate AGP 8's
    // requirement that every Android library module declare a `namespace`
    // — they only set the legacy `package` attribute in
    // AndroidManifest.xml. Backfill it from that manifest so the build
    // doesn't fail on plugins we don't control. Must be registered here
    // (before `evaluationDependsOn` below forces early evaluation of some
    // subprojects) — afterEvaluate can't be called on an already-evaluated
    // project. Safe to remove once such plugins are upgraded upstream.
    afterEvaluate {
        val androidExtension = extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
        if (androidExtension != null && androidExtension.namespace == null) {
            val manifestFile = file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val packageMatch = Regex("package=\"([^\"]+)\"").find(manifestFile.readText())
                if (packageMatch != null) {
                    androidExtension.namespace = packageMatch.groupValues[1]
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
