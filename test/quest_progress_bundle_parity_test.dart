import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final goals =
      (jsonDecode(
                File(
                  'assets/data/quest-progress-goals.json',
                ).readAsStringSync(),
              )
              as Map)
          .cast<String, dynamic>();

  test('bundled Poi rules include all 432 quests and 962 subgoals', () {
    expect(goals, hasLength(432));
    expect(
      goals.values.fold<int>(
        0,
        (count, goal) => count + (goal as Map).values.whereType<Map>().length,
      ),
      962,
    );
  });

  test('all 25 former name rules use master IDs without name fallbacks', () {
    const migrated = [
      249,
      337,
      339,
      345,
      346,
      354,
      355,
      356,
      357,
      362,
      368,
      371,
      373,
      375,
      377,
      875,
      888,
      903,
      904,
      912,
      928,
      975,
      977,
      1018,
      1045,
    ];
    const names = {'flagship', 'secondship', 'escortship', 'shipNamesAll'};
    for (final entry in goals.entries) {
      for (final step in (entry.value as Map).values.whereType<Map>()) {
        expect(
          step.keys.toSet().intersection(names),
          isEmpty,
          reason: 'quest ${entry.key}',
        );
      }
    }
    for (final id in migrated) {
      final goal = goals['$id'] as Map;
      expect(goal['revision'], greaterThanOrEqualTo(1), reason: '$id');
      expect(
        goal.values.whereType<Map>().every(
          (step) => step.keys.any(
            (key) => {
              'flagshipId',
              'secondshipId',
              'escortshipId',
              'escortshipIdAll',
            }.contains(key),
          ),
        ),
        isTrue,
        reason: '$id',
      );
    }
  });

  test('local conservative completion and companion requirements survive', () {
    expect((goals['318'] as Map)['fuzzy'], isTrue);
    final cruiserGroups =
        (goals['372'] as Map)['practice_win_a']['escortshiptype'] as List;
    expect(cruiserGroups, [
      [
        [10],
        2,
        true,
      ],
      [
        [2],
        2,
        true,
      ],
    ]);
    final french = (goals['373'] as Map)['practice_win_a'] as Map;
    expect((french['escortshipIdAll'] as List).single[2], isTrue);
    final yamato = goals['977'] as Map;
    expect(yamato['revision'], greaterThanOrEqualTo(2));
    for (final step in yamato.values.whereType<Map>()) {
      expect(step['escortshipIdAll'], [
        [
          [911],
          1,
        ],
        [
          [546],
          1,
        ],
      ]);
      expect(step['escortshiptype'], [
        [
          [2],
          2,
        ],
      ]);
      if ((step['maparea'] as List).contains(72)) {
        expect(step['mapcell'], [15]);
      }
    }
  });

  test(
    'all imported values match the reviewed Poi snapshot except local policy',
    () {
      final upstream = (jsonDecode(jsonEncode(goals)) as Map)
          .cast<String, dynamic>();
      for (final goal in upstream.values) {
        (goal as Map).remove('revision');
      }
      (upstream['318'] as Map).remove('fuzzy');
      final aviation = (upstream['372'] as Map)['practice_win_a'] as Map;
      for (final group in aviation['escortshiptype'] as List) {
        (group as List).removeLast();
      }
      ((upstream['373'] as Map)['practice_win_a'] as Map).remove(
        'escortshipIdAll',
      );
      // Canonical JSON of all 432 upstream IDs and all 962 steps, reviewed at
      // 725029997b84729df6394e1f107079b8e9437f36. This checks every source field.
      expect(
        sha256.convert(utf8.encode(jsonEncode(upstream))).toString(),
        'eef9c8b39d5ca585a8dd75263cc85d2a5001567c99d7ce54321e5e85383dcd96',
      );
    },
  );
}
