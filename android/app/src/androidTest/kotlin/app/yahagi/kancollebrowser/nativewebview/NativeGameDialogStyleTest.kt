package app.yahagi.kancollebrowser.nativewebview

import android.app.Dialog
import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.os.Build
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.Button
import android.widget.CheckBox
import android.widget.FrameLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
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
import java.io.File
import java.io.FileOutputStream
import kotlin.math.roundToInt

/** Real native layouts with synthetic local content; no network or game account. */
@RunWith(AndroidJUnit4::class)
class NativeGameDialogStyleTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private lateinit var scenario: ActivityScenario<MainActivity>
    private lateinit var engine: FlutterEngine
    private lateinit var game: WebView
    private lateinit var control: NativeGameWarningDialogChannel
    private var gameDowns = 0

    @Before fun setUp() {
        scenario = ActivityScenario.launch(MainActivity::class.java)
        onMain { activity ->
            activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            game = WebView(activity).apply {
                setOnTouchListener { _, event ->
                    if (event.actionMasked == MotionEvent.ACTION_DOWN) gameDowns++
                    false
                }
                loadData("<html><body style='background:#345678'>local game</body></html>", "text/html", "utf-8")
            }
            activity.findViewById<FrameLayout>(android.R.id.content).addView(game,
                FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            engine = FlutterEngine(activity, null, false)
            control = NativeGameWarningDialogChannel(activity, engine) { game }
        }
        waitUntil { onMainValue { game.width > game.height && game.height > 0 && game.isAttachedToWindow } }
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

    @Test fun allEightNativeDialogKindsApplyTheResolvedFlutterPresentation() {
        for ((index, kind) in KINDS.withIndex()) {
            val result = show(payload(kind, index + 1L))
            waitForStableLayout()
            capture("custom-$kind")
            onMain {
                val card = card()
                val title = tagged("dialog-title") as TextView
                val body = tagged(if (kind in NativeGameWarningDialogSpec.checklistKinds) "value:fuel" else "dialog-body") as TextView
                val root = root()
                assertTrue("$kind must share the intrinsic card", card is NativeGameDialogCard)
                assertSame("$kind content must be the first independent scroll area", card.getChildAt(0), contentScroll())
                assertSame("$kind actions must be the second independent scroll area", card.getChildAt(1), footerScroll())
                assertEquals("$kind surface color", SURFACE.toInt(), backgroundPixel(card))
                assertEquals("$kind title color", ON_SURFACE.toInt(), title.currentTextColor)
                assertEquals("$kind body color", BODY.toInt(), body.currentTextColor)
                assertEquals("$kind title must use resolved DIP rather than SP", px(23f), title.textSize, 0.6f)
                assertEquals("$kind body must use resolved DIP rather than SP", px(15f), body.textSize, 0.6f)
                assertTrue("$kind title must retain the supplied bold face", title.typeface.isBold)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) assertEquals("$kind title weight", 700, title.typeface.weight)

                val bars = requireNotNull(ViewCompat.getRootWindowInsets(root)).getInsetsIgnoringVisibility(
                    WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
                assertEquals("$kind left inset", bars.left + dp(12), root.paddingLeft)
                assertEquals("$kind top inset", bars.top + dp(14), root.paddingTop)
                assertEquals("$kind right inset", bars.right + dp(18), root.paddingRight)
                assertEquals("$kind bottom inset", bars.bottom + dp(16), root.paddingBottom)
                assertCardInsideRoot(kind)

                val titleLocation = screenLocation(title)
                val cardLocation = screenLocation(card)
                assertEquals("$kind title left padding", dp(9), titleLocation[0] + title.compoundPaddingLeft - cardLocation[0])
                assertEquals("$kind title top padding", dp(10), titleLocation[1] + title.compoundPaddingTop - cardLocation[1])
                for (button in descendants(card).filterIsInstance<Button>().filterNot { it is CheckBox }) {
                    assertEquals("$kind action font", px(14f), button.textSize, 0.6f)
                    assertTrue("$kind action must preserve its minimum touch height", button.height >= dp(40))
                }
                for (checkbox in descendants(card).filterIsInstance<CheckBox>()) {
                    assertEquals("$kind checkbox font", px(19f), checkbox.textSize, 0.6f)
                }
            }
            dismiss(kind, index + 1L)
            waitUntil { onMainValue { dialog() == null && result.values.size == 1 } }
        }
        assertEquals(0, gameDowns)
    }

    @Test fun nativeTextFilledAndOutlinedActionsUseTheirDeclaredVariants() {
        show(payload("surfaceDialog") + mapOf(
            "actions" to listOf("plain", "outlined", "confirm"),
            "labels" to mapOf("plain" to "取消", "outlined" to "稍后", "confirm" to "确认"),
            "variants" to mapOf("plain" to "text", "outlined" to "outlined", "confirm" to "filled"),
        ))
        waitForStableLayout()
        capture("action-variants")
        onMain {
            val plain = action("plain")
            val outlined = action("outlined")
            val filled = action("confirm")
            assertEquals(PRIMARY.toInt(), plain.currentTextColor)
            assertEquals(PRIMARY.toInt(), outlined.currentTextColor)
            assertEquals(ON_PRIMARY.toInt(), filled.currentTextColor)
            assertEquals("A drawable must not erase the text action spacing", dp(12), plain.paddingLeft)
            assertEquals("A drawable must not erase the filled label spacing", dp(24), filled.paddingLeft)
            assertEquals("An outlined label must retain Material horizontal spacing", dp(24), outlined.paddingRight)
            assertEquals("A text action must not acquire the old filled pill", Color.TRANSPARENT, backgroundPixel(plain))
            assertEquals("An outlined action must retain a transparent center", Color.TRANSPARENT, backgroundPixel(outlined))
            assertEquals("A filled action must use the theme primary color", PRIMARY.toInt(), backgroundPixel(filled))
            val edge = backgroundPixel(outlined, edge = true)
            assertTrue("An outlined action must draw a visible border", Color.alpha(edge) > 0)
            assertEquals("The outline must use the resolved outline color", OUTLINE.toInt() and 0xffffff, edge and 0xffffff)
        }
    }

    @Test fun longGenericBodyScrollsWhileItsActionFooterStaysFixed() {
        show(payload("debuff") + ("body" to (1..80).joinToString("\n") { "长文第 $it 行，确认动作始终可以到达。" }))
        resizeWindow(640, 360)
        waitUntil { onMainValue { contentScroll().canScrollVertically(1) } }
        val before = onMainValue {
            assertFalse("A single short action does not need a scrolling footer", footerScroll().canScrollVertically(1))
            screenBounds(buttonNamed("完成"))
        }
        onMain { contentScroll().scrollTo(0, contentScroll().getChildAt(0).height) }
        instrumentation.waitForIdleSync()
        waitUntil { onMainValue { contentScroll().scrollY > 0 && !contentScroll().canScrollVertically(1) } }
        capture("generic-long-body-scrolled")
        onMain {
            assertEquals("Scrolling reminder prose must not move its action", before, screenBounds(buttonNamed("完成")))
            assertTrue("The action must remain visible", buttonNamed("完成").getLocalVisibleRect(Rect()))
            assertTrue("The generic body and footer must not share one scroll gesture", contentScroll() !== footerScroll())
            assertCardInsideRoot("long generic body")
        }
    }

    @Test fun shortWindowWith200PercentTextCanScrollToAndTapTheFourthLongAction() {
        val labels = mapOf(
            "first" to "保留当前设置并稍后重新进行完整检查",
            "second" to "打开详细说明以确认每一项相关设置",
            "third" to "返回上一层继续调整显示与通知设置",
            "confirm" to "确认应用全部设置并继续当前游戏会话",
        )
        val result = show(payload("surfaceDialog") + mapOf(
            "title" to "确认显示设置",
            "body" to "短窗口和大号文字仍然必须能到达全部操作。".repeat(8),
            "actions" to labels.keys.toList(),
            "labels" to labels,
            "presentation" to presentation(scale = 2.0),
        ))
        resizeWindow(320, 240)
        waitUntil { onMainValue { footerScroll().height > 0 && footerScroll().canScrollVertically(1) } }
        onMain {
            assertEquals("The supplied 200% action size is applied exactly once", px(28f), action("confirm").textSize, 0.6f)
            assertCardInsideRoot("320x240 at 200% text")
            footerScroll().scrollTo(0, footerScroll().getChildAt(0).height)
        }
        instrumentation.waitForIdleSync()
        waitUntil { onMainValue { footerScroll().scrollY > 0 && !footerScroll().canScrollVertically(1) } }
        capture("short-window-200-percent-final-action")
        val point = onMainValue {
            val last = action("confirm")
            val visible = Rect()
            assertTrue("The last long action must be visible after scrolling its footer", last.getLocalVisibleRect(visible))
            assertTrue("A usable portion of the final action must remain reachable", visible.width() > 0 && visible.height() > dp(8))
            val position = screenLocation(last)
            Pair(position[0] + visible.exactCenterX(), position[1] + visible.exactCenterY())
        }
        tapScreen(point.first, point.second)
        waitUntil { onMainValue { result.values == listOf(mapOf("action" to "confirm", "checked" to false)) } }
        onMain { assertEquals("The last action must consume its physical tap", 0, gameDowns) }
    }

    @Test fun aWindowNarrowerThan280DpClampsTheCardAndAllItsTextTargets() {
        show(payload("surfaceDialog") + mapOf(
            "title" to "窄窗口确认",
            "body" to "这段文字需要换行，但不能把整个对话框撑出窗口。",
            "presentation" to presentation() + ("layout" to layout(inset = listOf(8.0, 8.0, 8.0, 8.0))),
        ))
        resizeWindow(240, 320)
        capture("narrow-240dp")
        onMain {
            val root = root()
            val card = card()
            assertTrue("The regression must use a window narrower than the normal 280dp minimum", root.width < dp(280))
            assertCardInsideRoot("240dp narrow window")
            val bounds = screenBounds(card)
            for (view in descendants(card).filterIsInstance<TextView>()) {
                val child = screenBounds(view)
                assertTrue("${view.text} starts outside the card: child=$child, card=$bounds", child.left >= bounds.left)
                assertTrue("${view.text} extends past the card: child=$child, card=$bounds", child.right <= bounds.right)
            }
        }
    }

    @Test fun darkConfirmationReferenceUsesBoldHarmonyOsAndStandardMaterialGeometry() {
        val dark = mapOf<String, Any>(
            "fontAsset" to "assets/fonts/HarmonyOS_Sans_SC.ttf",
            "text" to mapOf(
                "title" to textStyle(24.0, 32.0, 700),
                "body" to textStyle(14.0, 20.0, 700),
                "action" to textStyle(14.0, 20.0, 700),
                "checkbox" to textStyle(16.0, 24.0, 700),
            ),
        )
        show(payload("surfaceDialog") + mapOf(
            "title" to "确认刷新框架",
            "headline" to "",
            "body" to "将重新加载游戏框架。当前游戏页面将保持打开。",
            "checkbox" to mapOf("label" to "以后不再确认", "checked" to false),
            "labels" to mapOf("cancel" to "取消", "confirm" to "确认刷新"),
            "variants" to mapOf("cancel" to "text", "confirm" to "filled"),
            "presentation" to dark,
        ))
        waitForStableLayout()
        capture("flutter-dark-harmony-bold-reference")
        onMain {
            assertEquals(0xff2b261e.toInt(), backgroundPixel(card()))
            assertEquals(px(24f), (tagged("dialog-title") as TextView).textSize, 0.6f)
            assertTrue((tagged("dialog-title") as TextView).typeface.isBold)
            assertEquals(0xffedbf69.toInt(), backgroundPixel(action("confirm")))
            assertCardInsideRoot("Flutter dark reference")
        }
    }

    private fun payload(kind: String, id: Long = 1L): Map<String, Any> {
        val actions = when (kind) {
            "surfaceDialog" -> listOf("cancel", "confirm")
            "battle" -> NativeGameWarningDialogSpec.actions
            else -> listOf("acknowledge")
        }
        return mapOf(
            "kind" to kind, "id" to id, "title" to "统一确认样式", "headline" to "当前状态",
            "body" to "所有原生弹窗使用Flutter解析出的颜色和文字。", "rows" to emptyList<String>(),
            "actions" to actions,
            "labels" to actions.associateWith { if (it == "acknowledge") "完成" else if (it == "confirm") "确认" else "取消" },
            "presentation" to presentation(),
        ) + when (kind) {
            "surfaceDialog" -> mapOf("checkbox" to mapOf("label" to "以后不再确认", "checked" to false))
            in NativeGameWarningDialogSpec.checklistKinds -> mapOf("items" to listOf(
                mapOf("id" to "fuel", "label" to "燃料", "value" to "1200", "checked" to true)))
            else -> emptyMap()
        }
    }

    private fun presentation(scale: Double = 1.0): Map<String, Any> = mapOf(
        "colors" to mapOf("surface" to SURFACE, "onSurface" to ON_SURFACE, "body" to BODY,
            "primary" to PRIMARY, "onPrimary" to ON_PRIMARY, "checkbox" to PRIMARY,
            "checkboxCheck" to ON_PRIMARY, "outline" to OUTLINE, "barrier" to 0x66000000L),
        "text" to mapOf(
            "title" to textStyle(23.0 * scale, 31.0 * scale, 700),
            "body" to textStyle(15.0 * scale, 21.0 * scale, 400),
            "action" to textStyle(14.0 * scale, 22.0 * scale, 500),
            "checkbox" to textStyle(19.0 * scale, 27.0 * scale, 400),
        ),
        "layout" to layout(), "textDirection" to "ltr",
    )

    private fun textStyle(size: Double, height: Double, weight: Int): Map<String, Any> =
        mapOf("fontSize" to size, "lineHeight" to height, "fontWeight" to weight)

    private fun layout(inset: List<Double> = listOf(12.0, 14.0, 18.0, 16.0)): Map<String, Any> = mapOf(
        "insetPadding" to inset, "titlePadding" to listOf(9.0, 10.0, 11.0, 4.0),
        "contentPadding" to listOf(9.0, 7.0, 11.0, 8.0), "actionsPadding" to listOf(13.0, 3.0, 15.0, 9.0),
        "radius" to 17.0, "minWidth" to 280.0, "actionMinHeight" to 40.0,
        "actionSpacing" to 8.0, "buttonRadius" to 20.0,
    )

    private fun show(spec: Map<String, Any>): Result {
        val result = Result()
        onMain { control.onMethodCall(MethodCall("show", spec), result) }
        instrumentation.waitForIdleSync()
        onMain { assertTrue("Native style dialog failed to present: ${result.errors}", result.errors.isEmpty()) }
        waitUntil { onMainValue { dialog()?.isShowing == true && root().childCount > 0 && card().width > 0 } }
        return result
    }

    private fun resizeWindow(widthDp: Int, heightDp: Int) {
        onMain { requireNotNull(dialog()?.window).setLayout(dp(widthDp), dp(heightDp)) }
        instrumentation.waitForIdleSync()
        waitUntil { onMainValue { root().width == dp(widthDp) && root().height == dp(heightDp) && !root().isLayoutRequested } }
        waitForStableLayout()
    }

    private fun dismiss(kind: String, id: Long) = onMain {
        control.onMethodCall(MethodCall("dismiss", mapOf("kind" to kind, "id" to id)), Result())
    }

    private fun assertCardInsideRoot(label: String) {
        val root = root()
        val card = card()
        assertTrue("$label card left must respect the inset", card.left >= root.paddingLeft)
        assertTrue("$label card top must respect the inset", card.top >= root.paddingTop)
        assertTrue("$label card right must respect the inset", card.right <= root.width - root.paddingRight)
        assertTrue("$label card bottom must respect the inset", card.bottom <= root.height - root.paddingBottom)
        assertTrue("$label card must retain a usable content area", contentScroll().width > 0 && contentScroll().height > 0)
    }

    private fun backgroundPixel(view: View, edge: Boolean = false): Int {
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        try {
            val drawable = requireNotNull(view.background)
            drawable.setBounds(0, 0, view.width, view.height)
            drawable.draw(Canvas(bitmap))
            if (edge) {
                for (y in 0 until view.height / 2) {
                    val pixel = bitmap.getPixel(view.width / 2, y)
                    if (Color.alpha(pixel) > 0) return pixel
                }
                return Color.TRANSPARENT
            }
            return bitmap.getPixel(view.width / 2, view.height / 2)
        } finally { bitmap.recycle() }
    }

    private fun capture(name: String) {
        val directory = onMainValue { activity ->
            File(requireNotNull(activity.getExternalFilesDir(null)), "dialog-style").apply {
                check(isDirectory || mkdirs()) { "Cannot create the native dialog screenshot directory" }
            }
        }
        val bitmap = requireNotNull(instrumentation.uiAutomation.takeScreenshot())
        try {
            FileOutputStream(File(directory, "$name.png")).use { stream ->
                assertTrue("Native dialog screenshot could not be encoded", bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream))
            }
            Log.i("NativeDialogStyle", "Captured $name.png")
        } finally { bitmap.recycle() }
    }

    private fun root(): FrameLayout = NativeGameWarningDialogChannel::class.java.getDeclaredField("root").let {
        it.isAccessible = true; it.get(control) as FrameLayout
    }
    private fun card(): ViewGroup = root().getChildAt(0) as ViewGroup
    private fun contentScroll(): ScrollView = tagged("dialog-content-scroll") as ScrollView
    private fun footerScroll(): ScrollView = tagged("dialog-actions-scroll") as ScrollView
    private fun tagged(tag: String): View = requireNotNull(dialog()?.window?.decorView?.findViewWithTag<View>(tag))
    private fun action(id: String): Button = tagged("surface-dialog-action:$id") as Button
    private fun buttonNamed(label: String): Button = descendants(card()).filterIsInstance<Button>().single { it.text.toString() == label }
    private fun dialog(): Dialog? = NativeGameWarningDialogChannel::class.java.getDeclaredField("dialog").let {
        it.isAccessible = true; it.get(control) as? Dialog
    }
    private fun descendants(view: View): List<View> = listOf(view) + if (view is ViewGroup) {
        (0 until view.childCount).flatMap { descendants(view.getChildAt(it)) }
    } else emptyList()
    private fun screenLocation(view: View): IntArray = IntArray(2).also { view.getLocationOnScreen(it) }
    private fun screenBounds(view: View): Rect = screenLocation(view).let { Rect(it[0], it[1], it[0] + view.width, it[1] + view.height) }
    private fun px(value: Float): Float = value * game.resources.displayMetrics.density
    private fun dp(value: Int): Int = px(value.toFloat()).roundToInt()

    private fun waitForStableLayout() {
        var previous: List<Int>? = null
        var samples = 0
        waitUntil {
            onMainValue {
                val card = card()
                val geometry = listOf(root().width, root().height, card.left, card.top, card.width, card.height)
                samples = if (!root().isLayoutRequested && !card.isLayoutRequested && geometry == previous) samples + 1 else 0
                previous = geometry
                samples >= 3
            }
        }
    }

    private fun tapScreen(x: Float, y: Float) {
        val downTime = SystemClock.uptimeMillis()
        for (action in listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP)) {
            val event = MotionEvent.obtain(downTime, SystemClock.uptimeMillis(), action, x, y, 0).apply {
                source = InputDevice.SOURCE_TOUCHSCREEN
            }
            try { assertTrue("Real screen touch injection failed", instrumentation.uiAutomation.injectInputEvent(event, true)) }
            finally { event.recycle() }
        }
    }

    private fun waitUntil(condition: () -> Boolean) {
        val deadline = SystemClock.uptimeMillis() + 6000
        while (SystemClock.uptimeMillis() < deadline) {
            if (condition()) return
            SystemClock.sleep(40)
        }
        fail("Native dialog style condition timed out")
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
        override fun success(result: Any?) { values.add(result) }
        override fun error(code: String, message: String?, details: Any?) { errors.add("$code: $message") }
        override fun notImplemented() { fail("Unexpected native method") }
    }
    companion object {
        private val KINDS = listOf("surfaceDialog", "battle", "debuff", "newShip", "headerResources", "collapsedResources", "moduleDisplay", "fleetDisplay")
        private const val SURFACE = 0xff263349L
        private const val ON_SURFACE = 0xffe8ecf4L
        private const val BODY = 0xffbbc7d9L
        private const val PRIMARY = 0xff77bbddL
        private const val ON_PRIMARY = 0xff102030L
        private const val OUTLINE = 0xffaabb66L
    }
}
