package app.yahagi.kancollebrowser.notification

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Restores system registrations without starting a background foreground service. */
class NotificationRecoveryReceiver(
    private val restore: (Context) -> Unit = {
        val result = AppNotificationManager.restoreScheduledAlarms(it)
        check((result["failures"] as? List<*>)?.isEmpty() != false) {
            "Some notification alarms could not be restored"
        }
    },
) : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!shouldRestore(intent.action)) return
        runCatching { restore(context) }.onFailure {
            Log.w("YahagiNotifications", "Unable to restore saved notification alarms", it)
        }
    }

    companion object {
        internal fun shouldRestore(action: String?): Boolean = when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> true
            else -> false
        }
    }
}
