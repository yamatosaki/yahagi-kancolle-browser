import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_warning_dialog.dart';
import 'package:yahagi_kancolle_browser/src/notice/debuff_reminder_controller.dart';
import 'package:yahagi_kancolle_browser/src/notice/debuff_reminder_feedback.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/notification_settings_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

import '../fixtures/kcsapi_fixtures.dart';

final _dialog = find.byKey(const Key('debuff-reminder-dialog'));
final _time = DateTime(2026, 10, 25, 13, 7, 9);

void main() {
  testWidgets('default dialog presents an alert queued before mounting', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.send(DebuffReminderSource.port);
    await h.mount();

    expect(_dialog, findsOneWidget);
    expect(find.text(h.l10n.debuffReminderTitle), findsOneWidget);
    expect(find.text(h.message(DebuffReminderSource.port)), findsOneWidget);
    expect(find.text('13:07:09'), findsOneWidget);
    expect(find.textContaining('api_'), findsNothing);
    expect(h.vibrations, 1);
    expect(h.controller.currentAlert, isNotNull);
    expect(h.header.notices, isEmpty);
    await tester.pump(const Duration(seconds: 30));
    expect(_dialog, findsOneWidget);
    await h.confirm();
    expect(_dialog, findsNothing);
    expect(h.controller.alerts, isEmpty);
  });

  for (final source in DebuffReminderSource.values) {
    testWidgets('dialog localizes ${source.name} and its occurrence time', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.mount();
      await h.send(source);
      await tester.pumpAndSettle();

      expect(find.text(h.message(source)), findsOneWidget);
      expect(find.text('13:07:09'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final locale in const [
    Locale('ja'),
    Locale('ko'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]) {
    testWidgets('dialog and time render in $locale without locale errors', (
      tester,
    ) async {
      final h = _Harness(tester, locale: locale);
      await h.mount();
      await h.send(DebuffReminderSource.airDefense);
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
      expect(
        find.text(h.message(DebuffReminderSource.airDefense)),
        findsOneWidget,
      );
      final time = tester.widget<Text>(
        find.byKey(const Key('debuff-reminder-time')),
      );
      expect(time.data, contains('07:09'));
      expect(tester.takeException(), isNull);
      await h.confirm();
    });
  }

  testWidgets('outside tap acknowledges the active dialog', (tester) async {
    final h = _Harness(tester);
    await h.mount();
    await h.send(DebuffReminderSource.port);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing);
    expect(h.controller.alerts, isEmpty);
  });

  testWidgets('system back acknowledges the active dialog', (tester) async {
    final h = _Harness(tester);
    await h.mount();
    await h.send(DebuffReminderSource.port);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(_dialog, findsNothing);
    expect(h.controller.alerts, isEmpty);
  });

  testWidgets('a burst presents one dialog at a time in source order', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.mount();
    for (final source in DebuffReminderSource.values) {
      await h.send(source);
    }
    await tester.pumpAndSettle();

    for (var index = 0; index < DebuffReminderSource.values.length; index++) {
      expect(find.byType(AlertDialog, skipOffstage: false), findsOneWidget);
      expect(
        find.text(h.message(DebuffReminderSource.values[index])),
        findsOneWidget,
      );
      expect(h.controller.alerts, hasLength(3 - index));
      await h.mount(); // Rebuilding must not push the same alert again.
      expect(find.byType(AlertDialog, skipOffstage: false), findsOneWidget);
      await h.confirm();
    }
    expect(_dialog, findsNothing);
    expect(h.vibrations, 3);
  });

  testWidgets('the next dialog waits for the previous input protection', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.mount();
    await h.send(DebuffReminderSource.port);
    await h.send(DebuffReminderSource.battleResult);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: _dialog, matching: find.byType(FilledButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(AlertDialog, skipOffstage: false), findsNothing);
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    expect(h.controller.alerts, hasLength(2));
    await tester.pumpAndSettle();
    expect(
      find.text(h.message(DebuffReminderSource.battleResult)),
      findsOneWidget,
    );
  });

  testWidgets(
    'native reminder keeps its alert until the real guard completes',
    (tester) async {
      final h = _Harness(tester)..nativePort = _NativeReminderPort();
      await h.mount();
      await h.send(DebuffReminderSource.port);
      await tester.pumpAndSettle();
      final native = h.nativePort!;
      expect(native.shown, hasLength(1));
      expect(_dialog, findsNothing);
      expect(native.shown.single['body'], contains('13:07:09'));
      expect(h.controller.alerts, hasLength(1));
      native.pending.single.complete(NativeGameWarningAction.acknowledge);
      await tester.pumpAndSettle();
      expect(h.controller.alerts, isEmpty);
      expect(find.byKey(const Key('game-safety-input-guard')), findsNothing);
    },
  );

  testWidgets('native queue waits for completion and preserves source order', (
    tester,
  ) async {
    final h = _Harness(tester)..nativePort = _NativeReminderPort();
    await h.mount();
    await h.send(DebuffReminderSource.port);
    await h.send(DebuffReminderSource.battleResult);
    await tester.pumpAndSettle();
    final native = h.nativePort!;
    expect(native.shown, hasLength(1));
    expect(
      native.shown.single['body'],
      contains(h.message(DebuffReminderSource.port)),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(native.shown, hasLength(1));
    expect(h.controller.alerts, hasLength(2));
    native.pending[0].complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(native.shown, hasLength(2));
    expect(native.shown.last['id'], isNot(native.shown.first['id']));
    expect(
      native.shown.last['body'],
      contains(h.message(DebuffReminderSource.battleResult)),
    );
    expect(h.controller.alerts, hasLength(1));
    native.pending[1].complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(h.controller.alerts, isEmpty);
  });

  testWidgets('mode restart cancels without claiming and re-presents later', (
    tester,
  ) async {
    final h = _Harness(tester)..nativePort = _NativeReminderPort();
    await h.mount();
    await h.send(DebuffReminderSource.port);
    await tester.pumpAndSettle();
    final native = h.nativePort!;
    final firstId = native.shown.single['id'];
    h.presentationEnabled = false;
    await h.mount();
    expect(native.dismissed, [firstId]);
    expect(h.controller.alerts, hasLength(1));
    native.pending.first.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(h.controller.alerts, hasLength(1));
    h.presentationEnabled = true;
    await h.mount();
    expect(native.shown, hasLength(2));
    native.pending.last.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(h.controller.alerts, isEmpty);
  });

  testWidgets('account change rejects a late native acknowledgement', (
    tester,
  ) async {
    final h = _Harness(tester)..nativePort = _NativeReminderPort();
    await h.mount();
    await h.send(DebuffReminderSource.port);
    await tester.pumpAndSettle();
    final native = h.nativePort!;
    final firstId = native.shown.single['id'];
    h.session.selectMember(2002);
    await tester.pumpAndSettle();
    expect(native.dismissed, [firstId]);
    await h.send(DebuffReminderSource.airDefense);
    await tester.pumpAndSettle();
    native.pending.first.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(h.controller.alerts, hasLength(1));
    expect(native.shown, hasLength(2));
    native.pending.last.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(h.controller.alerts, isEmpty);
  });

  testWidgets('native failure falls back safely and next reminder can retry', (
    tester,
  ) async {
    final h = _Harness(tester)
      ..nativePort = (_NativeReminderPort()
        ..failure = StateError('unavailable'));
    await h.mount();
    await h.send(DebuffReminderSource.port);
    await tester.pumpAndSettle();
    expect(_dialog, findsOneWidget);
    expect(h.nativePort!.shown, hasLength(1));
    await tester.tap(find.byKey(const Key('debuff-reminder-acknowledge')));
    await tester.pump();
    expect(find.byKey(const Key('game-safety-input-guard')), findsOneWidget);
    expect(h.controller.alerts, hasLength(1));
    await tester.pumpAndSettle();
    expect(h.controller.alerts, isEmpty);
    h.nativePort!.failure = null;
    await h.send(DebuffReminderSource.battleResult);
    await tester.pumpAndSettle();
    expect(h.nativePort!.shown, hasLength(2));
    expect(_dialog, findsNothing);
    h.nativePort!.pending.single.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(h.controller.alerts, isEmpty);
  });

  for (final alreadyVisible in [false, true]) {
    testWidgets(
      'account change cancels a ${alreadyVisible ? 'visible' : 'scheduled'} dialog',
      (tester) async {
        final h = _Harness(tester);
        await h.mount();
        await h.send(DebuffReminderSource.port);
        if (alreadyVisible) await tester.pumpAndSettle();
        h.session.selectMember(2002);
        await tester.pumpAndSettle();

        expect(_dialog, findsNothing);
        expect(h.controller.alerts, isEmpty);
        await h.send(DebuffReminderSource.battleResult);
        await tester.pumpAndSettle();
        expect(
          find.text(h.message(DebuffReminderSource.battleResult)),
          findsOneWidget,
        );
        await h.confirm();
        expect(h.controller.alerts, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'unmount cancels a ${alreadyVisible ? 'visible' : 'scheduled'} dialog without claiming it',
      (tester) async {
        final h = _Harness(tester);
        await h.mount();
        await h.send(DebuffReminderSource.port);
        if (alreadyVisible) await tester.pumpAndSettle();
        h.feedbackMounted = false;
        await h.mount();

        expect(_dialog, findsNothing);
        expect(h.controller.alerts, hasLength(1));
        expect(tester.takeException(), isNull);
        h.feedbackMounted = true;
        await h.mount();
        expect(_dialog, findsOneWidget);
        await h.confirm();
        expect(h.controller.alerts, isEmpty);
      },
    );

    testWidgets(
      'controller replacement invalidates a ${alreadyVisible ? 'visible' : 'scheduled'} old dialog',
      (tester) async {
        final h = _Harness(tester);
        await h.mount();
        final old = h.controller;
        await h.send(DebuffReminderSource.port);
        if (alreadyVisible) await tester.pumpAndSettle();
        h.controller = h.newController();
        await h.send(DebuffReminderSource.airDefense);
        // Both controllers start their IDs at the same value.
        expect(old.currentAlert!.id, h.controller.currentAlert!.id);
        await h.mount();

        expect(find.text(h.message(DebuffReminderSource.port)), findsNothing);
        expect(
          find.text(h.message(DebuffReminderSource.airDefense)),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog, skipOffstage: false), findsOneWidget);
        expect(old.alerts, hasLength(1));
        await h.confirm();
        expect(old.alerts, hasLength(1));
        expect(h.controller.alerts, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'clearing then immediately enqueuing does not claim the new alert',
    (tester) async {
      final h = _Harness(tester);
      await h.mount();
      await h.send(DebuffReminderSource.port);
      await tester.pumpAndSettle();
      h.session.selectMember(2002);
      await h.send(DebuffReminderSource.airDefense);
      await tester.pumpAndSettle();

      expect(
        find.text(h.message(DebuffReminderSource.airDefense)),
        findsOneWidget,
      );
      expect(h.controller.alerts, hasLength(1));
      await h.confirm();
      expect(h.controller.alerts, isEmpty);
    },
  );

  testWidgets(
    'changing style affects the next alert and keeps the active dialog',
    (tester) async {
      final h = _Harness(tester);
      await h.mount();
      await h.send(DebuffReminderSource.port);
      await h.send(DebuffReminderSource.battleResult);
      await tester.pumpAndSettle();
      await h.settings.setDebuffReminderStyle(DebuffReminderStyle.topNotice);
      await tester.pumpAndSettle();

      expect(find.text(h.message(DebuffReminderSource.port)), findsOneWidget);
      expect(h.header.notices, isEmpty);
      await h.confirm();
      expect(_dialog, findsNothing);
      expect(h.controller.alerts, isEmpty);
      expect(
        h.header.current!.message,
        contains(h.message(DebuffReminderSource.battleResult)),
      );
      expect(h.vibrations, 2);
      h.header.hide();
    },
  );

  testWidgets(
    'top notice uses the shield, chosen duration and retains quest alerts',
    (tester) async {
      final h = _Harness(tester, style: DebuffReminderStyle.topNotice);
      h.duration = () => const Duration(seconds: 2);
      await h.mount();
      h.header.show(
        message: '任务达成：测试任务',
        tone: TopNoticeTone.quest,
        duration: const Duration(seconds: 30),
      );
      await h.send(DebuffReminderSource.airDefense);
      final id = h.controller.currentAlert!.id;
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(h.controller.alerts, isEmpty);
      expect(h.header.notices, hasLength(2));
      final notice = h.header.current!;
      expect(notice.tone, TopNoticeTone.debuff);
      expect(notice.customIcon, Icons.shield_outlined);
      expect(notice.showIcon, isTrue);
      expect(notice.replacementKey, 'debuff-reminder-$id');
      expect(
        notice.message,
        contains(h.message(DebuffReminderSource.airDefense)),
      );
      expect(notice.message, contains('13:07:09'));
      expect(h.vibrations, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(h.header.notices.single.message, '任务达成：测试任务');
      h.header.hide();
    },
  );

  testWidgets(
    'top notices default to five seconds and do not replay on rebuild',
    (tester) async {
      final h = _Harness(tester, style: DebuffReminderStyle.topNotice);
      await h.mount();
      await h.send(DebuffReminderSource.port);
      await tester.pumpAndSettle();
      final noticeId = h.header.current!.id;
      await h.mount();

      expect(h.header.notices, hasLength(1));
      expect(h.header.current!.id, noticeId);
      expect(h.vibrations, 1);
      await tester.pump(const Duration(seconds: 4));
      expect(h.header.current, isNotNull);
      await tester.pump(const Duration(seconds: 1));
      expect(h.header.notices, isEmpty);
    },
  );

  testWidgets(
    'top notice queue publishes every alert before switching to dialog',
    (tester) async {
      final h = _Harness(tester, style: DebuffReminderStyle.topNotice);
      await h.mount();
      await h.send(DebuffReminderSource.port);
      await h.send(DebuffReminderSource.battleResult);
      await tester.pumpAndSettle();

      expect(h.header.notices, hasLength(2));
      expect(h.controller.alerts, isEmpty);
      await h.settings.setDebuffReminderStyle(DebuffReminderStyle.dialog);
      await h.send(DebuffReminderSource.airDefense);
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
      expect(h.header.notices, hasLength(2));
      expect(h.vibrations, 3);
      h.header.hide();
    },
  );

  testWidgets(
    'a failed vibration still displays the independently enabled reminder',
    (tester) async {
      final h = _Harness(tester, failVibration: true);
      await h.mount();
      await h.send(DebuffReminderSource.port);
      await tester.pumpAndSettle();

      expect(_dialog, findsOneWidget);
      expect(h.vibrations, 1);
      await h.confirm();
      expect(h.controller.alerts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'English dialog fits 320px with large bold text and localized time',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = _Harness(tester, locale: const Locale('en'), textScale: 2);
      await h.mount();
      await h.send(DebuffReminderSource.airDefense);
      await tester.pumpAndSettle();

      expect(_dialog, findsOneWidget);
      expect(find.text(h.l10n.debuffReminderTitle), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('debuff-reminder-time'))).data,
        '1:07:09\u202fPM',
      );
      expect(tester.takeException(), isNull);
      await h.confirm();
      expect(_dialog, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Harness {
  _Harness(
    this.tester, {
    DebuffReminderStyle style = DebuffReminderStyle.dialog,
    this.locale = const Locale('zh'),
    this.textScale = 1,
    this.failVibration = false,
  }) : settings = NotificationSettingsController(
         store: _SettingsStore(),
         initialSettings: NotificationSettings(
           // Debuff reminders have their own policy, independent of OS alerts.
           master: false,
           vibration: false,
           debuffReminderStyle: style,
         ),
       ) {
    controller = newController();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      for (final controller in controllers) {
        controller.dispose();
      }
      settings.dispose();
      header.dispose();
      session.dispose();
    });
  }

  final WidgetTester tester;
  final Locale locale;
  final double textScale;
  final bool failVibration;
  final session = AccountSession(initialMemberId: 1001);
  final header = TopNoticeController();
  final NotificationSettingsController settings;
  final controllers = <DebuffReminderController>[];
  late DebuffReminderController controller;
  Duration Function()? duration;
  bool feedbackMounted = true;
  bool presentationEnabled = true;
  _NativeReminderPort? nativePort;
  int vibrations = 0;
  int _sequence = 0;

  AppLocalizations get l10n => lookupAppLocalizations(locale);

  String message(DebuffReminderSource source) =>
      l10n.debuffReminderMessage(switch (source) {
        DebuffReminderSource.port => l10n.debuffReminderSourcePort,
        DebuffReminderSource.battleResult =>
          l10n.debuffReminderSourceBattleResult,
        DebuffReminderSource.airDefense => l10n.debuffReminderSourceAirDefense,
      });

  DebuffReminderController newController() {
    final controller = DebuffReminderController(
      accountSession: session,
      vibrate: () async {
        vibrations++;
        if (failVibration) throw StateError('haptics unavailable');
      },
    );
    controllers.add(controller);
    return controller;
  }

  Future<void> send(DebuffReminderSource source) async {
    final (path, data) = switch (source) {
      DebuffReminderSource.port => (
        '/kcsapi/api_port/port',
        <String, Object?>{
          'api_event_object': {'api_m_flag2': 1},
        },
      ),
      DebuffReminderSource.battleResult => (
        '/kcsapi/api_req_sortie/battleresult',
        <String, Object?>{'api_m2': 1},
      ),
      DebuffReminderSource.airDefense => (
        '/kcsapi/api_req_map/next',
        <String, Object?>{
          'api_destruction_battle': {'api_m2': 1},
        },
      ),
    };
    controller.accept(
      kcsapiEvent(path, data, capturedAt: _time, sequence: ++_sequence),
    );
    await controller.idle;
  }

  Future<void> mount() async {
    final content = Column(
      children: [
        const SizedBox(
          height: 44,
          child: QuestCompletionHeaderSlot(child: SizedBox.expand()),
        ),
        const Expanded(child: SizedBox.expand(key: Key('game-surface'))),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(boldText: true, textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: QuestCompletionDrawerHost(
            controller: header,
            child: feedbackMounted
                ? DebuffReminderFeedback(
                    controller: controller,
                    settingsController: settings,
                    headerNoticeController: header,
                    topNoticeDuration: duration,
                    nativeWarningDialogPort: nativePort,
                    presentationEnabled: presentationEnabled,
                    child: content,
                  )
                : content,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirm() async {
    await tester.tap(
      find.descendant(of: _dialog, matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();
  }
}

class _NativeReminderPort implements NativeGameWarningDialogPort {
  final shown = <Map<String, Object?>>[];
  final dismissed = <int>[];
  final pending = <Completer<NativeGameWarningAction?>>[];
  Object? failure;

  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> warning) {
    shown.add(warning);
    if (failure case final error?) return Future.error(error);
    final completion = Completer<NativeGameWarningAction?>();
    pending.add(completion);
    return completion.future;
  }

  @override
  Future<void> dismiss(int id) async => dismissed.add(id);

  @override
  Future<void> update(Map<String, Object?> warning) async {}
}

class _SettingsStore implements NotificationSettingsStore {
  NotificationSettings _settings = const NotificationSettings();

  @override
  Future<NotificationSettings> load() async => _settings;

  @override
  Future<void> save(NotificationSettings settings) async =>
      _settings = settings;
}
