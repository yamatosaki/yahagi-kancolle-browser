package app.yahagi.kancollebrowser.mods

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import app.yahagi.kancollebrowser.browser.GameModPagePresence
import app.yahagi.kancollebrowser.browser.PreparedGameFrameReloadBridgePort
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

/** Exercises real coroutine/channel handling using isolated files and preferences. */
@RunWith(AndroidJUnit4::class)
class GameModManagerStatusTest {
    @Test fun repeatedStatusReadsDoNotInvalidateNativeLayoutButMutationsStillNotify() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val app = instrumentation.targetContext
        val prefix = "mod-manager-status-${UUID.randomUUID()}"
        val root = File(app.cacheDir, prefix).apply { check(mkdir()) }
        val isolated = object : ContextWrapper(app) {
            override fun getApplicationContext(): Context = this
            override fun getFilesDir() = File(root, "files").apply { mkdirs() }
            override fun getCacheDir() = File(root, "cache").apply { mkdirs() }
            override fun getSharedPreferences(name: String, mode: Int) = app.getSharedPreferences("$prefix-$name", mode)
        }
        val changes = AtomicInteger()
        val initialized = CountDownLatch(1)
        var manager: GameModManager? = null
        try {
            instrumentation.runOnMainSync {
                val activity = object : Activity() {
                    override fun getApplicationContext(): Context = isolated
                }
                manager = GameModManager(activity, object : PreparedGameFrameReloadBridgePort {
                    override fun isSupported() = true
                    override fun configure() = Unit
                    override fun dispose() = Unit
                    override fun clearMemoryCache() = Unit
                    override fun reload(onComplete: (String) -> Unit) = error("Unexpected reload")
                    override fun gamePagePresence() = GameModPagePresence.ABSENT
                    override fun reloadPrepared(beforeDispatch: () -> Unit, onComplete: (String, Boolean) -> Unit) = error("Unexpected reload")
                }) {
                    changes.incrementAndGet()
                    initialized.countDown()
                }
            }
            assertTrue("Isolated native manager did not initialize", initialized.await(10, TimeUnit.SECONDS))
            val initial = changes.get()
            repeat(30) {
                val status = call(checkNotNull(manager), "status") as Map<*, *>
                assertEquals(true, status["supported"])
                assertTrue((status["packages"] as List<*>).isEmpty())
                assertEquals(false, (status["library"] as Map<*, *>)["configured"])
                call(checkNotNull(manager), "portraitSnapshot")
            }
            assertEquals("Read-only polling must not repeatedly trigger native layout work", initial, changes.get())
            call(checkNotNull(manager), "cancelChanges")
            assertEquals("A real configuration operation still invalidates native layout", initial + 1, changes.get())
        } finally {
            instrumentation.runOnMainSync { manager?.dispose() }
            app.getSharedPreferences("$prefix-game_mod_library", Context.MODE_PRIVATE).edit().clear().commit()
            app.deleteSharedPreferences("$prefix-game_mod_library")
            assertTrue(root.canonicalPath.startsWith(app.cacheDir.canonicalPath + File.separator))
            assertTrue(root.deleteRecursively())
        }
    }

    private fun call(manager: GameModManager, method: String): Any? {
        val finished = CountDownLatch(1)
        var value: Any? = null
        var failure: String? = null
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            manager.onMethodCall(MethodCall(method, null), object : MethodChannel.Result {
                override fun success(result: Any?) { value = result; finished.countDown() }
                override fun error(code: String, message: String?, details: Any?) { failure = "$code: $message"; finished.countDown() }
                override fun notImplemented() { failure = "Not implemented: $method"; finished.countDown() }
            })
        }
        assertTrue("Native $method did not complete", finished.await(10, TimeUnit.SECONDS))
        assertNull(failure)
        return value
    }
}
