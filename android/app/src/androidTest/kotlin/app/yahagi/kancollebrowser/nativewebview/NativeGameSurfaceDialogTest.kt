package app.yahagi.kancollebrowser.nativewebview

import android.app.Dialog
import android.os.Looper
import android.os.SystemClock
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.CheckBox
import android.widget.FrameLayout
import android.widget.TextView
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

/** Local animation and real native modal windows; never touches a game account. */
@RunWith(AndroidJUnit4::class)
class NativeGameSurfaceDialogTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private lateinit var scenario: ActivityScenario<MainActivity>
    private lateinit var engine: FlutterEngine
    private lateinit var game: WebView
    private lateinit var control: NativeGameWarningDialogChannel
    private var gameDowns = 0
    private var available = true

    @Before fun setUp() {
        scenario = ActivityScenario.launch(MainActivity::class.java)
        onMain { activity ->
            game = WebView(activity).apply {
                settings.javaScriptEnabled = true
                setOnTouchListener { _, event ->
                    if (event.actionMasked == MotionEvent.ACTION_DOWN) gameDowns++
                    false
                }
            }
            activity.findViewById<FrameLayout>(android.R.id.content).addView(game,
                FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            game.loadDataWithBaseURL("https://surface-dialog.invalid/", """
                <html><body style="background:#305050"><script>window.ticks=0;
                function frame(){window.ticks++;requestAnimationFrame(frame);}requestAnimationFrame(frame);</script></body></html>
            """.trimIndent(), "text/html", "utf-8", null)
            engine = FlutterEngine(activity, null, false)
            control = NativeGameWarningDialogChannel(activity, engine) { game.takeIf { available } }
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

    @Test fun confirmationReturnsCheckboxOnlyAfterProtectionAndKeepsAnimating() {
        val result = show(payload() + ("checkbox" to mapOf("label" to "以后不再确认", "checked" to false)))
        val before = javascript("window.ticks").toInt()
        SystemClock.sleep(180)
        assertTrue("Background must animate while the modal is open", javascript("window.ticks").toInt() > before)
        onMain {
            assertTrue(game.isShown)
            (find(R.id.native_game_surface_dialog_checkbox) as CheckBox).performClick()
            tagged("surface-dialog-action:confirm").performClick()
            assertTrue(result.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        waitResult(result, mapOf("action" to "confirm", "checked" to true))
        assertTrue(javascript("window.ticks").toInt() > before)
        assertEquals(0, gameDowns)
    }

    @Test fun outsideAndBackCancelWithoutEverReturningTheConfirmAction() {
        val outside = show(payload())
        onMain {
            tap(2f, 2f)
            assertTrue(outside.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        waitResult(outside, null)
        val back = show(payload(2))
        onMain {
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_BACK))
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_BACK))
            assertTrue(back.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        waitResult(back, null)
        assertEquals(0, gameDowns)
    }

    @Test fun nonDismissibleBarrierConsumesTouchButBackStillCancels() {
        val result = show(payload() + ("dismissible" to false))
        onMain { tap(2f, 2f) }
        SystemClock.sleep(700)
        onMain {
            assertTrue(result.values.isEmpty())
            assertNotNull(find(R.id.native_game_surface_dialog))
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_BACK))
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_BACK))
        }
        waitResult(result, null)
        assertEquals(0, gameDowns)
    }

    @Test fun singleChoiceKeepsGroupAndDetailsAndWaitsForHeldPointerToRelease() {
        val result = show(payload() + mapOf(
            "choices" to listOf(mapOf("id" to "mission_1", "label" to "01 · 練習航海", "detail" to "00:15:00", "group" to "镇守府海域")),
            "selectedChoiceId" to "mission_1",
        ))
        onMain {
            val texts = texts(requireNotNull(find(R.id.native_game_surface_dialog)))
            assertTrue(texts.containsAll(listOf("镇守府海域", "01 · 練習航海", "00:15:00")))
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            tagged("surface-dialog-choice:mission_1").performClick()
            assertTrue(result.values.isEmpty())
        }
        SystemClock.sleep(800)
        onMain {
            assertTrue(result.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
        }
        waitResult(result, mapOf("action" to "mission_1", "checked" to false))
        assertEquals(0, gameDowns)
    }

    @Test fun disabledActionAndStaleButtonCannotCommitOrCloseAnotherRequest() {
        val result = show(payload() + ("enabled" to mapOf("confirm" to false)))
        lateinit var oldButton: View
        onMain {
            oldButton = tagged("surface-dialog-action:confirm")
            assertFalse(oldButton.isEnabled)
            oldButton.performClick()
            assertTrue(result.values.isEmpty())
            tagged("surface-dialog-action:cancel").performClick()
        }
        waitResult(result, mapOf("action" to "cancel", "checked" to false))
        val second = show(payload(2))
        onMain {
            oldButton.performClick()
            assertTrue(second.values.isEmpty())
            assertNotNull(find(R.id.native_game_surface_dialog))
            tagged("surface-dialog-action:confirm").performClick()
        }
        waitResult(second, mapOf("action" to "confirm", "checked" to false))
        assertEquals(0, gameDowns)
    }

    @Test fun availabilityImmediatelyReadyDoesNotOpenAWindowOrEnterTheQueue() {
        val result = waitAvailability()
        onMain {
            assertEquals(listOf(true), result.values)
            assertNull(dialog())
            assertTrue(game.isShown)
            assertNoAvailabilityWaits()
        }
    }

    @Test fun availabilityWaitsForBothCreationAndActualVisibility() {
        onMain { available = false }
        val result = waitAvailability()
        SystemClock.sleep(100)
        onMain {
            assertTrue(result.values.isEmpty())
            assertNull(dialog())
            available = true
            game.visibility = View.INVISIBLE
        }
        SystemClock.sleep(100)
        onMain {
            assertTrue(result.values.isEmpty())
            assertEquals(View.INVISIBLE, game.visibility)
            game.visibility = View.VISIBLE
        }
        waitResult(result, true)
        onMain { assertNull(dialog()); assertNoAvailabilityWaits() }
        assertEquals(0, gameDowns)
    }

    @Test fun availabilityTimesOutOnceAndDoesNotPresentWhenTheGameArrivesLate() {
        onMain { available = false }
        val started = SystemClock.uptimeMillis()
        val result = waitAvailability()
        waitResult(result, false)
        assertTrue(SystemClock.uptimeMillis() - started >= 4900)
        onMain {
            assertNull(dialog())
            assertNoAvailabilityWaits()
            available = true
        }
        SystemClock.sleep(100)
        onMain { assertEquals(listOf(false), result.values); assertNull(dialog()) }
    }

    @Test fun availabilityIsCancelledOnBackgroundWithoutResumingTheOldWait() {
        onMain { available = false }
        val result = waitAvailability()
        onMain {
            assertTrue(result.values.isEmpty())
            control.setForeground(false)
            assertEquals(listOf(false), result.values)
            assertNoAvailabilityWaits()
            available = true
            control.setForeground(true)
        }
        SystemClock.sleep(100)
        onMain { assertEquals(listOf(false), result.values); assertNull(dialog()) }
    }

    @Test fun availabilityDisposeReleasesPendingResultsAndCallbacks() {
        onMain { available = false }
        val result = waitAvailability()
        onMain {
            assertTrue(result.values.isEmpty())
            control.dispose()
            assertEquals(listOf(false), result.values)
            assertNoAvailabilityWaits()
            available = true
        }
        SystemClock.sleep(100)
        onMain { assertEquals(listOf(false), result.values); assertNull(dialog()) }
    }

    private fun waitAvailability(): Result {
        val result = Result()
        onMain { control.onMethodCall(MethodCall("waitUntilAvailable", null), result) }
        onMain { assertTrue(result.errors.isEmpty()) }
        return result
    }

    private fun assertNoAvailabilityWaits() {
        val waits = NativeGameWarningDialogChannel::class.java.getDeclaredField("availabilityWaits").let {
            it.isAccessible = true; it.get(control) as Collection<*>
        }
        assertTrue("Availability callbacks must be released", waits.isEmpty())
    }

    private fun payload(id: Long = 1): Map<String, Any> = mapOf(
        "kind" to "surfaceDialog", "id" to id, "title" to "确认刷新", "body" to "游戏继续播放",
        "actions" to listOf("cancel", "confirm"), "labels" to mapOf("cancel" to "取消", "confirm" to "确认"),
    )
    private fun show(payload: Map<String, Any>): Result {
        val result = Result()
        onMain { control.onMethodCall(MethodCall("show", payload), result) }
        instrumentation.waitForIdleSync()
        onMain {
            assertTrue("Native dialog should present: ${result.errors}", result.errors.isEmpty())
            assertNotNull(find(R.id.native_game_surface_dialog))
        }
        return result
    }
    private fun waitResult(result: Result, expected: Any?) = waitUntil {
        var matched = false
        onMain { matched = result.values == listOf(expected) }
        matched
    }
    private fun find(id: Int): View? = dialog()?.window?.decorView?.findViewById(id)
    private fun tagged(tag: String): View = requireNotNull(dialog()?.window?.decorView?.findViewWithTag<View>(tag))
    private fun dialog(): Dialog? = NativeGameWarningDialogChannel::class.java.getDeclaredField("dialog").let {
        it.isAccessible = true; it.get(control) as? Dialog
    }
    private fun tap(x: Float, y: Float) {
        dispatch(MotionEvent.ACTION_DOWN, x, y)
        dispatch(MotionEvent.ACTION_UP, x, y)
    }
    private fun dispatch(action: Int, x: Float, y: Float) {
        val now = SystemClock.uptimeMillis()
        val event = MotionEvent.obtain(now, now, action, x, y, 0)
        try { requireNotNull(dialog()).dispatchTouchEvent(event) } finally { event.recycle() }
    }
    private fun texts(view: View): List<String> = when (view) {
        is TextView -> listOf(view.text.toString())
        is ViewGroup -> (0 until view.childCount).flatMap { texts(view.getChildAt(it)) }
        else -> emptyList()
    }
    private fun javascript(script: String): String {
        val complete = CountDownLatch(1)
        var result = ""
        onMain { game.evaluateJavascript(script) { result = it; complete.countDown() } }
        assertTrue(complete.await(5, TimeUnit.SECONDS))
        return result
    }
    private fun waitUntil(condition: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 6000
        while (SystemClock.uptimeMillis() < deadline) {
            if (condition()) return
            SystemClock.sleep(40)
        }
        fail("Native surface dialog condition timed out")
    }
    private fun onMain(action: (MainActivity) -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) scenario.onActivity(action)
        else instrumentation.runOnMainSync { scenario.onActivity(action) }
    }
    private class Result : MethodChannel.Result {
        val values = mutableListOf<Any?>()
        val errors = mutableListOf<String>()
        override fun success(result: Any?) { values.add(result) }
        override fun error(code: String, message: String?, details: Any?) { errors.add("$code: $message") }
        override fun notImplemented() { fail("Unexpected method") }
    }
}
