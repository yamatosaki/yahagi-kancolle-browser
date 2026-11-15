package app.yahagi.kancollebrowser.notification

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class NotificationCustomLayoutStyleTest {
    @Test
    fun `custom notification text uses Android notification compatibility styles`() {
        val collapsed = layout("notification_ongoing_collapsed.xml")
        val expanded = layout("notification_ongoing_expanded.xml")

        assertEquals(1, collapsed.countStyle("TextAppearance.Compat.Notification.Title"))
        assertEquals(2, collapsed.countStyle("TextAppearance.Compat.Notification.Info"))
        assertEquals(5, expanded.countStyle("TextAppearance.Compat.Notification.Title"))
        assertEquals(10, expanded.countStyle("TextAppearance.Compat.Notification.Info"))
        assertFalse(collapsed.contains("?android:attr/textColorPrimary"))
        assertFalse(expanded.contains("?android:attr/textColorPrimary"))
    }

    private fun layout(name: String): String {
        val candidates = listOf(
            File("src/main/res/layout/$name"),
            File("android/app/src/main/res/layout/$name"),
        )
        return candidates.firstOrNull(File::isFile)?.readText()
            ?: error("Unable to find $name from ${File(".").absolutePath}")
    }

    private fun String.countStyle(styleName: String): Int =
        Regex("style=\"@style/${Regex.escape(styleName)}\"").findAll(this).count()
}
