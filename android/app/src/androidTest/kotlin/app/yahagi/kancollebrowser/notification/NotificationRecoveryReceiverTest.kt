package app.yahagi.kancollebrowser.notification

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

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
        val restored = CountDownLatch(actions.size)
        val receiver = NotificationRecoveryReceiver { restored.countDown() }
        actions.forEach { receiver.onReceive(context, Intent(it)) }
        assertTrue(restored.await(5, TimeUnit.SECONDS))
    }

    @Test
    fun unrelatedAndMissingActionsDoNotTouchSavedAlarms() {
        val restored = AtomicInteger()
        val receiver = NotificationRecoveryReceiver { restored.incrementAndGet() }
        receiver.onReceive(context, Intent("app.yahagi.unrelated"))
        receiver.onReceive(context, Intent())
        awaitRecoveryWorker()
        assertEquals(0, restored.get())
    }

    @Test
    fun bootRecoveryRetriesWhenFirstRestoreFails() {
        val attempts = AtomicInteger()
        val restored = CountDownLatch(1)
        val receiver = NotificationRecoveryReceiver {
            if (attempts.incrementAndGet() == 1) error("simulated platform failure")
            restored.countDown()
        }
        receiver.onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertTrue(restored.await(5, TimeUnit.SECONDS))
        assertEquals(2, attempts.get())
    }

    private fun awaitRecoveryWorker() {
        val drained = CountDownLatch(1)
        NotificationRecoveryReceiver.restoreInBackground(context, restore = {}) { drained.countDown() }
        assertTrue(drained.await(5, TimeUnit.SECONDS))
    }
}
