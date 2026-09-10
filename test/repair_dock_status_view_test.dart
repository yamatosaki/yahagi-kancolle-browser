import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/fleet/operation_status_views.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

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
}

Future<void> _pumpRepairDock(
  WidgetTester tester, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1024, 487);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final completionTime = DateTime.now().add(const Duration(hours: 2));
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
        completionTime: completionTime,
        fuelCost: 8,
        steelCost: 16,
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'RepairDockTestFont'),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(1024, 487),
        ).copyWith(textScaler: textScaler),
        child: Scaffold(body: RepairDockStatusView(state: state)),
      ),
    ),
  );
}

_HpMeasurements _measureHp(WidgetTester tester) {
  final hpText = find.text('HP 100/120');
  expect(hpText, findsOneWidget);
  expect(tester.widget<Text>(hpText).softWrap, isFalse);
  expect(
    find.ancestor(of: hpText, matching: find.byType(FittedBox)),
    findsOneWidget,
  );

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
    naturalWidth: textRender.size.width,
  );
}

void _expectHpInsideSlot(_HpMeasurements measurements) {
  expect(
    measurements.paintedText.left,
    greaterThanOrEqualTo(measurements.hpSlot.left),
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
    required this.naturalWidth,
  });

  final Rect hpSlot;
  final Rect paintedText;
  final double naturalWidth;
}
