package com.mossapps.flick.car

import com.mossapps.flick.car.ui.Pages
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * "Render9.kt is the ONLY file importing API 9 classes" (docs/ANDROID_AUTO_DESIGN.md, 6),
 * checked on the compiled classes: a class file names every class and method it uses in its
 * constant pool, so a level 9 reference anywhere else shows up as text in the bytes.
 */
class StructureTest {
    /** Everything androidx.car marks `@RequiresCarApi(9)` as a class, in the AAR this build uses. */
    private val level9Classes = listOf(
        "androidx/car/app/media/model/MediaPlaybackStyle",
        "androidx/car/app/model/Background",
        "androidx/car/app/model/Banner",
        "androidx/car/app/model/CarProgressBar",
        "androidx/car/app/model/Chip",
        "androidx/car/app/model/CondensedItem",
        "androidx/car/app/model/CondensedSection",
        "androidx/car/app/model/SearchCallback",
        "androidx/car/app/model/SearchHeader",
        "androidx/car/app/model/SectionHeader",
        "androidx/car/app/model/Shape",
        "androidx/car/app/model/SpotlightSection",
        "androidx/car/app/model/StrokeCap",
        "androidx/car/app/model/TabStyle",
    )

    /** Methods of older classes that exist only at level 9 (Header, GridSection, the templates). */
    private val level9Methods = listOf(
        "setSearchHeader",
        "setSectionHeader",
        "setStartHeaderImage",
        "setIncompleteLastRowStrategy",
        "setIncompleteLastColumnStrategy",
    )

    /** A compiled class: its path inside the classes root, and its bytes read as text. */
    private class ClassFile(val path: String, bytes: ByteArray) {
        val name: String get() = path.substringAfterLast('/')
        val pkg: String get() = path.substringBeforeLast('/').substringAfterLast('/')
        val topLevel: String get() = name.removeSuffix(".class").substringBefore('$')
        val text: String = String(bytes, Charsets.ISO_8859_1)
    }

    /** The unit test classpath holds the app classes as a directory or as a jar. */
    private val carClasses: List<ClassFile> by lazy {
        val location = File(Pages::class.java.protectionDomain!!.codeSource.location.toURI())
        val prefix = "com/mossapps/flick/car/"
        if (location.isDirectory) {
            File(location, prefix).walkTopDown().filter { it.extension == "class" }.map {
                ClassFile(it.relativeTo(location).path.replace(File.separatorChar, '/'), it.readBytes())
            }.toList()
        } else {
            java.util.zip.ZipFile(location).use { zip ->
                zip.entries().asSequence()
                    .filter { it.name.startsWith(prefix) && it.name.endsWith(".class") }
                    .map { ClassFile(it.name, zip.getInputStream(it).readBytes()) }
                    .toList()
            }
        }
    }

    private fun isRender9(file: ClassFile) = file.pkg == "ui" && file.topLevel == "Render9"

    @Test
    fun theCompiledClassesAreFound() {
        assertTrue("found ${carClasses.size} classes", carClasses.size > 100)
        assertTrue(carClasses.any { isRender9(it) })
    }

    @Test
    fun render9IsTheOnlyFileThatTouchesALevel9Class() {
        val offenders = mutableListOf<String>()
        for (file in carClasses.filter { !isRender9(it) }) {
            val body = file.text
            for (name in level9Classes) {
                if (body.contains(name)) offenders += "${file.name} -> $name"
            }
            for (method in level9Methods) {
                if (body.contains(method)) offenders += "${file.name} -> $method()"
            }
        }
        assertEquals("level 9 API outside Render9: $offenders", emptyList<String>(), offenders)
    }

    @Test
    fun render9ReallyUsesThem() {
        // Guards the scan above: it would pass vacuously if the names no longer matched the bytes.
        val body = carClasses.filter { isRender9(it) }.joinToString("") { it.text }
        for (name in listOf(
            "androidx/car/app/model/ChipSection",
            "androidx/car/app/model/BannerSection",
            "androidx/car/app/model/CondensedSection",
            "androidx/car/app/model/SpotlightSection",
            "androidx/car/app/model/SectionHeader",
            "androidx/car/app/model/SearchHeader",
            "androidx/car/app/media/model/MediaPlaybackStyle",
            "androidx/car/app/model/ChipStyle",
            "androidx/car/app/model/Background",
        )) {
            assertTrue("Render9 should reference $name", body.contains(name))
        }
        for (method in level9Methods) assertTrue("Render9 should call $method", body.contains(method))
    }

    @Test
    fun pagesAndSpecsImportNoCarOrAndroidClass() {
        val pure = carClasses.filter { file ->
            val name = file.topLevel
            // The page layer: specs, view models, the palette, Pages. Render and CarStyle are the renderers.
            (file.pkg == "ui" && name != "Render" && name != "Render9" && name != "CarStyle") ||
                file.pkg == "model" || name == "ClassicTree" || name == "CarStrings" || name == "EngineGate"
        }
        assertTrue("found ${pure.size} pure classes", pure.size > 80)
        val offenders = pure.filter { file ->
            val body = file.text
            body.contains("androidx/car") || body.contains("Landroid/") || body.contains("android/os")
        }.map { it.name }
        assertEquals("pure page code touches car or android classes: $offenders", emptyList<String>(), offenders)
    }

    @Test
    fun theLevelIsReadInExactlyOnePlace() {
        // CarStyle.api9 is the only reader of the negotiated level.
        val readers = carClasses.filter { it.text.contains("getCarAppApiLevel") }.map { it.topLevel }.toSet()
        assertEquals(setOf("CarStyle"), readers)
    }
}
