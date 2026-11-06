import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_ship_status_capsule.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/layout/hd_dashboard_content.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/fleet_display_options.dart';

import 'fixtures/fleet_display_sample.dart';

const _cardKey = Key('fixed-layout-fleet-card');

void main() {
  for (final dpr in [1.0, 2.75]) {
    testWidgets(
      'real fleet card preserves HP/fuel slots through modes and captures, DPR=$dpr',
      (tester) async {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(1000 * dpr, 1600 * dpr);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final controller = GameStateController(initialState: demoState());
        await controller.initialize();
        addTearDown(controller.dispose);

        State<FleetSummaryCard>? originalState;
        var stage = 0;
        var sequence = 0;
        Future<void> accept(
          String path,
          Object data, {
          bool decoded = false,
          Map<String, Object?> requestParams = const {},
        }) async {
          final envelope = <String, Object?>{'api_result': 1, 'api_data': data};
          controller.accept(
            CapturedApiEvent(
              path: '/kcsapi/$path',
              responseBody: jsonEncode(envelope),
              decodedEnvelope: decoded ? envelope : null,
              source: CaptureSource.xhr,
              capturedAt: DateTime.utc(2026, 11, 4, 12, 0, ++sequence),
              sequence: sequence,
              requestParams: requestParams,
            ),
          );
          await controller.idle;
          await tester.pump();
          expect(controller.lastError, isNull);
        }

        void verify(_Layout layout) {
          originalState ??= tester.state(find.byKey(_cardKey));
          expect(tester.state(find.byKey(_cardKey)), same(originalState));
          _expectFixedSlots(tester, layout, stage);
          expect(tester.takeException(), isNull, reason: layout.label);
        }

        Future<void> show(_Layout layout) async {
          tester.view.physicalSize = Size(
            layout.width * dpr,
            (layout.width >= 600 ? 480 : 900) * dpr,
          );
          await tester.pumpWidget(_host(controller, layout));
          await tester.pump();
          verify(layout);
        }

        final layouts = [
          _Layout('ordinary narrow', 280, 1, PanelStyle.card, defaultFields),
          _Layout(
            'ordinary wide text',
            760,
            1,
            PanelStyle.card,
            defaultFields.difference({'portrait'}),
          ),
          _Layout('compact split', 320, 1, PanelStyle.card, compactFields),
          _Layout(
            'all fields split',
            760,
            2,
            PanelStyle.card,
            allFields.difference({'portrait'}),
          ),
          _Layout('minimal narrow', 280, 1, PanelStyle.flat, defaultFields),
          _Layout('minimal split', 760, 3, PanelStyle.flat, compactFields),
          _Layout(
            'ordinary three columns',
            760,
            3,
            PanelStyle.card,
            defaultFields,
          ),
          _Layout(
            'portrait without bars or ammo',
            320,
            1,
            PanelStyle.card,
            defaultFields.difference({'bars', 'ammo'}),
          ),
          _Layout(
            'compact without ammo',
            320,
            1,
            PanelStyle.card,
            compactFields.difference({'ammo'}),
          ),
          _Layout(
            'minimal without ammo',
            320,
            1,
            PanelStyle.flat,
            defaultFields.difference({'portrait', 'ammo'}),
          ),
          _Layout(
            'compact restored narrow',
            280,
            1,
            PanelStyle.card,
            compactFields,
          ),
          _Layout(
            'ordinary restored wide',
            760,
            1,
            PanelStyle.card,
            defaultFields,
          ),
        ];

        for (var index = 0; index < layouts.length; index++) {
          final layout = layouts[index];
          await show(layout);
          if (index == 2) {
            // Exercise the body decoder and change digit count as well as values.
            await accept('api_get_member/ship2', [
              {
                'api_id': 1,
                'api_ship_id': 1,
                'api_nowhp': 107,
                'api_maxhp': 149,
                'api_fuel': 3,
                'api_bull': 7,
              },
              {
                'api_id': 2,
                'api_ship_id': 2,
                'api_nowhp': 12,
                'api_maxhp': 127,
                'api_fuel': 4,
                'api_bull': 9,
              },
            ]);
            stage = 1;
            verify(layout);
          } else if (index == 3) {
            // The predecoded capture path must keep HP separate from replenishment.
            await accept('api_req_hokyu/charge', {
              'api_ship': [
                {'api_id': 1, 'api_fuel': 40, 'api_bull': 45},
                {'api_id': 2, 'api_fuel': 25, 'api_bull': 30},
              ],
            }, decoded: true);
            stage = 2;
            verify(layout);
          } else if (index == 4) {
            await accept(
              'api_req_map/start',
              {'api_maparea_id': 1, 'api_mapinfo_no': 1, 'api_no': 1},
              requestParams: {'api_deck_id': '1'},
            );
            expect(controller.state.combatState.isActive, isTrue);
            controller.applyFriendlyBattleHp({
              1: 7,
              2: 2,
            }, DateTime.utc(2026, 11, 4, 12, 1));
            await controller.idle;
            await tester.pump();
            stage = 3;
            verify(layout);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _Layout {
  const _Layout(this.label, this.width, this.columns, this.style, this.fields);
  final String label;
  final double width;
  final int columns;
  final PanelStyle style;
  final Set<String> fields;
}

Widget _host(GameStateController controller, _Layout layout) => MaterialApp(
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
                key: _cardKey,
                controller: controller,
                visible: layout.fields,
                collapsed: false,
                onToggleCollapse: () {},
                onOpenFleet: (_) {},
                damagePulseFilter: DamagePulseFilter.off,
                moraleSparkleMode: MoraleSparkleMode.off,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void _expectFixedSlots(WidgetTester tester, _Layout layout, int stage) {
  final minimal = layout.style == PanelStyle.flat;
  for (final id in [1, 2]) {
    Finder value(String field) => find.byKey(
      Key(
        minimal
            ? field == 'hp'
                  ? 'minimal-hp-value-$id'
                  : 'minimal-supply-$field-value-$id'
            : 'fleet-focus-$field-value-$id',
      ),
    );
    Rect slot(String field) => tester.getRect(
      minimal
          ? find.byKey(Key('minimal-status-$field-$id'))
          : find.ancestor(
              of: value(field),
              matching: find.byType(CompactStatusMeter),
            ),
    );
    final reason = '${layout.label}, ship=$id, stage=$stage';
    final hp = slot('hp');
    final fuel = slot('fuel');
    expect(hp.left, lessThan(fuel.left), reason: reason);
    expect(hp.right, lessThanOrEqualTo(fuel.left + .01), reason: reason);
    expect(
      tester.getRect(value('hp')).right,
      lessThanOrEqualTo(fuel.left + .01),
      reason: reason,
    );
    expect(hp.top, greaterThanOrEqualTo(fuel.bottom), reason: reason);
    if (layout.fields.contains('ammo')) {
      final ammo = slot('ammo');
      expect(hp.top, closeTo(ammo.top, .01), reason: reason);
      expect(fuel.left, closeTo(ammo.left, .01), reason: reason);
    } else {
      expect(value('ammo'), findsNothing, reason: reason);
    }
    if (minimal) {
      final info = tester.getRect(find.byKey(Key('minimal-status-info-$id')));
      expect(info.top, closeTo(fuel.top, .01), reason: reason);
    }
    final expectedHp = switch ((stage, id)) {
      (0, 1) => '49/49',
      (0, _) => '20/27',
      (1 || 2, 1) => '107/149',
      (1 || 2, _) => '12/127',
      (_, 1) => '7/149',
      _ => '2/127',
    };
    final expectedFuel = stage == 1
        ? (id == 1 ? '3/40' : '4/25')
        : id == 1
        ? '40/40'
        : stage == 0
        ? '13/25'
        : '25/25';
    final expectedAmmo = stage == 1
        ? (id == 1 ? '7/45' : '9/30')
        : id == 1
        ? '45/45'
        : stage == 0
        ? '15/30'
        : '30/30';
    expect(tester.widget<Text>(value('hp')).data, expectedHp, reason: reason);
    expect(
      tester.widget<Text>(value('fuel')).data,
      expectedFuel,
      reason: reason,
    );
    if (layout.fields.contains('ammo')) {
      expect(
        tester.widget<Text>(value('ammo')).data,
        expectedAmmo,
        reason: reason,
      );
    }
  }
}
