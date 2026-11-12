import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_dialog_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_mission_picker.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_air_power_details.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_line_of_sight_details.dart';
import 'package:yahagi_kancolle_browser/src/game_state/fleet_metrics.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

const _channel = MethodChannel('app.yahagi.kancollebrowser/native_warning');
const _guard = Key('game-safety-input-guard');
const _metrics = FleetMetrics(
  shipCount: 1,
  totalLevel: 1,
  firepower: 0,
  torpedo: 0,
  antiAir: 0,
  antiSub: 0,
  lineOfSight: 99,
  formula33: [
    Formula33Result(
      mapModifier: 1,
      ship: 10,
      equipment: 2.5,
      admiralPenalty: 0,
      emptySlotBonus: 0,
    ),
    Formula33Result(
      mapModifier: 4,
      ship: 10,
      equipment: 10,
      admiralPenalty: 0,
      emptySlotBonus: 0,
    ),
  ],
  minimumCondition: 49,
  speedLabel: '高速',
  airPower: 40,
  airPowerMaximum: 41,
  airPowerWithoutProficiency: 24,
);
const _missions = <int, MasterMission>{
  1: MasterMission(
    id: 1,
    name: '练习航海',
    duration: Duration(minutes: 15),
    displayNumber: '01',
    mapAreaId: 1,
  ),
  9: MasterMission(
    id: 9,
    name: 'タンカー護衛任務',
    duration: Duration(hours: 4),
    displayNumber: '09',
    mapAreaId: 2,
  ),
};

void main() {
  testWidgets(
    'air-power details keep all values without opening a native dialog',
    (tester) async {
      final native = _NativeDialog();
      await _mount(
        tester,
        native: true,
        body: const Center(child: _MetricTrigger(airPower: true)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(native.shown, isEmpty);
      for (final text in ['制空详情', '最小', '40', '最大', '41', '不含熟练度加成', '24']) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'line-of-sight details keep all values without opening a native dialog',
    (tester) async {
      final native = _NativeDialog();
      await _mount(
        tester,
        native: true,
        body: const Center(child: _MetricTrigger(airPower: false)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(native.shown, isEmpty);
      for (final text in ['总索敌', '99', '33式', '× 1', '12.50', '× 4', '20.00']) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final result in ['mission-9', null]) {
    testWidgets(
      'native expedition ${result ?? 'dismissal'} retains area groups and returns only selection',
      (tester) async {
        final native = _NativeDialog();
        int? selected;
        await _mount(
          tester,
          native: true,
          body: ExpeditionMissionPicker(
            missions: _missions,
            missionIds: const [9, 1],
            selectedMissionId: 1,
            onSelected: (value) => selected = value,
          ),
        );
        await tester.tap(find.byKey(const Key('expedition-mission-picker')));
        await tester.pumpAndSettle();
        expect(native.shown, hasLength(1));
        final payload = native.shown.single;
        expect(payload['kind'], 'surfaceDialog');
        expect(payload['protectInputOnDismiss'], isFalse);
        expect(payload['selectedChoiceId'], 'mission-1');
        final choices = (payload['choices']! as List).cast<Map>();
        expect(choices.map((choice) => choice['id']), [
          'mission-1',
          'mission-9',
        ]);
        expect(choices.map((choice) => choice['label']), [
          '01 · 练习航海',
          '09 · タンカー護衛任務',
        ]);
        expect(choices.map((choice) => choice['group']), ['镇守府海域', '南西群岛海域']);
        expect(
          find.byKey(const Key('expedition-mission-picker-dialog')),
          findsNothing,
        );
        expect(selected, isNull);
        native.finish(result);
        await tester.pumpAndSettle();
        expect(selected, result == null ? isNull : 9);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final airPower in [false, true]) {
    final metric = airPower ? 'air power' : 'LOS';
    final title = airPower ? '制空详情' : '索敌详情';
    final closeKey = Key(
      airPower ? 'fleet-air-power-details-close' : 'fleet-los-details-close',
    );
    for (final close in ['button', 'outside', 'back', 'escape']) {
      testWidgets(
        'Flutter $metric $close leaves the next game touch available immediately',
        (tester) async {
          var gameTouches = 0;
          await _mount(
            tester,
            native: false,
            onGameTouch: () => gameTouches++,
            body: Center(child: _MetricTrigger(airPower: airPower)),
          );
          if (close == 'escape') {
            await tester.pump();
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          } else {
            await tester.tap(find.text('open'));
          }
          await tester.pumpAndSettle();
          expect(find.text(title), findsOneWidget);
          if (close == 'button') {
            await tester.tap(find.byKey(closeKey));
          } else if (close == 'outside') {
            await tester.tapAt(const Offset(4, 300));
          } else if (close == 'back') {
            await tester.binding.handlePopRoute();
          } else {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          }
          await tester.pump();
          expect(find.byKey(_guard), findsNothing);
          expect(find.text(title), findsNothing);
          expect(gameTouches, close == 'outside' ? 1 : 0);
          await tester.tapAt(const Offset(4, 300));
          expect(gameTouches, close == 'outside' ? 2 : 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('air power scroll position resets when the card is reopened', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 160);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _mount(
      tester,
      native: false,
      body: const Center(
        child: KeyedSubtree(
          key: PageStorageKey('fleet-pane'),
          child: _MetricTrigger(airPower: true),
        ),
      ),
    );
    final trigger = find.text('open');
    final scrollable = find.descendant(
      of: find.byKey(const Key('fleet-air-power-details-popover')),
      matching: find.byType(Scrollable),
    );
    ScrollPosition position() =>
        tester.state<ScrollableState>(scrollable).position;
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(position().maxScrollExtent, greaterThan(0));
    await tester.drag(scrollable, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(position().pixels, greaterThan(0));

    await tester.tapAt(const Offset(4, 80));
    await tester.pumpAndSettle();
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(position().pixels, 0);
  });

  testWidgets(
    'Flutter expedition selection and game input resume while a touch is held',
    (tester) async {
      int? selected;
      var gameTouches = 0;
      const gamePoint = Offset(4, 300);
      await _mount(
        tester,
        native: false,
        onGameTouch: () => gameTouches++,
        body: Center(
          child: SizedBox(
            width: 280,
            child: ExpeditionMissionPicker(
              missions: _missions,
              missionIds: const [1, 9],
              selectedMissionId: 1,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('expedition-mission-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expedition-area-2')));
      await tester.pumpAndSettle();
      final held = await tester.startGesture(
        tester.getCenter(find.text('选择远征')),
      );
      try {
        await tester.tap(find.byKey(const Key('expedition-mission-option-9')));
        await tester.pump();
        await tester.pump();
        expect(find.byKey(_guard), findsNothing);
        expect(find.text('选择远征'), findsNothing);
        expect(selected, 9);
        await tester.tapAt(gamePoint);
        expect(gameTouches, 1);
      } finally {
        await held.up();
      }
      expect(tester.takeException(), isNull);
    },
  );
}

class _MetricTrigger extends StatelessWidget {
  const _MetricTrigger({required this.airPower});

  final bool airPower;

  @override
  Widget build(BuildContext context) {
    Widget buildButton(VoidCallback toggle) => TextButton(
      autofocus: true,
      onPressed: toggle,
      child: const Text('open'),
    );
    return airPower
        ? FleetAirPowerDetails(metrics: _metrics, builder: buildButton)
        : FleetLineOfSightDetails(metrics: _metrics, builder: buildButton);
  }
}

Future<void> _mount(
  WidgetTester tester, {
  required bool native,
  required Widget body,
  VoidCallback? onGameTouch,
}) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: GameDialogPresentationScope(
      nativeActivity: native,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (onGameTouch != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onGameTouch,
              ),
            body,
          ],
        ),
      ),
    ),
  ),
);

class _NativeDialog {
  _NativeDialog() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'show') {
            shown.add(Map<String, Object?>.from(call.arguments as Map));
            return pending.future;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null);
    });
  }

  final shown = <Map<String, Object?>>[];
  final pending = Completer<Object?>();

  void finish(String? action) => pending.complete(
    action == null ? null : {'action': action, 'checked': false},
  );
}
