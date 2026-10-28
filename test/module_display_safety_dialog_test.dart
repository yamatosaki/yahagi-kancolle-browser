import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_dialog_presentation_scope.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_resource_checklist.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_warning_dialog.dart';
import 'package:yahagi_kancolle_browser/src/settings/fleet_display_options.dart';
import 'package:yahagi_kancolle_browser/src/settings/fleet_display_settings_section.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/module_display_settings.dart';

const _guard = Key('game-safety-input-guard');

void main() {
  for (final module in moduleDisplayOptions.keys) {
    testWidgets(
      '$module native editor keeps the game route and persists/reset',
      (tester) async {
        final h = await _Harness.mount(tester, module: module, native: true);
        await h.open(tester);
        expect(h.port.shown, hasLength(1));
        expect(find.byType(Dialog), findsNothing);
        final shown = h.port.shown.single;
        expect(shown['kind'], 'moduleDisplay');
        expect(
          (shown['items'] as List),
          hasLength(
            moduleDisplayOptions[module]!.length +
                2 +
                (module == 'repair' ? 2 : 0),
          ),
        );
        h.port.toggle('appearance-logo', false);
        h.port.toggle('appearance-name', false);
        await tester.pump();
        expect(h.settings.moduleShowLogo(module), isFalse);
        expect(h.settings.moduleShowName(module), isFalse);
        final restored = await LayoutSettingsController.load(
          SharedPreferencesLayoutSettingsStore(),
        );
        expect(restored.moduleShowLogo(module), isFalse);
        expect(restored.moduleShowName(module), isFalse);
        restored.dispose();
        if (moduleDisplayOptions[module]!.isNotEmpty) {
          final field = moduleDisplayOptions[module]!.keys.first;
          h.port.toggle('field-$field', false);
          expect(
            h.settings.moduleDisplayFields(module),
            isNot(contains(field)),
          );
        }
        if (module == 'repair') {
          h.port.toggle('fleet-name-number', true);
          expect(
            h.settings.repairFleetSelectorLabelMode,
            FleetSelectorLabelMode.number,
          );
          h.port.toggle('fleet-name-number', false);
          expect(h.row('fleet-name-number')['checked'], isTrue);
        }
        h.port.reset();
        await tester.pump();
        expect(h.settings.moduleShowLogo(module), isTrue);
        expect(h.settings.moduleShowName(module), isTrue);
        expect(
          h.settings.moduleDisplayFields(module),
          moduleDisplayOptions[module]!.keys.toSet(),
        );
        if (module == 'repair') {
          expect(
            h.settings.repairFleetSelectorLabelMode,
            FleetSelectorLabelMode.customName,
          );
        }
        h.port.finish();
        await tester.pumpAndSettle();
        expect(h.completed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final hd in [false, true]) {
    testWidgets(
      'native fleet editor keeps ${hd ? 7 : 5} summary limit and mutual choices',
      (tester) async {
        final h = await _Harness.mount(
          tester,
          module: 'fleet',
          native: true,
          hd: hd,
        );
        await h.open(tester);
        expect(h.port.shown, hasLength(1));
        expect(find.byType(Dialog), findsNothing);
        expect(h.port.shown.single['kind'], 'fleetDisplay');
        final current = hd
            ? h.settings.hdFleetDisplayFields
            : h.settings.fleetDisplayFields;
        final limit = hd ? 7 : 5;
        expect(current.intersection(summaryFields), hasLength(limit));
        final disabled = summaryFields.firstWhere(
          (field) => !current.contains(field),
        );
        expect(h.row('field-$disabled')['enabled'], isFalse);
        h.port.toggle('field-$disabled', true);
        expect(
          (hd ? h.settings.hdFleetDisplayFields : h.settings.fleetDisplayFields)
              .contains(disabled),
          isFalse,
        );
        final selected = current.intersection(summaryFields).first;
        h.port.toggle('field-$selected', false);
        expect(h.row('field-$disabled')['enabled'], isTrue);
        h.port.toggle('field-$disabled', true);
        expect(
          (hd ? h.settings.hdFleetDisplayFields : h.settings.fleetDisplayFields)
              .intersection(summaryFields),
          hasLength(limit),
        );
        h.port.toggle('fleet-name-number', true);
        expect(
          h.settings.fleetSelectorLabelMode,
          FleetSelectorLabelMode.number,
        );
        h.port.toggle('fleet-name-number', false);
        expect(h.row('fleet-name-number')['checked'], isTrue);
        h.port.toggle('ship-type-abbreviation', true);
        expect(
          h.settings.fleetShipTypeLabelMode,
          FleetShipTypeLabelMode.abbreviation,
        );
        h.port.toggle('appearance-logo', false);
        h.port.reset();
        await tester.pump();
        expect(h.settings.moduleShowLogo('fleet'), isTrue);
        expect(
          h.settings.fleetSelectorLabelMode,
          FleetSelectorLabelMode.customName,
        );
        expect(
          (hd ? h.settings.hdFleetDisplayFields : h.settings.fleetDisplayFields)
              .intersection(summaryFields),
          hasLength(limit),
        );
        h.port.finish();
        await tester.pumpAndSettle();
      },
    );
  }

  for (final module in ['battle', 'fleet']) {
    for (final close in ['button', 'outside', 'back']) {
      testWidgets(
        '$module Flutter $close protects game touches until close settles',
        (tester) async {
          final h = await _Harness.mount(tester, module: module, native: false);
          await h.open(tester);
          expect(find.byType(Dialog), findsOneWidget);
          if (close == 'button') {
            await tester.tap(find.byKey(Key('$module-display-close')));
          } else if (close == 'outside') {
            await tester.tapAt(const Offset(3, 3));
          } else {
            await tester.binding.handlePopRoute();
          }
          await tester.pump();
          expect(find.byKey(_guard), findsOneWidget);
          expect(h.completed, isFalse);
          await tester.tapAt(const Offset(4, 300));
          expect(h.gameTouches, 0);
          await tester.pump(const Duration(milliseconds: 599));
          expect(find.byKey(_guard), findsOneWidget);
          await tester.pumpAndSettle();
          expect(h.completed, isTrue);
          await tester.tapAt(const Offset(4, 300));
          expect(h.gameTouches, 1);
        },
      );
    }
  }

  testWidgets('module editor protects a pointer held before Back', (
    tester,
  ) async {
    final h = await _Harness.mount(tester, module: 'battle', native: false);
    await h.open(tester);
    final pointer = await tester.startGesture(
      tester.getCenter(find.byType(Dialog)),
      pointer: 41,
    );
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(_guard), findsOneWidget);
    expect(h.completed, isFalse);
    await pointer.up();
    await tester.pump(const Duration(milliseconds: 599));
    expect(h.completed, isFalse);
    await tester.pumpAndSettle();
    expect(h.completed, isTrue);
    expect(h.gameTouches, 0);
  });

  for (final change in ['lock', 'mode', 'owner']) {
    testWidgets('native settings $change cancellation rejects late edits', (
      tester,
    ) async {
      final h = await _Harness.mount(tester, module: 'battle', native: true);
      await h.open(tester);
      expect(h.port.shown, hasLength(1));
      if (change == 'lock') await h.settings.setUiLocked(true);
      if (change == 'mode') h.native.value = false;
      if (change == 'owner') h.visible.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(h.port.dismissed, hasLength(1));
      h.port.toggle('appearance-logo', false);
      expect(h.settings.moduleShowLogo('battle'), isTrue);
      expect(h.completed, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('locked or unavailable settings do not open an editor', (
    tester,
  ) async {
    final h = await _Harness.mount(tester, module: 'battle', native: true);
    await h.settings.setUiLocked(true);
    await h.open(tester);
    expect(h.port.shown, isEmpty);
    expect(find.byType(Dialog), findsNothing);
  });
}

class _Harness {
  _Harness(this.settings, this.module, bool isNative, this.hd)
    : native = ValueNotifier(isNative);
  final LayoutSettingsController settings;
  final String module;
  final bool hd;
  final ValueNotifier<bool> native;
  final visible = ValueNotifier(true);
  final port = _Port();
  bool completed = false;
  int gameTouches = 0;

  Map<String, Object?> row(String id) => (port.current['items'] as List)
      .cast<Map<String, Object?>>()
      .singleWhere((item) => item['id'] == id);

  static Future<_Harness> mount(
    WidgetTester tester, {
    required String module,
    required bool native,
    bool hd = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final h = _Harness(
      await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      ),
      module,
      native,
      hd,
    );
    addTearDown(h.settings.dispose);
    addTearDown(h.native.dispose);
    addTearDown(h.visible.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ValueListenableBuilder<bool>(
          valueListenable: h.native,
          builder: (context, native, _) => GameDialogPresentationScope(
            nativeActivity: native,
            nativeChecklistPort: h.port,
            child: Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => h.gameTouches++,
                child: ValueListenableBuilder<bool>(
                  valueListenable: h.visible,
                  builder: (context, visible, _) => visible
                      ? Builder(
                          builder: (context) => Center(
                            child: TextButton(
                              onPressed: () {
                                final future = module == 'fleet'
                                    ? showFleetDisplaySettings(
                                        context,
                                        h.settings,
                                        twoColumns: hd,
                                      )
                                    : showModuleDisplaySettings(
                                        context,
                                        h.settings,
                                        module,
                                      );
                                unawaited(
                                  future.then((_) => h.completed = true),
                                );
                              },
                              child: const Text('open'),
                            ),
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return h;
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    gameTouches = 0;
  }
}

class _Port implements NativeGameResourceChecklistPort {
  final source = StreamController<Map<String, Object?>>.broadcast(sync: true);
  final shown = <Map<String, Object?>>[];
  final dismissed = <Map<String, Object?>>[];
  final result = Completer<NativeGameWarningAction?>();
  Map<String, Object?> current = {};
  int sequence = 0;
  @override
  Stream<Map<String, Object?>> get events => source.stream;
  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> payload) {
    current = payload;
    shown.add(payload);
    return result.future;
  }

  @override
  Future<void> update(Map<String, Object?> payload) async => current = payload;
  @override
  Future<void> dismiss({required String kind, required int id}) async {
    dismissed.add({'kind': kind, 'id': id});
    if (!result.isCompleted) result.complete(null);
  }

  void toggle(String id, bool checked) => source.add({
    'kind': current['kind'],
    'id': current['id'],
    'event': 'toggle',
    'itemId': id,
    'checked': checked,
    'changeId': ++sequence,
  });
  void reset() => source.add({
    'kind': current['kind'],
    'id': current['id'],
    'event': 'reset',
    'changeId': ++sequence,
  });
  void finish() {
    if (!result.isCompleted) {
      result.complete(NativeGameWarningAction.acknowledge);
    }
  }
}
