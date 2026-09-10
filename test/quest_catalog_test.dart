import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_merger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalog = QuestCatalog(<QuestCatalogEntry>[
    const QuestCatalogEntry(
      gameId: 101,
      code: 'A1',
      name: 'はじめての「編成」！',
      description: '前置説明',
    ),
    const QuestCatalogEntry(
      gameId: 201,
      code: 'B1',
      name: '敵艦隊を撃破せよ！',
      description: '当前说明',
      prerequisites: <String>['A1'],
    ),
    const QuestCatalogEntry(
      gameId: 202,
      code: 'Bd2',
      name: '敵艦隊主力を撃滅せよ！',
      description: '后置说明',
      prerequisites: <String>['B1'],
    ),
  ]);

  test('projects English codes and pre/post quest relations', () {
    expect(catalog.byGameId(201)?.code, 'B1');
    expect(catalog.prerequisitesOf(201).map((q) => q.code), <String>['A1']);
    expect(catalog.successorsOf(201).map((q) => q.code), <String>['Bd2']);
  });

  test('projects unlocked state and progress from live quest chain', () {
    const live = <int, GameQuest>{
      201: GameQuest(
        id: 201,
        title: 'live',
        detail: '',
        category: 2,
        type: 4,
        state: 2,
        progressFlag: 1,
      ),
    };

    final projection = catalog.project(live);

    expect(
      projection.byGameId(101).unlockState,
      isNot(QuestUnlockState.unlocked),
    );
    expect(projection.byGameId(101).progressLabel, '100%');
    expect(projection.byGameId(201).progressLabel, '50%+');
    expect(projection.byGameId(202).unlockState, QuestUnlockState.locked);
    expect(projection.byGameId(202).progressLabel, '—');
  });

  test(
    'indexed relations preserve first-match behavior and tolerate cycles',
    () {
      final cyclic = QuestCatalog(const <QuestCatalogEntry>[
        QuestCatalogEntry(
          gameId: 1,
          code: 'A1',
          name: 'first',
          description: '',
          prerequisites: <String>['B1'],
        ),
        QuestCatalogEntry(
          gameId: 2,
          code: 'B1',
          name: 'second',
          description: '',
          prerequisites: <String>['A1'],
        ),
        QuestCatalogEntry(
          gameId: 3,
          code: 'A1',
          name: 'duplicate code',
          description: '',
        ),
      ]);

      expect(cyclic.byCode('A1')?.gameId, 1);
      expect(cyclic.prerequisitesOf(1).map((entry) => entry.gameId), <int>[2]);
      expect(cyclic.successorsOf(1).map((entry) => entry.gameId), <int>[2]);

      final projection = cyclic.project(const <int, GameQuest>{
        1: GameQuest(
          id: 1,
          title: 'live',
          detail: '',
          category: 1,
          type: 1,
          state: 2,
          progressFlag: 0,
        ),
      });
      expect(projection.byGameId(1).liveQuest, isNotNull);
      expect(() => projection.byGameId(999), throwsStateError);
    },
  );

  test(
    'matches Poi completion inference for a finished sibling quest chain',
    () {
      final branching = QuestCatalog(const [
        QuestCatalogEntry(gameId: 1, code: 'A1', name: '', description: ''),
        QuestCatalogEntry(
          gameId: 2,
          code: 'A2',
          name: '',
          description: '',
          prerequisites: ['A1'],
        ),
        QuestCatalogEntry(
          gameId: 3,
          code: 'A3',
          name: '',
          description: '',
          prerequisites: ['A1'],
        ),
        QuestCatalogEntry(
          gameId: 4,
          code: 'A4',
          name: '',
          description: '',
          prerequisites: ['A3'],
        ),
        QuestCatalogEntry(gameId: 5, code: 'A5', name: '', description: ''),
        QuestCatalogEntry(
          gameId: 6,
          code: 'A6',
          name: '',
          description: '',
          prerequisites: ['A2'],
        ),
      ]);
      const live = GameQuest(
        id: 2,
        title: '',
        detail: '',
        category: 1,
        type: 4,
        state: 1,
        progressFlag: 0,
      );
      final partial = branching.project({2: live}, isComplete: false);
      expect(partial.byGameId(3).unlockState, QuestUnlockState.unknown);
      expect(partial.byGameId(4).unlockState, QuestUnlockState.unknown);
      expect(partial.byGameId(1).unlockState, QuestUnlockState.completed);
      final projection = branching.project({2: live});
      expect(projection.byGameId(1).unlockState, QuestUnlockState.completed);
      expect(projection.byGameId(2).unlockState, QuestUnlockState.unlocked);
      expect(projection.byGameId(3).unlockState, QuestUnlockState.completed);
      expect(projection.byGameId(4).unlockState, QuestUnlockState.completed);
      expect(projection.byGameId(5).unlockState, QuestUnlockState.unknown);
      expect(projection.byGameId(6).unlockState, QuestUnlockState.locked);
    },
  );

  test(
    'Poi completed filter requires server completion for a visible task',
    () {
      for (final state in [1, 2, 3]) {
        final projection = catalog.project({
          201: GameQuest(
            id: 201,
            title: '',
            detail: '',
            category: 2,
            type: 4,
            state: state,
            progressFlag: 2,
            progressCurrent: 1,
            progressRequired: 1,
          ),
        });
        final current = projection.byGameId(201);
        expect(current.liveQuest!.isLocallyCompleted, isTrue);
        expect(
          current.matchesUnlockFilter(QuestUnlockState.completed),
          state == 3,
        );
        expect(current.matchesUnlockFilter(QuestUnlockState.unlocked), isTrue);
        expect(
          projection
              .byGameId(101)
              .matchesUnlockFilter(QuestUnlockState.completed),
          isTrue,
        );
        expect(
          projection.byGameId(202).matchesUnlockFilter(QuestUnlockState.locked),
          isTrue,
        );
      }
    },
  );

  test('loads the bundled Japanese quest catalog with relations', () async {
    final bundled = await QuestCatalog.loadAsset();

    expect(bundled.entries.length, greaterThan(500));
    expect(bundled.byGameId(201)?.code, 'Bd1');
    expect(bundled.byGameId(201)?.name, '敵艦隊を撃破せよ！');
    expect(bundled.byGameId(201)?.description, contains('敵艦隊'));
    expect(bundled.byGameId(201)?.description, isNot(contains('敌舰队')));
    expect(bundled.successorsOf(201), isNotEmpty);
    expect(bundled.byGameId(442)?.translatedName, '实施西方联络作战准备！');
    expect(bundled.byGameId(442)?.translatedDescription, contains('「潜水艇派遣作战」'));
    expect(bundled.byGameId(442)?.translatedDescription, isNot(contains('|')));
  });

  test('merges Japanese display text with kcWiki quest relations', () {
    final merged = mergeQuestCatalogJson(
      japaneseJson: jsonEncode(<String, Object?>{
        '201': <String, Object?>{
          'code': 'Bq11',
          'name': '南西諸島方面「海上警備行動」発令！',
          'desc': '艦隊を南西諸島方面へ出撃させよ！',
          'rewards': '開発資材',
        },
      }),
      relationJson: jsonEncode(<String, Object?>{
        '201': <String, Object?>{
          'code': 'Bq11',
          'name': '南西诸岛方面“海上警备行动”发令！',
          'desc': '执行「远征|西方海域侦察作战」<br>以及后续远征',
          'memo': '中文奖励',
          'pre': <String>['Bm8', 'Cd1'],
        },
      }),
    );
    final entry = (jsonDecode(merged) as Map<String, dynamic>)['201'];

    expect(entry['name'], '南西諸島方面「海上警備行動」発令！');
    expect(entry['desc'], '艦隊を南西諸島方面へ出撃させよ！');
    expect(entry['rewards'], '開発資材');
    expect(entry['pre'], <String>['Bm8', 'Cd1']);
    expect(entry['nameZh'], '南西诸岛方面“海上警备行动”发令！');
    expect(entry['descZh'], '执行「西方海域侦察作战」以及后续远征');

    final parsed = QuestCatalogEntry.fromJson(201, entry);
    expect(parsed.translatedName, '南西诸岛方面“海上警备行动”发令！');
    expect(parsed.translatedDescription, '执行「西方海域侦察作战」以及后续远征');
  });

  test('uses local quest translations only for missing upstream fields', () {
    final localOnly = QuestCatalogEntry.fromJson(380, <String, Object?>{
      'code': 'L2507C1',
      'name': '日本語名',
      'desc': '日本語説明',
    });
    expect(localOnly.translatedName, '【期间限定任务】登陆船团护卫演习');
    expect(localOnly.translatedDescription, contains('至少1艘登陆舰及至少2艘护卫海防舰'));

    final partiallyTranslated = QuestCatalogEntry.fromJson(
      380,
      <String, Object?>{
        'code': 'L2507C1',
        'name': '日本語名',
        'desc': '日本語説明',
        'nameZh': '上游名称',
        'descZh': '   ',
      },
    );
    expect(partiallyTranslated.translatedName, '上游名称');
    expect(
      partiallyTranslated.translatedDescription,
      contains('至少1艘登陆舰及至少2艘护卫海防舰'),
    );
  });

  test('every bundled quest has a complete Chinese detail translation', () async {
    final bundled = await QuestCatalog.loadAsset();
    final missing = <String>[
      for (final entry in bundled.entries)
        if (entry.translatedName == null || entry.translatedDescription == null)
          '${entry.gameId}/${entry.code}: '
              '${entry.translatedName == null ? 'name' : ''}'
              '${entry.translatedName == null && entry.translatedDescription == null ? '+' : ''}'
              '${entry.translatedDescription == null ? 'description' : ''}',
    ];
    final hardBreak = RegExp(
      r'<br\b[^>]*>|[\r\n\u0085\u2028\u2029]',
      caseSensitive: false,
    );
    final hardBreaks = <String>[
      for (final entry in bundled.entries)
        if (hardBreak.hasMatch(entry.description) ||
            hardBreak.hasMatch(entry.translatedDescription ?? ''))
          '${entry.gameId}/${entry.code}',
    ];

    expect(missing, isEmpty, reason: missing.join('\n'));
    expect(hardBreaks, isEmpty, reason: hardBreaks.join('\n'));
  });

  test('uses game id when upstream quest codes differ', () {
    final merged = mergeQuestCatalogJson(
      japaneseJson: jsonEncode(<String, Object?>{
        '199': <String, Object?>{
          'code': 'L2606A1',
          'name': '期間限定任務',
          'desc': '日本語説明',
        },
      }),
      relationJson: jsonEncode(<String, Object?>{
        '199': <String, Object?>{
          'code': '2606Am1',
          'pre': <String>['Fd4'],
        },
      }),
    );

    final entry = (jsonDecode(merged) as Map<String, dynamic>)['199'];
    expect(entry['code'], 'L2606A1');
    expect(entry['pre'], <String>['Fd4']);
  });
}
