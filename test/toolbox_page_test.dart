import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/external_fleet_tool_launcher.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/fleet_export_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/toolbox_page.dart';
import 'package:yahagi_kancolle_browser/src/widgets/top_notice.dart';

void main() {
  testWidgets('a pending ship refresh disables export until its stats arrive', (
    tester,
  ) async {
    const ready = GameState(
      memberId: 1,
      hasPortData: true,
      hasEquipmentInventory: true,
    );
    await tester.pumpWidget(_testApp(const FleetExportPage(state: ready)));
    await tester.pumpWidget(
      _testApp(
        FleetExportPage(state: ready.copyWith(pendingExportShipIds: {7})),
      ),
    );
    expect(find.text('装备数据等待更新'), findsOneWidget);
    for (final key in [
      'fleet-export-noro6',
      'fleet-export-noro6-mirror',
      'fleet-export-jervis',
      'copy-fleet-export',
    ]) {
      expect(
        tester.widget<FilledButton>(find.byKey(Key(key))).onPressed,
        isNull,
      );
    }
    expect(find.textContaining('"version":4'), findsNothing);
    await tester.pumpWidget(_testApp(const FleetExportPage(state: ready)));
    expect(find.textContaining('"version":4'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('fleet-export-noro6')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'port waits for full equipment inventory and clears stale preview',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          const FleetExportPage(
            state: GameState(
              memberId: 1,
              hasPortData: true,
              hasEquipmentInventory: true,
            ),
          ),
        ),
      );
      expect(find.textContaining('"version":4'), findsOneWidget);
      await tester.pumpWidget(
        _testApp(
          const FleetExportPage(
            state: GameState(memberId: 2, hasPortData: true),
          ),
        ),
      );
      expect(find.text('装备数据等待更新'), findsOneWidget);
      expect(find.textContaining('"version":4'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('fleet-export-noro6')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('copy-fleet-export')))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(
        _testApp(
          const FleetExportPage(
            state: GameState(
              memberId: 2,
              hasPortData: true,
              hasEquipmentInventory: true,
            ),
          ),
        ),
      );
      expect(find.textContaining('"version":4'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('fleet-export-noro6')))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets('ready port data shows an initial DeckBuilder export', (
    tester,
  ) async {
    const state = GameState(
      admiralLevel: 120,
      hasPortData: true,
      hasEquipmentInventory: true,
      ships: <int, OwnedShip>{
        101: OwnedShip(id: 101, masterId: 187, level: 70),
      },
      fleets: <Fleet>[
        Fleet(id: 1, name: 'First', shipIds: <int>[101]),
      ],
    );

    await tester.pumpWidget(_testApp(const ToolboxPage(state: state)));

    expect(find.byType(FleetExportPage), findsOneWidget);
    expect(find.text('导出至 noro6'), findsOneWidget);
    expect(find.text('导出至 noro6（国内镜像）'), findsOneWidget);
    expect(find.text('导出至 Jervis'), findsOneWidget);
    expect(
      _filledButtonKeysInNearestColumn(
        tester,
        find.byKey(const Key('fleet-export-noro6-mirror')),
      ).take(3),
      <Key>[
        const Key('fleet-export-noro6'),
        const Key('fleet-export-noro6-mirror'),
        const Key('fleet-export-jervis'),
      ],
    );
    expect(find.text('仅导出活动海域陆航'), findsOneWidget);
    expect(
      find.text('DeckBuilder 每次最多支持 3 队；关闭筛选时按已捕获顺序导出前 3 队。'),
      findsOneWidget,
    );
    expect(find.textContaining('"version":4'), findsOneWidget);
    expect(find.text('4 支'), findsNothing);
    expect(find.text('18 艘'), findsNothing);
    expect(find.text('3 队'), findsNothing);
  });

  testWidgets('waiting for port data disables external export', (tester) async {
    await tester.pumpWidget(_testApp(const ToolboxPage(state: GameState())));

    expect(find.text('等待母港数据'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('fleet-export-noro6')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('fleet-export-noro6-mirror')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('fleet-export-jervis')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'refresh uses the latest state without overwriting it beforehand',
    (tester) async {
      const oldState = GameState(
        admiralLevel: 10,
        hasPortData: true,
        hasEquipmentInventory: true,
      );
      const newState = GameState(
        admiralLevel: 99,
        hasPortData: true,
        hasEquipmentInventory: true,
      );

      await tester.pumpWidget(_testApp(const FleetExportPage(state: oldState)));
      expect(find.textContaining('"hqlv":10'), findsOneWidget);

      await tester.pumpWidget(_testApp(const FleetExportPage(state: newState)));
      expect(find.textContaining('"hqlv":10'), findsOneWidget);

      await tester.tap(find.byKey(const Key('refresh-fleet-export')));
      await tester.pump();
      expect(find.textContaining('"hqlv":99'), findsOneWidget);
    },
  );

  testWidgets('copy regenerates the latest fleet without a manual refresh', (
    tester,
  ) async {
    String? copied;
    Widget page(int level) => _testApp(
      FleetExportPage(
        state: GameState(
          admiralLevel: level,
          hasPortData: true,
          hasEquipmentInventory: true,
        ),
        copyText: (text) async => copied = text,
      ),
    );
    await tester.pumpWidget(page(10));
    await tester.pumpWidget(page(99));
    await tester.tap(find.byKey(const Key('copy-fleet-export')));
    await tester.pump();
    expect(jsonDecode(copied!)['hqlv'], 99);
    expect(find.textContaining('"hqlv":99'), findsOneWidget);
  });

  testWidgets(
    'switching accounts immediately replaces the visible export preview',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          const FleetExportPage(
            state: GameState(
              memberId: 1,
              admiralLevel: 10,
              hasPortData: true,
              hasEquipmentInventory: true,
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        _testApp(
          const FleetExportPage(
            state: GameState(
              memberId: 2,
              admiralLevel: 99,
              hasPortData: true,
              hasEquipmentInventory: true,
            ),
          ),
        ),
      );
      expect(find.textContaining('"hqlv":10'), findsNothing);
      expect(find.textContaining('"hqlv":99'), findsOneWidget);
    },
  );

  testWidgets('first port data replaces the waiting state automatically', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(const FleetExportPage(state: GameState())),
    );
    expect(find.text('等待母港数据'), findsOneWidget);

    await tester.pumpWidget(
      _testApp(
        const FleetExportPage(
          state: GameState(
            admiralLevel: 77,
            hasPortData: true,
            hasEquipmentInventory: true,
          ),
        ),
      ),
    );

    expect(find.textContaining('"hqlv":77'), findsOneWidget);
  });

  testWidgets('copy writes the current text and reports success', (
    tester,
  ) async {
    String? copied;
    await tester.pumpWidget(
      _testApp(
        FleetExportPage(
          state: const GameState(
            admiralLevel: 80,
            hasPortData: true,
            hasEquipmentInventory: true,
          ),
          copyText: (text) async => copied = text,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('copy-fleet-export')));
    await tester.pump();

    expect(copied, contains('"hqlv":80'));
    expect(find.text('舰队导出文本已复制。'), findsOneWidget);
  });

  testWidgets('copy failure is reported without clearing the text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        FleetExportPage(
          state: const GameState(
            admiralLevel: 81,
            hasPortData: true,
            hasEquipmentInventory: true,
          ),
          copyText: (_) => Future<void>.error(StateError('clipboard failed')),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('copy-fleet-export')));
    await tester.pump();

    expect(find.text('复制失败，请稍后重试。'), findsOneWidget);
    expect(find.textContaining('"hqlv":81'), findsOneWidget);
  });

  testWidgets('noro6 launch imports fleet and complete owned inventory', (
    tester,
  ) async {
    Uri? received;
    const state = GameState(
      admiralLevel: 88,
      hasPortData: true,
      hasEquipmentInventory: true,
      ships: <int, OwnedShip>{
        101: OwnedShip(
          id: 101,
          masterId: 187,
          level: 70,
          experience: 123456,
          nextExperience: 2345,
          extraSlotId: 503,
        ),
        202: OwnedShip(id: 202, masterId: 200, level: 45),
        303: OwnedShip(id: 303, masterId: 201, level: 30, extraSlotId: 0),
      },
      slotItems: <int, OwnedSlotItem>{
        501: OwnedSlotItem(instanceId: 501, masterSlotItemId: 86, level: 7),
        502: OwnedSlotItem(instanceId: 502, masterSlotItemId: 42),
      },
      fleets: <Fleet>[
        Fleet(id: 1, name: 'First', shipIds: <int>[101]),
      ],
    );
    await tester.pumpWidget(
      _testApp(
        FleetExportPage(
          state: state,
          launcher: ExternalFleetToolLauncher(
            launch: (uri) async {
              received = uri;
              return false;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('fleet-export-noro6')));
    await tester.pump();

    expect(received?.host, 'noro6.github.io');
    expect(received.toString(), contains('#import:'));
    expect(received?.queryParameters, isEmpty);
    final encodedPayload = received.toString().split('#import:').last;
    final payload = jsonDecode(Uri.decodeComponent(encodedPayload)) as Map;
    expect(payload['predeck'], isA<Map>());
    expect((payload['predeck'] as Map)['hqlv'], 88);
    expect(payload['ships'], <Object?>[
      <String, Object?>{
        'id': 101,
        'ship_id': 187,
        'lv': 70,
        'exp': <int>[123456, 2345, 0],
        'ex': 1,
        'area': 0,
      },
      <String, Object?>{
        'id': 202,
        'ship_id': 200,
        'lv': 45,
        'exp': <int>[0, 0, 0],
        'ex': 1,
        'area': 0,
      },
      <String, Object?>{
        'id': 303,
        'ship_id': 201,
        'lv': 30,
        'exp': <int>[0, 0, 0],
        'ex': 0,
        'area': 0,
      },
    ]);
    expect(payload['items'], <Object?>[
      <String, Object?>{'id': 86, 'lv': 7},
      <String, Object?>{'id': 42, 'lv': 0},
    ]);
    expect(find.textContaining('"hqlv":88'), findsOneWidget);
    expect(find.text('无法打开外部舰队工具，请检查是否已安装浏览器。'), findsOneWidget);
  });

  testWidgets(
    'noro6 mirror launch imports fleet and complete owned inventory',
    (tester) async {
      Uri? received;
      const state = GameState(
        admiralLevel: 88,
        hasPortData: true,
        hasEquipmentInventory: true,
        ships: <int, OwnedShip>{
          101: OwnedShip(
            id: 101,
            masterId: 187,
            level: 70,
            experience: 123456,
            nextExperience: 2345,
            extraSlotId: 503,
          ),
          202: OwnedShip(id: 202, masterId: 200, level: 45),
          303: OwnedShip(id: 303, masterId: 201, level: 30, extraSlotId: 0),
        },
        slotItems: <int, OwnedSlotItem>{
          501: OwnedSlotItem(instanceId: 501, masterSlotItemId: 86, level: 7),
          502: OwnedSlotItem(instanceId: 502, masterSlotItemId: 42),
        },
        fleets: <Fleet>[
          Fleet(id: 1, name: 'First', shipIds: <int>[101]),
        ],
      );
      await tester.pumpWidget(
        _testApp(
          FleetExportPage(
            state: state,
            launcher: ExternalFleetToolLauncher(
              launch: (uri) async {
                received = uri;
                return false;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('fleet-export-noro6-mirror')));
      await tester.pump();

      expect(received?.scheme, 'https');
      expect(received?.host, 'noro6.kcwiki.cn');
      expect(received?.path, '/');
      expect(received?.queryParameters, isEmpty);
      expect(received.toString(), contains('#import:'));
      final encodedPayload = received.toString().split('#import:').last;
      final payload = jsonDecode(Uri.decodeComponent(encodedPayload)) as Map;
      final displayedDeckBuilder = jsonDecode(
        tester
            .widget<SelectableText>(find.byKey(const Key('fleet-export-text')))
            .data!,
      );
      expect(payload['predeck'], displayedDeckBuilder);
      expect(payload['ships'], <Object?>[
        <String, Object?>{
          'id': 101,
          'ship_id': 187,
          'lv': 70,
          'exp': <int>[123456, 2345, 0],
          'ex': 1,
          'area': 0,
        },
        <String, Object?>{
          'id': 202,
          'ship_id': 200,
          'lv': 45,
          'exp': <int>[0, 0, 0],
          'ex': 1,
          'area': 0,
        },
        <String, Object?>{
          'id': 303,
          'ship_id': 201,
          'lv': 30,
          'exp': <int>[0, 0, 0],
          'ex': 0,
          'area': 0,
        },
      ]);
      expect(payload['items'], <Object?>[
        <String, Object?>{'id': 86, 'lv': 7},
        <String, Object?>{'id': 42, 'lv': 0},
      ]);
      expect(find.textContaining('"hqlv":88'), findsOneWidget);
      expect(find.text('无法打开外部舰队工具，请检查是否已安装浏览器。'), findsOneWidget);
    },
  );

  testWidgets('uses two columns in landscape and one column when narrow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpWidget(
      _testApp(
        const FleetExportPage(
          state: GameState(
            admiralLevel: 120,
            hasPortData: true,
            hasEquipmentInventory: true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('fleet-export-two-column')), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fleet-export-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: TopNoticeHost(child: Scaffold(body: child)),
);

List<Key> _filledButtonKeysInNearestColumn(
  WidgetTester tester,
  Finder descendant,
) {
  Element? columnElement;
  tester.element(descendant).visitAncestorElements((ancestor) {
    if (ancestor.widget is! Column) return true;
    columnElement = ancestor;
    return false;
  });

  final keys = <Key>[];
  columnElement!.visitChildren((directChild) {
    void collectFilledButtonKeys(Element element) {
      if (element.widget case FilledButton(key: final Key key)) {
        keys.add(key);
      }
      element.visitChildren(collectFilledButtonKeys);
    }

    collectFilledButtonKeys(directChild);
  });
  return keys;
}
