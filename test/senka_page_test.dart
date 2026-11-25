import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/layout/workspace_context_header.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_calendar_view.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_calculator_view.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_controller.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_page.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_state.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_store.dart';
import 'package:yahagi_kancolle_browser/src/senka/senka_ui.dart';
import 'package:yahagi_kancolle_browser/src/widgets/app_segmented_style.dart';

void main() {
  test('战果刷新时间固定显示为 UTC+9', () {
    expect(
      senkaJstTimestamp(DateTime.utc(2026, 8, 20, 16, 47, 4)),
      '2026-08-21 01:47:04',
    );
    expect(senkaJstTimestamp(null), '--');
  });

  late SenkaController controller;

  setUp(() async {
    controller = SenkaController(
      store: MemorySenkaStore(sampleState()),
      now: () => DateTime.utc(2026, 8, 10),
    );
    await controller.initialize();
  });
  tearDown(() => controller.dispose());

  for (final size in const [
    Size(1280, 680),
    Size(800, 1100),
    Size(720, 720),
    Size(844, 390),
    Size(390, 844),
  ]) {
    testWidgets('${size.width.toInt()}×${size.height.toInt()} 三页均无溢出', (
      tester,
    ) async {
      await pumpSenka(tester, controller, size);
      expect(find.byKey(const Key('senka-tab-info')), findsOneWidget);
      expect(find.byKey(const Key('senka-tab-calendar')), findsOneWidget);
      expect(find.byKey(const Key('senka-tab-calculator')), findsOneWidget);
      expect(find.text('所在服务器'), findsOneWidget);
      expect(find.text('2026年8月战果日历'), findsNothing);
      expect(find.text('目标战果'), findsNothing);
      expect(tester.takeException(), isNull);
      final horizontal =
          size == const Size(1280, 680) || size == const Size(844, 390);
      expect(
        find.byKey(Key('senka-info-${horizontal ? 'horizontal' : 'vertical'}')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const Key('senka-sortie-row-3-2')));

      await tester.tap(find.byKey(const Key('senka-tab-calendar')));
      await tester.pump();
      expect(find.text('2026年8月战果日历'), findsOneWidget);
      expect(find.text('所在服务器'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('senka-day-detail')));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('senka-tab-calculator')));
      await tester.pump();
      expect(find.text('目标战果'), findsOneWidget);
      expect(find.text('2026年8月战果日历'), findsNothing);
      expect(
        find.byKey(
          Key('senka-calculator-${horizontal ? 'horizontal' : 'vertical'}'),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('senka-calculator-footer')),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('顶部三按钮等宽且选中态为金色', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    Color selectedTabColor(String name) => AppSegmentedStyle.selectedBackground(
      tester.element(find.byKey(Key('senka-tab-$name'))),
    );
    final rects = [
      for (final key in ['info', 'calendar', 'calculator'])
        tester.getRect(find.byKey(Key('senka-tab-$key'))),
    ];
    expect(rects[0].width, closeTo(rects[1].width, .01));
    expect(rects[1].width, closeTo(rects[2].width, .01));
    expect(rects.every((rect) => rect.height >= 30), isTrue);
    expect(tabColor(tester, 'info'), selectedTabColor('info'));
    expect(tabColor(tester, 'calendar'), isNot(selectedTabColor('calendar')));
    await tester.tap(find.byKey(const Key('senka-tab-calendar')));
    await tester.pump();
    expect(tabColor(tester, 'calendar'), selectedTabColor('calendar'));
    expect(tabColor(tester, 'info'), isNot(selectedTabColor('info')));
    await tester.tap(find.byKey(const Key('senka-tab-calculator')));
    await tester.pump();
    expect(tabColor(tester, 'calculator'), selectedTabColor('calculator'));
    expect(tabColor(tester, 'calendar'), isNot(selectedTabColor('calendar')));
  });

  testWidgets('tabs 提供 button、selected 与可读标签语义', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSenka(tester, controller, const Size(844, 390));
    final info = tester.getSemantics(find.bySemanticsLabel('战果信息'));
    expect(info.flagsCollection.isButton, isTrue);
    expect(info.flagsCollection.isSelected, Tristate.isTrue);
    await tester.tap(find.byKey(const Key('senka-tab-calendar')));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('战果信息'))
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('战果日历'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('战果页结构文案跟随日文与繁中语言环境', (tester) async {
    await pumpSenka(
      tester,
      controller,
      const Size(844, 390),
      locale: const Locale('ja'),
    );
    expect(find.text('戦果情報'), findsOneWidget);
    expect(find.text('所属サーバー'), findsOneWidget);
    await tester.tap(find.byKey(const Key('senka-tab-calculator')));
    await tester.pump();
    expect(find.text('集計後の増加分'), findsOneWidget);
    expect(find.text('残り日数（今日を含む）'), findsOneWidget);

    await pumpSenka(
      tester,
      controller,
      const Size(844, 390),
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );
    await tester.tap(find.byKey(const Key('senka-tab-calendar')));
    await tester.pump();
    expect(find.text('2026年8月戰果日曆'), findsOneWidget);
    expect(find.textContaining('本月素戰果'), findsOneWidget);
  });

  testWidgets('SenkaPage 默认向子页传递未平移的 UTC instant', (tester) async {
    final before = DateTime.now().toUtc();
    await pumpSenkaWithoutNow(tester, controller, const Size(844, 390));
    final calendarNow = tester
        .widget<SenkaCalendarView>(find.byType(SenkaCalendarView))
        .now;
    final afterCalendar = DateTime.now().toUtc();
    expect(calendarNow.isUtc, isTrue);
    expect(
      calendarNow.isBefore(before) || calendarNow.isAfter(afterCalendar),
      isFalse,
    );
    await tester.tap(find.byKey(const Key('senka-tab-calculator')));
    await tester.pump();
    final calculatorNow = tester
        .widget<SenkaCalculatorView>(find.byType(SenkaCalculatorView))
        .now;
    final afterCalculator = DateTime.now().toUtc();
    expect(calculatorNow.isUtc, isTrue);
    expect(
      calculatorNow.isBefore(before) || calculatorNow.isAfter(afterCalculator),
      isFalse,
    );
  });

  testWidgets('信息页横屏左右等宽，方形与竖屏顺序滚动', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    final left = tester.getRect(find.byKey(const Key('senka-info-left')));
    final right = tester.getRect(find.byKey(const Key('senka-info-right')));
    expect(left.width, closeTo(right.width, 1));
    expect(left.left, lessThan(right.left));
    final server = tester.getRect(find.byKey(const Key('senka-info-server')));
    final ranking = tester.getRect(find.byKey(const Key('senka-info-ranking')));
    expect(server.height / (server.height + ranking.height), closeTo(.30, .02));

    await pumpSenka(tester, controller, const Size(720, 720));
    final verticalColumn = tester.widget<Column>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Column &&
            widget.children.any(
              (child) => child.key == const Key('senka-info-server'),
            ),
      ),
    );
    expect(
      verticalColumn.children
          .map((child) => child.key)
          .whereType<ValueKey<String>>(),
      const [
        Key('senka-info-server'),
        Key('senka-info-ranking'),
        Key('senka-info-sorties'),
      ],
    );
    await tester.ensureVisible(find.text('出击海域统计'));
    expect(find.text('出击海域统计'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('所在服务器、排名与统计遵守文案和两位小数', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    expect(find.text('横須賀鎮守府'), findsOneWidget);
    expect(find.text('108.00'), findsWidgets);
    expect(find.text('3874'), findsWidgets);
    for (final label in ['海域', 'Boss', '出击', 'S / A', '操作']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('海域明细'), findsNothing);
    expect(find.textContaining('到达率'), findsNothing);
    expect(find.textContaining('撤退'), findsNothing);
  });

  testWidgets('出击统计切到今日后仅显示今日数据', (tester) async {
    final state = SenkaState.fromJson({
      ...sampleState().toJson(),
      'sortieStatsByDay': {
        '2026-08-10': {
          '1-1': const SenkaSortieStats(
            areaId: 1,
            mapNo: 1,
            sorties: 2,
            bossArrivals: 1,
            sWins: 1,
          ).toJson(),
        },
      },
    });
    final dailyController = SenkaController(
      store: MemorySenkaStore(state),
      now: () => DateTime.utc(2026, 8, 10, 3),
    );
    await dailyController.initialize();
    addTearDown(dailyController.dispose);

    await pumpSenka(tester, dailyController, const Size(1280, 680));
    expect(find.byKey(const Key('senka-sortie-row-3-2')), findsOneWidget);

    await tester.tap(find.text('今日'));
    await tester.pump();

    expect(find.text('今日出击'), findsOneWidget);
    expect(find.byKey(const Key('senka-sortie-row-3-2')), findsNothing);
    final todayRow = find.byKey(const Key('senka-sortie-row-1-1'));
    for (final value in ['1-1', '1', '2', '1 / 0']) {
      expect(
        find.descendant(of: todayRow, matching: find.text(value)),
        findsOneWidget,
      );
    }
  });

  testWidgets('统计数据行同字号同中线且操作按钮完整位于行内', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    final row = find.byKey(const Key('senka-sortie-row-1-1'));
    final texts = tester
        .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .toList();
    expect(texts.map((text) => text.style?.fontSize).toSet(), hasLength(1));
    final centers = [
      for (final text in texts) tester.getCenter(find.byWidget(text)).dy,
    ];
    expect(
      centers.every((center) => (center - centers.first).abs() <= 1),
      isTrue,
    );
    expect(texts[3].maxLines, 1);
    final rowRect = tester.getRect(row);
    for (final key in const ['senka-favorite-1-1', 'senka-hide-1-1']) {
      final rect = tester.getRect(find.byKey(Key(key)));
      expect(rect.width, greaterThanOrEqualTo(36));
      expect(rect.height, greaterThanOrEqualTo(36));
      expect(rect.left, greaterThanOrEqualTo(rowRect.left));
      expect(rect.top, greaterThanOrEqualTo(rowRect.top));
      expect(rect.right, lessThanOrEqualTo(rowRect.right));
      expect(rect.bottom, lessThanOrEqualTo(rowRect.bottom));
    }
  });

  testWidgets('统计操作提供 Tooltip、button 与 toggled 语义', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSenka(tester, controller, const Size(1280, 680));
    final favorite = find.bySemanticsLabel('收藏海域 1-1');
    final hidden = find.bySemanticsLabel('隐藏海域 1-1');
    expect(tester.getSemantics(favorite).flagsCollection.isButton, isTrue);
    expect(
      tester.getSemantics(favorite).flagsCollection.isToggled,
      Tristate.isFalse,
    );
    expect(tester.getSemantics(hidden).flagsCollection.isButton, isTrue);
    expect(
      find.ancestor(
        of: find.byKey(const Key('senka-favorite-1-1')),
        matching: find.byType(Tooltip),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('senka-favorite-1-1')));
    await tester.pump();
    expect(
      tester.getSemantics(favorite).flagsCollection.isToggled,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('出击统计头部最近记录按钮提供 button 语义且触发跳转回调', (tester) async {
    var opened = false;
    final semantics = tester.ensureSemantics();
    await pumpSenka(
      tester,
      controller,
      const Size(1280, 680),
      onOpenSortieLog: () => opened = true,
    );
    final button = find.byKey(const Key('senka-recent-records'));
    expect(button, findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('最近记录'))
          .flagsCollection
          .isButton,
      isTrue,
    );
    await tester.tap(button);
    await tester.pump();
    expect(opened, isTrue);
    semantics.dispose();
  });

  testWidgets('统计默认隐藏隐藏项，收藏实际置顶且关闭开关恢复已取消隐藏项', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    expect(find.text('2-1'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('senka-sortie-row-1-1'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('senka-sortie-row-3-2'))).dy,
      ),
    );
    await tester.tap(find.byKey(const Key('senka-favorite-3-2')));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const Key('senka-sortie-row-3-2'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('senka-sortie-row-1-1'))).dy,
      ),
    );
    await tester.tap(find.byKey(const Key('senka-show-hidden')));
    await tester.pump();
    expect(find.text('2-1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('senka-hide-2-1')));
    await tester.pump();
    expect(controller.state.hiddenSortieMapKeys, isNot(contains('2-1')));
    await tester.tap(find.byKey(const Key('senka-show-hidden')));
    await tester.pump();
    expect(find.text('2-1'), findsOneWidget);
  });

  testWidgets('显示隐藏开关具有 44px 单一命中区和 toggled 语义', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSenka(tester, controller, const Size(1280, 680));
    final toggle = find.byKey(const Key('senka-show-hidden'));
    final rect = tester.getRect(toggle);
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('显示隐藏海域'))
          .flagsCollection
          .isToggled,
      Tristate.isFalse,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('显示隐藏海域'))
          .flagsCollection
          .isButton,
      isTrue,
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('2-1'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('显示隐藏海域'))
          .flagsCollection
          .isToggled,
      Tristate.isTrue,
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('2-1'), findsNothing);
    semantics.dispose();
  });

  testWidgets('排名保留固定线和当前行变化行为', (tester) async {
    await pumpSenka(tester, controller, const Size(1280, 680));
    expect(find.text('更新：2026-08-10 15:00:00'), findsOneWidget);
    for (final rank in [5, 20, 100, 501]) {
      expect(find.byKey(Key('ranking-row-$rank')), findsOneWidget);
    }
    expect(find.byKey(const Key('player-rank-subcolumns')), findsOneWidget);
    expect(find.text('↑42'), findsOneWidget);
    expect(find.byKey(const Key('player-senka-delta')), findsOneWidget);
  });

  testWidgets('日历保留六乘七、周一开始、日期选择和两位小数详情', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSenka(tester, controller, const Size(1280, 680));
    await tester.tap(find.byKey(const Key('senka-tab-calendar')));
    await tester.pump();
    expect(find.byKey(const Key('calendar-weekday-row')), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'calendar-cell-',
            ),
      ),
      findsNWidgets(42),
    );
    await tester.tap(find.byKey(const Key('calendar-cell-10')));
    await tester.pump();
    expect(find.text('+3.80'), findsOneWidget);
    expect(find.text('经验'), findsOneWidget);
    expect(find.text('EO'), findsOneWidget);
    expect(find.text('任务'), findsOneWidget);
    expect(find.textContaining('本月已记录 3.80'), findsOneWidget);
    final selectedDay = tester.getSemantics(
      find.bySemanticsLabel('2026年8月10日，战果3.80'),
    );
    expect(selectedDay.flagsCollection.isButton, isTrue);
    expect(selectedDay.flagsCollection.isSelected, Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('日历跨月时按 now 或新月首日重置选择与详情', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCalendar(
      tester,
      sampleState(),
      DateTime.utc(2026, 8, 10, 3),
      const Size(800, 700),
    );
    await tester.tap(find.byKey(const Key('calendar-cell-15')));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('2026年8月15日，战果0.00'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    final september = SenkaState.forMonth(
      '2026-09',
    ).copyWith(days: {'2026-09-08': const SenkaDayRecord(experience: 5.5)});
    await pumpCalendar(
      tester,
      september,
      DateTime.utc(2026, 9, 8, 3),
      const Size(800, 700),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('2026年9月8日，战果5.50'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(find.text('+5.50'), findsOneWidget);
    await pumpCalendar(
      tester,
      SenkaState.forMonth('2026-10'),
      DateTime.utc(2026, 9, 30, 3),
      const Size(800, 700),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('2026年10月1日，战果0.00'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('日历内部将 UTC instant 转为 JST 战果日', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCalendar(
      tester,
      SenkaState.forMonth('2026-08'),
      DateTime.utc(2026, 8, 30, 17, 30),
      const Size(800, 700),
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('2026年8月31日，战果0.00'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('计算页横屏始终三七双栏，方形为概况后任务矩阵', (tester) async {
    for (final size in const [Size(1280, 680), Size(844, 390)]) {
      await pumpCalculator(tester, controller, size);
      final left = tester.getRect(
        find.byKey(const Key('senka-calculator-left')),
      );
      final right = tester.getRect(
        find.byKey(const Key('senka-calculator-right')),
      );
      expect(left.width / (left.width + right.width), closeTo(.30, .02));
      expect(left.left, lessThan(right.left));
      expect(tester.takeException(), isNull);
    }
    await pumpCalculator(tester, controller, const Size(720, 720));
    final overviewY = tester
        .getTopLeft(find.byKey(const Key('senka-calculator-left')))
        .dy;
    await tester.ensureVisible(find.text('年度战果任务'));
    expect(tester.getTopLeft(find.text('年度战果任务')).dy, greaterThan(overviewY));
    expect(tester.takeException(), isNull);
  });

  testWidgets('计算页复制Demo横屏四列紧凑矩阵', (tester) async {
    for (final size in const [Size(1280, 680), Size(844, 390)]) {
      await pumpCalculator(tester, controller, size);

      final eo15 = tester.getRect(find.byKey(const Key('senka-toggle-eo-15')));
      final eo16 = tester.getRect(find.byKey(const Key('senka-toggle-eo-16')));
      final eo25 = tester.getRect(find.byKey(const Key('senka-toggle-eo-25')));
      final eo45 = tester.getRect(find.byKey(const Key('senka-toggle-eo-45')));
      expect(eo15.top, closeTo(eo16.top, 1));
      expect(eo15.top, closeTo(eo25.top, 1));
      expect(eo45.top, greaterThan(eo15.top));

      final quest854 = tester.getRect(
        find.byKey(const Key('senka-toggle-quest-854')),
      );
      final quest888 = tester.getRect(
        find.byKey(const Key('senka-toggle-quest-888')),
      );
      final quest893 = tester.getRect(
        find.byKey(const Key('senka-toggle-quest-893')),
      );
      final quest284 = tester.getRect(
        find.byKey(const Key('senka-toggle-quest-284')),
      );
      expect(quest854.top, closeTo(quest888.top, 1));
      expect(quest854.top, closeTo(quest893.top, 1));
      expect(quest284.top, greaterThan(quest854.top));

      final annual = tester.getRect(
        find.byKey(const Key('senka-task-group-annual')),
      );
      final oneTime = tester.getRect(
        find.byKey(const Key('senka-task-group-one-time')),
      );
      expect(annual.top, closeTo(oneTime.top, 1));
      expect(annual.right, lessThan(oneTime.left));

      final currentInput = tester.getRect(
        find.byKey(const Key('senka-current-input')),
      );
      final targetInput = tester.getRect(
        find.byKey(const Key('senka-target-input')),
      );
      expect(currentInput.top, closeTo(targetInput.top, 1));

      final projectedFinder = find.byKey(const Key('senka-projected-card'));
      final projected = tester.widget<Container>(projectedFinder);
      final projectedDecoration = projected.decoration! as BoxDecoration;
      expect(projectedDecoration.border, isNotNull);
      expect(projectedDecoration.color, senkaGold.withValues(alpha: .08));
      expect(
        find.descendant(
          of: projectedFinder,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOneWidget,
      );

      final metrics = find.byKey(const Key('senka-metrics-grid'));
      final metricsDecoration =
          tester.widget<Container>(metrics).decoration! as BoxDecoration;
      expect(metricsDecoration.border, isNotNull);
      final plannedEo = tester.getRect(
        find.byKey(const Key('senka-metric-planned-eo')),
      );
      final plannedQuest = tester.getRect(
        find.byKey(const Key('senka-metric-planned-quest')),
      );
      final remainingDays = tester.getRect(
        find.byKey(const Key('senka-metric-remaining-days')),
      );
      final baseSenka = tester.getRect(
        find.byKey(const Key('senka-metric-base-senka')),
      );
      final dailyRequired = tester.getRect(
        find.byKey(const Key('senka-metric-daily-required')),
      );
      final todayRemaining = tester.getRect(
        find.byKey(const Key('senka-metric-today-remaining')),
      );
      expect(plannedEo.right, closeTo(plannedQuest.left, 1));
      expect(dailyRequired.right, closeTo(todayRemaining.left, 1));
      expect(baseSenka.right, closeTo(remainingDays.left, 1));
      expect(plannedEo.bottom, closeTo(dailyRequired.top, 1));
      expect(dailyRequired.bottom, closeTo(baseSenka.top, 1));

      final hitTarget = tester.getRect(
        find.byKey(const Key('senka-toggle-eo-15')),
      );
      expect(hitTarget.height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('任务矩阵紧凑展示四组任务且无冗余文字标签', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));
    expect(find.text('EO 战果奖励'), findsOneWidget);
    expect(find.text('季度战果任务'), findsOneWidget);
    expect(find.text('年度战果任务'), findsOneWidget);
    expect(find.text('单次战果任务'), findsOneWidget);
    final eoTitle = tester.widget<Text>(find.text('EO 战果奖励'));
    expect(eoTitle.style!.fontSize, 15);
    final footerText = tester.widget<Text>(find.textContaining('合计'));
    final fontSize =
        footerText.style?.fontSize ?? footerText.textSpan?.style?.fontSize;
    expect(fontSize, 13);
    expect(find.text('实时计算'), findsNothing);
    expect(find.text('单击循环切换状态'), findsNothing);
    expect(find.text('手动选择'), findsNothing);
  });

  testWidgets('任务矩阵移除外层大胶囊并在 EO 标题后显示三态说明', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));

    expect(find.text('EO · 战果奖励矩阵'), findsNothing);
    final right = find.byKey(const Key('senka-calculator-right'));
    expect(
      find.descendant(of: right, matching: find.byType(SenkaPanel)),
      findsNothing,
    );

    const legend = '黄色＋✕：计划放置，不计入预计战果，绿色＋✓：计划完成，计入预计战果，灰色＋○：已经完成，不再重复计算。';
    expect(find.text(legend), findsOneWidget);
    final titleRect = tester.getRect(find.text('EO 战果奖励'));
    final legendRect = tester.getRect(find.text(legend));
    expect(titleRect.center.dy, closeTo(legendRect.center.dy, 1));
    expect(titleRect.right, lessThan(legendRect.left));

    final leftRect = tester.getRect(
      find.byKey(const Key('senka-calculator-left')),
    );
    final eoFrameRect = tester.getRect(
      find.byKey(const Key('senka-task-group-frame-eo')),
    );
    expect(leftRect.top, closeTo(eoFrameRect.top, 0.01));
  });

  testWidgets('计算数值在独立弹窗确认后更新', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));

    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byKey(const Key('senka-current-input')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('senka-value-input-dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('senka-value-input-dialog-field')),
      '850.5',
    );
    await tester.tap(find.byKey(const Key('senka-value-input-dialog-confirm')));
    await tester.pumpAndSettle();
    expect(controller.state.calculatorCurrentSenka, 850.5);

    await tester.tap(find.byKey(const Key('senka-target-input')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('senka-value-input-dialog-field')),
      '1800',
    );
    await tester.tap(find.byKey(const Key('senka-value-input-dialog-confirm')));
    await tester.pumpAndSettle();
    expect(controller.state.targetSenka, 1800);
  });

  testWidgets('计算弹窗取消不修改数值，负数确认后归零', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));
    final original = controller.state.calculatorCurrentSenka;

    await tester.tap(find.byKey(const Key('senka-current-input')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('senka-value-input-dialog-field')),
      '999',
    );
    await tester.tap(find.byKey(const Key('senka-value-input-dialog-cancel')));
    await tester.pumpAndSettle();
    expect(controller.state.calculatorCurrentSenka, original);

    await tester.tap(find.byKey(const Key('senka-current-input')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('senka-value-input-dialog-field')),
      '-120',
    );
    await tester.tap(find.byKey(const Key('senka-value-input-dialog-confirm')));
    await tester.pumpAndSettle();
    expect(controller.state.calculatorCurrentSenka, 0);
  });

  testWidgets('计算数值同步外部状态', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));
    controller.setTargetSenka(2200);
    await tester.pump();
    expect(find.text('2200.00'), findsOneWidget);
  });

  testWidgets('计算概况指标固定三乘二且文案两位小数', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));
    expect(find.textContaining('距离目标还差'), findsOneWidget);
    final expected = [
      ['计划 EO', '计划任务'],
      ['每日所需', '今日剩余'],
      ['结算后增量', '可用天数（含今日）'],
    ];
    for (var row = 0; row < expected.length; row++) {
      final first = tester.getRect(find.text(expected[row][0]));
      final second = tester.getRect(find.text(expected[row][1]));
      expect(first.top, closeTo(second.top, 1));
      expect(first.right, lessThan(second.left));
      if (row > 0) {
        final prev = tester.getRect(find.text(expected[row - 1][0]));
        expect(first.top, greaterThan(prev.top));
      }
    }
  });

  testWidgets('四组任务完整且统一胶囊三态可辨识', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCalculator(tester, controller, const Size(1280, 680));
    for (final title in ['EO 战果奖励', '季度战果任务', '年度战果任务', '单次战果任务']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('AL作戦'), findsOneWidget);
    expect(find.text('機動部隊決戦'), findsOneWidget);
    expect(find.text('改装特務空母『Gambier Bay Mk.II』抜錨！'), findsOneWidget);
    final toggle = find.byKey(const Key('senka-toggle-quest-854'));
    expect(tester.getRect(toggle).height, greaterThanOrEqualTo(36));
    expect(rewardGradient(tester, toggle).colors, const [
      Color(0xff735116),
      Color(0xff4a350f),
    ]);
    expect(rewardTooltip(tester, toggle), contains('计划放置'));
    expect(find.bySemanticsLabel(RegExp('前段作战，计划放置')), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(RegExp('前段作战，计划放置')))
          .flagsCollection
          .isToggled,
      Tristate.isFalse,
    );
    expect(
      find.descendant(of: toggle, matching: find.text('✕')),
      findsOneWidget,
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(controller.state.questStatuses[854], SenkaRewardStatus.planned);
    expect(rewardGradient(tester, toggle).colors, const [
      Color(0xff23694f),
      Color(0xff174b3a),
    ]);
    expect(rewardTooltip(tester, toggle), contains('计划完成（计预计）'));
    expect(find.bySemanticsLabel(RegExp('前段作战，计划完成（计预计）')), findsOneWidget);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(RegExp('前段作战，计划完成（计预计）')))
          .flagsCollection
          .isToggled,
      Tristate.isTrue,
    );
    expect(
      find.descendant(of: toggle, matching: find.text('✓')),
      findsOneWidget,
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(controller.state.questStatuses[854], SenkaRewardStatus.completed);
    expect(rewardGradient(tester, toggle).colors, const [
      Color(0xff4b565e),
      Color(0xff323b42),
    ]);
    expect(rewardTooltip(tester, toggle), contains('已完成'));
    expect(find.bySemanticsLabel(RegExp('前段作战，已完成')), findsOneWidget);
    final completedSurface = tester.getRect(
      find.byKey(const Key('senka-reward-visual-quest-854')),
    );
    final completedStrike = tester.getRect(
      find.byKey(const Key('senka-strike-quest-854')),
    );
    expect(completedStrike.left, closeTo(completedSurface.left, .01));
    expect(completedStrike.right, closeTo(completedSurface.right, .01));
    expect(completedStrike.center.dy, closeTo(completedSurface.center.dy, .01));
    expect(
      find.descendant(of: toggle, matching: find.text('○')),
      findsOneWidget,
    );
    expect(find.descendant(of: toggle, matching: find.text('✓')), findsNothing);
    semantics.dispose();
  });

  testWidgets('EO 状态条保持 HTML 渐变材质', (tester) async {
    final styledController = SenkaController(
      store: MemorySenkaStore(
        sampleState().copyWith(
          eoStatuses: const {
            15: SenkaRewardStatus.deferred,
            16: SenkaRewardStatus.planned,
            25: SenkaRewardStatus.completed,
          },
        ),
      ),
      now: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(styledController.dispose);
    await styledController.initialize();
    await pumpCalculator(tester, styledController, const Size(1280, 680));

    const expectedGradients = <int, List<Color>>{
      15: [Color(0xff735116), Color(0xff4a350f)],
      16: [Color(0xff23694f), Color(0xff174b3a)],
      25: [Color(0xff4b565e), Color(0xff323b42)],
    };
    for (final entry in expectedGradients.entries) {
      final toggle = find.byKey(Key('senka-toggle-eo-${entry.key}'));
      final surface = find.byKey(Key('senka-reward-visual-eo-${entry.key}'));
      final decoration = tester.widget<DecoratedBox>(surface).decoration;
      expect(decoration, isA<BoxDecoration>());
      final box = decoration as BoxDecoration;
      expect(box.gradient, isA<LinearGradient>());
      final gradient = box.gradient! as LinearGradient;
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
      expect(gradient.colors, entry.value);
      final border = box.border! as Border;
      expect(border.top.width, 1);
      expect(border.top.color.a, lessThan(1));
      final radius = box.borderRadius! as BorderRadius;
      expect(radius.topLeft.x, inInclusiveRange(4, 6));
      expect(box.boxShadow, hasLength(1));
      expect(box.boxShadow!.single.blurRadius, 3);
      expect(box.boxShadow!.single.offset, const Offset(0, 1));
      expect(tester.getRect(surface).height, closeTo(36, .01));
      expect(tester.getRect(toggle).height, greaterThanOrEqualTo(44));
      expect(
        find.byKey(Key('senka-reward-highlight-eo-${entry.key}')),
        findsOneWidget,
      );
    }

    final completed = find.byKey(const Key('senka-toggle-eo-25'));
    expect(
      find.descendant(of: completed, matching: find.text('○')),
      findsOneWidget,
    );
    final completedSurface = tester.getRect(
      find.byKey(const Key('senka-reward-visual-eo-25')),
    );
    final completedStrike = tester.getRect(
      find.byKey(const Key('senka-strike-eo-25')),
    );
    expect(completedStrike.left, closeTo(completedSurface.left, .01));
    expect(completedStrike.right, closeTo(completedSurface.right, .01));
    expect(completedStrike.center.dy, closeTo(completedSurface.center.dy, .01));

    final questToggle = find.byKey(const Key('senka-toggle-quest-854'));
    expect(rewardGradient(tester, questToggle).colors, const [
      Color(0xff735116),
      Color(0xff4a350f),
    ]);
  });

  testWidgets('四类奖励统一立体材质、放大文字、紧凑行距和独立分组框', (tester) async {
    final styledController = SenkaController(
      store: MemorySenkaStore(
        sampleState().copyWith(
          eoStatuses: const {15: SenkaRewardStatus.deferred},
          questStatuses: const {
            854: SenkaRewardStatus.deferred,
            888: SenkaRewardStatus.planned,
            893: SenkaRewardStatus.completed,
          },
        ),
      ),
      now: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(styledController.dispose);
    await styledController.initialize();
    await pumpCalculator(tester, styledController, const Size(1280, 680));

    const expectedGradients = <int, List<Color>>{
      854: [Color(0xff735116), Color(0xff4a350f)],
      888: [Color(0xff23694f), Color(0xff174b3a)],
      893: [Color(0xff4b565e), Color(0xff323b42)],
    };
    for (final entry in expectedGradients.entries) {
      final surface = find.byKey(Key('senka-reward-visual-quest-${entry.key}'));
      final decoration =
          tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
      expect((decoration.gradient! as LinearGradient).colors, entry.value);
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
      expect(tester.getRect(surface).height, closeTo(36, .01));
      expect(
        find.byKey(Key('senka-reward-highlight-quest-${entry.key}')),
        findsOneWidget,
      );
    }

    final firstToggle = find.byKey(const Key('senka-toggle-eo-15'));
    final label = tester.widget<Text>(
      find.descendant(of: firstToggle, matching: find.text('1-5')),
    );
    final reward = tester.widget<Text>(
      find.descendant(of: firstToggle, matching: find.text('+75.00')),
    );
    expect(label.style!.fontSize, 10);
    expect(reward.style!.fontSize, 10);
    final firstSurface = tester.getRect(
      find.byKey(const Key('senka-reward-visual-eo-15')),
    );
    expect(
      tester
          .getRect(find.descendant(of: firstToggle, matching: find.text('1-5')))
          .center
          .dy,
      closeTo(firstSurface.center.dy, 1.5),
    );
    final nextRowSurface = tester.getRect(
      find.byKey(const Key('senka-reward-visual-eo-45')),
    );
    expect(nextRowSurface.top - firstSurface.bottom, closeTo(8, .01));

    final leading = tester.getRect(
      find.byKey(const Key('senka-reward-leading-eo-15')),
    );
    final value = tester.getRect(
      find.byKey(const Key('senka-reward-value-eo-15')),
    );
    expect(leading.left - firstSurface.left, inInclusiveRange(6, 10));
    expect(leading.right, lessThanOrEqualTo(value.left));
    expect(firstSurface.right - value.right, inInclusiveRange(6, 10));
    expect(leading.center.dy, closeTo(firstSurface.center.dy, 1));
    expect(value.center.dy, closeTo(firstSurface.center.dy, 1));
    final iconRect = tester.getRect(
      find.descendant(of: firstToggle, matching: find.text('✕')),
    );
    final labelRect = tester.getRect(
      find.descendant(of: firstToggle, matching: find.text('1-5')),
    );
    final rewardRect = tester.getRect(
      find.descendant(of: firstToggle, matching: find.text('+75.00')),
    );
    expect(iconRect.bottom, closeTo(labelRect.bottom, .5));
    expect(labelRect.bottom, closeTo(rewardRect.bottom, .5));

    for (final group in const ['eo', 'quarterly', 'annual', 'one-time']) {
      final frame = find.byKey(Key('senka-task-group-frame-$group'));
      expect(frame, findsOneWidget);
      final decoration =
          tester.widget<Container>(frame).decoration! as BoxDecoration;
      expect(decoration.color, isNotNull);
      expect(decoration.border, isNotNull);
      expect(
        (decoration.borderRadius! as BorderRadius).topLeft.x,
        inInclusiveRange(6, 8),
      );
    }
  });

  testWidgets('当前战果不计入无计划奖励时的 footer 合计', (tester) async {
    await pumpCalculator(tester, controller, const Size(1280, 680));
    expect(find.text('计划 EO 战果奖励 +0.00'), findsOneWidget);
    expect(find.text('计划任务战果奖励 +0.00'), findsOneWidget);
    expect(find.text('合计 +0.00'), findsOneWidget);
  });

  testWidgets('概况与 footer 只汇总 planned 奖励金额并使用两位小数', (tester) async {
    final mixedController = SenkaController(
      store: MemorySenkaStore(
        sampleState().copyWith(
          eoStatuses: const {
            15: SenkaRewardStatus.planned,
            25: SenkaRewardStatus.completed,
            35: SenkaRewardStatus.deferred,
          },
          questStatuses: const {
            854: SenkaRewardStatus.planned,
            888: SenkaRewardStatus.completed,
            893: SenkaRewardStatus.deferred,
          },
        ),
      ),
      now: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(mixedController.dispose);
    await mixedController.initialize();
    await pumpCalculator(tester, mixedController, const Size(1280, 680));

    expect(
      find.descendant(
        of: find.byKey(const Key('senka-metric-planned-eo')),
        matching: find.text('+75.00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('senka-metric-planned-quest')),
        matching: find.text('+350.00'),
      ),
      findsOneWidget,
    );
    expect(find.text('计划 EO 战果奖励 +75.00'), findsOneWidget);
    expect(find.text('计划任务战果奖励 +350.00'), findsOneWidget);
    expect(find.text('合计 +425.00'), findsOneWidget);
  });

  testWidgets('390×844 可连续拖动到信息末行与计算单次任务和 footer', (tester) async {
    await pumpSenka(tester, controller, const Size(390, 844));
    await dragUntilVisible(
      tester,
      find.byKey(const Key('senka-sortie-row-3-2')),
    );
    await tester.tap(find.byKey(const Key('senka-tab-calculator')));
    await tester.pump();
    await dragUntilVisible(tester, find.text('单次战果任务'));
    await dragUntilVisible(
      tester,
      find.byKey(const Key('senka-calculator-footer')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('竖屏信息页从统计行起拖仅滚动外层并可到末行', (tester) async {
    final manyStats = <String, SenkaSortieStats>{
      for (var map = 1; map <= 12; map++)
        '1-$map': SenkaSortieStats(
          areaId: 1,
          mapNo: map,
          sorties: map,
          bossArrivals: map,
          sWins: map,
          aWins: 0,
        ),
    };
    final longController = SenkaController(
      store: MemorySenkaStore(sampleState().copyWith(sortieStats: manyStats)),
      now: () => DateTime.utc(2026, 8, 10),
    );
    addTearDown(longController.dispose);
    await longController.initialize();
    await pumpSenka(tester, longController, const Size(390, 844));
    final vertical = find.byKey(const Key('senka-info-vertical'));
    expect(
      find.descendant(
        of: vertical,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
      findsOneWidget,
    );
    final firstRow = find.byKey(const Key('senka-sortie-row-1-1'));
    await tester.ensureVisible(firstRow);
    await dragFromUntilVisible(
      tester,
      firstRow,
      find.byKey(const Key('senka-sortie-row-1-12')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('竖屏计算页从任务胶囊起拖仅滚动外层并可到 footer', (tester) async {
    await pumpSenka(tester, controller, const Size(390, 844), textScale: 1.3);
    await tester.tap(find.byKey(const Key('senka-tab-calculator')));
    await tester.pump();
    final vertical = find.byKey(const Key('senka-calculator-vertical'));
    expect(
      find.descendant(
        of: vertical,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
      findsOneWidget,
    );
    final chip = find.byKey(const Key('senka-toggle-eo-15'));
    await tester.ensureVisible(chip);
    await dragFromUntilVisible(
      tester,
      chip,
      find.byKey(const Key('senka-calculator-footer')),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机横竖屏主交互命中区均不小于 44px', (tester) async {
    for (final size in const [Size(844, 390), Size(390, 844)]) {
      await pumpSenka(tester, controller, size);
      await tester.tap(find.byKey(const Key('senka-tab-info')));
      await tester.pump();
      for (final tab in const ['info', 'calendar', 'calculator']) {
        expect(
          tester.getRect(find.byKey(Key('senka-tab-$tab'))).height,
          greaterThanOrEqualTo(30),
        );
      }
      for (final action in const ['senka-favorite-1-1', 'senka-hide-1-1']) {
        final rect = tester.getRect(find.byKey(Key(action)));
        expect(rect.width, greaterThanOrEqualTo(30));
        expect(rect.height, greaterThanOrEqualTo(30));
      }
      await tester.tap(find.byKey(const Key('senka-tab-calendar')));
      await tester.pump();
      final calendarCell = tester.getRect(
        find.byKey(const Key('calendar-cell-10')),
      );
      expect(calendarCell.width, greaterThanOrEqualTo(44));
      expect(calendarCell.height, greaterThanOrEqualTo(44));
      await tester.tap(find.byKey(const Key('senka-tab-calculator')));
      await tester.pump();
      for (final input in const ['senka-current-input', 'senka-target-input']) {
        expect(
          tester.getRect(find.byKey(Key(input))).height,
          greaterThanOrEqualTo(44),
        );
      }
      final reward = tester.getRect(
        find.byKey(const Key('senka-toggle-eo-15')),
      );
      expect(reward.width, greaterThanOrEqualTo(44));
      expect(reward.height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('390×844 在 1.3 倍文字下三页无溢出且关键内容可滚动', (tester) async {
    await pumpSenka(tester, controller, const Size(390, 844), textScale: 1.3);
    await dragUntilVisible(
      tester,
      find.byKey(const Key('senka-sortie-row-3-2')),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('senka-tab-calendar')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('senka-tab-calculator')));
    await tester.pump();
    await dragUntilVisible(
      tester,
      find.byKey(const Key('senka-calculator-footer')),
    );
    expect(tester.takeException(), isNull);
  });
}

Color? tabColor(WidgetTester tester, String name) =>
    tester.widget<Material>(find.byKey(Key('senka-tab-$name'))).color;

LinearGradient rewardGradient(WidgetTester tester, Finder toggle) {
  final boxes = tester.widgetList<DecoratedBox>(
    find.descendant(of: toggle, matching: find.byType(DecoratedBox)),
  );
  for (final box in boxes) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration &&
        decoration.border != null &&
        decoration.gradient is LinearGradient) {
      return decoration.gradient! as LinearGradient;
    }
  }
  throw StateError('Reward gradient not found');
}

String rewardTooltip(WidgetTester tester, Finder toggle) => tester
    .widget<Tooltip>(find.ancestor(of: toggle, matching: find.byType(Tooltip)))
    .message!;

Future<void> pumpCalculator(
  WidgetTester tester,
  SenkaController controller,
  Size size,
) async {
  await pumpSenka(tester, controller, size);
  await tester.tap(find.byKey(const Key('senka-tab-calculator')));
  await tester.pump();
}

class _SenkaTestHarness extends StatefulWidget {
  const _SenkaTestHarness({
    required this.controller,
    this.now,
    this.onOpenSortieLog,
  });

  final SenkaController controller;
  final DateTime? now;
  final VoidCallback? onOpenSortieLog;

  @override
  State<_SenkaTestHarness> createState() => _SenkaTestHarnessState();
}

class _SenkaTestHarnessState extends State<_SenkaTestHarness> {
  SenkaCenterMode _mode = SenkaCenterMode.info;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 38,
          child: SenkaModeTabs(
            mode: _mode,
            onChanged: (value) => setState(() => _mode = value),
          ),
        ),
        Expanded(
          child: SenkaPage(
            controller: widget.controller,
            now: widget.now,
            mode: _mode,
            onOpenSortieLog: widget.onOpenSortieLog,
          ),
        ),
      ],
    );
  }
}

Future<void> pumpSenka(
  WidgetTester tester,
  SenkaController controller,
  Size size, {
  double textScale = 1,
  VoidCallback? onOpenSortieLog,
  Locale? locale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      locale: locale ?? const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Row(
        children: [
          const SizedBox(width: 58),
          Expanded(
            child: _SenkaTestHarness(
              controller: controller,
              now: DateTime.utc(2026, 8, 10, 3),
              onOpenSortieLog: onOpenSortieLog,
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
}

Future<void> pumpSenkaWithoutNow(
  WidgetTester tester,
  SenkaController controller,
  Size size,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Row(
        children: [
          const SizedBox(width: 58),
          Expanded(child: _SenkaTestHarness(controller: controller)),
        ],
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('senka-tab-calendar')));
  await tester.pump();
}

Future<void> pumpCalendar(
  WidgetTester tester,
  SenkaState state,
  DateTime now,
  Size size,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SenkaCalendarView(state: state, now: now, compact: false),
    ),
  );
  await tester.pump();
}

String textFieldValue(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

Future<void> dragUntilVisible(WidgetTester tester, Finder target) async {
  for (
    var attempt = 0;
    attempt < 6 && target.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -350),
    );
    await tester.pump();
  }
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> dragFromUntilVisible(
  WidgetTester tester,
  Finder dragStart,
  Finder target,
) async {
  for (
    var attempt = 0;
    attempt < 8 && target.hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(dragStart, const Offset(0, -250));
    await tester.pump();
  }
  expect(target.hitTestable(), findsOneWidget);
}

SenkaState sampleState() => SenkaState.forMonth('2026-08').copyWith(
  serverOrigin: 'https://w01.kancolle-server.com',
  memberId: 123,
  nickname: '矢矧',
  calculatorCurrentSenka: 108,
  targetSenka: 3000,
  completedEoIds: {15, 25, 55},
  days: {'2026-08-10': const SenkaDayRecord(experience: 3.8)},
  sortieStats: const {
    '1-1': SenkaSortieStats(
      areaId: 1,
      mapNo: 1,
      sorties: 12,
      bossArrivals: 10,
      sWins: 8,
      aWins: 1,
    ),
    '2-1': SenkaSortieStats(
      areaId: 2,
      mapNo: 1,
      sorties: 5,
      bossArrivals: 4,
      sWins: 3,
      aWins: 1,
    ),
    '3-2': SenkaSortieStats(
      areaId: 3,
      mapNo: 2,
      sorties: 8,
      bossArrivals: 7,
      sWins: 6,
      aWins: 1,
    ),
  },
  hiddenSortieMapKeys: {'2-1'},
  rankingHistory: {
    '5': [snapshot(5, 4700), snapshot(5, 4755)],
    '20': [snapshot(20, 2200), snapshot(20, 2250)],
    '100': [snapshot(100, 1600), snapshot(100, 1610)],
    '501': [snapshot(501, 1100), snapshot(501, 1144)],
    'player': [snapshot(3916, 100), snapshot(3874, 108)],
  },
);

SenkaRankingSnapshot snapshot(int rank, double senka) => SenkaRankingSnapshot(
  rank: rank,
  senka: senka,
  capturedAt: DateTime.utc(2026, 8, 10, 6),
  localSenkaAtCapture: 0,
);

class MemorySenkaStore implements SenkaStore {
  MemorySenkaStore(this.state);
  SenkaState? state;
  @override
  Future<SenkaState?> load() async => state;
  @override
  Future<void> save(SenkaState state) async => this.state = state;
}
