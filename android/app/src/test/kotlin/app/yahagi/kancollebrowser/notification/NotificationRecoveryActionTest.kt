package app.yahagi.kancollebrowser.notification

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationRecoveryActionTest {
    @Test
    fun `system recovery events restore saved alarms`() {
        listOf(
            "android.intent.action.BOOT_COMPLETED",
            "android.intent.action.MY_PACKAGE_REPLACED",
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED",
        ).forEach { assertTrue(it, NotificationRecoveryReceiver.shouldRestore(it)) }
    }

    @Test
    fun `unrelated or missing events do not restore alarms`() {
        assertFalse(NotificationRecoveryReceiver.shouldRestore(null))
        assertFalse(NotificationRecoveryReceiver.shouldRestore(""))
        assertFalse(NotificationRecoveryReceiver.shouldRestore("android.intent.action.TIME_TICK"))
        assertFalse(NotificationRecoveryReceiver.shouldRestore("app.yahagi.unrelated"))
    }
}
