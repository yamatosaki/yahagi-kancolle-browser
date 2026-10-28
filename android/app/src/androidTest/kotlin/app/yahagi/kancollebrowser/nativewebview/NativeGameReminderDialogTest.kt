package app.yahagi.kancollebrowser.nativewebview

import android.app.Dialog
import android.os.Build
import android.os.Looper
import android.os.SystemClock
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.FrameLayout
import android.widget.TextView
import android.window.OnBackInvokedCallback
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

/** Real native windows over an entirely local WebView; no account is used. */
@RunWith(AndroidJUnit4::class)
class NativeGameReminderDialogTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private lateinit var scenario: ActivityScenario<MainActivity>
    private lateinit var engine: FlutterEngine
    private lateinit var game: WebView
    private lateinit var currentGame: WebView
    private val extraGames = mutableListOf<WebView>()
    private lateinit var control: NativeGameWarningDialogChannel
    private var available = true
    private var gameDowns = 0

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
            game.loadDataWithBaseURL("https://reminder.invalid/", """
                <html><body style="background:#305050"><script>window.ticks=0;
                function frame(){window.ticks++;requestAnimationFrame(frame);}requestAnimationFrame(frame);</script></body></html>
            """.trimIndent(), "text/html", "utf-8", null)
            engine = FlutterEngine(activity, null, false)
            currentGame = game
            control = NativeGameWarningDialogChannel(activity, engine) { currentGame.takeIf { available } }
        }
        waitUntil { javascript("window.ticks || 0").toIntOrNull()?.let { it > 1 } == true }
    }

    @After fun tearDown() {
        if (::control.isInitialized) onMain {
            control.dispose()
            extraGames.forEach {
                (it.parent as? ViewGroup)?.removeView(it)
                it.destroy()
            }
            extraGames.clear()
            (game.parent as? ViewGroup)?.removeView(game)
            game.destroy()
            engine.destroy()
        }
        if (::scenario.isInitialized) scenario.close()
    }

    @Test fun noticeConfirmationWaitsForQuietWhileTheGameKeepsAnimating() {
        val result = showNotice("debuff", 1)
        waitView(R.id.native_game_reminder_debuff)
        val before = javascript("window.ticks").toInt()
        onMain {
            assertTrue(game.isShown)
            assertEquals(View.VISIBLE, game.visibility)
            requireView(R.id.native_game_reminder_acknowledge).performClick()
            assertTrue(result.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        waitResult(result, "acknowledge")
        onMain { assertNull(dialog()) }
        assertTrue(javascript("window.ticks").toInt() > before)
        assertEquals(0, gameDowns)
    }

    @Test fun onlyAnOutsideTapConfirmsNotCardBlankSpaceOrADrag() {
        val result = showNotice("newShip", 1)
        waitView(R.id.native_game_reminder_new_ship)
        onMain {
            val root = requireView(R.id.native_game_reminder_new_ship) as ViewGroup
            val card = root.getChildAt(0)
            val position = IntArray(2)
            card.getLocationOnScreen(position)
            tap(position[0] + 3f, position[1] + 3f)
            assertNotNull(find(R.id.native_game_reminder_new_ship))
            assertTrue(result.values.isEmpty())
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            dispatch(MotionEvent.ACTION_MOVE, 202f, 2f)
            dispatch(MotionEvent.ACTION_UP, 202f, 2f)
            assertNotNull(find(R.id.native_game_reminder_new_ship))
            assertTrue(result.values.isEmpty())
            val diagonal = ViewConfiguration.get(root.context).scaledTouchSlop * 0.8f
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            dispatch(MotionEvent.ACTION_MOVE, 2f + diagonal, 2f + diagonal)
            dispatch(MotionEvent.ACTION_UP, 2f + diagonal, 2f + diagonal)
            assertNotNull(find(R.id.native_game_reminder_new_ship))
            assertTrue(result.values.isEmpty())
            tap(2f, 2f)
            assertNotNull(find(R.id.native_game_warning_input_guard))
            assertTrue(result.values.isEmpty())
        }
        waitResult(result, "acknowledge")
        assertEquals(0, gameDowns)
    }

    @Test fun backKeyAndCommittedGestureCallbacksBothUseTheQuietProtection() {
        val keyed = showNotice("debuff", 1)
        waitView(R.id.native_game_reminder_debuff)
        onMain {
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_BACK))
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_BACK))
            assertTrue(keyed.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        waitResult(keyed, "acknowledge")
        val gestured = showNotice("newShip", 1)
        waitView(R.id.native_game_reminder_new_ship)
        onMain {
            if (Build.VERSION.SDK_INT >= 33) {
                val field = NativeGameWarningDialogChannel::class.java.getDeclaredField("backCallback").apply { isAccessible = true }
                (field.get(control) as OnBackInvokedCallback).onBackInvoked()
            } else {
                @Suppress("DEPRECATION")
                requireNotNull(dialog()).onBackPressed()
            }
            assertTrue(gestured.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        waitResult(gestured, "acknowledge")
    }

    @Test fun battlePreemptsAndBothUnconfirmedNoticesResumeInOrder() {
        val debuff = showNotice("debuff", 1)
        val firstWindow = dialog()
        val ship = showNotice("newShip", 1)
        val battle = showBattle(1)
        waitView(R.id.native_game_warning_dialog)
        onMain {
            assertSame(firstWindow, dialog())
            assertTrue(debuff.values.isEmpty())
            assertTrue(ship.values.isEmpty())
            requireView(R.id.native_game_warning_acknowledge).performClick()
            assertEquals(listOf("acknowledge"), battle.values)
        }
        waitView(R.id.native_game_reminder_debuff)
        onMain {
            assertSame(firstWindow, dialog())
            assertTrue(debuff.values.isEmpty())
            requireView(R.id.native_game_reminder_acknowledge).performClick()
        }
        waitView(R.id.native_game_reminder_new_ship)
        assertEquals(listOf("acknowledge"), debuff.values)
        onMain { requireView(R.id.native_game_reminder_acknowledge).performClick() }
        waitResult(ship, "acknowledge")
    }

    @Test fun anOldButtonAndOldKindCannotCloseBattleOrTheResumedNotice() {
        val debuff = showNotice("debuff", 1)
        lateinit var stale: View
        onMain { stale = requireView(R.id.native_game_reminder_acknowledge) }
        val battle = showBattle(1)
        onMain {
            stale.performClick()
            dismiss("newShip", 1)
            assertTrue(battle.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_dialog))
            requireView(R.id.native_game_warning_acknowledge).performClick()
        }
        waitView(R.id.native_game_reminder_debuff)
        onMain {
            stale.performClick()
            assertTrue(debuff.values.isEmpty())
            assertNotNull(find(R.id.native_game_reminder_debuff))
            requireView(R.id.native_game_reminder_acknowledge).performClick()
        }
        waitResult(debuff, "acknowledge")
    }

    @Test fun heldProtectionFinishesBeforeTheQueuedBattleAndNoticeAppear() {
        val debuff = showNotice("debuff", 1)
        onMain {
            requireView(R.id.native_game_reminder_acknowledge).performClick()
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
        }
        val ship = showNotice("newShip", 1)
        val battle = showBattle(1)
        SystemClock.sleep(800)
        onMain {
            assertNotNull(find(R.id.native_game_warning_input_guard))
            assertTrue(debuff.values.isEmpty())
            assertTrue(battle.values.isEmpty())
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
        }
        waitView(R.id.native_game_warning_dialog)
        assertEquals(listOf("acknowledge"), debuff.values)
        onMain { requireView(R.id.native_game_warning_acknowledge).performClick() }
        waitView(R.id.native_game_reminder_new_ship)
        onMain { requireView(R.id.native_game_reminder_acknowledge).performClick() }
        waitResult(ship, "acknowledge")
    }

    @Test fun cancellationDuringGuardDoesNotAcknowledgeOrReleaseAHeldPointerEarly() {
        val debuff = showNotice("debuff", 1)
        onMain {
            requireView(R.id.native_game_reminder_acknowledge).performClick()
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            dismiss("debuff", 1)
            assertEquals(listOf(null), debuff.values)
        }
        SystemClock.sleep(800)
        onMain {
            assertNotNull(find(R.id.native_game_warning_input_guard))
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
        }
        waitUntil { var gone = false; onMain { gone = dialog() == null }; gone }
        assertEquals(listOf(null), debuff.values)
    }

    @Test fun queuedCancellationAndOwnerChangesSettlePendingRequestsWithoutAcknowledging() {
        val battle = showBattle(1)
        val debuff = showNotice("debuff", 1)
        val ship = showNotice("newShip", 1)
        onMain {
            dismiss("debuff", 1)
            assertEquals(listOf(null), debuff.values)
            assertTrue(battle.values.isEmpty())
            control.setForeground(false)
            available = false
            control.setForeground(true)
            assertNull(dialog())
            assertEquals(listOf(null), battle.values)
            assertEquals(listOf(null), ship.values)
            control.dispose()
            assertEquals(1, ship.values.size)
        }
    }

    @Test fun changingTheOwnerDuringAHeldGuardCancelsReadingButKeepsGlobalProtection() {
        val debuff = showNotice("debuff", 1)
        onMain {
            requireView(R.id.native_game_reminder_acknowledge).performClick()
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            available = false
            control.setForeground(true)
            assertEquals(listOf(null), debuff.values)
        }
        SystemClock.sleep(800)
        onMain {
            assertNotNull(find(R.id.native_game_warning_input_guard))
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
        }
        waitUntil { var gone = false; onMain { gone = dialog() == null }; gone }
        assertEquals(listOf(null), debuff.values)
    }

    @Test fun aQueuedNoticeCanUpdateWithoutChangingTheCurrentBattle() {
        showBattle(1)
        val ship = showNotice("newShip", 1)
        onMain {
            control.onMethodCall(MethodCall("update", notice("newShip", 1) + ("body" to "updated ship body")), Result())
            assertNotNull(find(R.id.native_game_warning_dialog))
            requireView(R.id.native_game_warning_acknowledge).performClick()
        }
        waitView(R.id.native_game_reminder_new_ship)
        onMain {
            assertTrue(texts(requireView(R.id.native_game_reminder_new_ship)).contains("updated ship body"))
            requireView(R.id.native_game_reminder_acknowledge).performClick()
        }
        waitResult(ship, "acknowledge")
    }

    @Test fun changingAnUnconfirmedOwnerKeepsTheNewOwnersQueuedReminder() {
        val oldShip = showNotice("newShip", 1)
        val oldDebuff = showNotice("debuff", 2)
        val originalWindow = dialog()
        replaceGameOwner()
        val newDebuff = showNotice("debuff", 3)
        onMain {
            control.setForeground(true)
            assertEquals(listOf(null), oldShip.values)
            assertEquals(listOf(null), oldDebuff.values)
            assertTrue(newDebuff.values.isEmpty())
            assertSame(originalWindow, dialog())
            assertNotNull(find(R.id.native_game_reminder_debuff))
            requireView(R.id.native_game_reminder_acknowledge).performClick()
        }
        waitResult(newDebuff, "acknowledge")
        onMain { assertNull(dialog()) }
    }

    @Test fun anUnconfirmedHeldContactSurvivesOwnerChangesUntilUpAndQuiet() {
        val oldShip = showNotice("newShip", 1)
        onMain { dispatch(MotionEvent.ACTION_DOWN, 2f, 2f) }
        replaceGameOwner()
        val newDebuff = showNotice("debuff", 3)
        onMain {
            control.setForeground(true)
            assertEquals(listOf(null), oldShip.values)
            assertTrue(newDebuff.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        SystemClock.sleep(800)
        onMain {
            assertNotNull(find(R.id.native_game_warning_input_guard))
            assertTrue(newDebuff.values.isEmpty())
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        waitView(R.id.native_game_reminder_debuff)
        onMain { requireView(R.id.native_game_reminder_acknowledge).performClick() }
        waitResult(newDebuff, "acknowledge")
        assertEquals(0, gameDowns)
    }

    @Test fun cancellingAnUnconfirmedHeldContactKeepsTheProtectionUntilUpAndQuiet() {
        val ship = showNotice("newShip", 1)
        onMain {
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            dismiss("newShip", 1)
            assertEquals(listOf(null), ship.values)
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        SystemClock.sleep(800)
        onMain {
            assertNotNull(find(R.id.native_game_warning_input_guard))
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        waitUntil { var gone = false; onMain { gone = dialog() == null }; gone }
        assertEquals(listOf(null), ship.values)
        assertEquals(0, gameDowns)
    }

    private fun replaceGameOwner() {
        onMain { activity ->
            currentGame = WebView(activity).apply {
                setOnTouchListener { _, event ->
                    if (event.actionMasked == MotionEvent.ACTION_DOWN) gameDowns++
                    false
                }
            }
            extraGames.add(currentGame)
            activity.findViewById<FrameLayout>(android.R.id.content).addView(currentGame,
                FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            currentGame.loadData("<html><body>next owner</body></html>", "text/html", "utf-8")
        }
        instrumentation.waitForIdleSync()
        onMain {
            assertTrue(currentGame.isAttachedToWindow)
            assertTrue(currentGame.isShown)
        }
    }

    private fun showNotice(kind: String, id: Long): Result = invokeShow(notice(kind, id))
    private fun showBattle(id: Long): Result = invokeShow(mapOf(
        "id" to id, "title" to "大破警告", "headline" to "请撤退", "body" to "body", "rows" to emptyList<String>(),
        "labels" to NativeGameWarningDialogSpec.actions.associateWith { it },
    ))
    private fun invokeShow(payload: Map<String, Any>): Result {
        val result = Result()
        onMain { control.onMethodCall(MethodCall("show", payload), result) }
        instrumentation.waitForIdleSync()
        onMain { assertTrue(result.errors.isEmpty()) }
        return result
    }
    private fun notice(kind: String, id: Long): Map<String, Any> = mapOf(
        "kind" to kind, "id" to id, "title" to kind, "body" to "local reminder body",
        "actions" to listOf("acknowledge"), "labels" to mapOf("acknowledge" to "确认"),
    )
    private fun dismiss(kind: String, id: Long) {
        control.onMethodCall(MethodCall("dismiss", mapOf("kind" to kind, "id" to id)), Result())
    }
    private fun waitView(id: Int) = waitUntil { var shown = false; onMain { shown = find(id) != null }; shown }
    private fun waitResult(result: Result, expected: String) = waitUntil {
        var matched = false
        onMain { matched = result.values == listOf(expected) }
        matched
    }
    private fun find(id: Int): View? = dialog()?.window?.decorView?.findViewById(id)
    private fun requireView(id: Int): View = requireNotNull(find(id))
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
        fail("Native reminder condition timed out")
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
