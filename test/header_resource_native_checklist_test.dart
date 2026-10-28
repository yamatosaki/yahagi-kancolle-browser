import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_dialog_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_resource_checklist.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_warning_dialog.dart';
import 'package:yahagi_kancolle_browser/src/fleet/header_resource_catalog.dart';
import 'package:yahagi_kancolle_browser/src/fleet/resource_grid.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/settings/header_resource_settings.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

void main() {
  testWidgets('native checklist carries every resource and symbol icon', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    await h.open(tester);
    final rows = h.port.shown.single['items']! as List;
    for (final spec in headerResourceCatalog) {
      final row = rows.singleWhere((dynamic row) => row['id'] == spec.id);
      expect(row['iconAsset'], spec.assetPath, reason: spec.id);
      expect(row.containsKey('iconCodePoint'), isFalse, reason: spec.id);
    }
    final symbols = {
      headerSenkaId: Icons.emoji_events_rounded,
      headerAnchorageTimerId: Icons.anchor_rounded,
      headerNosakiTimerId: Icons.restaurant_rounded,
      headerFrameRefreshId: Icons.refresh_rounded,
      headerGameRefreshId: Icons.refresh_rounded,
      headerShipCapacityId: Icons.directions_boat_filled_rounded,
      headerEquipmentCapacityId: Icons.build_rounded,
    };
    for (final entry in symbols.entries) {
      final row = rows.singleWhere((dynamic row) => row['id'] == entry.key);
      expect(row['iconCodePoint'], entry.value.codePoint, reason: entry.key);
      expect(row.containsKey('iconAsset'), isFalse, reason: entry.key);
      expect(
        row['iconColor'],
        entry.key == headerSenkaId ? 0xffe0b25c : 0xff9fb3bf,
        reason: entry.key,
      );
    }
    h.port.emit(h.port.shown.single, headerSenkaId, false);
    final updatedRows = h.port.updated.last['items']! as List;
    expect(
      updatedRows.first['iconCodePoint'],
      Icons.emoji_events_rounded.codePoint,
    );
    expect(updatedRows.first['checked'], isFalse);
    h.port.results.single.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'native checklist keeps the game route and saves changes immediately',
    (tester) async {
      final h = await _Harness.mount(tester);
      await h.open(tester);
      expect(h.port.shown, hasLength(1));
      expect(find.byType(Dialog), findsNothing);
      final payload = h.port.shown.single;
      expect(payload['kind'], 'headerResources');
      expect(
        (payload['items']! as List),
        hasLength(allHeaderResourceIds.length),
      );
      expect(
        h.settings.visibleHeaderResourceIds,
        isNot(contains(headerGameRefreshId)),
      );
      h.port.emit(payload, headerGameRefreshId, true);
      await tester.pump();
      expect(
        h.settings.visibleHeaderResourceIds,
        contains(headerGameRefreshId),
      );
      final reloaded = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      expect(reloaded.visibleHeaderResourceIds, contains(headerGameRefreshId));
      reloaded.dispose();
      expect(h.port.updated, isNotEmpty);
      h.port.results.single.complete(NativeGameWarningAction.acknowledge);
      await tester.pumpAndSettle();
      expect(h.gameRefreshes, 0);
      expect(h.frameRefreshes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rapid native changes acknowledge their sequence before updates',
    (tester) async {
      final h = await _Harness.mount(tester);
      await h.open(tester);
      final payload = h.port.shown.single;
      h.port.emit(payload, headerSenkaId, false);
      expect(h.port.updated.first['appliedChangeId'], 1);
      expect(
        h.settings.visibleHeaderResourceIds,
        isNot(contains(headerSenkaId)),
      );
      h.port.emit(payload, headerSenkaId, true);
      expect(h.port.updated.last['appliedChangeId'], 2);
      expect(h.settings.visibleHeaderResourceIds, contains(headerSenkaId));
      final updates = h.port.updated.length;
      h.port.source.add({
        'kind': 'headerResources',
        'id': payload['id'],
        'event': 'toggle',
        'itemId': headerSenkaId,
        'checked': false,
        'changeId': 1,
      });
      expect(h.port.updated, hasLength(updates));
      expect(h.settings.visibleHeaderResourceIds, contains(headerSenkaId));
      h.port.results.single.complete(NativeGameWarningAction.acknowledge);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'old ids, kinds, unknown items and malformed sequences cannot edit',
    (tester) async {
      final h = await _Harness.mount(tester);
      await h.open(tester);
      final payload = h.port.shown.single;
      final initial = h.settings.visibleHeaderResourceIds;
      for (final patch in [
        {'id': (payload['id']! as int) + 1},
        {'kind': 'collapsedResources'},
        {'itemId': 'not-a-resource'},
        {'checked': 'false'},
        {'changeId': 0},
        {'changeId': 1.5},
        {'event': 'reset'},
      ]) {
        h.port.source.add({
          'kind': 'headerResources',
          'id': payload['id'],
          'event': 'toggle',
          'itemId': headerSenkaId,
          'checked': false,
          'changeId': 99,
          ...patch,
        });
      }
      expect(h.settings.visibleHeaderResourceIds, initial);
      expect(h.port.updated, isEmpty);
      h.port.emit(payload, headerSenkaId, false);
      expect(
        h.settings.visibleHeaderResourceIds,
        isNot(contains(headerSenkaId)),
      );
      h.port.results.single.complete(NativeGameWarningAction.acknowledge);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('locking cancels only this editor and retains saved choices', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    await h.open(tester);
    final old = h.port.shown.single;
    h.port.emit(old, headerGameRefreshId, true);
    await h.settings.setUiLocked(true);
    await tester.pumpAndSettle();
    expect(h.port.dismissed.single, {
      'kind': 'headerResources',
      'id': old['id'],
    });
    h.port.emit(old, headerGameRefreshId, false);
    expect(h.settings.visibleHeaderResourceIds, contains(headerGameRefreshId));
    await h.settings.setUiLocked(false);
    unawaited(h.key.currentState!.openHeaderChecklist());
    await tester.pumpAndSettle();
    expect(h.port.shown, hasLength(2));
    final next = h.port.shown.last;
    expect(next['id'], isNot(old['id']));
    h.port.results.first.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(h.port.dismissed, hasLength(1));
    h.port.emit(next, headerGameRefreshId, false);
    expect(
      h.settings.visibleHeaderResourceIds,
      isNot(contains(headerGameRefreshId)),
    );
    h.port.results.last.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
  });

  for (final change in ['mode', 'busy', 'owner']) {
    testWidgets('$change cancellation rejects late native changes', (
      tester,
    ) async {
      final h = await _Harness.mount(tester);
      await h.open(tester);
      final old = h.port.shown.single;
      if (change == 'mode') h.nativeActivity = false;
      if (change == 'busy') h.enabled = false;
      if (change == 'owner') h.showBar = false;
      h.revision.value++;
      await tester.pumpAndSettle();
      expect(h.port.dismissed.single, {
        'kind': 'headerResources',
        'id': old['id'],
      });
      h.port.emit(old, headerGameRefreshId, true);
      expect(
        h.settings.visibleHeaderResourceIds,
        isNot(contains(headerGameRefreshId)),
      );
      h.port.results.single.complete(NativeGameWarningAction.acknowledge);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('state and order changes update the owned native editor', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    await h.open(tester);
    h.state = const GameState(
      hasPortData: true,
      maxShipCount: 99,
      maxEquipmentCount: 123,
    );
    h.revision.value++;
    await tester.pumpAndSettle();
    final items = h.port.updated.last['items']! as List;
    expect(
      items.singleWhere(
        (dynamic row) => row['id'] == headerShipCapacityId,
      )['value'],
      '0 / 99',
    );
    await h.settings.setHeaderResourceOrder([
      headerGameRefreshId,
      ...h.settings.headerResourceOrder,
    ]);
    expect(
      (h.port.updated.last['items']! as List).first['id'],
      headerGameRefreshId,
    );
    h.port.results.single.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
  });

  testWidgets('collapsed choices use their own kind and preserve reset', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    await h.settings.setCollapsedPanelResourceIds([headerSenkaId]);
    unawaited(h.key.currentState!.openCollapsedChecklist());
    await tester.pumpAndSettle();
    final payload = h.port.shown.single;
    expect(payload['kind'], 'collapsedResources');
    expect(payload['resetLabel'], isA<String>());
    h.port.emit(payload, headerAnchorageTimerId, true);
    expect(
      h.settings.collapsedPanelResourceIds,
      contains(headerAnchorageTimerId),
    );
    h.port.source.add({
      'kind': 'collapsedResources',
      'id': payload['id'],
      'event': 'reset',
      'changeId': 2,
    });
    expect(h.settings.collapsedPanelResourceIds, isNull);
    expect(h.port.updated.last['appliedChangeId'], 2);
    h.port.results.single.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'the public editor reads current values after it is already open',
    (tester) async {
      final h = await _Harness.mount(tester);
      final presentation = showHeaderResourceChecklist(
        context: tester.element(find.byType(CompactResourceBar)),
        controller: h.settings,
        stateProvider: () => h.state,
        senkaProvider: () => h.senka,
        rankProvider: () => h.rank,
        nosakiSparkleStartedAtProvider: () => h.nosakiStarted,
        valueChanges: h.revision,
      )!;
      addTearDown(presentation.cancel);
      await tester.pumpAndSettle();
      h.senka = 21.25;
      h.rank = 42;
      h.nosakiStarted = DateTime.now().toUtc().subtract(
        const Duration(minutes: 2),
      );
      h.revision.value++;
      await tester.pumpAndSettle();
      final values = h.port.updated.last['items']! as List;
      expect(
        values.singleWhere(
          (dynamic row) => row['id'] == headerSenkaId,
        )['value'],
        '21.3（#42）',
      );
      expect(
        values.singleWhere(
          (dynamic row) => row['id'] == headerNosakiTimerId,
        )['value'],
        startsWith('00:02:'),
      );
      h.nosakiStarted = null;
      h.revision.value++;
      await tester.pumpAndSettle();
      final reset = h.port.updated.last['items']! as List;
      expect(
        reset.singleWhere(
          (dynamic row) => row['id'] == headerNosakiTimerId,
        )['value'],
        '--:--:--',
      );
      expect(h.port.shown, hasLength(1));
      h.port.results.single.complete(NativeGameWarningAction.acknowledge);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a timer started after opening continues to tick without reopening',
    (tester) async {
      final h = await _Harness.mount(tester);
      await h.open(tester);
      h.nosakiStarted = DateTime.now().toUtc().subtract(
        const Duration(minutes: 2),
      );
      h.revision.value++;
      await tester.pumpAndSettle();
      String elapsed() =>
          (h.port.updated.last['items']! as List).singleWhere(
                (dynamic row) => row['id'] == headerNosakiTimerId,
              )['value']
              as String;
      final before = elapsed();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(elapsed(), isNot(before));
      expect(h.port.shown, hasLength(1));
      h.port.results.single.complete(NativeGameWarningAction.acknowledge);
      await tester.pumpAndSettle();
    },
  );
}

class _Harness {
  _Harness(this.settings);
  final LayoutSettingsController settings;
  final port = _Port();
  final key = GlobalKey<CompactResourceBarState>();
  final revision = ValueNotifier(0);
  bool nativeActivity = true;
  bool enabled = true;
  bool showBar = true;
  GameState state = const GameState();
  double? senka;
  int? rank;
  DateTime? nosakiStarted;
  int gameRefreshes = 0;
  int frameRefreshes = 0;

  static Future<_Harness> mount(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await LayoutSettingsController.load(
      SharedPreferencesLayoutSettingsStore(),
    );
    final h = _Harness(settings);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
      h.revision.dispose();
      await h.port.source.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ValueListenableBuilder<int>(
          valueListenable: h.revision,
          builder: (context, _, _) => GameDialogPresentationScope(
            nativeActivity: h.nativeActivity,
            presentationEnabled: h.enabled,
            nativeChecklistPort: h.port,
            child: Scaffold(
              body: h.showBar
                  ? CompactResourceBar(
                      key: h.key,
                      state: h.state,
                      senka: h.senka,
                      rank: h.rank,
                      nosakiSparkleStartedAt: h.nosakiStarted,
                      settingsController: settings,
                      initiallyEditing: true,
                      onGameRefreshTap: () => h.gameRefreshes++,
                      onFrameRefreshTap: () => h.frameRefreshes++,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    return h;
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('header-resource-filter')));
    await tester.pumpAndSettle();
  }
}

class _Port implements NativeGameResourceChecklistPort {
  final source = StreamController<Map<String, Object?>>.broadcast(sync: true);
  final shown = <Map<String, Object?>>[];
  final updated = <Map<String, Object?>>[];
  final dismissed = <Map<String, Object?>>[];
  final results = <Completer<NativeGameWarningAction?>>[];
  int _changeId = 0;

  @override
  Stream<Map<String, Object?>> get events => source.stream;
  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> payload) {
    shown.add(payload);
    final result = Completer<NativeGameWarningAction?>();
    results.add(result);
    return result.future;
  }

  @override
  Future<void> update(Map<String, Object?> payload) async =>
      updated.add(payload);
  @override
  Future<void> dismiss({required String kind, required int id}) async =>
      dismissed.add({'kind': kind, 'id': id});

  void emit(Map<String, Object?> payload, String itemId, bool checked) =>
      source.add({
        'kind': payload['kind'],
        'id': payload['id'],
        'event': 'toggle',
        'itemId': itemId,
        'checked': checked,
        'changeId': ++_changeId,
      });
}
