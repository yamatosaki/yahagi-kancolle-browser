import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/development/development_resources.dart';
import 'package:yahagi_kancolle_browser/src/development/development_workbench_state_store.dart';

void main() {
  setUp(() async {
    AccountSession.shared.selectMember(1001);
    await SharedPreferencesDevelopmentWorkbenchStateStore.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('workbench state round trips every persisted field', () {
    final state = _sampleState();

    expect(DevelopmentWorkbenchState.fromJson(state.toJson()), state);
  });

  test('shared preferences store persists state', () async {
    final store = SharedPreferencesDevelopmentWorkbenchStateStore();
    final state = _sampleState();

    await store.save(state);

    expect(await store.load(), state);
  });

  test('shared preferences store ignores damaged state', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'account.1001.development_workbench_state_v1',
      '{broken',
    );

    expect(
      await SharedPreferencesDevelopmentWorkbenchStateStore().load(),
      isNull,
    );
  });
}

DevelopmentWorkbenchState _sampleState() => const DevelopmentWorkbenchState(
  mode: DevelopmentWorkbenchMode.formula,
  selectedPoolKey: 'carrier-akagi#1',
  followsCurrentFlagship: false,
  resources: DevelopmentResources(20, 30, 40, 50),
  targetIds: <int>[7, 8],
  recipeSort: DevelopmentRecipeSortField.totalResources,
  sortAscending: true,
);
