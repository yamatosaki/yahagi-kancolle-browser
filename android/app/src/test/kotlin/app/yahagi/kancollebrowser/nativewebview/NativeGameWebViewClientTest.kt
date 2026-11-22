package app.yahagi.kancollebrowser.nativewebview

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeGameWebViewClientTest {
    @Test
    fun disabledStartupChecksDoNotReadTheProgressUrlOrEmitProgress() {
        val events = mutableListOf<String>()
        var enabled = false
        val delegate = NativeGameWebViewClientDelegate(
            generation = 2,
            sink = recordingSink(events),
            acceptsGeneration = { true },
            prepareRenderProcessGone = { true },
            onRenderProcessGone = {},
            startupChecksEnabled = { enabled },
        )
        delegate.pageStarted("https://example.test/game")
        events.clear()
        delegate.pageProgress(25) { error("Disabled progress must not read the URL") }
        delegate.receivedHttpError(false, 503, "https://w00g.kancolle-server.com/gadget_html5/js/kcs_const.js")
        assertTrue(events.isEmpty())

        enabled = true
        delegate.pageProgress(75) { "https://example.test/game" }
        assertEquals(listOf("progress:2:75:https://example.test/game"), events)
    }

    @Test
    fun progressFollowsTheCurrentDocumentAndNeverEmitsPrivateUrlComponents() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)
        delegate.pageProgress(25) { "https://example.test/old" }
        assertTrue(events.isEmpty())
        delegate.pageStarted("https://example.test/game/private=%3D?token=secret")
        events.clear()

        delegate.pageProgress(12) { "https://example.test/old" }
        delegate.pageProgress(101) { null }
        delegate.pageProgress(25) { "HTTPS://EXAMPLE.TEST:443/game/private=%3D?token=secret#fragment" }
        delegate.pageProgress(100) { null }

        assertEquals(listOf("progress:2:25:https://example.test/game", "progress:2:100:null"), events)
    }

    @Test
    fun reportsGadgetKindOnlyForKnownScriptsAtTheOfficialOrigin() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)
        delegate.receivedHttpError(false, 503, "https://w00g.kancolle-server.com/gadget_html5/js/kcs_login.js?v=private")
        delegate.receivedError(false, -2, "private", "https://w00g.kancolle-server.com/gadget_html5/script/jquery.min.js")
        delegate.receivedHttpError(false, 503, "https://mirror.example/gadget_html5/js/kcs_const.js")
        delegate.receivedHttpError(false, 404, "https://w00g.kancolle-server.com/gadget_html5/img/kcs_login.js")
        delegate.receivedHttpError(false, 503, "https://w00g.kancolle-server.com/gadget_html5/js/kcs_optional.js")
        delegate.receivedHttpError(false, 503, "https://w00g.kancolle-server.com:444/gadget_html5/js/kcs_const.js")

        assertEquals(
            listOf("gadget:503", "gadget:-2"),
            events,
        )
    }

    @Test
    fun oldMainDocumentErrorsDoNotFailTheNewerDocument() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)
        delegate.pageStarted("https://game.example/a")
        delegate.pageStarted("https://game.example/b?token=current")
        events.clear()
        delegate.receivedError(true, -2, "old network error", "https://game.example/a")
        delegate.receivedHttpError(true, 503, "https://game.example/a")
        assertTrue(events.isEmpty())
        delegate.receivedHttpError(true, 503, "HTTPS://GAME.EXAMPLE:443/b?token=current#fragment")
        assertEquals(listOf("error:503:HTTP 503"), events)
    }

    @Test
    fun mainAndChildHttpErrorsKeepTheirFrameAttribution() {
        val events = mutableListOf<String>()
        val sink = object : NativeGameWebViewEventSink by recordingSink(events) {
            override fun resourceError(generation: Long, errorCode: Int, kind: NativeGameWebViewResourceKind?) {
                events += "resource:$generation:$errorCode"
            }
        }
        val delegate = NativeGameWebViewClientDelegate(
            generation = 7,
            sink = sink,
            acceptsGeneration = { true },
            prepareRenderProcessGone = { true },
            onRenderProcessGone = {},
        )
        delegate.receivedHttpError(true, 503)
        delegate.receivedHttpError(false, 404)
        delegate.receivedHttpError(true, 304)
        assertEquals(listOf("error:503:HTTP 503", "resource:7:404"), events)
    }

    @Test
    fun childResourceFailureReportsCodeWithoutMainFrameFailureOrPrivateText() {
        val events = mutableListOf<String>()
        val sink = object : NativeGameWebViewEventSink by recordingSink(events) {
            override fun resourceError(generation: Long, errorCode: Int, kind: NativeGameWebViewResourceKind?) {
                events += "resource:$generation:$errorCode"
            }
        }
        val delegate = NativeGameWebViewClientDelegate(
            generation = 7,
            sink = sink,
            acceptsGeneration = { true },
            prepareRenderProcessGone = { true },
            onRenderProcessGone = {},
        )
        delegate.receivedError(false, -2, "https://private.invalid/token=secret")
        assertEquals(listOf("resource:7:-2"), events)
    }

    @Test
    fun reportsPageEventsForTheCurrentGeneration() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)

        delegate.pageStarted("https://example.test/start")
        delegate.pageFinished("https://example.test/finish")

        assertEquals(
            listOf("started:https://example.test/start", "finished:https://example.test/finish"),
            events,
        )
    }

    @Test
    fun allowsOnlyHttpAndHttpsNavigation() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)

        assertFalse(delegate.shouldOverrideUrlLoading("https://example.test/path?q=secret"))
        assertFalse(delegate.shouldOverrideUrlLoading("HTTP://example.test"))
        assertTrue(delegate.shouldOverrideUrlLoading("intent:#Intent;end"))
        assertTrue(delegate.shouldOverrideUrlLoading("javascript:alert(1)"))
        assertTrue(delegate.shouldOverrideUrlLoading(""))
        assertTrue(delegate.shouldOverrideUrlLoading("not a uri"))

        assertEquals(
            listOf("blocked:intent", "blocked:javascript", "blocked:invalid", "blocked:invalid"),
            events,
        )
    }

    @Test
    fun normalizesAndLimitsBlockedScheme() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)

        delegate.shouldOverrideUrlLoading("CuStOmSchemeWhichIsFarLongerThanThirtyTwoCharacters:value")

        assertEquals("blocked:customschemewhichisfarlongerthan", events.single())
    }

    @Test
    fun blocksSubframeCustomSchemesWithoutReportingNavigation() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)

        assertTrue(delegate.shouldOverrideUrlLoading("intent:#Intent;end", isMainFrame = false))
        assertFalse(delegate.shouldOverrideUrlLoading("https://example.test", isMainFrame = false))

        assertTrue(events.isEmpty())
    }

    @Test
    fun reportsOnlyMainFrameErrorsAndSanitizesDescriptions() {
        val events = mutableListOf<String>()
        val delegate = delegate(events)
        val description = "x".repeat(300)

        delegate.receivedError(isMainFrame = false, errorCode = -1, description = "subresource")
        delegate.receivedError(isMainFrame = true, errorCode = -2, description = description)

        assertEquals(1, events.size)
        assertEquals("error:-2:${"x".repeat(256)}", events.single())
    }

    @Test
    fun ignoresEventsForOldGeneration() {
        val events = mutableListOf<String>()
        val delegate = NativeGameWebViewClientDelegate(
            generation = 7,
            sink = recordingSink(events),
            acceptsGeneration = { false },
            prepareRenderProcessGone = { true },
            onRenderProcessGone = {},
        )

        delegate.pageStarted("https://example.test")
        delegate.pageProgress(25) { "https://example.test" }
        delegate.receivedError(true, -1, "error")
        delegate.receivedHttpError(false, 503, "https://w00g.kancolle-server.com/gadget_html5/js/kcs_const.js")
        assertTrue(delegate.shouldOverrideUrlLoading("intent:#Intent;end"))
        assertTrue(delegate.renderProcessGone(didCrash = true))

        assertTrue(events.isEmpty())
    }

    @Test
    fun renderGoneEmitsBeforeCleanupAndIsolatesExceptions() {
        val events = mutableListOf<String>()
        val delegate = NativeGameWebViewClientDelegate(
            generation = 3,
            sink = object : NativeGameWebViewEventSink {
                override fun created(generation: Long) = Unit
                override fun pageStarted(generation: Long, url: String) = Unit
                override fun pageFinished(generation: Long, url: String) = Unit
                override fun mainFrameError(generation: Long, errorCode: Int, description: String) = Unit
                override fun navigationBlocked(generation: Long, scheme: String) = Unit
                override fun renderProcessGone(generation: Long, didCrash: Boolean) {
                    events += "event"
                    throw IllegalStateException("sink failure")
                }
                override fun destroyed(generation: Long) = Unit
            },
            acceptsGeneration = { true },
            prepareRenderProcessGone = { true },
            onRenderProcessGone = {
                events += "cleanup"
                throw IllegalStateException("cleanup failure")
            },
        )

        assertTrue(delegate.renderProcessGone(didCrash = true))

        assertEquals(listOf("event", "cleanup"), events)
    }

    @Test
    fun renderGonePreparesTheHostBeforeNotifyingTheSink() {
        val events = mutableListOf<String>()
        var active = true
        val delegate = NativeGameWebViewClientDelegate(
            generation = 3,
            sink = recordingSink(events),
            acceptsGeneration = { active },
            prepareRenderProcessGone = {
                events += "prepared"
                active = false
                true
            },
            onRenderProcessGone = { events += "cleanup" },
        )

        assertTrue(delegate.renderProcessGone(didCrash = true))

        assertEquals(listOf("prepared", "gone:true", "cleanup"), events)
    }

    private fun delegate(events: MutableList<String>) = NativeGameWebViewClientDelegate(
        generation = 2,
        sink = recordingSink(events),
        acceptsGeneration = { true },
        prepareRenderProcessGone = { true },
        onRenderProcessGone = {},
    )

    private fun recordingSink(events: MutableList<String>) = object : NativeGameWebViewEventSink {
        override fun created(generation: Long) = Unit
        override fun pageStarted(generation: Long, url: String) {
            events.add("started:$url")
        }
        override fun pageFinished(generation: Long, url: String) {
            events.add("finished:$url")
        }
        override fun pageProgress(generation: Long, progress: Int, url: String?) {
            events.add("progress:$generation:$progress:$url")
        }
        override fun resourceError(generation: Long, errorCode: Int, kind: NativeGameWebViewResourceKind?) {
            if (kind == NativeGameWebViewResourceKind.GADGET) events.add("gadget:$errorCode")
        }
        override fun mainFrameError(generation: Long, errorCode: Int, description: String) {
            events.add("error:$errorCode:$description")
        }
        override fun navigationBlocked(generation: Long, scheme: String) {
            events.add("blocked:$scheme")
        }
        override fun renderProcessGone(generation: Long, didCrash: Boolean) {
            events.add("gone:$didCrash")
        }
        override fun destroyed(generation: Long) = Unit
    }
}
