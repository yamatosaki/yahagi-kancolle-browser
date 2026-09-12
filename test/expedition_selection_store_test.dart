import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/expedition/expedition_selection_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AccountSession.shared.selectMember(1001));

  test('按舰队分别保存并恢复上次选择的远征', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const store = SharedPreferencesExpeditionSelectionStore();

    await store.saveMissionId(2, 105);
    await store.saveMissionId(3, 112);

    expect(await store.loadMissionId(2), 105);
    expect(await store.loadMissionId(3), 112);
    expect(await store.loadMissionId(4), isNull);
  });
}
