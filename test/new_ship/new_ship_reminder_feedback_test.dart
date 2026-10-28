import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_warning_dialog.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_feedback.dart';
import 'package:yahagi_kancolle_browser/src/new_ship/new_ship_reminder_store.dart';

import '../fixtures/kcsapi_fixtures.dart';

void main() {
  testWidgets('an already queued ship is presented on the first mount', (
    tester,
  ) async {
    final fixture = await _Fixture.mount(tester, preexistingMasterId: 7);
    expect(fixture.port.shown, hasLength(1));
    fixture.port.pending.single.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(fixture.controller.currentAlert, isNull);
  });

  testWidgets(
    'controller replacement detaches the old listener and ignores its late action',
    (tester) async {
      final fixture = await _Fixture.mount(tester);
      await fixture.warn(tester, 7);
      final previous = fixture.controller;
      final previousKey = previous.currentAlert!.key;
      final next = NewShipReminderController(
        stateProvider: () => fixture.state,
        accountSession: fixture.account,
        store: NewShipReminderStore(await SharedPreferences.getInstance()),
        onPublish: (_) {},
      );
      fixture.controllers.add(next);
      fixture.controller = next;
      fixture.revision.value++;
      await tester.pumpAndSettle();
      // Verify ownership of the feedback listener after replacing the controller.
      // ignore: invalid_use_of_protected_member
      expect(previous.hasListeners, isFalse);
      // ignore: invalid_use_of_protected_member
      expect(next.hasListeners, isTrue);
      expect(fixture.port.dismissed, hasLength(1));
      await fixture.warn(tester, 9);
      final nextKey = next.currentAlert!.key;
      fixture.port.pending.first.complete(NativeGameWarningAction.acknowledge);
      await tester.pumpAndSettle();
      expect(previous.currentAlert?.key, previousKey);
      expect(next.currentAlert?.key, nextKey);
      fixture.port.pending.last.complete(NativeGameWarningAction.acknowledge);
      await tester.pumpAndSettle();
      expect(next.currentAlert, isNull);
    },
  );

  testWidgets('native ship confirmation preserves the game route', (
    tester,
  ) async {
    final fixture = await _Fixture.mount(tester);
    await fixture.warn(tester, 7);
    expect(fixture.port.shown, hasLength(1));
    expect(find.byKey(const Key('new-ship-alert-dialog')), findsNothing);
    fixture.port.pending.single.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(fixture.controller.currentAlert, isNull);
    expect(fixture.port.dismissed, isEmpty);
    expect(tester.element(find.byKey(const Key('game'))), same(fixture.game));
  });

  testWidgets('a newer ship waits and cannot be acknowledged by the old key', (
    tester,
  ) async {
    final fixture = await _Fixture.mount(tester);
    await fixture.warn(tester, 7);
    final oldKey = fixture.controller.currentAlert!.key;
    await fixture.warn(tester, 9);
    final newKey = fixture.controller.currentAlert!.key;
    expect(newKey, isNot(oldKey));
    expect(fixture.port.shown, hasLength(1));
    fixture.port.pending.first.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(fixture.controller.currentAlert?.key, newKey);
    expect(fixture.port.shown, hasLength(2));
    fixture.port.pending.last.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(fixture.controller.currentAlert, isNull);
  });

  for (final reason in ['account', 'dispose', 'mode']) {
    testWidgets(
      '$reason cancels the old ship presentation and rejects its late confirmation',
      (tester) async {
        final fixture = await _Fixture.mount(tester);
        await fixture.warn(tester, 7);
        final oldKey = fixture.controller.currentAlert!.key;
        if (reason == 'account') {
          fixture.state = fixture.state.copyWith(memberId: 2002);
          fixture.account.selectMember(2002);
        } else if (reason == 'dispose') {
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        } else {
          fixture.enabled.value = false;
        }
        await tester.pumpAndSettle();
        expect(fixture.port.dismissed, hasLength(1));
        fixture.port.pending.first.complete(
          NativeGameWarningAction.acknowledge,
        );
        await tester.pumpAndSettle();
        if (reason == 'account') {
          expect(fixture.controller.currentAlert, isNull);
          await fixture.warn(tester, 9);
          expect(fixture.port.shown, hasLength(2));
        } else {
          expect(fixture.controller.currentAlert?.key, oldKey);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'mode transition resumes the pending ship using Flutter without a stale native ack',
    (tester) async {
      final fixture = await _Fixture.mount(tester);
      await fixture.warn(tester, 7);
      fixture.enabled.value = false;
      await tester.pumpAndSettle();
      fixture.native.value = false;
      fixture.enabled.value = true;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('new-ship-alert-dialog')), findsOneWidget);
      fixture.port.pending.first.complete(NativeGameWarningAction.acknowledge);
      await tester.pumpAndSettle();
      expect(fixture.controller.currentAlert, isNotNull);
      await tester.tap(find.byKey(const Key('new-ship-reminder-acknowledge')));
      await tester.pumpAndSettle();
      expect(fixture.controller.currentAlert, isNull);
    },
  );

  for (final close in ['button', 'outside', 'back']) {
    testWidgets('Flutter $close uses input protection and acknowledges once', (
      tester,
    ) async {
      final fixture = await _Fixture.mount(tester, native: false);
      await fixture.warn(tester, 7);
      expect(find.byKey(const Key('new-ship-alert-dialog')), findsOneWidget);
      if (close == 'button') {
        await tester.tap(
          find.byKey(const Key('new-ship-reminder-acknowledge')),
        );
      } else if (close == 'outside') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.controller.currentAlert, isNotNull);
      await tester.pumpAndSettle();
      expect(fixture.controller.currentAlert, isNull);
      expect(find.byKey(const Key('new-ship-alert-dialog')), findsNothing);
      expect(tester.element(find.byKey(const Key('game'))), same(fixture.game));
    });
  }

  testWidgets(
    'temporary native failure falls back without consuming the ship',
    (tester) async {
      final fixture = await _Fixture.mount(tester);
      fixture.port.failure = PlatformException(
        code: 'native_warning_unavailable',
      );
      await fixture.warn(tester, 7);
      expect(find.byKey(const Key('new-ship-alert-dialog')), findsOneWidget);
      expect(fixture.controller.currentAlert, isNotNull);
      await tester.tap(find.byKey(const Key('new-ship-reminder-acknowledge')));
      await tester.pumpAndSettle();
      expect(fixture.controller.currentAlert, isNull);
    },
  );
}

class _Fixture {
  final account = AccountSession(initialMemberId: 1001);
  final port = _Port();
  final native = ValueNotifier(true);
  final enabled = ValueNotifier(true);
  final revision = ValueNotifier(0);
  final controllers = <NewShipReminderController>[];
  late NewShipReminderController controller;
  late Element game;
  int sequence = 0;
  GameState state = const GameState(
    memberId: 1001,
    masterShips: {
      7: MasterShip(id: 7, name: '三日月', shipTypeId: 2, sortNo: 7),
      9: MasterShip(id: 9, name: '吹雪', shipTypeId: 2, sortNo: 9),
    },
  );

  static Future<_Fixture> mount(
    WidgetTester tester, {
    bool native = true,
    int? preexistingMasterId,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final fixture = _Fixture()..native.value = native;
    fixture.controller = NewShipReminderController(
      stateProvider: () => fixture.state,
      accountSession: fixture.account,
      store: NewShipReminderStore(await SharedPreferences.getInstance()),
      onPublish: (_) {},
    );
    fixture.controllers.add(fixture.controller);
    if (preexistingMasterId != null) {
      await fixture.publish(preexistingMasterId);
    }
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      for (final controller in fixture.controllers) {
        controller.dispose();
      }
      fixture.account.dispose();
      fixture.native.dispose();
      fixture.enabled.dispose();
      fixture.revision.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AnimatedBuilder(
          animation: Listenable.merge([
            fixture.native,
            fixture.enabled,
            fixture.revision,
          ]),
          builder: (_, _) => NewShipReminderFeedback(
            controller: fixture.controller,
            stateProvider: () => fixture.state,
            nativeWarningDialogPort: fixture.native.value ? fixture.port : null,
            presentationEnabled: fixture.enabled.value,
            child: const SizedBox.expand(key: Key('game')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    fixture.game = tester.element(find.byKey(const Key('game')));
    return fixture;
  }

  Future<void> warn(WidgetTester tester, int masterId) async {
    await publish(masterId);
    await tester.pumpAndSettle();
  }

  Future<void> publish(int masterId) async {
    controller.accept(
      kcsapiEvent('/kcsapi/api_req_quest/clearitemget', {
        'api_bounus': [
          {
            'api_type': 11,
            'api_item': {'api_ship_id': masterId},
          },
        ],
      }, sequence: ++sequence),
    );
    await controller.idle;
  }
}

class _Port implements NativeGameWarningDialogPort {
  final shown = <Map<String, Object?>>[];
  final dismissed = <int>[];
  final pending = <Completer<NativeGameWarningAction?>>[];
  Object? failure;
  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> warning) {
    shown.add(warning);
    if (failure case final error?) return Future.error(error);
    final result = Completer<NativeGameWarningAction?>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<void> dismiss(int id) async => dismissed.add(id);
  @override
  Future<void> update(Map<String, Object?> warning) async {}
}
