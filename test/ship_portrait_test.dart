import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  group('ShipPortraitUriBuilder', () {
    test('matches the game remodel-art cipher used by Yahagi avatars', () {
      const ship = MasterShip(
        id: 163,
        name: 'まるゆ',
        shipTypeId: 22,
        portraitVersion: '7',
      );

      final uri = ShipPortraitUriBuilder.build(
        ship: ship,
        serverOrigin: 'https://203.104.209.71',
      );

      expect(
        uri.toString(),
        'https://203.104.209.71/kcs2/resources/ship/remodel/0163_6320.png?version=7',
      );
    });

    test('rejects non-http origins and missing versions', () {
      const ship = MasterShip(id: 101, name: '测试舰', shipTypeId: 2);

      expect(
        ShipPortraitUriBuilder.build(
          ship: ship,
          serverOrigin: 'file:///data/game',
        ),
        isNull,
      );
      expect(
        ShipPortraitUriBuilder.build(
          ship: ship,
          serverOrigin: 'https://example.com',
        ),
        isNull,
      );
    });
  });
}
