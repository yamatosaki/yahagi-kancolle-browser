package app.yahagi.kancollebrowser.nativewebview

import android.app.Dialog
import android.graphics.Rect
import android.os.Looper
import android.os.SystemClock
import android.view.Gravity
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.CheckBox
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.ScrollView
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

@RunWith(AndroidJUnit4::class)
class NativeGameResourceChecklistTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private lateinit var scenario: ActivityScenario<MainActivity>
    private lateinit var engine: FlutterEngine
    private lateinit var game: WebView
    private lateinit var control: NativeGameWarningDialogChannel
    private val changes = mutableListOf<Map<String, Any>>()
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
            game.loadDataWithBaseURL("https://checklist.invalid/", """
                <html><body style="background:#305050"><script>window.ticks=0;
                function frame(){window.ticks++;requestAnimationFrame(frame);}requestAnimationFrame(frame);</script></body></html>
            """.trimIndent(), "text/html", "utf-8", null)
            engine = FlutterEngine(activity, null, false)
            control = NativeGameWarningDialogChannel(activity, engine, checklistEventSink = { changes.add(it) }) { game }
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

    @Test fun nativeChecksPublishImmediatelyWithoutHidingOrClosingTheLiveGame() {
        val result = show(checklist())
        val before = javascript("window.ticks").toInt()
        onMain {
            val checkbox = checkbox("senka")
            assertEquals("战果", checkbox.text.toString())
            assertTrue(checkbox.isChecked)
            checkbox.performClick()
            assertFalse(checkbox.isChecked)
            assertEquals(listOf(mapOf("kind" to "headerResources", "id" to 1L,
                "event" to "toggle", "itemId" to "senka", "checked" to false, "changeId" to 1L)), changes)
            assertTrue(result.values.isEmpty())
            assertTrue(game.isShown)
            assertEquals(View.VISIBLE, game.visibility)
            assertNotNull(find(R.id.native_game_resource_checklist))
            requireView(R.id.native_game_resource_checklist_done).performClick()
            assertTrue(result.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        waitResult(result)
        assertTrue(javascript("window.ticks").toInt() > before)
        assertEquals(0, gameDowns)
    }

    @Test fun bundledResourceAndMaterialGlyphIconsKeepTheCheckboxAccessible() {
        show(checklist())
        onMain {
            val container = requireView(R.id.native_game_resource_checklist)
            val glyph = container.findViewWithTag<TextView>("glyph:senka")
            assertNotNull("Material icons need a native glyph view", glyph)
            assertEquals(String(Character.toChars(0xe148)), glyph.text.toString())
            assertEquals(0xffe0b25cL.toInt(), glyph.currentTextColor)
            assertTrue("The bundled Material Icons font must contain the glyph", glyph.paint.hasGlyph(glyph.text.toString()))
            val asset = container.findViewWithTag<ImageView>("asset:material-3")
            assertNotNull("Resource icons need a native image view", asset)
            assertNotNull("The resource PNG must load from Flutter assets", asset.drawable)
            assertEquals(View.IMPORTANT_FOR_ACCESSIBILITY_NO, glyph.importantForAccessibility)
            assertEquals("战果", checkbox("senka").text.toString())
            assertEquals(View.IMPORTANT_FOR_ACCESSIBILITY_YES, checkbox("senka").importantForAccessibility)
            container.findViewWithTag<View>("row:material-3").performClick()
            assertEquals(listOf("material-3"), changes.map { it["itemId"] })
            assertFalse(checkbox("material-3").isChecked)
        }
    }

    @Test fun iconUpdatesPreserveTheCheckboxAndIconHostWithoutPublishingASelection() {
        show(checklist())
        onMain {
            val container = requireView(R.id.native_game_resource_checklist)
            val original = checkbox("material-3")
            val icon = container.findViewWithTag<View>("icon:material-3")
            val updated = itemMaps().map {
                if (it["id"] == "material-3") (it - "iconAsset") +
                    mapOf("iconCodePoint" to 0xe148, "iconColor" to 0xff9fb3bfL, "value" to "456") else it
            }
            update(checklist() + mapOf("title" to "新的顶部项目", "items" to updated))
            assertSame(original, checkbox("material-3"))
            assertSame(icon, container.findViewWithTag<View>("icon:material-3"))
            val glyph = container.findViewWithTag<TextView>("glyph:material-3")
            assertEquals(View.VISIBLE, glyph.visibility)
            assertEquals(0xff9fb3bfL.toInt(), glyph.currentTextColor)
            assertEquals(View.GONE, container.findViewWithTag<View>("asset:material-3").visibility)
            assertTrue(changes.isEmpty())
        }
    }

    @Test fun resourceChecklistUsesSharedDialogGeometryAndAccessibleScrollableRows() {
        show(checklist())
        waitForScrollableList()
        onMain { activity ->
            val density = activity.resources.displayMetrics.density
            val container = requireView(R.id.native_game_resource_checklist) as ViewGroup
            val card = container.getChildAt(0)
            val row = container.findViewWithTag<View>("row:senka")
            assertTrue("Resource cards must respect the shared safe width", card.width <= container.width - container.paddingLeft - container.paddingRight)
            assertTrue("The list must leave the dialog actions reachable", list().height < card.height)
            assertTrue("Material checkbox rows retain a 56dp target", row.height >= 56 * density - 1)
            assertTrue("Normal one-line resource rows fit within 56dp", row.height <= 56 * density + 1)
            assertTrue("Checkbox artwork must be compact", checkbox("senka").buttonDrawable!!.intrinsicWidth <= 20 * density + 1)
            val icon = container.findViewWithTag<View>("icon:senka")
            assertEquals((20 * density).toInt().toDouble(), icon.width.toDouble(), 1.0)
        }
    }

    @Test fun aShortWindowKeepsTheHeadingAndLastScrollableRowInsideTheCard() {
        show(checklist("collapsedResources") + ("resetLabel" to "恢复默认"))
        onMain { activity ->
            val metrics = activity.resources.displayMetrics
            requireNotNull(dialog()?.window).setLayout((460 * metrics.density).toInt().coerceAtMost(metrics.widthPixels),
                (240 * metrics.density).toInt().coerceAtMost(metrics.heightPixels))
        }
        instrumentation.waitForIdleSync()
        waitForScrollableList()
        onMain {
            val container = requireView(R.id.native_game_resource_checklist) as ViewGroup
            val card = container.getChildAt(0)
            assertTrue("The compact card must respect top insets", card.top >= container.paddingTop)
            assertTrue("The compact card must respect bottom insets", card.bottom <= container.height - container.paddingBottom)
            assertTrue(requireView(R.id.native_game_resource_checklist_done).isShown)
            list().scrollTo(0, list().getChildAt(0).height)
        }
        instrumentation.waitForIdleSync()
        onMain {
            val visible = Rect()
            assertTrue("The last resource must be reachable on a short screen", checkbox("material-30").getGlobalVisibleRect(visible))
            assertTrue(visible.height() > 0)
            assertFalse(list().canScrollVertically(1))
        }
    }

    @Test fun externalUpdatesPatchExistingNodesAndKeepTheScrollPositionWithoutEvents() {
        show(checklist())
        waitForScrollableList()
        lateinit var original: CheckBox
        lateinit var originalScroll: ScrollView
        var originalOffset = 0
        onMain {
            original = checkbox("senka")
            originalScroll = list()
            originalScroll.scrollTo(0, 360)
            originalOffset = originalScroll.scrollY
            assertTrue(originalOffset > 0)
            val updated = itemMaps().map { if (it["id"] == "senka") it +
                mapOf("label" to "新的战果", "value" to "999 (#2)", "checked" to false) else it }
            update(checklist() + ("items" to updated))
            assertSame(original, checkbox("senka"))
            assertSame(originalScroll, list())
            assertEquals(originalOffset, list().scrollY)
            assertEquals("新的战果", original.text.toString())
            assertEquals("999 (#2)", (requireView(R.id.native_game_resource_checklist)
                .findViewWithTag<View>("value:senka") as TextView).text.toString())
            assertFalse(original.isChecked)
            assertTrue(changes.isEmpty())
        }
    }

    @Test fun battlePreemptionPreservesChecksAndScrollButRejectsOldCheckboxCallbacks() {
        val result = show(checklist())
        waitForScrollableList()
        lateinit var old: CheckBox
        var offset = 0
        onMain {
            old = checkbox("senka")
            old.performClick()
            list().scrollTo(0, 400)
            offset = list().scrollY
            assertTrue(offset > 0)
        }
        val battle = show(battle())
        onMain {
            old.performClick()
            assertEquals(1, changes.size)
            assertTrue(result.values.isEmpty())
            requireView(R.id.native_game_warning_acknowledge).performClick()
        }
        waitView(R.id.native_game_resource_checklist)
        waitUntil { var restored = false; onMain { restored = list().scrollY == offset }; restored }
        onMain {
            assertFalse(checkbox("senka").isChecked)
            old.performClick()
            assertEquals(1, changes.size)
            assertEquals(listOf("acknowledge"), battle.values)
            requireView(R.id.native_game_resource_checklist_done).performClick()
        }
        waitResult(result)
    }

    @Test fun rowAndCheckboxClicksEachToggleExactlyOnceAndRefreshRowsDoNotRefreshTheGame() {
        show(checklist())
        val beforeDocument = javascript("location.href")
        onMain {
            val row = requireView(R.id.native_game_resource_checklist).findViewWithTag<View>("row:senka")
            row.performClick()
            assertEquals(1, changes.size)
            assertFalse(checkbox("senka").isChecked)
            checkbox("senka").performClick()
            assertEquals(2, changes.size)
            assertTrue(checkbox("senka").isChecked)
            checkbox("frame-refresh").performClick()
            checkbox("game-refresh").performClick()
            assertEquals(listOf("frame-refresh", "game-refresh"), changes.takeLast(2).map { it["itemId"] })
            assertNotNull(find(R.id.native_game_resource_checklist))
            assertTrue(changes.all { it["event"] == "toggle" })
        }
        assertEquals(beforeDocument, javascript("location.href"))
        assertEquals(0, gameDowns)
    }

    @Test fun aHeldContactAndBackKeepTheResultPendingUntilRealUpAndQuiet() {
        val result = show(checklist())
        onMain {
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_BACK))
            requireNotNull(dialog()).dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_BACK))
            assertNotNull(find(R.id.native_game_warning_input_guard))
        }
        SystemClock.sleep(800)
        onMain {
            assertTrue(result.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
            assertTrue(result.values.isEmpty())
        }
        waitResult(result)
        assertEquals(0, gameDowns)
    }

    @Test fun unprotectedChecklistDismissesImmediatelyDespiteHeldContact() {
        for (method in listOf("done", "back", "dismiss")) {
            val current = show(checklist("moduleDisplay") + mapOf(
                "protectInputOnDismiss" to false, "backCancels" to true,
            ))
            val next = show(checklist("collapsedResources") + ("resetLabel" to "恢复默认"))
            onMain {
                assertNull(find(R.id.native_game_resource_checklist_reset))
                dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
                when (method) {
                    "done" -> requireView(R.id.native_game_resource_checklist_done).performClick()
                    "back" -> requireNotNull(dialog()).let { window ->
                        window.dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_BACK))
                        window.dispatchKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_BACK))
                    }
                    else -> dismiss("moduleDisplay", 1)
                }
                assertEquals(method, listOf(if (method == "done") "acknowledge" else null), current.values)
                assertNull(find(R.id.native_game_warning_input_guard))
                assertNotNull(find(R.id.native_game_resource_checklist_reset))
                requireView(R.id.native_game_resource_checklist_done).performClick()
                assertNotNull(find(R.id.native_game_warning_input_guard))
                assertTrue(next.values.isEmpty())
            }
            waitResult(next)
        }
    }

    @Test fun compactShipChecklistReturnsTheFirstRealGameTapAfterCloseBackAndDone() {
        val items = itemMaps().mapIndexed { index, item ->
            item + mapOf("label" to "舰娘 ${index + 1}", "detail" to "Lv.187", "value" to "+1,104 EXP")
        }
        lateinit var baselinePoint: Pair<Float, Float>
        onMain { baselinePoint = screenCenter(game) }
        tapScreen(baselinePoint.first, baselinePoint.second)
        onMain { assertEquals("The test WebView must receive a real game tap", 1, gameDowns) }
        for (exit in listOf("close", "back", "done")) {
            val result = show(checklist("moduleDisplay") + mapOf(
                "title" to "选择显示舰娘", "items" to items, "resetLabel" to "恢复默认",
                "compactShipChecklist" to true, "closeLabel" to "关闭",
                "backCancels" to true, "protectInputOnDismiss" to false,
            ))
            waitForScrollableList()
            var before = 0
            lateinit var exitPoint: Pair<Float, Float>
            lateinit var gamePoint: Pair<Float, Float>
            onMain { activity ->
                val container = requireView(R.id.native_game_resource_checklist)
                val close = container.findViewWithTag<View>("compact-ship-checklist-close")
                val done = requireView(R.id.native_game_resource_checklist_done)
                val first = checkbox("senka")
                assertEquals("关闭", close.contentDescription.toString())
                assertEquals("舰娘 1  Lv.187", first.text.toString())
                assertEquals("+1,104 EXP", container.findViewWithTag<TextView>("value:senka").text.toString())
                assertTrue(first.height <= (44 * activity.resources.displayMetrics.density).toInt())
                // The header and footer stay put when the body is scrolled.
                val headerPoint = screenCenter(close)
                val footerPoint = screenCenter(done)
                list().scrollTo(0, list().height)
                assertTrue(list().scrollY > 0)
                assertEquals(headerPoint, screenCenter(close))
                assertEquals(footerPoint, screenCenter(done))
                exitPoint = if (exit == "close") headerPoint else footerPoint
                before = gameDowns
            }
            if (exit == "back") instrumentation.sendKeyDownUpSync(KeyEvent.KEYCODE_BACK)
            else tapScreen(exitPoint.first, exitPoint.second)
            // Android posts a Button click after ACTION_UP. Drain that click,
            // then require dismissal without waiting for a protection timer.
            instrumentation.waitForIdleSync()
            onMain {
                assertEquals(exit, listOf(if (exit == "done") "acknowledge" else null), result.values)
                assertNull(exit, dialog())
                assertEquals("The closing gesture must not reach the game", before, gameDowns)
                gamePoint = screenCenter(game)
            }
            tapScreen(gamePoint.first, gamePoint.second)
            onMain {
                assertEquals("The first game tap after $exit must reach the WebView", before + 1, gameDowns)
            }
        }
    }

    @Test fun cancellationProtectsAHeldContactBeforeTheOtherChecklistAndResetAppears() {
        val first = show(checklist())
        lateinit var old: CheckBox
        onMain {
            old = checkbox("senka")
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            dismiss("headerResources", 1)
            assertEquals(listOf(null), first.values)
        }
        val next = show(checklist("collapsedResources") + ("resetLabel" to "恢复默认"))
        SystemClock.sleep(800)
        onMain {
            assertNotNull(find(R.id.native_game_warning_input_guard))
            old.performClick()
            assertTrue(changes.isEmpty())
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
        }
        waitView(R.id.native_game_resource_checklist)
        onMain {
            requireView(R.id.native_game_resource_checklist_reset).performClick()
            assertEquals(listOf(mapOf("kind" to "collapsedResources", "id" to 1L, "event" to "reset", "changeId" to 1L)), changes)
            assertTrue(next.values.isEmpty())
            requireView(R.id.native_game_resource_checklist_done).performClick()
        }
        waitResult(next)
    }

    @Test fun aStructuralUpdateCannotLoseTheContactOrLetAnOldItemActOnNewContent() {
        val result = show(checklist())
        lateinit var old: CheckBox
        onMain {
            old = checkbox("senka")
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            update(checklist() + ("items" to itemMaps().reversed()))
            old.performClick()
            assertTrue(changes.isEmpty())
            requireView(R.id.native_game_resource_checklist_done).performClick()
        }
        SystemClock.sleep(800)
        onMain {
            assertTrue(result.values.isEmpty())
            assertNotNull(find(R.id.native_game_warning_input_guard))
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
        }
        waitResult(result)
        assertEquals(0, gameDowns)
    }

    @Test fun anOutsideTapDoesNothingAndKeepsAppliedSelections() {
        val result = show(checklist())
        onMain {
            checkbox("senka").performClick()
            dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
            dispatch(MotionEvent.ACTION_UP, 2f, 2f)
            assertNotNull(find(R.id.native_game_resource_checklist))
            assertNull(find(R.id.native_game_warning_input_guard))
            assertTrue(result.values.isEmpty())
            assertFalse(checkbox("senka").isChecked)
            requireView(R.id.native_game_resource_checklist_done).performClick()
        }
        waitResult(result)
        assertEquals(false, changes.single()["checked"])
        assertEquals(0, gameDowns)
    }

    @Test fun outsideTapsNeverCloseAnyChecklistKindAndDoneStillWorks() {
        for (kind in NativeGameWarningDialogSpec.checklistKinds) {
            val result = show(checklist(kind))
            onMain {
                repeat(3) {
                    dispatch(MotionEvent.ACTION_DOWN, 2f, 2f)
                    dispatch(MotionEvent.ACTION_UP, 2f, 2f)
                }
                assertTrue(result.values.isEmpty())
                assertNotNull(find(R.id.native_game_resource_checklist))
                assertNull(find(R.id.native_game_warning_input_guard))
                val stateField = NativeGameWarningDialogChannel::class.java.getDeclaredField("state").apply { isAccessible = true }
                assertFalse((stateField.get(control) as NativeGameWarningDialogState).actionChosen)
                val releaseField = NativeGameWarningDialogChannel::class.java.getDeclaredField("release").apply { isAccessible = true }
                assertNull(releaseField.get(control))
                assertEquals(0, gameDowns)
                requireView(R.id.native_game_resource_checklist_done).performClick()
            }
            waitResult(result)
        }
    }

    @Test fun staleDartAcknowledgementsCannotFlipRapidNativeSelectionsBackwards() {
        show(checklist())
        onMain {
            checkbox("senka").performClick()
            checkbox("senka").performClick()
            assertTrue(checkbox("senka").isChecked)
            update(checklist() + mapOf("items" to itemMaps().map { if (it["id"] == "senka") it + ("checked" to false) else it },
                "appliedChangeId" to 1L))
            assertTrue(checkbox("senka").isChecked)
            checkbox("senka").performClick()
            assertFalse(checkbox("senka").isChecked)
            update(checklist() + ("appliedChangeId" to 2L))
            assertFalse(checkbox("senka").isChecked)
            update(checklist() + mapOf("items" to itemMaps().map { if (it["id"] == "senka") it + ("checked" to false) else it },
                "appliedChangeId" to 3L))
            assertFalse(checkbox("senka").isChecked)
            update(checklist())
            assertTrue(checkbox("senka").isChecked)
            update(checklist() + mapOf("items" to itemMaps().map { if (it["id"] == "senka") it + ("checked" to false) else it },
                "appliedChangeId" to 1L))
            assertTrue(checkbox("senka").isChecked)
            assertEquals(listOf(1L, 2L, 3L), changes.map { it["changeId"] })
        }
    }

    @Test fun resetWaitsForItsAcknowledgedDefaultsWithoutBlockingDoneOrBack() {
        show(checklist("collapsedResources") + ("resetLabel" to "恢复默认"))
        onMain {
            requireView(R.id.native_game_resource_checklist_reset).performClick()
            assertFalse(checkbox("senka").isEnabled)
            checkbox("senka").performClick()
            assertTrue(checkbox("senka").isChecked)
            assertEquals(1, changes.size)
            assertTrue(requireView(R.id.native_game_resource_checklist_done).isEnabled)
            val defaults = checklist("collapsedResources") + mapOf("resetLabel" to "恢复默认",
                "items" to itemMaps().map { it + ("checked" to false) })
            update(defaults)
            assertFalse(checkbox("senka").isEnabled)
            update(defaults + ("appliedChangeId" to 1L))
            assertTrue(checkbox("senka").isEnabled)
            assertFalse(checkbox("senka").isChecked)
            checkbox("senka").performClick()
            assertEquals(listOf(1L, 2L), changes.map { it["changeId"] })
            assertEquals(listOf("reset", "toggle"), changes.map { it["event"] })
        }
    }

    @Test fun screenOffsetBottomCheckboxAndOutsideTapKeepTheChecklistOpen() {
        val result = show(checklist())
        onMain { activity ->
            val density = activity.resources.displayMetrics.density
            val window = requireNotNull(dialog()?.window)
            window.setGravity(Gravity.TOP or Gravity.LEFT)
            window.attributes = window.attributes.apply {
                x = (24 * density).toInt()
                // The shared Material footer now extends below the final row.
                // Keep enough real screen offset to exercise the original
                // root-relative versus screen-relative hit-test regression.
                y = (144 * density).toInt()
            }
            window.setLayout(activity.resources.displayMetrics.widthPixels - (48 * density).toInt(),
                activity.resources.displayMetrics.heightPixels - (192 * density).toInt())
        }
        instrumentation.waitForIdleSync()
        waitForScrollableList()
        onMain {
            list().apply {
                val maxScroll = (getChildAt(0).height - height + paddingTop + paddingBottom).coerceAtLeast(0)
                scrollTo(0, maxScroll)
            }
        }
        instrumentation.waitForIdleSync()
        var previousGeometry: List<Int>? = null
        var stableGeometrySamples = 0
        waitUntil {
            var atBottom = false
            onMain {
                val container = requireView(R.id.native_game_resource_checklist)
                val rootLocation = IntArray(2).also { container.rootView.getLocationOnScreen(it) }
                val lastLocation = IntArray(2).also { checkbox("material-30").getLocationOnScreen(it) }
                val geometry = rootLocation.toList() + lastLocation.toList() + listOf(list().scrollY, list().height)
                val maxScroll = (list().getChildAt(0).height - list().height + list().paddingTop + list().paddingBottom)
                    .coerceAtLeast(0)
                atBottom = list().scrollY > 0 && list().scrollY <= maxScroll && !list().canScrollVertically(1) &&
                    !container.isLayoutRequested
                stableGeometrySamples = if (atBottom && geometry == previousGeometry) stableGeometrySamples + 1 else 0
                previousGeometry = geometry
            }
            atBottom && stableGeometrySamples >= 2
        }
        var itemX = 0f
        var itemY = 0f
        var backdropX = 0f
        var backdropY = 0f
        onMain { activity ->
            val container = requireView(R.id.native_game_resource_checklist) as ViewGroup
            val card = container.getChildAt(0)
            val rootLocation = IntArray(2).also { card.rootView.getLocationOnScreen(it) }
            assertTrue("The regression needs a nonzero dialog screen offset", rootLocation[1] > 0)
            val cardRootBounds = Rect()
            assertTrue(card.getGlobalVisibleRect(cardRootBounds))
            val last = checkbox("material-30")
            val itemLocation = IntArray(2).also { last.getLocationOnScreen(it) }
            val density = activity.resources.displayMetrics.density
            itemX = itemLocation[0] + (24 * density).coerceAtMost(last.width / 2f)
            itemY = itemLocation[1] + last.height - 8 * density
            val itemRootBounds = Rect()
            val lastIsVisible = last.getGlobalVisibleRect(itemRootBounds)
            val window = requireNotNull(dialog()?.window)
            val diagnostics = "root=${rootLocation.contentToString()}, cardRoot=$cardRootBounds, " +
                "itemLocation=${itemLocation.contentToString()}, itemSize=${last.width}x${last.height}, " +
                "itemRoot=$itemRootBounds, scrollY=${list().scrollY}, scrollHeight=${list().height}, " +
                "contentHeight=${list().getChildAt(0).height}, window=${window.attributes}, " +
                "tap=($itemX,$itemY), density=$density"
            android.util.Log.i("NativeChecklistScreenOffset", diagnostics)
            assertTrue("The last checkbox must actually be visible after scrolling: $diagnostics", lastIsVisible)
            assertTrue("The tap must be inside the bottom checkbox: $diagnostics", itemY >= itemLocation[1])
            assertTrue("The old root/screen comparison must misclassify this real checkbox tap: $diagnostics",
                itemY >= cardRootBounds.bottom)
            assertTrue("The tap must remain inside the visible card on screen: $diagnostics",
                Rect(cardRootBounds).apply { offset(rootLocation[0], rootLocation[1]) }
                    .contains(itemX.toInt(), itemY.toInt()))
            val containerLocation = IntArray(2).also { container.getLocationOnScreen(it) }
            backdropX = containerLocation[0] + 2 * density
            backdropY = containerLocation[1] + 2 * density
        }
        tapScreen(itemX, itemY)
        onMain {
            assertEquals("A real bottom-row tap must publish a selection rather than acknowledge the dialog",
                listOf("material-30"), changes.map { it["itemId"] })
            assertFalse(checkbox("material-30").isChecked)
            assertTrue("A card tap must keep the checklist open", result.values.isEmpty())
            assertNull(find(R.id.native_game_warning_input_guard))
        }
        tapScreen(backdropX, backdropY)
        onMain {
            assertTrue("The real backdrop must leave the checklist open", result.values.isEmpty())
            assertNotNull(find(R.id.native_game_resource_checklist))
            assertNull(find(R.id.native_game_warning_input_guard))
            assertFalse(checkbox("material-30").isChecked)
            requireView(R.id.native_game_resource_checklist_done).performClick()
        }
        waitResult(result)
        assertEquals(1, changes.size)
        assertEquals(0, gameDowns)
    }

    private fun itemMaps(): List<Map<String, Any>> = (0..30).map {
        mapOf("id" to when (it) { 0 -> "senka"; 1 -> "frame-refresh"; 2 -> "game-refresh"; else -> "material-$it" },
            "label" to when (it) { 0 -> "战果"; 1 -> "框架刷新"; 2 -> "刷新游戏"; else -> "项目 $it" },
            "value" to "$it", "checked" to true) + when (it) {
                0 -> mapOf("iconCodePoint" to 0xe148, "iconColor" to 0xffe0b25cL)
                3 -> mapOf("iconAsset" to "assets/images/material/01.png")
                else -> emptyMap()
            }
    }
    private fun checklist(kind: String = "headerResources"): Map<String, Any> = mapOf(
        "kind" to kind, "id" to 1L, "title" to "选择顶部显示项目", "items" to itemMaps(),
        "labels" to mapOf("acknowledge" to "完成"),
    )
    private fun battle(): Map<String, Any> = mapOf(
        "id" to 1L, "title" to "大破警告", "headline" to "请撤退", "body" to "body", "rows" to emptyList<String>(),
        "labels" to NativeGameWarningDialogSpec.actions.associateWith { it },
    )
    private fun show(payload: Map<String, Any>): Result {
        val result = Result()
        onMain { control.onMethodCall(MethodCall("show", payload), result) }
        instrumentation.waitForIdleSync()
        onMain { assertTrue(result.errors.toString(), result.errors.isEmpty()) }
        return result
    }
    private fun update(payload: Map<String, Any>) {
        val result = Result()
        control.onMethodCall(MethodCall("update", payload), result)
        assertTrue(result.errors.toString(), result.errors.isEmpty())
    }
    private fun dismiss(kind: String, id: Long) =
        control.onMethodCall(MethodCall("dismiss", mapOf("kind" to kind, "id" to id)), Result())
    private fun checkbox(id: String): CheckBox = requireView(R.id.native_game_resource_checklist).findViewWithTag(id)
    private fun list(): ScrollView = requireView(R.id.native_game_resource_checklist_list) as ScrollView
    private fun waitForScrollableList() = waitUntil {
        var ready = false
        onMain { ready = list().height > 0 && list().canScrollVertically(1) }
        ready
    }
    private fun waitView(id: Int) = waitUntil { var shown = false; onMain { shown = find(id) != null }; shown }
    private fun waitResult(result: Result) = waitUntil { var completed = false; onMain { completed = result.values == listOf("acknowledge") }; completed }
    private fun find(id: Int): View? = dialog()?.window?.decorView?.findViewById(id)
    private fun requireView(id: Int): View = requireNotNull(find(id))
    private fun dialog(): Dialog? = NativeGameWarningDialogChannel::class.java.getDeclaredField("dialog").let { it.isAccessible = true; it.get(control) as? Dialog }
    private fun dispatch(action: Int, x: Float, y: Float) {
        val now = SystemClock.uptimeMillis()
        val event = MotionEvent.obtain(now, now, action, x, y, 0)
        try { requireNotNull(dialog()).dispatchTouchEvent(event) } finally { event.recycle() }
    }
    private fun tapScreen(x: Float, y: Float) {
        val downTime = SystemClock.uptimeMillis()
        for (action in listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP)) {
            val event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action, x, y, 0).apply {
                source = android.view.InputDevice.SOURCE_TOUCHSCREEN
            }
            try { assertTrue("Screen touch injection failed", instrumentation.uiAutomation.injectInputEvent(event, true)) }
            finally { event.recycle() }
        }
    }
    private fun screenCenter(view: View): Pair<Float, Float> {
        val location = IntArray(2).also(view::getLocationOnScreen)
        return (location[0] + view.width / 2f) to (location[1] + view.height / 2f)
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
        fail("Native checklist condition timed out")
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
