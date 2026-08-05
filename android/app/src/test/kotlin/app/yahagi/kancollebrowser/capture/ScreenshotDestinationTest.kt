package app.yahagi.kancollebrowser.capture

import org.junit.Assert.assertEquals
import org.junit.Test

class ScreenshotDestinationTest {
    @Test
    fun createsAGalleryFriendlyNameAndPicturesLocation() {
        val destination = ScreenshotDestination.create("20260806-013045-123")

        assertEquals("yahagi-game-20260806-013045-123.png", destination.fileName)
        assertEquals("Pictures/Yahagi", destination.relativeDirectory)
        assertEquals(
            "Pictures/Yahagi/yahagi-game-20260806-013045-123.png",
            destination.displayLocation,
        )
    }
}
