import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/fleet_display_sample.dart';
import 'package:yahagi_kancolle_browser/src/settings/fleet_display_options.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ship_status_capsule.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_repair_status.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_status_visuals.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_dashboard_content.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';

class _SampleStore extends GameStateStore {
  @override
  Future<GameState> load() async => demoState();
}

class _MechanismStore extends GameStateStore {
  @override
  Future<GameState> load() async => GameState.empty.copyWith(
    hasPortData: true,
    masterShips: {
      141: const MasterShip(
        id: 141,
        name: '五十鈴改二',
        shipTypeId: 3,
        maxFuel: 25,
        maxAmmo: 30,
      ),
    },
    ships: {
      1: const OwnedShip(
        id: 1,
        masterId: 141,
        level: 80,
        currentHp: 44,
        maxHp: 44,
        condition: 49,
        currentFuel: 25,
        currentAmmo: 30,
      ),
    },
    fleets: const [
      Fleet(id: 1, name: '第一舰队', shipIds: [1]),
    ],
  );
}

void main() {
  for (final showBars in [true, false]) {
    testWidgets(
      'hp and fuel keep their slots across avatar, width and data changes, bars=$showBars',
      (tester) async {
        final initialState = demoState();
        final refreshedState = initialState.copyWith(
          ships: {
            ...initialState.ships,
            1: const OwnedShip(
              id: 1,
              masterId: 1,
              level: 85,
              currentHp: 15,
              maxHp: 49,
              condition: 85,
              currentFuel: 3,
              currentAmmo: 7,
            ),
          },
        );
        Element? original;
        var refresh = false;
        for (final layout in [
          (width: 280.0, portrait: true),
          (width: 280.0, portrait: false),
          (width: 310.0, portrait: false),
          (width: 311.0, portrait: false),
          (width: 360.0, portrait: false),
          (width: 560.0, portrait: false),
          (width: 280.0, portrait: false),
          (width: 280.0, portrait: true),
        ]) {
          final state = refresh ? refreshedState : initialState;
          final fields = defaultFields.difference({
            if (!layout.portrait) 'portrait',
            if (!showBars) 'bars',
          });
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: layout.width,
                    child: FleetShipStatusCapsule(
                      state: state,
                      ship: state.ships[1]!,
                      visible: fields,
                      damagePulseFilter: DamagePulseFilter.off,
                      moraleSparkleMode: MoraleSparkleMode.off,
                    ),
                  ),
                ),
              ),
            ),
          );
          Rect meterRect(String field) => tester.getRect(
            find.ancestor(
              of: find.byKey(Key('fleet-focus-$field-value-1')),
              matching: find.byType(CompactStatusMeter),
            ),
          );
          final hp = meterRect('hp');
          final fuel = meterRect('fuel');
          final ammo = meterRect('ammo');
          expect(hp.left, lessThan(fuel.left), reason: '$layout');
          expect(hp.top, greaterThan(fuel.top), reason: '$layout');
          expect(hp.top, closeTo(ammo.top, .01), reason: '$layout');
          expect(fuel.left, closeTo(ammo.left, .01), reason: '$layout');
          for (final field in ['hp', 'fuel', 'ammo']) {
            final expected = switch (field) {
              'hp' => refresh ? '15/49' : '49/49',
              'fuel' => refresh ? '3/40' : '40/40',
              _ => refresh ? '7/45' : '45/45',
            };
            expect(
              tester
                  .widget<Text>(find.byKey(Key('fleet-focus-$field-value-1')))
                  .data,
              expected,
            );
          }
          final element = tester.element(find.byType(FleetShipStatusCapsule));
          original ??= element;
          expect(element, same(original));
          expect(tester.takeException(), isNull, reason: '$layout');
          refresh = !refresh;
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('right aligned meters keep the same icon gap as fuel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (var i = 0; i < 3; i++)
                SizedBox(
                  width: 120,
                  child: CompactStatusMeter(
                    height: 16,
                    showTrack: false,
                    alignRight: i != 0,
                    icon: SizedBox(
                      key: Key('gap-icon-$i'),
                      width: 10,
                      height: 10,
                    ),
                    value: ['20/25', '22/24', '24/30'][i],
                    valueKey: Key('gap-value-$i'),
                    ratio: 1,
                    valueColor: Colors.white,
                    barColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final gaps = [
      for (var i = 0; i < 3; i++)
        tester.getRect(find.byKey(Key('gap-value-$i'))).left -
            tester.getRect(find.byKey(Key('gap-icon-$i'))).right,
    ];
    expect(gaps[1], closeTo(gaps[0], 0.1));
    expect(gaps[2], closeTo(gaps[0], 0.1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('text-only name, morale and repair status share one row', (
    tester,
  ) async {
    final state = demoState();
    for (final width in [280.0, 360.0, 560.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: FleetShipStatusCapsule(
                  state: state,
                  ship: state.ships[3]!,
                  repairStatus: ShipRepairStatus.anchorage,
                  visible: defaultFields.difference({'portrait'}),
                ),
              ),
            ),
          ),
        ),
      );
      final name = tester.getRect(find.byKey(const Key('text-name-3')));
      final morale = tester.getRect(find.byKey(const Key('text-morale-3')));
      final status = tester.getRect(find.byKey(const Key('text-status-3')));
      final face = tester.getRect(
        find.byKey(const Key('fleet-fatigue-face-27')),
      );
      expect(face.left, greaterThanOrEqualTo(morale.left));
      expect(face.right, lessThanOrEqualTo(morale.right));
      expect(face.center.dy, closeTo(name.center.dy, 0.1));
      expect(face.center.dy, closeTo(status.center.dy, 0.1));
      expect(morale.left, greaterThan(name.right));
      expect(status.left, greaterThan(morale.right));
      expect(morale.center.dy, closeTo(name.center.dy, 1));
      expect(status.center.dy, closeTo(name.center.dy, 1));
      expect(
        tester.widget<ShipHpFrame>(find.byType(ShipHpFrame)).filter,
        DamagePulseFilter.off,
      );
      expect(
        tester.widget<ShipMoraleMark>(find.byType(ShipMoraleMark)).sparkleMode,
        MoraleSparkleMode.off,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'saved settings preserve mechanisms and enforce a maximum of five metrics',
    () {
      expect(defaultFields, contains('mechanisms'));
      expect(compactFields, contains('mechanisms'));
      expect(normalizeDisplayFields({'asw', 'night'}), {'mechanisms'});
      expect(normalizeDisplayFields({'mechanisms', 'hp'}), {
        'mechanisms',
        'hp',
      });
      expect(
        allFields.intersection({'asw', 'aaci', 'rocket', 'night', 'special'}),
        isEmpty,
      );
      final restored = normalizeDisplayFields(allFields);
      expect(restored.intersection(summaryFields).length, 5);
      expect(normalizeDisplayFields({}), isEmpty);
    },
  );
  testWidgets('all fleet layouts use the combined mechanism switch', (
    tester,
  ) async {
    final controller = GameStateController(gameStateStore: _MechanismStore());
    await controller.initialize();
    addTearDown(controller.dispose);
    for (final layout in [
      (
        name: 'ordinary',
        width: 560.0,
        columns: 1,
        style: PanelStyle.card,
        fields: defaultFields,
      ),
      (
        name: 'compact',
        width: 320.0,
        columns: 1,
        style: PanelStyle.card,
        fields: compactFields,
      ),
      (
        name: 'HD',
        width: 760.0,
        columns: 2,
        style: PanelStyle.card,
        fields: defaultFields,
      ),
      (
        name: 'minimal',
        width: 360.0,
        columns: 1,
        style: PanelStyle.flat,
        fields: defaultFields,
      ),
    ]) {
      for (final enabled in [true, false]) {
        final visible = {
          ...layout.fields.difference({
            'portrait',
            'mechanisms',
            'asw',
            'aaci',
            'rocket',
            'night',
            'special',
          }),
          if (enabled) 'mechanisms',
        };
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: layout.width,
                    child: PanelStyleScope(
                      style: layout.style,
                      child: HdModuleColumns(
                        columns: layout.columns,
                        child: FleetSummaryCard(
                          controller: controller,
                          collapsed: false,
                          onToggleCollapse: () {},
                          onOpenFleet: (_) {},
                          visible: visible,
                          damagePulseFilter: DamagePulseFilter.off,
                          moraleSparkleMode: MoraleSparkleMode.off,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final mechanism = find.byKey(
          Key(
            layout.style == PanelStyle.flat
                ? 'minimal-mechanism-1-openingAsw'
                : 'fleet-focus-mechanism-1',
          ),
        );
        expect(
          mechanism,
          enabled ? findsOneWidget : findsNothing,
          reason: '${layout.name}, mechanisms=$enabled',
        );
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('hidden fields return width to name and all combinations fit', (
    tester,
  ) async {
    final controller = GameStateController(gameStateStore: _SampleStore());
    await controller.initialize();
    addTearDown(controller.dispose);
    Future<void> show(Set<String> fields, double width) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: FleetSummaryCard(
                  controller: controller,
                  visible: fields,
                  collapsed: false,
                  onToggleCollapse: () {},
                  onOpenFleet: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }

    await show(compactFields, 280);
    final hpRight = tester
        .getRect(find.byKey(const Key('fleet-focus-hp-value-1')))
        .right;
    final hpRect = tester.getRect(
      find.byKey(const Key('fleet-focus-hp-value-1')),
    );
    final fuelRect = tester.getRect(
      find.byKey(const Key('fleet-focus-fuel-value-1')),
    );
    final ammoRect = tester.getRect(
      find.byKey(const Key('fleet-focus-ammo-value-1')),
    );
    expect(hpRect.left, lessThan(fuelRect.left));
    expect(hpRect.center.dy, closeTo(ammoRect.center.dy, .1));
    expect(fuelRect.bottom, lessThan(hpRect.top));
    final hpMeter = find.ancestor(
      of: find.byKey(const Key('fleet-focus-hp-value-1')),
      matching: find.byType(CompactStatusMeter),
    );
    expect(hpRight, closeTo(tester.getRect(hpMeter).right, 0.1));
    final ammoMeter = find.ancestor(
      of: find.byKey(const Key('fleet-focus-ammo-value-1')),
      matching: find.byType(CompactStatusMeter),
    );
    expect(ammoRect.right, closeTo(tester.getRect(ammoMeter).right, .1));
    await show(compactFields, 360);
    final initial = tester
        .getSize(find.byKey(const Key('text-identity-1')))
        .width;
    await show(compactFields.difference({'fuel'}), 360);
    expect(
      tester.getSize(find.byKey(const Key('text-identity-1'))).width,
      greaterThan(initial + 50),
    );
    for (final width in [280.0, 360.0, 560.0]) {
      for (var mask = 0; mask < 32; mask++) {
        final fields = {...defaultFields};
        final keys = ['portrait', 'fuel', 'ammo', 'bars', 'hp'];
        for (var bit = 0; bit < 5; bit++) {
          if ((mask & (1 << bit)) != 0) fields.remove(keys[bit]);
        }
        await show(fields, width);
        expect(
          find.byKey(const Key('fleet-focus-hp-value-1')),
          fields.contains('hp') ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull, reason: '$width $mask');
      }
    }
    await show({'speed', 'firepower', 'torpedo', 'anti-air', 'anti-sub'}, 360);
    final fiveWidth = tester
        .getSize(find.byKey(const Key('fleet-summary-metric-speed')))
        .width;
    expect(
      find.byKey(const Key('fleet-summary-metric-firepower')),
      findsOneWidget,
    );
    await show({'speed', 'firepower'}, 360);
    expect(
      tester.getSize(find.byKey(const Key('fleet-summary-metric-speed'))).width,
      greaterThan(fiveWidth * 2),
    );
    await show({}, 360);
    expect(find.byKey(const Key('fleet-summary-metrics')), findsNothing);
    expect(find.byKey(const Key('fleet-focus-hp-value-1')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
