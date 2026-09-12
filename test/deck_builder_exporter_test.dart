import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/deck_builder_exporter.dart';

void main() {
  group('DeckBuilderExporter', () {
    test('exports the v4 header and a minimal fleet', () {
      const state = GameState(
        admiralLevel: 120,
        ships: <int, OwnedShip>{
          101: OwnedShip(id: 101, masterId: 187, level: 70, luck: 12),
        },
        fleets: <Fleet>[
          Fleet(id: 1, name: 'First', shipIds: <int>[101]),
        ],
      );

      final result = const DeckBuilderExporter().exportMap(state);

      expect(result['version'], 4);
      expect(result['hqlv'], 120);
      expect(result['f1'], <String, Object?>{
        'name': 'First',
        's1': <String, Object?>{
          'id': 187,
          'lv': 70,
          'luck': 12,
          'exa': true,
          'items': <String, Object?>{},
        },
      });
      expect(jsonDecode(const DeckBuilderExporter().exportJson(state)), result);
    });

    test('preserves fleet positions and marks a combined fleet', () {
      const state = GameState(
        combinedFleetType: CombinedFleetType.surfaceTaskForce,
        ships: <int, OwnedShip>{
          202: OwnedShip(id: 202, masterId: 200, level: 80),
          301: OwnedShip(id: 301, masterId: 300, level: 90),
        },
        fleets: <Fleet>[
          Fleet(id: 1, name: 'First', shipIds: <int>[999, 202]),
          Fleet(id: 2, name: 'Second', shipIds: <int>[301]),
        ],
      );

      final result = const DeckBuilderExporter().exportMap(state);

      expect((result['f1'] as Map<String, Object?>)['t'], 2);
      expect((result['f1'] as Map<String, Object?>).containsKey('s1'), isFalse);
      expect(((result['f1'] as Map<String, Object?>)['s2'] as Map)['id'], 200);
      expect(((result['f2'] as Map<String, Object?>)['s1'] as Map)['id'], 300);
    });

    test('exports equipment in its original slot and extra slot', () {
      const state = GameState(
        ships: <int, OwnedShip>{
          101: OwnedShip(
            id: 101,
            masterId: 187,
            level: 70,
            slotIds: <int>[501, -1, 503, 999],
            extraSlotId: 504,
          ),
        },
        slotItems: <int, OwnedSlotItem>{
          501: OwnedSlotItem(instanceId: 501, masterSlotItemId: 86),
          503: OwnedSlotItem(
            instanceId: 503,
            masterSlotItemId: 90,
            level: 6,
            proficiency: 7,
          ),
          504: OwnedSlotItem(instanceId: 504, masterSlotItemId: 42, level: 1),
        },
        fleets: <Fleet>[
          Fleet(id: 1, name: 'First', shipIds: <int>[101]),
        ],
      );

      final result = const DeckBuilderExporter().exportMap(state);
      final ship = (result['f1'] as Map<String, Object?>)['s1'] as Map;
      final items = ship['items'] as Map;

      expect(items['i1'], <String, Object?>{'id': 86, 'rf': 0});
      expect(items.containsKey('i2'), isFalse);
      expect(items['i3'], <String, Object?>{'id': 90, 'rf': 6, 'mas': 7});
      expect(items.containsKey('i4'), isFalse);
      expect(items['ix'], <String, Object?>{'id': 42, 'rf': 1});
    });

    test('filters event land bases by default and renumbers them', () {
      const state = GameState(
        slotItems: <int, OwnedSlotItem>{
          601: OwnedSlotItem(
            instanceId: 601,
            masterSlotItemId: 364,
            proficiency: 3,
          ),
          602: OwnedSlotItem(instanceId: 602, masterSlotItemId: 286),
        },
        landBases: <LandBaseState>[
          LandBaseState(
            areaId: 6,
            baseId: 1,
            name: 'Normal',
            actionKind: 1,
            squadrons: <LandBaseSquadronState>[
              LandBaseSquadronState(squadronId: 1, slotItemId: 602),
            ],
          ),
          LandBaseState(
            areaId: 47,
            baseId: 2,
            name: 'Event A',
            actionKind: 2,
            squadrons: <LandBaseSquadronState>[
              LandBaseSquadronState(squadronId: 1),
              LandBaseSquadronState(squadronId: 2, slotItemId: 601),
            ],
          ),
          LandBaseState(
            areaId: 48,
            baseId: 1,
            name: 'Event B',
            actionKind: 0,
            squadrons: <LandBaseSquadronState>[
              LandBaseSquadronState(squadronId: 1, slotItemId: 999),
              LandBaseSquadronState(squadronId: 2, slotItemId: 602),
            ],
          ),
          LandBaseState(areaId: 49, baseId: 1, name: 'Event C', actionKind: 1),
        ],
      );

      final eventOnly = const DeckBuilderExporter().exportMap(state);

      expect((eventOnly['a3'] as Map)['mode'], 1);
      expect(eventOnly.containsKey('a4'), isFalse);
      expect(eventOnly['a1'], <String, Object?>{
        'name': 'Event A',
        'mode': 2,
        'items': <String, Object?>{
          'i2': <String, Object?>{'id': 364, 'rf': 0, 'mas': 3},
        },
      });
      expect(eventOnly['a2'], <String, Object?>{
        'name': 'Event B',
        'mode': 0,
        'items': <String, Object?>{
          'i2': <String, Object?>{'id': 286, 'rf': 0},
        },
      });

      final all = const DeckBuilderExporter().exportMap(
        state,
        eventLandBasesOnly: false,
      );
      expect((all['a1'] as Map)['mode'], 1);
      expect((all['a2'] as Map)['mode'], 2);
      expect((all['a3'] as Map)['mode'], 0);
      expect(all.containsKey('a4'), isFalse);
    });
  });
}
