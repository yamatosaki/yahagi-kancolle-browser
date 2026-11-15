package app.yahagi.kancollebrowser.browser

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class KanxyGameRouteStateTest {
    @Test fun `initial VPN readiness can reach a surviving page and duplicates are ignored`() {
        for (active in listOf(false, true)) {
            val state = KanxyGameRouteState()
            state.observe(active)
            val initial = state.beginReconcile()!!
            val expected = if (active) KanxyGameRouteState.Change(true, initial, renewed = true) else null
            assertEquals(expected, state.finishReconcile(initial, true))
            state.observe(active)
            assertNull(state.beginReconcile())
        }
    }

    @Test fun `real switches wait for proxy settlement and can retry after failure`() {
        val state = KanxyGameRouteState()
        state.observe(false)
        state.finishReconcile(state.beginReconcile()!!, true)
        state.observe(true)
        val enable = state.beginReconcile()!!
        assertFalse(state.canReload(enable.generation))
        assertNull(state.beginReconcile())
        assertNull(state.finishReconcile(enable, false))
        assertEquals(enable, state.beginReconcile())
        assertEquals(KanxyGameRouteState.Change(false, enable), state.finishReconcile(enable, true))
        assertTrue(state.canReload(enable.generation))

        state.observe(false)
        assertFalse(state.canReload(enable.generation))
        val disable = state.beginReconcile()!!
        assertEquals(KanxyGameRouteState.Change(true, disable), state.finishReconcile(disable, true))
        assertTrue(state.canReload(disable.generation))
    }

    @Test fun `obsolete callbacks cannot reload and a VPN returning after loss gets a new generation`() {
        val state = KanxyGameRouteState()
        state.observe(false)
        state.finishReconcile(state.beginReconcile()!!, true)
        state.observe(true)
        val enable = state.beginReconcile()!!
        state.finishReconcile(enable, true)

        state.observe(false)
        val stale = state.beginReconcile()!!
        state.observe(true)
        val latest = state.beginReconcile()!!
        assertNull(state.finishReconcile(stale, true))
        assertFalse(state.canReload(enable.generation))
        assertEquals(KanxyGameRouteState.Change(true, latest, renewed = true), state.finishReconcile(latest, true))
        assertFalse(state.canReload(enable.generation))
        assertTrue(state.canReload(latest.generation))
    }

    @Test fun `a replacement Android VPN network renews readiness without a confirmed loss`() {
        val state = KanxyGameRouteState()
        state.observe(true)
        val first = state.beginReconcile()!!
        state.finishReconcile(first, true)

        state.observe(true, renewActive = true)
        val replacement = state.beginReconcile()!!
        assertFalse(state.canReload(first.generation))
        assertEquals(
            KanxyGameRouteState.Change(true, replacement, renewed = true),
            state.finishReconcile(replacement, true),
        )
        assertTrue(state.canReload(replacement.generation))
    }

    @Test fun `HTTP only permits a current recovery ticket while that proxy is selected`() {
        val state = KanxyGameRouteState()
        state.observe(false)
        state.finishReconcile(state.beginReconcile()!!, true)

        val first = state.observeHttp(true).route
        assertTrue(state.canReload(first.generation, httpSelected = true))
        assertFalse(state.canReload(first.generation))

        val stopped = state.observeHttp(false).route
        assertFalse(state.canReload(first.generation, httpSelected = true))
        assertFalse(state.canReload(stopped.generation, httpSelected = true))
        val recovered = state.observeHttp(true).route
        assertTrue(state.canReload(recovered.generation, httpSelected = true))
        assertFalse(state.canReload(first.generation, httpSelected = true))

        state.observe(true)
        val vpn = state.beginReconcile()!!
        state.finishReconcile(vpn, true)
        assertTrue(state.canReload(vpn.generation))
        assertFalse(state.canReload(vpn.generation, httpSelected = true))
    }

    @Test fun `rapid VPN takeover invalidates HTTP reload before HTTP is reverified`() {
        val state = KanxyGameRouteState()
        state.observe(false)
        state.finishReconcile(state.beginReconcile()!!, true)
        val firstHttp = state.observeHttp(true).route
        assertTrue(state.canReload(firstHttp.generation, httpSelected = true))

        state.observe(true)
        val pendingVpn = state.beginReconcile()!!
        state.observe(false)
        assertNull(state.finishReconcile(pendingVpn, true))
        state.finishReconcile(state.beginReconcile()!!, true)

        assertFalse(state.canReload(firstHttp.generation, httpSelected = true))
        val restoredHttp = state.observeHttp(true).route
        assertTrue(state.canReload(restoredHttp.generation, httpSelected = true))
        assertFalse(state.canReload(firstHttp.generation, httpSelected = true))
    }
}
