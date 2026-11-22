import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_startup_activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(
    'app.yahagi.kancollebrowser/game_startup_activity',
  );
  const port = MethodChannelGameStartupActivityPort();
  const state = <String, Object?>{
    'navigationId': 17,
    'requestCount': 9,
    'gameResources': true,
    'gameApi': false,
  };

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'polls the requested surface and decodes the privacy-safe snapshot',
    () async {
      final routes = <Object?>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'snapshot');
        expect(call.arguments, isA<Map<Object?, Object?>>());
        routes.add((call.arguments as Map<Object?, Object?>)['nativeActivity']);
        return state;
      });

      for (final nativeActivity in [true, false]) {
        final snapshot = await port.snapshot(nativeActivity: nativeActivity);
        expect(snapshot!.navigationId, 17);
        expect(snapshot.requestCount, 9);
        expect(snapshot.gameResources, isTrue);
        expect(snapshot.gameApi, isFalse);
      }
      expect(routes, [true, false]);
    },
  );

  test(
    'tolerates unavailable telemetry and rejects malformed snapshots',
    () async {
      expect(await port.snapshot(nativeActivity: false), isNull);
      for (final payload in <Object?>[
        null,
        123,
        {...state, 'navigationId': -1},
        {...state, 'requestCount': -1},
        {...state, 'gameApi': 'yes'},
        {...state, 'sanitizedUrl': 'example.invalid'},
      ]) {
        messenger.setMockMethodCallHandler(channel, (_) async => payload);
        expect(await port.snapshot(nativeActivity: true), isNull);
      }
    },
  );
}
