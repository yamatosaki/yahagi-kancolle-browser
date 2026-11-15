import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../account/shared_game_data.dart';
import 'game_state.dart';
import 'game_state_serializer.dart';
import 'master_ship_names.dart';

class GameStateStore {
  GameStateStore({
    this.saveDelay = const Duration(seconds: 5),
    this.writeString,
    this.masterShipNames = const MasterShipNames(),
  });

  static const String _key = 'yahagi_kancolle_browser_game_state';
  static const String _sharedKey = 'game_state.shared.v1';
  static const String _migrationKey = 'game_state.legacy_migrated.v1';
  static String _accountKey(int memberId) => 'account.$memberId.game_state.v1';
  final Duration saveDelay;
  final Future<bool> Function(SharedPreferences, String, String)? writeString;
  final MasterShipNames masterShipNames;
  Timer? _debounceTimer;
  final Map<int, GameState> _pendingStates = {};
  Map<String, Object?>? _pendingMaster;
  Map<String, Object?>? _latestSharedData;
  Future<void> _writes = Future<void>.value();

  Future<void> _putString(
    SharedPreferences prefs,
    String key,
    String value,
  ) async {
    final saved =
        await (writeString?.call(prefs, key, value) ??
            prefs.setString(key, value));
    if (!saved) throw StateError('Game state cache write failed');
  }

  Future<GameState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacy(prefs);
      final jsonStr = prefs.getString(_sharedKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return sharedGameData(
          GameStateSerializer.deserialize(
            jsonStr,
            masterShipNames: masterShipNames,
          ),
        );
      }
    } catch (e) {
      // Ignore load errors and return empty state
    }
    return GameState.empty;
  }

  Future<GameState> loadForAccount(int memberId) async {
    if (memberId <= 0) return load();
    await flush();
    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacy(prefs);
      final pending = _pendingStates[memberId];
      final accountRaw = pending == null
          ? prefs.getString(_accountKey(memberId))
          : jsonEncode(GameStateSerializer.personalData(pending));
      if (accountRaw == null) return GameState.empty;
      final account = jsonDecode(accountRaw) as Map<String, dynamic>;
      if (account['memberId'] != memberId) return GameState.empty;
      final shared = _pendingMaster == null
          ? jsonDecode(prefs.getString(_sharedKey) ?? '{}') as Map
          : _pendingMaster!;
      return GameStateSerializer.deserialize(
        jsonEncode({...shared, ...account}),
        masterShipNames: masterShipNames,
      );
    } catch (_) {
      return _pendingStates[memberId] ?? GameState.empty;
    }
  }

  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    if (prefs.getBool(_migrationKey) == true) return;
    final raw = prefs.getString(_key);
    if (raw != null) {
      final legacy = GameStateSerializer.deserialize(
        raw,
        masterShipNames: masterShipNames,
      );
      // Keep the original global value as a backup, never as login identity.
      if (legacy.memberId > 0 &&
          !prefs.containsKey(_accountKey(legacy.memberId))) {
        await _putString(
          prefs,
          _accountKey(legacy.memberId),
          jsonEncode(GameStateSerializer.personalData(legacy)),
        );
      }
      if (!prefs.containsKey(_sharedKey) && legacy.masterShips.isNotEmpty) {
        await _putString(
          prefs,
          _sharedKey,
          jsonEncode(GameStateSerializer.sharedData(legacy)),
        );
      }
    }
    if (!await prefs.setBool(_migrationKey, true)) {
      throw StateError('Game state cache migration marker failed');
    }
  }

  void save(GameState state) {
    if (state.memberId > 0) _pendingStates[state.memberId] = state;
    if (_hasSharedData(state)) {
      final shared = GameStateSerializer.sharedData(state);
      if (!_sameData(shared, _latestSharedData)) {
        _latestSharedData = shared;
        _pendingMaster = shared;
      }
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(saveDelay, () {
      unawaited(flush());
    });
  }

  Future<void> flush() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final states = Map<int, GameState>.of(_pendingStates);
    final master = _pendingMaster;
    _writes = _writes.catchError((Object _) {}).then((_) async {
      if (states.isEmpty && master == null) return;
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacy(prefs);
      if (master != null) {
        await _putString(prefs, _sharedKey, jsonEncode(master));
        if (identical(_pendingMaster, master)) _pendingMaster = null;
      }
      for (final entry in states.entries) {
        await _putString(
          prefs,
          _accountKey(entry.key),
          jsonEncode(GameStateSerializer.personalData(entry.value)),
        );
        if (identical(_pendingStates[entry.key], entry.value)) {
          _pendingStates.remove(entry.key);
        }
      }
    });
    try {
      await _writes;
    } catch (_) {
      // Do not make capture depend on optional disk persistence.
      _debounceTimer ??= Timer(saveDelay, () => unawaited(flush()));
    }
  }
}

bool _hasSharedData(GameState state) =>
    state.hasMasterData ||
    state.masterShips.isNotEmpty ||
    state.masterShipTypes.isNotEmpty ||
    state.masterSlotItems.isNotEmpty ||
    state.masterSlotItemTypes.isNotEmpty ||
    state.expansionSlotEquipmentTypeIds.isNotEmpty ||
    state.expansionSlotSpecialRules.isNotEmpty ||
    state.expansionSlotLimitsByShipId.isNotEmpty ||
    state.hasEquipmentCompatibilityData ||
    state.masterMissions.isNotEmpty ||
    state.masterMapInfos.isNotEmpty ||
    state.masterMapAreas.isNotEmpty;

bool _sameData(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _sameData(a[key], b[key]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (!_sameData(a[index], b[index])) return false;
    }
    return true;
  }
  return a == b;
}
