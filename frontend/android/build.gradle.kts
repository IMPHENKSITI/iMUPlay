import org.jetbrains.kotlin.gradle.dsl.JvmTarget

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_11)
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

    afterEvaluate {
        project.extensions.findByName("android")?.let { android ->
            try {
                val namespaceMethod = android.javaClass.getMethod("getNamespace")
                val namespace = namespaceMethod.invoke(android)
                if (namespace == null || namespace.toString().isEmpty()) {
                    val setNamespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    var generatedNamespace = project.group.toString()
                    if (generatedNamespace.isEmpty()) {
                        generatedNamespace = "com.example.${project.name.replace("-", "_")}"
                    }
                    setNamespaceMethod.invoke(android, generatedNamespace)
                }
            } catch (e: Exception) {
            }
            
            if (project.name == "isar_flutter_libs" || project.name.contains("on_audio_query")) {
                try {
                    android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(android, 34)
                } catch (e: Exception) {
                    try {
                        android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType).invoke(android, 34)
                    } catch (e2: Exception) {
                    }
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


