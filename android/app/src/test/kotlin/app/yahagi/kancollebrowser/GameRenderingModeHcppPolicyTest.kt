package app.yahagi.kancollebrowser

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameRenderingModeHcppPolicyTest {
    @Test
    fun onlyExplicitHighPerformanceModeKeepsHcppDisabled() {
        assertFalse(GameRenderingModeHcppPolicy.shouldEnable("standard"))
    }

    @Test
    fun compatibilityModesEnableHcppBeforeEngineStartup() {
        assertTrue(GameRenderingModeHcppPolicy.shouldEnable("compatibility"))
        assertTrue(GameRenderingModeHcppPolicy.shouldEnable("canvasCompatibility"))
        assertTrue(GameRenderingModeHcppPolicy.shouldEnable(null))
        assertTrue(GameRenderingModeHcppPolicy.shouldEnable("future-mode"))
    }
}
