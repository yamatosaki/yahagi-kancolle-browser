import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../account/shared_game_data.dart';
import 'game_state.dart';
import 'game_state_serializer.dart';

class GameStateStore {
  GameStateStore({this.saveDelay = const Duration(seconds: 5)});

  static const String _key = 'yahagi_kancolle_browser_game_state';
  static const String _sharedKey = 'game_state.shared.v1';
  static const String _migrationKey = 'game_state.legacy_migrated.v1';
  static const _masterKeys = <String>{
    'masterShipTypes',
    'masterShips',
    'masterSlotItems',
    'masterSlotItemTypes',
    'expansionSlotEquipmentTypeIds',
    'expansionSlotSpecialRules',
    'expansionSlotLimitsByShipId',
    'hasEquipmentCompatibilityData',
    'masterMissions',
    'masterMapInfos',
    'masterMapAreas',
    'hasMasterData',
  };
  static String _accountKey(int memberId) => 'account.$memberId.game_state.v1';
  final Duration saveDelay;
  Timer? _debounceTimer;
  final Map<int, GameState> _pendingStates = {};
  GameState? _pendingMaster;
  Future<void> _writes = Future<void>.value();

  Future<GameState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacy(prefs);
      final jsonStr = prefs.getString(_sharedKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return sharedGameData(GameStateSerializer.deserialize(jsonStr));
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
      final accountRaw = prefs.getString(_accountKey(memberId));
      if (accountRaw == null) return GameState.empty;
      final account = jsonDecode(accountRaw) as Map<String, dynamic>;
      if (account['memberId'] != memberId) return GameState.empty;
      final shared = jsonDecode(prefs.getString(_sharedKey) ?? '{}') as Map;
      return GameStateSerializer.deserialize(
        jsonEncode({...shared, ...account}),
      );
    } catch (_) {
      return GameState.empty;
    }
  }

  Map<String, dynamic> _personalData(GameState state) =>
      (jsonDecode(GameStateSerializer.serialize(state)) as Map<String, dynamic>)
        ..removeWhere((key, _) => _masterKeys.contains(key));

  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    if (prefs.getBool(_migrationKey) == true) return;
    final raw = prefs.getString(_key);
    if (raw != null) {
      final legacy = GameStateSerializer.deserialize(raw);
      // Keep the original global value as a backup, never as login identity.
      if (legacy.memberId > 0 &&
          !prefs.containsKey(_accountKey(legacy.memberId))) {
        await prefs.setString(
          _accountKey(legacy.memberId),
          jsonEncode(_personalData(legacy)),
        );
      }
      if (!prefs.containsKey(_sharedKey) && legacy.masterShips.isNotEmpty) {
        await prefs.setString(
          _sharedKey,
          GameStateSerializer.serialize(sharedGameData(legacy)),
        );
      }
    }
    await prefs.setBool(_migrationKey, true);
  }

  void save(GameState state) {
    if (state.memberId > 0) _pendingStates[state.memberId] = state;
    if (state.masterShips.isNotEmpty) _pendingMaster = sharedGameData(state);
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
    _pendingStates.clear();
    _pendingMaster = null;
    _writes = _writes.catchError((Object _) {}).then((_) async {
      if (states.isEmpty && master == null) return;
      final prefs = await SharedPreferences.getInstance();
      await _migrateLegacy(prefs);
      if (master != null) {
        await prefs.setString(
          _sharedKey,
          GameStateSerializer.serialize(master),
        );
      }
      for (final entry in states.entries) {
        await prefs.setString(
          _accountKey(entry.key),
          jsonEncode(_personalData(entry.value)),
        );
      }
    });
    try {
      await _writes;
    } catch (_) {
      // Do not make capture depend on optional disk persistence.
    }
  }
}
