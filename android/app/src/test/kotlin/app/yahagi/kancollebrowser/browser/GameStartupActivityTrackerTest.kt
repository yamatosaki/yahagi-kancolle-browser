package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GameStartupActivityTrackerTest {
    @Test
    fun disabledSettingPreventsPageAndFrameTrackingEvenBeforeListenerRefresh() {
        var enabled = true
        val tracker = GameStartupActivityTracker(GameStartupActivityTracker.Setting { enabled })
        tracker.pageStarted("https", "play.games.dmm.com")
        val previous = requireNotNull(tracker.snapshot())

        enabled = false
        tracker.pageStarted("https", "play.games.dmm.com")
        tracker.startFrameReload()
        tracker.recordRequest("https", "w01y.kancolle-server.com", -1, null, "/kcsapi/api_start2/getData", "POST")
        assertFalse(tracker.hasPendingNavigation)
        assertNull(tracker.snapshot())

        enabled = true
        assertNull(tracker.snapshot())
        tracker.startFrameReload()
        val fresh = requireNotNull(tracker.snapshot())
        assertTrue(fresh.navigationId > previous.navigationId)
        assertEquals(0, fresh.requestCount)
        assertFalse(fresh.gameApi)
    }

    @Test
    fun preferenceListenerInvalidatesSnapshotsAcrossEveryWebViewBeforeReenable() {
        var enabled = true
        val setting = GameStartupActivityTracker.Setting { enabled }
        val current = GameStartupActivityTracker(setting)
        val detached = GameStartupActivityTracker(setting)
        current.pageStarted("https", "play.games.dmm.com")
        detached.pageStarted("https", "ooi.moe")
        detached.recordRequest("https", "w01y.kancolle-server.com", -1, null, "/kcsapi/api_start2/getData", "POST")
        val previous = requireNotNull(detached.snapshot())
        assertTrue(previous.gameApi)

        enabled = false
        setting.refresh()
        assertFalse(current.hasPendingNavigation)
        current.recordRequest("https", "w01y.kancolle-server.com", -1, null, "/kcs2/js/main.js", "GET")
        assertNull(current.snapshot())
        assertNull(detached.snapshot())

        enabled = true
        setting.refresh()
        assertNull(current.snapshot())
        assertNull(detached.snapshot())
        current.pageStarted("https", "play.games.dmm.com")
        assertTrue(requireNotNull(current.snapshot()).navigationId > previous.navigationId)
        assertNull(detached.snapshot())
    }

    @Test
    fun tracksOfficialResourcesAndStopsCountingAtTheFirstGameApiRequest() {
        val tracker = GameStartupActivityTracker()
        assertNull(tracker.snapshot())
        tracker.pageStarted("https", "play.games.dmm.com")
        val initial = requireNotNull(tracker.snapshot())
        assertEquals(0, initial.requestCount)

        tracker.recordRequest("https", "w01y.kancolle-server.com", -1, null, "/kcs2/js/main.js", "GET")
        val resources = requireNotNull(tracker.snapshot())
        assertEquals(initial.navigationId, resources.navigationId)
        assertEquals(1, resources.requestCount)
        assertTrue(resources.gameResources)
        assertFalse(resources.gameApi)

        tracker.recordRequest("https", "w01y.kancolle-server.com", 443, null, "/kcsapi/api_start2/getData", "POST")
        val game = requireNotNull(tracker.snapshot())
        assertEquals(2, game.requestCount)
        assertTrue(game.gameApi)
        assertFalse(tracker.hasPendingNavigation)
        tracker.recordRequest("https", "w01y.kancolle-server.com", -1, null, "/kcs2/img/other.png", "GET")
        assertEquals(game, tracker.snapshot())
        assertEquals(setOf("navigationId", "requestCount", "gameResources", "gameApi"), game.toMap().keys)
    }

    @Test
    fun unrelatedRequestsAndPreflightCannotFinishGameStartup() {
        val tracker = GameStartupActivityTracker()
        tracker.pageStarted("https", "play.games.dmm.com")
        tracker.recordRequest("https", "osapi.dmm.com", -1, null, "/kcsapi/api_start2/getData", "POST")
        tracker.recordRequest("https", "w01y.kancolle-server.com.example", -1, null, "/kcs2/js/main.js", "GET")
        tracker.recordRequest("https", "w01y.kancolle-server.com", -1, null, "/kcsapi/api_start2/getData", "OPTIONS")
        tracker.recordRequest("https", "w01y.kancolle-server.com", 444, null, "/kcsapi/api_start2/getData", "POST")
        tracker.recordRequest("https", "w01y.kancolle-server.com", -1, "secret", "/kcsapi/api_start2/getData", "POST")
        tracker.recordRequest("https", "w01y.kancolle-server.com", -1, null, "/proxy/kcsapi/api_start2/getData", "POST")
        tracker.recordRequest("file", null, -1, null, "/kcs2/js/main.js", "GET")

        val current = requireNotNull(tracker.snapshot())
        assertEquals(6, current.requestCount)
        assertFalse(current.gameResources)
        assertFalse(current.gameApi)
        assertTrue(tracker.hasPendingNavigation)
    }

    @Test
    fun resetsPerNavigationOrInPlaceFrameReloadWithoutCarryingReadyStateToAnotherView() {
        val firstView = GameStartupActivityTracker()
        val secondView = GameStartupActivityTracker()
        firstView.pageStarted("https", "play.games.dmm.com")
        firstView.recordRequest("https", "w01y.kancolle-server.com", -1, null, "/kcsapi/api_start2/getData", "POST")
        val previous = requireNotNull(firstView.snapshot())
        secondView.pageStarted("https", "ooi.moe")
        val other = requireNotNull(secondView.snapshot())
        firstView.startFrameReload()
        val reloaded = requireNotNull(firstView.snapshot())

        assertTrue(reloaded.navigationId > other.navigationId)
        assertTrue(other.navigationId > previous.navigationId)
        assertEquals(0, reloaded.requestCount)
        assertFalse(reloaded.gameResources)
        assertFalse(reloaded.gameApi)
        assertEquals(other, secondView.snapshot())

        firstView.pageStarted("about", null)
        assertNull(firstView.snapshot())
        firstView.recordRequest("https", "w01y.kancolle-server.com", -1, null, "/kcsapi/api_start2/getData", "POST")
        assertNull(firstView.snapshot())
        firstView.pageStarted("https", "play.games.dmm.com")
        assertTrue(requireNotNull(firstView.snapshot()).navigationId > reloaded.navigationId)
    }
}
