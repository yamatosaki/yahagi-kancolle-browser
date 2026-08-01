import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';

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
