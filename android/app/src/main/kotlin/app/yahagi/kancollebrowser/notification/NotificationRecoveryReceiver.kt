package app.yahagi.kancollebrowser.notification

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.Executors

/** Restores system registrations without starting a background foreground service. */
class NotificationRecoveryReceiver(
    private val restore: (Context) -> Unit = ::restoreSavedAlarms,
) : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!shouldRestore(intent.action)) return
        val pendingResult = goAsync()
        restoreInBackground(context, restore) { pendingResult?.finish() }
    }

    companion object {
        private const val RETRY_DELAY_MS = 1_000L
        private val worker = Executors.newSingleThreadExecutor { task ->
            Thread(task, "YahagiNotificationRecovery")
        }

        internal fun restoreInBackground(
            context: Context,
            restore: (Context) -> Unit = ::restoreSavedAlarms,
            onFinished: () -> Unit = {},
        ) {
            val appContext = context.applicationContext
            worker.execute {
                try {
                    attemptRecovery(
                        restore = { restore(appContext) },
                        waitBeforeRetry = { Thread.sleep(RETRY_DELAY_MS) },
                    ).onFailure {
                        Log.w("YahagiNotifications", "Unable to restore saved notification alarms", it)
                    }
                } finally {
                    onFinished()
                }
            }
        }

        internal fun attemptRecovery(
            restore: () -> Unit,
            waitBeforeRetry: () -> Unit,
        ): Result<Unit> = runCatching(restore).recoverCatching {
            waitBeforeRetry()
            restore()
        }

        private fun restoreSavedAlarms(context: Context) {
            val result = AppNotificationManager.restoreScheduledAlarms(context)
            check((result["failures"] as? List<*>)?.isEmpty() != false) {
                "Some notification alarms could not be restored"
            }
        }

        internal fun shouldRestore(action: String?): Boolean = when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> true
            else -> false
        }
    }
}
