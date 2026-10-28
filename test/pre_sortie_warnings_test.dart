import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/pre_sortie_check_summary.dart';
import 'package:yahagi_kancolle_browser/src/fleet/pre_sortie_warnings.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';

void main() {
  setUp(() => GameStateController.disableTimerForTest = true);

  testWidgets(
    'shared warnings preserve fleet-category counts and displayed copy',
    (tester) async {
      final controller = GameStateController(initialState: _warningState);
      addTearDown(controller.dispose);
      late List<PreSortieWarning> warnings;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              warnings = generatePreSortieWarnings(
                context,
                controller.state,
                AppLocalizations.of(context)!,
              );
              return PreSortieCheckSummary(
                controller: controller,
                collapsed: false,
                onToggleCollapse: () {},
                onOpenFleet: (_) {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(warnings.map((warning) => warning.fleetId), [1, 1, 1, 1, 1]);
      expect(warnings.map((warning) => warning.kind.keyName), [
        'critical',
        'supply',
        'fatigue',
        'main-equipment',
        'extra-equipment',
      ]);
      expect(warnings.map((warning) => warning.message), [
        '第1舰队 存在大破舰，停止出击！',
        '第1舰队 舰娘未补给',
        '第1舰队 舰娘疲劳未恢复',
        '第1舰队 装备缺失（主装备槽）：瑞鹤改二甲、雪风改',
        '第1舰队 装备缺失（增设槽）：雪风改',
      ]);
      for (final warning in warnings) {
        expect(find.text(warning.message), findsOneWidget);
        expect(
          find.byKey(
            Key(
              'pre-sortie-warning-${warning.fleetId}-${warning.kind.keyName}',
            ),
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('expedition fleets do not add any shared warnings', (
    tester,
  ) async {
    final state = _warningState.copyWith(
      fleets: [
        ..._warningState.fleets,
        Fleet(
          id: 2,
          name: '远征舰队',
          shipIds: const [1001, 1002],
          mission: FleetMission(
            state: 1,
            missionId: 1,
            completionTime: DateTime(2026, 10, 27),
          ),
        ),
      ],
    );
    late List<PreSortieWarning> warnings;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            warnings = generatePreSortieWarnings(
              context,
              state,
              AppLocalizations.of(context)!,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(warnings, hasLength(5));
    expect(warnings.every((warning) => warning.fleetId == 1), isTrue);
  });

  testWidgets('warning focus returns to ships and saves the selected mode', (
    tester,
  ) async {
    final controller = GameStateController(initialState: _warningState);
    final focusRequest = ValueNotifier(0);
    final bucket = PageStorageBucket();
    addTearDown(controller.dispose);
    addTearDown(focusRequest.dispose);
    Widget summary() => PreSortieCheckSummary(
      key: const PageStorageKey('pre-sortie-focus'),
      controller: controller,
      collapsed: false,
      onToggleCollapse: () {},
      onOpenFleet: (_) {},
      warningFocusRequest: focusRequest,
    );
    Widget host(Widget child) => _app(
      PageStorage(
        bucket: bucket,
        child: Column(
          children: [
            TextButton(
              onPressed: () => focusRequest.value++,
              child: const Text('查看出击提醒'),
            ),
            child,
          ],
        ),
      ),
    );

    await tester.pumpWidget(host(summary()));
    await tester.tap(find.byKey(const Key('sortie-check-mode-maps')));
    await tester.pump();
    expect(
      find.byKey(const Key('pre-sortie-warning-1-critical')),
      findsNothing,
    );
    await tester.tap(find.text('查看出击提醒'));
    await tester.pump();
    expect(
      find.byKey(const Key('pre-sortie-warning-1-critical')),
      findsOneWidget,
    );

    await tester.pumpWidget(host(const SizedBox.shrink()));
    await tester.pumpWidget(host(summary()));
    expect(
      find.byKey(const Key('pre-sortie-warning-1-critical')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const _warningState = GameState(
  hasMasterData: true,
  hasPortData: true,
  masterShips: {
    101: MasterShip(
      id: 101,
      name: '瑞鹤改二甲',
      shipTypeId: 18,
      maxFuel: 100,
      maxAmmo: 100,
      slotCount: 2,
    ),
    102: MasterShip(
      id: 102,
      name: '雪风改',
      shipTypeId: 2,
      maxFuel: 20,
      maxAmmo: 20,
      slotCount: 3,
    ),
  },
  ships: {
    1001: OwnedShip(
      id: 1001,
      masterId: 101,
      level: 99,
      currentHp: 2,
      maxHp: 10,
      currentFuel: 50,
      currentAmmo: 50,
      condition: 18,
      slotIds: [7001],
      extraSlotId: 0,
    ),
    1002: OwnedShip(
      id: 1002,
      masterId: 102,
      level: 80,
      currentHp: 30,
      maxHp: 30,
      currentFuel: 20,
      currentAmmo: 20,
      condition: 49,
      slotIds: [7002, 7003],
      extraSlotId: -1,
    ),
  },
  fleets: [
    Fleet(id: 1, name: '第1舰队', shipIds: [1001, 1002]),
  ],
);
