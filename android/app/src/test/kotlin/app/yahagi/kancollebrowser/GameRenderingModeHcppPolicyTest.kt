package app.yahagi.kancollebrowser

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameRenderingModeHcppPolicyTest {
    @Test
    fun standardAndUnknownModesKeepHcppDisabled() {
        assertFalse(GameRenderingModeHcppPolicy.shouldEnable("standard"))
        assertFalse(GameRenderingModeHcppPolicy.shouldEnable(null))
        assertFalse(GameRenderingModeHcppPolicy.shouldEnable("future-mode"))
    }

    @Test
    fun compatibilityModesEnableHcppBeforeEngineStartup() {
        assertTrue(GameRenderingModeHcppPolicy.shouldEnable("compatibility"))
        assertTrue(GameRenderingModeHcppPolicy.shouldEnable("canvasCompatibility"))
    }
}
