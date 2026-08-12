import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_merger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const catalog = QuestCatalog(<QuestCatalogEntry>[
    QuestCatalogEntry(
      gameId: 101,
      code: 'A1',
      name: 'はじめての「編成」！',
      description: '前置説明',
    ),
    QuestCatalogEntry(
      gameId: 201,
      code: 'B1',
      name: '敵艦隊を撃破せよ！',
      description: '当前说明',
      prerequisites: <String>['A1'],
    ),
    QuestCatalogEntry(
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

    expect(projection.byGameId(101).unlockState, QuestUnlockState.unlocked);
    expect(projection.byGameId(101).progressLabel, '100%');
    expect(projection.byGameId(201).progressLabel, '50%+');
    expect(projection.byGameId(202).unlockState, QuestUnlockState.locked);
    expect(projection.byGameId(202).progressLabel, '＜50%');
  });

  test('loads the bundled Japanese quest catalog with relations', () async {
    final bundled = await QuestCatalog.loadAsset();

    expect(bundled.entries.length, greaterThan(500));
    expect(bundled.byGameId(201)?.code, 'Bd1');
    expect(bundled.byGameId(201)?.name, '敵艦隊を撃破せよ！');
    expect(bundled.byGameId(201)?.description, contains('敵艦隊'));
    expect(bundled.byGameId(201)?.description, isNot(contains('敌舰队')));
    expect(bundled.successorsOf(201), isNotEmpty);
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
          'desc': '中文说明',
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
    expect(merged, isNot(contains('中文')));
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
