import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../account/account_session.dart';

const Set<int> validFormationIds = <int>{1, 2, 3, 4, 5, 6, 11, 12, 13, 14};

final RegExp _formationMemoryKeyPattern = RegExp(
  r'^[1-9]\d*-[1-9]\d*-[1-9]\d*$',
);

String formationMemoryKey({
  required int mapAreaId,
  required int mapInfoNo,
  required int node,
}) => '$mapAreaId-$mapInfoNo-$node';

bool isValidFormationMemoryKey(String value) =>
    _formationMemoryKeyPattern.hasMatch(value);

abstract interface class FormationMemoryStore {
  Future<Map<String, int>> load();

  Future<void> save(Map<String, int> formations);
}

abstract interface class AccountFormationMemoryStore {
  FormationMemoryStore forAccount(int memberId);
}

final class SharedPreferencesFormationMemoryStore
    implements FormationMemoryStore, AccountFormationMemoryStore {
  SharedPreferencesFormationMemoryStore({this.memberId});
  final int? memberId;
  static const String _key = 'battle.formationMemory';

  @override
  FormationMemoryStore forAccount(int memberId) =>
      SharedPreferencesFormationMemoryStore(memberId: memberId);

  String? _storageKey() {
    final id = memberId ?? AccountSession.shared.current.memberId;
    return id > 0 ? 'account.$id.$_key' : null;
  }

  @override
  Future<Map<String, int>> load() async {
    final key = _storageKey();
    if (key == null) return {};
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return <String, int>{
        for (final entry in decoded.entries)
          if (entry.key is String &&
              isValidFormationMemoryKey(entry.key as String) &&
              entry.value is int &&
              validFormationIds.contains(entry.value))
            entry.key as String: entry.value as int,
      };
    } on FormatException {
      return <String, int>{};
    }
  }

  @override
  Future<void> save(Map<String, int> formations) async {
    final key = _storageKey();
    if (key == null) return;
    final saved = await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(formations),
    );
    if (!saved) throw StateError('formation memory was not saved');
  }
}

final class MemoryFormationMemoryStore
    implements FormationMemoryStore, AccountFormationMemoryStore {
  MemoryFormationMemoryStore([Map<String, int> initial = const <String, int>{}])
    : _values = Map<String, int>.from(initial);

  Map<String, int> _values;
  int saveCount = 0;
  final Map<int, MemoryFormationMemoryStore> _accounts = {};

  @override
  FormationMemoryStore forAccount(int memberId) =>
      _accounts.putIfAbsent(memberId, MemoryFormationMemoryStore.new);

  Map<String, int> get values => Map<String, int>.unmodifiable(_values);

  @override
  Future<Map<String, int>> load() async => Map<String, int>.from(_values);

  @override
  Future<void> save(Map<String, int> formations) async {
    saveCount++;
    _values = Map<String, int>.from(formations);
  }
}

final class FormationMemoryController {
  FormationMemoryController._(
    this._store,
    this._formations,
    this.accountSession,
  ) {
    accountSession?.addListener(_onAccountChanged);
  }

  final FormationMemoryStore _store;
  final Map<String, int> _formations;
  Future<void> _pendingSave = Future<void>.value();
  Future<void> _ready = Future<void>.value();
  final AccountSession? accountSession;
  bool _disposed = false;
  Future<void> get idle async {
    await _ready;
    await _pendingSave;
  }

  FormationMemoryStore? _storeFor(AccountScope? scope) {
    if (scope == null) return _store;
    if (!scope.isKnown) return null;
    return _store is AccountFormationMemoryStore
        ? (_store as AccountFormationMemoryStore).forAccount(scope.memberId)
        : null;
  }

  void _onAccountChanged() {
    _formations.clear();
    final scope = accountSession!.current;
    final store = _storeFor(scope);
    _ready = () async {
      await _pendingSave.catchError((Object _) {});
      final values = await store?.load() ?? <String, int>{};
      if (!_disposed && accountSession!.isCurrent(scope)) {
        _formations.addAll(values);
      }
    }();
  }

  void dispose() {
    _disposed = true;
    accountSession?.removeListener(_onAccountChanged);
  }

  static Future<FormationMemoryController> load(
    FormationMemoryStore store, {
    AccountSession? accountSession,
  }) async {
    final controller = FormationMemoryController._(store, {}, accountSession);
    if (accountSession != null) {
      controller._onAccountChanged();
      await controller._ready;
    } else {
      controller._formations.addAll(await store.load());
    }
    return controller;
  }

  int? formationFor({
    required int mapAreaId,
    required int mapInfoNo,
    required int node,
  }) {
    if (_disposed || accountSession?.current.isKnown == false) return null;
    if (mapAreaId <= 0 || mapInfoNo <= 0 || node <= 0) return null;
    return _formations[formationMemoryKey(
      mapAreaId: mapAreaId,
      mapInfoNo: mapInfoNo,
      node: node,
    )];
  }

  Future<void> remember({
    required int mapAreaId,
    required int mapInfoNo,
    required int node,
    required int formation,
  }) {
    final targetStore = _storeFor(accountSession?.current);
    if (_disposed || targetStore == null) return Future<void>.value();
    if (!validFormationIds.contains(formation) ||
        mapAreaId <= 0 ||
        mapInfoNo <= 0 ||
        node <= 0) {
      return Future<void>.value();
    }
    final key = formationMemoryKey(
      mapAreaId: mapAreaId,
      mapInfoNo: mapInfoNo,
      node: node,
    );
    if (_formations[key] == formation) return Future<void>.value();
    _formations[key] = formation;
    final snapshot = Map<String, int>.unmodifiable(_formations);
    final operation = _pendingSave
        .catchError((Object _) {})
        .then((_) => targetStore.save(snapshot));
    _pendingSave = operation;
    return operation;
  }
}
