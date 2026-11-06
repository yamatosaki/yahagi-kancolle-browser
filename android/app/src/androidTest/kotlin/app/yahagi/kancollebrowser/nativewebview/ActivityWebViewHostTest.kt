package app.yahagi.kancollebrowser.nativewebview

import android.content.Context
import android.os.Build
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ActivityWebViewHostTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private var host: ActivityWebViewHost? = null

    @After
    fun tearDown() = onMain {
        host?.destroyCurrent()
        host = null
    }

    @Test
    fun createAddsInvisibleOverlayAfterExistingFlutterChildAndConfiguresWebView() = onMain {
        val root = sizedRoot()
        val flutterChild = View(context)
        root.addView(flutterChild)
        val events = mutableListOf<String>()
        val configurationActions = mutableListOf<NativeGameWebViewConfigurationAction>()
        var initialUserAgent = ""
        var initialCacheMode = 0
        var initialFileAccessFromFileUrls = false
        var initialUniversalAccessFromFileUrls = false
        host = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = recordingSink(events),
            configureWebView = { webView, client, _ ->
                initialUserAgent = webView.settings.userAgentString
                initialCacheMode = webView.settings.cacheMode
                initialFileAccessFromFileUrls = webView.settings.allowFileAccessFromFileURLs
                initialUniversalAccessFromFileUrls = webView.settings.allowUniversalAccessFromFileURLs
                NativeGameWebViewConfigurator.configure(
                    webView,
                    client,
                    onPresentationStateChanged = {},
                ) { action ->
                    configurationActions += action
                }
            },
        )

        val generation = requireNotNull(host!!.create())
        val overlay = root.getChildAt(1) as FrameLayout
        val webView = requireNotNull(host!!.currentWebView)

        assertEquals(2, root.childCount)
        assertSame(overlay, root.getChildAt(root.childCount - 1))
        assertEquals(View.INVISIBLE, overlay.visibility)
        assertEquals(1, overlay.childCount)
        assertSame(webView, overlay.getChildAt(0))
        assertEquals(1, countWebViews(root))
        assertEquals(ViewGroup.LayoutParams.MATCH_PARENT, webView.layoutParams.width)
        assertEquals(ViewGroup.LayoutParams.MATCH_PARENT, webView.layoutParams.height)
        assertTrue(webView.settings.javaScriptEnabled)
        assertTrue(webView.settings.domStorageEnabled)
        assertFalse(webView.settings.mediaPlaybackRequiresUserGesture)
        assertEquals(View.LAYER_TYPE_HARDWARE, webView.layerType)
        assertTrue(CookieManager.getInstance().acceptCookie())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            assertTrue(CookieManager.getInstance().acceptThirdPartyCookies(webView))
        }
        assertEquals(
            NativeGameWebViewUserAgent.toDesktop(initialUserAgent),
            webView.settings.userAgentString,
        )
        assertEquals(initialCacheMode, webView.settings.cacheMode)
        assertEquals(initialFileAccessFromFileUrls, webView.settings.allowFileAccessFromFileURLs)
        assertEquals(
            initialUniversalAccessFromFileUrls,
            webView.settings.allowUniversalAccessFromFileURLs,
        )
        assertTrue(NativeGameWebViewConfigurationAction.DATABASE_ENABLED in configurationActions)
        assertTrue(NativeGameWebViewConfigurationAction.BACKGROUND_BLACK in configurationActions)
        assertTrue(NativeGameWebViewConfigurationAction.USER_AGENT_SET in configurationActions)
        assertTrue(NativeGameWebViewConfigurationAction.WEB_VIEW_CLIENT_SET in configurationActions)
        assertTrue(NativeGameWebViewConfigurationAction.WEB_CHROME_CLIENT_SET in configurationActions)
        assertEquals(listOf("created:$generation"), events)
    }

    @Test
    fun appliesBoundsShowsOnlyWithValidBoundsAndRejectsOldGeneration() = onMain {
        val root = sizedRoot()
        host = ActivityWebViewHost(context, root, recordingSink(mutableListOf()))
        val generation = requireNotNull(host!!.create())
        val overlay = root.getChildAt(0) as FrameLayout

        assertFalse(host!!.setVisible(generation, true))
        assertEquals(View.INVISIBLE, overlay.visibility)
        assertTrue(host!!.setBounds(generation, NativeGameWebViewBounds(10.0, 20.0, 100.0, 50.0, 2.0)))
        val params = overlay.layoutParams as FrameLayout.LayoutParams
        assertEquals(200, params.width)
        assertEquals(100, params.height)
        assertEquals(20, params.leftMargin)
        assertEquals(40, params.topMargin)
        assertTrue(host!!.setVisible(generation, true))
        assertEquals(View.VISIBLE, overlay.visibility)
        assertFalse(host!!.setBounds(generation, NativeGameWebViewBounds(1000.0, 0.0, 10.0, 10.0, 1.0)))
        assertEquals(View.INVISIBLE, overlay.visibility)
        assertFalse(host!!.setBounds(generation + 1, NativeGameWebViewBounds(1.0, 1.0, 10.0, 10.0, 1.0)))
    }

    @Test
    fun equivalentPhysicalBoundsDoNotRequestAnotherLayoutOrHideTheGame() = onMain {
        val root = sizedRoot()
        host = ActivityWebViewHost(context, root, recordingSink(mutableListOf()))
        val generation = requireNotNull(host!!.create())
        val overlay = root.getChildAt(0) as FrameLayout
        val webView = host!!.currentWebView
        assertTrue(host!!.setBounds(generation, NativeGameWebViewBounds(10.0, 20.0, 100.0, 50.0, 2.0)))
        assertTrue(host!!.setVisible(generation, true))
        root.measure(View.MeasureSpec.makeMeasureSpec(800, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(600, View.MeasureSpec.EXACTLY))
        root.layout(0, 0, 800, 600)
        assertFalse(overlay.isLayoutRequested)
        val originalParams = overlay.layoutParams
        assertTrue(host!!.setBounds(generation, NativeGameWebViewBounds(10.01, 20.01, 99.99, 49.99, 2.0)))
        assertSame(originalParams, overlay.layoutParams)
        assertFalse(overlay.isLayoutRequested)
        assertEquals(View.VISIBLE, overlay.visibility)
        assertSame(webView, host!!.currentWebView)
        assertFalse(host!!.setBounds(generation, NativeGameWebViewBounds(1000.0, 0.0, 10.0, 10.0, 1.0)))
        assertTrue(host!!.setBounds(generation, NativeGameWebViewBounds(10.0, 20.0, 100.0, 50.0, 2.0)))
        assertTrue(host!!.setVisible(generation, true))
        assertEquals(View.VISIBLE, overlay.visibility)
    }

    @Test
    fun croppingPreservesFullWebViewPlaneInsteadOfRefittingTheVisiblePart() = onMain {
        val root = sizedRoot()
        host = ActivityWebViewHost(context, root, recordingSink(mutableListOf()))
        val generation = requireNotNull(host!!.create())
        val overlay = root.getChildAt(0) as FrameLayout
        assertTrue(host!!.setBounds(generation, NativeGameWebViewBounds(-30.0, 10.0, 460.0, 276.0, 2.0)))
        val params = overlay.layoutParams as FrameLayout.LayoutParams
        assertEquals(0, params.leftMargin)
        assertEquals(20, params.topMargin)
        assertEquals(800, params.width)
        assertEquals(552, params.height)
        val gameParams = host!!.currentWebView!!.layoutParams as FrameLayout.LayoutParams
        assertEquals(-60, gameParams.leftMargin)
        assertEquals(920, gameParams.width)
        assertEquals(552, gameParams.height)
        assertTrue(root.clipChildren)
        assertTrue(host!!.setVisible(generation, true))
        host!!.destroy(generation)
        val nextGeneration = requireNotNull(host!!.create())
        assertTrue(host!!.setBounds(nextGeneration, NativeGameWebViewBounds(-30.0, 10.0, 460.0, 276.0, 2.0)))
        assertTrue(host!!.setVisible(nextGeneration, true))
    }

    @Test
    fun cameraViewportClipsTheNativeOverlayAndPreservesTheFullGameCanvas() = onMain {
        val root = sizedRoot()
        host = ActivityWebViewHost(context, root, recordingSink(mutableListOf()))
        val generation = requireNotNull(host!!.create())
        assertTrue(host!!.setBounds(generation,
            NativeGameWebViewBounds(-100.0, -60.0, 1200.0, 720.0, 1.0, 20.0, 40.0, 700.0, 400.0)))
        val overlay = root.getChildAt(0) as FrameLayout
        val outer = overlay.layoutParams as FrameLayout.LayoutParams
        val inner = host!!.currentWebView!!.layoutParams as FrameLayout.LayoutParams
        assertEquals(20, outer.leftMargin)
        assertEquals(40, outer.topMargin)
        assertEquals(700, outer.width)
        assertEquals(400, outer.height)
        assertEquals(-120, inner.leftMargin)
        assertEquals(-100, inner.topMargin)
        assertEquals(1200, inner.width)
        assertEquals(720, inner.height)
        assertTrue(overlay.clipChildren)
        assertTrue(host!!.setVisible(generation, true))
    }

    @Test
    fun destroysOnceAndAllowsNewGeneration() = onMain {
        val root = sizedRoot()
        val events = mutableListOf<String>()
        host = ActivityWebViewHost(context, root, recordingSink(events))
        val first = requireNotNull(host!!.create())

        assertTrue(host!!.destroy(first))
        assertEquals(0, root.childCount)
        assertNull(host!!.currentWebView)
        assertNull(host!!.currentGeneration)
        assertFalse(host!!.destroy(first))
        val second = requireNotNull(host!!.create())

        assertTrue(second > first)
        assertFalse(host!!.setVisible(first, false))
        assertEquals(listOf("created:$first", "destroyed:$first", "created:$second"), events)
    }

    @Test
    fun clientRenderGoneInvalidatesBeforeSinkReentryAndUsesOnlyRendererSafeCleanup() = onMain {
        val root = sizedRoot()
        val events = mutableListOf<String>()
        val cleanupCalls = mutableListOf<String>()
        val timeline = mutableListOf<String>()
        var client: NativeGameWebViewClient? = null
        host = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = object : NativeGameWebViewEventSink by recordingSink(events) {
                override fun renderProcessGone(generation: Long, didCrash: Boolean) {
                    events += "gone:$generation:$didCrash"
                    timeline += "gone"
                    assertFalse(requireNotNull(host).destroy(generation))
                }
                override fun destroyed(generation: Long) {
                    events += "destroyed:$generation"
                    timeline += "destroyed"
                }
            },
            configureWebView = { webView, suppliedClient, _ ->
                client = suppliedClient as NativeGameWebViewClient
                NativeGameWebViewConfigurator.configure(webView, suppliedClient)
            },
            webViewCleanup = recordingCleanup(cleanupCalls, timeline),
        )
        val generation = requireNotNull(host!!.create())

        assertTrue(client!!.onRenderProcessGone(requireNotNull(host!!.currentWebView), null))

        assertEquals(0, root.childCount)
        assertEquals(
            listOf("created:$generation", "gone:$generation:false", "destroyed:$generation"),
            events,
        )
        assertEquals(listOf("destroy"), cleanupCalls)
        assertEquals(listOf("gone", "destroy", "destroyed"), timeline)
    }

    @Test
    fun configureSynchronousRendererGoneCleansUnpublishedResourcesAndAllowsAnotherCreate() = onMain {
        val root = sizedRoot()
        val events = mutableListOf<String>()
        val createdViews = mutableListOf<WebView>()
        var configureCount = 0
        host = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = recordingSink(events),
            webViewFactory = { factoryContext -> WebView(factoryContext).also(createdViews::add) },
            configureWebView = { webView, client, _ ->
                if (configureCount++ == 0) {
                    assertTrue((client as NativeGameWebViewClient).onRenderProcessGone(webView, null))
                } else {
                    NativeGameWebViewConfigurator.configure(webView, client)
                }
            },
        )

        assertNull(host!!.create())
        assertEquals(0, root.childCount)
        assertNull(host!!.currentGeneration)
        assertNull(host!!.currentWebView)
        assertEquals(listOf("gone:0:false", "destroyed:0"), events)

        val nextGeneration = requireNotNull(host!!.create())
        assertEquals(1, root.childCount)
        assertEquals(nextGeneration, host!!.currentGeneration)
        assertSame(createdViews[1], host!!.currentWebView)
        assertFalse(containsView(root, createdViews[0]))
    }

    @Test
    fun destroyedSinkReentryCreateCannotBeOverwrittenByTheOldCreate() = onMain {
        val root = sizedRoot()
        val events = mutableListOf<String>()
        val createdViews = mutableListOf<WebView>()
        var configureCount = 0
        var reenteredGeneration: Long? = null
        host = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = object : NativeGameWebViewEventSink by recordingSink(events) {
                override fun destroyed(generation: Long) {
                    events += "destroyed:$generation"
                    if (reenteredGeneration == null) {
                        reenteredGeneration = requireNotNull(host).create()
                    }
                }
            },
            webViewFactory = { factoryContext -> WebView(factoryContext).also(createdViews::add) },
            configureWebView = { webView, client, _ ->
                if (configureCount++ == 0) {
                    assertTrue((client as NativeGameWebViewClient).onRenderProcessGone(webView, null))
                } else {
                    NativeGameWebViewConfigurator.configure(webView, client)
                }
            },
        )

        assertNull(host!!.create())
        val secondGeneration = requireNotNull(reenteredGeneration)
        assertEquals(secondGeneration, host!!.currentGeneration)
        assertSame(createdViews[1], host!!.currentWebView)
        assertEquals(1, root.childCount)
        assertEquals(1, countWebViews(root))
        assertFalse(containsView(root, createdViews[0]))
        assertEquals(1, events.count { it == "destroyed:0" })
        assertNull(host!!.create())

        assertTrue(host!!.destroy(secondGeneration))
        val thirdGeneration = requireNotNull(host!!.create())
        assertEquals(thirdGeneration, host!!.currentGeneration)
        assertEquals(1, root.childCount)
        assertEquals(1, countWebViews(root))
    }

    @Test
    fun destroyContinuesAfterCleanupOperationThrows() = onMain {
        val root = sizedRoot()
        val events = mutableListOf<String>()
        val cleanupCalls = mutableListOf<String>()
        host = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = recordingSink(events),
            webViewCleanup = throwingCleanup(cleanupCalls),
        )
        val generation = requireNotNull(host!!.create())

        assertTrue(host!!.destroy(generation))

        assertEquals(0, root.childCount)
        assertNull(host!!.currentWebView)
        assertNull(host!!.currentGeneration)
        assertEquals(listOf("created:$generation", "destroyed:$generation"), events)
        assertEquals(
            listOf("stop", "blank", "history", "contents", "chrome", "client", "destroy"),
            cleanupCalls,
        )
    }

    @Test
    fun rollsBackFactoryFailureAndCanCreateAfterward() = onMain {
        val root = sizedRoot()
        val failing = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = recordingSink(mutableListOf()),
            webViewFactory = { throw IllegalStateException("factory failure") },
        )

        assertCreateFailure(NativeGameWebViewCreateStage.CREATE_WEB_VIEW) {
            failing.create()
        }
        assertEquals(0, root.childCount)
        assertNull(failing.currentGeneration)
        host = ActivityWebViewHost(context, root, recordingSink(mutableListOf()))
        assertNotNull(host!!.create())
    }

    @Test
    fun rollsBackWhenRootThrowsAfterAddingOverlayAndAllowsAnotherCreate() = onMain {
        val root = sizedRoot()
        root.setOnHierarchyChangeListener(object : ViewGroup.OnHierarchyChangeListener {
            override fun onChildViewAdded(parent: View?, child: View?) {
                throw IllegalStateException("root add failure")
            }

            override fun onChildViewRemoved(parent: View?, child: View?) = Unit
        })
        host = ActivityWebViewHost(context, root, recordingSink(mutableListOf()))

        assertCreateFailure(NativeGameWebViewCreateStage.ATTACH_OVERLAY) {
            host!!.create()
        }
        assertEquals(0, root.childCount)
        assertNull(host!!.currentGeneration)
        assertNull(host!!.currentWebView)

        root.setOnHierarchyChangeListener(null)
        assertNotNull(host!!.create())
        assertEquals(1, root.childCount)
    }

    @Test
    fun rollsBackConfigurationFailureWithoutLeakingTheWebView() = onMain {
        val root = sizedRoot()
        val events = mutableListOf<String>()
        val cleanupCalls = mutableListOf<String>()
        var client: NativeGameWebViewClient? = null
        val failing = ActivityWebViewHost(
            context = context,
            contentRoot = root,
            eventSink = recordingSink(events),
            configureWebView = { webView, suppliedClient, _ ->
                client = suppliedClient as NativeGameWebViewClient
                NativeGameWebViewConfigurator.configure(webView, suppliedClient)
                throw IllegalStateException("configuration failure")
            },
            webViewCleanup = rollbackCleanup(cleanupCalls),
        )

        assertCreateFailure(NativeGameWebViewCreateStage.CONFIGURE_WEB_VIEW) {
            failing.create()
        }
        assertEquals(0, root.childCount)
        assertNull(failing.currentWebView)
        assertNull(failing.currentGeneration)
        client!!.onPageStarted(null, "https://example.test/old", null)
        assertTrue(events.isEmpty())
        assertEquals(listOf("chrome", "client", "destroy"), cleanupCalls)
    }

    @Test
    fun rejectsPublicCallsFromBackgroundThread() {
        onMain {
            host = ActivityWebViewHost(context, sizedRoot(), recordingSink(mutableListOf()))
        }

        try {
            host!!.currentGeneration
        } catch (_: IllegalStateException) {
            return
        }
        throw AssertionError("Expected a main-thread violation")
    }

    private fun sizedRoot(): FrameLayout = FrameLayout(context).apply {
        measure(
            View.MeasureSpec.makeMeasureSpec(800, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(600, View.MeasureSpec.EXACTLY),
        )
        layout(0, 0, 800, 600)
    }

    private fun countWebViews(view: View): Int = when (view) {
        is WebView -> 1
        is ViewGroup -> (0 until view.childCount).sumOf { countWebViews(view.getChildAt(it)) }
        else -> 0
    }

    private fun containsView(root: View, target: View): Boolean = when {
        root === target -> true
        root is ViewGroup -> (0 until root.childCount).any { containsView(root.getChildAt(it), target) }
        else -> false
    }

    private fun throwingCleanup(calls: MutableList<String>) = object : NativeGameWebViewCleanup {
        override fun stopLoading(webView: WebView) {
            calls += "stop"
            throw IllegalStateException("stop failure")
        }

        override fun loadBlank(webView: WebView) {
            calls += "blank"
            throw IllegalStateException("blank failure")
        }

        override fun clearHistory(webView: WebView) {
            calls += "history"
            webView.clearHistory()
        }

        override fun removeAllViews(webView: WebView) {
            calls += "contents"
            webView.removeAllViews()
        }

        override fun clearWebChromeClient(webView: WebView) {
            calls += "chrome"
            webView.webChromeClient = null
        }

        override fun clearWebViewClient(webView: WebView) {
            calls += "client"
            webView.webViewClient = android.webkit.WebViewClient()
        }

        override fun destroy(webView: WebView) {
            calls += "destroy"
            webView.destroy()
        }
    }

    private fun recordingCleanup(
        calls: MutableList<String>,
        timeline: MutableList<String>? = null,
    ) = object : NativeGameWebViewCleanup {
        override fun stopLoading(webView: WebView) { calls += "stop" }
        override fun loadBlank(webView: WebView) { calls += "blank" }
        override fun clearHistory(webView: WebView) { calls += "history" }
        override fun removeAllViews(webView: WebView) { calls += "contents" }
        override fun clearWebChromeClient(webView: WebView) { calls += "chrome" }
        override fun clearWebViewClient(webView: WebView) { calls += "client" }
        override fun destroy(webView: WebView) {
            calls += "destroy"
            timeline?.add("destroy")
            webView.destroy()
        }
    }

    private fun rollbackCleanup(calls: MutableList<String>) = object : NativeGameWebViewCleanup {
        override fun stopLoading(webView: WebView) = Unit
        override fun loadBlank(webView: WebView) = Unit
        override fun clearHistory(webView: WebView) = Unit
        override fun removeAllViews(webView: WebView) = Unit
        override fun clearWebChromeClient(webView: WebView) { calls += "chrome" }
        override fun clearWebViewClient(webView: WebView) {
            calls += "client"
            throw IllegalStateException("client cleanup failure")
        }
        override fun destroy(webView: WebView) { calls += "destroy"; webView.destroy() }
    }

    private fun recordingSink(events: MutableList<String>) = object : NativeGameWebViewEventSink {
        override fun created(generation: Long) {
            events += "created:$generation"
        }
        override fun pageStarted(generation: Long, url: String) = Unit
        override fun pageFinished(generation: Long, url: String) = Unit
        override fun mainFrameError(generation: Long, errorCode: Int, description: String) = Unit
        override fun navigationBlocked(generation: Long, scheme: String) = Unit
        override fun renderProcessGone(generation: Long, didCrash: Boolean) {
            events += "gone:$generation:$didCrash"
        }
        override fun destroyed(generation: Long) {
            events += "destroyed:$generation"
        }
    }

    private fun assertCreateFailure(
        expectedStage: NativeGameWebViewCreateStage,
        operation: () -> Unit,
    ) {
        try {
            operation()
        } catch (error: NativeGameWebViewCreateException) {
            assertEquals(expectedStage, error.stage)
            return
        }
        throw AssertionError("Expected native WebView creation to fail at ${expectedStage.wireName}")
    }

    private fun onMain(block: () -> Unit) {
        instrumentation.runOnMainSync(block)
    }
}
