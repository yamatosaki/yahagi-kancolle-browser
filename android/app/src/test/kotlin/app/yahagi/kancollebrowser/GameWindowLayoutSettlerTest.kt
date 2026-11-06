package app.yahagi.kancollebrowser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameWindowLayoutSettlerTest {
    @Test fun revertingToPublishedGeometryStillReleasesThePendingStabilityGate() {
        val settler = GameWindowLayoutSettler<String>()
        assertTrue(settler.observe("A", 0).changing)
        assertTrue(settler.observe("A", 200).stable)
        assertTrue(settler.observe("B", 300).changing)
        assertTrue(settler.observe("A", 500).changing)
        assertFalse(settler.observe("A", 699).stable)
        assertTrue(settler.observe("A", 700).stable)
        assertEquals(GameWindowLayoutSettler.Decision(), settler.observe("A", 900))
    }

    @Test fun repeatedIdenticalCallbacksDoNotPostponeTheQuietDeadline() {
        val settler = GameWindowLayoutSettler<String>()
        settler.observe("A", 0)
        assertEquals(150L, settler.observe("A", 50).retryAfterMillis)
        assertEquals(1L, settler.observe("A", 199).retryAfterMillis)
        assertTrue(settler.observe("A", 200).stable)
    }
}
