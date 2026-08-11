import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/performance/frame_notification_coalescer.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  group('GameStateController', () {
    test('processes captured events in acceptance order', () async {
      final controller = GameStateController();
      addTearDown(controller.dispose);

      controller
        ..accept(portEvent)
        ..accept(
          kcsapiEvent('/kcsapi/api_get_member/material', <Object?>[
            <String, Object?>{'api_id': 1, 'api_value': 321},
          ], sequence: 2),
        );
      await controller.idle;

      expect(controller.state.resource(GameResourceType.fuel), 321);
      expect(controller.lastError, isNull);
      expect(controller.lastUpdatedPath, '/kcsapi/api_get_member/material');
    });

    test(
      'coalesces capture notifications while committing every state',
      () async {
        final scheduled = <void Function()>[];
        final controller = GameStateController(
          captureNotifications: FrameNotificationCoalescer(
            scheduleFrame: scheduled.add,
          ),
        );
        addTearDown(controller.dispose);
        var notifications = 0;
        controller.addListener(() => notifications += 1);

        controller
          ..accept(portEvent)
          ..accept(
            kcsapiEvent('/kcsapi/api_get_member/material', <Object?>[
              <String, Object?>{'api_id': 1, 'api_value': 321},
            ], sequence: 2),
          );
        await controller.idle;

        expect(controller.state.resource(GameResourceType.fuel), 321);
        expect(notifications, 0);
        expect(scheduled, hasLength(1));
        scheduled.single();
        expect(notifications, 1);
      },
    );

    test('invalid event keeps the last valid state', () async {
      final controller = GameStateController();
      addTearDown(controller.dispose);
      controller.accept(portEvent);
      await controller.idle;
      final previous = controller.state;

      controller.accept(
        kcsapiEvent(
          '/kcsapi/api_get_member/material',
          const <Object?>[],
          apiResult: 0,
        ),
      );
      await controller.idle;

      expect(controller.state, same(previous));
      expect(controller.lastError, '游戏数据解析失败（GameApiParseException）');
    });
    test(
      'battle forecast synchronizes friendly HP without a port refresh',
      () async {
        final controller = GameStateController();
        final battleController = BattleController(
          gameState: () => controller.state,
        );
        addTearDown(controller.dispose);
        addTearDown(battleController.dispose);

        controller
          ..accept(start2Event)
          ..accept(portEvent);
        await controller.idle;
        expect(controller.state.ships[9001]!.currentHp, 28);
        expect(controller.state.ships[9002]!.currentHp, 8);

        controller.accept(mapStartEvent);
        battleController.accept(mapStartEvent);
        await controller.idle;
        await battleController.idle;

        controller.accept(dayBattleEvent);
        battleController.accept(dayBattleEvent);
        await controller.idle;
        await battleController.idle;
        await controller.idle;

        expect(controller.state.ships[9001]!.currentHp, 28);
        expect(controller.state.ships[9002]!.currentHp, 8);

        battleController.bindFriendlyHpUpdater(
          controller.applyFriendlyBattleHp,
        );
        await controller.idle;

        expect(controller.state.ships[9001]!.currentHp, 18);
        expect(controller.state.ships[9002]!.currentHp, 15);

        controller.accept(nightBattleEvent);
        battleController.accept(nightBattleEvent);
        await controller.idle;
        await battleController.idle;
        await controller.idle;

        expect(controller.state.ships[9001]!.currentHp, 13);
        expect(controller.state.ships[9002]!.currentHp, 15);
      },
    );

    test('practice battle HP never overwrites the owned fleet', () async {
      final controller = GameStateController();
      final battleController = BattleController(
        gameState: () => controller.state,
        onFriendlyHpUpdated: controller.applyFriendlyBattleHp,
      );
      addTearDown(controller.dispose);
      addTearDown(battleController.dispose);

      controller
        ..accept(start2Event)
        ..accept(portEvent);
      await controller.idle;

      battleController.accept(
        kcsapiEvent('/kcsapi/api_req_practice/battle', <String, Object?>{
          'api_deck_id': 1,
          'api_f_nowhps': <int>[28, 8],
          'api_f_maxhps': <int>[30, 15],
          'api_e_nowhps': <int>[20],
          'api_e_maxhps': <int>[20],
          'api_ship_ke': <int>[501],
          'api_hougeki1': <String, Object?>{
            'api_at_eflag': <int>[1],
            'api_at_list': <int>[0],
            'api_df_list': <Object?>[
              <int>[0],
            ],
            'api_damage': <Object?>[
              <num>[5],
            ],
          },
        }, sequence: 2001),
      );
      await battleController.idle;

      battleController.accept(
        kcsapiEvent(
          '/kcsapi/api_req_practice/midnight_battle',
          <String, Object?>{
            'api_hougeki': <String, Object?>{
              'api_at_eflag': <int>[1],
              'api_at_list': <int>[0],
              'api_df_list': <Object?>[
                <int>[0],
              ],
              'api_damage': <Object?>[
                <num>[5],
              ],
            },
          },
          sequence: 2002,
        ),
      );
      await battleController.idle;
      await controller.idle;

      expect(controller.state.ships[9001]!.currentHp, 28);
      expect(controller.state.ships[9002]!.currentHp, 8);
    });

    test(
      'delayed cache restore never overwrites an accepted live event',
      () async {
        final store = _DelayedGameStateStore();
        final controller = GameStateController(gameStateStore: store);
        addTearDown(controller.dispose);

        controller.accept(
          kcsapiEvent('/kcsapi/api_get_member/material', <Object?>[
            <String, Object?>{'api_id': 1, 'api_value': 321},
          ], sequence: 2),
        );
        await controller.idle;

        store.completeLoad(
          GameState(
            resources: const <GameResourceType, int>{
              GameResourceType.fuel: 999,
            },
            hasPortData: true,
            updatedAt: DateTime.utc(2026),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(controller.state.resource(GameResourceType.fuel), 321);
      },
    );
  });
}

final class _DelayedGameStateStore extends GameStateStore {
  final Completer<GameState> _loadCompleter = Completer<GameState>();

  @override
  Future<GameState> load() => _loadCompleter.future;

  void completeLoad(GameState state) => _loadCompleter.complete(state);

  @override
  void save(GameState state) {}
}
