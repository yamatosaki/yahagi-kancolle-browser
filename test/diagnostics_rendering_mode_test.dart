import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_browser_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/capture/capture_mode_store.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_controller.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/diagnostics_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode.dart';
import 'package:yahagi_kancolle_browser/src/settings/game_rendering_mode_controller.dart';

void main() {
  testWidgets('diagnostics reports the active rendering pipeline', (
    tester,
  ) async {
    final captureModeController = await CaptureModeController.load(
      _CaptureStore(),
    );
    final renderingController = await GameRenderingModeController.load(
      MemoryGameRenderingModeStore(GameRenderingMode.canvasCompatibility),
    );
    addTearDown(captureModeController.dispose);
    addTearDown(renderingController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DiagnosticsSection(
              browserController: GameBrowserController(),
              captureModeController: captureModeController,
              gameCaptureController: GameCaptureController(),
              prototypeStatusController: PrototypeStatusController(),
              gameRenderingModeController: renderingController,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Hybrid Composition'), findsOneWidget);
    expect(find.textContaining('Canvas'), findsOneWidget);
    expect(find.textContaining('Backdrop blur: off'), findsOneWidget);
  });
}

final class _CaptureStore implements CaptureModeStore {
  @override
  Future<CaptureMode?> read() async => CaptureMode.game;

  @override
  Future<void> write(CaptureMode mode) async {}
}
