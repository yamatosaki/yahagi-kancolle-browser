import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_session.dart';
import 'senka_state.dart';

abstract interface class SenkaStore {
  Future<SenkaState?> load();
  Future<void> save(SenkaState state);
}

abstract interface class AccountSenkaStore implements SenkaStore {
  Future<SenkaState?> loadForAccount(int memberId);
}

class SharedPreferencesSenkaStore implements AccountSenkaStore {
  SharedPreferencesSenkaStore(
    this.preferences, {
    AccountSession? accountSession,
  }) : accountSession = accountSession ?? AccountSession.shared;

  static const _key = 'senka.archive.v1';
  final SharedPreferences preferences;
  final AccountSession accountSession;

  static Future<SharedPreferencesSenkaStore> create({
    AccountSession? accountSession,
  }) async => SharedPreferencesSenkaStore(
    await SharedPreferences.getInstance(),
    accountSession: accountSession,
  );

  @override
  Future<SenkaState?> load() => loadForAccount(accountSession.current.memberId);

  @override
  Future<SenkaState?> loadForAccount(int memberId) async {
    if (memberId <= 0) return null;
    final key = AccountScope(memberId: memberId, generation: 0).key(_key);
    final raw = preferences.getString(key) ?? preferences.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final state = SenkaState.fromJson(jsonDecode(raw));
      if (state.memberId != memberId) return null;
      if (!preferences.containsKey(key)) {
        // The legacy archive identifies its owner. Keep the original as a
        // backup, and never assign anonymous archives to the first login.
        await preferences.setString(key, raw);
      }
      return state;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(SenkaState state) async {
    if (state.memberId <= 0) return;
    final key = AccountScope(memberId: state.memberId, generation: 0).key(_key);
    await preferences.setString(key, jsonEncode(state.toJson()));
  }
}
