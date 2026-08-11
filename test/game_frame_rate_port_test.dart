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
