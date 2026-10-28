import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/notice/debuff_reminder_controller.dart';

import '../fixtures/kcsapi_fixtures.dart';

const _portPath = '/kcsapi/api_port/port';
const _battlePath = '/kcsapi/api_req_sortie/battleresult';
const _combinedBattlePath = '/kcsapi/api_req_combined_battle/battleresult';
const _mapStartPath = '/kcsapi/api_req_map/start';
const _mapNextPath = '/kcsapi/api_req_map/next';

Object? _flagData(DebuffReminderSource source, Object? flag) =>
    switch (source) {
      DebuffReminderSource.port => <String, Object?>{
        'api_event_object': <String, Object?>{'api_m_flag2': flag},
      },
      DebuffReminderSource.battleResult => <String, Object?>{'api_m2': flag},
      DebuffReminderSource.airDefense => <String, Object?>{
        'api_destruction_battle': <String, Object?>{'api_m2': flag},
      },
    };

CapturedApiEvent _rawEvent(
  String path,
  String body, {
  Map<String, Object?>? decodedEnvelope,
}) => CapturedApiEvent(
  path: path,
  responseBody: body,
  source: CaptureSource.xhr,
  capturedAt: DateTime.utc(2026, 10, 25, 9, 15),
  decodedEnvelope: decodedEnvelope,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DebuffReminderController controller;
  late int vibrations;

  setUp(() {
    vibrations = 0;
    controller = DebuffReminderController(vibrate: () async => vibrations++);
  });

  tearDown(() => controller.dispose());

  for (final sample in <(String, DebuffReminderSource)>[
    (_portPath, DebuffReminderSource.port),
    (_battlePath, DebuffReminderSource.battleResult),
    (_combinedBattlePath, DebuffReminderSource.battleResult),
    ('/kcsapi/custom/battleresult', DebuffReminderSource.battleResult),
    ('/kcsapi_compat/battleresult', DebuffReminderSource.battleResult),
    (_mapStartPath, DebuffReminderSource.airDefense),
    (_mapNextPath, DebuffReminderSource.airDefense),
  ]) {
    test('${sample.$1} queues its source and capture time', () async {
      final capturedAt = DateTime.utc(2026, 10, 24, 10, 20);
      expect(controller.supportsPath(sample.$1), isTrue);
      controller.accept(
        kcsapiEvent(sample.$1, _flagData(sample.$2, 1), capturedAt: capturedAt),
      );
      await controller.idle;

      expect(controller.alerts, hasLength(1));
      expect(controller.currentAlert?.source, sample.$2);
      expect(controller.currentAlert?.occurredAt, capturedAt);
      expect(vibrations, 1);
    });
  }

  for (final source in DebuffReminderSource.values) {
    final path = switch (source) {
      DebuffReminderSource.port => _portPath,
      DebuffReminderSource.battleResult => _battlePath,
      DebuffReminderSource.airDefense => _mapNextPath,
    };

    test('$source accepts numeric 1.0', () async {
      controller.accept(kcsapiEvent(path, _flagData(source, 1.0)));
      await controller.idle;
      expect(controller.alerts, hasLength(1));
      expect(vibrations, 1);
    });

    for (final flag in <Object?>[
      0,
      -1,
      2,
      1.1,
      '1',
      '1.0',
      true,
      false,
      null,
      [],
      {},
    ]) {
      test('$source ignores ${jsonEncode(flag)}', () async {
        controller.accept(kcsapiEvent(path, _flagData(source, flag)));
        await controller.idle;
        expect(controller.alerts, isEmpty);
        expect(vibrations, 0);
      });
    }

    for (final data in <Object?>[
      null,
      [],
      [1],
      1,
      '1',
      true,
      {},
    ]) {
      test(
        '$source ignores non-object or missing data ${jsonEncode(data)}',
        () async {
          controller.accept(kcsapiEvent(path, data));
          await controller.idle;
          expect(controller.alerts, isEmpty);
          expect(vibrations, 0);
        },
      );
    }
  }

  for (final sample in <(String, Object?)>[
    (_portPath, {'api_m_flag2': 1}),
    (
      _portPath,
      {
        'api_event_object': {'api_m2': 1},
      },
    ),
    (
      _portPath,
      {
        'api_event_object': [
          {'api_m_flag2': 1},
        ],
      },
    ),
    (_portPath, {'api_event_object': 1}),
    (
      _battlePath,
      {
        'api_event_object': {'api_m2': 1},
      },
    ),
    (
      _battlePath,
      {
        'api_destruction_battle': {'api_m2': 1},
      },
    ),
    (_mapNextPath, {'api_m2': 1}),
    (
      _mapStartPath,
      {
        'api_destruction_battle': {'api_m_flag2': 1},
      },
    ),
    (
      _mapNextPath,
      {
        'api_destruction_battle': [
          {'api_m2': 1},
        ],
      },
    ),
    (_mapNextPath, {'api_destruction_battle': 1}),
  ]) {
    test(
      'ignores wrong field structure ${sample.$1} ${jsonEncode(sample.$2)}',
      () async {
        controller.accept(kcsapiEvent(sample.$1, sample.$2));
        await controller.idle;
        expect(controller.alerts, isEmpty);
        expect(vibrations, 0);
      },
    );
  }

  for (final path in <String>[
    '/api_req_sortie/battleresult',
    '/other/kcsapi/api_req_sortie/battleresult',
    '/KCSAPI/api_req_sortie/battleresult',
    '/kcsapi/api_req_sortie/battle_result',
    '/kcsapi/api_req_sortie/battleresult?x=1',
    '/kcsapi/api_req_sortie/battleresult/extra',
    '/kcsapi/api_port/port/extra',
    '/kcsapi/api_port/port?x=1',
    '/kcsapi/api_req_map/start/extra',
    '/kcsapi/api_req_map/next?x=1',
    '/kcsapi/api_req_map/other',
  ]) {
    test(
      'ignores unsupported path $path even when directly accepted',
      () async {
        expect(controller.supportsPath(path), isFalse);
        controller.accept(
          kcsapiEvent(path, {
            'api_m2': 1,
            'api_event_object': {'api_m_flag2': 1},
            'api_destruction_battle': {'api_m2': 1},
          }),
        );
        await controller.idle;
        expect(controller.alerts, isEmpty);
        expect(vibrations, 0);
      },
    );
  }

  for (final body in <String>[
    'invalid JSON',
    'svdata=invalid JSON',
    '[]',
    'null',
    '{"api_result":0,"api_data":{"api_m2":1}}',
    '{"api_result":2,"api_data":{"api_m2":1}}',
    '{"api_result":null,"api_data":{"api_m2":1}}',
    '{"api_data":{"api_m2":1}}',
    '{"api_result":1}',
  ]) {
    test('invalid response does not block a later reminder: $body', () async {
      controller.accept(_rawEvent(_battlePath, body));
      controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
      await controller.idle;
      expect(controller.alerts, hasLength(1));
      expect(vibrations, 1);
    });
  }

  test('decodes svdata-prefixed responses', () async {
    controller.accept(
      _rawEvent(_battlePath, 'svdata={"api_result":1,"api_data":{"api_m2":1}}'),
    );
    await controller.idle;
    expect(controller.alerts, hasLength(1));
    expect(vibrations, 1);
  });

  test('uses predecoded data and checks its api_result', () async {
    controller.accept(
      _rawEvent(
        _battlePath,
        'invalid JSON',
        decodedEnvelope: {
          'api_result': 0,
          'api_data': {'api_m2': 1},
        },
      ),
    );
    controller.accept(
      _rawEvent(
        _battlePath,
        'invalid JSON',
        decodedEnvelope: {
          'api_result': 1,
          'api_data': {'api_m2': 1},
        },
      ),
    );
    await controller.idle;
    expect(controller.alerts, hasLength(1));
    expect(vibrations, 1);
  });

  test('predecoded numeric values still require exactly one', () async {
    for (final flag in <num>[
      double.nan,
      double.infinity,
      double.negativeInfinity,
      1.1,
    ]) {
      controller.accept(
        _rawEvent(
          _battlePath,
          '',
          decodedEnvelope: {
            'api_result': 1,
            'api_data': {'api_m2': flag},
          },
        ),
      );
    }
    await controller.idle;
    expect(controller.alerts, isEmpty);
    expect(vibrations, 0);
  });

  test(
    'each valid response is queued in order without deduplication',
    () async {
      final event = kcsapiEvent(_battlePath, {'api_m2': 1});
      controller.accept(event);
      controller.accept(event);
      controller.accept(
        kcsapiEvent(
          _mapNextPath,
          _flagData(DebuffReminderSource.airDefense, 1),
        ),
      );
      await controller.idle;

      expect(controller.alerts.map((alert) => alert.source), [
        DebuffReminderSource.battleResult,
        DebuffReminderSource.battleResult,
        DebuffReminderSource.airDefense,
      ]);
      expect(controller.alerts.map((alert) => alert.id).toSet(), hasLength(3));
      expect(controller.currentAlert, same(controller.alerts.first));
      expect(vibrations, 3);
    },
  );

  test(
    'alerts are read-only and acknowledgement removes only its id',
    () async {
      var changes = 0;
      controller.addListener(() => changes++);
      for (var i = 0; i < 3; i++) {
        controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
      }
      await controller.idle;
      final ids = controller.alerts.map((alert) => alert.id).toList();
      expect(changes, 3);
      expect(() => controller.alerts.clear(), throwsUnsupportedError);
      expect(
        () => controller.alerts.add(controller.alerts.first),
        throwsUnsupportedError,
      );

      controller.acknowledge(-1);
      expect(changes, 3);
      controller.acknowledge(ids[1]);
      expect(controller.alerts.map((alert) => alert.id), [ids[0], ids[2]]);
      expect(controller.currentAlert?.id, ids[0]);
      controller.acknowledge(ids[0]);
      expect(controller.currentAlert?.id, ids[2]);
      controller.acknowledge(ids[0]);
      expect(changes, 5);
      controller.acknowledge(ids[2]);
      expect(controller.currentAlert, isNull);
      expect(changes, 6);
      expect(vibrations, 3);
    },
  );

  test(
    'publishes reminder before vibration finishes and idle awaits it',
    () async {
      controller.dispose();
      final vibrating = Completer<void>();
      final vibrationStarted = Completer<void>();
      controller = DebuffReminderController(
        vibrate: () {
          vibrationStarted.complete();
          return vibrating.future;
        },
      );
      controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
      var idleCompleted = false;
      final idle = controller.idle.then((_) => idleCompleted = true);
      await vibrationStarted.future;

      expect(controller.alerts, hasLength(1));
      expect(idleCompleted, isFalse);
      vibrating.complete();
      await idle;
      expect(idleCompleted, isTrue);
    },
  );

  for (final error in <Object>[
    StateError('vibration failed'),
    MissingPluginException('no vibration implementation'),
  ]) {
    test('vibration error $error preserves reminders and processing', () async {
      controller.dispose();
      controller = DebuffReminderController(
        vibrate: () async {
          vibrations++;
          throw error;
        },
      );
      controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
      controller.accept(
        kcsapiEvent(_portPath, _flagData(DebuffReminderSource.port, 1)),
      );
      await controller.idle;
      expect(controller.alerts, hasLength(2));
      expect(vibrations, 2);
    });
  }

  test('synchronous vibration errors preserve subsequent processing', () async {
    controller.dispose();
    controller = DebuffReminderController(
      vibrate: () {
        vibrations++;
        throw StateError('synchronous vibration failure');
      },
    );
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    await controller.idle;
    expect(controller.alerts, hasLength(2));
    expect(vibrations, 2);
  });

  test('default vibration uses the platform haptic service', () async {
    controller.dispose();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    controller = DebuffReminderController();
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    await controller.idle;
    expect(controller.alerts, hasLength(1));
    expect(calls.map((call) => call.method), ['HapticFeedback.vibrate']);
  });

  test(
    'account changes clear reminders but unchanged identity retains them',
    () async {
      controller.dispose();
      final account = AccountSession(initialMemberId: 1001);
      addTearDown(account.dispose);
      controller = DebuffReminderController(
        accountSession: account,
        vibrate: () async => vibrations++,
      );
      controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
      await controller.idle;
      final firstId = controller.currentAlert!.id;
      account.selectMember(1001);
      expect(controller.alerts, hasLength(1));
      account.selectMember(2002);
      expect(controller.alerts, isEmpty);
      expect(controller.currentAlert, isNull);
      controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
      await controller.idle;
      expect(controller.alerts, hasLength(1));
      expect(controller.currentAlert!.id, isNot(firstId));
      account.reset();
      expect(controller.alerts, isEmpty);
      expect(vibrations, 2);
    },
  );

  test('account metadata notifications retain the same-scope queue', () async {
    controller.dispose();
    final account = AccountSession(initialMemberId: 1001);
    addTearDown(account.dispose);
    controller = DebuffReminderController(
      accountSession: account,
      vibrate: () async {},
    );
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    await controller.idle;
    account.accept(
      kcsapiEvent('/kcsapi/api_get_member/basic', {
        'api_member_id': 1001,
        'api_nickname': 'new display name',
      }),
    );
    expect(controller.alerts, hasLength(1));
  });

  test('an account switch suppresses queued old-scope events', () async {
    controller.dispose();
    final account = AccountSession();
    addTearDown(account.dispose);
    controller = DebuffReminderController(
      accountSession: account,
      vibrate: () async => vibrations++,
    );
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    account.selectMember(1001);
    await controller.idle;
    expect(controller.alerts, isEmpty);
    expect(vibrations, 0);
  });

  test('a new login for the same member suppresses old-scope events', () async {
    controller.dispose();
    final account = AccountSession(initialMemberId: 1001);
    addTearDown(account.dispose);
    controller = DebuffReminderController(
      accountSession: account,
      vibrate: () async => vibrations++,
    );
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    account.reset();
    account.selectMember(1001);
    await controller.idle;
    expect(controller.alerts, isEmpty);
    expect(vibrations, 0);
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    await controller.idle;
    expect(controller.alerts, hasLength(1));
    expect(vibrations, 1);
  });

  test('a switch during vibration cannot replay old queued work', () async {
    controller.dispose();
    final account = AccountSession(initialMemberId: 1001);
    addTearDown(account.dispose);
    final vibrating = Completer<void>();
    final vibrationStarted = Completer<void>();
    controller = DebuffReminderController(
      accountSession: account,
      vibrate: () {
        vibrations++;
        if (vibrations == 1) {
          vibrationStarted.complete();
          return vibrating.future;
        }
        return Future<void>.value();
      },
    );
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    await vibrationStarted.future;
    account.selectMember(2002);
    expect(controller.alerts, isEmpty);
    controller.accept(
      kcsapiEvent(_mapNextPath, _flagData(DebuffReminderSource.airDefense, 1)),
    );
    vibrating.complete();
    await controller.idle;
    expect(controller.alerts.map((alert) => alert.source), [
      DebuffReminderSource.airDefense,
    ]);
    expect(vibrations, 2);
  });

  test(
    'switching accounts from a listener suppresses the stale vibration',
    () async {
      controller.dispose();
      final account = AccountSession(initialMemberId: 1001);
      addTearDown(account.dispose);
      controller = DebuffReminderController(
        accountSession: account,
        vibrate: () async => vibrations++,
      );
      controller.addListener(() {
        if (controller.alerts.isNotEmpty) account.selectMember(2002);
      });
      controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
      await controller.idle;
      expect(controller.alerts, isEmpty);
      expect(vibrations, 0);
    },
  );

  test(
    'dispose suppresses queued events and later accepts and acknowledgements',
    () async {
      var changes = 0;
      controller.addListener(() => changes++);
      controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
      controller.dispose();
      controller.dispose();
      controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
      controller.acknowledge(1);
      await controller.idle;
      expect(controller.alerts, isEmpty);
      expect(changes, 0);
      expect(vibrations, 0);
    },
  );

  test('dispose clears reminders before later account changes', () async {
    controller.dispose();
    final account = AccountSession(initialMemberId: 1001);
    addTearDown(account.dispose);
    controller = DebuffReminderController(
      accountSession: account,
      vibrate: () async {},
    );
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    await controller.idle;
    controller.dispose();
    expect(controller.alerts, isEmpty);
    expect(controller.currentAlert, isNull);
    account.selectMember(2002);
  });

  test('dispose during vibration suppresses the remaining queue', () async {
    controller.dispose();
    final vibrating = Completer<void>();
    final vibrationStarted = Completer<void>();
    controller = DebuffReminderController(
      vibrate: () {
        vibrations++;
        vibrationStarted.complete();
        return vibrating.future;
      },
    );
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    controller.accept(kcsapiEvent(_battlePath, {'api_m2': 1}));
    await vibrationStarted.future;
    controller.dispose();
    vibrating.complete();
    await controller.idle;
    expect(controller.alerts, isEmpty);
    expect(vibrations, 1);
  });
}
