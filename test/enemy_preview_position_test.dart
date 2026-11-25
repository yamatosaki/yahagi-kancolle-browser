import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/formation_memory.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/battle/official_enemy_preview.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_engine.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';

import 'fixtures/kcsapi_fixtures.dart';

final class _InlinePredictionExecutor implements BattlePredictionExecutor {
  const _InlinePredictionExecutor();

  @override
  Future<BattlePredictionAppendResult> append({
    required BattlePredictionEngine engine,
    required String path,
    required Map<String, Object?> data,
  }) async =>
      (engine: engine, prediction: engine.append(path: path, data: data));
}

Future<BattleController> _navigationController({
  bool combined = false,
  bool raid = false,
  bool preview = true,
}) async {
  final reducer = GameStateReducer();
  var state = reducer.reduce(GameState.empty, start2Event);
  state = reducer
      .reduce(state, portEvent)
      .copyWith(
        combinedFleetType: combined
            ? CombinedFleetType.carrierTaskForce
            : CombinedFleetType.none,
        serverOrigin: 'https://example.com',
        masterShips: <int, MasterShip>{
          ...state.masterShips,
          1501: const MasterShip(
            id: 1501,
            name: '敌方主力一',
            shipTypeId: 2,
            portraitVersion: '7',
          ),
          1502: const MasterShip(
            id: 1502,
            name: '敌方随伴一',
            shipTypeId: 2,
            portraitVersion: '7',
          ),
        },
      );
  final memory = await FormationMemoryController.load(
    MemoryFormationMemoryStore(<String, int>{'1-1-1': 5}),
  );
  final controller = BattleController(
    gameState: () => state,
    formationMemory: memory,
    predictionExecutor: const _InlinePredictionExecutor(),
  );
  controller.accept(
    kcsapiEvent('/kcsapi/api_req_map/start', <String, Object?>{
      'api_maparea_id': 1,
      'api_mapinfo_no': 1,
      'api_no': 1,
      'api_event_id': 4,
      'api_event_kind': 1,
      if (preview)
        'api_e_deck_info': <Object?>[
          <String, Object?>{
            'api_kind': 1,
            'api_ship_ids': <int>[1501],
          },
          if (combined)
            <String, Object?>{
              'api_kind': 1,
              'api_ship_ids': <int>[1502],
            },
        ],
      if (raid)
        'api_destruction_battle': <String, Object?>{
          'api_f_nowhps': <int>[200],
          'api_f_maxhps': <int>[200],
          'api_air_base_attack': <String, Object?>{
            'api_stage1': <String, Object?>{'api_disp_seiku': 1},
            'api_stage3': <String, Object?>{
              'api_fdam': <num>[48.9],
            },
          },
        },
    }),
  );
  await controller.idle;
  return controller;
}

Future<void> _pumpCard(
  WidgetTester tester,
  BattleController controller, {
  required bool compact,
  bool portraits = true,
  EnemyPreviewPosition position = EnemyPreviewPosition.above,
  Locale locale = const Locale('zh'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 320,
            child: LiveBattleCard(
              controller: controller,
              collapsed: false,
              onToggleCollapse: () {},
              showEnemyPortraits: portraits,
              enemyPreviewPosition: position,
            ),
          ),
        ),
      ),
    ),
  );
  if (compact) {
    await tester.tap(find.byKey(const Key('battle-mode-compact')));
    await tester.pump();
  }
}

Finder _overview(WidgetTester tester, bool compact) {
  final panel = tester.widget<Column>(
    find.byKey(Key(compact ? 'compact-battle-panel' : 'detailed-battle-panel')),
  );
  return find.byWidget(panel.children.first);
}

void main() {
  final preview = find.byKey(const Key('official-enemy-preview'));
  final friendly = find.byKey(const Key('navigation-friendly-fleets'));
  final raidPanel = find.byKey(const Key('land-base-raid-panel'));
  final formation = find.byKey(const Key('battle-last-formation-pill'));

  for (final (locale, title) in const [
    (Locale('zh'), '敌方部队（战前预测）'),
    (Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), '敵方部隊（戰前預測）'),
    (Locale('ja'), '敵艦隊（戦闘前予測）'),
    (Locale('ko'), '적 함대 (전투 전 예측)'),
    (Locale('en'), 'Enemy fleet (pre-battle prediction)'),
  ]) {
    testWidgets('enemy forecast heading uses $locale', (tester) async {
      final controller = await _navigationController();
      addTearDown(controller.dispose);
      await _pumpCard(tester, controller, compact: false, locale: locale);
      expect(find.text(title), findsOneWidget);
    });
  }

  for (final compact in [false, true]) {
    testWidgets(
      'English air raid fits a narrow battle card (compact=$compact)',
      (tester) async {
        final controller = await _navigationController(raid: true);
        addTearDown(controller.dispose);
        await _pumpCard(
          tester,
          controller,
          compact: compact,
          locale: const Locale('en'),
        );
        expect(find.text('Air raid on base'), findsOneWidget);
        expect(find.textContaining('Air supremacy'), findsWidgets);
        expect(find.text('第一基地航空隊'), findsOneWidget);
        expect(find.text('152/200（-48）'), findsOneWidget);
        expect(find.text('敌方主力一'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final compact in <bool>[false, true]) {
    for (final combined in <bool>[false, true]) {
      for (final portraits in <bool>[false, true]) {
        for (final raid in <bool>[false, true]) {
          testWidgets(
            'legacy position maps to the whole prediction result order '
            '(compact=$compact combined=$combined portraits=$portraits raid=$raid)',
            (tester) async {
              final controller = await _navigationController(
                combined: combined,
                raid: raid,
              );
              addTearDown(controller.dispose);
              await _pumpCard(
                tester,
                controller,
                compact: compact,
                portraits: portraits,
              );

              final overviewRect = tester.getRect(_overview(tester, compact));
              final mapRect = tester.getRect(
                find.byKey(const Key('sortie-map-section')),
              );
              final overviewText = tester
                  .widgetList<Text>(
                    find.descendant(
                      of: _overview(tester, compact),
                      matching: find.byType(Text),
                    ),
                  )
                  .map((text) => (text.data, text.style))
                  .toList();
              final formationRect = tester.getRect(formation);
              final previewSize = tester.getSize(preview);
              final friendlySize = tester.getSize(friendly);
              final raidSize = raid ? tester.getSize(raidPanel) : null;
              expect(mapRect.top - overviewRect.bottom, closeTo(7, 0.001));
              expect(
                tester.getTopLeft(preview).dy - mapRect.bottom,
                closeTo(9, 0.001),
              );
              if (raid) {
                expect(
                  tester.getTopLeft(raidPanel).dy -
                      tester.getBottomLeft(preview).dy,
                  closeTo(9, 0.001),
                );
                expect(
                  tester.getTopLeft(friendly).dy -
                      tester.getBottomLeft(raidPanel).dy,
                  closeTo(9, 0.001),
                );
              } else {
                expect(
                  tester.getTopLeft(friendly).dy -
                      tester.getBottomLeft(preview).dy,
                  closeTo(9, 0.001),
                );
              }

              await _pumpCard(
                tester,
                controller,
                compact: compact,
                portraits: portraits,
                position: EnemyPreviewPosition.below,
              );

              expect(tester.getRect(_overview(tester, compact)), overviewRect);
              expect(tester.getRect(formation), formationRect);
              expect(
                tester
                    .widgetList<Text>(
                      find.descendant(
                        of: _overview(tester, compact),
                        matching: find.byType(Text),
                      ),
                    )
                    .map((text) => (text.data, text.style))
                    .toList(),
                overviewText,
              );
              expect(tester.getSize(preview), previewSize);
              expect(tester.getSize(friendly), friendlySize);
              expect(
                tester.getRect(find.byKey(const Key('sortie-map-section'))),
                mapRect,
              );
              if (raid) {
                expect(tester.getSize(raidPanel), raidSize);
                expect(
                  tester.getTopLeft(raidPanel).dy - mapRect.bottom,
                  closeTo(9, 0.001),
                );
                expect(
                  tester.getTopLeft(friendly).dy -
                      tester.getBottomLeft(raidPanel).dy,
                  closeTo(9, 0.001),
                );
                expect(find.text('152/200（-48）'), findsOneWidget);
              } else {
                expect(
                  tester.getTopLeft(friendly).dy - mapRect.bottom,
                  closeTo(9, 0.001),
                );
              }
              expect(
                tester.getTopLeft(preview).dy -
                    tester.getBottomLeft(friendly).dy,
                closeTo(9, 0.001),
              );
              final previewWidget = tester.widget<OfficialEnemyPreview>(
                find.byType(OfficialEnemyPreview),
              );
              expect(previewWidget.combined, combined);
              expect(previewWidget.showPortraits, portraits && !compact);
              expect(find.text('敌方主力一'), findsOneWidget);
              if (combined) {
                expect(find.text('敌方随伴一'), findsOneWidget);
                expect(
                  find.byKey(const Key('navigation-combined-fleets')),
                  findsOneWidget,
                );
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    for (final raid in <bool>[false, true]) {
      testWidgets(
        'missing preview keeps original layout (compact=$compact raid=$raid)',
        (tester) async {
          final controller = await _navigationController(
            preview: false,
            raid: raid,
          );
          addTearDown(controller.dispose);
          await _pumpCard(tester, controller, compact: compact);
          final overviewRect = tester.getRect(_overview(tester, compact));
          final mapRect = tester.getRect(
            find.byKey(const Key('sortie-map-section')),
          );
          final friendlyRect = tester.getRect(friendly);
          final raidRect = raid ? tester.getRect(raidPanel) : null;
          await _pumpCard(
            tester,
            controller,
            compact: compact,
            position: EnemyPreviewPosition.below,
          );
          expect(preview, findsNothing);
          expect(tester.getRect(_overview(tester, compact)), overviewRect);
          expect(tester.getRect(friendly), friendlyRect);
          if (raid) {
            expect(tester.getRect(raidPanel), raidRect);
            expect(friendlyRect.top - raidRect!.bottom, 9);
            expect(raidRect.top - mapRect.bottom, 9);
          } else {
            expect(friendlyRect.top - mapRect.bottom, 9);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final result in <bool>[false, true]) {
      testWidgets(
        'position does not affect battle or result (compact=$compact result=$result)',
        (tester) async {
          final controller = await _navigationController();
          addTearDown(controller.dispose);
          controller.accept(dayBattleEvent);
          if (result) controller.accept(battleResultEvent);
          await controller.idle;
          await _pumpCard(tester, controller, compact: compact);
          final panel = find.byKey(
            Key(compact ? 'compact-battle-panel' : 'detailed-battle-panel'),
          );
          final rect = tester.getRect(panel);
          final texts = tester
              .widgetList<Text>(
                find.descendant(of: panel, matching: find.byType(Text)),
              )
              .map((text) => text.data)
              .toList();
          await _pumpCard(
            tester,
            controller,
            compact: compact,
            position: EnemyPreviewPosition.below,
          );
          expect(tester.getRect(panel), rect);
          expect(
            tester
                .widgetList<Text>(
                  find.descendant(of: panel, matching: find.byType(Text)),
                )
                .map((text) => text.data)
                .toList(),
            texts,
          );
          expect(preview, findsNothing);
          expect(friendly, findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
