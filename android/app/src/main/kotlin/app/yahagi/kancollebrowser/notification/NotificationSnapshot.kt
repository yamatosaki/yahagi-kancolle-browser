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
) {
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
        if (!desired.presentation.enabled) return desired

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
        return previous.copy(
            alarms = previous.alarms.filterNot { it.key == key },
            ongoingItems = previous.ongoingItems.map { item ->
                if (item.id != taskId) return@map item
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
    fun notificationId(key: String, triggerTimeEpochMs: Long): Int =
        ("$key:$triggerTimeEpochMs".hashCode() and 0x3FFFFFFF) + 1_000

    fun notificationIdForAlarm(
        snapshot: NativeNotificationSnapshot,
        alarm: NotificationAlarm,
    ): Int {
        val deliveryAlarm = if (alarm.stage == "preempt") {
            snapshot.alarms.firstOrNull { candidate ->
                candidate.taskId == alarm.taskId && candidate.stage == "complete"
            } ?: alarm
        } else {
            alarm
        }
        val stableKey = deliveryAlarm.taskId.ifBlank { deliveryAlarm.key }
        return notificationId(stableKey, deliveryAlarm.triggerTimeEpochMs)
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
            immediateAlerts = immediateAlerts,
            alarms = alarms,
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
