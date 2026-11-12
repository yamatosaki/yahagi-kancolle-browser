import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';

void main() {
  test('saved attacks without a type code retain their original damage', () {
    final legacy = BattleDetailAttack.fromJson({
      'attackType': '鱼雷 Cut-in',
      'defenderHpBefore': 45,
      'defenderHpAfter': 21,
      'hits': [
        {'damage': 24, 'kind': 'hit', 'hpAfter': 21},
      ],
    });

    expect(legacy.attackTypeCode, 'Normal');
    expect(legacy.totalDamage, 24);
    expect(legacy.defenderHpAfter, 21);
  });

  test('battle detail snapshot preserves fleets, equipment and per-hit HP', () {
    const snapshot = BattleDetailSnapshot(
      completedAtMillis: 1788533880000,
      mapLabel: '62-5',
      nodeLabel: 'Z点',
      rank: 'S',
      enemyFleetName: '深海联合舰队',
      fleets: <BattleDetailFleet>[
        BattleDetailFleet(
          side: BattleDetailSide.friend,
          role: BattleDetailFleetRole.main,
          ships: <BattleDetailShip>[
            BattleDetailShip(
              name: '大和改二重',
              side: BattleDetailSide.friend,
              role: BattleDetailFleetRole.main,
              position: 0,
              level: 175,
              initialHp: 98,
              maxHp: 98,
              finalHp: 82,
              damageDealt: 243,
              damageReceived: 16,
              equipment: <BattleDetailEquipment>[
                BattleDetailEquipment(
                  masterId: 467,
                  name: '51cm 连装炮',
                  improvement: 10,
                ),
              ],
            ),
          ],
        ),
        BattleDetailFleet(
          side: BattleDetailSide.friend,
          role: BattleDetailFleetRole.escort,
        ),
        BattleDetailFleet(
          side: BattleDetailSide.enemy,
          role: BattleDetailFleetRole.main,
        ),
        BattleDetailFleet(
          side: BattleDetailSide.enemy,
          role: BattleDetailFleetRole.escort,
        ),
      ],
      stages: <BattleDetailStage>[
        BattleDetailStage(
          keyName: 'api_hougeki1',
          title: '第一炮击战',
          attacks: <BattleDetailAttack>[
            BattleDetailAttack(
              attackerSide: BattleDetailSide.friend,
              attackerRole: BattleDetailFleetRole.main,
              attackerPosition: 0,
              attackerName: '大和改二重',
              defenderSide: BattleDetailSide.enemy,
              defenderRole: BattleDetailFleetRole.main,
              defenderPosition: 0,
              defenderName: '战舰栖姬',
              attackType: '主炮连击',
              defenderHpBefore: 400,
              defenderHpAfter: 157,
              damageControlName: '应急修理女神',
              hits: <BattleDetailHit>[
                BattleDetailHit(
                  damage: 80,
                  kind: BattleDetailHitKind.hit,
                  hpAfter: 320,
                ),
                BattleDetailHit(
                  damage: 120,
                  kind: BattleDetailHitKind.critical,
                  hpAfter: 200,
                ),
                BattleDetailHit(
                  damage: 43,
                  kind: BattleDetailHitKind.critical,
                  hpAfter: 157,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final decoded = BattleDetailSnapshot.fromJson(snapshot.toJson());

    expect(decoded.schemaVersion, 1);
    expect(decoded.fleets, hasLength(4));
    expect(decoded.fleets.first.ships.single.level, 175);
    expect(decoded.fleets.first.ships.single.equipment.single.improvement, 10);
    expect(decoded.stages.single.attacks.single.hits, hasLength(3));
    expect(
      decoded.stages.single.attacks.single.hits[1].kind,
      BattleDetailHitKind.critical,
    );
    expect(decoded.stages.single.attacks.single.hits.last.hpAfter, 157);
    expect(decoded.stages.single.attacks.single.damageControlName, '应急修理女神');
    expect(
      () => decoded.fleets.add(decoded.fleets.first),
      throwsUnsupportedError,
    );
  });
}
