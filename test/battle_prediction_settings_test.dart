import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/src/settings/battle_prediction_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loading settings removes the legacy prediction method', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.predictionMethod': 'yahagi',
    });
    final store = SharedPreferencesBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('battle.predictionMethod'), isFalse);
  });

  test('missing enemy portrait setting defaults to enabled', () async {
    final store = SharedPreferencesBattlePredictionSettingsStore();

    expect(await store.loadEnemyPortraitsEnabled(), isTrue);
  });

  for (final stored in <Object?>[null, 'invalid', true]) {
    test('fleet information sync defaults to immediate for $stored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'battle.fleetInformationSyncMode': ?stored,
      });
      final controller = await BattlePredictionSettingsController.load(
        SharedPreferencesBattlePredictionSettingsStore(),
      );
      addTearDown(controller.dispose);

      expect(
        controller.fleetInformationSyncMode,
        FleetInformationSyncMode.immediate,
      );
    });
  }

  test('fleet information sync saves overlapping choices in order', () async {
    final store = SharedPreferencesBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);
    final modes = <FleetInformationSyncMode>[];
    controller.addListener(
      () => modes.add(controller.fleetInformationSyncMode),
    );

    await Future.wait([
      controller.setFleetInformationSyncMode(
        FleetInformationSyncMode.settlement,
      ),
      controller.setFleetInformationSyncMode(
        FleetInformationSyncMode.immediate,
      ),
      controller.setFleetInformationSyncMode(
        FleetInformationSyncMode.immediate,
      ),
    ]);

    expect(modes, [
      FleetInformationSyncMode.settlement,
      FleetInformationSyncMode.immediate,
    ]);
    expect(
      await store.loadFleetInformationSyncMode(),
      FleetInformationSyncMode.immediate,
    );
  });

  for (final stored in <String?>[null, 'unknown-position']) {
    test('enemy preview position defaults above for $stored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'battle.enemyPreviewPosition': ?stored,
      });
      final controller = await BattlePredictionSettingsController.load(
        SharedPreferencesBattlePredictionSettingsStore(),
      );
      addTearDown(controller.dispose);

      expect(controller.enemyPreviewPosition, EnemyPreviewPosition.above);
    });
  }

  test(
    'controller persists preview position and notifies only changes',
    () async {
      final store = MemoryBattlePredictionSettingsStore();
      final controller = await BattlePredictionSettingsController.load(store);
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setEnemyPreviewPosition(EnemyPreviewPosition.below);
      expect(controller.enemyPreviewPosition, EnemyPreviewPosition.below);
      expect(
        await store.loadEnemyPreviewPosition(),
        EnemyPreviewPosition.below,
      );
      expect(notifications, 1);

      await controller.setEnemyPreviewPosition(EnemyPreviewPosition.below);
      expect(notifications, 1);
      await controller.setEnemyPreviewPosition(EnemyPreviewPosition.above);
      expect(
        await store.loadEnemyPreviewPosition(),
        EnemyPreviewPosition.above,
      );
      expect(notifications, 2);
    },
  );

  test('enemy portrait setting loads a saved disabled value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.enemyPreviewPortraitsEnabled': false,
    });
    final store = SharedPreferencesBattlePredictionSettingsStore();

    expect(await store.loadEnemyPortraitsEnabled(), isFalse);
  });

  test('missing last formation hint setting defaults to enabled', () async {
    final store = SharedPreferencesBattlePredictionSettingsStore();

    expect(await store.loadLastFormationHintEnabled(), isTrue);
  });

  test('last formation hint setting loads a saved disabled value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.lastFormationHintEnabled': false,
    });
    final store = SharedPreferencesBattlePredictionSettingsStore();

    expect(await store.loadLastFormationHintEnabled(), isFalse);
  });

  test('controller persists enemy portrait visibility', () async {
    final store = MemoryBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    expect(controller.enemyPortraitsEnabled, isTrue);

    await controller.setEnemyPortraitsEnabled(false);
    expect(controller.enemyPortraitsEnabled, isFalse);
    expect(await store.loadEnemyPortraitsEnabled(), isFalse);

    await controller.setEnemyPortraitsEnabled(true);
    expect(controller.enemyPortraitsEnabled, isTrue);
    expect(await store.loadEnemyPortraitsEnabled(), isTrue);
  });

  test('controller persists last formation hint visibility', () async {
    final store = MemoryBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    expect(controller.lastFormationHintEnabled, isTrue);

    await controller.setLastFormationHintEnabled(false);
    expect(controller.lastFormationHintEnabled, isFalse);
    expect(await store.loadLastFormationHintEnabled(), isFalse);

    await controller.setLastFormationHintEnabled(true);
    expect(controller.lastFormationHintEnabled, isTrue);
    expect(await store.loadLastFormationHintEnabled(), isTrue);
  });

  test('legacy cleanup failure does not block display settings', () async {
    final controller = await BattlePredictionSettingsController.load(
      _FailingLegacyCleanupStore(),
    );
    addTearDown(controller.dispose);

    expect(controller.enemyPortraitsEnabled, isFalse);
    expect(controller.lastFormationHintEnabled, isFalse);
  });

  test('missing section order preserves the default arrangement', () async {
    final controller = await BattlePredictionSettingsController.load(
      MemoryBattlePredictionSettingsStore(),
    );
    addTearDown(controller.dispose);

    expect(controller.sectionOrder, defaultBattlePredictionSectionOrder);
  });

  test('legacy below position migrates to map, result, enemy', () async {
    final controller = await BattlePredictionSettingsController.load(
      MemoryBattlePredictionSettingsStore(
        true,
        true,
        EnemyPreviewPosition.below,
      ),
    );
    addTearDown(controller.dispose);

    expect(controller.sectionOrder, <BattlePredictionSection>[
      BattlePredictionSection.sortieMap,
      BattlePredictionSection.predictionResult,
      BattlePredictionSection.enemyPreview,
    ]);
  });

  test('saved section order takes precedence over legacy position', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.enemyPreviewPosition': 'below',
      'battle.sectionOrder': <String>[
        'enemyPreview',
        'sortieMap',
        'predictionResult',
      ],
    });
    final controller = await BattlePredictionSettingsController.load(
      SharedPreferencesBattlePredictionSettingsStore(),
    );
    addTearDown(controller.dispose);

    expect(controller.sectionOrder.first, BattlePredictionSection.enemyPreview);
    await controller.setEnemyPreviewPosition(EnemyPreviewPosition.above);
    expect(controller.sectionOrder.first, BattlePredictionSection.enemyPreview);
  });

  test(
    'partial saved section order drops unknown and duplicate names',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'battle.sectionOrder': <String>[
          'predictionResult',
          'unknown-section',
          'predictionResult',
        ],
      });
      final controller = await BattlePredictionSettingsController.load(
        SharedPreferencesBattlePredictionSettingsStore(),
      );
      addTearDown(controller.dispose);

      expect(controller.sectionOrder, <BattlePredictionSection>[
        BattlePredictionSection.predictionResult,
        BattlePredictionSection.sortieMap,
        BattlePredictionSection.enemyPreview,
      ]);
    },
  );

  for (final corruptValue in <Object>[42, true, 'enemyPreview']) {
    test(
      'corrupt section order $corruptValue preserves legacy fallback',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'battle.enemyPreviewPosition': 'below',
          'battle.sectionOrder': corruptValue,
        });
        final controller = await BattlePredictionSettingsController.load(
          SharedPreferencesBattlePredictionSettingsStore(),
        );
        addTearDown(controller.dispose);

        expect(controller.sectionOrder, <BattlePredictionSection>[
          BattlePredictionSection.sortieMap,
          BattlePredictionSection.predictionResult,
          BattlePredictionSection.enemyPreview,
        ]);
      },
    );
  }

  test('saved section order loads despite a corrupt legacy position', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'battle.enemyPreviewPosition': 42,
      'battle.sectionOrder': <String>[
        'predictionResult',
        'enemyPreview',
        'sortieMap',
      ],
    });
    final controller = await BattlePredictionSettingsController.load(
      SharedPreferencesBattlePredictionSettingsStore(),
    );
    addTearDown(controller.dispose);

    expect(
      controller.sectionOrder.first,
      BattlePredictionSection.predictionResult,
    );
  });

  test(
    'unavailable section preference does not block existing settings',
    () async {
      final controller = await BattlePredictionSettingsController.load(
        _UnavailableSectionOrderStore(),
      );
      addTearDown(controller.dispose);

      expect(controller.enemyPortraitsEnabled, isFalse);
      expect(controller.sectionOrder, defaultBattlePredictionSectionOrder);
    },
  );

  test('section order remains immutable before and after saving', () async {
    final store = MemoryBattlePredictionSettingsStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    expect(
      () => controller.sectionOrder.add(BattlePredictionSection.sortieMap),
      throwsUnsupportedError,
    );
    final requestedOrder = <BattlePredictionSection>[
      BattlePredictionSection.predictionResult,
      BattlePredictionSection.enemyPreview,
      BattlePredictionSection.sortieMap,
    ];
    await controller.setSectionOrder(requestedOrder);
    requestedOrder.clear();
    expect(
      controller.sectionOrder.first,
      BattlePredictionSection.predictionResult,
    );
    expect(() => controller.sectionOrder.removeLast(), throwsUnsupportedError);
    final savedOrder = (await store.loadSectionOrder())!;
    expect(() => savedOrder.clear(), throwsUnsupportedError);
  });

  test(
    'controller persists normalized order and only notifies a change',
    () async {
      final controller = await BattlePredictionSettingsController.load(
        SharedPreferencesBattlePredictionSettingsStore(),
      );
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.setSectionOrder(<BattlePredictionSection>[
        BattlePredictionSection.enemyPreview,
        BattlePredictionSection.enemyPreview,
      ]);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList('battle.sectionOrder'), <String>[
        'enemyPreview',
        'sortieMap',
        'predictionResult',
      ]);
      expect(notifications, 1);
      await controller.setSectionOrder(controller.sectionOrder);
      expect(notifications, 1);
    },
  );

  test('legacy fallback stays live until an explicit order is saved', () async {
    final controller = await BattlePredictionSettingsController.load(
      MemoryBattlePredictionSettingsStore(),
    );
    addTearDown(controller.dispose);

    await controller.setEnemyPreviewPosition(EnemyPreviewPosition.below);
    expect(controller.sectionOrder.last, BattlePredictionSection.enemyPreview);
    await controller.setSectionOrder(controller.sectionOrder);
    await controller.setEnemyPreviewPosition(EnemyPreviewPosition.above);
    expect(controller.sectionOrder.last, BattlePredictionSection.enemyPreview);
  });

  test(
    'move respects boundaries and reset persists the default order',
    () async {
      final store = MemoryBattlePredictionSettingsStore();
      final controller = await BattlePredictionSettingsController.load(store);
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.moveSection(BattlePredictionSection.sortieMap, -1);
      await controller.moveSection(BattlePredictionSection.predictionResult, 1);
      expect(notifications, 0);
      expect(await store.loadSectionOrder(), isNull);

      await controller.moveSection(BattlePredictionSection.enemyPreview, -1);
      expect(controller.sectionOrder, <BattlePredictionSection>[
        BattlePredictionSection.enemyPreview,
        BattlePredictionSection.sortieMap,
        BattlePredictionSection.predictionResult,
      ]);
      expect(notifications, 1);
      await controller.resetSectionOrder();
      expect(controller.sectionOrder, defaultBattlePredictionSectionOrder);
      expect(
        await store.loadSectionOrder(),
        defaultBattlePredictionSectionOrder,
      );
      expect(notifications, 2);
    },
  );

  test(
    'failed section save retains the previous order without notification',
    () async {
      final controller = await BattlePredictionSettingsController.load(
        _FailingSectionOrderStore(),
      );
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await expectLater(
        controller.moveSection(BattlePredictionSection.enemyPreview, -1),
        throwsStateError,
      );
      expect(controller.sectionOrder, defaultBattlePredictionSectionOrder);
      expect(notifications, 0);
    },
  );

  test('rapid moves serialize against the last saved order', () async {
    final store = _DelayedSectionOrderStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    final firstMove = controller.moveSection(
      BattlePredictionSection.predictionResult,
      -1,
    );
    final secondMove = controller.moveSection(
      BattlePredictionSection.predictionResult,
      -1,
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.saves, hasLength(1));
    expect(controller.sectionOrder, defaultBattlePredictionSectionOrder);

    store.pendingSaves[0].complete();
    await firstMove;
    await Future<void>.delayed(Duration.zero);
    expect(store.saves, hasLength(2));
    store.pendingSaves[1].complete();
    await secondMove;
    expect(controller.sectionOrder, <BattlePredictionSection>[
      BattlePredictionSection.predictionResult,
      BattlePredictionSection.sortieMap,
      BattlePredictionSection.enemyPreview,
    ]);
    expect(await store.loadSectionOrder(), controller.sectionOrder);
  });

  test('a failed queued save does not block a later move', () async {
    final store = _DelayedSectionOrderStore();
    final controller = await BattlePredictionSettingsController.load(store);
    addTearDown(controller.dispose);

    final firstMove = controller.moveSection(
      BattlePredictionSection.predictionResult,
      -1,
    );
    final failedMove = expectLater(firstMove, throwsStateError);
    final secondMove = controller.moveSection(
      BattlePredictionSection.enemyPreview,
      -1,
    );
    await Future<void>.delayed(Duration.zero);
    store.pendingSaves[0].completeError(StateError('save failed'));
    await failedMove;
    await Future<void>.delayed(Duration.zero);
    store.pendingSaves[1].complete();
    await secondMove;

    expect(controller.sectionOrder.first, BattlePredictionSection.enemyPreview);
    expect(await store.loadSectionOrder(), controller.sectionOrder);
  });
}

final class _FailingLegacyCleanupStore
    implements BattlePredictionSettingsStore {
  @override
  Future<void> initialize() async {
    throw StateError('legacy cleanup failed');
  }

  @override
  Future<bool> loadEnemyPortraitsEnabled() async => false;

  @override
  Future<bool> loadLastFormationHintEnabled() async => false;

  @override
  Future<void> saveEnemyPortraitsEnabled(bool enabled) async {}

  @override
  Future<void> saveLastFormationHintEnabled(bool enabled) async {}

  @override
  Future<EnemyPreviewPosition> loadEnemyPreviewPosition() async =>
      EnemyPreviewPosition.above;

  @override
  Future<void> saveEnemyPreviewPosition(EnemyPreviewPosition position) async {}

  @override
  Future<FleetInformationSyncMode> loadFleetInformationSyncMode() async =>
      FleetInformationSyncMode.immediate;

  @override
  Future<void> saveFleetInformationSyncMode(
    FleetInformationSyncMode mode,
  ) async {}

  @override
  Future<List<BattlePredictionSection>?> loadSectionOrder() async => null;

  @override
  Future<void> saveSectionOrder(List<BattlePredictionSection> order) async {}
}

class _SectionOrderStore implements BattlePredictionSettingsStore {
  List<BattlePredictionSection>? order;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> loadEnemyPortraitsEnabled() async => false;

  @override
  Future<bool> loadLastFormationHintEnabled() async => true;

  @override
  Future<EnemyPreviewPosition> loadEnemyPreviewPosition() async =>
      EnemyPreviewPosition.above;

  @override
  Future<void> saveEnemyPortraitsEnabled(bool enabled) async {}

  @override
  Future<void> saveLastFormationHintEnabled(bool enabled) async {}

  @override
  Future<void> saveEnemyPreviewPosition(EnemyPreviewPosition position) async {}

  @override
  Future<FleetInformationSyncMode> loadFleetInformationSyncMode() async =>
      FleetInformationSyncMode.immediate;

  @override
  Future<void> saveFleetInformationSyncMode(
    FleetInformationSyncMode mode,
  ) async {}

  @override
  Future<List<BattlePredictionSection>?> loadSectionOrder() async => order;

  @override
  Future<void> saveSectionOrder(List<BattlePredictionSection> order) async {
    this.order = List<BattlePredictionSection>.of(order);
  }
}

final class _UnavailableSectionOrderStore extends _SectionOrderStore {
  @override
  Future<List<BattlePredictionSection>?> loadSectionOrder() async {
    throw StateError('section preference unavailable');
  }
}

final class _FailingSectionOrderStore extends _SectionOrderStore {
  @override
  Future<void> saveSectionOrder(List<BattlePredictionSection> order) async {
    throw StateError('section order was not saved');
  }
}

final class _DelayedSectionOrderStore extends _SectionOrderStore {
  final saves = <List<BattlePredictionSection>>[];
  final pendingSaves = <Completer<void>>[];

  @override
  Future<void> saveSectionOrder(List<BattlePredictionSection> order) async {
    saves.add(List<BattlePredictionSection>.of(order));
    final pendingSave = Completer<void>();
    pendingSaves.add(pendingSave);
    await pendingSave.future;
    await super.saveSectionOrder(order);
  }
}
