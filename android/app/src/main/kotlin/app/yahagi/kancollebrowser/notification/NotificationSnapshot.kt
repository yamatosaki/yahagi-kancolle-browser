package app.yahagi.kancollebrowser.notification

import org.json.JSONArray
import org.json.JSONObject

data class NotificationAlarm(
    val key: String,
    val taskId: String,
    val type: String,
    val stage: String,
    val removeTaskOnFire: Boolean,
    val triggerTimeEpochMs: Long,
    val title: String,
    val body: String,
    val deliveryAttempts: Int = 0,
    val deadlineEpochMs: Long? = null,
    val bodyTemplate: String? = null,
)

data class DeliveredNotificationAlert(
    val taskId: String,
    val deadlineEpochMs: Long,
    val stage: String,
    val notificationId: Int,
)

data class ImmediateNotificationAlert(
    val key: String,
    val taskId: String = "",
    val type: String,
    val occurredAtEpochMs: Long,
    val deadlineEpochMs: Long = occurredAtEpochMs,
    val title: String,
    val body: String,
    val deliveryAttempts: Int = 0,
)

data class OngoingNotificationItem(
    val id: String,
    val type: String,
    val title: String,
    val state: String = "running",
    val clockMode: String = "countdown",
    val anchorEpochMs: Long? = null,
    val progress: Double,
    val remainingSeconds: Int,
    val targetEpochMs: Long?,
    val totalDurationSec: Int?,
)

data class NotificationPresentation(
    val enabled: Boolean,
    val sound: Boolean,
    val vibration: Boolean,
    val showProgress: Boolean,
    val showPercent: Boolean,
    val showCountdown: Boolean,
    val ongoingLive: Boolean,
    val localeCode: String = "zh",
)

data class NativeNotificationSnapshot(
    val schemaVersion: Int,
    val updatedAtEpochMs: Long,
    val immediateAlerts: List<ImmediateNotificationAlert> = emptyList(),
    val alarms: List<NotificationAlarm>,
    val ongoingItems: List<OngoingNotificationItem>,
    val presentation: NotificationPresentation,
    val memberId: Long? = null,
    val sessionId: String? = null,
    val deliveredAlerts: List<DeliveredNotificationAlert> = emptyList(),
    val scheduledWithExactAlarms: Boolean? = null,
) {
    fun hasSameAccountSession(other: NativeNotificationSnapshot): Boolean =
        memberId == other.memberId && sessionId == other.sessionId

    val hasKnownAccountSession: Boolean
        get() = (memberId ?: 0L) > 0L && !sessionId.isNullOrBlank()

    companion object {
        val EMPTY = NativeNotificationSnapshot(
            schemaVersion = 1,
            updatedAtEpochMs = 0L,
            immediateAlerts = emptyList(),
            alarms = emptyList(),
            ongoingItems = emptyList(),
            presentation = NotificationPresentation(
                enabled = false,
                sound = true,
                vibration = true,
                showProgress = true,
                showPercent = true,
                showCountdown = true,
                ongoingLive = true,
            ),
        )
    }
}

data class NotificationAlarmDiff(
    val cancelKeys: Set<String>,
    val upsert: List<NotificationAlarm>,
)

object NotificationSnapshotDiff {
    fun between(
        previous: NativeNotificationSnapshot,
        next: NativeNotificationSnapshot,
    ): NotificationAlarmDiff {
        if (!previous.hasSameAccountSession(next)) {
            return NotificationAlarmDiff(
                cancelKeys = previous.alarms.mapTo(mutableSetOf(), NotificationAlarm::key),
                upsert = next.alarms,
            )
        }
        val alarmDiff = between(previous.alarms, next.alarms)
        val presentationChanged =
            previous.presentation.sound != next.presentation.sound ||
                previous.presentation.vibration != next.presentation.vibration
        return if (presentationChanged) {
            alarmDiff.copy(upsert = next.alarms)
        } else {
            alarmDiff
        }
    }

    fun between(
        previous: List<NotificationAlarm>,
        next: List<NotificationAlarm>,
    ): NotificationAlarmDiff {
        val previousByKey = previous.associateBy(NotificationAlarm::key)
        val nextByKey = next.associateBy(NotificationAlarm::key)
        return NotificationAlarmDiff(
            cancelKeys = previousByKey.keys - nextByKey.keys,
            upsert = next.filter { previousByKey[it.key] != it },
        )
    }
}

object NotificationSnapshotRecovery {
    fun afterScheduleFailures(
        desired: NativeNotificationSnapshot,
        failedKeys: Set<String>,
    ): NativeNotificationSnapshot = desired.copy(
        alarms = desired.alarms.filterNot { it.key in failedKeys },
    )

    fun afterDeliveryResults(
        desired: NativeNotificationSnapshot,
        failedScheduleKeys: Set<String>,
        failedImmediateKeys: Set<String>,
    ): NativeNotificationSnapshot = desired.copy(
        alarms = desired.alarms.filterNot { it.key in failedScheduleKeys },
        immediateAlerts = desired.immediateAlerts
            .filter { it.key in failedImmediateKeys }
            .map { it.copy(deliveryAttempts = it.deliveryAttempts + 1) },
    )
}

object NotificationSnapshotReconciliation {
    fun beforeApply(
        previous: NativeNotificationSnapshot,
        desired: NativeNotificationSnapshot,
        nowEpochMs: Long,
    ): NativeNotificationSnapshot {
        if (!desired.presentation.enabled || !previous.hasSameAccountSession(desired)) return desired

        val previousAlarmsByKey = previous.alarms.associateBy(NotificationAlarm::key)
        val desiredAlarms = desired.alarms.map { alarm ->
            val previousAlarm = previousAlarmsByKey[alarm.key]
            if (previousAlarm != null &&
                previousAlarm.taskId == alarm.taskId &&
                previousAlarm.triggerTimeEpochMs == alarm.triggerTimeEpochMs
            ) {
                alarm.copy(deliveryAttempts = previousAlarm.deliveryAttempts)
            } else {
                alarm
            }
        }
        val desiredAlarmKeys = desiredAlarms.mapTo(mutableSetOf(), NotificationAlarm::key)
        val dueCompletionAlarms = previous.alarms.filter { alarm ->
            alarm.key !in desiredAlarmKeys &&
                alarm.stage == "complete" &&
                alarm.triggerTimeEpochMs <= nowEpochMs &&
                nowEpochMs - alarm.triggerTimeEpochMs <= NotificationDeliveryRetry.RETENTION_MS
        }
        val desiredImmediateKeys = desired.immediateAlerts.mapTo(
            mutableSetOf(),
            ImmediateNotificationAlert::key,
        )
        val pendingImmediateAlerts = previous.immediateAlerts.filter { alert ->
            alert.key !in desiredImmediateKeys &&
                alert.deliveryAttempts > 0 &&
                nowEpochMs - alert.deadlineEpochMs <= NotificationDeliveryRetry.RETENTION_MS
        }

        return desired.copy(
            immediateAlerts = desired.immediateAlerts + pendingImmediateAlerts,
            alarms = desiredAlarms + dueCompletionAlarms,
            deliveredAlerts = previous.deliveredAlerts,
        )
    }
}

object NotificationSnapshotTransitions {
    fun onAlarmDeliveryFailed(alarm: NotificationAlarm): NotificationAlarm =
        alarm.copy(deliveryAttempts = alarm.deliveryAttempts + 1)

    fun onAlarmFired(
        previous: NativeNotificationSnapshot,
        key: String,
        taskId: String,
        stage: String,
    ): NativeNotificationSnapshot {
        val fired = previous.alarms.firstOrNull { it.key == key }
        val roundDeadline = fired?.let { NotificationDelivery.roundDeadline(previous, it) }
        return previous.copy(
            alarms = previous.alarms.filterNot { candidate ->
                candidate.key == key || (stage == "complete" && candidate.stage == "preempt" &&
                    candidate.taskId == taskId && roundDeadline != null &&
                    NotificationDelivery.roundDeadline(previous, candidate) == roundDeadline)
            },
            ongoingItems = previous.ongoingItems.map { item ->
                if (item.id != taskId) return@map item
                if (roundDeadline != null && item.targetEpochMs != null &&
                    item.targetEpochMs != roundDeadline && item.clockMode != "elapsed"
                ) return@map item
                when {
                    stage == "complete" -> item.copy(
                        state = "completed",
                        progress = 1.0,
                        remainingSeconds = 0,
                    )
                    stage == "milestone" && item.type == "anchorage" -> item.copy(
                        state = "settlementReady",
                    )
                    else -> item
                }
            },
        )
    }
}

object NotificationDeliveryRetry {
    const val RETENTION_MS = 24L * 60L * 60L * 1_000L

    fun delayAfterFailure(deliveryAttempts: Int): Long? = when (deliveryAttempts) {
        1 -> 1_000L
        2 -> 3_000L
        3 -> 10_000L
        else -> null
    }
}

object NotificationChronometer {
    fun elapsedRealtimeBase(
        nowEpochMs: Long,
        elapsedRealtimeMs: Long,
        anchorEpochMs: Long,
    ): Long = elapsedRealtimeMs - (nowEpochMs - anchorEpochMs).coerceAtLeast(0L)

    fun countdownFormat(percent: Int, showPercent: Boolean): String =
        if (showPercent) "$percent%%  %s" else "%s"

    fun percentOnlyFormat(percent: Int): String = "$percent%%"
}

object NotificationDelivery {
    fun currentAlarm(
        snapshot: NativeNotificationSnapshot,
        memberId: Long,
        sessionId: String?,
        key: String,
        taskId: String,
        stage: String,
        triggerTimeEpochMs: Long,
        nowEpochMs: Long = System.currentTimeMillis(),
    ): NotificationAlarm? {
        if (!snapshot.presentation.enabled || !snapshot.hasKnownAccountSession ||
            snapshot.memberId != memberId || snapshot.sessionId != sessionId
        ) return null
        val alarm = snapshot.alarms.firstOrNull {
            it.key == key && it.taskId == taskId && it.stage == stage &&
                it.triggerTimeEpochMs == triggerTimeEpochMs
        } ?: return null
        if (alarm.deliveryAttempts > 3) return null
        if (alarm.stage == "preempt" && !isCurrentPreempt(snapshot, alarm, nowEpochMs)) return null
        return alarm
    }

    /** A round stays identifiable after its completion registration has been consumed. */
    fun roundDeadline(snapshot: NativeNotificationSnapshot, alarm: NotificationAlarm): Long? {
        alarm.deadlineEpochMs?.let { return it }
        if (alarm.stage != "preempt") return alarm.triggerTimeEpochMs
        return snapshot.alarms.filter {
            it.taskId == alarm.taskId && it.type == alarm.type && it.stage == "complete" &&
                it.triggerTimeEpochMs >= alarm.triggerTimeEpochMs
        }.minOfOrNull { it.deadlineEpochMs ?: it.triggerTimeEpochMs }
            ?: snapshot.ongoingItems.firstOrNull { it.id == alarm.taskId }?.targetEpochMs
            ?: snapshot.deliveredAlerts.lastOrNull { it.taskId == alarm.taskId }?.deadlineEpochMs
    }

    fun isCurrentPreempt(snapshot: NativeNotificationSnapshot, alarm: NotificationAlarm, nowEpochMs: Long): Boolean {
        val deadline = roundDeadline(snapshot, alarm) ?: return false
        if (deadline <= nowEpochMs) return false
        val task = snapshot.ongoingItems.firstOrNull { it.id == alarm.taskId }
        if (task != null) return task.state == "running" && task.targetEpochMs == deadline
        // Older clients omitted task metadata when the ongoing display was off.
        // Its pending completion is the remaining authoritative round marker.
        return snapshot.alarms.any { it.taskId == alarm.taskId && it.type == alarm.type &&
            it.stage == "complete" && it.triggerTimeEpochMs == deadline &&
            roundDeadline(snapshot, it) == deadline }
    }

    fun shouldRestore(snapshot: NativeNotificationSnapshot, alarm: NotificationAlarm, nowEpochMs: Long): Boolean =
        snapshot.presentation.enabled && snapshot.hasKnownAccountSession &&
            (alarm.deliveryAttempts == 0 || NotificationDeliveryRetry.delayAfterFailure(alarm.deliveryAttempts) != null) && when (alarm.stage) {
            "preempt" -> isCurrentPreempt(snapshot, alarm, nowEpochMs)
            else -> nowEpochMs - alarm.triggerTimeEpochMs <= NotificationDeliveryRetry.RETENTION_MS &&
                alarm.deliveryAttempts <= 3
        }

    fun notificationId(key: String, triggerTimeEpochMs: Long): Int =
        ("$key:$triggerTimeEpochMs".hashCode() and 0x3FFFFFFF) + 1_000

    fun notificationIdForAlarm(
        snapshot: NativeNotificationSnapshot,
        alarm: NotificationAlarm,
    ): Int {
        val stableKey = alarm.taskId.ifBlank { alarm.key }
        return notificationId(stableKey, roundDeadline(snapshot, alarm) ?: alarm.triggerTimeEpochMs)
    }

    fun obsoleteDeliveredAlerts(previous: NativeNotificationSnapshot, next: NativeNotificationSnapshot,
        nowEpochMs: Long = System.currentTimeMillis(),
    ): List<DeliveredNotificationAlert> {
        // Before delivered metadata existed, a fired preempt was removed while
        // its running task and pending completion still identified the round.
        val legacyPreempts = previous.alarms.filter { it.stage == "complete" }.mapNotNull { alarm ->
            val deadline = roundDeadline(previous, alarm) ?: return@mapNotNull null
            val task = previous.ongoingItems.firstOrNull { it.id == alarm.taskId }
            if ((task != null && (task.state != "running" || task.targetEpochMs != deadline)) ||
                previous.deliveredAlerts.any { it.taskId == alarm.taskId && it.deadlineEpochMs == deadline }
            ) return@mapNotNull null
            DeliveredNotificationAlert(alarm.taskId, deadline, "preempt", notificationId(alarm.taskId, deadline))
        }
        return (previous.deliveredAlerts + legacyPreempts).filter { delivered ->
            if (!next.presentation.enabled || !previous.hasSameAccountSession(next)) return@filter true
            val task = next.ongoingItems.firstOrNull { it.id == delivered.taskId }
            val nextRounds = next.alarms.filter { it.taskId == delivered.taskId }
                .mapNotNull { roundDeadline(next, it) }
            val replacedRound = (task?.state == "running" && task.targetEpochMs != null &&
                task.targetEpochMs != delivered.deadlineEpochMs) ||
                nextRounds.any { it != delivered.deadlineEpochMs }
            val pendingCompletion = next.alarms.any { it.taskId == delivered.taskId &&
                it.stage == "complete" && roundDeadline(next, it) == delivered.deadlineEpochMs }
            if (delivered.stage != "preempt") replacedRound
            else replacedRound || (task == null && !pendingCompletion) ||
                (task != null && task.state != "running") || delivered.deadlineEpochMs <= nowEpochMs
        }
    }

    fun notificationIdForImmediate(alert: ImmediateNotificationAlert): Int =
        notificationId(alert.taskId.ifBlank { alert.key }, alert.deadlineEpochMs)

    fun onlyAlertOnce(stage: String): Boolean = stage != "complete"

    fun stageFor(key: String, explicitStage: String?): String = explicitStage ?: when {
        key.endsWith("_preempt") -> "preempt"
        key.endsWith("_20m") -> "milestone"
        else -> "complete"
    }
}

object NotificationSnapshotCodec {
    fun fromMap(raw: Map<*, *>): NativeNotificationSnapshot {
        val immediateAlerts = raw.optionalList("immediateAlerts").map { alertRaw ->
            val alert = alertRaw.asMap()
            ImmediateNotificationAlert(
                key = alert.string("key"),
                taskId = alert.optionalString("taskId") ?: "",
                type = alert.string("type"),
                occurredAtEpochMs = alert.long("occurredAtEpochMs"),
                deadlineEpochMs = alert.optionalNumber("deadlineEpochMs")?.toLong()
                    ?: alert.long("occurredAtEpochMs"),
                title = alert.string("title"),
                body = alert.string("body"),
                deliveryAttempts = alert.optionalNumber("deliveryAttempts")?.toInt() ?: 0,
            )
        }
        val alarms = raw.list("alarms").map { alarmRaw ->
            val alarm = alarmRaw.asMap()
            NotificationAlarm(
                key = alarm.string("key"),
                taskId = alarm.string("taskId"),
                type = alarm.string("type"),
                stage = alarm.string("stage"),
                removeTaskOnFire = alarm.boolean("removeTaskOnFire"),
                triggerTimeEpochMs = alarm.long("triggerTimeEpochMs"),
                title = alarm.string("title"),
                body = alarm.string("body"),
                deliveryAttempts = alarm.optionalNumber("deliveryAttempts")?.toInt() ?: 0,
                deadlineEpochMs = alarm.optionalNumber("deadlineEpochMs")?.toLong(),
                bodyTemplate = alarm.optionalString("bodyTemplate"),
            )
        }
        val ongoingItems = raw.list("ongoingItems").map { itemRaw ->
            val item = itemRaw.asMap()
            OngoingNotificationItem(
                id = item.string("id"),
                type = item.string("type"),
                title = item.string("title"),
                state = item.optionalString("state") ?: "running",
                clockMode = item.optionalString("clockMode") ?: "countdown",
                anchorEpochMs = item.optionalNumber("anchorEpochMs")?.toLong(),
                progress = item.number("progress").toDouble().coerceIn(0.0, 1.0),
                remainingSeconds = item.number("remainingSeconds").toInt().coerceAtLeast(0),
                targetEpochMs = item.optionalNumber("targetEpochMs")?.toLong(),
                totalDurationSec = item.optionalNumber("totalDurationSec")?.toInt(),
            )
        }
        val presentation = raw["presentation"].asMap()
        return NativeNotificationSnapshot(
            schemaVersion = raw.number("schemaVersion").toInt(),
            updatedAtEpochMs = raw.long("updatedAtEpochMs"),
            memberId = raw.optionalNumber("memberId")?.toLong(),
            sessionId = raw.optionalString("sessionId"),
            immediateAlerts = immediateAlerts,
            alarms = alarms,
            deliveredAlerts = raw.optionalList("deliveredAlerts").map { entry ->
                val delivered = entry.asMap()
                DeliveredNotificationAlert(delivered.string("taskId"), delivered.long("deadlineEpochMs"),
                    delivered.string("stage"), delivered.number("notificationId").toInt())
            },
            scheduledWithExactAlarms = raw["scheduledWithExactAlarms"] as? Boolean,
            ongoingItems = ongoingItems,
            presentation = NotificationPresentation(
                enabled = presentation.boolean("enabled"),
                sound = presentation.boolean("sound"),
                vibration = presentation.boolean("vibration"),
                showProgress = presentation.boolean("showProgress"),
                showPercent = presentation.boolean("showPercent"),
                showCountdown = presentation.boolean("showCountdown"),
                ongoingLive = presentation.boolean("ongoingLive"),
                localeCode = presentation["localeCode"] as? String ?: "zh",
            ),
        )
    }

    fun toJson(snapshot: NativeNotificationSnapshot): String = JSONObject().apply {
        put("schemaVersion", snapshot.schemaVersion)
        put("updatedAtEpochMs", snapshot.updatedAtEpochMs)
        put("memberId", snapshot.memberId ?: JSONObject.NULL)
        put("sessionId", snapshot.sessionId ?: JSONObject.NULL)
        snapshot.scheduledWithExactAlarms?.let { put("scheduledWithExactAlarms", it) }
        put("deliveredAlerts", JSONArray().apply {
            snapshot.deliveredAlerts.forEach { delivered ->
                put(JSONObject().apply {
                    put("taskId", delivered.taskId)
                    put("deadlineEpochMs", delivered.deadlineEpochMs)
                    put("stage", delivered.stage)
                    put("notificationId", delivered.notificationId)
                })
            }
        })
        put("immediateAlerts", JSONArray().apply {
            snapshot.immediateAlerts.forEach { alert ->
                put(JSONObject().apply {
                    put("key", alert.key)
                    put("taskId", alert.taskId)
                    put("type", alert.type)
                    put("occurredAtEpochMs", alert.occurredAtEpochMs)
                    put("deadlineEpochMs", alert.deadlineEpochMs)
                    put("title", alert.title)
                    put("body", alert.body)
                    put("deliveryAttempts", alert.deliveryAttempts)
                })
            }
        })
        put("alarms", JSONArray().apply {
            snapshot.alarms.forEach { alarm ->
                put(JSONObject().apply {
                    put("key", alarm.key)
                    put("taskId", alarm.taskId)
                    put("type", alarm.type)
                    put("stage", alarm.stage)
                    put("removeTaskOnFire", alarm.removeTaskOnFire)
                    put("triggerTimeEpochMs", alarm.triggerTimeEpochMs)
                    put("title", alarm.title)
                    put("body", alarm.body)
                    put("deliveryAttempts", alarm.deliveryAttempts)
                    alarm.deadlineEpochMs?.let { put("deadlineEpochMs", it) }
                    alarm.bodyTemplate?.takeIf { it.isNotEmpty() }?.let { put("bodyTemplate", it) }
                })
            }
        })
        put("ongoingItems", JSONArray().apply {
            snapshot.ongoingItems.forEach { item ->
                put(JSONObject().apply {
                    put("id", item.id)
                    put("type", item.type)
                    put("title", item.title)
                    put("state", item.state)
                    put("clockMode", item.clockMode)
                    put("anchorEpochMs", item.anchorEpochMs ?: JSONObject.NULL)
                    put("progress", item.progress)
                    put("remainingSeconds", item.remainingSeconds)
                    put("targetEpochMs", item.targetEpochMs ?: JSONObject.NULL)
                    put("totalDurationSec", item.totalDurationSec ?: JSONObject.NULL)
                })
            }
        })
        put("presentation", JSONObject().apply {
            put("enabled", snapshot.presentation.enabled)
            put("sound", snapshot.presentation.sound)
            put("vibration", snapshot.presentation.vibration)
            put("showProgress", snapshot.presentation.showProgress)
            put("showPercent", snapshot.presentation.showPercent)
            put("showCountdown", snapshot.presentation.showCountdown)
            put("ongoingLive", snapshot.presentation.ongoingLive)
            put("localeCode", snapshot.presentation.localeCode)
        })
    }.toString()

    fun fromJson(json: String): NativeNotificationSnapshot {
        val root = JSONObject(json)
        return fromMap(root.toMap())
    }
}

private fun Any?.asMap(): Map<*, *> = this as? Map<*, *>
    ?: throw IllegalArgumentException("Expected map")

private fun Map<*, *>.string(key: String): String = this[key] as? String
    ?: throw IllegalArgumentException("$key must be a string")

private fun Map<*, *>.optionalString(key: String): String? = this[key] as? String

private fun Map<*, *>.number(key: String): Number = this[key] as? Number
    ?: throw IllegalArgumentException("$key must be a number")

private fun Map<*, *>.optionalNumber(key: String): Number? = this[key] as? Number

private fun Map<*, *>.long(key: String): Long = number(key).toLong()

private fun Map<*, *>.boolean(key: String): Boolean = this[key] as? Boolean
    ?: throw IllegalArgumentException("$key must be a boolean")

private fun Map<*, *>.list(key: String): List<*> = this[key] as? List<*>
    ?: throw IllegalArgumentException("$key must be a list")

private fun Map<*, *>.optionalList(key: String): List<*> = this[key] as? List<*> ?: emptyList<Any?>()

private fun JSONObject.toMap(): Map<String, Any?> = keys().asSequence().associateWith { key ->
    when (val value = get(key)) {
        JSONObject.NULL -> null
        is JSONObject -> value.toMap()
        is JSONArray -> value.toList()
        else -> value
    }
}

private fun JSONArray.toList(): List<Any?> = (0 until length()).map { index ->
    when (val value = get(index)) {
        JSONObject.NULL -> null
        is JSONObject -> value.toMap()
        is JSONArray -> value.toList()
        else -> value
    }
}
