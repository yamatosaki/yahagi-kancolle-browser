package app.yahagi.kancollebrowser.notification

import kotlin.math.ceil

object NotificationProgressProjection {
    const val REFRESH_INTERVAL_MS = 30_000L
    private const val MAX_DISPLAY_ROWS = 5

    fun project(
        item: OngoingNotificationItem,
        capturedAtEpochMs: Long,
        nowEpochMs: Long,
    ): OngoingNotificationItem {
        if (item.state == "completed") {
            return item.copy(progress = 1.0, remainingSeconds = 0)
        }
        val targetEpochMs = item.targetEpochMs ?: return item
        val remainingMs = (targetEpochMs - nowEpochMs).coerceAtLeast(0L)
        val remainingWindowMs = (targetEpochMs - capturedAtEpochMs).coerceAtLeast(1L)
        val elapsedSinceCaptureMs = (nowEpochMs - capturedAtEpochMs).coerceAtLeast(0L)
        val elapsedFraction = elapsedSinceCaptureMs.toDouble() / remainingWindowMs.toDouble()
        val progress = (
            item.progress + (1.0 - item.progress) * elapsedFraction
        ).coerceIn(item.progress, 1.0)
        val state = if (
            item.clockMode == "countdown" &&
            item.state == "running" &&
            nowEpochMs >= targetEpochMs
        ) {
            "completed"
        } else {
            item.state
        }
        return item.copy(
            state = state,
            progress = if (state == "completed") 1.0 else progress,
            remainingSeconds = ceil(remainingMs / 1_000.0).toInt(),
        )
    }

    fun requiresRefresh(
        snapshot: NativeNotificationSnapshot,
        nowEpochMs: Long,
    ): Boolean {
        val presentation = snapshot.presentation
        if (!presentation.enabled || !presentation.ongoingLive) return false
        return snapshot.ongoingItems.any { item ->
            val targetEpochMs = item.targetEpochMs ?: return@any false
            if (item.state == "completed" || targetEpochMs <= nowEpochMs) return@any false
            when (item.clockMode) {
                "countdown" -> presentation.showCountdown ||
                    presentation.showPercent ||
                    presentation.showProgress
                "elapsed" -> presentation.showPercent || presentation.showProgress
                else -> false
            }
        }
    }

    fun nextRefreshDelayMs(
        snapshot: NativeNotificationSnapshot,
        nowEpochMs: Long,
    ): Long? {
        if (!requiresRefresh(snapshot, nowEpochMs)) return null
        val nearestTargetDelay = snapshot.ongoingItems
            .asSequence()
            .filter { it.state != "completed" }
            .mapNotNull { it.targetEpochMs }
            .map { it - nowEpochMs }
            .filter { it > 0L }
            .minOrNull()
        return minOf(REFRESH_INTERVAL_MS, nearestTargetDelay ?: REFRESH_INTERVAL_MS)
    }

    fun project(
        snapshot: NativeNotificationSnapshot,
        nowEpochMs: Long,
    ): NativeNotificationSnapshot = snapshot.copy(
        ongoingItems = snapshot.ongoingItems.map { item ->
            project(item, snapshot.updatedAtEpochMs, nowEpochMs)
        },
    )

    fun displayItems(
        items: List<OngoingNotificationItem>,
        localeCode: String = "zh",
    ): List<OngoingNotificationItem> {
        val sorted = items.sortedWith(
            compareBy<OngoingNotificationItem>(
                { if (it.state == "completed") 0 else 1 },
                { it.targetEpochMs ?: Long.MAX_VALUE },
                { it.id },
            ),
        )
        if (sorted.size <= MAX_DISPLAY_ROWS) return sorted

        val visible = sorted.take(MAX_DISPLAY_ROWS - 1)
        val hidden = sorted.drop(MAX_DISPLAY_ROWS - 1)
        val nearest = hidden.minWithOrNull(
            compareBy<OngoingNotificationItem>(
                { it.targetEpochMs ?: Long.MAX_VALUE },
                { it.id },
            ),
        ) ?: hidden.first()
        val summary = OngoingNotificationItem(
            id = "overflow:${hidden.size}",
            type = "overflow",
            title = NotificationStrings(localeCode).overflow(hidden.size),
            state = nearest.state,
            clockMode = "countdown",
            anchorEpochMs = null,
            progress = nearest.progress,
            remainingSeconds = nearest.remainingSeconds.coerceAtLeast(0),
            targetEpochMs = nearest.targetEpochMs,
            totalDurationSec = nearest.totalDurationSec,
        )
        return visible + summary
    }
}
