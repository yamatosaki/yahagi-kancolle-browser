package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class FixedCanvasFitRequestsTest {
    @Test
    fun repeatedActiveRequestSharesWorkAndCompletesEveryCaller() {
        val requests = FixedCanvasFitRequests<String>()
        val outcomes = mutableListOf<Boolean>()
        val first = requests.begin("same viewport", { true }) { outcomes += it.getOrThrow() }
        val joined = requests.begin("same viewport", { true }) { outcomes += it.getOrThrow() }

        assertSame(first, joined)
        assertTrue(outcomes.isEmpty())
        requests.finish(first, Result.success(true))
        requests.finish(first, Result.success(false))
        assertEquals(listOf(true, true), outcomes)
    }

    @Test
    fun changedViewportCancelsTheObsoleteRequestOnce() {
        val requests = FixedCanvasFitRequests<String>()
        val outcomes = mutableListOf<Boolean>()
        val first = requests.begin("old bounds", { true }) { outcomes += it.getOrThrow() }
        val latest = requests.begin("new bounds", { true }) { outcomes += it.getOrThrow() }

        assertNotSame(first, latest)
        assertEquals(listOf(false), outcomes)
        requests.finish(first, Result.success(true))
        requests.finish(latest, Result.success(true))
        assertEquals(listOf(false, true), outcomes)
    }

    @Test
    fun completedViewportCanBeFittedAgainForANewDocumentAtTheSameUrl() {
        val requests = FixedCanvasFitRequests<String>()
        val first = requests.begin("same viewport and url", { true }) { }
        requests.finish(first, Result.success(true))
        val nextDocument = requests.begin("same viewport and url", { true }) { }

        assertNotSame(first, nextDocument)
    }

    @Test
    fun invalidatedCallerCannotMakeAJoinedRequestReportAStaleSuccess() {
        val requests = FixedCanvasFitRequests<String>()
        var originalCurrent = true
        val outcomes = mutableListOf<Boolean>()
        val first = requests.begin("same viewport", { originalCurrent }) { outcomes += it.getOrThrow() }
        requests.begin("same viewport", { true }) { outcomes += it.getOrThrow() }
        originalCurrent = false

        assertTrue(requests.isCurrent(first))
        requests.finish(first, Result.success(true))
        assertEquals(listOf(false, true), outcomes)
    }

    @Test
    fun cancelCompletesAllJoinedCallersAndIgnoresLateCallbacks() {
        val requests = FixedCanvasFitRequests<String>()
        val outcomes = mutableListOf<Boolean>()
        val first = requests.begin("same viewport", { true }) { outcomes += it.getOrThrow() }
        requests.begin("same viewport", { true }) { outcomes += it.getOrThrow() }

        requests.cancel()
        requests.finish(first, Result.success(true))
        assertEquals(listOf(false, false), outcomes)
    }

    @Test
    fun failingFirstCompletionDoesNotDropJoinedCompletion() {
        val requests = FixedCanvasFitRequests<String>()
        val outcomes = mutableListOf<Boolean>()
        val first = requests.begin("same viewport", { true }) {
            outcomes += it.getOrThrow()
            throw IllegalStateException("Caller failed")
        }
        requests.begin("same viewport", { true }) { outcomes += it.getOrThrow() }

        assertNull(runCatching { requests.finish(first, Result.success(true)) }.exceptionOrNull())
        assertEquals(listOf(true, true), outcomes)
    }

    @Test
    fun failingFirstCancellationDoesNotPreventReplacingTheRequest() {
        val requests = FixedCanvasFitRequests<String>()
        val outcomes = mutableListOf<Boolean>()
        requests.begin("old viewport", { true }) { throw IllegalStateException("Caller failed") }
        requests.begin("old viewport", { true }) { outcomes += it.getOrThrow() }

        val replacement = runCatching {
            requests.begin("new viewport", { true }) { outcomes += it.getOrThrow() }
        }
        assertNull(replacement.exceptionOrNull())
        requests.finish(replacement.getOrThrow(), Result.success(true))
        assertEquals(listOf(false, true), outcomes)
    }

    @Test
    fun failingValidityCheckDoesNotHideAnotherCurrentCaller() {
        val requests = FixedCanvasFitRequests<String>()
        var failCheck = false
        val first = requests.begin("same viewport", {
            if (failCheck) throw IllegalStateException("Validity check failed")
            true
        }) { }
        requests.begin("same viewport", { true }) { }
        failCheck = true

        assertEquals(true, runCatching { requests.isCurrent(first) }.getOrNull())
    }

    @Test
    fun failingValidityCheckIsReportedToItsCallerAndOtherCallersStillComplete() {
        val requests = FixedCanvasFitRequests<String>()
        var failCheck = false
        var firstOutcome: Result<Boolean>? = null
        var joinedOutcome: Result<Boolean>? = null
        val first = requests.begin("same viewport", {
            if (failCheck) throw IllegalStateException("Validity check failed")
            true
        }) { firstOutcome = it }
        requests.begin("same viewport", { true }) { joinedOutcome = it }
        failCheck = true

        assertNull(runCatching { requests.finish(first, Result.success(true)) }.exceptionOrNull())
        assertTrue(firstOutcome!!.exceptionOrNull() is IllegalStateException)
        assertEquals(true, joinedOutcome!!.getOrThrow())
    }

    @Test
    fun failingCleanupDoesNotDropCallersOrPreventAFutureFit() {
        val requests = FixedCanvasFitRequests<String>()
        val outcomes = mutableListOf<Boolean>()
        val first = requests.begin("same viewport", { true }) { outcomes += it.getOrThrow() }
        requests.begin("same viewport", { true }) { outcomes += it.getOrThrow() }
        first.onFinish = { throw IllegalStateException("Cleanup failed") }

        assertNull(runCatching { requests.finish(first, Result.success(true)) }.exceptionOrNull())
        val next = requests.begin("same viewport", { true }) { outcomes += it.getOrThrow() }
        requests.finish(next, Result.success(true))
        assertEquals(listOf(true, true, true), outcomes)
    }
}
