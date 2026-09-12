import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../account/account_session.dart';

import '../fleet/anchorage_repair_calculator.dart';
import '../game_state/game_state.dart';

class GlobalNotificationTimerAnchor {
  const GlobalNotificationTimerAnchor({
    required this.anchorAt,
    required this.signature,
  });

  final DateTime anchorAt;
  final String signature;

  Map<String, Object?> toJson() => {
    'anchorAtEpochMs': anchorAt.toUtc().millisecondsSinceEpoch,
    'signature': signature,
  };

  static GlobalNotificationTimerAnchor? fromJson(Object? value) {
    if (value is! Map) return null;
    final epoch = value['anchorAtEpochMs'];
    final signature = value['signature'];
    if (epoch is! num || signature is! String || signature.isEmpty) return null;
    return GlobalNotificationTimerAnchor(
      anchorAt: DateTime.fromMillisecondsSinceEpoch(epoch.toInt(), isUtc: true),
      signature: signature,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlobalNotificationTimerAnchor &&
      other.anchorAt.toUtc() == anchorAt.toUtc() &&
      other.signature == signature;

  @override
  int get hashCode => Object.hash(anchorAt.toUtc(), signature);
}

class MoraleNotificationTimerAnchor {
  const MoraleNotificationTimerAnchor({
    required this.fleetSignature,
    required this.observedAt,
    required this.observedCondition,
    required this.targetAt,
  });

  final String fleetSignature;
  final DateTime observedAt;
  final int observedCondition;
  final DateTime targetAt;

  Map<String, Object?> toJson() => {
    'fleetSignature': fleetSignature,
    'observedAtEpochMs': observedAt.toUtc().millisecondsSinceEpoch,
    'observedCondition': observedCondition,
    'targetAtEpochMs': targetAt.toUtc().millisecondsSinceEpoch,
  };

  static MoraleNotificationTimerAnchor? fromJson(Object? value) {
    if (value is! Map) return null;
    final signature = value['fleetSignature'];
    final observedAt = value['observedAtEpochMs'];
    final observedCondition = value['observedCondition'];
    final targetAt = value['targetAtEpochMs'];
    if (signature is! String ||
        signature.isEmpty ||
        observedAt is! num ||
        observedCondition is! num ||
        targetAt is! num) {
      return null;
    }
    return MoraleNotificationTimerAnchor(
      fleetSignature: signature,
      observedAt: DateTime.fromMillisecondsSinceEpoch(
        observedAt.toInt(),
        isUtc: true,
      ),
      observedCondition: observedCondition.toInt(),
      targetAt: DateTime.fromMillisecondsSinceEpoch(
        targetAt.toInt(),
        isUtc: true,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MoraleNotificationTimerAnchor &&
      other.fleetSignature == fleetSignature &&
      other.observedAt.toUtc() == observedAt.toUtc() &&
      other.observedCondition == observedCondition &&
      other.targetAt.toUtc() == targetAt.toUtc();

  @override
  int get hashCode => Object.hash(
    fleetSignature,
    observedAt.toUtc(),
    observedCondition,
    targetAt.toUtc(),
  );
}

class NotificationTimerAnchors {
  const NotificationTimerAnchors({
    this.akashi,
    this.nozaki,
    this.moraleByFleet = const {},
  });

  static const empty = NotificationTimerAnchors();

  final GlobalNotificationTimerAnchor? akashi;
  final GlobalNotificationTimerAnchor? nozaki;
  final Map<int, MoraleNotificationTimerAnchor> moraleByFleet;

  NotificationTimerAnchors copyWith({
    GlobalNotificationTimerAnchor? akashi,
    bool clearAkashi = false,
    GlobalNotificationTimerAnchor? nozaki,
    bool clearNozaki = false,
    Map<int, MoraleNotificationTimerAnchor>? moraleByFleet,
  }) => NotificationTimerAnchors(
    akashi: clearAkashi ? null : (akashi ?? this.akashi),
    nozaki: clearNozaki ? null : (nozaki ?? this.nozaki),
    moraleByFleet: moraleByFleet ?? this.moraleByFleet,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'akashi': akashi?.toJson(),
    'nozaki': nozaki?.toJson(),
    'moraleByFleet': {
      for (final entry in moraleByFleet.entries)
        entry.key.toString(): entry.value.toJson(),
    },
  };

  static NotificationTimerAnchors fromJson(Object? value) {
    if (value is! Map || value['schemaVersion'] != 1) return empty;
    final rawMorale = value['moraleByFleet'];
    final morale = <int, MoraleNotificationTimerAnchor>{};
    if (rawMorale is Map) {
      for (final entry in rawMorale.entries) {
        final fleetId = int.tryParse(entry.key.toString());
        final anchor = MoraleNotificationTimerAnchor.fromJson(entry.value);
        if (fleetId != null && anchor != null) morale[fleetId] = anchor;
      }
    }
    return NotificationTimerAnchors(
      akashi: GlobalNotificationTimerAnchor.fromJson(value['akashi']),
      nozaki: GlobalNotificationTimerAnchor.fromJson(value['nozaki']),
      moraleByFleet: morale,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! NotificationTimerAnchors ||
        other.akashi != akashi ||
        other.nozaki != nozaki ||
        other.moraleByFleet.length != moraleByFleet.length) {
      return false;
    }
    return moraleByFleet.entries.every(
      (entry) => other.moraleByFleet[entry.key] == entry.value,
    );
  }

  @override
  int get hashCode => Object.hash(
    akashi,
    nozaki,
    Object.hashAll(
      moraleByFleet.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}

abstract interface class NotificationTimerAnchorStore {
  Future<NotificationTimerAnchors> load();
  Future<void> save(NotificationTimerAnchors anchors);
}

abstract interface class AccountNotificationTimerAnchorStore {
  NotificationTimerAnchorStore forAccount(int memberId);
}

class SharedPreferencesNotificationTimerAnchorStore
    implements
        NotificationTimerAnchorStore,
        AccountNotificationTimerAnchorStore {
  const SharedPreferencesNotificationTimerAnchorStore({this.memberId});
  final int? memberId;

  static const key = 'yahagi_notification_timer_anchors';

  @override
  NotificationTimerAnchorStore forAccount(int memberId) =>
      SharedPreferencesNotificationTimerAnchorStore(memberId: memberId);

  String? _storageKey() {
    final id = memberId ?? AccountSession.shared.current.memberId;
    return id > 0 ? 'account.$id.$key' : null;
  }

  @override
  Future<NotificationTimerAnchors> load() async {
    final storageKey = _storageKey();
    if (storageKey == null) return NotificationTimerAnchors.empty;
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw == null || raw.isEmpty) return NotificationTimerAnchors.empty;
    return _decode(raw);
  }

  NotificationTimerAnchors _decode(String raw) {
    try {
      return NotificationTimerAnchors.fromJson(jsonDecode(raw));
    } catch (_) {
      return NotificationTimerAnchors.empty;
    }
  }

  @override
  Future<void> save(NotificationTimerAnchors anchors) async {
    final storageKey = _storageKey();
    if (storageKey == null) return;
    await (await SharedPreferences.getInstance()).setString(
      storageKey,
      jsonEncode(anchors.toJson()),
    );
  }
}

class NotificationTimerSignature {
  const NotificationTimerSignature._();

  static String? anchorage(GameState state) {
    if (!AnchorageRepairCalculator.hasReadyFleet(state)) return null;
    final fleet = state.fleets.where((fleet) => fleet.id == 1).firstOrNull;
    if (fleet == null) return null;
    return 'anchorage:${fleet.id}:${fleet.shipIds.join(',')}';
  }

  static String nozaki(GameState state) {
    final fleets = [...state.fleets]..sort((a, b) => a.id.compareTo(b.id));
    return 'nozaki:${fleets.map((fleet) => '${fleet.id}:${fleet.shipIds.join(',')}').join('|')}';
  }

  static String morale(Fleet fleet) =>
      'morale:${fleet.id}:${fleet.shipIds.join(',')}';
}
