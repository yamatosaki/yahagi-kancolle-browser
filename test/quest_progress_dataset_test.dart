import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_progress_dataset.dart';

Map<String, dynamic> _goal({int required = 3}) => {
  'practice_win_a': {'description': 'A', 'required': required, 'init': 0},
};

String _payload({
  String version = '2026/10/25/01',
  Map<String, dynamic>? data,
}) => jsonEncode({
  'meta': {'name': 'questgoal', 'version': version},
  'data': data ?? {'301': _goal()},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FCD payload keeps original text, version, commit and digest', () {
    final raw = _payload();
    final parsed = QuestProgressDataset.parsePayload(raw, sourceCommit: 'abc');
    expect(parsed.version, '2026/10/25/01');
    expect(parsed.sourceCommit, 'abc');
    expect(parsed.rawJson, raw);
    expect(parsed.sha256, sha256.convert(utf8.encode(raw)).toString());
    expect(parsed.goals[301]!.steps.values.single['required'], 3);
    expect(() => parsed.goals.clear(), throwsUnsupportedError);
    expect(() => parsed.goals[301]!.raw.clear(), throwsUnsupportedError);
    expect(
      () => parsed.goals[301]!.raw['practice_win_a']['required'] = 1,
      throwsUnsupportedError,
    );
  });

  test('only newer payloads overlay complete quest entries', () {
    final fallback = QuestProgressDataset.parsePayload(
      _payload(data: {'301': _goal(required: 4), '302': _goal()}),
    );
    final newer = QuestProgressDataset.parsePayload(
      _payload(version: '2026/10/26/01', data: {'301': _goal(required: 2)}),
    );
    final result = newer.overlayOn(fallback);
    expect(result.goals.keys, containsAll([301, 302]));
    expect(result.goals[301]!.steps.values.single['required'], 2);
    expect(result.rawJson, newer.rawJson);
    expect(result.sha256, newer.sha256);
    expect(fallback.overlayOn(result), same(result));
    expect(fallback.overlayOn(fallback), same(fallback));
  });

  test('overlay cannot downgrade a quest migration revision', () {
    final fallback = QuestProgressDataset.parsePayload(
      _payload(
        data: {
          '301': {..._goal(), 'revision': 7},
        },
      ),
    );
    final newer = QuestProgressDataset.parsePayload(
      _payload(version: '2026/10/26/01', data: {'301': _goal()}),
    );
    expect(newer.overlayOn(fallback).goals[301]!.revision, 7);
  });

  test(
    'every downloaded payload reapplies strict local safety constraints',
    () {
      final data = {
        for (final id in [318, 350, 372, 373, 977, 1005]) '$id': _goal(),
        '1138': {
          'destory_item': {'description': 'disposal', 'required': 4, 'init': 0},
        },
      };
      data['350'] = {
        'practice_win_a': {
          'description': 'A',
          'required': 3,
          'init': 0,
          'escortshipId': [
            [
              [93, 94, 15, 16],
              4,
            ],
          ],
        },
      };
      data['1005'] = {
        'practice_win_a': {
          'description': 'A',
          'required': 1,
          'init': 0,
          'escortshipId': [
            [
              [230, 232, 231, 233],
              4,
            ],
          ],
        },
      };
      final parsed = QuestProgressDataset.parsePayload(_payload(data: data));
      expect(parsed.goals[318]!.completeOnCount, isFalse);
      expect(parsed.goals[350]!.revision, greaterThanOrEqualTo(1));
      expect(parsed.goals[350]!.steps.values.single['escortshipId'], [
        [
          [93, 94, 15, 16],
          4,
        ],
      ]);
      expect(parsed.goals[372]!.steps.values.single['escortshiptype'], [
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
      expect(
        (parsed.goals[373]!.steps.values.single['escortshipIdAll'] as List)
            .single[2],
        isTrue,
      );
      expect(parsed.goals[977]!.revision, greaterThanOrEqualTo(2));
      expect(parsed.goals[977]!.completeOnCount, isFalse);
      expect(parsed.goals[1005]!.steps.values.single['escortshipId'], [
        [
          [230, 232, 231, 233],
          4,
        ],
      ]);
      expect(parsed.goals[1138]!.completeOnCount, isFalse);
    },
  );

  test('local policy preserves stricter future IDs, counts and AND groups', () {
    final data = {
      '350': {
        'practice_win_a': {
          'description': 'A',
          'required': 5,
          'escortshipId': [
            [
              [407],
              1,
            ],
          ],
        },
      },
      '372': {
        'practice_win_a': {
          'description': 'A',
          'required': 5,
          'flagshipclass': [54],
          'escortshiptype': [
            [
              [10],
              3,
            ],
            [
              [2],
              3,
            ],
            [
              [3],
              1,
            ],
          ],
        },
      },
      '373': {
        'practice_win_a': {
          'description': 'A',
          'required': 5,
          'flagshipId': [492],
          'escortshipId': [
            [
              [935],
              3,
            ],
          ],
          'escortshipIdAll': [
            [
              [491],
              1,
            ],
          ],
        },
      },
      '977': {
        'battle_boss_win_rank_s': {
          'description': 'S',
          'required': 2,
          'maparea': [72],
          'mapcell': [17],
          'escortshipIdAll': [
            [
              [916],
              1,
            ],
            [
              [546],
              1,
            ],
          ],
        },
      },
      '1005': {
        'practice_win_a': {
          'description': 'A',
          'required': 2,
          'escortshipId': [
            [
              [407],
              1,
            ],
          ],
        },
      },
    };
    final parsed = QuestProgressDataset.parsePayload(_payload(data: data));
    expect(parsed.goals[350]!.steps.values.single['escortshipId'], [
      [
        [407],
        1,
      ],
    ]);
    expect(parsed.goals[372]!.steps.values.single['escortshiptype'], [
      [
        [10],
        3,
        true,
      ],
      [
        [2],
        3,
        true,
      ],
      [
        [3],
        1,
      ],
    ]);
    final french = parsed.goals[373]!.steps.values.single;
    expect(french['flagshipId'], [492]);
    expect(french['escortshipId'], [
      [
        [935],
        3,
      ],
    ]);
    expect((french['escortshipIdAll'] as List).first, [
      [491],
      1,
    ]);
    final yamato = parsed.goals[977]!.steps.values.single;
    expect(yamato['mapcell'], [17]);
    expect(yamato['escortshipIdAll'], [
      [
        [916],
        1,
      ],
      [
        [546],
        1,
      ],
    ]);
    expect(parsed.goals[1005]!.steps.values.single['escortshipId'], [
      [
        [407],
        1,
      ],
    ]);
    final reparsed = QuestProgressDataset.parsePayload(
      _payload(
        data: {for (final goal in parsed.goals.values) '${goal.id}': goal.raw},
      ),
    );
    for (final id in parsed.goals.keys) {
      expect(reparsed.goals[id]!.raw, parsed.goals[id]!.raw);
    }
  });

  final invalid = <String, dynamic>{
    'flat payload': {'301': _goal()},
    'wrong dataset': {
      'meta': {'name': 'quests', 'version': '2026/10/25/01'},
      'data': {'301': _goal()},
    },
    'empty goals': {
      'meta': {'name': 'questgoal', 'version': '2026/10/25/01'},
      'data': {},
    },
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.key}', () {
      expect(
        () => QuestProgressDataset.parsePayload(jsonEncode(entry.value)),
        throwsFormatException,
      );
    });
  }
  for (final version in [
    '2026/2/01/01',
    '2026/02/30/01',
    '2026/13/01/01',
    'v1',
  ]) {
    test('rejects invalid version $version', () {
      expect(
        () => QuestProgressDataset.parsePayload(_payload(version: version)),
        throwsFormatException,
      );
    });
  }
  for (final id in ['0', '-1', '03', '301x']) {
    test('rejects invalid quest ID $id', () {
      expect(
        () => QuestProgressDataset.parsePayload(_payload(data: {id: _goal()})),
        throwsFormatException,
      );
    });
  }
  final malformedGoals = <Map<String, dynamic>>[
    {},
    {
      'unknown_event': {'description': 'x', 'required': 1},
    },
    {
      'practice_win_a': {'description': 'x', 'required': 0},
    },
    {
      'practice_win_a': {'description': 'x', 'required': 1.5},
    },
    {
      'practice_win_a': {'description': 'x', 'required': 1, 'init': -1},
    },
    {
      'practice_win_a': {'description': 'x', 'required': 1, 'unknown': 1},
    },
    {
      'practice_win_a': {
        'description': 'x',
        'required': 1,
        'flagshipId': ['16'],
      },
    },
    {
      'practice_win_a': {
        'description': 'x',
        'required': 1,
        'escortshipId': [
          [
            [16],
            0,
          ],
        ],
      },
    },
    {
      'practice_win_a': {
        'description': 'x',
        'required': 1,
        'escortshipId': [
          [
            [16],
            1,
            1,
          ],
        ],
      },
    },
    {
      'practice_win_a': {
        'description': 'x',
        'required': 1,
        'escortshipIdAll': [
          [16, 1],
        ],
      },
    },
    {
      'practice_win_a': {
        'description': 'x',
        'required': 1,
        'flagship': ['潮'],
      },
    },
    {..._goal(), 'type': 99},
    {..._goal(), 'fuzzy': 'true'},
    {..._goal(), 'revision': -1},
  ];
  for (final (index, goal) in malformedGoals.indexed) {
    test('rejects malformed goal $index', () {
      expect(
        () => QuestProgressDataset.parsePayload(_payload(data: {'301': goal})),
        throwsFormatException,
      );
    });
  }

  test(
    'bundle verifies flat payload digest and metadata then reapplies policy',
    () {
      final raw = File(
        'assets/data/quest-progress-goals.json',
      ).readAsStringSync();
      final meta = File(
        'assets/data/quest-progress-meta.json',
      ).readAsStringSync();
      final bundled = QuestProgressDataset.fromBundledData(
        rawJson: raw,
        metadataJson: meta,
      );
      expect(bundled.goals, hasLength(432));
      expect(bundled.version, '2026/10/25/01');
      expect(bundled.sourceCommit, '725029997b84729df6394e1f107079b8e9437f36');
      expect(
        QuestProgressDataset.parsePayload(bundled.rawJson).goals,
        hasLength(432),
      );
      expect(
        () => QuestProgressDataset.fromBundledData(
          rawJson: '$raw ',
          metadataJson: meta,
        ),
        throwsFormatException,
      );
    },
  );

  test('bundled assets can be loaded by the app', () async {
    expect((await QuestProgressDataset.loadBundled()).goals, hasLength(432));
  });
}
