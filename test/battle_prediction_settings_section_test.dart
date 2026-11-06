import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings_section.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

Future<void> _pumpSettings(
  WidgetTester tester,
  BattlePredictionSettingsController controller, {
  Locale locale = const Locale('zh'),
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData.dark(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: TopNoticeHost(
        child: SingleChildScrollView(
          child: BattlePredictionSettingsSection(controller: controller),
        ),
      ),
    ),
  ),
);

Future<void> _openOrderSheet(WidgetTester tester) async {
  final action = find.byKey(const Key('battle-section-order'));
  await tester.ensureVisible(action);
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Finder _move(String section, String direction) =>
    find.byKey(Key('battle-section-$direction-$section'));

List<BattlePredictionSection> _visibleOrder(WidgetTester tester) {
  final sections = BattlePredictionSection.values.toList();
  sections.sort((a, b) {
    final first = tester.getTopLeft(
      find.byKey(Key('battle-section-row-${a.name}')),
    );
    final second = tester.getTopLeft(
      find.byKey(Key('battle-section-row-${b.name}')),
    );
    return first.dy.compareTo(second.dy);
  });
  return sections;
}

void main() {
  testWidgets('fleet information sync can wait for settlement and reload', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    await _pumpSettings(tester, controller);
    expect(find.text('编队信息同步'), findsOneWidget);
    final immediate = find.text('即时同步');
    expect(immediate.hitTestable(), findsOneWidget);
    await tester.tap(immediate.hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('结算同步').hitTestable().last);
    await tester.pumpAndSettle();

    final reloaded = await BattlePredictionSettingsController.load(store);
    addTearDown(reloaded.dispose);
    await _pumpSettings(tester, reloaded);
    expect(find.text('结算同步').hitTestable(), findsOneWidget);
  });

  testWidgets('section order replaces the old position dropdown', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    await _pumpSettings(tester, controller);
    expect(find.byType(DropdownButton<EnemyPreviewPosition>), findsNothing);
    final order = find.byKey(const Key('battle-section-order'));
    expect(order, findsOneWidget);
    expect(find.text('信息区顺序'), findsOneWidget);
    expect(find.text('调整信息区显示顺序'), findsOneWidget);
    expect(find.text('调整'), findsOneWidget);

    await tester.tap(order);
    await tester.pumpAndSettle();
    expect(find.text('点击上下箭头调整，自动保存'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(_visibleOrder(tester), defaultBattlePredictionSectionOrder);
    expect(
      tester.widget<IconButton>(_move('sortieMap', 'up')).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(_move('predictionResult', 'down')).onPressed,
      isNull,
    );
    final targetSize = tester.getSize(_move('enemyPreview', 'up'));
    expect(targetSize.width, greaterThanOrEqualTo(44));
    expect(targetSize.height, greaterThanOrEqualTo(44));
  });

  testWidgets('moves save immediately, survive reload and reset to default', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);
    await _pumpSettings(tester, controller);
    await _openOrderSheet(tester);

    await tester.tap(_move('enemyPreview', 'down'));
    await tester.pumpAndSettle();
    await tester.tap(_move('sortieMap', 'down'));
    await tester.pumpAndSettle();
    const changedOrder = <BattlePredictionSection>[
      BattlePredictionSection.predictionResult,
      BattlePredictionSection.sortieMap,
      BattlePredictionSection.enemyPreview,
    ];
    expect(_visibleOrder(tester), changedOrder);
    expect(controller.sectionOrder, changedOrder);
    expect(await store.loadSectionOrder(), changedOrder);
    await tester.tap(find.byKey(const Key('battle-section-order-done')));
    await tester.pumpAndSettle();
    expect(find.text('调整信息区显示顺序'), findsOneWidget);

    final reloaded = await BattlePredictionSettingsController.load(store);
    addTearDown(reloaded.dispose);
    await _pumpSettings(tester, reloaded);
    expect(find.text('调整信息区显示顺序'), findsOneWidget);
    await _openOrderSheet(tester);
    await tester.tap(find.byKey(const Key('battle-section-order-reset')));
    await tester.pumpAndSettle();
    expect(_visibleOrder(tester), defaultBattlePredictionSectionOrder);
    expect(await store.loadSectionOrder(), defaultBattlePredictionSectionOrder);
  });

  testWidgets(
    'a pending save blocks duplicate moves and failed saves stay open',
    (tester) async {
      final store = _ControlledOrderStore();
      final controller = await BattlePredictionSettingsController.load(store);
      addTearDown(controller.dispose);
      await _pumpSettings(tester, controller);
      await _openOrderSheet(tester);
      final pendingSave = Completer<void>();
      store.pendingSave = pendingSave.future;
      await tester.tap(_move('enemyPreview', 'down'));
      await tester.pump();
      await tester.tap(_move('enemyPreview', 'down'));
      await tester.pump();
      expect(store.saveCalls, 1);
      expect(controller.sectionOrder, defaultBattlePredictionSectionOrder);
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('battle-section-order-reset')),
            )
            .onPressed,
        isNull,
      );
      pendingSave.complete();
      await tester.pumpAndSettle();
      final savedOrder = controller.sectionOrder;
      store.pendingSave = null;
      store.failSave = true;
      await tester.tap(_move('sortieMap', 'down'));
      await tester.pumpAndSettle();
      expect(store.saveCalls, 2);
      expect(controller.sectionOrder, savedOrder);
      expect(_visibleOrder(tester), savedOrder);
      expect(
        find.byKey(const Key('battle-section-order-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('battle-section-order-error')),
        findsOneWidget,
      );
      expect(find.byKey(topNoticeKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in <double>[240, 280, 360]) {
    testWidgets('order sheet fits ${width.toInt()}px and short landscape', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 320);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final controller = await BattlePredictionSettingsController.load(
        MemoryBattlePredictionSettingsStore(),
      );
      addTearDown(controller.dispose);
      await _pumpSettings(tester, controller, textScale: 1.6);
      await _openOrderSheet(tester);
      expect(tester.takeException(), isNull);
      final sheet = tester.getRect(
        find.byKey(const Key('battle-section-order-sheet')),
      );
      expect(sheet.left, greaterThanOrEqualTo(0));
      expect(sheet.right, lessThanOrEqualTo(width));
      expect(sheet.top, greaterThanOrEqualTo(24));
      expect(sheet.bottom, lessThanOrEqualTo(320));
      final done = find.byKey(const Key('battle-section-order-done'));
      await tester.ensureVisible(done);
      expect(tester.getBottomRight(done).dy, lessThanOrEqualTo(300));
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('battle-section-order-sheet')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in <Locale>[
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ja'),
  ]) {
    testWidgets('order labels are localized for $locale', (tester) async {
      final controller = await BattlePredictionSettingsController.load(
        MemoryBattlePredictionSettingsStore(),
      );
      addTearDown(controller.dispose);
      await _pumpSettings(tester, controller, locale: locale);
      await _openOrderSheet(tester);
      final l10n = lookupAppLocalizations(locale);
      expect(find.text(l10n.battleSectionOrderHint), findsOneWidget);
      expect(find.text(l10n.battleSectionSortieMap), findsOneWidget);
      expect(find.text(l10n.battleSectionEnemyPreview), findsOneWidget);
      expect(find.text(l10n.battleSectionPredictionResult), findsOneWidget);
      expect(
        tester.widget<IconButton>(_move('sortieMap', 'down')).tooltip,
        l10n.battleSectionOrderMoveDown(l10n.battleSectionSortieMap),
      );
    });
  }

  testWidgets('order sheet blocks outside taps and preserves Back and drag', (
    tester,
  ) async {
    final controller = await BattlePredictionSettingsController.load(
      MemoryBattlePredictionSettingsStore(),
    );
    addTearDown(controller.dispose);
    await _pumpSettings(tester, controller);
    await _openOrderSheet(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('battle-section-order-sheet')), findsNothing);
    await _openOrderSheet(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('battle-section-order-sheet')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('battle-section-order-sheet')),
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('battle-section-order-sheet')), findsNothing);
    expect(controller.sectionOrder, defaultBattlePredictionSectionOrder);
  });

  testWidgets('shows only POI display options and persists both switches', (
    tester,
  ) async {
    final store = MemoryBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BattlePredictionSettingsSection(controller: controller),
        ),
      ),
    );

    expect(find.byType(SegmentedButton), findsNothing);
    expect(find.text('增强模式'), findsNothing);
    expect(find.text('轻量模式'), findsNothing);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(
      tester
          .widget<Switch>(
            find.byKey(const Key('battle-enemy-preview-portraits')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('battle-last-formation-hint')))
          .value,
      isTrue,
    );
    expect(find.text('在未卜先知中显示战前敌方立绘。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('battle-enemy-preview-portraits')));
    await tester.pump();

    expect(controller.enemyPortraitsEnabled, isFalse);
    expect(await store.loadEnemyPortraitsEnabled(), isFalse);

    await tester.tap(find.byKey(const Key('battle-last-formation-hint')));
    await tester.pump();

    expect(controller.lastFormationHintEnabled, isFalse);
    expect(await store.loadLastFormationHintEnabled(), isFalse);
  });
}

class _ControlledOrderStore implements BattlePredictionSettingsStore {
  final _delegate = MemoryBattlePredictionSettingsStore();
  Future<void>? pendingSave;
  bool failSave = false;
  int saveCalls = 0;

  @override
  Future<void> initialize() => _delegate.initialize();

  @override
  Future<bool> loadEnemyPortraitsEnabled() =>
      _delegate.loadEnemyPortraitsEnabled();

  @override
  Future<void> saveEnemyPortraitsEnabled(bool enabled) =>
      _delegate.saveEnemyPortraitsEnabled(enabled);

  @override
  Future<bool> loadLastFormationHintEnabled() =>
      _delegate.loadLastFormationHintEnabled();

  @override
  Future<void> saveLastFormationHintEnabled(bool enabled) =>
      _delegate.saveLastFormationHintEnabled(enabled);

  @override
  Future<EnemyPreviewPosition> loadEnemyPreviewPosition() =>
      _delegate.loadEnemyPreviewPosition();

  @override
  Future<void> saveEnemyPreviewPosition(EnemyPreviewPosition position) =>
      _delegate.saveEnemyPreviewPosition(position);

  @override
  Future<FleetInformationSyncMode> loadFleetInformationSyncMode() =>
      _delegate.loadFleetInformationSyncMode();

  @override
  Future<void> saveFleetInformationSyncMode(FleetInformationSyncMode mode) =>
      _delegate.saveFleetInformationSyncMode(mode);

  @override
  Future<List<BattlePredictionSection>?> loadSectionOrder() =>
      _delegate.loadSectionOrder();

  @override
  Future<void> saveSectionOrder(List<BattlePredictionSection> order) async {
    saveCalls++;
    await pendingSave;
    if (failSave) throw StateError('save failed');
    await _delegate.saveSectionOrder(order);
  }
}
