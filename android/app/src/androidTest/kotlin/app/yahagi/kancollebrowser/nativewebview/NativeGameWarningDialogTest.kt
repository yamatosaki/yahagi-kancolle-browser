package app.yahagi.kancollebrowser.nativewebview

import android.app.Dialog
import android.os.Looper
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import app.yahagi.kancollebrowser.MainActivity
import app.yahagi.kancollebrowser.R
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** Run only in the isolated warning-smoke application; all content is local. */
@RunWith(AndroidJUnit4::class)
class NativeGameWarningDialogTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private lateinit var scenario: ActivityScenario<MainActivity>
    private lateinit var engine: FlutterEngine
    private lateinit var game: WebView
    private lateinit var control: NativeGameWarningDialogChannel
    private var gameDowns = 0

    @Before fun setUp() {
        scenario = ActivityScenario.launch(MainActivity::class.java)
        onMain {
            game = WebView(it).apply {
                settings.javaScriptEnabled = true
                setOnTouchListener { _, event ->
                    if (event.actionMasked == MotionEvent.ACTION_DOWN) gameDowns++
                    false
                }
            }
            it.findViewById<FrameLayout>(android.R.id.content).addView(
                game, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
            )
            game.loadDataWithBaseURL("https://warning.invalid/", """
                <html><body style="background:#286060"><canvas id="c" width="300" height="160"></canvas>
                <script>window.ticks=0;const x=c.getContext('2d');function frame(){window.ticks++;
                x.fillStyle=window.ticks%2?'#aaff55':'#55aaff';x.fillRect(0,0,300,160);
                requestAnimationFrame(frame);}requestAnimationFrame(frame);</script></body></html>
            """.trimIndent(), "text/html", "utf-8", null)
            engine = FlutterEngine(it, null, false)
            control = NativeGameWarningDialogChannel(it, engine) { game }
        }
        waitUntil { javascript("window.ticks || 0").toIntOrNull()?.let { it > 1 } == true }
    }

    @After fun tearDown() {
        if (::control.isInitialized) onMain {
            control.dispose()
            (game.parent as? ViewGroup)?.removeView(game)
            game.destroy()
            engine.destroy()
        }
        if (::scenario.isInitialized) scenario.close()
    }

    @Test fun allFourActionsKeepTheRealGameVisibleAndAnimatingAndFinishExactlyOnce() {
        NativeGameWarningDialogSpec.actions.forEachIndexed { index, action ->
            val result = show(index + 1L)
            val before = javascript("window.ticks").toInt()
            SystemClock.sleep(180)
            val during = javascript("window.ticks").toInt()
            assertTrue("requestAnimationFrame must continue underneath the warning", during > before)
            onMain {
                assertTrue(game.isShown)
                assertEquals(View.VISIBLE, game.visibility)
                assertNull(requireView("native-game-warning-$action").contentDescription)
                assertTrue(requireView("native-game-warning-$action").performClick())
                assertEquals(listOf(action), result.values)
                requireNotNull(dialog()).dispatchTouchEvent(event(MotionEvent.ACTION_CANCEL))
                assertNotNull(findView("native-game-warning-input-guard"))
            }
            waitUntil { dialog() == null }
            assertTrue(javascript("window.ticks").toInt() > during)
            assertEquals(0, gameDowns)
        }
    }

    @Test fun transparentProtectionSurvivesHeldPointerAndRestartsAfterRapidTouches() {
        val result = show(20)
        onMain {
            requireView("native-game-warning-acknowledge").performClick()
            requireNotNull(dialog()).dispatchTouchEvent(event(MotionEvent.ACTION_DOWN))
        }
        SystemClock.sleep(800)
        onMain {
            assertNotNull(findView("native-game-warning-input-guard"))
            requireNotNull(dialog()).dispatchTouchEvent(event(MotionEvent.ACTION_UP))
        }
        SystemClock.sleep(350)
        onMain {
            requireNotNull(dialog()).dispatchTouchEvent(event(MotionEvent.ACTION_DOWN))
            requireNotNull(dialog()).dispatchTouchEvent(event(MotionEvent.ACTION_UP))
        }
        SystemClock.sleep(350)
        onMain { assertNotNull(findView("native-game-warning-input-guard")) }
        waitUntil { dialog() == null }
        assertEquals(listOf("acknowledge"), result.values)
        assertEquals(0, gameDowns)
    }

    @Test fun replacingAProtectedWarningIsNotDismissedByItsOldTimerOrOldId() {
        val first = show(30)
        val next = Result()
        onMain {
            requireView("native-game-warning-mute").performClick()
            control.onMethodCall(MethodCall("show", payload(31)), next)
            assertNotNull(findView("native-game-warning-input-guard"))
            assertTrue(next.values.isEmpty())
        }
        waitUntil { findView("native-game-warning-dialog") != null }
        onMain {
            control.onMethodCall(MethodCall("dismiss", mapOf("id" to 30L)), Result())
            assertNotNull(findView("native-game-warning-dialog"))
            assertTrue(next.values.isEmpty())
            requireView("native-game-warning-reloadFrame").performClick()
        }
        waitUntil { dialog() == null }
        assertEquals(listOf("mute"), first.values)
        assertEquals(listOf("reloadFrame"), next.values)
    }

    @Test fun pendingWarningSurvivesBackgroundAndDisposalCompletesItOnlyOnce() {
        val result = show(40)
        onMain {
            control.setForeground(false)
            assertFalse(requireNotNull(dialog()).isShowing)
            assertTrue(result.values.isEmpty())
            control.setForeground(true)
            assertTrue(requireNotNull(dialog()).isShowing)
            assertNotNull(findView("native-game-warning-dialog"))
            control.dispose()
            control.dispose()
            assertNull(dialog())
            assertEquals(listOf(null), result.values)
        }
    }

    @Test fun backgroundDuringTheQuietIntervalCannotStrandATransparentWindowOnResume() {
        show(45)
        onMain {
            requireView("native-game-warning-acknowledge").performClick()
            control.setForeground(false)
        }
        waitUntil { dialog() == null }
        onMain {
            control.setForeground(true)
            assertNull(dialog())
            assertTrue(game.isShown)
        }
    }

    @Test fun anOpenWarningRemeasuresItsCardWhenTheWindowBecomesNarrow() {
        show(46)
        onMain { dialog()?.window?.setLayout(300, 600) }
        instrumentation.waitForIdleSync()
        onMain {
            val root = requireView("native-game-warning-dialog") as ViewGroup
            val card = root.getChildAt(0)
            assertTrue(card.measuredWidth <= root.width - root.paddingLeft - root.paddingRight)
            assertTrue(card.measuredHeight <= root.height - root.paddingTop - root.paddingBottom)
        }
    }

    @Test fun unavailableGameFailsInsteadOfLeavingAnInvisiblePendingWarning() {
        onMain {
            game.visibility = View.INVISIBLE
            val result = Result()
            control.onMethodCall(MethodCall("show", payload(50)), result)
            assertEquals(listOf("native_warning_unavailable"), result.errors)
            assertTrue(result.values.isEmpty())
            assertNull(dialog())
            game.visibility = View.VISIBLE
        }
    }

    private fun show(id: Long): Result {
        val result = Result()
        onMain { control.onMethodCall(MethodCall("show", payload(id)), result) }
        instrumentation.waitForIdleSync()
        onMain {
            assertTrue(result.errors.isEmpty())
            assertTrue(requireNotNull(dialog()).isShowing)
            assertNotNull(findView("native-game-warning-dialog"))
        }
        return result
    }

    private fun payload(id: Long) = mapOf(
        "id" to id, "title" to "大破警告", "headline" to "舰队中存在大破舰娘",
        "body" to "请确认后撤退。", "rows" to listOf("阿武隈改二  7 / 51  未装备损管"),
        "labels" to mapOf("acknowledge" to "确认", "mute" to "本次出击不再提醒", "reloadGame" to "刷新", "reloadFrame" to "刷新框架"),
    )

    private fun event(action: Int) = MotionEvent.obtain(
        SystemClock.uptimeMillis(), SystemClock.uptimeMillis(), action, 2f, 2f, 0,
    )

    private fun dialog(): Dialog? = NativeGameWarningDialogChannel::class.java.getDeclaredField("dialog").let {
        it.isAccessible = true
        it.get(control) as? Dialog
    }

    private fun findView(description: String): View? = dialog()?.window?.decorView?.findViewById(when (description) {
        "native-game-warning-dialog" -> R.id.native_game_warning_dialog
        "native-game-warning-input-guard" -> R.id.native_game_warning_input_guard
        "native-game-warning-acknowledge" -> R.id.native_game_warning_acknowledge
        "native-game-warning-mute" -> R.id.native_game_warning_mute
        "native-game-warning-reloadGame" -> R.id.native_game_warning_reload_game
        "native-game-warning-reloadFrame" -> R.id.native_game_warning_reload_frame
        else -> error("Unknown warning view: $description")
    })

    private fun requireView(description: String) = requireNotNull(findView(description)) { description }

    private fun javascript(script: String): String {
        val complete = CountDownLatch(1)
        var result = ""
        onMain { game.evaluateJavascript(script) { result = it; complete.countDown() } }
        assertTrue("WebView JavaScript did not finish", complete.await(5, TimeUnit.SECONDS))
        return result
    }

    private fun waitUntil(condition: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 5000
        while (SystemClock.uptimeMillis() < deadline) {
            if (condition()) return
            SystemClock.sleep(40)
        }
        fail("Native warning condition timed out")
    }

    private fun onMain(action: (MainActivity) -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            scenario.onActivity(action)
        } else {
            instrumentation.runOnMainSync { scenario.onActivity(action) }
        }
    }

    private class Result : MethodChannel.Result {
        val values = mutableListOf<Any?>()
        val errors = mutableListOf<String>()
        override fun success(result: Any?) { values.add(result) }
        override fun error(code: String, message: String?, details: Any?) { errors.add(code) }
        override fun notImplemented() { fail("Unexpected method") }
    }
}
