package app.yahagi.kancollebrowser.notification

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/** Uses the application's current manager/receiver and real Android services. */
@RunWith(AndroidJUnit4::class)
class NativeNotificationDeliveryTest {
    private val context: Context get() = ApplicationProvider.getApplicationContext()
    private val manager: NotificationManager
        get() = context.getSystemService(NotificationManager::class.java)
    private val taskId = "expedition:2"
    private val session = "notification-timing-instrumentation"

    @Before
    fun prepare() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            InstrumentationRegistry.getInstrumentation().uiAutomation.grantRuntimePermission(
                context.packageName, Manifest.permission.POST_NOTIFICATIONS,
            )
        }
        apply(emptySnapshot())
        manager.cancelAll()
    }

    @After
    fun cleanUp() {
        apply(emptySnapshot())
        manager.cancelAll()
    }

    @Test
    fun delayedPreemptUsesActualRemainingTimeAndCurrentSnapshotText() {
        val deadline = System.currentTimeMillis() + 42_000L
        val snapshot = snapshot(deadline, deadline - 60_000L)
        apply(snapshot)
        // Delivery through the actual receiver is deterministic even if the OS
        // has already dispatched this overdue alarm before the direct call.
        NotificationAlarmReceiver().onReceive(context, alarmIntent(snapshot, "preempt"))
        val alert = awaitAlert("Returning")
        val body = alert.extras.getCharSequence(Notification.EXTRA_TEXT).toString()
        val seconds = Regex("还有 (\\d+) 秒").find(body)?.groupValues?.get(1)?.toInt()
        assertNotNull(body, seconds)
        assertTrue(body, seconds!! in 1..42)
        assertFalse(body, body.contains("还有 60 秒"))
        assertFalse(body, body.contains("UNTRUSTED_INTENT_TEXT"))
    }

    @Test
    fun earlyDeliveryDoesNotPostAndKeepsTheAlarmScheduled() {
        val now = System.currentTimeMillis()
        val snapshot = snapshot(now + 600_000L, now + 540_000L)
        apply(snapshot)
        NotificationAlarmReceiver().onReceive(context, alarmIntent(snapshot, "preempt"))
        assertTrue(manager.activeNotifications.none { it.tag == AppNotificationManager.GAME_ALERT_TAG })
        assertEquals(2, AppNotificationManager.loadSnapshot(context).alarms.size)
    }

    @Test
    fun successfulDeadlineReplacementRejectsCapturedOldIntent() {
        val now = System.currentTimeMillis()
        val before = snapshot(now + 600_000L, now + 540_000L)
        val captured = alarmIntent(before, "preempt")
        apply(before)
        apply(snapshot(now + 900_000L, now + 840_000L))
        NotificationAlarmReceiver().onReceive(context, captured)
        assertTrue(manager.activeNotifications.none { it.tag == AppNotificationManager.GAME_ALERT_TAG })
        assertEquals(now + 840_000L,
            AppNotificationManager.loadSnapshot(context).alarms.first { it.stage == "preempt" }.triggerTimeEpochMs)
    }

    @Test
    fun deadlineReplacementRemovesTheAlreadyDeliveredOldPreempt() {
        val deadline = System.currentTimeMillis() + 42_000L
        val before = snapshot(deadline, deadline - 60_000L)
        apply(before)
        NotificationAlarmReceiver().onReceive(context, alarmIntent(before, "preempt"))
        awaitAlert("Returning")
        apply(snapshot(deadline + 600_000L, deadline + 540_000L))
        awaitNoGameAlerts()
    }

    @Test
    fun taskRemovalRemovesTheAlreadyDeliveredPreempt() {
        val deadline = System.currentTimeMillis() + 42_000L
        val before = snapshot(deadline, deadline - 60_000L)
        apply(before)
        NotificationAlarmReceiver().onReceive(context, alarmIntent(before, "preempt"))
        awaitAlert("Returning")
        apply(emptySnapshot(enabled = true))
        awaitNoGameAlerts()
    }

    @Test
    fun completionThenLatePreemptLeavesOnlyTheCompletionNotification() {
        val deadline = System.currentTimeMillis() - 100L
        val before = snapshot(deadline, deadline - 60_000L)
        apply(before)
        NotificationAlarmReceiver().onReceive(context, alarmIntent(before, "complete"))
        awaitAlert("Returned")
        NotificationAlarmReceiver().onReceive(context, alarmIntent(before, "preempt"))
        val alerts = manager.activeNotifications.filter { it.tag == AppNotificationManager.GAME_ALERT_TAG }
        assertEquals(1, alerts.size)
        assertEquals("Returned", alerts.single().notification.extras.getCharSequence(Notification.EXTRA_TITLE).toString())
        assertFalse(AppNotificationManager.loadSnapshot(context).alarms.any { it.stage == "preempt" })
    }

    @Test
    fun explicitRecoveryRebuildsCancelledSystemRegistrations() {
        val now = System.currentTimeMillis()
        apply(snapshot(now + 600_000L, now + 540_000L))
        val alarms = context.getSystemService(AlarmManager::class.java)
        listOf("expedition_2_preempt", "expedition_2_complete").forEach { key ->
            val pending = PendingIntent.getBroadcast(context, key.hashCode(),
                Intent(context, NotificationAlarmReceiver::class.java),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
            assertNotNull(pending)
            alarms.cancel(requireNotNull(pending))
        }
        val result = AppNotificationManager.restoreScheduledAlarms(context)
        val registrations = (result["scheduledExact"] as Number).toInt() +
            (result["scheduledInexact"] as Number).toInt()
        assertEquals(2, registrations)
        assertTrue((result["failures"] as List<*>).isEmpty())
    }

    private fun apply(snapshot: Map<String, Any?>) {
        val result = AppNotificationManager.applySnapshot(context, snapshot)
        assertTrue(result.toString(), (result["failures"] as List<*>).isEmpty())
    }

    private fun emptySnapshot(enabled: Boolean = false) = base(enabled).apply {
        put("alarms", emptyList<Any>())
        put("ongoingItems", emptyList<Any>())
    }

    private fun snapshot(deadline: Long, preempt: Long): Map<String, Any?> = base(true).apply {
        put("alarms", listOf(
            mapOf("key" to "expedition_2_preempt", "taskId" to taskId, "type" to "expedition",
                "stage" to "preempt", "removeTaskOnFire" to false, "triggerTimeEpochMs" to preempt,
                "deadlineEpochMs" to deadline, "title" to "Returning",
                "body" to "海峡警備行動 还有 60 秒返回母港。",
                "bodyTemplate" to "海峡警備行動 还有 {seconds} 秒返回母港。"),
            mapOf("key" to "expedition_2_complete", "taskId" to taskId, "type" to "expedition",
                "stage" to "complete", "removeTaskOnFire" to true, "triggerTimeEpochMs" to deadline,
                "title" to "Returned", "body" to "海峡警備行動 已返回母港。"),
        ))
        put("ongoingItems", listOf(mapOf("id" to taskId, "type" to "expedition", "title" to "Test expedition",
            "state" to "running", "clockMode" to "countdown", "progress" to 0.5,
            "remainingSeconds" to 42, "targetEpochMs" to deadline, "totalDurationSec" to 600)))
    }

    private fun base(enabled: Boolean): MutableMap<String, Any?> = mutableMapOf(
        "schemaVersion" to 1, "memberId" to 1001L, "sessionId" to session,
        "updatedAtEpochMs" to System.currentTimeMillis(), "immediateAlerts" to emptyList<Any>(),
        "presentation" to mapOf("enabled" to enabled, "sound" to false, "vibration" to false,
            "showProgress" to false, "showPercent" to false, "showCountdown" to false,
            "ongoingLive" to false, "localeCode" to "zh"),
    )

    private fun alarmIntent(snapshot: Map<String, Any?>, stage: String): Intent {
        @Suppress("UNCHECKED_CAST")
        val alarm = (snapshot["alarms"] as List<Map<String, Any?>>).first { it["stage"] == stage }
        return Intent(context, NotificationAlarmReceiver::class.java).apply {
            putExtra("memberId", 1001L)
            putExtra("sessionId", session)
            putExtra("key", alarm["key"] as String)
            putExtra("taskId", taskId)
            putExtra("stage", stage)
            putExtra("triggerTimeEpochMs", (alarm["triggerTimeEpochMs"] as Number).toLong())
            putExtra("title", "UNTRUSTED_INTENT_TEXT")
            putExtra("body", "UNTRUSTED_INTENT_TEXT")
        }
    }

    private fun awaitAlert(title: String): Notification {
        val stop = SystemClock.elapsedRealtime() + 5_000L
        while (SystemClock.elapsedRealtime() < stop) {
            val alert = manager.activeNotifications.firstOrNull {
                it.tag == AppNotificationManager.GAME_ALERT_TAG &&
                    it.notification.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() == title
            }
            if (alert != null) return alert.notification
            SystemClock.sleep(25L)
        }
        fail("Expected actual system notification: $title")
        error("unreachable")
    }

    private fun awaitNoGameAlerts() {
        val stop = SystemClock.elapsedRealtime() + 5_000L
        while (SystemClock.elapsedRealtime() < stop) {
            if (manager.activeNotifications.none { it.tag == AppNotificationManager.GAME_ALERT_TAG }) return
            SystemClock.sleep(25L)
        }
        fail("Obsolete notification was not removed")
    }
}
