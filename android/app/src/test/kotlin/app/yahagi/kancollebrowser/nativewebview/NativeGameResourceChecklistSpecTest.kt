package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.*
import org.junit.Test

class NativeGameResourceChecklistSpecTest {
    private fun payload(kind: String = "headerResources"): Map<String, Any> = mapOf(
        "kind" to kind, "id" to 80L, "title" to "选择顶部显示项目",
        "labels" to mapOf("acknowledge" to "完成"),
        "items" to listOf(mapOf("id" to "senka", "label" to "战果", "value" to "20 (#1)", "checked" to true)),
    )

    private fun valid(values: Map<String, Any>): NativeGameWarningDialogSpec = try {
        NativeGameWarningDialogSpec.parse(values)
    } catch (error: Exception) {
        fail("Resource checklist must parse without a Flutter modal: ${error.message}")
        throw AssertionError("unreachable")
    }

    private fun field(value: Any, name: String): Any? = value.javaClass.getDeclaredMethod(name).invoke(value)
    private fun items(value: NativeGameWarningDialogSpec) = field(value, "getItems") as List<*>
    private fun reject(values: Map<String, Any>) {
        try {
            NativeGameWarningDialogSpec.parse(values)
            fail("Invalid resource checklist must be rejected")
        } catch (_: IllegalArgumentException) {
        } catch (_: IllegalStateException) {
        }
    }

    @Test fun headerChecklistKeepsTypedItemsAndAllowsTheEmptyReminderFields() {
        val spec = valid(payload())
        assertEquals("headerResources", spec.kind)
        assertTrue(spec.isNotice)
        assertEquals("", spec.headline)
        assertEquals("", spec.body)
        assertEquals(emptyList<String>(), spec.rows)
        assertEquals(listOf("acknowledge"), spec.displayActions)
        val item = items(spec).single()!!
        assertEquals("senka", field(item, "getId"))
        assertEquals("战果", field(item, "getLabel"))
        assertEquals("20 (#1)", field(item, "getValue"))
        assertEquals(true, field(item, "getChecked"))
    }

    @Test fun collapsedChecklistKeepsItsSeparateKindAndLocalizedResetAction() {
        val spec = valid(payload("collapsedResources") + ("resetLabel" to "恢复默认"))
        assertEquals("collapsedResources", spec.kind)
        assertEquals("恢复默认", field(spec, "getResetLabel"))
        assertEquals(NativeGameDialogKey("collapsedResources", 80), spec.key)
    }

    @Test fun anEmptySelectionEditorStillHasAUsableDoneAction() {
        val spec = valid(payload() + ("items" to emptyList<Any>()))
        assertTrue(items(spec).isEmpty())
        assertEquals("完成", spec.labels["acknowledge"])
    }

    @Test fun itemIdsMustBeUniqueAndNonempty() {
        val original = (payload()["items"] as List<*>).single()!!
        reject(payload() + ("items" to listOf(original, original)))
        reject(payload() + ("items" to listOf(mapOf("id" to "", "label" to "a", "value" to "", "checked" to true))))
    }

    @Test fun checksAndVisibleValuesAreStrictlyTyped() {
        for (invalid in listOf(
            mapOf("id" to "a", "label" to "a", "value" to "", "checked" to "yes"),
            mapOf("id" to "a", "label" to "a", "value" to 1, "checked" to false),
            mapOf("id" to "a", "label" to "", "value" to "", "checked" to false),
        )) reject(payload() + ("items" to listOf(invalid)))
    }

    @Test fun unboundedAndMalformedItemListsAreRejected() {
        reject(payload() + ("items" to "not a list"))
        reject(payload() + ("items" to (1..65).map {
            mapOf("id" to "item-$it", "label" to "$it", "value" to "", "checked" to false)
        }))
    }

    @Test fun resetMustBeANonemptyLocalizedLabel() {
        reject(payload() + ("resetLabel" to ""))
        reject(payload() + ("resetLabel" to 1))
    }

    @Test fun checklistCannotAcquireARefreshAction() {
        reject(payload() + ("actions" to listOf("reloadGame")))
    }

    @Test fun ordinaryRemindersCannotSmuggleInteractiveItems() {
        reject(payload("debuff") + ("body" to "notice"))
    }

    @Test fun acknowledgedChangeSequenceIsPreservedForLateUpdateRejection() {
        val spec = valid(payload() + ("appliedChangeId" to 3L))
        val getter = spec.javaClass.declaredMethods.firstOrNull { it.name == "getAppliedChangeId" }
        assertNotNull("Checklist updates must carry their applied change sequence", getter)
        assertEquals(3L, getter!!.invoke(spec))
    }

    @Test fun negativeFractionalAndTextChangeSequencesAreRejected() {
        for (invalid in listOf(-1L, 1.5, "3")) reject(payload() + ("appliedChangeId" to invalid))
    }
}
