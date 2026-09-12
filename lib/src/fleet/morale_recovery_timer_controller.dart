import 'package:flutter/foundation.dart';

import '../game_state/game_state.dart';
import '../notification/notification_timer_anchor_store.dart';

typedef MoraleRecoveryAnchorsChanged =
    void Function(Map<int, MoraleNotificationTimerAnchor> anchors);

class MoraleRecoveryTimerController extends ChangeNotifier {
  MoraleRecoveryTimerController({
    Map<int, MoraleNotificationTimerAnchor> initialAnchors = const {},
    this.onAnchorsChanged,
  }) : _anchors = Map<int, MoraleNotificationTimerAnchor>.from(initialAnchors),
       super();

  Map<int, MoraleNotificationTimerAnchor> _anchors;
  int? _memberId;
  final MoraleRecoveryAnchorsChanged? onAnchorsChanged;

  Map<int, MoraleNotificationTimerAnchor> get anchors =>
      Map<int, MoraleNotificationTimerAnchor>.unmodifiable(_anchors);

  DateTime? targetForFleet(int fleetId) => _anchors[fleetId]?.targetAt;

  void reconcile(GameState state, {DateTime? now}) {
    if (_memberId != null && _memberId != state.memberId) {
      _anchors = {};
    }
    _memberId = state.memberId;
    final fallbackNow = (now ?? DateTime.now()).toUtc();
    final next = <int, MoraleNotificationTimerAnchor>{};

    for (final fleet in state.fleets) {
      if (fleet.shipIds.isEmpty) continue;
      final conditions = fleet.shipIds
          .map((shipId) => state.ships[shipId]?.condition)
          .whereType<int>()
          .toList(growable: false);
      if (conditions.length != fleet.shipIds.length) continue;

      final minimumCondition = conditions.reduce(
        (left, right) => left < right ? left : right,
      );
      if (minimumCondition >= 49) continue;

      final signature = NotificationTimerSignature.morale(fleet);
      final existing = _anchors[fleet.id];
      if (existing != null &&
          existing.fleetSignature == signature &&
          existing.observedCondition == minimumCondition) {
        next[fleet.id] = existing;
        continue;
      }

      final observedAt = (state.updatedAt ?? fallbackNow).toUtc();
      final neededTicks = ((49 - minimumCondition) / 3).ceil();
      next[fleet.id] = MoraleNotificationTimerAnchor(
        fleetSignature: signature,
        observedAt: observedAt,
        observedCondition: minimumCondition,
        targetAt: observedAt.add(Duration(minutes: neededTicks * 3)),
      );
    }

    _setAnchors(next, persist: true);
  }

  void replaceAnchors(Map<int, MoraleNotificationTimerAnchor> anchors) {
    _memberId = null;
    _setAnchors(anchors, persist: false);
  }

  void _setAnchors(
    Map<int, MoraleNotificationTimerAnchor> anchors, {
    required bool persist,
  }) {
    if (_mapsEqual(_anchors, anchors)) return;
    _anchors = Map<int, MoraleNotificationTimerAnchor>.from(anchors);
    notifyListeners();
    if (persist) onAnchorsChanged?.call(this.anchors);
  }

  static bool _mapsEqual(
    Map<int, MoraleNotificationTimerAnchor> left,
    Map<int, MoraleNotificationTimerAnchor> right,
  ) {
    if (left.length != right.length) return false;
    return left.entries.every((entry) => right[entry.key] == entry.value);
  }
}
