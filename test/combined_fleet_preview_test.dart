import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  setUpAll(() async {
    final fontBytes = await File(r'C:\Windows\Fonts\msyh.ttc').readAsBytes();
    await (FontLoader(
      'PreviewCjk',
    )..addFont(Future<ByteData>.value(ByteData.sublistView(fontBytes)))).load();
    final iconBytes = await File(
      r'G:\DevTools\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    ).readAsBytes();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future<ByteData>.value(ByteData.sublistView(iconBytes)))).load();
  });

  testWidgets('renders the combined fleet prophet preview', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 880);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final state = _combinedFleetState();
    final controller = BattleController(gameState: () => state);
    addTearDown(controller.dispose);
    controller
      ..accept(
        kcsapiEvent(
          '/kcsapi/api_req_map/start',
          <String, Object?>{
            'api_maparea_id': 46,
            'api_mapinfo_no': 1,
            'api_no': 3,
            'api_bosscell_no': 5,
            'api_event_id': 4,
            'api_event_kind': 1,
          },
          sequence: 501,
          requestParams: const <String, Object?>{'api_deck_id': '1'},
        ),
      )
      ..accept(
        kcsapiEvent(
          '/kcsapi/api_req_combined_battle/each_battle',
          <String, Object?>{
            'api_deck_id': 1,
            'api_formation': <int>[4, 3, 1],
            'api_f_nowhps': <int>[-1, 96, 82, 58, 44, 61, 36],
            'api_f_maxhps': <int>[-1, 96, 82, 58, 44, 61, 36],
            'api_f_nowhps_combined': <int>[-1, 48, 43, 37, 32, 31, 29],
            'api_f_maxhps_combined': <int>[-1, 48, 43, 37, 32, 31, 29],
            'api_ship_ke': <int>[-1, 301, 302, 303, 304, 305, 306],
            'api_e_nowhps': <int>[-1, 210, 130, 90, 70, 55, 45],
            'api_e_maxhps': <int>[-1, 210, 130, 90, 70, 55, 45],
            'api_ship_ke_combined': <int>[-1, 307, 308, 309, 310, 311, 312],
            'api_e_nowhps_combined': <int>[-1, 66, 52, 44, 40, 36, 32],
            'api_e_maxhps_combined': <int>[-1, 66, 52, 44, 40, 36, 32],
            'api_hougeki1': <String, Object?>{
              'api_at_eflag': <int>[0, 0, 0, 0, 1, 1],
              'api_at_list': <int>[0, 2, 6, 8, 0, 7],
              'api_df_list': <Object?>[
                <int>[0],
                <int>[2],
                <int>[7],
                <int>[9],
                <int>[1],
                <int>[6],
              ],
              'api_damage': <Object?>[
                <num>[82],
                <num>[49],
                <num>[31],
                <num>[44],
                <num>[27],
                <num>[19],
              ],
            },
          },
          sequence: 502,
        ),
      );
    await controller.idle;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'PreviewCjk',
          scaffoldBackgroundColor: const Color(0xff081521),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xffd4a85f),
            brightness: Brightness.dark,
          ),
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 1120,
                child: LiveBattleCard(
                  controller: controller,
                  collapsed: false,
                  onToggleCollapse: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('live-battle-card')),
      matchesGoldenFile(
        '../docs/previews/combined-fleet-prophet-sidebar-preview.png',
      ),
    );
  });
}

GameState _combinedFleetState() {
  const friendNames = <String>[
    '大和改二',
    '武藏改二',
    '伊势改二',
    '日向改二',
    'Atlanta改',
    '秋月改',
    '矢矧改二乙',
    '最上改二特',
    '雪风改二',
    '时雨改三',
    '北上改二',
    '大井改二',
  ];
  const enemyNames = <String>[
    '深海旗舰',
    '战舰栖姬',
    '空母栖姬',
    '重巡ネ级',
    '轻巡ツ级',
    '驱逐ナ级',
    '护卫旗舰',
    '战舰ル级',
    '重巡リ级',
    '轻巡ヘ级',
    '驱逐ロ级',
    '驱逐イ级',
  ];
  final masters = <int, MasterShip>{};
  final ships = <int, OwnedShip>{};
  for (var index = 0; index < friendNames.length; index++) {
    final masterId = 101 + index;
    final ownedId = 1001 + index;
    masters[masterId] = MasterShip(
      id: masterId,
      name: friendNames[index],
      shipTypeId: index < 2 ? 9 : 2,
      speed: 10,
    );
    ships[ownedId] = OwnedShip(
      id: ownedId,
      masterId: masterId,
      level: 99 - index,
      currentHp: index < 6
          ? const <int>[96, 82, 58, 44, 61, 36][index]
          : const <int>[48, 43, 37, 32, 31, 29][index - 6],
      maxHp: index < 6
          ? const <int>[96, 82, 58, 44, 61, 36][index]
          : const <int>[48, 43, 37, 32, 31, 29][index - 6],
      condition: const <int>[
        62,
        58,
        53,
        49,
        71,
        65,
        57,
        49,
        64,
        52,
        48,
        45,
      ][index],
    );
  }
  for (var index = 0; index < enemyNames.length; index++) {
    final masterId = 301 + index;
    masters[masterId] = MasterShip(
      id: masterId,
      name: enemyNames[index],
      shipTypeId: 9,
    );
  }
  return GameState(
    masterShips: masters,
    ships: ships,
    fleets: <Fleet>[
      Fleet(
        id: 1,
        name: '第一舰队',
        shipIds: <int>[for (var id = 1001; id <= 1006; id++) id],
      ),
      Fleet(
        id: 2,
        name: '第二舰队',
        shipIds: <int>[for (var id = 1007; id <= 1012; id++) id],
      ),
    ],
    combinedFleetType: CombinedFleetType.surfaceTaskForce,
    hasMasterData: true,
    hasPortData: true,
  );
}
