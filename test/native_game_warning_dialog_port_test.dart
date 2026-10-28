import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_warning_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.yahagi.kancollebrowser/native_warning');
  const port = MethodChannelNativeGameWarningDialogPort(channel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final action in NativeGameWarningAction.values) {
    test(
      'maps the native ${action.name} result without changing the payload',
      () async {
        final payload = <String, Object?>{
          'id': 73,
          'title': '危险',
          'rows': ['舰娘 2/20'],
        };
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'show');
          expect(call.arguments, payload);
          return action.name;
        });
        expect(await port.show(payload), action);
      },
    );
  }

  test('native lifecycle cancellation produces no button action', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await port.show({'id': 1}), isNull);
  });

  test(
    'an unrecognized native response is rejected for safe fallback',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => 'unrecognized');
      await expectLater(port.show({'id': 1}), throwsStateError);
    },
  );

  test(
    'updates and dismissals always identify the owned presentation',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      await port.update({'id': 98, 'title': '更新'});
      await port.dismiss(98);
      expect(calls.map((call) => call.method), ['update', 'dismiss']);
      expect(calls.first.arguments, {'id': 98, 'title': '更新'});
      expect(calls.last.arguments, {'id': 98});
    },
  );

  test(
    'native presentation failure remains an error for Flutter fallback',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'native_warning_unavailable');
      });
      await expectLater(
        port.show({'id': 1}),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  for (final kind in ['debuff', 'newShip']) {
    test('reminder $kind identifies all native lifecycle calls', () async {
      final calls = <MethodCall>[];
      final reminder = MethodChannelNativeGameWarningDialogPort.forReminder(
        kind,
        channel,
      );
      final payload = <String, Object?>{'id': 81, 'title': '提醒'};
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'show' ? 'acknowledge' : null;
      });
      expect(await reminder.show(payload), NativeGameWarningAction.acknowledge);
      await reminder.update(payload);
      await reminder.dismiss(81);
      expect(calls.map((call) => call.method), ['show', 'update', 'dismiss']);
      expect(calls[0].arguments, {...payload, 'kind': kind});
      expect(calls[1].arguments, {...payload, 'kind': kind});
      expect(calls[2].arguments, {'id': 81, 'kind': kind});
      expect(payload, {'id': 81, 'title': '提醒'});
    });
  }
}
