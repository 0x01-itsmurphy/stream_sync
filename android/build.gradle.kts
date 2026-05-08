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

    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val setCompileSdk = androidExt.javaClass.getMethod("setCompileSdk", Int::class.java)
                setCompileSdk.invoke(androidExt, 35)
            } catch (e: Exception) {
                try {
                    val setCompileSdkVersion = androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                    setCompileSdkVersion.invoke(androidExt, 35)
                } catch (e2: Exception) {}
            }
            
            try {
                val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                if (getNamespace.invoke(androidExt) == null) {
                    val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespace.invoke(androidExt, project.group.toString())
                }
            } catch (e: Exception) {}
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
