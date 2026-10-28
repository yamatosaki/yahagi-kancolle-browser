package app.yahagi.kancollebrowser.browser

import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import app.yahagi.kancollebrowser.MainActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/** Run against the isolated warning-smoke application, without a game account. */
@RunWith(AndroidJUnit4::class)
class GameFullscreenDamageControlNoticeTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private lateinit var scenario: ActivityScenario<MainActivity>
    private lateinit var root: FrameLayout
    private lateinit var engine: FlutterEngine
    private lateinit var control: GameFullscreenChannel
    private var revision = 0

    @Before fun setUp() {
        scenario = ActivityScenario.launch(MainActivity::class.java)
        instrumentation.waitForIdleSync()
        scenario.onActivity { activity ->
            root = activity.findViewById(android.R.id.content)
            engine = FlutterEngine(activity, null, false)
            control = GameFullscreenChannel(activity, engine)
            assertTrue(root.width > 0 && root.height > 0)
        }
    }

    @After fun tearDown() {
        if (::control.isInitialized) onMain {
            control.dispose()
            engine.destroy()
        }
        if (::scenario.isInitialized) scenario.close()
    }

    @Test fun inactiveShowFailsAndDoesNotAppearWhenFullscreenStartsLater() {
        onMain { assertEquals(false, notice(1, "损管确认")) }
        activate()
        onMain {
            assertEquals(false, visible(1))
            assertNull(noticeView())
        }
    }

    @Test fun completeTextIsReportedVisibleOnlyAfterTheRealViewHasLaidOut() {
        activate()
        onMain { assertEquals(true, notice(2, "损管确认")) }
        instrumentation.waitForIdleSync()
        onMain {
            assertEquals(true, visible(2))
            val view = requireNotNull(noticeView())
            assertEquals("损管确认", view.text.toString())
            assertFalse(view.isClickable)
            assertFalse(view.isFocusable)
            assertNull(view.ellipsize)
            assertTrue(view.layout.lineCount in 1..2)
        }
    }

    @Test fun oversizedTextAndTinyContentBoundsAreRejectedWithoutAnEllipsizedNotice() {
        activate()
        onMain {
            assertEquals(false, notice(3, "损管信息".repeat(1000)))
            assertNull(noticeView())
            update(contentWidth = 1.0, contentHeight = 1.0)
            assertEquals(false, notice(4, "损管确认"))
            assertNull(noticeView())
        }
        instrumentation.waitForIdleSync()
        onMain { assertEquals(false, visible(4)) }
    }

    @Test fun resizeInvalidatesTheNoticeAndRestoringSpaceCannotReviveIt() {
        activate()
        onMain { assertEquals(true, notice(5, "损管确认")) }
        instrumentation.waitForIdleSync()
        onMain {
            assertEquals(true, visible(5))
            update(contentWidth = 1.0, contentHeight = 1.0)
            assertEquals(false, visible(5))
            assertNull(noticeView())
            update()
            assertEquals(false, visible(5))
            assertNull(noticeView())
        }
    }

    @Test fun enlargedTextThatNoLongerFitsIsNotReportedAsVisible() {
        activate()
        onMain { assertEquals(true, notice(6, "损管确认")) }
        instrumentation.waitForIdleSync()
        onMain {
            assertEquals(true, visible(6))
            requireNotNull(noticeView()).textSize = 1000f
        }
        instrumentation.waitForIdleSync()
        onMain { assertEquals(false, visible(6)) }
    }

    @Test fun draggingTheExitControlOverTheTextInvalidatesVisibilityAndTheNextShow() {
        activate()
        onMain { assertEquals(true, notice(7, "损管确认")) }
        instrumentation.waitForIdleSync()
        onMain {
            assertEquals(true, visible(7))
            val view = requireNotNull(noticeView())
            val exitControl = (0 until root.childCount).map { root.getChildAt(it) }
                .filterIsInstance<ImageView>().single()
            exitControl.x = view.left.toFloat()
            exitControl.y = view.top.toFloat()
            assertEquals(false, visible(7))
            notice(7, "")
            assertEquals(false, notice(8, "损管确认"))
            assertNull(noticeView())
        }
    }

    @Test fun aPendingExitControlLayoutAlsoRejectsAnOverlappingNotice() {
        activate()
        onMain {
            val density = root.resources.displayMetrics.density.toDouble()
            update(controlX = (root.width / density - 34.0) / 2.0, controlY = 8.0)
            assertEquals(false, notice(9, "损管确认"))
            assertNull(noticeView())
        }
    }

    @Test fun damageControlKeepsPriorityAndOnlyItsCurrentIdCanRestoreThePendingQuest() {
        activate()
        onMain {
            assertNull(call("questNotice", mapOf("message" to "任务A")))
            assertEquals(true, notice(10, "旧损管"))
            assertEquals(true, notice(11, "新损管"))
        }
        instrumentation.waitForIdleSync()
        onMain {
            assertEquals(true, visible(11))
            assertNull(call("questNotice", mapOf("message" to "任务B")))
            assertEquals(true, visible(11))
            assertEquals("新损管", noticeView()?.text.toString())
            assertEquals(false, notice(10, ""))
            assertEquals("新损管", noticeView()?.text.toString())
        }
        instrumentation.waitForIdleSync()
        onMain {
            assertEquals(true, visible(11))
            assertEquals(false, notice(11, ""))
            assertEquals("任务B", noticeView()?.text.toString())
            assertNotNull(noticeView()?.ellipsize)
        }
    }

    @Test fun leavingFullscreenClearsTheDamageControlIdAndSharedBubble() {
        activate()
        onMain {
            assertEquals(true, notice(12, "损管确认"))
            call("update", mapOf("active" to false))
            assertEquals(false, visible(12))
            assertNull(noticeView())
            update()
            assertEquals(false, visible(12))
            assertNull(noticeView())
        }
    }

    private fun activate() {
        onMain { update() }
        instrumentation.waitForIdleSync()
    }

    private fun update(
        contentWidth: Double? = null,
        contentHeight: Double? = null,
        controlX: Double = 0.0,
        controlY: Double = 0.0,
    ) {
        val density = root.resources.displayMetrics.density.toDouble()
        call("update", mapOf(
            "active" to true, "scale" to density,
            "geometryRevision" to ++revision,
            "x" to controlX, "y" to controlY, "width" to 34.0, "height" to 34.0,
            "minX" to 0.0, "minY" to 0.0,
            "maxX" to (root.width / density - 34.0).coerceAtLeast(0.0),
            "maxY" to (root.height / density - 34.0).coerceAtLeast(0.0),
            "contentLeft" to 0.0, "contentTop" to 0.0,
            "contentWidth" to (contentWidth ?: root.width / density),
            "contentHeight" to (contentHeight ?: root.height / density),
        ))
    }

    private fun notice(id: Int, message: String) =
        call("damageControlNotice", mapOf("id" to id, "message" to message))

    private fun visible(id: Int) = call("damageControlNoticeVisible", mapOf("id" to id))

    private fun noticeView(): TextView? = (0 until root.childCount)
        .map { root.getChildAt(it) }.filterIsInstance<TextView>().singleOrNull()

    private fun call(method: String, arguments: Map<String, Any>): Any? {
        var completed = false
        var output: Any? = null
        control.onMethodCall(MethodCall(method, arguments), object : MethodChannel.Result {
            override fun success(result: Any?) { completed = true; output = result }
            override fun error(code: String, message: String?, details: Any?) {
                throw AssertionError("$method failed: $code $message")
            }
            override fun notImplemented() { throw AssertionError("$method was not implemented") }
        })
        assertTrue("$method must answer synchronously", completed)
        return output
    }

    private fun onMain(block: () -> Unit) = instrumentation.runOnMainSync(block)
}
