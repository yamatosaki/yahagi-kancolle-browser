package app.yahagi.kancollebrowser.nativewebview

import android.app.Dialog
import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.util.Log
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.webkit.WebView
import android.widget.CheckBox
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
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
    private var protectionClock: Long? = null

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
            control = NativeGameWarningDialogChannel(activity, engine,
                releasePolicy = NativeGameDialogReleasePolicy { protectionClock ?: SystemClock.uptimeMillis() },
            ) { game.takeIf { available } }
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

    @Test fun ordinarySurfaceChoiceClosesImmediatelyWhileConfirmationStillGuardsHeldTouch() {
        val choice = show(payload() + mapOf(
            "protectInputOnDismiss" to false,
            "choices" to listOf(mapOf("id" to "fuel", "label" to "燃料")),
        ))
        onMain {
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            assertOutsideIgnored(choice)
            tagged("surface-dialog-choice:fuel").performClick()
            assertEquals(listOf(mapOf("action" to "fuel", "checked" to false)), choice.values)
            assertNull(dialog())
        }

        val confirmation = show(payload(2L))
        onMain {
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            tagged("surface-dialog-action:confirm").performClick()
            assertTrue(confirmation.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
            assertTrue(confirmation.values.isEmpty())
        }
        waitResult(confirmation, mapOf("action" to "confirm", "checked" to false))
        assertEquals(0, gameDowns)
    }

    @Test fun repeatedSurfaceTouchesFinishAtTheProtectionDeadlineWithoutTouchThrough() {
        onMain { protectionClock = 0L }
        val result = show(payload() + ("postTouchProtectionActions" to listOf("confirm")))
        onMain {
            tagged("surface-dialog-action:confirm").performClick()
            for (upAt in listOf(400L, 800L, 1200L, 1600L, 1999L)) {
                protectionClock = upAt
                tap(2f, 2f)
                assertTrue(result.values.isEmpty())
                assertNotNull(find(R.id.native_game_warning_input_guard))
            }
            protectionClock = 2000L
            tap(2f, 2f)
            assertEquals(0, gameDowns)
        }
        waitResult(result, mapOf("action" to "confirm", "checked" to false))
        onMain {
            assertNull(dialog())
            assertEquals(1, result.values.size)
            assertEquals(0, gameDowns)
        }
        val point = onMainValue { screenPoint(game) }
        tapScreen(point.first, point.second)
        waitUntil { onMainValue { gameDowns == 1 } }
    }

    @Test fun expiredSurfaceProtectionKeepsAHeldGestureUntilItsFinalUp() {
        onMain { protectionClock = 0L }
        val result = show(payload())
        onMain {
            tagged("surface-dialog-action:confirm").performClick()
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            protectionClock = 2500L
            dispatch(MotionEvent.ACTION_MOVE, 2f, 2f)
            assertTrue(result.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
            assertEquals(0, gameDowns)
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
        }
        waitResult(result, mapOf("action" to "confirm", "checked" to false))
        onMain {
            assertNull(dialog())
            assertEquals(1, result.values.size)
            assertEquals(0, gameDowns)
        }
    }

    @Test fun framePromptCancelAndBackReleaseBeforeTheNextIndependentTouch() {
        for ((index, action) in listOf("cancel", "back").withIndex()) {
            val beforeGameDowns = onMainValue { gameDowns }
            val result = show(payload(index + 1L) + ("postTouchProtectionActions" to listOf("confirm")))
            val releasedAt = if (action == "back") {
                var backUpAt = 0L
                onMain {
                    requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_BACK))
                    backUpAt = SystemClock.uptimeMillis()
                    requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_BACK))
                }
                backUpAt
            } else {
                val point = onMainValue { screenPoint(tagged("surface-dialog-action:cancel")) }
                tapScreen(point.first, point.second)
            }
            // A zero-delay release is drained by the next main-loop barrier;
            // the old 600 ms invisible guard would still own this window.
            instrumentation.waitForIdleSync()
            onMain {
                val expected = if (action == "cancel") mapOf("action" to "cancel", "checked" to false) else null
                assertEquals("$action must settle without an extra quiet interval", listOf(expected), result.values)
                assertNull("$action must release the transparent window", dialog())
                assertEquals(beforeGameDowns, gameDowns)
                Log.i("FramePromptCancel", "action=$action upToResultMs=${result.completedAt - releasedAt}")
            }
            val gamePoint = onMainValue { screenPoint(game) }
            tapScreen(gamePoint.first, gamePoint.second)
            onMain {
                assertEquals("The next independent touch after $action must reach the game", beforeGameDowns + 1, gameDowns)
                Log.i("FramePromptCancel", "action=$action upToNextGameTouchMs=${SystemClock.uptimeMillis() - releasedAt}")
            }
        }
    }

    @Test fun framePromptCancellationKeepsEveryHeldPointerUntilFinalUpOrCancel() {
        for ((index, finish) in listOf("up", "cancel").withIndex()) {
            val result = show(payload(index + 1L) + ("postTouchProtectionActions" to listOf("confirm")))
            onMain {
                dispatchPointers(MotionEvent.ACTION_DOWN, intArrayOf(0))
                dispatchPointers(MotionEvent.ACTION_POINTER_DOWN, intArrayOf(0, 4), actionIndex = 1)
                tagged("surface-dialog-action:cancel").performClick()
                assertTrue(result.values.isEmpty())
                assertNotNull(find(R.id.native_game_warning_input_guard))
                if (finish == "up") {
                    dispatchPointers(MotionEvent.ACTION_POINTER_UP, intArrayOf(0, 4), actionIndex = 0)
                    assertTrue("The remaining held contact must stay protected", result.values.isEmpty())
                    assertNotNull(find(R.id.native_game_warning_input_guard))
                    dispatchPointers(MotionEvent.ACTION_UP, intArrayOf(4))
                } else {
                    dispatchPointers(MotionEvent.ACTION_CANCEL, intArrayOf(0, 4))
                }
                assertEquals(0, gameDowns)
            }
            instrumentation.waitForIdleSync()
            onMain {
                assertEquals(listOf(mapOf("action" to "cancel", "checked" to false)), result.values)
                assertNull(dialog())
                assertEquals(0, gameDowns)
                Log.i("FramePromptCancel", "heldFinish=$finish completed=true gameDowns=$gameDowns")
            }
        }
    }

    @Test fun outsideTapsLongPressAndMultitouchDoNothingEvenWhenLegacyDismissibleIsTrue() {
        val result = show(payload() + ("dismissible" to true))
        val point = onMainValue { backdropScreenPoint() }
        repeat(3) { tapScreen(point.first, point.second) }
        val heldAt = SystemClock.uptimeMillis()
        onMain { dispatchPointers(MotionEvent.ACTION_DOWN, intArrayOf(0)) }
        waitUntil { SystemClock.uptimeMillis() - heldAt >= NativeGameWarningDialogChannel.PROTECTION_MILLIS + 100 }
        onMain {
            dispatchPointers(MotionEvent.ACTION_MOVE, intArrayOf(0))
            dispatchPointers(MotionEvent.ACTION_POINTER_DOWN, intArrayOf(0, 4), actionIndex = 1)
            assertOutsideIgnored(result)
            dispatchPointers(MotionEvent.ACTION_POINTER_UP, intArrayOf(0, 4), actionIndex = 0)
            dispatchPointers(MotionEvent.ACTION_UP, intArrayOf(4))
            assertOutsideIgnored(result)
            tagged("surface-dialog-action:confirm").performClick()
        }
        waitResult(result, mapOf("action" to "confirm", "checked" to false))
        onMain { assertNull(dialog()); assertEquals(0, gameDowns) }
    }

    @Test fun consumedConfirmationTouchCannotBeReclassifiedAsOutside() {
        val result = show(payload())
        waitForStableTarget("surface-dialog-action:confirm")
        var targetDowns = 0
        var targetUps = 0
        onMain {
            val target = tagged("surface-dialog-action:confirm")
            val location = IntArray(2).also { target.getLocationInWindow(it) }
            val localX = location[0] + target.width / 2f
            val localY = location[1] + target.height / 2f
            val current = requireNotNull(dialog())
            target.setOnTouchListener { _, event ->
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> targetDowns++
                    MotionEvent.ACTION_UP -> targetUps++
                }
                false
            }
            val downTime = SystemClock.uptimeMillis()
            for (action in listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP)) {
                // A transformed/stale screen-space sample must never overrule
                // the real Button that consumed the window-local gesture.
                val event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action, 2f, 2f, 0)
                try {
                    event.source = InputDevice.SOURCE_TOUCHSCREEN
                    event.offsetLocation(localX - 2f, localY - 2f)
                    assertEquals(localX, event.x, 0.01f)
                    assertEquals(localY, event.y, 0.01f)
                    assertEquals(2f, event.rawX, 0.01f)
                    assertEquals(2f, event.rawY, 0.01f)
                    current.dispatchTouchEvent(event)
                } finally { event.recycle() }
            }
            assertEquals(1, targetDowns)
            assertEquals(1, targetUps)
            assertTrue("The result must still wait for input protection", result.values.isEmpty())
        }
        waitUntil { onMainValue { result.values.isNotEmpty() } }
        onMain {
            assertEquals(listOf(mapOf("action" to "confirm", "checked" to false)), result.values)
            assertEquals(0, gameDowns)
        }
    }

    @Test fun nativeDialogPreservesTheActivityImmersiveSystemBars() {
        prepareLandscapeImmersiveActivity()
        show(payload())
        val window = onMainValue { requireNotNull(dialog()?.window) }
        waitForStableTarget("surface-dialog-action:confirm")
        repeat(3) {
            onMain {
                val insets = requireNotNull(ViewCompat.getRootWindowInsets(window.decorView))
                assertFalse("Opening the independent dialog must not reveal the status bar: ${barDiagnostics(window)}",
                    insets.isVisible(WindowInsetsCompat.Type.statusBars()))
                assertFalse("Opening the independent dialog must not reveal gesture navigation: ${barDiagnostics(window)}",
                    insets.isVisible(WindowInsetsCompat.Type.navigationBars()))
            }
            SystemClock.sleep(80)
        }
    }

    @Test fun confirmationScreenBoundsStayStableWhenSystemBarsAreShownAndHidden() {
        prepareLandscapeImmersiveActivity()
        show(payload() + ("checkbox" to mapOf("label" to "以后不再确认", "checked" to false)))
        val window = onMainValue { requireNotNull(dialog()?.window) }
        onMain { hideSystemBars(window) }
        waitForSystemBars(window, visible = false)
        onMain { WindowInsetsControllerCompat(window, window.decorView).show(WindowInsetsCompat.Type.navigationBars()) }
        waitForNavigationBar(window, visible = true)
        waitForStableTarget("surface-dialog-action:confirm")
        val shown = onMainValue { screenBounds(tagged("surface-dialog-action:confirm")) }
        onMain { hideSystemBars(window) }
        waitForSystemBars(window, visible = false)
        waitForStableTarget("surface-dialog-action:confirm")
        val hidden = onMainValue { screenBounds(tagged("surface-dialog-action:confirm")) }
        assertEquals("Temporarily revealing system bars must not move the confirmation hit target", shown, hidden)
    }

    @Test fun frameRefreshRealScreenTapAfterSystemBarsChangeReturnsConfirmAndCheckbox() {
        confirmFromRealScreenAfterSystemBarsChange(
            payload() + mapOf(
                "title" to "确认刷新框架",
                "body" to "刷新游戏框架，游戏继续播放。",
                "checkbox" to mapOf("label" to "以后不再确认框架刷新", "checked" to false),
                "labels" to mapOf("cancel" to "取消", "confirm" to "确认刷新"),
            ),
        )
    }

    @Test fun fullscreenExitRealScreenTapAfterSystemBarsChangeReturnsConfirmAndCheckbox() {
        confirmFromRealScreenAfterSystemBarsChange(
            payload() + mapOf(
                "title" to "退出全屏",
                "body" to "是否退出游戏全屏显示？",
                "checkbox" to mapOf("label" to "以后不再确认退出全屏", "checked" to false),
                "labels" to mapOf("cancel" to "取消", "confirm" to "退出全屏"),
            ),
        )
    }

    @Test fun confirmedRealTouchKeepsTheTransparentGuardUntil600MillisAfterTheLastUp() {
        prepareLandscapeImmersiveActivity()
        val result = show(payload())
        waitForStableTarget("surface-dialog-action:confirm")
        val point = onMainValue { screenPoint(tagged("surface-dialog-action:confirm")) }
        tapScreen(point.first, point.second)
        waitForInputGuard()
        val downTime = SystemClock.uptimeMillis()
        injectScreen(MotionEvent.ACTION_DOWN, point.first, point.second, downTime)
        SystemClock.sleep(NativeGameWarningDialogChannel.PROTECTION_MILLIS + 100)
        onMain {
            assertTrue("A held contact must keep the confirmation result protected", result.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
            assertEquals("Neither the confirmation nor a held guard touch may reach the game", 0, gameDowns)
        }
        val releasedAt = injectScreen(MotionEvent.ACTION_UP, point.first, point.second, downTime)
        SystemClock.sleep(400)
        onMain {
            assertTrue("The guard must survive until 600 ms after the real final UP", result.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
            assertEquals(0, gameDowns)
        }
        waitResult(result, mapOf("action" to "confirm", "checked" to false))
        onMain {
            assertTrue("The confirmation completed before the quiet interval elapsed",
                result.completedAt - releasedAt >= NativeGameWarningDialogChannel.PROTECTION_MILLIS)
            assertNull(dialog())
            assertEquals(0, gameDowns)
        }
        // Prove that the real screen coordinate can reach the live game once the guard is gone.
        tapScreen(point.first, point.second)
        waitUntil { onMainValue { gameDowns == 1 } }
    }

    @Test fun realScreenBackdropAfterSystemBarsChangeStaysOpenWithoutTouchThrough() {
        prepareLandscapeImmersiveActivity()
        val result = show(payload() + ("checkbox" to mapOf("label" to "以后不再确认", "checked" to false)))
        cycleDialogSystemBars()
        waitForStableTarget("surface-dialog-action:confirm")
        val point = onMainValue {
            val container = requireNotNull(find(R.id.native_game_surface_dialog)) as ViewGroup
            val location = IntArray(2).also { container.getLocationOnScreen(it) }
            Pair(location[0] + container.width / 2f,
                location[1] + (container.paddingTop / 2f).coerceAtLeast(1f))
        }
        tapScreen(point.first, point.second)
        onMain {
            assertOutsideIgnored(result)
            assertEquals(0, gameDowns)
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_BACK))
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_BACK))
        }
        waitResult(result, null)
        onMain { assertNull(dialog()); assertEquals(0, gameDowns) }
    }

    @Test fun frameRefreshAfterRealBottomSwipeReturnsConfirmAndCheckbox() {
        confirmAfterRealBottomSwipe("frame-refresh", payload() + mapOf(
            "title" to "确认刷新框架",
            "body" to "刷新游戏框架，游戏继续播放。",
            "checkbox" to mapOf("label" to "以后不再确认框架刷新", "checked" to false),
            "labels" to mapOf("cancel" to "取消", "confirm" to "确认刷新"),
        ))
    }

    @Test fun fullscreenExitAfterRealBottomSwipeReturnsConfirmAndCheckbox() {
        confirmAfterRealBottomSwipe("fullscreen-exit", payload() + mapOf(
            "title" to "退出全屏",
            "body" to "是否退出游戏全屏显示？",
            "checkbox" to mapOf("label" to "以后不再确认退出全屏", "checked" to false),
            "labels" to mapOf("cancel" to "取消", "confirm" to "退出全屏"),
        ))
    }

    @Test fun realBottomSwipeOutsideKeepsDialogOpenAndCancelStillWorks() {
        prepareLandscapeImmersiveActivity()
        for ((index, action) in listOf("cancel", "backdrop").withIndex()) {
            val kind = "bottom-swipe-$action"
            val beforeGameDowns = onMainValue { gameDowns }
            val result = show(payload((index + 1).toLong()) +
                ("checkbox" to mapOf("label" to "以后不再确认", "checked" to false)))
            val before = revealNavigationWithRealBottomSwipe(kind, result, beforeGameDowns)
            val point = onMainValue {
                if (action == "cancel") screenPoint(tagged("surface-dialog-action:cancel"))
                else backdropScreenPoint()
            }
            assertTransientNavigationShown(kind, "before-$action")
            var releasedAt = tapScreen(point.first, point.second)
            if (action == "backdrop") {
                onMain { assertOutsideIgnored(result, beforeGameDowns) }
                val cancel = onMainValue { screenPoint(tagged("surface-dialog-action:cancel")) }
                releasedAt = tapScreen(cancel.first, cancel.second)
            }
            val expected = mapOf("action" to "cancel", "checked" to false)
            val recoveryBounds = before.getValue("confirm")
            val recoveryPoint = Pair(recoveryBounds.exactCenterX(), recoveryBounds.exactCenterY())
            finishProtectedRealTouch(kind, result, expected, releasedAt, recoveryPoint, beforeGameDowns)
        }
    }

    @Test fun realBottomSwipeAutoHideKeepsConfirmationTouchableAndRestoresGameInput() {
        confirmAfterRealBottomSwipe("after-transient-auto-hide", payload() + mapOf(
            "title" to "确认刷新框架",
            "checkbox" to mapOf("label" to "以后不再确认框架刷新", "checked" to false),
        ), waitForAutoHide = true)
    }

    @Test fun outsideDoesNotCloseAndBackStillCancelsWithoutConfirm() {
        val outside = show(payload())
        onMain {
            tap(2f, 2f)
            assertOutsideIgnored(outside)
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_BACK))
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_BACK))
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

    @Test fun legacyDismissibleTrueCannotEnableOutsideDismissalAndBackStillCancels() {
        val result = show(payload() + ("dismissible" to true))
        onMain {
            tap(2f, 2f)
            assertOutsideIgnored(result)
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

    private fun prepareLandscapeImmersiveActivity() {
        onMain { it.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE }
        waitUntil { onMainValue { game.width > game.height && game.height > 0 && !game.isLayoutRequested } }
        val window = onMainValue { activity -> activity.window.also { hideSystemBars(it) } }
        waitForSystemBars(window, visible = false)
    }

    private fun confirmAfterRealBottomSwipe(kind: String, spec: Map<String, Any>, waitForAutoHide: Boolean = false) {
        prepareLandscapeImmersiveActivity()
        val beforeGameDowns = onMainValue { gameDowns }
        val result = show(spec)
        val before = revealNavigationWithRealBottomSwipe(kind, result, beforeGameDowns)
        if (waitForAutoHide) {
            // Transient bars must disappear by SystemUI's timeout, without a controller.hide() shortcut.
            waitForSystemTransientNavigation(kind, "auto-hidden", visible = false, timeoutMillis = 10000)
            waitForStableTarget("surface-dialog-action:confirm")
            assertEquals("Automatically hiding transient navigation must preserve all hit targets", before, surfaceTouchBounds())
            saveNavigationScreenshot(kind, "auto-hidden")
        }
        val checkbox = onMainValue { screenPoint(requireNotNull(find(R.id.native_game_surface_dialog_checkbox))) }
        tapScreen(checkbox.first, checkbox.second)
        waitUntil { onMainValue { (find(R.id.native_game_surface_dialog_checkbox) as? CheckBox)?.isChecked == true } }
        assertSurfaceStillOpen(kind, "checkbox-checked", result, beforeGameDowns)
        assertEquals("The checkbox touch must preserve the action hit targets", before, surfaceTouchBounds())
        if (!waitForAutoHide) assertTransientNavigationShown(kind, "before-confirm")
        val confirm = onMainValue { screenPoint(tagged("surface-dialog-action:confirm")) }
        val releasedAt = tapScreen(confirm.first, confirm.second)
        finishProtectedRealTouch(kind, result, mapOf("action" to "confirm", "checked" to true),
            releasedAt, confirm, beforeGameDowns)
    }

    private fun revealNavigationWithRealBottomSwipe(kind: String, result: Result, beforeGameDowns: Int): Map<String, Rect> {
        // Layout can settle before the first cold-start window gains focus.
        // A system gesture must target the actual foreground dialog.
        waitUntil { onMainValue { dialog()?.window?.decorView?.hasWindowFocus() == true } }
        waitForStableTarget("surface-dialog-action:confirm")
        waitForSystemTransientNavigation(kind, "before-swipe", visible = false, timeoutMillis = 10000)
        val before = surfaceTouchBounds()
        Log.i("NativeNavRetest", "kind=$kind phase=before-swipe bounds=$before")
        swipeUpFromBottomEdge(kind)
        waitForSystemTransientNavigation(kind, "transient-shown", visible = true, timeoutMillis = 3000)
        // Capture the actual SystemUI overlay while its transient state is still present.
        saveNavigationScreenshot(kind, "transient-shown")
        assertSurfaceStillOpen(kind, "after-swipe", result, beforeGameDowns)
        waitForStableTarget("surface-dialog-action:confirm")
        val after = surfaceTouchBounds()
        Log.i("NativeNavRetest", "kind=$kind phase=after-swipe bounds=$after")
        assertEquals("A real bottom-edge swipe must not move checkbox, confirm or cancel hit targets", before, after)
        return before
    }

    private fun swipeUpFromBottomEdge(kind: String) {
        // Screenshot dimensions describe the physical screen after rotation, including the hidden bar area.
        val screenshot = requireNotNull(instrumentation.uiAutomation.takeScreenshot()) { "Cannot read the real screen dimensions" }
        val width = screenshot.width
        val height = screenshot.height
        screenshot.recycle()
        val density = onMainValue { it.resources.displayMetrics.density }
        val x = width / 2f
        val startY = height - 1f
        val endY = startY - (80f * density).coerceAtMost(height / 4f)
        Log.i("NativeNavRetest", "kind=$kind phase=swipe screen=${width}x$height from=($x,$startY) to=($x,$endY)")
        val downTime = SystemClock.uptimeMillis()
        injectScreen(MotionEvent.ACTION_DOWN, x, startY, downTime)
        try {
            for (step in 1..10) {
                SystemClock.sleep(18)
                injectScreen(MotionEvent.ACTION_MOVE, x, startY + (endY - startY) * step / 10f, downTime)
            }
        } finally {
            injectScreen(MotionEvent.ACTION_UP, x, endY, downTime)
        }
    }

    private fun systemTransientNavigationLines(): List<String> {
        val dump = ParcelFileDescriptor.AutoCloseInputStream(
            instrumentation.uiAutomation.executeShellCommand(
                "dumpsys activity service com.android.systemui/.SystemUIService NavigationBarController",
            ),
        ).bufferedReader().use { it.readText() }
        // App WindowInsets may deliberately keep reporting hidden during a real transient overlay.
        // SystemUI records both visibility and gesture origin on API 34.
        // An unsupported diagnostic must fail, never fall back to controller.show().
        val lines = dump.lineSequence().map { it.trim() }.toList()
        val start = lines.indexOf("NavigationBar (displayId=0):")
        assertTrue("SystemUI has no navigation diagnostics for display 0", start >= 0)
        val state = lines.drop(start + 1).takeWhile { !it.startsWith("NavigationBar (displayId=") }
            .filter { it.startsWith("mTransientShown=") || it.startsWith("mTransientShownFromGestureOnSystemBar=") }
        assertTrue("SystemUI does not expose transient visibility and gesture origin: $state",
            state.any { it.startsWith("mTransientShown=") } &&
                state.any { it.startsWith("mTransientShownFromGestureOnSystemBar=") })
        return state
    }

    private fun waitForSystemTransientNavigation(kind: String, phase: String, visible: Boolean, timeoutMillis: Long) {
        val deadline = SystemClock.uptimeMillis() + timeoutMillis
        var lines = emptyList<String>()
        while (SystemClock.uptimeMillis() < deadline) {
            lines = systemTransientNavigationLines()
            val matches = if (visible) {
                "mTransientShown=true" in lines && "mTransientShownFromGestureOnSystemBar=true" in lines
            } else {
                "mTransientShown=false" in lines && "mTransientShownFromGestureOnSystemBar=false" in lines
            }
            if (matches) {
                Log.i("NativeNavRetest", "kind=$kind phase=$phase transientNavigation=$visible system=$lines")
                return
            }
            SystemClock.sleep(60)
        }
        fail("kind=$kind phase=$phase: real transient navigation expected visible=$visible; " +
            "SystemUI transient/gesture evidence=$lines (no controller.show fallback)")
    }

    private fun assertTransientNavigationShown(kind: String, phase: String) {
        val lines = systemTransientNavigationLines()
        Log.i("NativeNavRetest", "kind=$kind phase=$phase system=$lines")
        assertTrue("The real transient navigation bar must still be shown when tapping $phase",
            "mTransientShown=true" in lines && "mTransientShownFromGestureOnSystemBar=true" in lines)
    }

    private fun saveNavigationScreenshot(kind: String, phase: String) {
        val screenshot = requireNotNull(instrumentation.uiAutomation.takeScreenshot()) { "Cannot capture $kind/$phase" }
        try {
            val directory = requireNotNull(instrumentation.targetContext.getExternalFilesDir("native-nav-retest")) {
                "Navigation evidence external files directory is unavailable"
            }
            assertTrue("Cannot create navigation evidence directory", directory.isDirectory || directory.mkdirs())
            val output = java.io.File(directory, "$kind-$phase.png")
            output.outputStream().use { assertTrue("Cannot encode navigation evidence", screenshot.compress(Bitmap.CompressFormat.PNG, 100, it)) }
            Log.i("NativeNavRetest", "kind=$kind phase=$phase screenshot=${output.absolutePath}")
        } finally {
            screenshot.recycle()
        }
    }

    private fun surfaceTouchBounds(): Map<String, Rect> = onMainValue {
        linkedMapOf(
            "checkbox" to screenBounds(requireNotNull(find(R.id.native_game_surface_dialog_checkbox))),
            "confirm" to screenBounds(tagged("surface-dialog-action:confirm")),
            "cancel" to screenBounds(tagged("surface-dialog-action:cancel")),
        )
    }

    private fun assertSurfaceStillOpen(kind: String, phase: String, result: Result, beforeGameDowns: Int) = onMain {
        assertTrue("kind=$kind phase=$phase must not complete the request", result.values.isEmpty())
        assertNotNull("kind=$kind phase=$phase must preserve the dialog", find(R.id.native_game_surface_dialog))
        assertEquals("kind=$kind phase=$phase must not touch the game", beforeGameDowns, gameDowns)
        Log.i("NativeNavRetest", "kind=$kind phase=$phase result=${result.values} gameDowns=$gameDowns")
    }

    private fun backdropScreenPoint(): Pair<Float, Float> {
        val container = requireNotNull(find(R.id.native_game_surface_dialog)) as ViewGroup
        val bounds = screenBounds(container)
        val card = screenBounds(container.getChildAt(0))
        // Use the dialog's own 20dp side margin, beyond cutout/system-bar padding and outside the card.
        val inset = (10f * container.resources.displayMetrics.density).coerceAtMost(container.paddingLeft / 2f)
        val point = Pair(bounds.left + container.paddingLeft - inset, bounds.exactCenterY())
        assertTrue("Backdrop touch must remain inside the window", bounds.contains(point.first.toInt(), point.second.toInt()))
        assertFalse("Backdrop touch must remain outside the card", card.contains(point.first.toInt(), point.second.toInt()))
        return point
    }

    private fun finishProtectedRealTouch(kind: String, result: Result, expected: Any?, releasedAt: Long,
        recoveryPoint: Pair<Float, Float>, beforeGameDowns: Int,
    ) {
        waitForInputGuard()
        val protectedUntil = releasedAt + NativeGameWarningDialogChannel.PROTECTION_MILLIS - 100
        while (SystemClock.uptimeMillis() < protectedUntil) {
            onMain {
                assertTrue("kind=$kind must wait for the final UP quiet interval", result.values.isEmpty())
                assertNotNull(find(R.id.native_game_warning_input_guard))
                assertEquals("kind=$kind protected touches must not reach the game", beforeGameDowns, gameDowns)
            }
            SystemClock.sleep(40)
        }
        waitResult(result, expected)
        onMain {
            assertTrue("kind=$kind completed before the 600ms quiet interval",
                result.completedAt - releasedAt >= NativeGameWarningDialogChannel.PROTECTION_MILLIS)
            assertTrue(result.errors.toString(), result.errors.isEmpty())
            assertNull(dialog())
            assertEquals("kind=$kind must not leak its closing touch", beforeGameDowns, gameDowns)
            Log.i("NativeNavRetest", "kind=$kind phase=completed result=${result.values} quietMillis=${result.completedAt - releasedAt} gameDowns=$gameDowns")
        }
        tapScreen(recoveryPoint.first, recoveryPoint.second)
        waitUntil { onMainValue { gameDowns == beforeGameDowns + 1 } }
        Log.i("NativeNavRetest", "kind=$kind phase=game-input-restored gameDowns=${onMainValue { gameDowns }}")
    }

    private fun confirmFromRealScreenAfterSystemBarsChange(spec: Map<String, Any>) {
        prepareLandscapeImmersiveActivity()
        for ((index, barsVisible) in listOf(true, false).withIndex()) {
            val result = show(spec + ("id" to (index + 1).toLong()))
            cycleDialogSystemBars(leaveVisible = barsVisible)
            waitForStableTarget("surface-dialog-action:confirm")
            val checkbox = onMainValue { screenPoint(requireNotNull(find(R.id.native_game_surface_dialog_checkbox))) }
            tapScreen(checkbox.first, checkbox.second)
            waitUntil { onMainValue { (find(R.id.native_game_surface_dialog_checkbox) as? CheckBox)?.isChecked == true } }
            onMain {
                assertTrue("Tapping the real checkbox must keep the confirmation open (barsVisible=$barsVisible)",
                    result.values.isEmpty())
                assertEquals(0, gameDowns)
            }
            val confirmBounds = onMainValue { screenBounds(tagged("surface-dialog-action:confirm")) }
            val confirm = onMainValue { screenPoint(tagged("surface-dialog-action:confirm")) }
            val downTime = SystemClock.uptimeMillis()
            injectScreen(MotionEvent.ACTION_DOWN, confirm.first, confirm.second, downTime)
            val window = onMainValue { requireNotNull(dialog()?.window) }
            onMain {
                WindowInsetsControllerCompat(window, window.decorView).apply {
                    if (barsVisible) hide(WindowInsetsCompat.Type.navigationBars())
                    else show(WindowInsetsCompat.Type.navigationBars())
                }
            }
            waitForNavigationBar(window, visible = !barsVisible)
            waitForStableTarget("surface-dialog-action:confirm")
            onMain {
                assertEquals("Navigation changing during a held touch must not move its target",
                    confirmBounds, screenBounds(tagged("surface-dialog-action:confirm")))
            }
            val releasedAt = injectScreen(MotionEvent.ACTION_UP, confirm.first, confirm.second, downTime)
            waitForInputGuard()
            onMain {
                assertTrue("Real confirmation must enter the quiet guard before completing (barsVisible=$barsVisible)",
                    result.values.isEmpty())
                assertEquals(0, gameDowns)
            }
            waitResult(result, mapOf("action" to "confirm", "checked" to true))
            onMain {
                assertTrue("The real confirmation must wait at least 600 ms after UP",
                    result.completedAt - releasedAt >= NativeGameWarningDialogChannel.PROTECTION_MILLIS)
                assertEquals(0, gameDowns)
                assertNull(dialog())
            }
        }
    }

    private fun cycleDialogSystemBars(leaveVisible: Boolean = false) {
        val window = onMainValue { requireNotNull(dialog()?.window) }
        onMain { WindowInsetsControllerCompat(window, window.decorView).show(WindowInsetsCompat.Type.systemBars()) }
        waitForSystemBars(window, visible = true)
        if (!leaveVisible) {
            onMain { hideSystemBars(window) }
            waitForSystemBars(window, visible = false)
        }
    }

    private fun hideSystemBars(window: Window) {
        WindowInsetsControllerCompat(window, window.decorView).apply {
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }
    }

    private fun waitForSystemBars(window: Window, visible: Boolean) {
        waitUntil {
            onMainValue {
                ViewCompat.getRootWindowInsets(window.decorView)?.let { insets ->
                    insets.isVisible(WindowInsetsCompat.Type.statusBars()) == visible &&
                        insets.isVisible(WindowInsetsCompat.Type.navigationBars()) == visible
                } == true
            }
        }
    }

    private fun barDiagnostics(window: Window): String {
        val location = IntArray(2).also { window.decorView.getLocationOnScreen(it) }
        val insets = ViewCompat.getRootWindowInsets(window.decorView)
        return "location=${location.contentToString()}, flags=${window.attributes.flags}, " +
            "systemUi=${window.decorView.systemUiVisibility}, " +
            "statusVisible=${insets?.isVisible(WindowInsetsCompat.Type.statusBars())}, " +
            "navigationVisible=${insets?.isVisible(WindowInsetsCompat.Type.navigationBars())}, " +
            "bars=${insets?.getInsets(WindowInsetsCompat.Type.systemBars())}"
    }

    private fun waitForNavigationBar(window: Window, visible: Boolean) = waitUntil {
        onMainValue {
            ViewCompat.getRootWindowInsets(window.decorView)?.isVisible(WindowInsetsCompat.Type.navigationBars()) == visible
        }
    }

    private fun waitForStableTarget(tag: String) {
        var previous: List<Int>? = null
        var stableSamples = 0
        waitUntil {
            onMainValue {
                val view = tagged(tag)
                val location = IntArray(2).also { view.getLocationOnScreen(it) }
                val geometry = location.toList() + listOf(view.width, view.height)
                stableSamples = if (!view.isLayoutRequested && view.width > 0 && view.height > 0 && geometry == previous) {
                    stableSamples + 1
                } else 0
                previous = geometry
                stableSamples >= 3
            }
        }
    }

    private fun screenPoint(view: View): Pair<Float, Float> {
        val visible = Rect()
        assertTrue("The real touch target must be visible", view.getLocalVisibleRect(visible))
        val x = view.width / 2
        val y = view.height / 2
        assertTrue("The real touch must land inside the visible target", visible.contains(x, y))
        val location = IntArray(2).also { view.getLocationOnScreen(it) }
        return Pair(location[0] + x.toFloat(), location[1] + y.toFloat())
    }

    private fun screenBounds(view: View): Rect {
        val location = IntArray(2).also { view.getLocationOnScreen(it) }
        return Rect(location[0], location[1], location[0] + view.width, location[1] + view.height)
    }

    private fun waitForInputGuard() = waitUntil {
        onMainValue { find(R.id.native_game_warning_input_guard) != null }
    }

    private fun tapScreen(x: Float, y: Float): Long {
        val downTime = SystemClock.uptimeMillis()
        injectScreen(MotionEvent.ACTION_DOWN, x, y, downTime)
        val upTime = injectScreen(MotionEvent.ACTION_UP, x, y, downTime)
        instrumentation.waitForIdleSync()
        return upTime
    }

    private fun injectScreen(action: Int, x: Float, y: Float, downTime: Long): Long {
        val eventTime = SystemClock.uptimeMillis()
        val event = MotionEvent.obtain(downTime, eventTime, action, x, y, 0).apply {
            source = InputDevice.SOURCE_TOUCHSCREEN
        }
        try { assertTrue("Real screen touch injection failed", instrumentation.uiAutomation.injectInputEvent(event, true)) }
        finally { event.recycle() }
        return eventTime
    }

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

    private fun assertOutsideIgnored(result: Result, beforeGameDowns: Int = 0) {
        assertTrue("Outside input must not choose any action", result.values.isEmpty())
        assertNotNull(find(R.id.native_game_surface_dialog))
        assertNull("Outside input must not create a closing guard", find(R.id.native_game_warning_input_guard))
        val stateField = NativeGameWarningDialogChannel::class.java.getDeclaredField("state").apply { isAccessible = true }
        assertFalse((stateField.get(control) as NativeGameWarningDialogState).actionChosen)
        val releaseField = NativeGameWarningDialogChannel::class.java.getDeclaredField("release").apply { isAccessible = true }
        assertNull("Outside input must not start a closing timer", releaseField.get(control))
        assertEquals(beforeGameDowns, gameDowns)
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

    private fun dispatchPointers(action: Int, pointerIds: IntArray, actionIndex: Int = 0) {
        val now = SystemClock.uptimeMillis()
        val properties = pointerIds.map { pointerId ->
            MotionEvent.PointerProperties().apply { id = pointerId; toolType = MotionEvent.TOOL_TYPE_FINGER }
        }.toTypedArray()
        val coordinates = pointerIds.map {
            MotionEvent.PointerCoords().apply { x = 2f; y = 2f; pressure = 1f; size = 1f }
        }.toTypedArray()
        val event = MotionEvent.obtain(now, now, action or (actionIndex shl MotionEvent.ACTION_POINTER_INDEX_SHIFT),
            pointerIds.size, properties, coordinates, 0, 0, 1f, 1f, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0)
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
    private fun <T> onMainValue(action: (MainActivity) -> T): T {
        var value: T? = null
        onMain { value = action(it) }
        @Suppress("UNCHECKED_CAST")
        return value as T
    }
    private class Result : MethodChannel.Result {
        val values = mutableListOf<Any?>()
        val errors = mutableListOf<String>()
        var completedAt = 0L
        override fun success(result: Any?) { completedAt = SystemClock.uptimeMillis(); values.add(result) }
        override fun error(code: String, message: String?, details: Any?) { errors.add("$code: $message") }
        override fun notImplemented() { fail("Unexpected method") }
    }
}
