package app.yahagi.kancollebrowser.notification

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import app.yahagi.kancollebrowser.MainActivity
import app.yahagi.kancollebrowser.R

class NotificationAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        synchronized(AppNotificationManager) {
            runCatching { deliverCurrentAlarm(context, intent) }.onFailure {
                Log.w("YahagiNotifications", "Unable to deliver the current notification alarm", it)
            }
        }
    }

    private fun deliverCurrentAlarm(context: Context, intent: Intent) {
        if (!AppNotificationManager.alarmDeliveryAllowed(context)) return
        val key = intent.getStringExtra("key") ?: return
        val taskId = intent.getStringExtra("taskId") ?: return
        val stage = NotificationDelivery.stageFor(key, intent.getStringExtra("stage"))
        val triggerTimeEpochMs = intent.getLongExtra("triggerTimeEpochMs", 0L)
        val snapshot = AppNotificationManager.loadSnapshot(context)
        val now = System.currentTimeMillis()
        if (!snapshot.presentation.enabled || !snapshot.hasKnownAccountSession ||
            snapshot.memberId != intent.getLongExtra("memberId", 0L) ||
            snapshot.sessionId != intent.getStringExtra("sessionId")
        ) return
        val matched = snapshot.alarms.firstOrNull { it.key == key && it.taskId == taskId &&
            it.stage == stage && it.triggerTimeEpochMs == triggerTimeEpochMs
        } ?: return
        if (stage == "preempt" && !NotificationDelivery.isCurrentPreempt(snapshot, matched, now)) {
            AppNotificationManager.discardPreempt(context, matched)
            return
        }
        if (now < matched.triggerTimeEpochMs) {
            AppNotificationManager.deferEarlyAlarm(context, matched, snapshot)
            return
        }
        val currentAlarm = NotificationDelivery.currentAlarm(
            snapshot = snapshot,
            memberId = intent.getLongExtra("memberId", 0L),
            sessionId = intent.getStringExtra("sessionId"),
            key = key,
            taskId = taskId,
            stage = stage,
            triggerTimeEpochMs = triggerTimeEpochMs,
            nowEpochMs = now,
        ) ?: return
        val presentation = snapshot.presentation
        val channelId = AppNotificationManager.channelId(currentAlarm.type, presentation.sound, presentation.vibration)
        val title = currentAlarm.title
        val sound = presentation.sound
        val vibration = presentation.vibration

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

        // First channel registration can take long enough to cross a deadline.
        val renderTime = System.currentTimeMillis()
        if (stage == "preempt" && !NotificationDelivery.isCurrentPreempt(snapshot, currentAlarm, renderTime)) {
            AppNotificationManager.discardPreempt(context, currentAlarm)
            return
        }
        val body = if (stage == "preempt") {
            val deadline = NotificationDelivery.roundDeadline(snapshot, currentAlarm) ?: return
            val seconds = ((deadline - renderTime - 1L) / 1_000L) + 1L
            NotificationStrings(presentation.localeCode).preemptBody(currentAlarm, seconds)
        } else currentAlarm.body

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

        val deliveryTime = System.currentTimeMillis()
        if (deliveryTime < currentAlarm.triggerTimeEpochMs) {
            AppNotificationManager.deferEarlyAlarm(context, currentAlarm, snapshot)
            return
        }
        if (stage == "preempt" && !NotificationDelivery.isCurrentPreempt(snapshot, currentAlarm, deliveryTime)) {
            AppNotificationManager.discardPreempt(context, currentAlarm)
            return
        }
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
