package app.yahagi.kancollebrowser.fleet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ShipPortraitRequestPolicyTest {
    @Test
    fun acceptsOnlyPortraitResourceVariantsOnTheGameWorld() {
        for (type in listOf("remodel", "remodel_dmg", "banner", "banner_dmg")) {
            val uri = "https://w00g.kancolle-server.com:443/kcs2/resources/ship/$type/0748_2246.png?version=92"
            assertEquals(uri, ShipPortraitRequestPolicy.parse(uri)?.toString())
        }
        val equipment = "https://w00g.kancolle-server.com/kcs2/resources/slot/item_up/0168_2246.png?version=2"
        assertEquals(equipment, ShipPortraitRequestPolicy.parse(equipment)?.toString())
    }

    @Test
    fun rejectsOtherOriginsAndRequestShapes() {
        val path = "/kcs2/resources/ship/remodel/0748_2246.png"
        val host = "w00g.kancolle-server.com"
        listOf(
            "http://$host$path",
            "https://$host:444$path",
            "https://$host.example$path",
            "https://kancolle-server.com$path",
            "https://user@$host$path",
            "https://$host$path#file",
            "https://$host$path?version=1&name=other",
            "https://$host$path?version=%31",
            "https://$host/kcs2/resources/ship/remodel/../remodel/0748_2246.png",
            "https://$host/kcs2/resources/ship/full/0748_2246_ibcavjzuajrb.png",
            "https://$host/kcs2/resources/slot/other/0168_2246.png",
            "https://$host/kcsapi/api_start2/getData",
        ).forEach { assertNull(it, ShipPortraitRequestPolicy.parse(it)) }
    }
}
