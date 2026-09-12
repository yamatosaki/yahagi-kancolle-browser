package app.yahagi.kancollebrowser.notification

import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.content.ContextCompat

class NotificationProgressService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val refreshRunnable = Runnable(::refreshAndSchedule)

    override fun onCreate() {
        super.onCreate()
        running = true
        AppNotificationManager.initChannels(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_SET_SESSION_RETENTION) {
            sessionRetentionRequested = intent.getBooleanExtra(EXTRA_RETAINING, false)
        }
        handler.removeCallbacks(refreshRunnable)
        refreshAndSchedule()
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        sessionRetentionRequested = false
        handler.removeCallbacks(refreshRunnable)
        refreshAndSchedule()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        handler.removeCallbacks(refreshRunnable)
        sessionRetentionRequested = false
        running = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun refreshAndSchedule() {
        synchronized(AppNotificationManager) {
            refreshCurrentAndSchedule()
        }
    }

    private fun refreshCurrentAndSchedule() {
        val snapshot = AppNotificationManager.loadSnapshot(this)
        val hasOngoingItems = snapshot.hasKnownAccountSession && snapshot.presentation.enabled &&
            snapshot.presentation.ongoingLive &&
            snapshot.ongoingItems.isNotEmpty()
        val mode = NotificationForegroundMode.resolve(
            sessionRetentionRequested = sessionRetentionRequested,
            hasOngoingItems = hasOngoingItems,
        )
        if (mode == NotificationForegroundMode.STOP) {
            stopForegroundCompat(removeNotification = true)
            getSystemService(NotificationManager::class.java)
                ?.cancel(AppNotificationManager.ONGOING_NOTIFICATION_ID)
            stopSelf()
            return
        }

        val notification = when (mode) {
            NotificationForegroundMode.PROGRESS ->
                AppNotificationManager.buildOngoingNotification(this, snapshot)
            NotificationForegroundMode.SESSION ->
                AppNotificationManager.buildSessionRetentionNotification(this)
            NotificationForegroundMode.STOP -> error("stop mode handled above")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                AppNotificationManager.ONGOING_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(AppNotificationManager.ONGOING_NOTIFICATION_ID, notification)
        }

        val nowEpochMs = System.currentTimeMillis()
        val delayMs = NotificationProgressProjection.nextRefreshDelayMs(snapshot, nowEpochMs)
        if (delayMs == null && !sessionRetentionRequested) {
            stopForegroundCompat(removeNotification = false)
            stopSelf()
            return
        }
        if (delayMs != null) {
            handler.postDelayed(refreshRunnable, delayMs)
        }
    }

    private fun stopForegroundCompat(removeNotification: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(
                if (removeNotification) STOP_FOREGROUND_REMOVE else STOP_FOREGROUND_DETACH,
            )
        } else {
            @Suppress("DEPRECATION")
            stopForeground(removeNotification)
        }
    }

    companion object {
        private const val ACTION_SET_SESSION_RETENTION =
            "app.yahagi.kancollebrowser.action.SET_SESSION_RETENTION"
        private const val EXTRA_RETAINING = "retaining"

        @Volatile
        private var running = false

        @Volatile
        private var sessionRetentionRequested = false

        fun setSessionRetention(context: Context, retaining: Boolean) {
            val intent = Intent(context, NotificationProgressService::class.java).apply {
                action = ACTION_SET_SESSION_RETENTION
                putExtra(EXTRA_RETAINING, retaining)
            }
            if (retaining) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
        }

        fun sync(context: Context, snapshot: NativeNotificationSnapshot) {
            val intent = Intent(context, NotificationProgressService::class.java)
            if (NotificationProgressProjection.requiresRefresh(snapshot, System.currentTimeMillis())) {
                ContextCompat.startForegroundService(context, intent)
            } else if (running) {
                context.startService(intent)
            }
        }
    }
}
