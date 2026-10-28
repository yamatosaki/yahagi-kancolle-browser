import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_trend_page.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_database.dart';
import 'package:yahagi_kancolle_browser/src/logbook/logbook_page.dart';

const _tabIds = [
  'sortie',
  'expedition',
  'construction',
  'development',
  'retirement',
  'resource',
];

void _expectReadableTab(WidgetTester tester, int index, String label) {
  final tabText = find.descendant(
    of: find.byKey(Key('logbook-tab-${_tabIds[index]}')),
    matching: find.text(label),
  );
  final paragraph = tester.renderObject<RenderParagraph>(tabText);
  final textBounds = tester.getRect(tabText);
  final switcherBounds = tester.getRect(
    find.byKey(const Key('logbook-segmented')),
  );
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(textBounds.width, closeTo(paragraph.size.width, .1));
  expect(textBounds.height, closeTo(paragraph.size.height, .1));
  expect(textBounds.left, greaterThanOrEqualTo(switcherBounds.left - .1));
  expect(textBounds.right, lessThanOrEqualTo(switcherBounds.right + .1));
  expect(textBounds.top, greaterThanOrEqualTo(switcherBounds.top - .1));
  expect(textBounds.bottom, lessThanOrEqualTo(switcherBounds.bottom + .1));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (locale, labels) in [
    (const Locale('zh'), ['出击', '远征', '建造', '开发', '除籍', '资源']),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ['出擊', '遠征', '建造', '開發', '除籍', '資源'],
    ),
    (const Locale('ja'), ['出撃', '遠征', '建造', '開発', '除籍', '資源']),
    (const Locale('ko'), ['출격', '원정', '건조', '개발', '제적', '자원']),
    (
      const Locale('en'),
      [
        'Sortie',
        'Expedition',
        'Construction',
        'Development',
        'Removal',
        'Resources',
      ],
    ),
  ]) {
    for (final width in [320.0, 360.0, 900.0]) {
      testWidgets('logbook header and page navigate in $locale at $width', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 780);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final database = await LogbookDatabase.openForTesting();
        final controller = BattleController(gameState: () => GameState.empty);
        addTearDown(database.close);
        addTearDown(controller.dispose);
        // A ship name can equal a navigation source label without becoming UI.
        await database.insertConstructionRecord(
          timestamp: DateTime.now().millisecondsSinceEpoch,
          constructionType: '普通建造',
          shipId: 1,
          shipName: '出击',
          shipType: '驱逐舰',
          fuel: 30,
          ammo: 30,
          steel: 30,
          bauxite: 30,
          developmentMaterial: 1,
          secretaryName: '矢矧改二乙',
        );
        var selected = 0;
        late StateSetter changeSelection;
        final changes = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  changeSelection = setState;
                  return Column(
                    children: [
                      SizedBox(
                        height: 54,
                        child: WorkspaceContextHeader(
                          workspaceIndex: 6,
                          state: GameState.empty,
                          selectedFleetId: 1,
                          logbookTabIndex: selected,
                          onLogbookTabChanged: (value) {
                            changes.add(value);
                            setState(() => selected = value);
                          },
                        ),
                      ),
                      Expanded(
                        child: LogbookPage(
                          battleController: controller,
                          database: database,
                          selectedTabIndex: selected,
                          onTabChanged: (value) =>
                              setState(() => selected = value),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final header = find.byType(WorkspaceContextHeader);
        expect(
          find.descendant(
            of: header,
            matching: find.text(lookupAppLocalizations(locale).battleRecords),
          ),
          findsOneWidget,
        );
        for (var index = 0; index < labels.length; index++) {
          expect(
            find.descendant(
              of: find.byKey(Key('logbook-tab-${_tabIds[index]}')),
              matching: find.text(labels[index]),
            ),
            findsOneWidget,
          );
        }
        const selections = [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0];
        for (final index in selections) {
          final tab = find.byKey(Key('logbook-tab-${_tabIds[index]}'));
          await tester.ensureVisible(tab);
          await tester.pumpAndSettle();
          await tester.tap(tab);
          await tester.pumpAndSettle();
          _expectReadableTab(tester, index, labels[index]);
          expect(selected, index);
          expect(
            tester
                .widget<LogbookPage>(find.byType(LogbookPage))
                .selectedTabIndex,
            index,
          );
          expect(
            tester
                .widget<Material>(
                  find
                      .descendant(of: tab, matching: find.byType(Material))
                      .first,
                )
                .color,
            const Color(0xff5b4829),
          );
          final visiblePage = index == 5
              ? find.byType(ResourceTrendPage)
              : find.byKey(Key('logbook-table-${_tabIds[index]}'));
          expect(visiblePage, findsOneWidget);
          expect(
            tester.getRect(visiblePage).left,
            closeTo(index == 5 ? 0 : 12, .1),
          );
          if (index == 2) {
            expect(
              find.descendant(
                of: find.byType(LogbookPage),
                matching: find.text('出击'),
              ),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        }
        expect(changes, selections);
        // Programmatic navigation also reveals its selected label without a
        // test-driven scroll, including a return from the last category.
        for (final index in [5, 0]) {
          changeSelection(() => selected = index);
          await tester.pumpAndSettle();
          _expectReadableTab(tester, index, labels[index]);
          expect(tester.takeException(), isNull);
        }
        expect(
          (await database.getConstructionRecords()).single['ship_name'],
          '出击',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
