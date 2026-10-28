import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_rate_port.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_frame_rate_runtime_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/game_frame_rate');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'configuration retries while the platform WebView is mounting',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'configure');
        calls += 1;
        if (calls < 3) {
          throw PlatformException(code: 'webview_not_found');
        }
        expect(call.arguments, <String, Object?>{'mode': 'stable30'});
        return null;
      });

      await const MethodChannelGameFrameRatePort(
        channel: channel,
      ).configure(GameFrameRateMode.stable30);

      expect(calls, 3);
    },
  );

  test(
    'configuration waits for a WebView mounting after the old retry budget',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls += 1;
        if (calls < 14) throw PlatformException(code: 'webview_not_found');
        return null;
      });

      await const MethodChannelGameFrameRatePort(
        channel: channel,
      ).configure(GameFrameRateMode.highRefresh);

      expect(calls, 14);
    },
  );

  test('configuration fails after sixty missing WebView responses', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls += 1;
      throw PlatformException(code: 'webview_not_found');
    });

    await expectLater(
      const MethodChannelGameFrameRatePort(
        channel: channel,
      ).configure(GameFrameRateMode.automatic),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'webview_not_found',
        ),
      ),
    );
    expect(calls, 60);
  });

  for (final code in <String>[
    'multiple_webviews',
    'frame_rate_configuration_failed',
    'frame_rate_unsupported',
  ]) {
    test('configuration does not retry $code', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls += 1;
        throw PlatformException(code: code);
      });

      await expectLater(
        const MethodChannelGameFrameRatePort(
          channel: channel,
        ).configure(GameFrameRateMode.stable60),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', code)),
      );
      expect(calls, 1);
    });
  }

  test('inactive configuration never calls native code', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls += 1;
      return null;
    });

    await expectLater(
      MethodChannelGameFrameRatePort(
        channel: channel,
        isActive: () => false,
      ).configure(GameFrameRateMode.automatic),
      throwsA(isA<GameFrameRateConfigurationCancelledException>()),
    );
    expect(calls, 0);
  });

  test('cancellation rejects a late native success', () async {
    var active = true;
    final dispatched = Completer<void>();
    final response = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      dispatched.complete();
      await response.future;
      return null;
    });
    final pending = MethodChannelGameFrameRatePort(
      channel: channel,
      isActive: () => active,
    ).configure(GameFrameRateMode.automatic);
    final rejected = expectLater(
      pending,
      throwsA(isA<GameFrameRateConfigurationCancelledException>()),
    );
    await dispatched.future;
    active = false;
    response.complete();
    await rejected;
  });

  test(
    'cancellation releases a native configuration that never responds',
    () async {
      var calls = 0;
      final dispatched = Completer<void>();
      final reply = Completer<void>();
      final cancelled = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls += 1;
        dispatched.complete();
        await reply.future;
        return null;
      });
      final pending = MethodChannelGameFrameRatePort(
        channel: channel,
        cancelled: cancelled.future,
      ).configure(GameFrameRateMode.automatic);
      final rejected = expectLater(
        pending,
        throwsA(isA<GameFrameRateConfigurationCancelledException>()),
      );
      await dispatched.future;
      cancelled.complete();
      await rejected;
      expect(calls, 1);

      reply.completeError(PlatformException(code: 'webview_not_found'));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
    },
  );

  test('an already cancelled configuration never calls native code', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls += 1;
      return null;
    });

    await expectLater(
      MethodChannelGameFrameRatePort(
        channel: channel,
        cancelled: Future<void>.value(),
      ).configure(GameFrameRateMode.automatic),
      throwsA(isA<GameFrameRateConfigurationCancelledException>()),
    );
    expect(calls, 0);
  });

  test('cancellation rejects a late native failure without retrying', () async {
    var active = true;
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls += 1;
      active = false;
      throw PlatformException(code: 'webview_not_found');
    });

    await expectLater(
      MethodChannelGameFrameRatePort(
        channel: channel,
        isActive: () => active,
      ).configure(GameFrameRateMode.automatic),
      throwsA(isA<GameFrameRateConfigurationCancelledException>()),
    );
    expect(calls, 1);
  });

  test(
    'cancellation during retry delay prevents another native attempt',
    () async {
      var active = true;
      var calls = 0;
      final dispatched = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls += 1;
        if (!dispatched.isCompleted) dispatched.complete();
        throw PlatformException(code: 'webview_not_found');
      });
      final pending = MethodChannelGameFrameRatePort(
        channel: channel,
        isActive: () => active,
      ).configure(GameFrameRateMode.automatic);
      final rejected = expectLater(
        pending,
        throwsA(isA<GameFrameRateConfigurationCancelledException>()),
      );
      await dispatched.future;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      active = false;
      await rejected;
      expect(calls, 1);
    },
  );

  test(
    'unsupported platform port reports explicit unsupported configuration',
    () async {
      await expectLater(
        const UnsupportedGameFrameRatePort().configure(
          GameFrameRateMode.automatic,
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'frame_rate_unsupported',
          ),
        ),
      );
    },
  );

  test(
    'runtime control is sent through the frame-level native bridge',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'measuredFps') return 57.5;
        return null;
      });
      const port = MethodChannelGameFrameRateRuntimePort(channel: channel);

      await port.apply(GameFrameRateTarget.fps30);
      final fps = await port.measuredFps();

      expect(calls.first.method, 'applyTarget');
      expect(calls.first.arguments, <String, Object?>{'target': 'fps30'});
      expect(calls.last.method, 'measuredFps');
      expect(fps, 57.5);
    },
  );
}
