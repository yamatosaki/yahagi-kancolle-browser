package app.yahagi.kancollebrowser.notification

import android.app.Notification
import android.content.Context
import android.view.View
import android.widget.Chronometer
import android.widget.FrameLayout
import android.widget.RemoteViews
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import app.yahagi.kancollebrowser.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class OngoingNotificationRenderingTest {
    @Test
    fun reappliedNotificationKeepsCountdownAndStaticStatsSeparate() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        var result: Result<Unit>? = null
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            result = runCatching { verifyStatsTransitions(context) }
        }
        requireNotNull(result).getOrThrow()
    }

    private fun verifyStatsTransitions(context: Context) {
        val now = System.currentTimeMillis()
        val item = OngoingNotificationItem(
            id = "expedition:2",
            type = "expedition",
            title = "Expedition 2",
            progress = 0.54,
            remainingSeconds = 3600,
            targetEpochMs = now + 3_600_000L,
            totalDurationSec = 7800,
        )
        val live = NativeNotificationSnapshot.EMPTY.copy(
            updatedAtEpochMs = now,
            ongoingItems = listOf(item),
            presentation = NativeNotificationSnapshot.EMPTY.presentation.copy(enabled = true),
        )
        val percentOnly = live.copy(presentation = live.presentation.copy(showCountdown = false))
        val hidden = percentOnly.copy(presentation = percentOnly.presentation.copy(showPercent = false))
        val completed = hidden.copy(ongoingItems = listOf(item.copy(state = "completed")))

        fun build(snapshot: NativeNotificationSnapshot) =
            AppNotificationManager.buildOngoingNotification(context, snapshot)

        val liveNotification = build(live)
        val percentNotification = build(percentOnly)
        val hiddenNotification = build(hidden)
        val completedNotification = build(completed)
        val layouts = listOf(
            StatsLayout(R.id.notif_collapsed_stats, "notif_collapsed_static_stats") {
                requireNotNull(it.contentView)
            },
            StatsLayout(R.id.notif_item_1_stats, "notif_item_1_static_stats") {
                requireNotNull(it.bigContentView)
            },
        )
        for (layout in layouts) {
            val root = layout.views(liveNotification).apply(context, FrameLayout(context))
            val timer = root.findViewById<Chronometer>(layout.timerId)
            assertEquals(layout.staticName, View.VISIBLE, timer.visibility)

            layout.views(percentNotification).reapply(context, root)
            // On the old layout the visible stats are written to the timer itself.
            val staticId = context.resources.getIdentifier(layout.staticName, "id", context.packageName)
            val percentText = if (staticId == 0) timer else root.findViewById<TextView>(staticId)
            assertEquals(layout.staticName, View.VISIBLE, percentText.visibility)
            assertEquals(layout.staticName, "54%", percentText.text.toString())
            assertNotEquals(layout.staticName, timer.id, percentText.id)
            assertEquals(layout.staticName, View.GONE, timer.visibility)

            layout.views(hiddenNotification).reapply(context, root)
            assertEquals(layout.staticName, View.GONE, timer.visibility)
            assertEquals(layout.staticName, View.GONE, percentText.visibility)

            layout.views(liveNotification).reapply(context, root)
            assertEquals(layout.staticName, View.VISIBLE, timer.visibility)
            assertEquals(layout.staticName, View.GONE, percentText.visibility)

            layout.views(completedNotification).reapply(context, root)
            assertEquals(layout.staticName, View.GONE, timer.visibility)
            assertEquals(layout.staticName, View.VISIBLE, percentText.visibility)
            assertEquals(layout.staticName, "已完成", percentText.text.toString())
        }
    }

    private data class StatsLayout(
        val timerId: Int,
        val staticName: String,
        val views: (Notification) -> RemoteViews,
    )
}
