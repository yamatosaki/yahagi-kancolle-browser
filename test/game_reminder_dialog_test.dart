import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_reminder_dialog.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_surface_input_guard.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_warning_dialog.dart';

const _ack = Key('reminder-ack');
const _guard = Key('game-safety-input-guard');

void main() {
  testWidgets('confirm waits for the actual input guard before completing', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final presentation = h.show();
    var result = false;
    presentation.completed.then((value) => result = value);
    await tester.pumpAndSettle();
    expect(find.byKey(_ack), findsOneWidget);
    await tester.tap(find.byKey(_ack));
    await tester.pump();
    expect(find.byKey(_ack), findsNothing);
    expect(find.byKey(_guard), findsOneWidget);
    expect(result, isFalse);
    await tester.tapAt(const Offset(20, 200));
    expect(h.gameTouches, 0);
    await tester.pump(const Duration(milliseconds: 599));
    expect(result, isFalse);
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(presentation.isActive, isFalse);
    await tester.tapAt(const Offset(20, 200));
    expect(h.gameTouches, 1);
  });

  for (final close in ['outside', 'back']) {
    testWidgets('$close dismissal also establishes input protection', (
      tester,
    ) async {
      final h = await _Harness.mount(tester);
      final presentation = h.show();
      await tester.pumpAndSettle();
      if (close == 'outside') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pump();
      expect(find.byKey(_guard), findsOneWidget);
      expect(h.gameTouches, 0);
      await tester.pumpAndSettle();
      expect(await presentation.completed, isTrue);
    });
  }

  testWidgets('holding a pointer extends protection beyond 600 milliseconds', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final presentation = h.show();
    var completed = false;
    presentation.completed.then((_) => completed = true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_ack));
    await tester.pump();
    final pointer = await tester.startGesture(const Offset(20, 200));
    await tester.pump(const Duration(seconds: 2));
    expect(completed, isFalse);
    expect(find.byKey(_guard), findsOneWidget);
    await pointer.up();
    await tester.pump(const Duration(milliseconds: 599));
    expect(completed, isFalse);
    await tester.pumpAndSettle();
    expect(await presentation.completed, isTrue);
    expect(h.gameTouches, 0);
  });

  for (final close in ['back', 'second finger']) {
    testWidgets('a pointer held before $close keeps protection until release', (
      tester,
    ) async {
      final h = await _Harness.mount(tester);
      final presentation = h.show();
      await tester.pumpAndSettle();
      final pointer = await tester.startGesture(
        tester.getCenter(find.text('title')),
        pointer: 41,
      );
      if (close == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byKey(_ack));
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(_guard), findsOneWidget);
      expect(presentation.isActive, isTrue);
      await pointer.up();
      await tester.pump(const Duration(milliseconds: 599));
      expect(find.byKey(_guard), findsOneWidget);
      await tester.pumpAndSettle();
      expect(await presentation.completed, isTrue);
      expect(h.gameTouches, 0);
    });
  }

  testWidgets(
    'program cancellation protects a pointer held on the old dialog',
    (tester) async {
      final h = await _Harness.mount(tester);
      final first = h.show();
      await tester.pumpAndSettle();
      final pointer = await tester.startGesture(
        tester.getCenter(find.text('title')),
        pointer: 42,
      );
      first.cancel();
      final next = h.show(kind: 'newShip', title: 'next reminder');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(await first.completed, isFalse);
      expect(find.byKey(_guard), findsOneWidget);
      expect(find.text('next reminder'), findsNothing);
      await pointer.cancel();
      await tester.pump(const Duration(milliseconds: 599));
      expect(find.text('next reminder'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('next reminder'), findsOneWidget);
      next.cancel();
      await tester.pumpAndSettle();
      expect(h.gameTouches, 0);
    },
  );

  testWidgets('unmounting the owner while held keeps navigator protection', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final presentation = h.show();
    h.onOwnerDispose = presentation.cancel;
    await tester.pumpAndSettle();
    final pointer = await tester.startGesture(
      tester.getCenter(find.text('title')),
      pointer: 45,
    );
    h.ownerVisible.value = false;
    await tester.pump();
    expect(h.context.mounted, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(_guard), findsOneWidget);
    expect(await presentation.completed, isFalse);
    await pointer.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_guard), findsNothing);
    expect(find.byKey(_ack), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old and new held pointers both delay the same protection', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final presentation = h.show();
    await tester.pumpAndSettle();
    final oldPointer = await tester.startGesture(
      tester.getCenter(find.text('title')),
      pointer: 43,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    final newPointer = await tester.startGesture(
      const Offset(20, 200),
      pointer: 44,
    );
    await oldPointer.up();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(_guard), findsOneWidget);
    expect(presentation.isActive, isTrue);
    await newPointer.cancel();
    await tester.pumpAndSettle();
    expect(await presentation.completed, isTrue);
  });

  testWidgets('replacement owner cannot overtake deferred held protection', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final first = h.show();
    await tester.pumpAndSettle();
    final pointer = await tester.startGesture(
      tester.getCenter(find.text('title')),
      pointer: 46,
    );
    GameReminderDialogPresentation? next;
    h.onOwnerDispose = first.cancel;
    // New owner's initState enqueues its post-frame show before finalizeTree
    // disposes the old owner and schedules the old shield's visual update.
    h.onOwnerMount = () => next = h.show(title: 'replacement reminder');
    h.ownerGeneration.value++;
    await tester.pump();
    await tester.pump();
    expect(next, isNotNull);
    expect(await first.completed, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(_guard), findsOneWidget);
    expect(find.text('replacement reminder'), findsNothing);
    await pointer.up();
    await tester.pumpAndSettle();
    expect(find.text('replacement reminder'), findsOneWidget);
    next!.cancel();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a covered reminder ignores its obsolete acknowledge callback', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final presentation = h.show();
    await tester.pumpAndSettle();
    final staleAcknowledge = h.acknowledge!;
    unawaited(
      showDialog<void>(
        context: h.context,
        builder: (_) => const AlertDialog(title: Text('cover')),
      ),
    );
    await tester.pumpAndSettle();
    staleAcknowledge();
    await tester.pump();
    expect(find.text('cover'), findsOneWidget);
    expect(find.byKey(_guard), findsNothing);
    expect(presentation.isActive, isTrue);
    h.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    h.acknowledge!();
    await tester.pumpAndSettle();
    expect(await presentation.completed, isTrue);
  });

  testWidgets('program cancellation removes only its owned route', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final presentation = h.show();
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: h.context,
        builder: (_) => const AlertDialog(title: Text('other modal')),
      ),
    );
    await tester.pumpAndSettle();
    presentation.cancel();
    await tester.pumpAndSettle();
    expect(await presentation.completed, isFalse);
    expect(find.text('other modal'), findsOneWidget);
    expect(find.byKey(_ack), findsNothing);
    expect(find.byKey(_guard), findsNothing);
  });

  testWidgets(
    'cancellation while held keeps protection but is not an acknowledgement',
    (tester) async {
      final h = await _Harness.mount(tester);
      final presentation = h.show();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_ack));
      await tester.pump();
      final pointer = await tester.startGesture(const Offset(20, 200));
      presentation.cancel();
      expect(await presentation.completed, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(_guard), findsOneWidget);
      expect(h.gameTouches, 0);
      await pointer.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_guard), findsNothing);
    },
  );

  for (final nextKind in ['debuff', 'newShip']) {
    testWidgets('replacement $nextKind waits for the cancelled held guard', (
      tester,
    ) async {
      final h = await _Harness.mount(tester);
      final first = h.show();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_ack));
      await tester.pump();
      final pointer = await tester.startGesture(const Offset(20, 200));
      first.cancel();
      final next = h.show(kind: nextKind, title: 'next reminder');
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(await first.completed, isFalse);
      expect(find.byKey(_guard), findsOneWidget);
      expect(find.text('next reminder'), findsNothing);
      expect(next.isActive, isTrue);
      await pointer.up();
      await tester.pump(const Duration(milliseconds: 599));
      expect(find.text('next reminder'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('next reminder'), findsOneWidget);
      await tester.tap(find.byKey(_ack));
      await tester.pumpAndSettle();
      expect(await next.completed, isTrue);
    });
  }

  testWidgets(
    'a reminder waits behind an existing Flutter battle input guard',
    (tester) async {
      final h = await _Harness.mount(tester);
      final guard = GameSurfaceInputGuardRoute(context: h.context);
      unawaited(h.navigator.currentState!.push<void>(guard));
      await tester.pump();
      final pointer = await tester.startGesture(const Offset(20, 200));
      final presentation = h.show();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(_ack), findsNothing);
      await pointer.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_ack), findsOneWidget);
      await tester.tap(find.byKey(_ack));
      await tester.pumpAndSettle();
      expect(await presentation.completed, isTrue);
    },
  );

  testWidgets('a guard installed before actual push delays the reminder', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final presentation = h.show();
    final guard = GameSurfaceInputGuardRoute(context: h.context);
    unawaited(h.navigator.currentState!.push<void>(guard));
    await tester.pump();
    final pointer = await tester.startGesture(const Offset(20, 200));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(_ack), findsNothing);
    presentation.cancel();
    await pointer.up();
    await tester.pumpAndSettle();
    expect(await presentation.completed, isFalse);
    expect(find.byKey(_ack), findsNothing);
  });

  testWidgets('an existing battle warning has priority over a new reminder', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final battle = h.showBattle();
    await tester.pumpAndSettle();
    final presentation = h.show();
    await tester.pumpAndSettle();
    expect(find.text('battle warning'), findsOneWidget);
    expect(find.byKey(_ack), findsNothing);
    final guard = GameSurfaceInputGuardRoute(context: h.context);
    unawaited(h.navigator.currentState!.push<void>(guard));
    h.navigator.currentState!.removeRoute(battle);
    await tester.pump();
    final pointer = await tester.startGesture(const Offset(20, 200));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(_ack), findsNothing);
    await pointer.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_ack), findsOneWidget);
    await tester.tap(find.byKey(_ack));
    await tester.pumpAndSettle();
    expect(await presentation.completed, isTrue);
  });

  testWidgets(
    'battle installed before the actual reminder push keeps priority',
    (tester) async {
      final h = await _Harness.mount(tester);
      final presentation = h.show();
      final battle = h.showBattle();
      await tester.pumpAndSettle();
      expect(find.text('battle warning'), findsOneWidget);
      expect(find.byKey(_ack), findsNothing);
      presentation.cancel();
      h.navigator.currentState!.removeRoute(battle);
      await tester.pumpAndSettle();
      expect(await presentation.completed, isFalse);
      expect(find.byKey(_ack), findsNothing);
    },
  );

  testWidgets('battle can cover a reminder which resumes after battle guard', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final presentation = h.show();
    await tester.pumpAndSettle();
    final staleAcknowledge = h.acknowledge!;
    final battle = h.showBattle();
    await tester.pumpAndSettle();
    staleAcknowledge();
    expect(find.text('battle warning'), findsOneWidget);
    expect(presentation.isActive, isTrue);
    final guard = GameSurfaceInputGuardRoute(context: h.context);
    unawaited(h.navigator.currentState!.push<void>(guard));
    h.navigator.currentState!.removeRoute(battle);
    await tester.pump();
    expect(find.byKey(_guard), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(_ack), findsOneWidget);
    await tester.tap(find.byKey(_ack));
    await tester.pumpAndSettle();
    expect(await presentation.completed, isTrue);
  });

  testWidgets('native completion does not create a Flutter route or guard', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final native = _NativePort();
    final presentation = h.show(native: native);
    await tester.pumpAndSettle();
    expect(native.shown, hasLength(1));
    expect(native.shown.single['actions'], ['acknowledge']);
    expect(native.shown.single['body'], 'message\n\ndetail');
    expect(find.byKey(_ack), findsNothing);
    expect(presentation.isActive, isTrue);
    native.pending.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(await presentation.completed, isTrue);
    expect(find.byKey(_guard), findsNothing);
  });

  testWidgets('native cancellation rejects a late result', (tester) async {
    final h = await _Harness.mount(tester);
    final native = _NativePort();
    final presentation = h.show(native: native);
    await tester.pumpAndSettle();
    presentation.cancel();
    native.pending.complete(NativeGameWarningAction.acknowledge);
    await tester.pumpAndSettle();
    expect(await presentation.completed, isFalse);
    expect(native.dismissed, [native.shown.single['id']]);
    expect(find.byKey(_ack), findsNothing);
  });

  testWidgets('native unavailable falls back once to protected Flutter UI', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final native = _NativePort()..failure = StateError('unavailable');
    final presentation = h.show(native: native);
    await tester.pumpAndSettle();
    expect(native.shown, hasLength(1));
    expect(find.byKey(_ack), findsOneWidget);
    await tester.tap(find.byKey(_ack));
    await tester.pump();
    expect(find.byKey(_guard), findsOneWidget);
    await tester.pumpAndSettle();
    expect(await presentation.completed, isTrue);
    expect(native.shown, hasLength(1));
  });
}

class _Harness {
  final navigator = GlobalKey<NavigatorState>();
  final ownerVisible = ValueNotifier(true);
  final ownerGeneration = ValueNotifier(0);
  late BuildContext context;
  VoidCallback? onOwnerDispose;
  VoidCallback? onOwnerMount;
  VoidCallback? acknowledge;
  var gameTouches = 0;

  static Future<_Harness> mount(WidgetTester tester) async {
    final h = _Harness();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: h.navigator,
        home: ListenableBuilder(
          listenable: Listenable.merge([h.ownerVisible, h.ownerGeneration]),
          builder: (_, _) => h.ownerVisible.value
              ? _Owner(
                  key: ValueKey(h.ownerGeneration.value),
                  onDispose: () => h.onOwnerDispose?.call(),
                  onMount: () => h.onOwnerMount?.call(),
                  child: Builder(
                    builder: (context) {
                      h.context = context;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => h.gameTouches++,
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
    return h;
  }

  GameReminderDialogPresentation show({
    _NativePort? native,
    String kind = 'debuff',
    String title = 'title',
  }) => showGameReminderDialog(
    context: context,
    kind: kind,
    title: title,
    message: 'message',
    detail: 'detail',
    nativePort: native,
    builder: (_, callback) {
      acknowledge = callback;
      return AlertDialog(
        title: Text(title),
        actions: [
          FilledButton(
            key: _ack,
            onPressed: callback,
            child: const Text('acknowledge'),
          ),
        ],
      );
    },
  );

  GameSafetyDialogRoute showBattle() {
    final route = GameSafetyDialogRoute(
      context: context,
      builder: (_) => const AlertDialog(title: Text('battle warning')),
    );
    unawaited(navigator.currentState!.push<void>(route));
    return route;
  }
}

class _Owner extends StatefulWidget {
  const _Owner({
    super.key,
    required this.child,
    required this.onDispose,
    required this.onMount,
  });

  final Widget child;
  final VoidCallback onDispose;
  final VoidCallback onMount;

  @override
  State<_Owner> createState() => _OwnerState();
}

class _OwnerState extends State<_Owner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onMount();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }
}

class _NativePort implements NativeGameWarningDialogPort {
  final shown = <Map<String, Object?>>[];
  final dismissed = <int>[];
  final pending = Completer<NativeGameWarningAction?>();
  Object? failure;

  @override
  Future<NativeGameWarningAction?> show(Map<String, Object?> warning) {
    shown.add(warning);
    if (failure case final error?) return Future.error(error);
    return pending.future;
  }

  @override
  Future<void> dismiss(int id) async => dismissed.add(id);

  @override
  Future<void> update(Map<String, Object?> warning) async {}
}
