allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.gradle.BaseExtension>("android") {
            testOptions {
                unitTests.all {
                    it.isEnabled = false
                }
            }
        }
    }

    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.BaseExtension>("android") {
            testOptions {
                unitTests.all {
                    it.isEnabled = false
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
