import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_progress.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_status_views.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/performance/second_tick_scope.dart';

void main() {
  setUpAll(() async {
    final fontBytes = await File(
      'assets/fonts/HarmonyOS_Sans_SC.ttf',
    ).readAsBytes();
    await (FontLoader(
      'RepairDockTestFont',
    )..addFont(Future<ByteData>.value(ByteData.sublistView(fontBytes)))).load();
  });

  testWidgets('three-digit repair HP uses its natural width by default', (
    tester,
  ) async {
    await _pumpRepairDock(tester);

    final measurements = _measureHp(tester);
    expect(measurements.hpSlot.width, 102);
    expect(
      measurements.paintedText.width,
      closeTo(measurements.naturalWidth, 0.01),
    );
    _expectHpInsideSlot(measurements);
  });

  testWidgets('three-digit repair HP scales down and stays visible at 1.3x', (
    tester,
  ) async {
    await _pumpRepairDock(tester, textScaler: const TextScaler.linear(1.3));

    final measurements = _measureHp(tester);
    expect(measurements.hpSlot.width, 102);
    expect(measurements.naturalWidth, greaterThan(measurements.hpSlot.width));
    expect(measurements.paintedText.width, lessThan(measurements.naturalWidth));
    _expectHpInsideSlot(measurements);
  });

  testWidgets('three-digit repair HP leaves usable progress width on phone', (
    tester,
  ) async {
    const phoneSize = Size(390, 844);
    await _pumpRepairDock(
      tester,
      size: phoneSize,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(tester.takeException(), isNull);
    final measurements = _measureHp(tester);
    final minimumUsableProgressWidth =
        phoneSize.width -
        28 - // RepairDockStatusView list padding.
        24 - // Operation card padding.
        102 - // HP slot.
        20 - // Gap between HP and progress.
        16; // Allow stable layout slack.
    expect(
      measurements.progress.width,
      greaterThanOrEqualTo(minimumUsableProgressWidth),
    );
    _expectHpInsideSlot(measurements);
  });

  testWidgets('portrait repair card stays within a narrowed workspace', (
    tester,
  ) async {
    const workspaceWidth = 330.0;
    await _pumpRepairDock(
      tester,
      size: const Size(390, 844),
      contentWidth: workspaceWidth,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const Key('repair-dock-row-1'))).right,
      lessThanOrEqualTo(workspaceWidth),
    );
  });

  for (final (width, stacked, day, expectedTime) in [
    (1024.0, false, 18, '14:40'),
    (580.0, true, 19, '11/19 14:40'),
    (330.0, true, 19, '11/19 14:40'),
  ]) {
    testWidgets('repair cost and expected finish stay on one line at $width', (
      tester,
    ) async {
      await _pumpRepairDock(
        tester,
        contentWidth: width,
        textScaler: TextScaler.linear(width < 600 ? 1.3 : 1),
        now: DateTime(2026, 11, 18, 12),
        completionTime: DateTime(2026, 11, day, 14, 40),
      );

      final cost = find.text('消耗');
      final steel = find.byKey(const Key('repair-resource-1-steel'));
      final completion = find.text('预计完成时间 $expectedTime');
      final progress = tester.getRect(
        find.byKey(const Key('repair-progress-1')),
      );
      final hp = tester.getRect(find.byKey(const Key('repair-hp-1')));
      expect(completion, findsOneWidget);
      expect(tester.widget<Text>(cost).style?.color, Colors.white);
      expect(
        tester.getCenter(cost).dy,
        closeTo(tester.getCenter(steel).dy, .1),
      );
      expect(
        tester.getCenter(completion).dy,
        closeTo(tester.getCenter(steel).dy, .1),
      );
      expect(
        tester.getTopLeft(completion).dx,
        greaterThan(tester.getCenter(steel).dx),
      );
      expect(
        tester.getTopLeft(cost).dx,
        closeTo(stacked ? hp.left : progress.left, .1),
      );
      expect(tester.getTopLeft(cost).dy, greaterThan(progress.bottom));
      expect(find.byType(OperationCountdownText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (size, width, scale) in [
    (const Size(320, 844), 320.0, 2.0),
    (const Size(1200, 655), 938.0, 1.0),
  ]) {
    testWidgets('repair footer fits long English completion text at $width', (
      tester,
    ) async {
      await _pumpRepairDock(
        tester,
        size: size,
        contentWidth: width,
        locale: const Locale('en'),
        textScaler: TextScaler.linear(scale),
        now: DateTime(2026, 11, 18, 12),
        completionTime: DateTime(2027, 1, 1, 14, 40),
      );

      final progress = tester.getRect(
        find.byKey(const Key('repair-progress-1')),
      );
      final hp = tester.getRect(find.byKey(const Key('repair-hp-1')));
      final completion = find.text(
        'Estimated completion time 2027/01/01 14:40',
      );
      final naturalWidth = tester
          .renderObject<RenderParagraph>(completion)
          .size
          .width;
      final completionRect = tester.getRect(completion);
      final fontSize = tester.widget<Text>(completion).style!.fontSize!;
      final paintedFontSize =
          fontSize * scale * completionRect.width / naturalWidth;
      expect(paintedFontSize, greaterThanOrEqualTo(8));
      expect(completionRect.top, greaterThan(progress.bottom));
      expect(tester.getTopLeft(find.text('Cost')).dx, closeTo(hp.left, .1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('portrait construction card stays within a narrowed workspace', (
    tester,
  ) async {
    const size = Size(390, 844);
    const workspaceWidth = 330.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final completionTime = DateTime.now().add(const Duration(hours: 2));
    final state = GameState(
      masterShips: const <int, MasterShip>{
        101: MasterShip(
          id: 101,
          name: '超长测试建造舰娘名称',
          shipTypeId: 2,
          buildTimeMinutes: 120,
        ),
      },
      constructionDocks: <ConstructionDock>[
        ConstructionDock(
          id: 1,
          state: 2,
          createdShipMasterId: 101,
          completionTime: completionTime,
          fuel: 30,
          ammunition: 30,
          steel: 30,
          bauxite: 30,
          developmentMaterial: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'RepairDockTestFont'),
        home: MediaQuery(
          data: const MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(1.3),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: workspaceWidth,
                child: ConstructionDockStatusView(state: state),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const Key('construction-dock-row-1'))).right,
      lessThanOrEqualTo(workspaceWidth),
    );
  });
}

Future<void> _pumpRepairDock(
  WidgetTester tester, {
  Size size = const Size(1024, 487),
  double? contentWidth,
  Locale locale = const Locale('zh'),
  TextScaler textScaler = TextScaler.noScaling,
  DateTime? now,
  DateTime? completionTime,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final currentTime = now ?? DateTime.now();
  final state = GameState(
    masterShips: const <int, MasterShip>{
      101: MasterShip(id: 101, name: '朝霜改二補', shipTypeId: 2),
    },
    ships: const <int, OwnedShip>{
      1001: OwnedShip(
        id: 1001,
        masterId: 101,
        level: 97,
        currentHp: 100,
        maxHp: 120,
        repairDurationMilliseconds: 7200000,
      ),
    },
    repairDocks: <RepairDock>[
      RepairDock(
        id: 1,
        state: 1,
        shipId: 1001,
        completionTime:
            completionTime ?? currentTime.add(const Duration(hours: 2)),
        fuelCost: 8,
        steelCost: 16,
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'RepairDockTestFont'),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: textScaler),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: contentWidth,
              child: SecondTickScope(
                now: () => currentTime,
                child: RepairDockStatusView(state: state),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

_HpMeasurements _measureHp(WidgetTester tester) {
  final hpText = find.text('HP 100/120');
  expect(hpText, findsOneWidget);
  expect(tester.widget<Text>(hpText).softWrap, isFalse);
  final fittedBoxFinder = find.ancestor(
    of: hpText,
    matching: find.byType(FittedBox),
  );
  expect(fittedBoxFinder, findsOneWidget);
  final fittedBox = tester.widget<FittedBox>(fittedBoxFinder);
  expect(fittedBox.fit, BoxFit.scaleDown);
  expect(fittedBox.alignment, Alignment.centerLeft);

  final textRender = tester.renderObject<RenderParagraph>(hpText);

  final hpSlot = tester.getRect(find.byKey(const Key('repair-hp-1')));
  final paintedText = MatrixUtils.transformRect(
    textRender.getTransformTo(null),
    Offset.zero & textRender.size,
  );
  final progress = tester.getRect(find.byKey(const Key('repair-progress-1')));
  expect(progress.left - hpSlot.right, greaterThanOrEqualTo(16));

  return _HpMeasurements(
    hpSlot: hpSlot,
    paintedText: paintedText,
    progress: progress,
    naturalWidth: textRender.size.width,
  );
}

void _expectHpInsideSlot(_HpMeasurements measurements) {
  expect(
    measurements.paintedText.left,
    closeTo(measurements.hpSlot.left, 0.01),
  );
  expect(
    measurements.paintedText.right,
    lessThanOrEqualTo(measurements.hpSlot.right),
  );
}

class _HpMeasurements {
  const _HpMeasurements({
    required this.hpSlot,
    required this.paintedText,
    required this.progress,
    required this.naturalWidth,
  });

  final Rect hpSlot;
  final Rect paintedText;
  final Rect progress;
  final double naturalWidth;
}
