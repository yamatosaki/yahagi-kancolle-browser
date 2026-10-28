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
    'native air-power details retain all metrics without a game-covering route',
    (tester) async {
      final native = _NativeDialog();
      var completed = false;
      await _mount(
        tester,
        native: true,
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFleetAirPowerDetails(
              context,
              _metrics,
            ).then((_) => completed = true),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(native.shown, hasLength(1));
      final payload = native.shown.single;
      expect(payload['kind'], 'surfaceDialog');
      expect(payload['title'], '制空详情');
      expect(payload['rows'], ['最小：40', '最大：41', '不含熟练度加成：24']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(completed, isFalse);
      native.finish('close');
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native line-of-sight details retain total and every formula result',
    (tester) async {
      final native = _NativeDialog();
      await _mount(
        tester,
        native: true,
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFleetLineOfSightDetails(context, _metrics),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(native.shown, hasLength(1));
      expect(native.shown.single['rows'], [
        '总索敌：99',
        '33式 × 1：12.50',
        '33式 × 4：20.00',
      ]);
      expect(find.byType(AlertDialog), findsNothing);
      native.finish('close');
      await tester.pumpAndSettle();
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

  for (final close in ['button', 'outside', 'back']) {
    testWidgets(
      'Flutter LOS $close keeps game touches blocked until dismissal settles',
      (tester) async {
        var gameTouches = 0;
        var completed = false;
        await _mount(
          tester,
          native: false,
          onGameTouch: () => gameTouches++,
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showFleetLineOfSightDetails(
                  context,
                  _metrics,
                ).then((_) => completed = true),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        if (close == 'button') {
          await tester.tap(find.text('关闭'));
        } else if (close == 'outside') {
          await tester.tapAt(const Offset(3, 3));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pump();
        expect(find.byKey(_guard), findsOneWidget);
        expect(completed, isFalse);
        await tester.tapAt(const Offset(4, 300));
        expect(gameTouches, 0);
        await tester.pumpAndSettle();
        expect(completed, isTrue);
        await tester.tapAt(const Offset(4, 300));
        expect(gameTouches, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Flutter expedition selection reaches its owner only after touch protection',
    (tester) async {
      int? selected;
      await _mount(
        tester,
        native: false,
        body: ExpeditionMissionPicker(
          missions: _missions,
          missionIds: const [1, 9],
          selectedMissionId: 1,
          onSelected: (value) => selected = value,
        ),
      );
      await tester.tap(find.byKey(const Key('expedition-mission-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expedition-area-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('expedition-mission-option-9')));
      await tester.pump();
      expect(find.byKey(_guard), findsOneWidget);
      expect(selected, isNull);
      await tester.pumpAndSettle();
      expect(selected, 9);
      expect(tester.takeException(), isNull);
    },
  );
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
