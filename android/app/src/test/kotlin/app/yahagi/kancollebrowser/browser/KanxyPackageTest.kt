package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KanxyPackageTest {
    @Test
    fun acceptsEitherEnabledKanxyPackage() {
        assertTrue(hasEnabledKanxyPackage { it == "com.axis000.kanxy" })
        assertTrue(hasEnabledKanxyPackage { it == "com.kanxy.android" })
    }

    @Test
    fun rejectsDisabledOrUnrelatedPackages() {
        assertFalse(hasEnabledKanxyPackage { false })
        assertFalse(hasEnabledKanxyPackage { it == "com.axis000.kanxy.other" || it == "com.other.vpn" })
    }
}
