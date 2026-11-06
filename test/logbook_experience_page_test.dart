import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_experience_record.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_page.dart';
import 'package:yahagi_kancolle_browser/src/sortie_experience/sortie_experience_controller.dart';
import 'package:yahagi_kancolle_browser/src/widgets/frozen_data_table.dart';

import 'fixtures/kcsapi_fixtures.dart';

const _experienceTable = Key('logbook-table-experience');

void main() {
  testWidgets('experience opens latest and shows unnumbered ships in order', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _withLogbook(tester, [_sortie, _practice], (_) async {
      final table = tester.widget<FrozenDataTable>(
        find.byKey(_experienceTable),
      );
      expect(
        [
          ...table.frozenColumnWidths,
          ...table.scrollableColumnWidths,
        ].reduce((left, right) => left + right),
        closeTo(tester.getSize(find.byKey(_experienceTable)).width, .1),
      );
      expect(find.text('演习'), findsOneWidget);
      expect(find.text('已结算 1 场战斗'), findsOneWidget);
      expect(find.text('本次演习经验'), findsOneWidget);
      expect(find.text('吹雪改二'), findsOneWidget);
      expect(find.text('深雪改二'), findsOneWidget);
      expect(find.text('+320').hitTestable(), findsOneWidget);
      expect(find.text('+1,240').hitTestable(), findsOneWidget);
      expect(find.text('Lv.—').hitTestable(), findsNWidgets(2));
      expect(find.text('Next. —').hitTestable(), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('吹雪改二')).dy,
        lessThan(tester.getTopLeft(find.text('深雪改二')).dy),
      );
      expect(find.text('1'), findsNothing);
      expect(find.text('大和改二'), findsNothing);

      await tester.tap(
        find.byKey(const Key('logbook-experience-record-sortie')),
      );
      await tester.pumpAndSettle();

      expect(find.text('本次出击经验'), findsOneWidget);
      expect(find.text('主力舰队'), findsOneWidget);
      expect(find.text('护卫舰队'), findsOneWidget);
      expect(find.text('部分记录'), findsOneWidget);
      expect(find.text('大和改二'), findsOneWidget);
      expect(find.text('矢矧改二乙'), findsOneWidget);
      expect(find.text('未捕获').hitTestable(), findsOneWidget);
      expect(find.text('0').hitTestable(), findsOneWidget);
      expect(find.text('吹雪改二'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('experience opens a newly completed record on refresh', (
    tester,
  ) async {
    await _withLogbook(tester, [_sortie], (database) async {
      expect(find.text('大和改二'), findsOneWidget);

      await tester.runAsync(() async {
        await database.insertExperienceRecord(_practice);
        await database.getExperienceRecords();
      });
      await tester.pumpAndSettle();

      expect(find.text('吹雪改二'), findsOneWidget);
      expect(find.text('大和改二'), findsNothing);
    });
  });

  testWidgets('experience shows live progress for each copy in a narrow pane', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(220, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});

    const memberId = 793441;
    final account = AccountSession(initialMemberId: memberId);
    final previousAccount = LogbookDatabase.accountSession;
    LogbookDatabase.bindAccountSession(account);
    final database = LogbookDatabase.forAccount(memberId);
    var state = const GameState(
      memberId: memberId,
      ships: {
        41: OwnedShip(
          id: 41,
          masterId: 434,
          level: 10,
          experience: 5300,
          nextExperience: 200,
        ),
        22: OwnedShip(
          id: 22,
          masterId: 434,
          level: 151,
          experience: 2_800_000,
          nextExperience: 149999,
        ),
      },
      fleets: [
        Fleet(id: 2, name: '第二舰队', shipIds: [41, 22]),
      ],
    );
    final controller = (await tester.runAsync(() async {
      final controller = SortieExperienceController(
        accountSession: account,
        gameState: () => state,
      );
      await controller.initialize();
      return controller;
    }))!;
    final battle = BattleController(gameState: () => state);
    const name = '舰名很长的同名练级舰娘改二特别版本';
    final record = LogbookExperienceRecord(
      eventKey: 'copies',
      completedAt: _practice.completedAt,
      isPractice: true,
      mapAreaId: 0,
      mapInfoNo: 0,
      deckId: 2,
      battles: 1,
      ships: const [
        LogbookExperienceShip(
          ownedShipId: 41,
          masterShipId: 434,
          name: name,
          fleetId: 2,
          experience: 320,
        ),
        LogbookExperienceShip(
          ownedShipId: 22,
          masterShipId: 434,
          name: name,
          fleetId: 2,
          experience: 1_234_567,
        ),
      ],
    );

    void expectMetric(String metric, int id, String label) {
      final finder = find.byKey(ValueKey('logbook-experience-$metric-$id'));
      expect(finder.hitTestable(), findsOneWidget);
      final text = tester.widget<Text>(finder);
      expect(text.data, label);
      expect(text.softWrap, isFalse);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      final tableBounds = tester.getRect(find.byKey(_experienceTable));
      final textBounds = tester.getRect(finder);
      expect(textBounds.left, greaterThanOrEqualTo(tableBounds.left));
      expect(textBounds.right, lessThanOrEqualTo(tableBounds.right));
    }

    try {
      await tester.runAsync(() async {
        await database.insertExperienceRecord(record);
        await tester.pumpWidget(
          _app(battle, database, controller: controller, textScale: 1.4),
        );
        await database.getExperienceRecords();
      });
      await tester.pumpAndSettle();

      final names = tester.widgetList<Text>(find.text(name));
      expect(names, hasLength(2));
      for (final text in names) {
        expect(text.maxLines, 2);
        expect(text.overflow, TextOverflow.ellipsis);
      }
      expectMetric('level', 41, 'Lv.10');
      expectMetric('next', 41, 'Next. 200');
      expectMetric('level', 22, 'Lv.151');
      expectMetric('next', 22, 'Next. 149,999');
      expectMetric('value', 22, '+1,234,567');

      await tester.runAsync(() async {
        controller.accept(
          kcsapiEvent('/kcsapi/api_req_practice/battle', {'api_deck_id': 2}),
        );
        controller.accept(
          kcsapiEvent('/kcsapi/api_req_practice/battle_result', {
            'api_get_ship_exp': [-1, 350, 0],
            'api_get_exp_lvup': [
              [5300, 5500, 6600],
            ],
          }, sequence: 2),
        );
        await controller.idle;
      });
      await tester.pumpAndSettle();

      expectMetric('level', 41, 'Lv.11');
      expectMetric('next', 41, 'Next. 950');
      expectMetric('level', 22, 'Lv.151');
      expectMetric('next', 22, 'Next. 149,999');
      expectMetric('value', 41, '+320');
      expectMetric('value', 22, '+1,234,567');
      expect(find.text('#41'), findsNothing);
      expect(find.text('#22'), findsNothing);

      await tester.runAsync(() async {
        state = state.copyWith(
          memberId: memberId + 1,
          ships: const {
            41: OwnedShip(id: 41, masterId: 434, level: 44, nextExperience: 90),
          },
        );
        account.selectMember(memberId + 1);
        await controller.idle;
        await tester.pump();
        await database.getExperienceRecords();
      });
      await tester.pumpAndSettle();

      expect(controller.progressFor(41), (level: 44, nextExperience: 90));
      expectMetric('level', 41, 'Lv.—');
      expectMetric('next', 41, 'Next. —');
      expectMetric('value', 41, '+320');
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      battle.dispose();
      controller.dispose();
      LogbookDatabase.bindAccountSession(previousAccount);
      account.dispose();
      await tester.runAsync(database.close);
    }
  });
}

Future<void> _withLogbook(
  WidgetTester tester,
  List<LogbookExperienceRecord> records,
  Future<void> Function(LogbookDatabase) assertions,
) async {
  final database = (await tester.runAsync(() async {
    final database = await LogbookDatabase.openForTesting();
    for (final record in records) {
      await database.insertExperienceRecord(record);
    }
    return database;
  }))!;
  final battle = BattleController(gameState: () => GameState.empty);
  try {
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(battle, database));
      await database.getExperienceRecords();
    });
    await tester.pumpAndSettle();
    await assertions(database);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    battle.dispose();
    await tester.runAsync(database.close);
  }
}

Widget _app(
  BattleController battle,
  LogbookDatabase database, {
  SortieExperienceController? controller,
  double textScale = 1,
}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.only(left: 40),
      child: LogbookPage(
        battleController: battle,
        database: database,
        sortieExperienceController: controller,
        selectedTabIndex: 6,
      ),
    ),
  ),
);

final _practice = LogbookExperienceRecord(
  eventKey: 'practice',
  completedAt: DateTime.utc(2026, 11, 7, 1, 22),
  isPractice: true,
  mapAreaId: 0,
  mapInfoNo: 0,
  deckId: 2,
  battles: 1,
  ships: const [
    LogbookExperienceShip(
      ownedShipId: 41,
      masterShipId: 434,
      name: '吹雪改二',
      fleetId: 2,
      experience: 320,
    ),
    LogbookExperienceShip(
      ownedShipId: 22,
      masterShipId: 979,
      name: '深雪改二',
      fleetId: 2,
      experience: 1240,
    ),
  ],
);

final _sortie = LogbookExperienceRecord(
  eventKey: 'sortie',
  completedAt: DateTime.utc(2026, 11, 7, 0, 56),
  isPractice: false,
  mapAreaId: 5,
  mapInfoNo: 3,
  deckId: 1,
  battles: 2,
  incomplete: true,
  ships: const [
    LogbookExperienceShip(
      ownedShipId: 11,
      masterShipId: 911,
      name: '大和改二',
      fleetId: 1,
      experience: 0,
    ),
    LogbookExperienceShip(
      ownedShipId: 12,
      masterShipId: 662,
      name: '矢矧改二乙',
      fleetId: 2,
      experience: null,
    ),
  ],
);
