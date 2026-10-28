import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_completion_drawer.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

const _channel = MethodChannel('app.yahagi.kancollebrowser/game_fullscreen');
const _message = '大破舰已携带损管';

void main() {
  testWidgets('native acceptance works without a Flutter header slot', (
    tester,
  ) async {
    final native = _NativeOverlay(tester);
    final context = await _mountHost(tester);
    expect(await _show(tester, context), isTrue);
    expect(native.shows, hasLength(1));
    expect(_arguments(native.shows.single)['message'], _message);
    expect(_arguments(native.shows.single)['id'], isA<int>());
    expect(native.activeMessage, _message);
    expect(find.byType(QuestCompletionHeaderSlot), findsNothing);
    expect(find.text(_message), findsNothing);
    await _unmount(tester);
  });

  for (final rejection in ['false', 'null', 'missing', 'platform']) {
    testWidgets(
      'native $rejection rejection returns false without dismissing',
      (tester) async {
        final native = _NativeOverlay(tester);
        native.showResult = (_, _) async => switch (rejection) {
          'false' => false,
          'null' => null,
          'missing' => throw MissingPluginException(),
          _ => throw PlatformException(code: 'unavailable'),
        };
        final context = await _mountHost(tester);
        var dismissed = 0;
        expect(
          await _show(tester, context, onDismissed: () => dismissed++),
          isFalse,
        );
        expect(native.shows, hasLength(1));
        expect(native.activeMessage, isNull);
        expect(dismissed, 0);
        await _unmount(tester);
      },
    );
  }

  testWidgets('an unanswered native show fails closed after two seconds', (
    tester,
  ) async {
    final native = _NativeOverlay(tester);
    final pending = Completer<Object?>();
    native.showResult = (_, _) => pending.future;
    final context = await _mountHost(tester);
    var finished = false;
    final shown = QuestCompletionDrawerHost.showDamageControlNotice(
      context,
      _message,
    )..then((_) => finished = true);
    await tester.pump();
    expect(finished, isFalse);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(finished, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(await shown, isFalse);
    final id = _id(native.shows.single);
    pending.complete(true);
    await _flush(tester);
    expect(native.clears.map(_id), contains(id));
    expect(native.activeId, isNull);
    await _unmount(tester);
  });

  testWidgets('native damage expires at ten seconds without clearing quests', (
    tester,
  ) async {
    final native = _NativeOverlay(tester);
    final notices = TopNoticeController();
    addTearDown(notices.dispose);
    final context = await _mountHost(tester, controller: notices);
    notices.show(
      message: '任务达成：出击',
      tone: TopNoticeTone.quest,
      duration: const Duration(seconds: 15),
    );
    var dismissed = 0;
    var unavailable = 0;
    expect(
      await _show(
        tester,
        context,
        onDismissed: () => dismissed++,
        onUnavailable: () => unavailable++,
      ),
      isTrue,
    );
    final id = _id(native.shows.single);
    await tester.pump(const Duration(seconds: 9));
    expect(native.activeId, id);
    expect(native.clears.map(_id), isNot(contains(id)));
    expect(dismissed, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(native.activeId, isNull);
    expect(native.clears.map(_id), contains(id));
    expect(dismissed, 1);
    expect(unavailable, 0);
    expect(notices.notices.map((notice) => notice.message), ['任务达成：出击']);
    expect(_arguments(native.questCalls.last)['message'], '任务达成：出击');
    await tester.pump(const Duration(milliseconds: 500));
    expect(dismissed, 1);
    expect(unavailable, 0);
    await tester.pump(const Duration(milliseconds: 4500));
    expect(notices.notices, isEmpty);
    await _unmount(tester);
  });

  for (final loss in ['false', 'null', 'missing', 'platform', 'timeout']) {
    testWidgets('native visibility $loss escalates only once and clears', (
      tester,
    ) async {
      final native = _NativeOverlay(tester);
      final context = await _mountHost(tester);
      var unavailable = 0;
      var dismissed = 0;
      expect(
        await _show(
          tester,
          context,
          onUnavailable: () => unavailable++,
          onDismissed: () => dismissed++,
        ),
        isTrue,
      );
      final id = _id(native.shows.single);
      final pending = Completer<Object?>();
      native.visibleResult = (_) async => switch (loss) {
        'false' => false,
        'null' => null,
        'missing' => throw MissingPluginException(),
        'platform' => throw PlatformException(code: 'unavailable'),
        _ => pending.future,
      };
      await tester.pump(const Duration(milliseconds: 499));
      expect(unavailable, 0);
      await tester.pump(const Duration(milliseconds: 1));
      if (loss == 'timeout') {
        await tester.pump(const Duration(seconds: 2));
      }
      expect(native.visibleCalls.map(_id), contains(id));
      expect(unavailable, 1);
      expect(dismissed, 0);
      expect(native.clears.map(_id), contains(id));
      expect(native.activeId, isNull);
      if (loss == 'timeout') {
        pending.complete(true);
        await _flush(tester);
      }
      await tester.pump(const Duration(seconds: 20));
      expect(unavailable, 1);
      expect(dismissed, 0);
      await _unmount(tester);
    });
  }

  for (final removal in ['programmatic', 'cached remover', 'dispose']) {
    testWidgets('$removal clears a native notice without dismissal', (
      tester,
    ) async {
      final native = _NativeOverlay(tester);
      final context = await _mountHost(tester);
      var unavailable = 0;
      var dismissed = 0;
      expect(
        await _show(
          tester,
          context,
          onUnavailable: () => unavailable++,
          onDismissed: () => dismissed++,
        ),
        isTrue,
      );
      final id = _id(native.shows.single);
      switch (removal) {
        case 'programmatic':
          QuestCompletionDrawerHost.removeDamageControlNotice(context);
        case 'cached remover':
          QuestCompletionDrawerHost.damageControlNoticeRemover(context)!();
        case 'dispose':
          await _unmount(tester);
      }
      await _flush(tester);
      expect(native.clears.map(_id), contains(id));
      expect(native.activeId, isNull);
      await tester.pump(const Duration(seconds: 20));
      expect(unavailable, 0);
      expect(dismissed, 0);
      await _unmount(tester);
    });
  }

  testWidgets('windowed to native preserves a live notice and its deadline', (
    tester,
  ) async {
    final native = _NativeOverlay(tester);
    final context = await _mountHost(tester, fullscreen: false, withSlot: true);
    var unavailable = 0;
    var dismissed = 0;
    expect(
      await _show(
        tester,
        context,
        onUnavailable: () => unavailable++,
        onDismissed: () => dismissed++,
      ),
      isTrue,
    );
    expect(native.shows, isEmpty);
    expect(find.text(_message), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await _mountHost(tester);
    await _flush(tester);
    expect(
      native.activeMessage,
      _message,
      reason:
          'calls=${native.calls.map((call) => '${call.method}:${call.arguments}').toList()} unavailable=$unavailable dismissed=$dismissed',
    );
    expect(find.text(_message), findsNothing);
    expect(unavailable, 0);
    await tester.pump(const Duration(milliseconds: 5999));
    expect(native.activeMessage, _message);
    await tester.pump(const Duration(milliseconds: 1));
    expect(native.activeId, isNull);
    expect(dismissed, 1);
    expect(unavailable, 0);
    await _unmount(tester);
  });

  testWidgets('native to windowed preserves a live notice and its deadline', (
    tester,
  ) async {
    final native = _NativeOverlay(tester);
    final context = await _mountHost(tester);
    var unavailable = 0;
    var dismissed = 0;
    expect(
      await _show(
        tester,
        context,
        onUnavailable: () => unavailable++,
        onDismissed: () => dismissed++,
      ),
      isTrue,
    );
    final id = _id(native.shows.single);
    await tester.pump(const Duration(seconds: 4));
    await _mountHost(tester, fullscreen: false, withSlot: true);
    await _flush(tester);
    expect(native.clears.map(_id), contains(id));
    expect(native.activeId, isNull);
    expect(find.text(_message), findsOneWidget);
    expect(unavailable, 0);
    await tester.pump(const Duration(milliseconds: 5999));
    expect(find.text(_message), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text(_message), findsNothing);
    expect(dismissed, 1);
    expect(unavailable, 0);
    await _unmount(tester);
  });

  testWidgets('leaving native with no readable header reports unavailable', (
    tester,
  ) async {
    final native = _NativeOverlay(tester);
    final context = await _mountHost(tester);
    var unavailable = 0;
    expect(
      await _show(tester, context, onUnavailable: () => unavailable++),
      isTrue,
    );
    final id = _id(native.shows.single);
    await _mountHost(tester, fullscreen: false);
    await _flush(tester);
    expect(unavailable, 1);
    expect(native.clears.map(_id), contains(id));
    expect(native.activeId, isNull);
    await _unmount(tester);
  });

  for (final mutation in ['clear', 'dispose', 'replacement']) {
    testWidgets('a pending native show cannot survive $mutation', (
      tester,
    ) async {
      final native = _NativeOverlay(tester);
      final pending = Completer<Object?>();
      native.showResult = (_, message) =>
          message == 'old' ? pending.future : Future<Object?>.value(true);
      final context = await _mountHost(tester);
      var oldDismissed = 0;
      var oldUnavailable = 0;
      final first = QuestCompletionDrawerHost.showDamageControlNotice(
        context,
        'old',
        onDismissed: () => oldDismissed++,
        onUnavailable: () => oldUnavailable++,
      );
      await _flush(tester);
      final oldId = _id(native.shows.single);
      Future<bool>? second;
      switch (mutation) {
        case 'clear':
          QuestCompletionDrawerHost.removeDamageControlNotice(context);
        case 'dispose':
          await _unmount(tester);
        case 'replacement':
          second = QuestCompletionDrawerHost.showDamageControlNotice(
            context,
            _message,
          );
      }
      await _flush(tester);
      pending.complete(true);
      await _flush(tester);
      expect(await first, isFalse);
      expect(native.clears.map(_id), contains(oldId));
      if (second != null) {
        expect(await second, isTrue);
        final latestId = _id(native.shows.last);
        expect(latestId, isNot(oldId));
        expect(native.activeId, latestId);
        expect(native.activeMessage, _message);
        expect(native.clears.map(_id), isNot(contains(latestId)));
      } else {
        expect(native.activeId, isNull);
      }
      expect(oldDismissed, 0);
      expect(oldUnavailable, 0);
      await _unmount(tester);
    });
  }

  testWidgets('a late visibility failure cannot clear a replacement notice', (
    tester,
  ) async {
    final native = _NativeOverlay(tester);
    final context = await _mountHost(tester);
    var unavailable = 0;
    var dismissed = 0;
    expect(
      await _show(
        tester,
        context,
        onUnavailable: () => unavailable++,
        onDismissed: () => dismissed++,
      ),
      isTrue,
    );
    final oldId = _id(native.shows.single);
    final pending = Completer<Object?>();
    native.visibleResult = (id) =>
        id == oldId ? pending.future : Future<Object?>.value(true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(native.visibleCalls.map(_id), contains(oldId));
    expect(await _show(tester, context), isTrue);
    final latestId = _id(native.shows.last);
    expect(latestId, isNot(oldId));
    pending.complete(false);
    await _flush(tester);
    expect(native.activeId, latestId);
    expect(native.clears.map(_id), isNot(contains(latestId)));
    expect(unavailable, 0);
    expect(dismissed, 0);
    await _unmount(tester);
  });

  testWidgets(
    'late acknowledgements from a disposed host preserve a new host',
    (tester) async {
      final native = _NativeOverlay(tester);
      final pending = Completer<Object?>();
      native.showResult = (_, message) =>
          message == 'old' ? pending.future : Future<Object?>.value(true);
      final oldContext = await _mountHost(tester);
      final removeOld = QuestCompletionDrawerHost.damageControlNoticeRemover(
        oldContext,
      )!;
      final first = QuestCompletionDrawerHost.showDamageControlNotice(
        oldContext,
        'old',
      );
      await _flush(tester);
      final oldId = _id(native.shows.single);
      await _unmount(tester);
      final context = await _mountHost(tester);
      expect(await _show(tester, context), isTrue);
      final latestId = _id(native.shows.last);
      expect(latestId, isNot(oldId));
      pending.complete(true);
      removeOld();
      await _flush(tester);
      expect(await first, isFalse);
      expect(native.clears.map(_id), contains(oldId));
      expect(native.clears.map(_id), isNot(contains(latestId)));
      expect(native.activeId, latestId);
      expect(native.activeMessage, _message);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    },
  );

  testWidgets('switching native rendering off preserves the Flutter deadline', (
    tester,
  ) async {
    final native = _NativeOverlay(tester);
    final context = await _mountHost(tester);
    var unavailable = 0;
    expect(
      await _show(tester, context, onUnavailable: () => unavailable++),
      isTrue,
    );
    final id = _id(native.shows.single);
    await tester.pump(const Duration(seconds: 4));
    await _mountHost(tester, native: false);
    await _flush(tester);
    expect(native.clears.map(_id), contains(id));
    expect(native.activeId, isNull);
    expect(find.text(_message), findsOneWidget);
    expect(unavailable, 0);
    await tester.pump(const Duration(milliseconds: 5999));
    expect(find.text(_message), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text(_message), findsNothing);
    expect(unavailable, 0);
    await _unmount(tester);
  });

  testWidgets('quest updates and removal do not reset native damage expiry', (
    tester,
  ) async {
    final native = _NativeOverlay(tester);
    final notices = TopNoticeController();
    addTearDown(notices.dispose);
    final context = await _mountHost(tester, controller: notices);
    expect(await _show(tester, context), isTrue);
    final id = _id(native.shows.single);
    await tester.pump(const Duration(seconds: 4));
    notices.show(message: 'quest one', tone: TopNoticeTone.quest);
    await _flush(tester);
    expect(_arguments(native.questCalls.last)['message'], 'quest one');
    notices.show(message: 'quest two', tone: TopNoticeTone.quest);
    await _flush(tester);
    expect(_arguments(native.questCalls.last)['message'], 'quest two');
    QuestCompletionDrawerHost.removeQuestNotices(context);
    await _flush(tester);
    expect(_arguments(native.questCalls.last)['message'], '');
    expect(native.shows, hasLength(1));
    expect(native.activeId, id);
    expect(native.clears.map(_id), isNot(contains(id)));
    await tester.pump(const Duration(milliseconds: 5999));
    expect(native.activeId, id);
    await tester.pump(const Duration(milliseconds: 1));
    expect(native.activeId, isNull);
    await _unmount(tester);
  });
}

class _NativeOverlay {
  _NativeOverlay(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      _handle,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );
  }

  final calls = <MethodCall>[];
  Future<Object?> Function(int id, String message)? showResult;
  Future<Object?> Function(int id)? visibleResult;
  int? _newestRequestedId;
  final _clearedIds = <int>{};
  int? activeId;
  String? activeMessage;

  List<MethodCall> get shows => calls
      .where(
        (call) =>
            call.method == 'damageControlNotice' &&
            _arguments(call)['message'] != '',
      )
      .toList();

  List<MethodCall> get clears => calls
      .where(
        (call) =>
            call.method == 'damageControlNotice' &&
            _arguments(call)['message'] == '',
      )
      .toList();

  List<MethodCall> get visibleCalls => calls
      .where((call) => call.method == 'damageControlNoticeVisible')
      .toList();

  List<MethodCall> get questCalls =>
      calls.where((call) => call.method == 'questNotice').toList();

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call);
    if (call.method == 'damageControlNoticeVisible') {
      final id = _id(call);
      return visibleResult?.call(id) ?? activeId == id;
    }
    if (call.method != 'damageControlNotice') return null;
    final arguments = _arguments(call);
    final id = arguments['id'] as int;
    final message = arguments['message'] as String;
    if (message.isEmpty) {
      _clearedIds.add(id);
      if (activeId == id) {
        activeId = null;
        activeMessage = null;
      }
      return false;
    }
    _newestRequestedId = id;
    final accepted =
        await (showResult?.call(id, message) ?? Future<Object?>.value(true));
    // Native work runs synchronously before its acknowledgement. A late reply
    // cannot repaint a request that was already cleared or superseded.
    if (accepted == true &&
        _newestRequestedId == id &&
        !_clearedIds.contains(id)) {
      activeId = id;
      activeMessage = message;
    }
    return accepted;
  }
}

Map<Object?, Object?> _arguments(MethodCall call) =>
    (call.arguments as Map).cast<Object?, Object?>();

int _id(MethodCall call) => _arguments(call)['id'] as int;

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _flush(tester);
}

Future<bool> _show(
  WidgetTester tester,
  BuildContext context, {
  VoidCallback? onUnavailable,
  VoidCallback? onDismissed,
}) async {
  final shown = QuestCompletionDrawerHost.showDamageControlNotice(
    context,
    _message,
    onUnavailable: onUnavailable,
    onDismissed: onDismissed,
  );
  await _flush(tester);
  return shown;
}

Future<BuildContext> _mountHost(
  WidgetTester tester, {
  TopNoticeController? controller,
  bool fullscreen = true,
  bool native = true,
  bool withSlot = false,
}) async {
  late BuildContext target;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuestCompletionDrawerHost(
          controller: controller,
          fullscreen: fullscreen,
          nativeQuestOverlay: native,
          child: Builder(
            builder: (context) {
              target = context;
              return Column(
                children: [
                  if (withSlot)
                    const SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: QuestCompletionHeaderSlot(child: Text('controls')),
                    ),
                  const Expanded(child: SizedBox.expand()),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  return target;
}
