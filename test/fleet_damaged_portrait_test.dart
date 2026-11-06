import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_information_center.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_summary_card.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/layout/panel_style.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_status_effect_settings.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets('briefings and details follow received ship HP and repair', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = GameStateController();
    addTearDown(controller.dispose);

    Map<String, int> shipAtHp(int hp) => {
      'api_id': 9001,
      'api_ship_id': 101,
      'api_lv': 50,
      'api_nowhp': hp,
      'api_maxhp': 30,
      'api_cond': 49,
    };

    controller
      ..accept(start2Event)
      ..accept(
        kcsapiEvent('/kcsapi/api_port/port', {
          'api_ship': [shipAtHp(16)],
          'api_deck_port': [
            {
              'api_id': 1,
              'api_name': '第一舰队',
              'api_ship': [9001],
            },
          ],
        }),
      );
    await controller.idle;

    Widget briefing(PanelStyle style) => PanelStyleScope(
      key: ValueKey(style),
      style: style,
      child: FleetSummaryCard(
        controller: controller,
        collapsed: false,
        onToggleCollapse: () {},
        onOpenFleet: (_) {},
        visible: const {'portrait'},
        damagePulseFilter: DamagePulseFilter.off,
        moraleSparkleMode: MoraleSparkleMode.off,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 350, child: briefing(PanelStyle.card)),
              SizedBox(width: 350, child: briefing(PanelStyle.flat)),
              Expanded(
                child: FleetInformationCenter(
                  controller: controller,
                  damagePulseMode: DamagePulseFilter.off,
                  moraleSparkleMode: MoraleSparkleMode.off,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    void expectPortraits({required int hp, required bool isDamaged}) {
      expect(controller.state.ships[9001]?.currentHp, hp);
      Finder detailPortrait(String key) => find.descendant(
        of: find.byType(FleetInformationCenter),
        matching: find.byKey(Key(key)),
      );
      final surfaces = {
        'card briefing': find.byKey(const ValueKey(PanelStyle.card)),
        'flat briefing': find.byKey(const ValueKey(PanelStyle.flat)),
        'detail roster': detailPortrait('fleet-roster-portrait-9001'),
        'detail focus': detailPortrait('fleet-focus-portrait-9001'),
      };
      for (final entry in surfaces.entries) {
        final portrait = find.descendant(
          of: entry.value,
          matching: find.byType(ShipPortrait),
        );
        final reason = '${entry.key} at $hp HP';
        expect(portrait, findsOneWidget, reason: reason);
        expect(
          tester.widget<ShipPortrait>(portrait).isDamaged,
          isDamaged,
          reason: reason,
        );
      }
    }

    expectPortraits(hp: 16, isDamaged: false);

    for (final hp in [15, 7]) {
      controller.accept(
        kcsapiEvent('/kcsapi/api_get_member/ship2', [shipAtHp(hp)]),
      );
      await controller.idle;
      await tester.pump();
      expectPortraits(hp: hp, isDamaged: true);
    }

    controller.accept(
      kcsapiEvent(
        '/kcsapi/api_req_nyukyo/start',
        null,
        includeApiData: false,
        requestParams: {
          'api_ndock_id': '1',
          'api_ship_id': '9001',
          'api_highspeed': '1',
        },
      ),
    );
    await controller.idle;
    await tester.pump();
    expectPortraits(hp: 30, isDamaged: false);
    expect(tester.takeException(), isNull);
  });
}
