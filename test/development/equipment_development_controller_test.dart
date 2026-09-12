import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/account/account_session.dart';
import 'package:yahagi_kancolle_browser/src/development/development_repository.dart';
import 'package:yahagi_kancolle_browser/src/development/development_resources.dart';
import 'package:yahagi_kancolle_browser/src/development/development_workbench_state_store.dart';
import 'package:yahagi_kancolle_browser/src/development/equipment_development_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

void main() {
  setUp(() => AccountSession.shared.selectMember(1001));

  test(
    'a delayed previous account load cannot replace the new account plan',
    () async {
      final session = AccountSession(initialMemberId: 1001);
      addTearDown(session.dispose);
      final store = _DeferredStateStore();
      final controller = EquipmentDevelopmentController(
        repository: _repository(),
        stateStore: store,
        accountSession: session,
      );
      addTearDown(controller.dispose);
      final initializing = controller.initialize(_stateWithFlagship(101));
      session.selectMember(2002);
      store.loads[1].complete(const DevelopmentWorkbenchState(targetIds: [8]));
      await Future<void>.delayed(Duration.zero);
      store.loads[0].complete(const DevelopmentWorkbenchState(targetIds: [7]));
      await initializing;
      expect(controller.targets, {8});
      expect(controller.dataset, isNotNull);
    },
  );

  test(
    'switching accounts clears previous development targets and manual recipe',
    () async {
      final controller = EquipmentDevelopmentController(
        repository: _repository(),
      );
      addTearDown(controller.dispose);
      await controller.initialize(_stateWithFlagship(101));
      controller.toggleTarget(7);
      controller.selectPool('gunnery-other#3');
      controller.commitResources(const DevelopmentResources(20, 30, 40, 50));
      AccountSession.shared.selectMember(2002);
      expect(controller.targets, isEmpty);
      expect(controller.followsCurrentFlagship, isTrue);
      expect(controller.resources, const DevelopmentResources(10, 10, 10, 10));
    },
  );
  test(
    'initializes from fleet 1 flagship and preserves manual pool selection',
    () async {
      final controller = EquipmentDevelopmentController(
        repository: _repository(),
      );
      await controller.initialize(_stateWithFlagship(101));
      expect(controller.selectedPoolKey, 'carrier-akagi#1');

      controller.selectPool('carrier-akagi#1');
      controller.updateGameState(_stateWithFlagship(202));
      expect(controller.selectedPoolKey, 'carrier-akagi#1');

      controller.selectPool('gunnery-other#3');
      controller.updateGameState(_stateWithFlagship(202));
      expect(controller.selectedPoolKey, 'gunnery-other#3');

      controller.useCurrentFlagship();
      expect(controller.selectedPoolKey, 'torpedo-sendai#2');

      controller.selectPool('gunnery-other#3');
      controller.updateGameState(_stateWithFlagship(303));
      expect(controller.useCurrentFlagship(), isFalse);
      expect(controller.selectedPoolKey, 'gunnery-other#3');
    },
  );

  test('invalid resources do not replace the committed recipe', () async {
    final controller = EquipmentDevelopmentController(
      repository: _repository(),
    );
    await controller.initialize(_stateWithFlagship(101));

    controller.commitResources(const DevelopmentResources(20, 30, 40, 50));
    controller.commitResources(const DevelopmentResources(9, 30, 40, 50));
    expect(controller.resources, const DevelopmentResources(20, 30, 40, 50));
  });

  test('target selection and search update the derived picker state', () async {
    final controller = EquipmentDevelopmentController(
      repository: _repository(),
    );
    await controller.initialize(_stateWithFlagship(101));

    expect(controller.filteredEquipment.map((item) => item.id), contains(7));
    controller.toggleTarget(7);
    expect(controller.targets, {7});
    expect(controller.recipes, isNotEmpty);
    expect(controller.filteredEquipment.map((item) => item.id), contains(9));
    expect(controller.enabledEquipment, isNot(contains(9)));

    controller.setEquipmentSearch('雷达');
    expect(controller.filteredEquipment.map((item) => item.id), [8]);
    controller.setEquipmentTypeFilter(1);
    expect(controller.filteredEquipment, isEmpty);
  });

  test('equipment type name comes from captured master data', () async {
    final controller = EquipmentDevelopmentController(
      repository: _repository(),
    );
    await controller.initialize(_stateWithFlagship(101));

    expect(controller.equipmentTypeName(1), '小口径主炮');
  });

  test('equipment filtering combines a requested type with search', () async {
    final controller = EquipmentDevelopmentController(
      repository: _repository(),
    );
    await controller.initialize(_stateWithFlagship(101));
    controller.setEquipmentSearch('测试');

    expect(controller.filteredEquipmentForType(1).map((item) => item.id), [7]);
    expect(controller.filteredEquipmentForType(12).map((item) => item.id), [8]);
    expect(
      controller.filteredEquipmentForTypes({1, 12}).map((item) => item.id),
      [7, 8],
    );
  });

  test('equipment search matches every localized name', () async {
    final controller = EquipmentDevelopmentController(
      repository: _repository(),
    );
    await controller.initialize(_stateWithFlagship(101));

    controller.setEquipmentSearch('測試主砲');

    expect(controller.filteredEquipment.map((item) => item.id), [7]);
  });

  test('default recipe ordering preserves calculator tie breakers', () async {
    final controller = EquipmentDevelopmentController(
      repository: _repository(),
    );
    await controller.initialize(_stateWithFlagship(101));
    controller.toggleTarget(7);

    expect(controller.recipes.first.poolKey, 'gunnery-other#3');
  });

  test('finishing a delayed load after dispose is harmless', () async {
    final source = Completer<String>();
    final controller = EquipmentDevelopmentController(
      repository: DevelopmentRepository(loadString: (_) => source.future),
    );
    final loading = controller.initialize(_stateWithFlagship(101));
    controller.dispose();

    source.complete(jsonEncode(_snapshot()));
    await expectLater(loading, completes);
  });

  test('repository failure leaves a retryable error state', () async {
    var calls = 0;
    final repository = DevelopmentRepository(
      loadString: (_) async {
        calls++;
        if (calls == 1) throw StateError('temporary');
        return jsonEncode(_snapshot());
      },
    );
    final controller = EquipmentDevelopmentController(repository: repository);

    await controller.initialize(_stateWithFlagship(101));
    expect(controller.error, isNotNull);
    await controller.retry();
    expect(controller.error, isNull);
    expect(controller.selectedPoolKey, 'carrier-akagi#1');
  });

  test('retry restores the state loaded before a repository failure', () async {
    var calls = 0;
    final controller = EquipmentDevelopmentController(
      repository: DevelopmentRepository(
        loadString: (_) async {
          calls++;
          if (calls == 1) throw StateError('temporary');
          return jsonEncode(_snapshot());
        },
      ),
      stateStore: _MemoryStateStore(
        const DevelopmentWorkbenchState(
          mode: DevelopmentWorkbenchMode.formula,
          resources: DevelopmentResources(20, 30, 40, 50),
          targetIds: <int>[7],
          recipeSort: DevelopmentRecipeSortField.totalResources,
          sortAscending: true,
        ),
      ),
    );

    await controller.initialize(_stateWithFlagship(101));
    expect(controller.error, isNotNull);
    await controller.retry();

    expect(controller.mode, DevelopmentWorkbenchMode.formula);
    expect(controller.resources, const DevelopmentResources(20, 30, 40, 50));
    expect(controller.targets, <int>{7});
    expect(controller.recipeSort, DevelopmentRecipeSortField.totalResources);
    expect(controller.sortAscending, isTrue);
  });

  test('state and repository loading start in parallel', () async {
    final state = Completer<DevelopmentWorkbenchState?>();
    final dataset = Completer<String>();
    var repositoryStarted = false;
    final controller = EquipmentDevelopmentController(
      repository: DevelopmentRepository(
        loadString: (_) {
          repositoryStarted = true;
          return dataset.future;
        },
      ),
      stateStore: _MemoryStateStore.future(state.future),
    );

    final initialization = controller.initialize(_stateWithFlagship(101));
    await Future<void>.delayed(Duration.zero);
    expect(controller.isLoading, isTrue);
    expect(repositoryStarted, isTrue);

    state.complete(null);
    dataset.complete(jsonEncode(_snapshot()));
    await initialization;
  });
}

final class _DeferredStateStore implements DevelopmentWorkbenchStateStore {
  final List<Completer<DevelopmentWorkbenchState?>> loads = [];
  @override
  Future<DevelopmentWorkbenchState?> load() {
    final completer = Completer<DevelopmentWorkbenchState?>();
    loads.add(completer);
    return completer.future;
  }

  @override
  Future<void> save(DevelopmentWorkbenchState state) async {}
}

final class _MemoryStateStore implements DevelopmentWorkbenchStateStore {
  _MemoryStateStore(DevelopmentWorkbenchState? state)
    : _state = Future<DevelopmentWorkbenchState?>.value(state);

  _MemoryStateStore.future(this._state);

  final Future<DevelopmentWorkbenchState?> _state;

  @override
  Future<DevelopmentWorkbenchState?> load() => _state;

  @override
  Future<void> save(DevelopmentWorkbenchState state) async {}
}

DevelopmentRepository _repository() =>
    DevelopmentRepository(loadString: (_) async => jsonEncode(_snapshot()));

GameState _stateWithFlagship(int masterId) => GameState(
  hasPortData: true,
  ships: {1: OwnedShip(id: 1, masterId: masterId, level: 1)},
  fleets: const [
    Fleet(id: 1, name: '第一舰队', shipIds: [1]),
  ],
  masterShips: {
    masterId: MasterShip(id: masterId, name: '旗舰$masterId', shipTypeId: 2),
  },
  masterSlotItems: const {
    7: MasterSlotItem(id: 7, name: '测试主炮', type: [0, 0, 1]),
    8: MasterSlotItem(id: 8, name: '测试雷达', type: [0, 0, 12]),
    9: MasterSlotItem(id: 9, name: '测试爆雷', type: [0, 0, 15]),
  },
  masterSlotItemTypes: const {1: '小口径主炮'},
);

Map<String, Object?> _snapshot() => {
  'schema_version': 1,
  'generated_at': '2026-09-01T00:00:00.000Z',
  'source': {
    'repository': 'https://example.invalid',
    'commit': 'abc',
    'hashes': {'pool': 'hash'},
  },
  'summary': {
    'pool_count': 4,
    'selectable_pool_count': 4,
    'equipment_count': 3,
    'negative_pool_count': 0,
    'minimum_resource_pool_count': 0,
  },
  'equipment': [
    {
      'id': 7,
      'name': '主炮',
      'names': {'zh': '测试主炮', 'zh_Hant': '測試主砲', 'ja': 'テスト主砲'},
      'type_id': 1,
      'minimum_resources': [10, 10, 10, 10],
    },
    {
      'id': 8,
      'name': '雷达',
      'type_id': 12,
      'minimum_resources': [10, 10, 10, 10],
    },
    {
      'id': 9,
      'name': '爆雷',
      'type_id': 15,
      'minimum_resources': [10, 10, 10, 10],
    },
  ],
  'pools': [
    _pool('carrier-akagi#1', 'carrier-akagi', 1, [101], {'7': 2, '8': 1}),
    _pool('torpedo-sendai#2', 'torpedo-sendai', 2, [202], {'7': 2, '8': 1}),
    _pool('gunnery-other#3', 'gunnery-other', 3, [101, 202], {'7': 2}),
    _pool('depth-charge#1', 'depth-charge', 1, [303], {'9': 2}),
  ],
  'secretaries': [
    {'ship_id': 101, 'pool_key': 'carrier-akagi#1'},
    {'ship_id': 202, 'pool_key': 'torpedo-sendai#2'},
  ],
};

Map<String, Object?> _pool(
  String key,
  String name,
  int id,
  List<int> ships,
  Map<String, num> rates,
) => {
  'pool_key': key,
  'name': name,
  'labels': {'zh': name, 'zh_Hant': name, 'ja': name},
  'descriptions': {'zh': '测试秘书舰', 'zh_Hant': '測試秘書艦', 'ja': 'テスト秘書艦'},
  'pool_id': id,
  'ship_ids': ships,
  'drop_rates': rates,
  'criteria': {
    'ship_types': <Object?>[],
    'class_types': <Object?>[],
    'ship_names': <Object?>[],
    'ship_ids': <Object?>[],
    'excluded_ship_ids': <Object?>[],
  },
};
