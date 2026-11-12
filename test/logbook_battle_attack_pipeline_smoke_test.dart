import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_detail_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/prediction/battle_prediction_executor.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_page.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets(
    'captured day and night attacks survive backup and logbook reopen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final reducer = GameStateReducer();
      final state = reducer
          .reduce(reducer.reduce(GameState.empty, start2Event), portEvent)
          .copyWith(memberId: 91017);
      final controller = BattleController(
        gameState: () => state,
        predictionExecutor: const ImmediateBattlePredictionExecutor(),
      );
      addTearDown(controller.dispose);
      final capturedDatabase = LogbookDatabase.forAccount(state.memberId);
      addTearDown(capturedDatabase.close);

      final day = (jsonDecode(dayBattleEvent.responseBody)['api_data'] as Map)
          .cast<String, Object?>();
      day.remove('api_raigeki');
      day['api_hougeki1'] = {
        'api_at_eflag': [0, 1, 0],
        'api_at_list': [0, 0, 1],
        'api_at_type': [101, 7, 2],
        'api_df_list': [
          [0, 0, 1],
          [0],
          [0, 0],
        ],
        'api_damage': [
          [2, 3, 4],
          [0],
          [1, 2],
        ],
        'api_cl_list': [
          [1, 1, 1],
          [0],
          [1, 1],
        ],
      };
      final night = kcsapiEvent(nightBattleEvent.path, {
        'api_hougeki': {
          'api_at_eflag': [0, 1, 1],
          'api_at_list': [0, 0, 1],
          'api_sp_list': [3, 4, 6],
          'api_df_list': [
            [0, 0],
            [0],
            [1],
          ],
          'api_damage': [
            [2, 4],
            [6],
            [0],
          ],
          'api_cl_list': [
            [1, 1],
            [2],
            [0],
          ],
        },
      }, sequence: 22);
      final result = kcsapiEvent(battleResultEvent.path, {
        'api_win_rank': 'S',
        'api_enemy_info': {'api_deck_name': '冒烟测试舰队'},
      }, sequence: 23);

      final reopened = (await tester.runAsync(() async {
        controller
          ..accept(mapStartEvent)
          ..accept(kcsapiEvent(dayBattleEvent.path, day, sequence: 21))
          ..accept(night);
        await controller.idle;
        expect(await capturedDatabase.getSortieRecords(), isEmpty);

        final changes = capturedDatabase.changesFor(
          LogbookChangeCategory.battle,
        );
        final saved = Completer<void>();
        void onSave() {
          if (!saved.isCompleted) saved.complete();
        }

        changes.addListener(onSave);
        addTearDown(() => changes.removeListener(onSave));
        controller
          ..accept(result)
          ..accept(result);
        await controller.idle;
        expect(controller.lastError, isNull);
        expect(controller.records, hasLength(1));
        await saved.future.timeout(const Duration(seconds: 5));
        final rows = await capturedDatabase.getSortieRecords();
        expect(rows, hasLength(1));
        expect(rows.single['has_detail'], 1);
        final id = (rows.single['id'] as int) ~/ 2;
        final recorded = (await capturedDatabase.getBattleDetail(id))!;
        expect(recorded.toJson(), controller.records.single.detail!.toJson());
        expect(
          recorded.stages
              .expand((stage) => stage.attacks)
              .map(
                (attack) => (
                  attack.attackTypeCode,
                  attack.attackerSide,
                  attack.defenderHpBefore,
                  attack.defenderHpAfter,
                ),
              ),
          [
            ('Nagato', BattleDetailSide.friend, 20, 18),
            ('Nagato', BattleDetailSide.friend, 18, 15),
            ('Nagato', BattleDetailSide.friend, 10, 6),
            ('CVCI', BattleDetailSide.enemy, 30, 30),
            ('Double', BattleDetailSide.friend, 15, 12),
            ('TTCI', BattleDetailSide.friend, 12, 6),
            ('PSCI', BattleDetailSide.enemy, 30, 24),
            ('NightCarrierCI', BattleDetailSide.enemy, 15, 15),
          ],
        );

        final directory = await Directory.systemTemp.createTemp(
          'yahagi-battle-attack-smoke-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final path = '${directory.path}${Platform.pathSeparator}logbook.db';
        final restored = await LogbookDatabase.openForTesting(path: path);
        try {
          await restored.restoreSnapshot(
            await capturedDatabase.backupSnapshot(),
          );
        } finally {
          await restored.close();
        }
        final reopened = await LogbookDatabase.openForTesting(path: path);
        addTearDown(reopened.close);
        expect(
          (await reopened.getBattleDetail(id))?.toJson(),
          recorded.toJson(),
        );
        return reopened;
      }))!;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: LogbookPage(battleController: controller, database: reopened),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('battle-detail-tab-process')));
      await tester.pumpAndSettle();
      expect(find.text('一齐射击（长门）'), findsNWidgets(3));
      expect(find.text('鱼雷 CI'), findsOneWidget);
      expect(find.text('战爆联合 CI'), findsOneWidget);
      expect(find.text('主炮·副炮 CI'), findsOneWidget);
      expect(find.text('空母夜袭 CI'), findsOneWidget);
      expect(find.text('未命中'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('battle-detail-filter-enemy')));
      await tester.pumpAndSettle();
      expect(find.text('一齐射击（长门）'), findsNothing);
      expect(find.text('鱼雷 CI'), findsNothing);
      expect(find.text('主炮·副炮 CI'), findsOneWidget);
      expect(find.text('空母夜袭 CI'), findsOneWidget);
      expect(find.text('未命中'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
