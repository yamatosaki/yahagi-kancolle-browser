import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_frame_rate_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('a new install defaults to automatic', () async {
    final store = SharedPreferencesGameFrameRateSettingsStore();
    expect(await store.loadMode(), GameFrameRateMode.automatic);
  });

  test('migrates the old boolean preference to an enum value', () async {
    for (final entry in <bool, GameFrameRateMode>{
      true: GameFrameRateMode.prefer60,
      false: GameFrameRateMode.stable30,
    }.entries) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'game.unlockFrameRate': entry.key,
      });
      final store = SharedPreferencesGameFrameRateSettingsStore();

      expect(await store.loadMode(), entry.value);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'game.frameRateMode.v2',
        ),
        entry.value.wireName,
      );
    }
  });

  test('migrates legacy string values', () async {
    for (final entry in <String, GameFrameRateMode>{
      'max60': GameFrameRateMode.prefer60,
      'followDisplay': GameFrameRateMode.prefer60,
      'off': GameFrameRateMode.stable30,
    }.entries) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'game.frameRateMode': entry.key,
      });
      final store = SharedPreferencesGameFrameRateSettingsStore();
      expect(await store.loadMode(), entry.value);
    }
  });

  test('new enum values round-trip and unknown values use automatic', () async {
    final store = SharedPreferencesGameFrameRateSettingsStore();
    for (final mode in GameFrameRateMode.values) {
      await store.saveMode(mode);
      expect(await store.loadMode(), mode);
    }

    SharedPreferences.setMockInitialValues(<String, Object>{
      'game.frameRateMode.v2': 'future-mode',
    });
    expect(
      await SharedPreferencesGameFrameRateSettingsStore().loadMode(),
      GameFrameRateMode.automatic,
    );
  });

  test(
    'controller applies startup mode and live changes to the port',
    () async {
      final store = MemoryGameFrameRateSettingsStore(
        GameFrameRateMode.prefer60,
      );
      final controller = await GameFrameRateSettingsController.load(store);
      final port = _RecordingFrameRatePort();
      addTearDown(controller.dispose);

      await controller.attachPort(port);
      await controller.setMode(GameFrameRateMode.stable30);

      expect(port.configuredModes, <GameFrameRateMode>[
        GameFrameRateMode.prefer60,
        GameFrameRateMode.stable30,
      ]);
      expect(controller.mode, GameFrameRateMode.stable30);
      expect(await store.loadMode(), GameFrameRateMode.stable30);
    },
  );

  test('port failure keeps the saved choice and marks support false', () async {
    final store = MemoryGameFrameRateSettingsStore();
    final controller = await GameFrameRateSettingsController.load(store);
    final port = _RecordingFrameRatePort(throwOnConfigure: true);
    addTearDown(controller.dispose);

    await controller.attachPort(port);
    await controller.setMode(GameFrameRateMode.prefer60);

    expect(controller.mode, GameFrameRateMode.prefer60);
    expect(await store.loadMode(), GameFrameRateMode.prefer60);
    expect(controller.supported, isFalse);
  });
}

final class _RecordingFrameRatePort implements GameFrameRatePort {
  _RecordingFrameRatePort({this.throwOnConfigure = false});

  final bool throwOnConfigure;
  final List<GameFrameRateMode> configuredModes = <GameFrameRateMode>[];

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> configure(GameFrameRateMode mode) async {
    if (throwOnConfigure) throw StateError('configure failed');
    configuredModes.add(mode);
  }
}
