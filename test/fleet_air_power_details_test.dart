import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/fleet_air_power_details.dart';
import 'package:yahagi_kancolle_browser/src/game_state/fleet_metrics.dart';

void main() {
  testWidgets('shows minimum maximum and no-bonus air power in order', (
    tester,
  ) async {
    const metrics = FleetMetrics(
      shipCount: 1,
      totalLevel: 1,
      firepower: 0,
      torpedo: 0,
      antiAir: 0,
      antiSub: 0,
      lineOfSight: 0,
      formula33: [],
      minimumCondition: 49,
      speedLabel: '高速',
      airPower: 40,
      airPowerMaximum: 41,
      airPowerWithoutProficiency: 24,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: FleetAirPowerDetails(
              metrics: metrics,
              builder: (toggle) =>
                  TextButton(onPressed: toggle, child: const Text('打开')),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('制空详情'), findsOneWidget);
    expect(find.text('最小'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('最大'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('不含熟练度加成'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    final minimumTop = tester.getTopLeft(find.text('最小')).dy;
    final maximumTop = tester.getTopLeft(find.text('最大')).dy;
    final withoutBonusTop = tester.getTopLeft(find.text('不含熟练度加成')).dy;
    expect(minimumTop, lessThan(maximumTop));
    expect(maximumTop, lessThan(withoutBonusTop));

    await tester.tap(find.byKey(const Key('fleet-air-power-details-close')));
    await tester.pumpAndSettle();
    expect(find.text('制空详情'), findsNothing);
  });
}
