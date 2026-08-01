import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';

void main() {
  group('parseEnemyFleetName', () {
    test('reads the optional fleet name at index 3', () {
      expect(parseEnemyFleetName(<Object?>[1, 1, 1, '敵艦隊']), '敵艦隊');
    });

    test('returns empty when absent or too short', () {
      expect(parseEnemyFleetName(<Object?>[1, 1, 1]), '');
      expect(parseEnemyFleetName(null), '');
      expect(parseEnemyFleetName('not a list'), '');
      expect(parseEnemyFleetName(<Object?>[1, 1, 1, 3]), '');
    });
  });

  group('parseDispSeiku', () {
    test('reads api_disp_seiku from api_kouku stage1', () {
      expect(
        parseDispSeiku(<String, Object?>{
          'api_kouku': <String, Object?>{
            'api_stage1': <String, Object?>{'api_disp_seiku': 2},
          },
        }),
        2,
      );
    });

    test('returns -1 when absent', () {
      expect(parseDispSeiku(<String, Object?>{}), -1);
      expect(
        parseDispSeiku(<String, Object?>{
          'api_kouku': <String, Object?>{
            'api_stage1': <String, Object?>{'api_other': 1},
          },
        }),
        -1,
      );
    });
  });

  group('kAirSuperiorityLabels', () {
    test('covers all known values', () {
      expect(kAirSuperiorityLabels[-1], '未知');
      expect(kAirSuperiorityLabels[0], '均衡');
      expect(kAirSuperiorityLabels[1], '确保');
      expect(kAirSuperiorityLabels[2], '优势');
      expect(kAirSuperiorityLabels[3], '劣势');
      expect(kAirSuperiorityLabels[4], '丧失');
    });
  });
}
