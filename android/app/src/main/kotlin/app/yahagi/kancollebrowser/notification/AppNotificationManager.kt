package app.yahagi.kancollebrowser.notification

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import app.yahagi.kancollebrowser.MainActivity
import app.yahagi.kancollebrowser.R

object AppNotificationManager {
    const val ONGOING_NOTIFICATION_ID = 999
    internal const val GAME_ALERT_TAG = "yahagi_game_alert"
    val VIBRATION_PATTERN = longArrayOf(0, 255, 90, 255)

    private const val PREFERENCES_NAME = "yahagi_native_notification_snapshot"
    private const val SNAPSHOT_KEY = "snapshot_json"
    private const val ONGOING_CHANNEL_ID = "channel_ongoing"
    private val channelTypes = setOf("expedition", "repair", "anchorage", "construction", "morale", "newShip")

    fun initChannels(
        context: Context,
        localeCode: String = loadSnapshot(context).presentation.localeCode,
    ) {
        val strings = NotificationStrings(localeCode)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val audioAttributes = AudioAttributes.Builder()
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .build()

        strings.channelNames.forEach { (type, name) ->
            listOf(false, true).forEach { sound ->
                listOf(false, true).forEach { vibration ->
                    manager.createNotificationChannel(
                        NotificationChannel(
                            channelId(type, sound, vibration),
                            strings.channelVariant(name, sound, vibration),
                            NotificationManager.IMPORTANCE_HIGH,
                        ).apply {
                            enableVibration(vibration)
                            vibrationPattern = if (vibration) VIBRATION_PATTERN else null
                            setSound(if (sound) soundUri else null, if (sound) audioAttributes else null)
                            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                            setShowBadge(true)
                        },
                    )
                }
            }
        }
        manager.createNotificationChannel(
            NotificationChannel(
                ONGOING_CHANNEL_ID,
                strings.ongoingChannelName,
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(false)
            },
        )
    }

    @Synchronized
    fun applySnapshot(context: Context, raw: Map<*, *>): Map<String, Any> {
        val desired = NotificationSnapshotCodec.fromMap(raw)
        initChannels(context, desired.presentation.localeCode)
        require(desired.schemaVersion == 1) { "Unsupported notification snapshot schema" }
        require(!desired.presentation.enabled || desired.hasKnownAccountSession) {
            "Enabled notification snapshot requires an account session"
        }
        val previous = loadSnapshot(context)
        val next = NotificationSnapshotReconciliation.beforeApply(
            previous = previous,
            desired = desired,
            nowEpochMs = System.currentTimeMillis(),
        )
        val diff = NotificationSnapshotDiff.between(previous, next)
        if (!previous.hasSameAccountSession(next)) clearPreviousAccountAlerts(context, previous)
        val failures = mutableListOf<String>()
        val failedScheduleKeys = mutableSetOf<String>()
        val failedImmediateKeys = mutableSetOf<String>()
        diff.cancelKeys.forEach { key ->
            runCatching { cancelAlarm(context, key) }
                .onFailure { failures += "$key:cancel" }
        }

        var exact = 0
        var inexact = 0
        diff.upsert.forEach { alarm ->
            runCatching {
                if (scheduleAlarm(context, alarm, next)) exact++ else inexact++
            }.onFailure {
                failures += "${alarm.key}:schedule"
                failedScheduleKeys += alarm.key
            }
        }
        if (next.presentation.enabled) {
            next.immediateAlerts.forEach { alert ->
                runCatching { showImmediateAlert(context, alert, next.presentation) }
                    .onFailure {
                        failures += "${alert.key}:notify"
                        failedImmediateKeys += alert.key
                    }
            }
        }
        val persisted = NotificationSnapshotRecovery.afterDeliveryResults(
            desired = next,
            failedScheduleKeys = failedScheduleKeys,
            failedImmediateKeys = failedImmediateKeys,
        )
        saveSnapshot(context, persisted)
        runCatching { updateOngoingProgress(context, persisted) }
            .onFailure { failures += "ongoing" }
        runCatching { NotificationProgressService.sync(context, persisted) }
            .onFailure { failures += "progress-service" }
        return mapOf(
            "scheduledExact" to exact,
            "scheduledInexact" to inexact,
            "canceled" to diff.cancelKeys.size,
            "failures" to failures,
        )
    }

    fun loadSnapshot(context: Context): NativeNotificationSnapshot {
        val json = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .getString(SNAPSHOT_KEY, null) ?: return NativeNotificationSnapshot.EMPTY
        return runCatching { NotificationSnapshotCodec.fromJson(json) }
            .getOrDefault(NativeNotificationSnapshot.EMPTY)
    }

    private fun saveSnapshot(context: Context, snapshot: NativeNotificationSnapshot) {
        context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(SNAPSHOT_KEY, NotificationSnapshotCodec.toJson(snapshot))
            .commit()
    }

    private fun clearPreviousAccountAlerts(context: Context, previous: NativeNotificationSnapshot) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        previous.alarms.forEach { manager.cancel(NotificationDelivery.notificationIdForAlarm(previous, it)) }
        previous.immediateAlerts.forEach { manager.cancel(NotificationDelivery.notificationIdForImmediate(it)) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.activeNotifications.forEach { active ->
                val legacyGameChannel = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    channelTypes.any { active.notification.channelId?.startsWith("channel_$it") == true }
                if (active.tag == GAME_ALERT_TAG || legacyGameChannel) manager.cancel(active.tag, active.id)
            }
        }
    }

    fun onAlarmFired(
        context: Context,
        key: String,
        taskId: String,
        stage: String,
    ) {
        val previous = loadSnapshot(context)
        val next = NotificationSnapshotTransitions.onAlarmFired(
            previous = previous,
            key = key,
            taskId = taskId,
            stage = stage,
        )
        saveSnapshot(context, next)
        updateOngoingProgress(context, next)
        runCatching { NotificationProgressService.sync(context, next) }
    }

    fun onAlarmDeliveryFailed(context: Context, key: String) {
        val previous = loadSnapshot(context)
        val alarm = previous.alarms.firstOrNull { it.key == key } ?: return
        val failed = NotificationSnapshotTransitions.onAlarmDeliveryFailed(alarm)
        val next = previous.copy(
            alarms = previous.alarms.map { if (it.key == key) failed else it },
        )
        saveSnapshot(context, next)
        val delayMs = NotificationDeliveryRetry.delayAfterFailure(failed.deliveryAttempts) ?: return
        val nowEpochMs = System.currentTimeMillis()
        if (nowEpochMs - failed.triggerTimeEpochMs > NotificationDeliveryRetry.RETENTION_MS) return
        runCatching {
            scheduleAlarm(
                context = context,
                alarm = failed,
                snapshot = next,
                scheduledAtEpochMs = nowEpochMs + delayMs,
            )
        }
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return false
        return manager.canScheduleExactAlarms()
    }

    fun channelsEnabled(context: Context): Boolean {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return false
        val snapshot = loadSnapshot(context)
        val activeTypes = (snapshot.alarms.map { it.type } + snapshot.ongoingItems.map { it.type })
            .filter { it in channelTypes }
            .toSet()
            .ifEmpty { channelTypes }
        val alertChannelsEnabled = activeTypes.all { type ->
            manager.getNotificationChannel(
                channelId(type, snapshot.presentation.sound, snapshot.presentation.vibration),
            )?.importance?.let { it != NotificationManager.IMPORTANCE_NONE } == true
        }
        val ongoingEnabled = snapshot.ongoingItems.isEmpty() ||
            manager.getNotificationChannel(ONGOING_CHANNEL_ID)
                ?.importance
                ?.let { it != NotificationManager.IMPORTANCE_NONE } == true
        return alertChannelsEnabled && ongoingEnabled
    }

    private fun scheduleAlarm(
        context: Context,
        alarm: NotificationAlarm,
        snapshot: NativeNotificationSnapshot,
        scheduledAtEpochMs: Long = alarm.triggerTimeEpochMs,
    ): Boolean {
        val presentation = snapshot.presentation
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: error("AlarmManager unavailable")
        val intent = Intent(context, NotificationAlarmReceiver::class.java).apply {
            putExtra("key", alarm.key)
            putExtra("memberId", snapshot.memberId ?: 0L)
            putExtra("sessionId", snapshot.sessionId)
            putExtra("taskId", alarm.taskId)
            putExtra("stage", alarm.stage)
            putExtra("triggerTimeEpochMs", alarm.triggerTimeEpochMs)
            putExtra("removeTaskOnFire", alarm.removeTaskOnFire)
            putExtra("channelId", channelId(alarm.type, presentation.sound, presentation.vibration))
            putExtra("sound", presentation.sound)
            putExtra("vibration", presentation.vibration)
            putExtra("title", alarm.title)
            putExtra("body", alarm.body)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarm.key.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val exactAllowed = canScheduleExactAlarms(context)
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && exactAllowed ->
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, scheduledAtEpochMs, pendingIntent)
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, scheduledAtEpochMs, pendingIntent)
            else -> manager.setExact(AlarmManager.RTC_WAKEUP, scheduledAtEpochMs, pendingIntent)
        }
        return exactAllowed
    }

    fun cancelAlarm(context: Context, key: String) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            key.hashCode(),
            Intent(context, NotificationAlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        manager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    private fun showImmediateAlert(
        context: Context,
        alert: ImmediateNotificationAlert,
        presentation: NotificationPresentation,
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: error("NotificationManager unavailable")
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = NotificationCompat.Builder(
            context,
            channelId(alert.type, presentation.sound, presentation.vibration),
        )
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(alert.title)
            .setContentText(alert.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(alert.body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setOnlyAlertOnce(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            builder.setVibrate(if (presentation.vibration) VIBRATION_PATTERN else null)
            builder.setSound(
                if (presentation.sound) RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION) else null,
            )
        }
        manager.notify(
            GAME_ALERT_TAG,
            NotificationDelivery.notificationIdForImmediate(alert),
            builder.build(),
        )
    }

    internal fun updateOngoingProgress(context: Context, snapshot: NativeNotificationSnapshot) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (!snapshot.hasKnownAccountSession || !snapshot.presentation.enabled ||
            !snapshot.presentation.ongoingLive ||
            snapshot.ongoingItems.isEmpty()
        ) {
            manager.cancel(ONGOING_NOTIFICATION_ID)
            return
        }
        manager.notify(ONGOING_NOTIFICATION_ID, buildOngoingNotification(context, snapshot))
    }

    internal fun buildOngoingNotification(
        context: Context,
        snapshot: NativeNotificationSnapshot,
    ): Notification {
        val projected = NotificationProgressProjection.project(snapshot, System.currentTimeMillis())
        val totalItemCount = projected.ongoingItems.size
        val items = NotificationProgressProjection.displayItems(projected.ongoingItems, projected.presentation.localeCode)
        val presentation = projected.presentation
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val collapsed = RemoteViews(context.packageName, R.layout.notification_ongoing_collapsed)
        bindItem(
            collapsed,
            items.first(),
            R.id.notif_collapsed_title,
            R.id.notif_collapsed_stats,
            R.id.notif_collapsed_progress,
            presentation,
        )
        val expanded = RemoteViews(context.packageName, R.layout.notification_ongoing_expanded)
        val containers = intArrayOf(R.id.notif_item_1, R.id.notif_item_2, R.id.notif_item_3, R.id.notif_item_4, R.id.notif_item_5)
        val titles = intArrayOf(R.id.notif_item_1_title, R.id.notif_item_2_title, R.id.notif_item_3_title, R.id.notif_item_4_title, R.id.notif_item_5_title)
        val stats = intArrayOf(R.id.notif_item_1_stats, R.id.notif_item_2_stats, R.id.notif_item_3_stats, R.id.notif_item_4_stats, R.id.notif_item_5_stats)
        val progress = intArrayOf(R.id.notif_item_1_progress, R.id.notif_item_2_progress, R.id.notif_item_3_progress, R.id.notif_item_4_progress, R.id.notif_item_5_progress)
        containers.indices.forEach { index ->
            if (index < items.size) {
                expanded.setViewVisibility(containers[index], View.VISIBLE)
                bindItem(expanded, items[index], titles[index], stats[index], progress[index], presentation)
            } else {
                expanded.setViewVisibility(containers[index], View.GONE)
            }
        }
        return NotificationCompat.Builder(context, ONGOING_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(collapsed)
            .setCustomBigContentView(expanded)
            .setContentTitle(NotificationStrings(presentation.localeCode).ongoingTitle(totalItemCount))
            .setContentText(items.first().title)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    internal fun buildSessionRetentionNotification(context: Context): Notification {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(context, ONGOING_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(NotificationStrings(loadSnapshot(context).presentation.localeCode).retentionTitle)
            .setContentText(NotificationStrings(loadSnapshot(context).presentation.localeCode).retentionBody)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun bindItem(
        views: RemoteViews,
        item: OngoingNotificationItem,
        titleId: Int,
        statsId: Int,
        progressId: Int,
        presentation: NotificationPresentation,
    ) {
        val percent = (item.progress * 100).toInt().coerceIn(0, 100)
        views.setTextViewText(titleId, item.title)
        if (item.type == "overflow") {
            views.setViewVisibility(progressId, View.GONE)
            if (item.state == "completed") {
                views.setViewVisibility(statsId, View.VISIBLE)
                views.setChronometer(statsId, SystemClock.elapsedRealtime(), NotificationStrings(presentation.localeCode).completed, false)
            } else if (presentation.showCountdown && item.targetEpochMs != null) {
                val base = SystemClock.elapsedRealtime() +
                    (item.targetEpochMs - System.currentTimeMillis()).coerceAtLeast(0L)
                views.setViewVisibility(statsId, View.VISIBLE)
                views.setChronometer(statsId, base, "%s", true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    views.setChronometerCountDown(statsId, true)
                }
            } else {
                views.setViewVisibility(statsId, View.GONE)
            }
            return
        }
        if (item.clockMode == "elapsed" && item.anchorEpochMs != null) {
            if (presentation.showCountdown) {
                val base = NotificationChronometer.elapsedRealtimeBase(
                    nowEpochMs = System.currentTimeMillis(),
                    elapsedRealtimeMs = SystemClock.elapsedRealtime(),
                    anchorEpochMs = item.anchorEpochMs,
                )
                val format = NotificationChronometer.countdownFormat(percent, presentation.showPercent)
                views.setViewVisibility(statsId, View.VISIBLE)
                views.setChronometer(statsId, base, format, true)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    views.setChronometerCountDown(statsId, false)
                }
            } else if (presentation.showPercent) {
                views.setViewVisibility(statsId, View.VISIBLE)
                views.setChronometer(
                    statsId,
                    SystemClock.elapsedRealtime(),
                    NotificationChronometer.percentOnlyFormat(percent),
                    false,
                )
            } else {
                views.setViewVisibility(statsId, View.GONE)
            }
        } else if (item.state == "completed") {
            views.setViewVisibility(statsId, View.VISIBLE)
            views.setChronometer(statsId, SystemClock.elapsedRealtime(), NotificationStrings(presentation.localeCode).completed, false)
        } else if (presentation.showCountdown && item.targetEpochMs != null) {
            val base = SystemClock.elapsedRealtime() + (item.targetEpochMs - System.currentTimeMillis())
            views.setViewVisibility(statsId, View.VISIBLE)
            views.setChronometer(
                statsId,
                base,
                NotificationChronometer.countdownFormat(percent, presentation.showPercent),
                true,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                views.setChronometerCountDown(statsId, true)
            }
        } else if (presentation.showPercent) {
            views.setViewVisibility(statsId, View.VISIBLE)
            views.setChronometer(
                statsId,
                SystemClock.elapsedRealtime(),
                NotificationChronometer.percentOnlyFormat(percent),
                false,
            )
        } else {
            views.setViewVisibility(statsId, View.GONE)
        }
        views.setViewVisibility(progressId, if (presentation.showProgress) View.VISIBLE else View.GONE)
        if (presentation.showProgress) views.setProgressBar(progressId, 100, percent, false)
    }

    private fun channelId(type: String, sound: Boolean, vibration: Boolean): String =
        "channel_${type}_${if (sound) "sound" else "silent"}_${if (vibration) "vibrate" else "quiet"}"
}
