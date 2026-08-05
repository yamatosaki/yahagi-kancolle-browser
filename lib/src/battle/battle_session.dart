import 'battle_models.dart';

class BattleSessionPacket {
  const BattleSessionPacket({
    required this.path,
    required this.sequence,
    required this.capturedAt,
    required this.data,
  });

  final String path;
  final int sequence;
  final DateTime capturedAt;
  final Map<String, Object?> data;
}

class BattleSessionIssue {
  const BattleSessionIssue({required this.stage, required this.message});

  final String stage;
  final String message;
}

/// Position-preserving state for one map-node battle from navigation to result.
///
/// Slots are fixed at six entries per fleet. Diagnostics are bounded and
/// recursively stripped of credentials before they can be retained.
class BattleSession {
  BattleSession({
    required this.id,
    required this.context,
    required this.startedAt,
    List<BattleShipSnapshot> friendMain = const <BattleShipSnapshot>[],
    List<BattleShipSnapshot> friendEscort = const <BattleShipSnapshot>[],
    List<BattleShipSnapshot> enemyMain = const <BattleShipSnapshot>[],
    List<BattleShipSnapshot> enemyEscort = const <BattleShipSnapshot>[],
    this.maxDiagnosticPackets = 64,
  }) : assert(maxDiagnosticPackets > 0),
       friendMainSlots = _slots(friendMain),
       friendEscortSlots = _slots(friendEscort),
       enemyMainSlots = _slots(enemyMain),
       enemyEscortSlots = _slots(enemyEscort);

  final String id;
  final BattleContext context;
  final DateTime startedAt;
  final int maxDiagnosticPackets;
  final List<BattleShipSnapshot?> friendMainSlots;
  final List<BattleShipSnapshot?> friendEscortSlots;
  final List<BattleShipSnapshot?> enemyMainSlots;
  final List<BattleShipSnapshot?> enemyEscortSlots;
  final List<BattleSessionPacket> _packets = <BattleSessionPacket>[];
  final List<BattleSessionIssue> _issues = <BattleSessionIssue>[];

  bool completed = false;

  List<BattleSessionPacket> get packets => List.unmodifiable(_packets);
  List<BattleSessionIssue> get issues => List.unmodifiable(_issues);
  bool get isConfirmed => _issues.isEmpty;

  void updateFleets({
    required List<BattleShipSnapshot> friendMain,
    required List<BattleShipSnapshot> friendEscort,
    required List<BattleShipSnapshot> enemyMain,
    required List<BattleShipSnapshot> enemyEscort,
  }) {
    _replaceSlots(friendMainSlots, friendMain);
    _replaceSlots(friendEscortSlots, friendEscort);
    _replaceSlots(enemyMainSlots, enemyMain);
    _replaceSlots(enemyEscortSlots, enemyEscort);
  }

  void appendPacket({
    required String path,
    required int sequence,
    required DateTime capturedAt,
    required Map<String, Object?> data,
  }) {
    _packets.add(
      BattleSessionPacket(
        path: path,
        sequence: sequence,
        capturedAt: capturedAt,
        data: _sanitizeMap(data),
      ),
    );
    if (_packets.length > maxDiagnosticPackets) {
      _packets.removeRange(0, _packets.length - maxDiagnosticPackets);
    }
  }

  void markUnconfirmed({required String stage, required String message}) {
    _issues.add(BattleSessionIssue(stage: stage, message: message));
  }

  static List<BattleShipSnapshot?> _slots(List<BattleShipSnapshot> ships) {
    final result = List<BattleShipSnapshot?>.filled(6, null);
    _replaceSlots(result, ships);
    return result;
  }

  static void _replaceSlots(
    List<BattleShipSnapshot?> result,
    List<BattleShipSnapshot> ships,
  ) {
    result.fillRange(0, result.length, null);
    for (final ship in ships) {
      if (ship.position >= 0 && ship.position < result.length) {
        result[ship.position] = ship;
      }
    }
  }

  static Map<String, Object?> _sanitizeMap(Map<String, Object?> source) {
    return <String, Object?>{
      for (final entry in source.entries)
        if (!_isSensitiveKey(entry.key)) entry.key: _sanitize(entry.value),
    };
  }

  static Object? _sanitize(Object? value) {
    if (value is Map) {
      return _sanitizeMap(
        value.map((key, child) => MapEntry(key.toString(), child)),
      );
    }
    if (value is List) {
      return <Object?>[for (final child in value) _sanitize(child)];
    }
    return value;
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('token') ||
        normalized.contains('cookie') ||
        normalized.contains('password') ||
        normalized.contains('authorization') ||
        normalized.contains('member_id') ||
        normalized.contains('user_id');
  }
}
