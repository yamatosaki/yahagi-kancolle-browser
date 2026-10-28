package app.yahagi.kancollebrowser.notification

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NotificationRecoveryReceiverTest {
    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun bootPackageUpdateAndPermissionGrantRestoreSavedAlarms() {
        val actions = listOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED,
        )
        var restored = 0
        val receiver = NotificationRecoveryReceiver { restored++ }
        actions.forEach { receiver.onReceive(context, Intent(it)) }
        assertEquals(3, restored)
    }

    @Test
    fun unrelatedAndMissingActionsDoNotTouchSavedAlarms() {
        var restored = 0
        val receiver = NotificationRecoveryReceiver { restored++ }
        receiver.onReceive(context, Intent("app.yahagi.unrelated"))
        receiver.onReceive(context, Intent())
        assertEquals(0, restored)
    }

    @Test
    fun recoveryFailureDoesNotCrashTheBroadcast() {
        var attempted = 0
        val receiver = NotificationRecoveryReceiver {
            attempted++
            throw IllegalStateException("simulated platform failure")
        }
        receiver.onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertEquals(1, attempted)
    }
}
