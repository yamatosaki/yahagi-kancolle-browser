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
    final separator = Platform.pathSeparator;
    final fontBytes = await File(
      'assets${separator}fonts${separator}HarmonyOS_Sans_SC.ttf',
    ).readAsBytes();
    await (FontLoader(
      'PreviewCjk',
    )..addFont(Future<ByteData>.value(ByteData.sublistView(fontBytes)))).load();
    final iconBytes = await _materialIconsFont().readAsBytes();
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

    expect(
      tester.widget<Text>(find.text('水上打击部队')).style?.color,
      const Color(0xff70c7bc),
    );

    expect(find.byKey(const Key('live-battle-card')), findsOneWidget);
    expect(find.textContaining('我方主力'), findsOneWidget);
    expect(find.textContaining('我方随伴'), findsOneWidget);
    expect(find.textContaining('敌方主力'), findsOneWidget);
    expect(find.textContaining('敌方护卫'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact combined battle shows four bar columns', (tester) async {
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
            'api_e_nowhps': <int>[-1, 60, 60, 60, 60, 60, 60],
            'api_e_maxhps': <int>[-1, 60, 60, 60, 60, 60, 60],
            'api_e_nowhps_combined': <int>[-1, 40, 40, 40, 40, 40, 40],
            'api_e_maxhps_combined': <int>[-1, 40, 40, 40, 40, 40, 40],
            'api_ship_ke': <int>[-1, 301, 302, 303, 304, 305, 306],
            'api_ship_ke_combined': <int>[-1, 307, 308, 309, 310, 311, 312],
          },
          sequence: 502,
        ),
      )
      ..accept(
        kcsapiEvent(
          '/kcsapi/api_req_combined_battle/battleresult',
          <String, Object?>{
            'api_win_rank': 'S',
            'api_mvp': 1,
            'api_mvp_combined': 1,
          },
          sequence: 503,
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
        ),
        home: Scaffold(
          body: Center(
            child: LiveBattleCard(
              controller: controller,
              collapsed: false,
              onToggleCollapse: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('battle-mode-compact')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('compact-fleet-grid')), findsOneWidget);
    expect(
      find.byKey(const Key('compact-fleet-col-friend-main')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('compact-fleet-col-friend-escort')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('compact-fleet-col-enemy-main')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('compact-fleet-col-enemy-escort')),
      findsOneWidget,
    );
    final columnKeys = <Key>[
      const Key('compact-fleet-col-friend-main'),
      const Key('compact-fleet-col-friend-escort'),
      const Key('compact-fleet-col-enemy-escort'),
      const Key('compact-fleet-col-enemy-main'),
    ];
    final columnLefts = <double>[
      for (final key in columnKeys) tester.getTopLeft(find.byKey(key)).dx,
    ];
    expect(columnLefts, orderedEquals(columnLefts.toList()..sort()));
    expect(find.text('我方舰队（梯形阵）'), findsOneWidget);
    expect(find.text('敌方舰队（轮形阵）'), findsOneWidget);
    expect(find.text('我方主力\n（梯形阵）'), findsNothing);
    expect(find.text('我方随伴'), findsNothing);
    expect(find.text('敌方护卫'), findsNothing);
    expect(find.text('敌方主力\n（轮形阵）'), findsNothing);
    expect(
      tester.widget<Text>(find.text('我方舰队（梯形阵）')).style?.color,
      const Color(0xff70c7bc),
    );
    expect(
      tester.widget<Text>(find.text('敌方舰队（轮形阵）')).style?.color,
      const Color(0xffff8c78),
    );
    final friendHeading = find.byKey(
      const Key('compact-fleet-side-title-friend'),
    );
    final enemyHeading = find.byKey(
      const Key('compact-fleet-side-title-enemy'),
    );
    final friendLeft = tester
        .getTopLeft(find.byKey(const Key('compact-fleet-col-friend-main')))
        .dx;
    final friendRight = tester
        .getTopRight(find.byKey(const Key('compact-fleet-col-friend-escort')))
        .dx;
    final enemyLeft = tester
        .getTopLeft(find.byKey(const Key('compact-fleet-col-enemy-escort')))
        .dx;
    final enemyRight = tester
        .getTopRight(find.byKey(const Key('compact-fleet-col-enemy-main')))
        .dx;
    expect(
      tester.getCenter(friendHeading).dx,
      closeTo((friendLeft + friendRight) / 2, 1),
    );
    expect(
      tester.getCenter(enemyHeading).dx,
      closeTo((enemyLeft + enemyRight) / 2, 1),
    );
    expect(find.byKey(const Key('compact-mvp-friend-main-0')), findsOneWidget);
    expect(
      find.byKey(const Key('compact-mvp-friend-escort-0')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('compact-mvp-enemy-main-0')), findsNothing);
    final mainCrown = tester.widget<Icon>(
      find.byKey(const Key('compact-mvp-friend-main-0')),
    );
    final escortCrown = tester.widget<Icon>(
      find.byKey(const Key('compact-mvp-friend-escort-0')),
    );
    expect(mainCrown.size, 9);
    expect(escortCrown.size, 9);
    expect(tester.takeException(), isNull);
  });
}

File _materialIconsFont() {
  final separator = Platform.pathSeparator;
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    final candidate = File(
      '${directory.path}${separator}bin${separator}cache${separator}artifacts'
      '${separator}material_fonts${separator}MaterialIcons-Regular.otf',
    );
    if (candidate.existsSync()) {
      return candidate;
    }
    directory = directory.parent;
  }
  throw StateError('Unable to locate the Flutter Material Icons font.');
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
