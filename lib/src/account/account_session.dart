import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../bridge/captured_api_event.dart';
import '../game_state/game_api_event_pipeline.dart';

/// Capture once before queueing work; never derive a write's owner after await.
final class AccountScope {
  const AccountScope({
    required this.memberId,
    required this.generation,
    this.explicitlyReset = false,
  });

  final int memberId;
  final int generation;
  final bool explicitlyReset;
  bool get isKnown => memberId > 0;

  String key(String baseKey) {
    if (!isKnown) throw StateError('Account identity has not been confirmed');
    return 'account.$memberId.$baseKey';
  }
}

/// The game response, not a persisted last-used account, establishes identity.
/// This consumer must run before all consumers of account-specific data.
final class AccountSession extends ChangeNotifier
    implements GameApiEventConsumer {
  AccountSession({int initialMemberId = 0})
    : _current = AccountScope(
        memberId: initialMemberId > 0 ? initialMemberId : 0,
        generation: 0,
      );

  static final AccountSession shared = AccountSession();
  AccountScope _current;
  AccountScope get current => _current;
  String _admiralName = '';
  String _serverName = '';
  String get admiralName => _admiralName;
  String get serverName => _serverName;

  bool isCurrent(AccountScope scope) => identical(scope, _current);

  void reset() => _change(0, force: true, explicitlyReset: true);

  /// For identity confirmed by the game API (also useful for injected tests).
  void selectMember(int memberId) => _change(memberId > 0 ? memberId : 0);

  void _change(
    int memberId, {
    bool force = false,
    bool explicitlyReset = false,
  }) {
    if (!force && memberId == _current.memberId) return;
    _admiralName = '';
    _serverName = '';
    _current = AccountScope(
      memberId: memberId,
      generation: _current.generation + 1,
      explicitlyReset: explicitlyReset,
    );
    notifyListeners();
  }

  @override
  bool supportsPath(String path) =>
      path == '/kcsapi/api_start2/getData' ||
      path == '/kcsapi/api_get_member/basic' ||
      path == '/kcsapi/api_port/port';

  @override
  void accept(CapturedApiEvent event) {
    if (!supportsPath(event.path) || event.apiResult != 1) return;
    if (event.path == '/kcsapi/api_start2/getData') {
      _change(0, force: true);
      return;
    }
    try {
      final envelope = event.decodedEnvelope ?? jsonDecode(event.responseBody);
      if (envelope is! Map) return;
      final data = envelope['api_data'];
      final basic = event.path == '/kcsapi/api_port/port' && data is Map
          ? data['api_basic']
          : data;
      if (basic is! Map) return;
      final raw = basic['api_member_id'];
      final memberId = raw is num ? raw.toInt() : int.tryParse('$raw');
      if (memberId != null && memberId > 0) {
        final accountChanged = memberId != _current.memberId;
        final previousAdmiralName = _admiralName;
        final previousServerName = _serverName;
        // Publish the verified ID and its display metadata together. Backup
        // listeners must not observe an intermediate unnamed account.
        if (accountChanged) {
          _admiralName = '';
          _serverName = '';
          _current = AccountScope(
            memberId: memberId,
            generation: _current.generation + 1,
          );
        }
        final nickname = basic['api_nickname'];
        if (nickname is String && nickname.trim().isNotEmpty) {
          _admiralName = nickname.trim();
        }
        final host = Uri.tryParse(event.sourceOrigin)?.host ?? '';
        if (host.isNotEmpty) _serverName = host;
        if (accountChanged ||
            _admiralName != previousAdmiralName ||
            _serverName != previousServerName) {
          notifyListeners();
        }
      }
    } on FormatException {
      // Invalid responses cannot establish or replace an account.
    }
  }

  @override
  Future<void> get idle => Future<void>.value();
}
