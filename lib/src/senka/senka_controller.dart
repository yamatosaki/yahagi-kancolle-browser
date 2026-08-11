import 'dart:async';

import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import '../game_state/game_api_event_pipeline.dart';
import '../performance/frame_notification_coalescer.dart';
import 'senka_catalog.dart';
import 'senka_reducer.dart';
import 'senka_state.dart';
import 'senka_store.dart';

class SenkaController extends ChangeNotifier implements GameApiEventConsumer {
  SenkaController({
    required this.store,
    this._reducer = const SenkaReducer(),
    DateTime Function()? now,
    FrameNotificationCoalescer? captureNotifications,
  }) : _now = now ?? DateTime.now,
       _captureNotifications =
           captureNotifications ?? FrameNotificationCoalescer(),
       _state = SenkaState.forMonth(
         currentSenkaMonthKey((now ?? DateTime.now)()),
       );

  final SenkaStore store;
  final SenkaReducer _reducer;
  final FrameNotificationCoalescer _captureNotifications;
  final DateTime Function() _now;
  SenkaState _state;
  Future<void> _queue = Future<void>.value();
  bool _disposed = false;

  SenkaState get state => _state;
  @override
  Future<void> get idle => _queue;

  @override
  bool supportsPath(String path) => _reducer.supportsPath(path);

  Future<void> initialize() async {
    final loaded = await store.load();
    if (_disposed || loaded == null) return;
    final month = currentSenkaMonthKey(_now());
    _state = loaded.monthKey == month
        ? loaded
        : SenkaState.forMonth(month).copyWith(
            memberId: loaded.memberId,
            nickname: loaded.nickname,
            magic: loaded.magic,
          );
    notifyListeners();
  }

  @override
  void accept(CapturedApiEvent event) {
    if (_disposed) return;
    _queue = _queue.then((_) async {
      if (_disposed) return;
      final next = _reducer.reduce(_state, event);
      if (identical(next, _state)) return;
      _state = next;
      _captureNotifications.schedule(notifyListeners);
      await store.save(next);
    });
  }

  void toggleEo(int id) {
    if (senkaEoById(id) == null || _disposed) return;
    final values = Set<int>.of(_state.completedEoIds);
    values.contains(id) ? values.remove(id) : values.add(id);
    _replace(_state.copyWith(completedEoIds: values));
  }

  void toggleQuest(int id) {
    if (senkaQuestById(id) == null || _disposed) return;
    final values = Set<int>.of(_state.completedQuestIds);
    values.contains(id) ? values.remove(id) : values.add(id);
    _replace(_state.copyWith(completedQuestIds: values));
  }

  void _replace(SenkaState next) {
    _state = next;
    notifyListeners();
    _queue = _queue.then((_) => store.save(next));
  }

  @override
  void dispose() {
    _disposed = true;
    _captureNotifications.dispose();
    super.dispose();
  }
}
