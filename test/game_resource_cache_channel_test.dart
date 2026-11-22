import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_resource_cache_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/game_resource_cache');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'status keeps manifest readiness separate from the proxy pause',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'status');
        return <String, Object?>{
          'mode': 'full',
          'manifestReady': true,
          'preloadBlockedByProxy': true,
        };
      });
      const port = MethodChannelGameResourceCachePort(channel);

      final status = await port.status();

      expect(status.manifestReady, isTrue);
      expect(status.preloadBlockedByProxy, isTrue);
      expect(status.waitingForWifi, isFalse);
    },
  );

  test('large manifests are transferred in bounded batches', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    const port = MethodChannelGameResourceCachePort(channel);
    final urls = List<String>.generate(
      1201,
      (index) => 'https://example.test/resource/$index.png',
    );

    final result = await port.setManifest(
      GameResourceManifest(
        profile: 'full',
        urls: urls,
        targetBytes: 123456789,
        expectedLengths: List<int>.generate(1201, (index) => index + 1),
      ),
    );

    expect(result, isTrue);
    expect(calls.map((call) => call.method), <String>[
      'beginManifest',
      'appendManifest',
      'appendManifest',
      'appendManifest',
      'commitManifest',
    ]);
    final batches = calls
        .where((call) => call.method == 'appendManifest')
        .map(
          (call) =>
              (call.arguments as Map<Object?, Object?>)['urls']!
                  as List<Object?>,
        )
        .toList();
    expect(batches.map((batch) => batch.length), <int>[500, 500, 201]);
    expect(batches.expand((batch) => batch), urls);
    final lengthBatches = calls
        .where((call) => call.method == 'appendManifest')
        .map(
          (call) =>
              (call.arguments as Map<Object?, Object?>)['expectedLengths']!
                  as List<Object?>,
        )
        .toList();
    expect(lengthBatches.map((batch) => batch.length), <int>[500, 500, 201]);
    expect(lengthBatches.expand((batch) => batch), <int>[
      for (var index = 1; index <= 1201; index++) index,
    ]);
    final transactionIds = calls
        .map(
          (call) =>
              (call.arguments as Map<Object?, Object?>?)?['transactionId'],
        )
        .whereType<String>()
        .toSet();
    expect(transactionIds, hasLength(1));
  });

  test('failed manifest transfer aborts its native transaction', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method != 'appendManifest';
    });
    const port = MethodChannelGameResourceCachePort(channel);

    final result = await port.setManifest(
      const GameResourceManifest(
        profile: 'full',
        urls: <String>['https://example.test/resource.png'],
        targetBytes: 1,
      ),
    );

    expect(result, isFalse);
    expect(calls.map((call) => call.method), <String>[
      'beginManifest',
      'appendManifest',
      'abortManifest',
    ]);
  });

  test('superseded manifest aborts between transfer batches', () async {
    final calls = <MethodCall>[];
    var current = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'appendManifest') current = false;
      return true;
    });
    const port = MethodChannelGameResourceCachePort(channel);

    final result = await port.setManifest(
      GameResourceManifest(
        profile: 'full',
        urls: List<String>.generate(
          1000,
          (index) => 'https://example.test/$index.png',
        ),
        targetBytes: 1000,
      ),
      shouldContinue: () => current,
    );

    expect(result, isFalse);
    expect(calls.map((call) => call.method), <String>[
      'beginManifest',
      'appendManifest',
      'abortManifest',
    ]);
  });
}
