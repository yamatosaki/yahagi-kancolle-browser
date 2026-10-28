import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_resource_checklist.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_warning_dialog.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'same named channel instances broadcast one event to both editors',
    () async {
      final first = MethodChannelNativeGameResourceChecklistPort(
        MethodChannel('checklist-shared-events'),
      );
      final second = MethodChannelNativeGameResourceChecklistPort(
        MethodChannel('checklist-shared-events'),
      );
      final firstEvents = <Map<String, Object?>>[];
      final secondEvents = <Map<String, Object?>>[];
      final a = first.events.listen(firstEvents.add);
      final b = second.events.listen(secondEvents.add);
      const event = {
        'kind': 'headerResources',
        'id': 7,
        'event': 'toggle',
        'itemId': 'senka',
        'checked': false,
        'changeId': 1,
      };
      // Test messenger's incoming platform dispatcher is the supported harness.
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        'checklist-shared-events',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('checklistChanged', event),
        ),
        (_) {},
      );
      expect(firstEvents, [event]);
      expect(secondEvents, [event]);
      await a.cancel();
      await b.cancel();
    },
  );

  test(
    'show, update and dismiss preserve the request kind and item data',
    () async {
      const channel = MethodChannel('checklist-method-contract');
      const port = MethodChannelNativeGameResourceChecklistPort(channel);
      final calls = <MethodCall>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'show' ? 'acknowledge' : null;
      });
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final payload = <String, Object?>{
        'kind': 'headerResources',
        'id': 8,
        'items': [
          {'id': 'senka', 'label': 'Senka', 'value': '2', 'checked': true},
        ],
        'appliedChangeId': 0,
      };
      expect(await port.show(payload), NativeGameWarningAction.acknowledge);
      await port.update({...payload, 'appliedChangeId': 1});
      await port.dismiss(kind: 'headerResources', id: 8);
      expect(calls.map((c) => c.method), ['show', 'update', 'dismiss']);
      expect(calls.first.arguments, payload);
      expect(calls.last.arguments, {'kind': 'headerResources', 'id': 8});
    },
  );

  for (final action in ['toggle failure', 'reset failure']) {
    test('$action is contained and still acknowledges its change id', () async {
      final port = _Port();
      var checked = true;
      final adapter = NativeGameResourceChecklistAdapter(
        kind: 'headerResources',
        port: port,
        items: () => [
          {'id': 'senka', 'label': 'Senka', 'value': '2', 'checked': checked},
        ],
        isCurrent: () => true,
        onToggle: (_) {
          checked = false;
          return Future<void>.error(StateError('save failed'));
        },
        onReset: () => Future<void>.error(StateError('reset failed')),
        doneLabel: 'Done',
        resetLabel: 'Reset',
      );
      final result = adapter.show({'id': 9});
      port.eventsController.add({
        'kind': 'headerResources',
        'id': 9,
        'event': action == 'toggle failure' ? 'toggle' : 'reset',
        'itemId': 'senka',
        'checked': false,
        'changeId': 1,
      });
      await Future<void>.delayed(Duration.zero);
      expect(port.updated.last['appliedChangeId'], 1);
      port.result.complete(NativeGameWarningAction.acknowledge);
      expect(await result, NativeGameWarningAction.acknowledge);
      await port.eventsController.close();
    });
  }

  test(
    'an event for a row removed by an external update is acknowledged without saving',
    () async {
      final port = _Port();
      final rows = <Map<String, Object?>>[
        {'id': 'senka', 'label': 'Senka', 'value': '2', 'checked': true},
      ];
      var saves = 0;
      final adapter = NativeGameResourceChecklistAdapter(
        kind: 'collapsedResources',
        port: port,
        items: () => rows,
        isCurrent: () => true,
        onToggle: (_) {
          saves++;
        },
        doneLabel: 'Done',
      );
      final result = adapter.show({'id': 10});
      rows.clear();
      adapter.updateCurrent();
      port.eventsController.add({
        'kind': 'collapsedResources',
        'id': 10,
        'event': 'toggle',
        'itemId': 'senka',
        'checked': false,
        'changeId': 1,
      });
      expect(saves, 0);
      expect(port.updated.last['appliedChangeId'], 1);
      port.result.complete(NativeGameWarningAction.acknowledge);
      await result;
      await port.eventsController.close();
    },
  );
}

class _Port implements NativeGameResourceChecklistPort {
  final eventsController = StreamController<Map<String, Object?>>.broadcast(
    sync: true,
  );
  final result = Completer<NativeGameWarningAction?>();
  final updated = <Map<String, Object?>>[];
  @override
  Stream<Map<String, Object?>> get events => eventsController.stream;
  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> payload) =>
      result.future;
  @override
  Future<void> update(Map<String, Object?> payload) async =>
      updated.add(payload);
  @override
  Future<void> dismiss({required String kind, required int id}) async {}
}
