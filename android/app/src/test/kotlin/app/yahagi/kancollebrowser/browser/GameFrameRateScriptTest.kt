package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameFrameRateScriptTest {
    @Test
    fun mapsWireModesAndFallsBackToAuto() {
        assertEquals(GameFrameRateMode.AUTO, GameFrameRateMode.fromWireName("auto"))
        assertEquals(GameFrameRateMode.STABLE_30, GameFrameRateMode.fromWireName("stable30"))
        assertEquals(GameFrameRateMode.PREFER_60, GameFrameRateMode.fromWireName("prefer60"))
        assertEquals(GameFrameRateMode.AUTO, GameFrameRateMode.fromWireName("future-mode"))
    }

    @Test
    fun onlyAutoAndPrefer60PatchTheRemoteMainScript() {
        assertTrue(GameFrameRateMode.AUTO.patchesMainScript)
        assertFalse(GameFrameRateMode.STABLE_30.patchesMainScript)
        assertTrue(GameFrameRateMode.PREFER_60.patchesMainScript)
    }

    @Test
    fun recognizesOnlyKancolleMainScripts() {
        assertTrue(
            GameMainScriptPatcher.isMainScriptUrl(
                "https://w00g.kancolle-server.com/kcs2/js/main.js?version=1",
            ),
        )
        assertFalse(
            GameMainScriptPatcher.isMainScriptUrl(
                "https://w00g.kancolle-server.com/kcs2/js/vendor.js",
            ),
        )
        assertFalse(
            GameMainScriptPatcher.isMainScriptUrl(
                "https://w00g.kancolle-server.com.evil.example/kcs2/js/main.js",
            ),
        )
    }

    @Test
    fun patchesCreateJsTickerToUnthrottledRafLikeGotoBrowser() {
        val original = "createjs.Ticker.timingMode=createjs.Ticker.TIMEOUT,b=1;"
        assertEquals(
            "createjs.Ticker.timingMode=createjs.Ticker.RAF,b=1;",
            GameMainScriptPatcher.patch(original),
        )
    }

    @Test
    fun unmatchedScriptIsReturnedUnchanged() {
        val original = "console.log('main');"
        assertEquals(original, GameMainScriptPatcher.patch(original))
    }
}
