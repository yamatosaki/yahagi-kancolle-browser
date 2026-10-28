package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.*
import org.junit.Test

class NativeGameDialogQueueTest {
    private class Queue {
        private val type = try {
            Class.forName("app.yahagi.kancollebrowser.nativewebview.NativeGameDialogQueue")
        } catch (_: ClassNotFoundException) {
            fail("Reminders need shared priority and protection-aware queueing")
            throw AssertionError("unreachable")
        }
        private val instance = type.getDeclaredConstructor().newInstance()
        fun offer(kind: String, id: Long, guard: Boolean = false) = type.getDeclaredMethod(
            "offer", String::class.java, java.lang.Long.TYPE, java.lang.Boolean.TYPE,
        ).invoke(instance, kind, id, guard) as Boolean
        fun finish(kind: String, id: Long) { type.getDeclaredMethod("finish", String::class.java, java.lang.Long.TYPE).invoke(instance, kind, id) }
        fun remove(kind: String, id: Long) = type.getDeclaredMethod("removeQueued", String::class.java, java.lang.Long.TYPE).invoke(instance, kind, id) as Boolean
        fun active() = key(type.getDeclaredMethod("getActive").invoke(instance))
        fun waiting() = (type.getDeclaredMethod("getWaiting").invoke(instance) as List<*>).map(::key)
        fun clear() = (type.getDeclaredMethod("clear").invoke(instance) as List<*>).map(::key)
        private fun key(value: Any?): String? = value?.let {
            "${it.javaClass.getDeclaredMethod("getKind").invoke(it)}:${it.javaClass.getDeclaredMethod("getId").invoke(it)}"
        }
    }

    @Test fun ordinaryRemindersRemainFifoWithoutReplacingTheirPendingRequest() {
        val queue = Queue()
        assertTrue(queue.offer("debuff", 1))
        assertFalse(queue.offer("newShip", 1))
        assertEquals("debuff:1", queue.active())
        queue.finish("debuff", 1)
        assertEquals("newShip:1", queue.active())
    }

    @Test fun battlePreemptsAnUnconfirmedReminderAndResumesItAheadOfLaterReminders() {
        val queue = Queue()
        queue.offer("debuff", 1)
        queue.offer("newShip", 1)
        assertTrue(queue.offer("battle", 1))
        assertEquals("battle:1", queue.active())
        assertEquals(listOf("debuff:1", "newShip:1"), queue.waiting())
        queue.finish("battle", 1)
        assertEquals("debuff:1", queue.active())
    }

    @Test fun evenBattleWaitsForThePhysicalQuietIntervalBeforeAnotherCardIsEnabled() {
        val queue = Queue()
        queue.offer("debuff", 1)
        assertFalse(queue.offer("newShip", 1, true))
        assertFalse(queue.offer("battle", 1, true))
        assertEquals("debuff:1", queue.active())
        assertEquals(listOf("battle:1", "newShip:1"), queue.waiting())
        queue.finish("debuff", 1)
        assertEquals("battle:1", queue.active())
    }

    @Test fun anOldOwnerWithTheSameNumericIdCannotFinishAnotherKind() {
        val queue = Queue()
        queue.offer("battle", 1)
        queue.offer("debuff", 1)
        queue.finish("newShip", 1)
        assertEquals("battle:1", queue.active())
        assertTrue(queue.remove("debuff", 1))
        assertEquals("battle:1", queue.active())
        assertFalse(queue.remove("battle", 1))
    }

    @Test fun cancellingAQueuedRequestPreservesItsNeighbors() {
        val queue = Queue()
        queue.offer("battle", 10)
        queue.offer("debuff", 20)
        queue.offer("newShip", 30)
        assertTrue(queue.remove("debuff", 20))
        queue.finish("battle", 10)
        assertEquals("newShip:30", queue.active())
    }

    @Test fun legacyBattleReplacementDoesNotPutTheSupersededBattleInTheQueue() {
        val queue = Queue()
        queue.offer("battle", 10)
        assertTrue(queue.offer("battle", 11))
        assertEquals("battle:11", queue.active())
        assertTrue(queue.waiting().isEmpty())
    }

    @Test fun queuedBattlesRemainFifoAheadOfOrdinaryReminders() {
        val queue = Queue()
        queue.offer("debuff", 1)
        queue.offer("battle", 10, true)
        queue.offer("newShip", 2, true)
        queue.offer("battle", 11, true)
        assertEquals(listOf("battle:10", "battle:11", "newShip:2"), queue.waiting())
    }

    @Test fun disposalCanSettleEveryActiveAndQueuedRequestExactlyOnce() {
        val queue = Queue()
        queue.offer("debuff", 1)
        queue.offer("newShip", 1)
        assertEquals(listOf("debuff:1", "newShip:1"), queue.clear())
        assertNull(queue.active())
        assertTrue(queue.waiting().isEmpty())
        assertTrue(queue.clear().isEmpty())
    }

    @Test fun noticeNeedsOnlyItsLocalizedConfirmationLabel() {
        val parsed = try {
            NativeGameWarningDialogSpec.parse(mapOf(
                "kind" to "debuff", "id" to 1, "title" to "削甲提醒", "body" to "已满足条件",
                "actions" to listOf("acknowledge"), "labels" to mapOf("acknowledge" to "确认"),
            ))
        } catch (error: Exception) {
            fail("A single-action reminder must not require battle-only headline/refresh labels: $error")
            throw AssertionError("unreachable")
        }
        assertEquals("确认", parsed.labels["acknowledge"])
        assertEquals(1, parsed.labels.size)
        assertTrue(parsed.rows.isEmpty())
        assertEquals("", parsed.headline)
    }

    @Test fun invalidReminderKindsCannotMasqueradeAsBattleRequests() {
        var rejected = false
        try {
            NativeGameWarningDialogSpec.parse(mapOf(
                "kind" to "other", "id" to 1, "title" to "title", "headline" to "headline", "body" to "body",
                "rows" to emptyList<String>(), "labels" to NativeGameWarningDialogSpec.actions.associateWith { "label" },
            ))
        } catch (_: IllegalArgumentException) { rejected = true }
        assertTrue("An unrecognized kind must be rejected", rejected)
    }
}
