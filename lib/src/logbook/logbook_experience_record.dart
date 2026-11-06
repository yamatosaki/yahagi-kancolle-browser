import 'dart:convert';

final class LogbookExperienceShip {
  const LogbookExperienceShip({
    required this.ownedShipId,
    required this.masterShipId,
    required this.name,
    required this.fleetId,
    required this.experience,
    this.retreated = false,
  });

  final int ownedShipId;
  final int masterShipId;
  final String name;
  final int fleetId;
  final int? experience;
  final bool retreated;

  Map<String, Object?> _toJson() => {
    'ownedShipId': ownedShipId,
    'masterShipId': masterShipId,
    'name': name,
    'fleetId': fleetId,
    'experience': experience,
    'retreated': retreated,
  };

  factory LogbookExperienceShip._fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid logbook experience ship');
    }
    final experience = _field<int?>(value, 'experience');
    if (experience != null && experience < 0) {
      throw const FormatException('Invalid logbook ship experience');
    }
    return LogbookExperienceShip(
      ownedShipId: _nonnegative(value, 'ownedShipId', minimum: 1),
      masterShipId: _nonnegative(value, 'masterShipId'),
      name: _field<String>(value, 'name'),
      fleetId: _nonnegative(value, 'fleetId', minimum: 1),
      experience: experience,
      retreated: _field<bool>(value, 'retreated'),
    );
  }
}

final class LogbookExperienceRecord {
  LogbookExperienceRecord({
    required this.eventKey,
    required this.completedAt,
    required this.isPractice,
    required this.mapAreaId,
    required this.mapInfoNo,
    required this.deckId,
    required this.battles,
    required List<LogbookExperienceShip> ships,
    this.incomplete = false,
  }) : ships = List.unmodifiable(ships);

  final String eventKey;
  final DateTime completedAt;
  final bool isPractice;
  final int mapAreaId;
  final int mapInfoNo;
  final int deckId;
  final int battles;
  final List<LogbookExperienceShip> ships;
  final bool incomplete;

  Map<String, Object?> toRow() => {
    'event_key': eventKey,
    'timestamp': completedAt.millisecondsSinceEpoch,
    'is_practice': isPractice ? 1 : 0,
    'map_area': mapAreaId,
    'map_no': mapInfoNo,
    'deck_id': deckId,
    'battle_count': battles,
    'incomplete': incomplete ? 1 : 0,
    'ships_json': jsonEncode(ships.map((ship) => ship._toJson()).toList()),
  };

  factory LogbookExperienceRecord.fromRow(Map<String, Object?> row) {
    final eventKey = _field<String>(row, 'event_key');
    final isPractice = _flag(row, 'is_practice');
    final battles = _nonnegative(row, 'battle_count', minimum: 1);
    if (eventKey.trim().isEmpty || (isPractice && battles != 1)) {
      throw const FormatException('Invalid logbook experience record');
    }
    final rawShips = jsonDecode(_field<String>(row, 'ships_json'));
    if (rawShips is! List) {
      throw const FormatException('Invalid logbook experience ships');
    }
    final ships = rawShips.map(LogbookExperienceShip._fromJson).toList();
    if (ships.map((ship) => ship.ownedShipId).toSet().length != ships.length) {
      throw const FormatException('Duplicate logbook experience ship');
    }
    return LogbookExperienceRecord(
      eventKey: eventKey,
      completedAt: DateTime.fromMillisecondsSinceEpoch(
        _field<int>(row, 'timestamp'),
        isUtc: true,
      ),
      isPractice: isPractice,
      mapAreaId: _nonnegative(row, 'map_area'),
      mapInfoNo: _nonnegative(row, 'map_no'),
      deckId: _nonnegative(row, 'deck_id'),
      battles: battles,
      ships: ships,
      incomplete: _flag(row, 'incomplete'),
    );
  }
}

T _field<T>(Map<String, Object?> values, String key) {
  final value = values[key];
  if (!values.containsKey(key) || value is! T) {
    throw FormatException('Invalid logbook experience field: $key');
  }
  return value;
}

int _nonnegative(Map<String, Object?> values, String key, {int minimum = 0}) {
  final value = _field<int>(values, key);
  if (value < minimum) {
    throw FormatException('Invalid logbook experience field: $key');
  }
  return value;
}

bool _flag(Map<String, Object?> values, String key) =>
    switch (_field<int>(values, key)) {
      0 => false,
      1 => true,
      _ => throw FormatException('Invalid logbook experience field: $key'),
    };
