package app.yahagi.kancollebrowser.notification

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import app.yahagi.kancollebrowser.MainActivity
import app.yahagi.kancollebrowser.R

class NotificationAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        synchronized(AppNotificationManager) {
            deliverCurrentAlarm(context, intent)
        }
    }

    private fun deliverCurrentAlarm(context: Context, intent: Intent) {
        val key = intent.getStringExtra("key") ?: return
        val taskId = intent.getStringExtra("taskId") ?: return
        val stage = NotificationDelivery.stageFor(key, intent.getStringExtra("stage"))
        val triggerTimeEpochMs = intent.getLongExtra("triggerTimeEpochMs", 0L)
        val snapshot = AppNotificationManager.loadSnapshot(context)
        val currentAlarm = NotificationDelivery.currentAlarm(
            snapshot = snapshot,
            memberId = intent.getLongExtra("memberId", 0L),
            sessionId = intent.getStringExtra("sessionId"),
            key = key,
            taskId = taskId,
            stage = stage,
            triggerTimeEpochMs = triggerTimeEpochMs,
        ) ?: return
        val channelId = intent.getStringExtra("channelId") ?: "channel_expedition"
        val title = intent.getStringExtra("title") ?: NotificationStrings(AppNotificationManager.loadSnapshot(context).presentation.localeCode).fallbackTitle
        val body = intent.getStringExtra("body") ?: ""
        val sound = intent.getBooleanExtra("sound", true)
        val vibration = intent.getBooleanExtra("vibration", true)

        AppNotificationManager.initChannels(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, flags)

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setOnlyAlertOnce(NotificationDelivery.onlyAlertOnce(stage))
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            builder.setVibrate(if (vibration) AppNotificationManager.VIBRATION_PATTERN else null)
            builder.setSound(
                if (sound) android.media.RingtoneManager.getDefaultUri(
                    android.media.RingtoneManager.TYPE_NOTIFICATION,
                ) else null,
            )
        }
        val notification = builder.build()

        val notificationId = NotificationDelivery.notificationIdForAlarm(snapshot, currentAlarm)
        runCatching { notificationManager.notify(AppNotificationManager.GAME_ALERT_TAG, notificationId, notification) }
            .onSuccess {
                AppNotificationManager.onAlarmFired(context, key, taskId, stage)
            }
            .onFailure {
                AppNotificationManager.onAlarmDeliveryFailed(context, key)
            }
    }
}
