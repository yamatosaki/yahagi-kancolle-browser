import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_session.dart';

abstract interface class ExpeditionSelectionStore {
  Future<int?> loadMissionId(int fleetId);

  Future<void> saveMissionId(int fleetId, int missionId);
}

final class SharedPreferencesExpeditionSelectionStore
    implements ExpeditionSelectionStore {
  const SharedPreferencesExpeditionSelectionStore({this.accountSession});

  final AccountSession? accountSession;
  AccountSession get _session => accountSession ?? AccountSession.shared;

  static String _missionKey(int fleetId) =>
      'expedition.selected_mission.fleet_$fleetId';

  @override
  Future<int?> loadMissionId(int fleetId) async {
    final scope = _session.current;
    if (!scope.isKnown) return null;
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getInt(scope.key(_missionKey(fleetId)));
    } catch (_) {
      // The expedition checker still works if local preferences are unavailable.
      return null;
    }
  }

  @override
  Future<void> saveMissionId(int fleetId, int missionId) async {
    final scope = _session.current;
    if (!scope.isKnown) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(scope.key(_missionKey(fleetId)), missionId);
    } catch (_) {
      // Remembering the selection is optional and must not block evaluation.
    }
  }
}
