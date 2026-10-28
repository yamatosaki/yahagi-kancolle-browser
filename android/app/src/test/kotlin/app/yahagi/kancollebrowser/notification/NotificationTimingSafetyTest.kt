package app.yahagi.kancollebrowser.notification

import org.junit.Assert.*
import org.junit.Test

class NotificationTimingSafetyTest {
    private val deadline = System.currentTimeMillis() + 60_000L
    private fun alarm(stage: String, at: Long = deadline) = NotificationAlarm(
        "repair_1_$stage", "repair:1", "repair", stage, stage == "complete",
        if (stage == "preempt") at - 60_000L else at, "title", "body",
    )
    private fun snapshot(at: Long = deadline): NativeNotificationSnapshot = NativeNotificationSnapshot(
        1, System.currentTimeMillis(), alarms = listOf(alarm("preempt", at), alarm("complete", at)),
        ongoingItems = listOf(OngoingNotificationItem("repair:1", "repair", "title",
            progress = 0.5, remainingSeconds = 60, targetEpochMs = at, totalDurationSec = 120)),
        presentation = NotificationPresentation(true, true, true, true, true, true, false),
        memberId = 1L, sessionId = "test",
    )
    private fun current(s: NativeNotificationSnapshot, a: NotificationAlarm) =
        NotificationDelivery.currentAlarm(s, 1L, "test", a.key, a.taskId, a.stage, a.triggerTimeEpochMs)

    @Test fun `completion retires every preempt of its own round`() {
        val before = snapshot()
        val after = NotificationSnapshotTransitions.onAlarmFired(before, alarm("complete").key, "repair:1", "complete")
        assertTrue(after.alarms.isEmpty())
        assertEquals("completed", after.ongoingItems.single().state)
    }

    @Test fun `completion preserves alarms and progress of a newer round`() {
        val old = alarm("complete", deadline - 120_000L).copy(key = "old_complete")
        val before = snapshot().let { it.copy(alarms = it.alarms + old) }
        val after = NotificationSnapshotTransitions.onAlarmFired(before, old.key, old.taskId, old.stage)
        assertEquals(before.alarms.dropLast(1), after.alarms)
        assertEquals("running", after.ongoingItems.single().state)
    }

    @Test fun `completed task rejects a pending preempt`() {
        val before = snapshot()
        val completed = before.copy(ongoingItems = before.ongoingItems.map { it.copy(state = "completed") })
        assertNull(current(completed, before.alarms.first()))
    }

    @Test fun `expired task rejects a pending preempt even before progress projection`() {
        val expired = snapshot(System.currentTimeMillis() - 1L)
        assertNull(current(expired, expired.alarms.first()))
    }

    @Test fun `preempt without either task metadata or a matching completion is rejected`() {
        val before = snapshot()
        assertNull(current(before.copy(ongoingItems = emptyList(), alarms = listOf(before.alarms.first())), before.alarms.first()))
    }

    @Test fun `legacy snapshot without ongoing display metadata still delivers a current preempt`() {
        val before = snapshot().copy(ongoingItems = emptyList())
        assertNotNull(current(before, before.alarms.first()))
    }

    @Test fun `legacy pending completion keeps a delivered preempt until its deadline`() {
        val before = snapshot().copy(ongoingItems = emptyList(), alarms = listOf(alarm("complete")),
            deliveredAlerts = listOf(DeliveredNotificationAlert("repair:1", deadline, "preempt", 123)))
        assertTrue(NotificationDelivery.obsoleteDeliveredAlerts(before, before).isEmpty())
        assertEquals(before.deliveredAlerts, NotificationDelivery.obsoleteDeliveredAlerts(before,
            before.copy(alarms = listOf(alarm("preempt")))))
    }

    @Test fun `legacy preempt rejects a completion for another type or explicit round`() {
        val before = snapshot().copy(ongoingItems = emptyList())
        val preempt = before.alarms.first().copy(deadlineEpochMs = deadline)
        val wrongType = before.alarms.last().copy(type = "construction")
        val wrongRound = before.alarms.last().copy(triggerTimeEpochMs = deadline + 100_000)
        assertNull(current(before.copy(alarms = listOf(preempt, wrongType)), preempt))
        assertNull(current(before.copy(alarms = listOf(preempt, wrongRound)), preempt))
    }

    @Test fun `preempt keeps round identity after completion alarm was consumed`() {
        val before = snapshot()
        val preempt = before.alarms.first()
        val completeId = NotificationDelivery.notificationIdForAlarm(before, before.alarms.last())
        assertEquals(completeId, NotificationDelivery.notificationIdForAlarm(before.copy(alarms = listOf(preempt)), preempt))
    }

    @Test fun `explicit preempt deadline survives JSON without a completion or task`() {
        val preempt = alarm("preempt").copy(deadlineEpochMs = deadline, bodyTemplate = "Ready in {secondsText}")
        val original = snapshot().copy(alarms = listOf(preempt), ongoingItems = emptyList())
        val restored = NotificationSnapshotCodec.fromJson(NotificationSnapshotCodec.toJson(original))
        assertEquals(original, restored)
        assertEquals(NotificationDelivery.notificationId("repair:1", deadline), NotificationDelivery.notificationIdForAlarm(restored, preempt))
    }

    @Test fun `legacy schema one omits new alarm fields and still round trips`() {
        val original = snapshot()
        val json = NotificationSnapshotCodec.toJson(original)
        assertFalse(org.json.JSONObject(json).getJSONArray("alarms").getJSONObject(0).has("deadlineEpochMs"))
        assertFalse(org.json.JSONObject(json).getJSONArray("alarms").getJSONObject(0).has("bodyTemplate"))
        assertEquals(original, NotificationSnapshotCodec.fromJson(json))
    }

    @Test fun `preempt from an old round does not use the new running task deadline`() {
        val old = alarm("preempt", deadline - 120_000L).copy(deadlineEpochMs = deadline - 120_000L)
        val before = snapshot().copy(alarms = listOf(old))
        assertNull(current(before, old))
    }

    @Test fun `completion removes only preempts with the same explicit deadline`() {
        val oldPreempt = alarm("preempt", deadline - 120_000L).copy(key = "old_preempt", deadlineEpochMs = deadline - 120_000L)
        val oldComplete = alarm("complete", deadline - 120_000L).copy(key = "old_complete")
        val before = snapshot().let { it.copy(alarms = it.alarms + oldPreempt + oldComplete) }
        val after = NotificationSnapshotTransitions.onAlarmFired(before, oldComplete.key, oldComplete.taskId, oldComplete.stage)
        assertEquals(before.alarms.take(2), after.alarms)
        assertEquals("running", after.ongoingItems.single().state)
    }

    @Test fun `body templates use current numeric seconds and English singular`() {
        val before = alarm("preempt").copy(bodyTemplate = "{seconds}: ready in {secondsText}")
        assertEquals("1: ready in 1 second", NotificationStrings("en").preemptBody(before, 1))
        assertEquals("45: ready in 45 seconds", NotificationStrings("en").preemptBody(before, 45))
        assertEquals("{seconds} fleet: 45", NotificationStrings("en").preemptBody(before.copy(bodyTemplate = "{{seconds}} fleet: {seconds}"), 45))
        assertEquals("Fleet {{}} {name}: 45", NotificationStrings("en").preemptBody(before.copy(bodyTemplate = "Fleet {{{{}}}} {{name}}: {seconds}"), 45))
    }

    @Test fun `legacy preempt body replaces the captured countdown`() {
        val before = alarm("preempt")
        assertEquals("还有45秒", NotificationStrings().preemptBody(before.copy(body = "还有60秒"), 45))
        assertEquals("Ready in 1 second", NotificationStrings("en").preemptBody(before.copy(body = "Ready in 60 seconds"), 1))
        assertEquals("あと45秒", NotificationStrings("ja").preemptBody(before.copy(body = "あと60秒"), 45))
    }

    @Test fun `restore skips expired preempts and exhausted completion retries`() {
        val before = snapshot()
        assertTrue(NotificationDelivery.shouldRestore(before, before.alarms.first(), deadline - 1))
        assertFalse(NotificationDelivery.shouldRestore(before, before.alarms.first(), deadline))
        assertFalse(NotificationDelivery.shouldRestore(before, before.alarms.last().copy(deliveryAttempts = 4), deadline + 1))
        assertFalse(NotificationDelivery.shouldRestore(before, before.alarms.last(), deadline + NotificationDeliveryRetry.RETENTION_MS + 1))
    }

    @Test fun `restore accepts a due completion within the retention window`() {
        val before = snapshot()
        assertTrue(NotificationDelivery.shouldRestore(before, before.alarms.last(), deadline + 1))
        assertFalse(NotificationDelivery.shouldRestore(before.copy(presentation = before.presentation.copy(enabled = false)), before.alarms.last(), deadline + 1))
    }

    @Test fun `exhausted delivery attempts reject a duplicated alarm intent`() {
        val before = snapshot()
        val exhausted = before.alarms.last().copy(deliveryAttempts = 4)
        assertNull(current(before.copy(alarms = listOf(exhausted)), exhausted))
    }

    @Test fun `delivered preempt is cleaned up after deadline replacement and task removal`() {
        val before = snapshot().copy(deliveredAlerts = listOf(DeliveredNotificationAlert("repair:1", deadline, "preempt", 123)))
        assertEquals(before.deliveredAlerts, NotificationDelivery.obsoleteDeliveredAlerts(before, snapshot(deadline + 161_000)))
        assertEquals(before.deliveredAlerts, NotificationDelivery.obsoleteDeliveredAlerts(before, before.copy(alarms = emptyList(), ongoingItems = emptyList())))
        assertTrue(NotificationDelivery.obsoleteDeliveredAlerts(before, before).isEmpty())
    }

    @Test fun `legacy running round is cleaned up without delivered metadata`() {
        val before = snapshot().copy(alarms = listOf(alarm("complete")))
        val obsolete = NotificationDelivery.obsoleteDeliveredAlerts(before, before.copy(alarms = emptyList(), ongoingItems = emptyList()))
        assertEquals(listOf(NotificationDelivery.notificationId("repair:1", deadline)), obsolete.map { it.notificationId })
        assertTrue(NotificationDelivery.obsoleteDeliveredAlerts(before, before).isEmpty())
    }

    @Test fun `successful completion survives ordinary refresh but is removed for a new round`() {
        val before = snapshot().copy(alarms = emptyList(),
            deliveredAlerts = listOf(DeliveredNotificationAlert("repair:1", deadline, "complete", 123)))
        val removedCompletedTask = before.copy(ongoingItems = emptyList())
        assertTrue(NotificationDelivery.obsoleteDeliveredAlerts(before, removedCompletedTask).isEmpty())
        assertEquals(before.deliveredAlerts, NotificationDelivery.obsoleteDeliveredAlerts(before, snapshot(deadline + 161_000)))
    }

    @Test fun `successful milestone survives ordinary settlement ready refresh`() {
        val before = snapshot().let { it.copy(alarms = emptyList(),
            ongoingItems = it.ongoingItems.map { task -> task.copy(state = "settlementReady") },
            deliveredAlerts = listOf(DeliveredNotificationAlert("repair:1", deadline, "milestone", 123))) }
        assertTrue(NotificationDelivery.obsoleteDeliveredAlerts(before, before).isEmpty())
    }

    @Test fun `native delivered metadata survives Dart refresh and JSON persistence`() {
        val before = snapshot().copy(deliveredAlerts = listOf(DeliveredNotificationAlert("repair:1", deadline, "preempt", 123)))
        val merged = NotificationSnapshotReconciliation.beforeApply(before, snapshot(), deadline - 30_000)
        assertEquals(before.deliveredAlerts, merged.deliveredAlerts)
        assertEquals(merged, NotificationSnapshotCodec.fromJson(NotificationSnapshotCodec.toJson(merged)))
        assertTrue(NotificationSnapshotReconciliation.beforeApply(before, snapshot().copy(sessionId = "another"), deadline).deliveredAlerts.isEmpty())
    }
}
