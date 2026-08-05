import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_session.dart';

BattleShipSnapshot _ship(int position) => BattleShipSnapshot(
  masterId: 100 + position,
  name: 'ship-$position',
  side: BattleSide.friend,
  fleetRole: BattleFleetRole.main,
  position: position,
  initialHp: 20,
  maxHp: 20,
  currentHp: 20,
);

void main() {
  test('keeps empty fleet slots instead of compressing positions', () {
    final session = BattleSession(
      id: 'session-1',
      context: const BattleContext(node: 1),
      startedAt: DateTime.utc(2026),
      friendMain: <BattleShipSnapshot>[_ship(0), _ship(2)],
    );

    expect(session.friendMainSlots, hasLength(6));
    expect(session.friendMainSlots[0]?.masterId, 100);
    expect(session.friendMainSlots[1], isNull);
    expect(session.friendMainSlots[2]?.masterId, 102);
  });

  test('diagnostic packets redact credentials and have a fixed capacity', () {
    final session = BattleSession(
      id: 'session-2',
      context: const BattleContext(node: 1),
      startedAt: DateTime.utc(2026),
      maxDiagnosticPackets: 2,
    );

    for (var sequence = 1; sequence <= 3; sequence++) {
      session.appendPacket(
        path: '/kcsapi/test/$sequence',
        sequence: sequence,
        capturedAt: DateTime.utc(2026, 1, sequence),
        data: <String, Object?>{
          'api_token': 'secret',
          'nested': <String, Object?>{
            'cookie': 'private',
            'api_ship_ke': <int>[1, 2],
          },
        },
      );
    }

    expect(session.packets.map((packet) => packet.sequence), <int>[2, 3]);
    expect(session.packets.last.data.toString(), isNot(contains('secret')));
    expect(session.packets.last.data.toString(), isNot(contains('private')));
    expect(session.packets.last.data.toString(), contains('api_ship_ke'));
  });

  test('parse uncertainty is retained with the failing stage', () {
    final session = BattleSession(
      id: 'session-3',
      context: const BattleContext(node: 1),
      startedAt: DateTime.utc(2026),
    );

    session.markUnconfirmed(
      stage: 'api_hougeki2',
      message: 'target 12 is outside the captured fleets',
    );

    expect(session.isConfirmed, isFalse);
    expect(session.issues.single.stage, 'api_hougeki2');
  });
}
