import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_api_event_pipeline.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/notification/game_notification_coordinator.dart';
import 'package:yahagi_kancolle_browser/src/notification/method_channel_notification_port.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';

import '../fixtures/kcsapi_fixtures.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/expedition_recall_notifications');
  const recallPath = '/kcsapi/api_req_mission/return_instruction';
  const preempt = Duration(minutes: 1);

  test(
    'a recall response replaces only that fleet’s expedition alarms',
    () async {
      final now = DateTime.utc(2026, 9, 24, 6);
      final originalReturn = now.add(const Duration(hours: 2));
      final otherReturn = now.add(const Duration(hours: 3));
      final recallReturn = now.add(const Duration(minutes: 20));
      final stateController = GameStateController(
        initialState: GameState.empty.copyWith(
          fleets: [
            Fleet(
              id: 2,
              name: 'Fleet 2',
              mission: FleetMission(
                state: 1,
                missionId: 5,
                completionTime: originalReturn,
              ),
            ),
            Fleet(
              id: 3,
              name: 'Fleet 3',
              mission: FleetMission(
                state: 1,
                missionId: 6,
                completionTime: otherReturn,
              ),
            ),
          ],
        ),
      );
      addTearDown(stateController.dispose);
      final settings = NotificationSettingsController();
      addTearDown(settings.dispose);
      final messenger = binding.defaultBinaryMessenger;
      Map<Object?, Object?> latestSnapshot = {};
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'applySnapshot');
        latestSnapshot = call.arguments as Map<Object?, Object?>;
        return {'scheduledExact': 4, 'failures': <String>[]};
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final coordinator = GameNotificationCoordinator(
        gameStateController: stateController,
        settingsController: settings,
        notificationPort: const MethodChannelNotificationPort(channel),
        nowProvider: () => now,
      );
      addTearDown(coordinator.dispose);
      final pipeline = GameApiEventPipeline(consumers: [stateController]);

      Map<Object?, Object?> scheduledInstants() {
        final alarms = (latestSnapshot['alarms'] as List<Object?>)
            .cast<Map<Object?, Object?>>();
        return {
          for (final alarm in alarms) alarm['key']: alarm['triggerTimeEpochMs'],
        };
      }

      coordinator.start();
      await Future<void>.delayed(Duration.zero);
      final originalAlarms = {
        'expedition_2_preempt': originalReturn
            .subtract(preempt)
            .millisecondsSinceEpoch,
        'expedition_2_complete': originalReturn.millisecondsSinceEpoch,
        'expedition_3_preempt': otherReturn
            .subtract(preempt)
            .millisecondsSinceEpoch,
        'expedition_3_complete': otherReturn.millisecondsSinceEpoch,
      };
      expect(scheduledInstants(), originalAlarms);

      pipeline.add(
        kcsapiEvent(
          recallPath,
          {
            'api_mission': [3, 5],
          },
          requestParams: {'api_deck_id': '2'},
          capturedAt: now,
        ),
      );
      await pipeline.idle;
      await Future<void>.delayed(Duration.zero);
      expect(scheduledInstants(), originalAlarms);

      pipeline.add(
        kcsapiEvent(
          recallPath,
          {
            'api_mission': [3, 5, recallReturn.millisecondsSinceEpoch, 0],
          },
          requestParams: {'api_deck_id': '2'},
          capturedAt: now,
          sequence: 2,
        ),
      );
      await pipeline.idle;
      await Future<void>.delayed(Duration.zero);

      expect(scheduledInstants(), {
        ...originalAlarms,
        'expedition_2_preempt': recallReturn
            .subtract(preempt)
            .millisecondsSinceEpoch,
        'expedition_2_complete': recallReturn.millisecondsSinceEpoch,
      });
      expect(stateController.state.fleets.first.mission.state, 3);
    },
  );
}
