import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/display_mode_store.dart';

void main() {
  testWidgets('显示模式开关：自动/横屏/竖屏', (tester) async {
    final controller = await DisplayModeController.load(
      MemoryDisplayModeStore(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DisplayModeSection(controller: controller)),
      ),
    );

    expect(find.text('显示模式'), findsOneWidget);
    expect(find.text('自动'), findsOneWidget);

    await tester.tap(find.text('自动'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('横屏').last);
    await tester.pumpAndSettle();
    expect(controller.displayMode, DisplayMode.landscape);

    await tester.tap(find.text('横屏').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('竖屏').last);
    await tester.pumpAndSettle();
    expect(controller.displayMode, DisplayMode.portrait);
  });
}
