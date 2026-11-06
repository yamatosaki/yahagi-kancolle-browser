package app.yahagi.kancollebrowser.nativewebview

import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeGameWebViewChannelTest {
    @Test
    fun viewportClipIsAcceptedOnlyAsACompleteFiniteRectangle() {
        val host = FakeHost()
        val channel = activeChannel(host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        val bounds = mapOf(
            "left" to -100.0, "top" to -60.0, "width" to 1200.0, "height" to 720.0,
            "devicePixelRatio" to 1.0,
            "clipLeft" to 20.0, "clipTop" to 40.0, "clipWidth" to 700.0, "clipHeight" to 400.0,
        )
        assertSuccess(channel, "setBounds", mapOf("generationId" to 0, "bounds" to bounds), null)
        for (invalidBounds in listOf(bounds - "clipTop", bounds + ("clipWidth" to 0.0), bounds + ("clipLeft" to Double.NaN))) {
            val result = RecordingResult()
            channel.onMethodCall(MethodCall("setBounds", mapOf("generationId" to 0, "bounds" to invalidBounds)), result)
            assertEquals("invalid_argument", result.errorCode)
        }
    }

    @Test
    fun createFailurePreservesStageAndSafeDetails() {
        val host = FakeHost().apply {
            createFailure = NativeGameWebViewCreateException(
                stage = NativeGameWebViewCreateStage.CONFIGURE_WEB_VIEW,
                cause = IllegalStateException("configuration failure"),
                webViewPackage = "com.google.android.webview",
                webViewVersion = "151.0.7922.85",
                sdkInt = 36,
            )
        }
        val channel = activeChannel(host)
        val result = RecordingResult()

        channel.onMethodCall(
            MethodCall("create", mapOf("renderer" to "webgl")),
            result,
        )

        assertEquals("native_webview_create_failed", result.errorCode)
        assertTrue(result.errorMessage!!.contains("configure_web_view"))
        assertEquals(
            mapOf(
                "stage" to "configure_web_view",
                "exceptionType" to "IllegalStateException",
                "webViewPackage" to "com.google.android.webview",
                "webViewVersion" to "151.0.7922.85",
                "sdkInt" to 36,
            ),
            result.errorDetails,
        )
    }

    @Test
    fun channelNamesExactlyMatchDartContract() {
        assertEquals(
            "app.yahagi.kancollebrowser/native_game_webview",
            NativeGameWebViewChannel.METHOD_CHANNEL_NAME,
        )
        assertEquals(
            "app.yahagi.kancollebrowser/native_game_webview_events",
            NativeGameWebViewChannel.EVENT_CHANNEL_NAME,
        )
    }

    @Test
    fun createRequiresExactRendererSchemaAndRunsOnMainDispatcher() {
        val host = FakeHost()
        val queued = mutableListOf<() -> Unit>()
        val channel = activeChannel(host, dispatchToMain = queued::add)
        val valid = RecordingResult()

        channel.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), valid)

        assertEquals(1, queued.size)
        assertEquals(0, host.createCalls)
        assertNull(valid.successValue)
        queued.removeAt(0).invoke()
        assertEquals(0L, valid.successValue)
        assertEquals(1, host.createCalls)

        listOf(
            null,
            emptyMap<String, Any?>(),
            mapOf("renderer" to "canvas"),
            mapOf("renderer" to "webgl", "extra" to true),
            mapOf(1 to "webgl"),
        ).forEach { arguments ->
            val invalid = RecordingResult()
            channel.onMethodCall(MethodCall("create", arguments), invalid)
            assertEquals("invalid_argument", invalid.errorCode)
            assertTrue(queued.isEmpty())
        }
    }

    @Test
    fun currentDartCommandsUseStrictArgumentsAndRejectStaleGeneration() {
        val host = FakeHost()
        val channel = activeChannel(host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        assertSuccess(
            channel,
            "setBounds",
            mapOf(
                "generationId" to 0,
                "bounds" to mapOf(
                    "left" to -1.5,
                    "top" to 2.0,
                    "width" to 1200.0,
                    "height" to 720.0,
                    "devicePixelRatio" to 2.5,
                ),
            ),
            null,
        )
        assertEquals(NativeGameWebViewBounds(-1.5, 2.0, 1200.0, 720.0, 2.5), host.bounds)
        assertSuccess(channel, "setVisible", mapOf("generationId" to 0, "visible" to true), null)
        assertSuccess(channel, "loadUri", mapOf("generationId" to 0, "uri" to "https://example.com/game"), null)
        assertSuccess(
            channel,
            "showLocalHome",
            mapOf("generationId" to 0, "html" to "<html>native home</html>"),
            null,
        )
        assertSuccess(channel, "reload", generation(0), null)
        assertSuccess(channel, "canGoBack", generation(0), true)
        assertSuccess(channel, "goBack", generation(0), null)
        assertSuccess(channel, "runJavaScript", mapOf("generationId" to 0, "javascript" to "1 + 1"), null)
        assertSuccess(
            channel,
            "fitGameScreen",
            mapOf("generationId" to 0, "javascript" to "window.fit()"),
            null,
        )
        assertEquals("<html>native home</html>", host.localHomeHtml)
        assertEquals("window.fit()", host.fitJavascript)
        assertSuccess(channel, "clearCache", generation(0), null)
        assertSuccess(channel, "clearSession", generation(0), null)

        val invalidCases = listOf(
            "setBounds" to mapOf("generationId" to 0, "bounds" to mapOf("left" to 0.0)),
            "setBounds" to mapOf(
                "generationId" to 0,
                "bounds" to mapOf(
                    "left" to 0,
                    "top" to 0.0,
                    "width" to 1.0,
                    "height" to 1.0,
                    "devicePixelRatio" to 1.0,
                ),
            ),
            "setVisible" to mapOf("generationId" to 0, "visible" to 1),
            "loadUri" to mapOf("generationId" to 0, "uri" to "javascript:alert(1)"),
            "reload" to mapOf("generationId" to 0, "extra" to true),
            "runJavaScript" to mapOf("generationId" to 0, "javascript" to 1),
            "goBack" to mapOf("generationId" to 0.0),
        )
        invalidCases.forEach { (method, arguments) ->
            assertError(channel, method, arguments, "invalid_argument")
        }

        assertError(channel, "reload", generation(99), "stale_generation")
        assertError(channel, "destroy", generation(99), "stale_generation")
    }

    @Test
    fun currentGenerationLayoutRejectionReturnsHostErrorRatherThanStale() {
        val host = FakeHost().apply {
            setBoundsResult = false
            setVisibleResult = false
        }
        val channel = activeChannel(host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        assertError(
            channel,
            "setBounds",
            mapOf(
                "generationId" to 0,
                "bounds" to mapOf(
                    "left" to 0.0,
                    "top" to 0.0,
                    "width" to 1.0,
                    "height" to 1.0,
                    "devicePixelRatio" to 1.0,
                ),
            ),
            "native_webview_error",
        )
        assertError(
            channel,
            "setVisible",
            mapOf("generationId" to 0, "visible" to true),
            "native_webview_error",
        )
    }

    @Test
    fun everyMethodValidatesItsCompleteSchemaBeforeCheckingGeneration() {
        val channel = activeChannel(FakeHost())
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        val invalidAndStale = listOf(
            "setBounds" to mapOf("generationId" to 99, "bounds" to emptyMap<String, Any?>()),
            "setVisible" to mapOf("generationId" to 99, "visible" to 1),
            "loadUri" to mapOf("generationId" to 99, "uri" to "javascript:alert(1)"),
            "showLocalHome" to mapOf("generationId" to 99, "html" to 1),
            "reload" to mapOf("generationId" to 99, "extra" to true),
            "canGoBack" to mapOf("generationId" to 99, "extra" to true),
            "goBack" to mapOf("generationId" to 99, "extra" to true),
            "runJavaScript" to mapOf("generationId" to 99, "javascript" to 1),
            "fitGameScreen" to mapOf("generationId" to 99, "javascript" to 1),
            "clearCache" to mapOf("generationId" to 99, "extra" to true),
            "clearSession" to mapOf("generationId" to 99, "extra" to true),
            "destroy" to mapOf("generationId" to 99, "extra" to true),
        )

        invalidAndStale.forEach { (method, arguments) ->
            assertError(channel, method, arguments, "invalid_argument")
        }
    }

    @Test
    fun cachedEngineDestroyedListenerCanImmediatelyQueueCreateUntilNewHostAttaches() {
        val registry = NativeGameWebViewChannelRegistry<Any>()
        val engine = Any()
        var registrations = 0
        val channel = registry.acquire(engine) { registrations++ }
        val pendingCreate = RecordingResult()
        val events = RecordingEventSink { event ->
            if ((event as? Map<*, *>)?.get("type") == "destroyed") {
                channel.onMethodCall(
                    MethodCall("create", mapOf("renderer" to "webgl")),
                    pendingCreate,
                )
            }
        }
        channel.onListen(null, events)
        val firstDispatches = mutableListOf<() -> Unit>()
        val firstAttachment = channel.attachActivity(firstDispatches::add)
        val firstHost = FakeHost(event = hostEvents(channel.eventSinkFor(firstAttachment)))
        channel.attachHost(firstAttachment, firstHost)
        val firstCreate = RecordingResult()
        channel.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), firstCreate)
        firstDispatches.removeAt(0).invoke()
        assertEquals(0L, firstCreate.successValue)

        channel.detachActivity(firstAttachment)
        assertEquals(listOf("create:0", "destroy:0"), firstHost.operations)
        assertEquals(mapOf("type" to "destroyed", "generationId" to 0L), events.values.last())
        assertEquals(0, pendingCreate.completionCount)

        val rebound = registry.acquire(engine) { registrations++ }
        assertTrue(channel === rebound)
        val secondDispatches = mutableListOf<() -> Unit>()
        val secondAttachment = rebound.attachActivity(secondDispatches::add)
        val secondHost = FakeHost(event = hostEvents(rebound.eventSinkFor(secondAttachment)))
        rebound.attachHost(secondAttachment, secondHost)
        assertEquals(0, pendingCreate.completionCount)
        secondDispatches.removeAt(0).invoke()

        assertEquals(1, registrations)
        assertEquals(0L, pendingCreate.successValue)
        assertEquals(
            listOf(
                mapOf("type" to "created", "generationId" to 0L),
                mapOf("type" to "destroyed", "generationId" to 0L),
                mapOf("type" to "created", "generationId" to 0L),
            ),
            events.values,
        )
    }

    @Test
    fun rebindQueueKeepsCommandsBehindItsSinglePendingCreate() {
        val channel = NativeGameWebViewChannel()
        val firstAttachment = channel.attachActivity(dispatchToMain = { it() })
        channel.attachHost(firstAttachment, FakeHost())
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        channel.detachActivity(firstAttachment)
        val pendingCreate = RecordingResult()
        val pendingLoad = RecordingResult()

        channel.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), pendingCreate)
        channel.onMethodCall(
            MethodCall("loadUri", mapOf("generationId" to 0, "uri" to "https://example.com/game")),
            pendingLoad,
        )

        assertEquals(0, pendingCreate.completionCount)
        assertEquals(0, pendingLoad.completionCount)
        val dispatches = mutableListOf<() -> Unit>()
        val secondHost = FakeHost()
        val secondAttachment = channel.attachActivity(dispatches::add)
        channel.attachHost(secondAttachment, secondHost)
        assertEquals(1, dispatches.size)
        dispatches.removeAt(0).invoke()
        assertEquals(1, pendingCreate.completionCount)
        assertEquals(0, pendingLoad.completionCount)
        assertEquals(0, secondHost.loadUriCalls)
        dispatches.removeAt(0).invoke()

        assertEquals(1, pendingLoad.completionCount)
        assertEquals(1, secondHost.loadUriCalls)
    }

    @Test
    fun rebindWindowRejectsASecondCreateWithoutReplacingThePendingCreate() {
        val channel = NativeGameWebViewChannel()
        val attachment = channel.attachActivity(dispatchToMain = { it() })
        channel.attachHost(attachment, FakeHost())
        channel.detachActivity(attachment)
        val first = RecordingResult()
        val second = RecordingResult()

        channel.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), first)
        channel.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), second)

        assertEquals(0, first.completionCount)
        assertEquals("native_webview_unavailable", second.errorCode)
        val rebound = channel.attachActivity(dispatchToMain = { it() })
        channel.attachHost(rebound, FakeHost())
        assertEquals(0L, first.successValue)
    }

    @Test
    fun engineShutdownCompletesAQueuedRebindCreateWithUnavailable() {
        val channel = NativeGameWebViewChannel()
        val attachment = channel.attachActivity(dispatchToMain = { it() })
        channel.attachHost(attachment, FakeHost())
        channel.detachActivity(attachment)
        val pending = RecordingResult()
        channel.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), pending)
        assertEquals(0, pending.completionCount)

        channel.shutdownEngine()

        assertEquals(1, pending.completionCount)
        assertEquals("native_webview_unavailable", pending.errorCode)
    }

    @Test
    fun oldAttachmentLateEventsCannotTouchANewHostThatReusesItsGeneration() {
        val channel = NativeGameWebViewChannel()
        val events = RecordingEventSink()
        channel.onListen(null, events)
        val firstAttachment = channel.attachActivity(dispatchToMain = { it() })
        val firstSink = channel.eventSinkFor(firstAttachment)
        val firstHost = FakeHost(event = hostEvents(firstSink))
        channel.attachHost(firstAttachment, firstHost)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        channel.detachActivity(firstAttachment)
        val observer = RecordingLifecycleObserver()
        val secondAttachment = channel.attachActivity(
            dispatchToMain = { it() },
            lifecycleObserver = observer,
        )
        val secondSink = channel.eventSinkFor(secondAttachment)
        val secondHost = FakeHost(event = hostEvents(secondSink))
        channel.attachHost(secondAttachment, secondHost)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        firstSink.created(0)
        firstSink.pageStarted(0, "https://old.example/start")
        firstSink.pageFinished(0, "https://old.example/finish")
        firstSink.mainFrameError(0, -2, "old error")
        firstSink.navigationBlocked(0, "intent")
        firstSink.presentationChanged(0, true)
        firstSink.renderProcessGone(0, true)
        firstSink.destroyed(0)
        secondSink.pageStarted(0, "https://new.example/start")
        secondSink.pageFinished(0, "https://new.example/finish")

        assertSuccess(channel, "reload", generation(0), null)
        assertEquals(1, secondHost.reloadCalls)
        assertEquals(1, observer.createdCalls)
        assertEquals(1, observer.pageStartedCalls)
        assertEquals(1, observer.pageFinishedCalls)
        assertEquals(0, observer.renderProcessGoneCalls)
        assertEquals(
            listOf(
                mapOf("type" to "created", "generationId" to 0L),
                mapOf("type" to "destroyed", "generationId" to 0L),
                mapOf("type" to "created", "generationId" to 0L),
                mapOf(
                    "type" to "pageStarted",
                    "generationId" to 0L,
                    "url" to "https://new.example/start",
                ),
                mapOf(
                    "type" to "pageFinished",
                    "generationId" to 0L,
                    "url" to "https://new.example/finish",
                ),
            ),
            events.values,
        )
    }

    @Test
    fun staleOldDispatcherCannotUnlockOrDuplicateTheNewAttachmentQueue() {
        val channel = NativeGameWebViewChannel()
        val oldDispatches = mutableListOf<() -> Unit>()
        val oldAttachment = channel.attachActivity(oldDispatches::add)
        val oldHost = FakeHost(event = hostEvents(channel.eventSinkFor(oldAttachment)))
        channel.attachHost(oldAttachment, oldHost)
        val events = RecordingEventSink { event ->
            if ((event as? Map<*, *>)?.get("type") == "destroyed") {
                channel.onMethodCall(
                    MethodCall("create", mapOf("renderer" to "webgl")),
                    RecordingResult(),
                )
            }
        }
        channel.onListen(null, events)
        val initialCreate = RecordingResult()
        channel.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), initialCreate)
        oldDispatches.removeAt(0).invoke()
        val abandonedReload = RecordingResult()
        channel.onMethodCall(MethodCall("reload", generation(0)), abandonedReload)
        val staleDispatcher = oldDispatches.removeAt(0)

        channel.detachActivity(oldAttachment)
        val newDispatches = mutableListOf<() -> Unit>()
        val newAttachment = channel.attachActivity(newDispatches::add)
        channel.attachHost(newAttachment, FakeHost())
        assertEquals(1, newDispatches.size)

        staleDispatcher.invoke()
        val queuedLoad = RecordingResult()
        channel.onMethodCall(
            MethodCall("loadUri", mapOf("generationId" to 0, "uri" to "https://example.com/game")),
            queuedLoad,
        )

        assertEquals(1, newDispatches.size)
        assertEquals(1, abandonedReload.completionCount)
        assertEquals("native_webview_unavailable", abandonedReload.errorCode)
        assertEquals(0, queuedLoad.completionCount)
    }

    @Test
    fun pendingCreateSurvivesAnAttachmentThatDetachesBeforeItsDispatchRuns() {
        val channel = NativeGameWebViewChannel()
        val firstAttachment = channel.attachActivity(dispatchToMain = { it() })
        channel.attachHost(firstAttachment, FakeHost())
        channel.detachActivity(firstAttachment)
        val pendingCreate = RecordingResult()
        channel.onMethodCall(
            MethodCall("create", mapOf("renderer" to "webgl")),
            pendingCreate,
        )
        val abandonedDispatches = mutableListOf<() -> Unit>()
        val abandonedAttachment = channel.attachActivity(abandonedDispatches::add)
        channel.attachHost(abandonedAttachment, FakeHost())
        assertEquals(1, abandonedDispatches.size)

        channel.detachActivity(abandonedAttachment)
        assertEquals(0, pendingCreate.completionCount)
        val finalAttachment = channel.attachActivity(dispatchToMain = { it() })
        channel.attachHost(finalAttachment, FakeHost())

        assertEquals(1, pendingCreate.completionCount)
        assertEquals(0L, pendingCreate.successValue)
        abandonedDispatches.single().invoke()
        assertEquals(1, pendingCreate.completionCount)
    }

    @Test
    fun destroyedEngineUnregistersAndEndsStreamWhileCachedEngineRemainsRegistered() {
        val registry = NativeGameWebViewChannelRegistry<Any>()
        val cachedEngine = Any()
        val destroyedEngine = Any()
        var registrations = 0
        val cached = registry.acquire(cachedEngine) { registrations++ }
        val destroyed = registry.acquire(destroyedEngine) { registrations++ }
        val sink = RecordingEventSink()
        destroyed.onListen(null, sink)

        assertTrue(registry.peek(cachedEngine) === cached)
        val removed = registry.remove(destroyedEngine)
        removed?.shutdownEngine()

        assertNull(registry.peek(destroyedEngine))
        assertTrue(registry.peek(cachedEngine) === cached)
        assertEquals(2, registrations)
        assertEquals(1, sink.endCalls)
    }

    @Test
    fun clearSessionSerializesLaterCommandsAndIgnoresDuplicateOrDetachedCallback() {
        val host = FakeHost().apply { autoCompleteClearSession = false }
        val channel = activeChannel(host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        val clear = RecordingResult()
        val load = RecordingResult()
        channel.onMethodCall(MethodCall("clearSession", generation(0)), clear)
        channel.onMethodCall(
            MethodCall("loadUri", mapOf("generationId" to 0, "uri" to "https://example.com/game")),
            load,
        )

        assertEquals(1, host.clearSessionCalls)
        assertEquals(0, host.loadUriCalls)
        assertEquals(0, clear.completionCount)
        host.completeClearSession(null)
        assertEquals(1, clear.completionCount)
        assertEquals(1, host.loadUriCalls)
        assertEquals(1, load.completionCount)
        host.completeClearSession(IllegalStateException("duplicate"))
        assertEquals(1, clear.completionCount)

        val detachedHost = FakeHost().apply { autoCompleteClearSession = false }
        val detachedChannel = NativeGameWebViewChannel()
        val attachment = detachedChannel.attachActivity(dispatchToMain = { it() })
        detachedChannel.attachHost(attachment, detachedHost)
        assertSuccess(detachedChannel, "create", mapOf("renderer" to "webgl"), 0L)
        val abandoned = RecordingResult()
        detachedChannel.onMethodCall(MethodCall("clearSession", generation(0)), abandoned)
        detachedChannel.disable()
        assertEquals(1, abandoned.completionCount)
        assertEquals("native_webview_unavailable", abandoned.errorCode)
        detachedHost.completeClearSession(null)
        assertEquals(1, abandoned.completionCount)
    }

    @Test
    fun detachCompletesRunningAndQueuedAttachmentCallsExactlyOnce() {
        val dispatches = mutableListOf<() -> Unit>()
        val channel = NativeGameWebViewChannel()
        val attachment = channel.attachActivity(dispatches::add)
        channel.attachHost(attachment, FakeHost())
        val create = RecordingResult()
        channel.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), create)
        dispatches.removeAt(0).invoke()
        val reload = RecordingResult()
        val load = RecordingResult()
        channel.onMethodCall(MethodCall("reload", generation(0)), reload)
        val lateReloadDispatcher = dispatches.removeAt(0)
        channel.onMethodCall(
            MethodCall("loadUri", mapOf("generationId" to 0, "uri" to "https://example.com/game")),
            load,
        )

        channel.detachActivity(attachment)

        assertEquals(1, reload.completionCount)
        assertEquals("native_webview_unavailable", reload.errorCode)
        assertEquals(1, load.completionCount)
        assertEquals("native_webview_unavailable", load.errorCode)
        lateReloadDispatcher.invoke()
        assertEquals(1, reload.completionCount)
        assertEquals(1, load.completionCount)
    }

    @Test
    fun detachAndShutdownTerminateAsyncClearSessionWithoutDoubleCompletion() {
        listOf(false, true).forEach { shutdown ->
            val scheduler = FakeOperationTimeoutScheduler()
            val host = FakeHost().apply { autoCompleteClearSession = false }
            val channel = NativeGameWebViewChannel(scheduler)
            val attachment = channel.attachActivity(dispatchToMain = { it() })
            channel.attachHost(attachment, host)
            assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
            val clear = RecordingResult()
            val load = RecordingResult()
            channel.onMethodCall(MethodCall("clearSession", generation(0)), clear)
            channel.onMethodCall(
                MethodCall("loadUri", mapOf("generationId" to 0, "uri" to "https://example.com/game")),
                load,
            )

            if (shutdown) channel.shutdownEngine()
            else channel.detachActivity(attachment)

            assertEquals(1, clear.completionCount)
            assertEquals("native_webview_unavailable", clear.errorCode)
            assertEquals(1, load.completionCount)
            assertEquals("native_webview_unavailable", load.errorCode)
            assertTrue(scheduler.tasks.single().cancelled)
            host.completeClearSession(null)
            host.completeClearSession(IllegalStateException("duplicate"))
            assertEquals(1, clear.completionCount)
            assertEquals(1, load.completionCount)
            assertEquals(0, host.loadUriCalls)
        }
    }

    @Test
    fun clearSessionWatchdogFailsAttachmentAndBlocksQueuedOrLaterCommands() {
        val scheduler = FakeOperationTimeoutScheduler()
        val host = FakeHost().apply { autoCompleteClearSession = false }
        val channel = NativeGameWebViewChannel(scheduler)
        val attachment = channel.attachActivity(dispatchToMain = { it() })
        channel.attachHost(attachment, host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        val clear = RecordingResult()
        val queuedLoad = RecordingResult()
        channel.onMethodCall(MethodCall("clearSession", generation(0)), clear)
        channel.onMethodCall(
            MethodCall("loadUri", mapOf("generationId" to 0, "uri" to "https://example.com/queued")),
            queuedLoad,
        )

        scheduler.fireNext()

        assertEquals("native_webview_unavailable", clear.errorCode)
        assertEquals("native_webview_unavailable", queuedLoad.errorCode)
        assertEquals(0, host.loadUriCalls)
        assertError(
            channel,
            "loadUri",
            mapOf("generationId" to 0, "uri" to "https://example.com/later"),
            "native_webview_unavailable",
        )
        host.completeClearSession(null)
        assertEquals(1, clear.completionCount)
        assertEquals(1, queuedLoad.completionCount)

        channel.detachActivity(attachment)
        val nextHost = FakeHost()
        val nextAttachment = channel.attachActivity(dispatchToMain = { it() })
        channel.attachHost(nextAttachment, nextHost)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
    }

    @Test
    fun rejectedClearSessionCallbackDispatchFailsAttachmentAndCancelsWatchdog() {
        val scheduler = FakeOperationTimeoutScheduler()
        val host = FakeHost().apply { autoCompleteClearSession = false }
        var rejectDispatch = false
        val channel = NativeGameWebViewChannel(scheduler)
        val attachment = channel.attachActivity(
            dispatchToMain = { operation ->
                if (rejectDispatch) throw IllegalStateException("dispatcher rejected")
                operation()
            },
        )
        channel.attachHost(attachment, host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        val clear = RecordingResult()
        val load = RecordingResult()
        channel.onMethodCall(MethodCall("clearSession", generation(0)), clear)
        channel.onMethodCall(
            MethodCall("loadUri", mapOf("generationId" to 0, "uri" to "https://example.com/game")),
            load,
        )

        rejectDispatch = true
        host.completeClearSession(null)

        assertEquals("native_webview_unavailable", clear.errorCode)
        assertEquals("native_webview_unavailable", load.errorCode)
        assertEquals(0, host.loadUriCalls)
        assertTrue(scheduler.tasks.single().cancelled)
        scheduler.fireNext()
        assertEquals(1, clear.completionCount)
        assertEquals(1, load.completionCount)
    }

    @Test
    fun unreturnedClearSessionCallbackDoesNotRetainDetachedActivityObserver() {
        val host = FakeHost().apply { autoCompleteClearSession = false }
        val channel = NativeGameWebViewChannel(FakeOperationTimeoutScheduler())
        val retained = startClearSessionAndDetachWithRetainedMarker(channel, host)

        assertEventuallyCollected(retained)
    }

    @Test
    fun unreturnedClearSessionCallbackDoesNotRetainTerminalFlutterResult() {
        val host = FakeHost().apply { autoCompleteClearSession = false }
        val channel = NativeGameWebViewChannel(FakeOperationTimeoutScheduler())
        val retained = startClearSessionAndDetachWithRetainingResult(channel, host)

        assertEventuallyCollected(retained)
    }

    @Test
    fun clearSessionCallbackFailureCompletesOnceWithFixedHostError() {
        val host = FakeHost().apply { autoCompleteClearSession = false }
        val channel = activeChannel(host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        val result = RecordingResult()

        channel.onMethodCall(MethodCall("clearSession", generation(0)), result)
        host.completeClearSession(IllegalStateException("cookie failure"))

        assertEquals("native_webview_error", result.errorCode)
        assertEquals(1, result.completionCount)
    }

    @Test
    fun unknownMethodIsNotImplemented() {
        val result = RecordingResult()

        activeChannel(FakeHost()).onMethodCall(MethodCall("futureTask8Command", emptyMap<String, Any?>()), result)

        assertTrue(result.notImplemented)
    }

    @Test
    fun repeatedCreateDeterministicallyDestroysOldGenerationBeforeCreatingNewOne() {
        val channel = NativeGameWebViewChannel()
        val attachment = channel.attachActivity(dispatchToMain = { it() })
        val host = FakeHost(event = hostEvents(channel.eventSinkFor(attachment)))
        channel.attachHost(attachment, host)
        val events = RecordingEventSink()
        channel.onListen(null, events)

        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 1L)

        assertEquals(listOf("create:0", "destroy:0", "create:1"), host.operations)
        assertEquals(
            listOf(
                mapOf("type" to "created", "generationId" to 0L),
                mapOf("type" to "destroyed", "generationId" to 0L),
                mapOf("type" to "created", "generationId" to 1L),
            ),
            events.values,
        )
    }

    @Test
    fun eventsUseExactMapsAndLateOrCancelledEventsAreSilent() {
        val channel = NativeGameWebViewChannel()
        val attachment = channel.attachActivity(dispatchToMain = { it() })
        val sink = channel.eventSinkFor(attachment)
        val host = FakeHost()
        channel.attachHost(attachment, host)
        val events = RecordingEventSink()
        channel.onListen(null, events)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        sink.created(0)
        sink.pageStarted(0, "https://example.com/start")
        sink.pageFinished(0, "https://example.com/finish")
        sink.mainFrameError(0, -2, "network")
        sink.navigationBlocked(0, "intent")
        sink.presentationChanged(0, true)
        sink.renderProcessGone(0, true)
        sink.destroyed(0)
        sink.pageFinished(0, "https://example.com/late")

        assertEquals(
            listOf(
                mapOf("type" to "created", "generationId" to 0L),
                mapOf("type" to "pageStarted", "generationId" to 0L, "url" to "https://example.com/start"),
                mapOf("type" to "pageFinished", "generationId" to 0L, "url" to "https://example.com/finish"),
                mapOf("type" to "mainFrameError", "generationId" to 0L, "errorCode" to -2, "description" to "network"),
                mapOf("type" to "navigationBlocked", "generationId" to 0L, "scheme" to "intent"),
                mapOf("type" to "presentationChanged", "generationId" to 0L, "isGame" to true),
                mapOf("type" to "renderProcessGone", "generationId" to 0L, "didCrash" to true),
                mapOf("type" to "destroyed", "generationId" to 0L),
            ),
            events.values,
        )

        channel.onCancel(null)
        sink.created(1)
        assertEquals(8, events.values.size)
    }

    @Test
    fun eventSinkFailuresAreIsolatedAndDisableMakesMethodsAndEventsSilent() {
        val channel = NativeGameWebViewChannel()
        val attachment = channel.attachActivity(dispatchToMain = { it() })
        val sink = channel.eventSinkFor(attachment)
        val host = FakeHost()
        channel.attachHost(attachment, host)
        channel.onListen(null, ThrowingEventSink())
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        sink.created(0)
        channel.disable()
        sink.destroyed(0)
        val result = RecordingResult()
        channel.onMethodCall(MethodCall("reload", generation(0)), result)

        assertEquals("activity_destroyed", result.errorCode)
        assertEquals(0, host.reloadCalls)
    }

    @Test
    fun homeAndFitCommandsRouteTheirSharedDartPayloads() {
        val host = FakeHost()
        val channel = activeChannel(host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)

        assertSuccess(
            channel,
            "showLocalHome",
            mapOf("generationId" to 0, "html" to "<html>home</html>"),
            null,
        )
        assertSuccess(
            channel,
            "fitGameScreen",
            mapOf("generationId" to 0, "javascript" to "window.fit()"),
            null,
        )

        assertEquals(1, host.showLocalHomeCalls)
        assertEquals(1, host.fitGameScreenCalls)
        assertEquals("<html>home</html>", host.localHomeHtml)
        assertEquals("window.fit()", host.fitJavascript)
    }

    @Test
    fun sharedPreferencesStoreReadsOneSnapshotAndCommitsWholeSnapshotOnce() {
        val preferences = FakeSnapshotPreferences(
            mutableMapOf(
                NativeWebViewStartupGuard.CONSECUTIVE_FAILURES_KEY to 1,
                NativeWebViewStartupGuard.LAST_STARTUP_STARTED_AT_MS_KEY to 10L,
                NativeWebViewStartupGuard.ATTEMPT_SESSION_ID_KEY to "session-a",
                NativeWebViewStartupGuard.RENDERING_MODE_KEY to "nativeActivityExperimental",
            ),
        )
        val processState = NativeWebViewStartupStoreProcessState()
        val store = SharedPreferencesNativeWebViewStartupStore(preferences, processState)

        assertEquals(
            NativeWebViewStartupReadResult.Success(
                NativeWebViewStartupSnapshot(1, 10L, NativeWebViewProcessSessionId("session-a"), "nativeActivityExperimental"),
            ),
            store.read(),
        )
        assertEquals(1, preferences.readCalls)

        val next = NativeWebViewStartupSnapshot(2, null, null, "compatibility")
        assertEquals(NativeWebViewStartupWriteResult.Durable, store.write(next))
        assertEquals(1, preferences.editCalls)
        assertEquals(1, preferences.commitCalls)
        assertEquals(2, preferences.values[NativeWebViewStartupGuard.CONSECUTIVE_FAILURES_KEY])
        assertFalse(preferences.values.containsKey(NativeWebViewStartupGuard.LAST_STARTUP_STARTED_AT_MS_KEY))
        assertFalse(preferences.values.containsKey(NativeWebViewStartupGuard.ATTEMPT_SESSION_ID_KEY))
        assertEquals("compatibility", preferences.values[NativeWebViewStartupGuard.RENDERING_MODE_KEY])
    }

    @Test
    fun failedCommitPoisonsEveryNewAdapterInSameProcessButNotNewProcess() {
        val preferences = FakeSnapshotPreferences(commitResult = false)
        val sameProcess = NativeWebViewStartupStoreProcessState()
        val first = SharedPreferencesNativeWebViewStartupStore(preferences, sameProcess)

        assertEquals(
            NativeWebViewStartupWriteResult.Indeterminate,
            first.write(NativeWebViewStartupSnapshot(1, 0, NativeWebViewProcessSessionId("a"), "nativeActivityExperimental")),
        )
        assertEquals(
            NativeWebViewStartupReadResult.Unavailable,
            SharedPreferencesNativeWebViewStartupStore(preferences, sameProcess).read(),
        )
        assertEquals(0, preferences.readCalls)
        val poisonedActivity = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(
                SharedPreferencesNativeWebViewStartupStore(preferences, sameProcess),
                NativeWebViewProcessSessionId("next-activity"),
            ),
            nowMs = { 1L },
            scheduleTimeout = { _, _ -> },
            cancelTimeout = {},
            requestRestart = {},
        )
        val poisonedOutcome = poisonedActivity.begin("nativeActivityExperimental")
        val poisonedChannel = NativeGameWebViewChannel()
        val poisonedAttachment = poisonedChannel.attachActivity(dispatchToMain = { it() })
        poisonedChannel.attachUnavailable(
            poisonedAttachment,
            poisonedOutcome as NativeWebViewActivityStartupOutcome.Unavailable,
        )
        assertError(
            poisonedChannel,
            "create",
            mapOf("renderer" to "webgl"),
            "native_webview_startup_failed",
        )

        preferences.commitResult = true
        assertTrue(
            SharedPreferencesNativeWebViewStartupStore(
                preferences,
                NativeWebViewStartupStoreProcessState(),
            ).read() is NativeWebViewStartupReadResult.Success,
        )
        assertEquals(1, preferences.readCalls)
    }

    @Test
    fun persistenceExceptionsFailClosedWithoutSwallowingFatalThrowables() {
        val readException = FakeSnapshotPreferences(readFailure = IllegalStateException("read"))
        assertEquals(
            NativeWebViewStartupReadResult.Unavailable,
            SharedPreferencesNativeWebViewStartupStore(readException, NativeWebViewStartupStoreProcessState()).read(),
        )

        val writeException = FakeSnapshotPreferences(commitFailure = IllegalStateException("commit"))
        val state = NativeWebViewStartupStoreProcessState()
        val store = SharedPreferencesNativeWebViewStartupStore(writeException, state)
        assertEquals(
            NativeWebViewStartupWriteResult.Indeterminate,
            store.write(NativeWebViewStartupSnapshot(0, null, null, null)),
        )
        assertEquals(NativeWebViewStartupReadResult.Unavailable, store.read())

        assertThrows<AssertionError> {
            SharedPreferencesNativeWebViewStartupStore(
                FakeSnapshotPreferences(readFailure = AssertionError("fatal")),
                NativeWebViewStartupStoreProcessState(),
            ).read()
        }
    }

    @Test
    fun persistedFallbackIsVisibleAndCompatibilityNeverStarts() {
        val preferences = FakeSnapshotPreferences(
            mutableMapOf(
                NativeWebViewStartupGuard.CONSECUTIVE_FAILURES_KEY to 1,
                NativeWebViewStartupGuard.LAST_STARTUP_STARTED_AT_MS_KEY to 0L,
                NativeWebViewStartupGuard.ATTEMPT_SESSION_ID_KEY to "old",
                NativeWebViewStartupGuard.RENDERING_MODE_KEY to "nativeActivityExperimental",
            ),
        )
        val state = NativeWebViewStartupStoreProcessState()
        val store = SharedPreferencesNativeWebViewStartupStore(preferences, state)

        assertEquals(
            NativeWebViewStartupDecision.FallbackTriggered,
            NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("new")).beginAttempt(1),
        )
        assertEquals("compatibility", preferences.values[NativeWebViewStartupGuard.RENDERING_MODE_KEY])
        assertEquals(
            NativeWebViewStartupDecision.FallbackActive,
            NativeWebViewStartupGuard(
                SharedPreferencesNativeWebViewStartupStore(preferences, state),
                NativeWebViewProcessSessionId("newer"),
            ).beginAttempt(2),
        )
    }

    @Test
    fun processSessionProviderReusesIdAcrossActivityRecreationAndChangesAcrossProcesses() {
        var sequence = 0
        val activityProcess = NativeWebViewProcessSessionIdProvider {
            NativeWebViewProcessSessionId("process-${sequence++}")
        }

        val firstActivity = activityProcess.current()
        val recreatedActivity = activityProcess.current()
        val restartedProcess = NativeWebViewProcessSessionIdProvider {
            NativeWebViewProcessSessionId("process-${sequence++}")
        }.current()

        assertEquals(firstActivity, recreatedActivity)
        assertEquals("process-0", firstActivity.value)
        assertEquals("process-1", restartedProcess.value)
    }

    @Test
    fun activityStartupCoordinatorUsesNativeDefaultForMissingPreference() {
        assertDefaultModeStartsHost(null)
    }

    @Test
    fun activityStartupCoordinatorUsesNativeDefaultForUnknownPreference() {
        listOf("", "unknown", "futureRenderingMode", "STANDARD", " compatibility ")
            .forEach(::assertDefaultModeStartsHost)
    }

    private fun assertDefaultModeStartsHost(storedMode: String?) {
        val store = CountingStore(NativeWebViewStartupSnapshot(0, null, null, storedMode))
        var scheduledDelay: Long? = null
        var restarts = 0
        val session = NativeWebViewProcessSessionId("fresh-process")
        val coordinator = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(store, session),
            nowMs = { 100L },
            scheduleTimeout = { delay, _ -> scheduledDelay = delay },
            cancelTimeout = {},
            requestRestart = { restarts++ },
        )

        assertEquals("Preference $storedMode must match the Dart native default",
            NativeWebViewActivityStartupOutcome.StartHost, coordinator.begin(storedMode))
        assertEquals(NativeWebViewStartupGuard.STARTUP_TIMEOUT_MS, scheduledDelay)
        assertEquals(NativeWebViewStartupSnapshot(0, 100L, session, storedMode), store.snapshot)
        assertEquals(0, restarts)
        coordinator.onPageFinished()
        assertNull(store.snapshot.attemptStartedAtMs)
    }

    @Test
    fun activityStartupCoordinatorRejectsAllExplicitPlatformViewModesWithoutStartingGuard() {
        listOf("standard", "compatibility", "canvasCompatibility").forEach { mode ->
            val store = CountingStore(NativeWebViewStartupSnapshot(0, null, null, mode))
            val coordinator = NativeWebViewActivityStartupCoordinator(
                guard = NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("process")),
                nowMs = { 100L },
                scheduleTimeout = { _, _ -> throw AssertionError("Platform mode must not start a timeout") },
                cancelTimeout = {},
                requestRestart = { throw AssertionError("Platform mode must not restart") },
            )
            assertEquals(
                NativeWebViewActivityStartupOutcome.Unavailable(
                    "native_webview_unavailable", "Native Activity WebView mode is not active.",
                ), coordinator.begin(mode),
            )
            assertEquals(0, store.reads)
        }
    }

    @Test
    fun defaultModeCannotBypassDurableCompatibilityFallback() {
        listOf(null, "unknown").forEach { mode ->
            val store = CountingStore(NativeWebViewStartupSnapshot(2, null, null, "compatibility"))
            val coordinator = NativeWebViewActivityStartupCoordinator(
                guard = NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("process")),
                nowMs = { 100L },
                scheduleTimeout = { _, _ -> throw AssertionError("Fallback must not start a timeout") },
                cancelTimeout = {},
                requestRestart = { throw AssertionError("Durable fallback must not restart again") },
            )
            assertEquals(
                NativeWebViewActivityStartupOutcome.Unavailable(
                    "native_webview_unavailable", "Native Activity WebView fallback is active.",
                ), coordinator.begin(mode),
            )
            assertEquals(NativeWebViewStartupSnapshot(2, null, null, "compatibility"), store.snapshot)
        }
    }

    @Test
    fun defaultModeStillFallsBackOnThirdProcessStartAfterTwoUnfinishedAttempts() {
        listOf(null, "unknown").forEach { mode ->
            val store = CountingStore(NativeWebViewStartupSnapshot(0, null, null, mode))
            var restarts = 0
            val scheduledDelays = mutableListOf<Long>()
            fun process(index: Int) = NativeWebViewActivityStartupCoordinator(
                guard = NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("process-$index")),
                nowMs = { index.toLong() },
                scheduleTimeout = { delay, _ -> scheduledDelays.add(delay) },
                cancelTimeout = {},
                requestRestart = { restarts++ },
            )

            assertEquals(NativeWebViewActivityStartupOutcome.StartHost, process(1).begin(mode))
            assertEquals(0, store.snapshot.consecutiveFailures)
            // Simulate process loss: no page-finished or orderly Activity close.
            assertEquals(NativeWebViewActivityStartupOutcome.StartHost, process(2).begin(mode))
            assertEquals(1, store.snapshot.consecutiveFailures)
            val thirdProcess = process(3)
            assertTrue(thirdProcess.begin(mode) is NativeWebViewActivityStartupOutcome.Unavailable)
            assertEquals(NativeWebViewStartupSnapshot(0, null, null, "compatibility"), store.snapshot)
            assertEquals(1, restarts)
            assertTrue(thirdProcess.begin(mode) is NativeWebViewActivityStartupOutcome.Unavailable)
            assertEquals(1, restarts)
            assertEquals(List(2) { NativeWebViewStartupGuard.STARTUP_TIMEOUT_MS }, scheduledDelays)
        }
    }

    @Test
    fun activityStartupCoordinatorGatesCompatibilityAndRestartsOnceAfterDurableFallback() {
        val compatibilityStore = CountingStore(
            NativeWebViewStartupSnapshot(0, null, null, "compatibility"),
        )
        val compatibility = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(compatibilityStore, NativeWebViewProcessSessionId("a")),
            nowMs = { 1L },
            scheduleTimeout = { _, _ -> },
            cancelTimeout = {},
            requestRestart = {},
        )
        assertEquals(
            NativeWebViewActivityStartupOutcome.Unavailable(
                "native_webview_unavailable",
                "Native Activity WebView mode is not active.",
            ),
            compatibility.begin("compatibility"),
        )
        assertEquals(0, compatibilityStore.reads)
        val compatibilityChannel = NativeGameWebViewChannel()
        val compatibilityAttachment = compatibilityChannel.attachActivity(dispatchToMain = { it() })
        compatibilityChannel.attachUnavailable(
            compatibilityAttachment,
            compatibility.begin("compatibility") as NativeWebViewActivityStartupOutcome.Unavailable,
        )
        assertError(
            compatibilityChannel,
            "create",
            mapOf("renderer" to "webgl"),
            "native_webview_unavailable",
        )

        val fallbackStore = CountingStore(
            NativeWebViewStartupSnapshot(
                1,
                0L,
                NativeWebViewProcessSessionId("old"),
                "nativeActivityExperimental",
            ),
        )
        var restarts = 0
        var durableModeWhenRestarted: String? = null
        val fallback = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(fallbackStore, NativeWebViewProcessSessionId("new")),
            nowMs = { 1L },
            scheduleTimeout = { _, _ -> },
            cancelTimeout = {},
            requestRestart = {
                restarts++
                durableModeWhenRestarted = fallbackStore.snapshot.storedRenderingMode
            },
        )

        assertTrue(fallback.begin("nativeActivityExperimental") is NativeWebViewActivityStartupOutcome.Unavailable)
        assertTrue(fallback.begin("nativeActivityExperimental") is NativeWebViewActivityStartupOutcome.Unavailable)
        assertEquals(1, restarts)
        assertEquals("compatibility", durableModeWhenRestarted)
    }

    @Test
    fun normalActivityCloseCancelsAnUnfinishedStartupAttempt() {
        val store = CountingStore(
            NativeWebViewStartupSnapshot(
                0,
                5L,
                NativeWebViewProcessSessionId("a"),
                "nativeActivityExperimental",
            ),
        )
        val coordinator = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("a")),
            nowMs = { 5L },
            scheduleTimeout = { _, _ -> },
            cancelTimeout = {},
            requestRestart = {},
        )

        coordinator.close()

        assertEquals(
            NativeWebViewStartupSnapshot(0, null, null, "nativeActivityExperimental"),
            store.snapshot,
        )
    }

    @Test
    fun startupPersistenceFailuresBecomeImmediateBrokerErrorsInsteadOfRebindWaits() {
        listOf(
            NativeWebViewStartupWriteResult.Failed,
            NativeWebViewStartupWriteResult.Indeterminate,
        ).forEach { writeResult ->
            val store = CountingStore(
                NativeWebViewStartupSnapshot(0, null, null, "nativeActivityExperimental"),
                writeResult = writeResult,
            )
            val coordinator = NativeWebViewActivityStartupCoordinator(
                guard = NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("process")),
                nowMs = { 1L },
                scheduleTimeout = { _, _ -> },
                cancelTimeout = {},
                requestRestart = {},
            )
            val outcome = coordinator.begin("nativeActivityExperimental")
            assertEquals(
                NativeWebViewActivityStartupOutcome.Unavailable(
                    "native_webview_startup_failed",
                    "Native WebView startup persistence is unavailable.",
                ),
                outcome,
            )
            val channel = NativeGameWebViewChannel()
            val attachment = channel.attachActivity(dispatchToMain = { it() })

            channel.attachUnavailable(attachment, outcome as NativeWebViewActivityStartupOutcome.Unavailable)

            assertError(
                channel,
                "create",
                mapOf("renderer" to "webgl"),
                "native_webview_startup_failed",
            )
        }
    }

    @Test
    fun unavailableActivityTerminatesPendingRebindAndRejectsAllLaterCalls() {
        val channel = NativeGameWebViewChannel()
        val pendingCreate = RecordingResult()
        channel.onMethodCall(MethodCall("create", mapOf("renderer" to "webgl")), pendingCreate)
        val attachment = channel.attachActivity(dispatchToMain = { it() })
        val outcome = NativeWebViewActivityStartupOutcome.Unavailable(
            "native_webview_startup_failed",
            "Host construction failed.",
        )

        channel.attachUnavailable(attachment, outcome)

        assertEquals(1, pendingCreate.completionCount)
        assertEquals("native_webview_startup_failed", pendingCreate.errorCode)
        assertError(
            channel,
            "create",
            mapOf("renderer" to "webgl"),
            "native_webview_startup_failed",
        )
        assertThrows<IllegalStateException> {
            channel.attachHost(attachment, FakeHost())
        }
    }

    @Test
    fun activityStartupCoordinatorSchedulesTimeoutAndClearsItAtReady() {
        val store = CountingStore(
            NativeWebViewStartupSnapshot(0, null, null, "nativeActivityExperimental"),
        )
        var scheduledDelay: Long? = null
        var timeout: (() -> Unit)? = null
        var cancellations = 0
        val coordinator = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("process")),
            nowMs = { 100L },
            scheduleTimeout = { delay, callback ->
                scheduledDelay = delay
                timeout = callback
            },
            cancelTimeout = { cancellations++ },
            requestRestart = {},
        )

        assertEquals(
            NativeWebViewActivityStartupOutcome.StartHost,
            coordinator.begin("nativeActivityExperimental"),
        )
        assertEquals(NativeWebViewStartupGuard.STARTUP_TIMEOUT_MS, scheduledDelay)
        coordinator.onPageFinished()
        assertEquals(1, cancellations)
        assertEquals(0, store.snapshot.consecutiveFailures)
        assertNull(store.snapshot.attemptStartedAtMs)

        timeout?.invoke()
        assertNull(store.snapshot.attemptStartedAtMs)
    }

    @Test
    fun activityStartupDeadlineCountsOnlyForegroundAndRejectsPausedCallback() {
        val store = CountingStore(
            NativeWebViewStartupSnapshot(1, null, null, "nativeActivityExperimental"),
        )
        var now = 100L
        var delay = 0L
        var callback: (() -> Unit)? = null
        var cancellations = 0
        var restarts = 0
        val coordinator = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("process")),
            nowMs = { now },
            scheduleTimeout = { scheduledDelay, operation ->
                delay = scheduledDelay
                callback = operation
            },
            cancelTimeout = { cancellations++ },
            requestRestart = { restarts++ },
        )
        coordinator.begin("nativeActivityExperimental")
        val stale = callback
        now = 20_100L
        coordinator.setForeground(false)
        assertEquals(1, cancellations)
        now = 300_100L
        stale?.invoke()
        assertEquals(1, store.snapshot.consecutiveFailures)
        assertEquals(0, restarts)
        coordinator.setForeground(true)
        assertEquals(10_000L, delay)
        now = 310_100L
        callback?.invoke()
        assertEquals(1, restarts)
        assertEquals("compatibility", store.snapshot.storedRenderingMode)
    }

    @Test
    fun readyWhileBackgroundedDoesNotRestartStartupDeadlineOnResume() {
        val store = CountingStore(
            NativeWebViewStartupSnapshot(0, null, null, "nativeActivityExperimental"),
        )
        var now = 100L
        var schedules = 0
        val coordinator = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("process")),
            nowMs = { now },
            scheduleTimeout = { _, _ -> schedules++ },
            cancelTimeout = {},
            requestRestart = { throw AssertionError("Ready must not restart the Activity") },
        )
        coordinator.begin("nativeActivityExperimental")
        coordinator.setForeground(false)
        now = 300_100L
        coordinator.onPageFinished()
        coordinator.setForeground(true)
        assertEquals(1, schedules)
        assertNull(store.snapshot.attemptStartedAtMs)
    }

    @Test
    fun startupBegunInBackgroundArmsOnlyWhenForegrounded() {
        val store = CountingStore(
            NativeWebViewStartupSnapshot(0, null, null, "nativeActivityExperimental"),
        )
        var now = 100L
        var schedules = 0
        var delay = 0L
        val coordinator = NativeWebViewActivityStartupCoordinator(
            guard = NativeWebViewStartupGuard(store, NativeWebViewProcessSessionId("process")),
            nowMs = { now },
            scheduleTimeout = { scheduledDelay, _ ->
                schedules++
                delay = scheduledDelay
            },
            cancelTimeout = {},
            requestRestart = {},
        )
        coordinator.setForeground(false)
        coordinator.begin("nativeActivityExperimental")
        assertEquals(0, schedules)
        now = 300_100L
        coordinator.setForeground(true)
        assertEquals(1, schedules)
        assertEquals(30_000L, delay)
    }

    private fun activeChannel(
        host: NativeGameWebViewHostOperations,
        dispatchToMain: ((() -> Unit) -> Unit) = { it() },
    ): NativeGameWebViewChannel {
        val channel = NativeGameWebViewChannel()
        val attachment = channel.attachActivity(dispatchToMain)
        channel.attachHost(attachment, host)
        return channel
    }

    private fun generation(value: Int) = mapOf<String, Any?>("generationId" to value)

    private fun hostEvents(sink: NativeGameWebViewEventSink): (String, Long) -> Unit = { type, generation ->
        when (type) {
            "created" -> sink.created(generation)
            "destroyed" -> sink.destroyed(generation)
        }
    }

    private fun assertSuccess(
        channel: NativeGameWebViewChannel,
        method: String,
        arguments: Any?,
        expected: Any?,
    ) {
        val result = RecordingResult()
        channel.onMethodCall(MethodCall(method, arguments), result)
        assertEquals(1, result.completionCount)
        assertEquals(expected, result.successValue)
        assertNull(result.errorCode)
        assertFalse(result.notImplemented)
    }

    private fun assertError(
        channel: NativeGameWebViewChannel,
        method: String,
        arguments: Any?,
        code: String,
    ) {
        val result = RecordingResult()
        channel.onMethodCall(MethodCall(method, arguments), result)
        assertEquals(1, result.completionCount)
        assertEquals(code, result.errorCode)
    }

    private fun startClearSessionAndDetachWithRetainedMarker(
        channel: NativeGameWebViewChannel,
        host: FakeHost,
    ): WeakReference<Any> {
        val marker = Any()
        val attachment = channel.attachActivity(
            dispatchToMain = { it() },
            lifecycleObserver = RetainingLifecycleObserver(marker),
        )
        channel.attachHost(attachment, host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        channel.onMethodCall(MethodCall("clearSession", generation(0)), RecordingResult())
        channel.detachActivity(attachment)
        return WeakReference(marker)
    }

    private fun startClearSessionAndDetachWithRetainingResult(
        channel: NativeGameWebViewChannel,
        host: FakeHost,
    ): WeakReference<Any> {
        val marker = Any()
        val attachment = channel.attachActivity(dispatchToMain = { it() })
        channel.attachHost(attachment, host)
        assertSuccess(channel, "create", mapOf("renderer" to "webgl"), 0L)
        channel.onMethodCall(MethodCall("clearSession", generation(0)), RetainingResult(marker))
        channel.detachActivity(attachment)
        return WeakReference(marker)
    }

    private fun assertEventuallyCollected(reference: WeakReference<*>) {
        repeat(40) {
            if (reference.get() == null) return
            System.gc()
            System.runFinalization()
            Thread.sleep(5)
        }
        assertNull("Detached Activity observer is still retained", reference.get())
    }

    private inline fun <reified T : Throwable> assertThrows(block: () -> Unit) {
        try {
            block()
        } catch (throwable: Throwable) {
            if (throwable is T) return
            throw AssertionError("Expected ${T::class.java.name}, got ${throwable::class.java.name}", throwable)
        }
        throw AssertionError("Expected ${T::class.java.name}")
    }

    private class RecordingResult : MethodChannel.Result {
        var successValue: Any? = null
        var errorCode: String? = null
        var errorMessage: String? = null
        var errorDetails: Any? = null
        var notImplemented = false
        var completionCount = 0

        override fun success(result: Any?) {
            completionCount++
            successValue = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            completionCount++
            this.errorCode = errorCode
            this.errorMessage = errorMessage
            this.errorDetails = errorDetails
        }

        override fun notImplemented() {
            completionCount++
            notImplemented = true
        }
    }

    private class RecordingEventSink(
        private val onSuccess: (Any?) -> Unit = {},
    ) : EventChannel.EventSink {
        val values = mutableListOf<Any?>()
        var endCalls = 0

        override fun success(event: Any?) {
            values += event
            onSuccess(event)
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit

        override fun endOfStream() {
            endCalls++
        }
    }

    private class ThrowingEventSink : EventChannel.EventSink {
        override fun success(event: Any?) {
            throw IllegalStateException("closed")
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit

        override fun endOfStream() = Unit
    }

    private class RecordingLifecycleObserver : NativeGameWebViewLifecycleObserver {
        var createdCalls = 0
        var pageStartedCalls = 0
        var pageFinishedCalls = 0
        var renderProcessGoneCalls = 0

        override fun onCreated() {
            createdCalls++
        }

        override fun onPageStarted() {
            pageStartedCalls++
        }

        override fun onPageFinished() {
            pageFinishedCalls++
        }

        override fun onRenderProcessGone() {
            renderProcessGoneCalls++
        }
    }

    private class RetainingLifecycleObserver(
        @Suppress("unused") private val retained: Any,
    ) : NativeGameWebViewLifecycleObserver

    private class RetainingResult(
        @Suppress("unused") private val retained: Any,
    ) : MethodChannel.Result {
        override fun success(result: Any?) = Unit

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit

        override fun notImplemented() = Unit
    }

    private class FakeOperationTimeoutScheduler : NativeGameWebViewOperationTimeoutScheduler {
        val tasks = mutableListOf<FakeScheduledOperation>()

        override fun schedule(delayMs: Long, operation: () -> Unit): NativeGameWebViewScheduledOperation =
            FakeScheduledOperation(operation).also(tasks::add)

        fun fireNext() {
            tasks.firstOrNull { !it.fired }?.fire()
        }
    }

    private class FakeScheduledOperation(
        private val operation: () -> Unit,
    ) : NativeGameWebViewScheduledOperation {
        var cancelled = false
        var fired = false

        override fun cancel() {
            cancelled = true
        }

        fun fire() {
            fired = true
            if (!cancelled) operation()
        }
    }

    private class FakeHost(
        private val event: (String, Long) -> Unit = { _, _ -> },
    ) : NativeGameWebViewHostOperations {
        override var currentGeneration: Long? = null
            private set
        var createCalls = 0
        var createFailure: RuntimeException? = null
        var reloadCalls = 0
        var loadUriCalls = 0
        var showLocalHomeCalls = 0
        var fitGameScreenCalls = 0
        var localHomeHtml: String? = null
        var fitJavascript: String? = null
        var clearSessionCalls = 0
        var autoCompleteClearSession = true
        private var clearSessionCallback: ((Exception?) -> Unit)? = null
        var bounds: NativeGameWebViewBounds? = null
        var setBoundsResult = true
        var setVisibleResult = true
        val operations = mutableListOf<String>()

        override fun create(): Long? {
            createFailure?.let { throw it }
            val generation = createCalls.toLong()
            createCalls++
            currentGeneration = generation
            operations += "create:$generation"
            event("created", generation)
            return generation
        }

        override fun setBounds(generation: Long, bounds: NativeGameWebViewBounds): Boolean {
            if (generation != currentGeneration) return false
            this.bounds = bounds
            return setBoundsResult
        }

        override fun setVisible(generation: Long, visible: Boolean) =
            generation == currentGeneration && setVisibleResult

        override fun loadUri(uri: String) {
            loadUriCalls++
        }

        override fun showLocalHome(html: String) {
            showLocalHomeCalls++
            localHomeHtml = html
        }

        override fun reload() {
            reloadCalls++
        }

        override fun canGoBack() = true

        override fun goBack() = Unit

        override fun runJavaScript(javascript: String) = Unit

        override fun fitGameScreen(javascript: String) {
            fitGameScreenCalls++
            fitJavascript = javascript
        }

        override fun clearCache() = Unit

        override fun clearSession(onComplete: (Exception?) -> Unit) {
            clearSessionCalls++
            clearSessionCallback = onComplete
            if (autoCompleteClearSession) completeClearSession(null)
        }

        fun completeClearSession(error: Exception?) {
            clearSessionCallback?.invoke(error)
        }

        override fun destroy(generation: Long): Boolean {
            if (generation != currentGeneration) return false
            operations += "destroy:$generation"
            currentGeneration = null
            event("destroyed", generation)
            return true
        }
    }

    private class FakeSnapshotPreferences(
        val values: MutableMap<String, Any?> = mutableMapOf(),
        var commitResult: Boolean = true,
        private val readFailure: Throwable? = null,
        private val commitFailure: Throwable? = null,
    ) : NativeWebViewSnapshotPreferences {
        var readCalls = 0
        var editCalls = 0
        var commitCalls = 0

        override fun readAll(): Map<String, Any?> {
            readCalls++
            readFailure?.let { throw it }
            return values.toMap()
        }

        override fun edit(): NativeWebViewSnapshotEditor {
            editCalls++
            val pending = values.toMutableMap()
            return object : NativeWebViewSnapshotEditor {
                override fun putInt(key: String, value: Int) = apply { pending[key] = value }

                override fun putLong(key: String, value: Long) = apply { pending[key] = value }

                override fun putString(key: String, value: String) = apply { pending[key] = value }

                override fun remove(key: String) = apply { pending.remove(key) }

                override fun commit(): Boolean {
                    commitCalls++
                    commitFailure?.let { throw it }
                    if (commitResult) {
                        values.clear()
                        values.putAll(pending)
                    }
                    return commitResult
                }
            }
        }
    }

    private class CountingStore(
        var snapshot: NativeWebViewStartupSnapshot,
        private val writeResult: NativeWebViewStartupWriteResult = NativeWebViewStartupWriteResult.Durable,
    ) : NativeWebViewStartupStore {
        var reads = 0

        override fun read(): NativeWebViewStartupReadResult {
            reads++
            return NativeWebViewStartupReadResult.Success(snapshot)
        }

        override fun write(nextSnapshot: NativeWebViewStartupSnapshot): NativeWebViewStartupWriteResult {
            if (writeResult == NativeWebViewStartupWriteResult.Durable) snapshot = nextSnapshot
            return writeResult
        }
    }
}
