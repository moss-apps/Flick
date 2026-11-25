package com.mossapps.flick.car

import com.mossapps.flick.car.ui.Api9Spec
import com.mossapps.flick.car.ui.ChipSectionSpec
import com.mossapps.flick.car.ui.PageSpec
import com.mossapps.flick.car.ui.SectionedPage
import java.lang.reflect.Modifier

/**
 * Walks a page spec through its fields with reflection, so a spec type added later is covered
 * without anyone remembering to extend a hand-written walker.
 */
object SpecWalker {
    private const val SPEC_PACKAGE = "com.mossapps.flick.car.ui."

    fun walk(root: Any): List<Any> {
        val seen = java.util.IdentityHashMap<Any, Boolean>()
        val out = mutableListOf<Any>()
        fun visit(node: Any?) {
            when (node) {
                null -> return
                is Iterable<*> -> node.forEach { visit(it) }
                is Map<*, *> -> node.values.forEach { visit(it) }
                is Array<*> -> node.forEach { visit(it) }
                else -> {
                    if (!node.javaClass.name.startsWith(SPEC_PACKAGE)) return
                    if (seen.put(node, true) != null) return
                    out += node
                    var type: Class<*>? = node.javaClass
                    while (type != null && type.name.startsWith(SPEC_PACKAGE)) {
                        for (field in type.declaredFields) {
                            if (Modifier.isStatic(field.modifiers)) continue
                            field.isAccessible = true
                            visit(field.get(node))
                        }
                        type = type.superclass
                    }
                }
            }
        }
        visit(root)
        return out
    }

    fun api9Specs(page: PageSpec): List<Api9Spec> = walk(page).filterIsInstance<Api9Spec>()

    fun chipSections(page: PageSpec): List<ChipSectionSpec> =
        (page as? SectionedPage)?.sections?.filterIsInstance<ChipSectionSpec>() ?: emptyList()
}
