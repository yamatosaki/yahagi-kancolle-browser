import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_controller.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_models.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_pills.dart';
import 'package:yahagi_kancolle_browser/src/battle/detailed_battle_panel.dart';
import 'package:yahagi_kancolle_browser/src/battle/live_battle_card.dart';
import 'package:yahagi_kancolle_browser/src/bridge/captured_api_event.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';

import 'fixtures/kcsapi_fixtures.dart';

BattleController _createController() {
  final reducer = GameStateReducer();
  var state = reducer.reduce(GameState.empty, start2Event);
  state = reducer.reduce(state, portEvent);
  return BattleController(gameState: () => state);
}

CapturedApiEvent _dayBattleWithAirSuperiority(int seiku) {
  final decoded =
      jsonDecode(dayBattleEvent.responseBody) as Map<String, dynamic>;
  final data = Map<String, Object?>.from(decoded['api_data'] as Map);
  data['api_kouku'] = <String, Object?>{
    'api_stage1': <String, Object?>{'api_disp_seiku': seiku},
  };
  return kcsapiEvent(
    dayBattleEvent.path,
    data,
    sequence: dayBattleEvent.sequence,
  );
}

CapturedApiEvent _dayBattleWithEngagement(int engagement) {
  final decoded =
      jsonDecode(dayBattleEvent.responseBody) as Map<String, dynamic>;
  final data = Map<String, Object?>.from(decoded['api_data'] as Map);
  data['api_formation'] = <int>[1, 1, engagement];
  return kcsapiEvent(
    dayBattleEvent.path,
    data,
    sequence: dayBattleEvent.sequence,
  );
}

CapturedApiEvent _dayBattleWithStatus({int seiku = 1, int engagement = 3}) {
  final decoded =
      jsonDecode(dayBattleEvent.responseBody) as Map<String, dynamic>;
  final data = Map<String, Object?>.from(decoded['api_data'] as Map);
  data['api_kouku'] = <String, Object?>{
    'api_stage1': <String, Object?>{'api_disp_seiku': seiku},
  };
  data['api_formation'] = <int>[1, 1, engagement];
  return kcsapiEvent(
    dayBattleEvent.path,
    data,
    sequence: dayBattleEvent.sequence,
  );
}

CapturedApiEvent _battleResultWithEnemyName(String name) {
  final decoded =
      jsonDecode(battleResultEvent.responseBody) as Map<String, dynamic>;
  final data = Map<String, Object?>.from(decoded['api_data'] as Map);
  data['api_enemy_info'] = <String, Object?>{'api_deck_name': name};
  return kcsapiEvent(
    battleResultEvent.path,
    data,
    sequence: battleResultEvent.sequence,
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  BattleController controller, {
  bool compact = false,
  double? width,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: LiveBattleCard(
            controller: controller,
            collapsed: false,
            onToggleCollapse: () {},
          ),
        ),
      ),
    ),
  );
  if (compact) {
    await tester.tap(find.byKey(const Key('battle-mode-compact')));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('air superiority pill colors', () {
    test('ensure and advantage use green', () {
      expect(
        airSuperiorityPillColors('确保').foreground,
        const Color(0xff83d5c8),
      );
      expect(
        airSuperiorityPillColors('优势').foreground,
        const Color(0xff83d5c8),
      );
    });

    test('disadvantage and loss use red', () {
      expect(
        airSuperiorityPillColors('劣势').foreground,
        const Color(0xffff8c78),
      );
      expect(
        airSuperiorityPillColors('丧失').foreground,
        const Color(0xffff8c78),
      );
    });

    test('balance and unknown use yellow', () {
      expect(
        airSuperiorityPillColors('均衡').foreground,
        const Color(0xffffc95c),
      );
      expect(
        airSuperiorityPillColors('未知').foreground,
        const Color(0xffffc95c),
      );
      expect(
        airSuperiorityPillColors('anything else').foreground,
        const Color(0xffffc95c),
      );
    });
  });

  group('node type pill colors', () {
    test('boss uses red', () {
      expect(nodeTypePillColors('Boss 战').foreground, const Color(0xffff8c78));
    });

    test('normal battle matches balanced air-control colors', () {
      final node = nodeTypePillColors('普通战斗');
      final balanced = airSuperiorityPillColors('均衡');
      expect(node.foreground, balanced.foreground);
      expect(node.background, balanced.background);
      expect(node.border, balanced.border);
    });

    test('all node types use the agreed semantic palettes', () {
      final groups = <(List<String>, Color, Color, Color)>[
        (
          <String>['普通战斗', '敌联合舰队', '空袭战', '长距离空袭战'],
          const Color(0xff4a3b21),
          const Color(0xffffc95c),
          const Color(0xff8b6a2b),
        ),
        (
          <String>['夜战'],
          const Color(0xff302943),
          const Color(0xffcbbcf6),
          const Color(0xff6b5b91),
        ),
        (
          <String>['资源获得', '运输点', '护送成功', '航空侦察', '泊地修理'],
          const Color(0xff183e38),
          const Color(0xff83d5c8),
          const Color(0xff2f7469),
        ),
        (
          <String>['资源损失', '起点', '无战斗', '路线选择', '节点事件'],
          const Color(0xff26343e),
          const Color(0xff9db2bf),
          const Color(0xff526875),
        ),
      ];
      for (final group in groups) {
        for (final label in group.$1) {
          final colors = nodeTypePillColors(label);
          expect(colors.background, group.$2, reason: '$label background');
          expect(colors.foreground, group.$3, reason: '$label foreground');
          expect(colors.border, group.$4, reason: '$label border');
        }
      }
    });
  });

  test('active branching is displayed as route selection', () {
    expect(const BattleContext(eventId: 6, eventKind: 2).nodeTypeLabel, '路线选择');
  });

  test('battle phases use yellow except for purple night battle', () {
    expect(battlePhaseChipColor('昼战'), const Color(0xffffc95c));
    expect(battlePhaseChipColor('航空战'), const Color(0xffffc95c));
    expect(battlePhaseChipColor('夜战'), const Color(0xffcbbcf6));
  });

  test('rank badge colors follow the agreed result semantics', () {
    for (final rank in <BattleRank>[BattleRank.ss, BattleRank.s]) {
      expect(battleRankBadgeColors(rank).background, const Color(0xff4a3b21));
    }
    expect(
      battleRankBadgeColors(BattleRank.a).background,
      const Color(0xff2b1a17),
    );
    expect(
      battleRankBadgeColors(BattleRank.b).background,
      const Color(0xff183e38),
    );
    for (final rank in <BattleRank>[
      BattleRank.c,
      BattleRank.d,
      BattleRank.e,
      BattleRank.unknown,
    ]) {
      expect(battleRankBadgeColors(rank).background, const Color(0xff26343e));
    }
  });

  test('enemy combined fleet display name omits the enemy prefix', () {
    expect(battleEnemyFleetDisplayName('敌 联合舰队'), '联合舰队');
    expect(battleEnemyFleetDisplayName('敌 空母机动部队'), '空母机动部队');
    expect(battleEnemyFleetDisplayName('敌方舰队'), '敌方舰队');
  });

  testWidgets('battle status pills use identical dimensions and typography', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: <Widget>[
              const NodeTypePill(label: '普通战斗'),
              const AirSuperiorityPill(label: '确保'),
              MetaChip(
                key: const Key('phase-meta-pill'),
                label: '昼战',
                color: battlePhaseChipColor('昼战'),
              ),
            ],
          ),
        ),
      ),
    );

    final nodePill = find.byKey(const Key('node-type-pill'));
    final airPill = find.byKey(const Key('air-superiority-pill'));
    final metaPill = find.byKey(const Key('phase-meta-pill'));
    expect(tester.getSize(nodePill).height, 20);
    expect(tester.getSize(airPill).height, 20);
    expect(tester.getSize(metaPill).height, 20);
    final nodeText = tester.widget<Text>(find.text('普通战斗'));
    final airText = tester.widget<Text>(find.text('制空：确保'));
    final metaText = tester.widget<Text>(find.text('昼战'));
    expect(nodeText.style?.fontSize, airText.style?.fontSize);
    expect(nodeText.style?.fontWeight, airText.style?.fontWeight);
    expect(nodeText.style?.height, airText.style?.height);
    expect(metaText.style?.fontSize, nodeText.style?.fontSize);
    expect(metaText.style?.fontWeight, nodeText.style?.fontWeight);
    expect(metaText.style?.height, nodeText.style?.height);
    final decoration =
        tester
                .widget<Container>(
                  find.descendant(
                    of: metaPill,
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.borderRadius, BorderRadius.circular(999));
  });

  testWidgets('rank badge applies semantic foreground, fill, and border', (
    tester,
  ) async {
    for (final entry in <(BattleRank, Color, Color, Color)>[
      (
        BattleRank.ss,
        const Color(0xffffd65c),
        const Color(0xff4a3b21),
        const Color(0xffd4a85f),
      ),
      (
        BattleRank.s,
        const Color(0xffffd65c),
        const Color(0xff4a3b21),
        const Color(0xffd4a85f),
      ),
      (
        BattleRank.a,
        const Color(0xffff8c78),
        const Color(0xff2b1a17),
        const Color(0xffa0453a),
      ),
      (
        BattleRank.b,
        const Color(0xff83d5c8),
        const Color(0xff183e38),
        const Color(0xff2f7469),
      ),
      (
        BattleRank.c,
        const Color(0xff9db2bf),
        const Color(0xff26343e),
        const Color(0xff526875),
      ),
      (
        BattleRank.d,
        const Color(0xff9db2bf),
        const Color(0xff26343e),
        const Color(0xff526875),
      ),
      (
        BattleRank.e,
        const Color(0xff9db2bf),
        const Color(0xff26343e),
        const Color(0xff526875),
      ),
      (
        BattleRank.unknown,
        const Color(0xff9db2bf),
        const Color(0xff26343e),
        const Color(0xff526875),
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BattleRankBadge(rank: entry.$1)),
        ),
      );
      final badge = tester.widget<Container>(
        find.byKey(const Key('battle-rank-badge')),
      );
      final decoration = badge.decoration! as BoxDecoration;
      expect(decoration.color, entry.$3, reason: entry.$1.label);
      expect(
        (decoration.border! as Border).top.color,
        entry.$4,
        reason: entry.$1.label,
      );
      expect(
        tester.widget<Text>(find.text(entry.$1.label)).style?.color,
        entry.$2,
        reason: entry.$1.label,
      );
    }
  });

  test('engagement chip colors use yellow except for T outcomes', () {
    expect(engagementChipColor(3), const Color(0xff6fd3a9));
    expect(engagementChipColor(4), const Color(0xffff6f68));
    expect(engagementChipColor(1), const Color(0xffffc95c));
    expect(engagementChipColor(2), const Color(0xffffc95c));
    expect(engagementChipColor(0), const Color(0xff9db2bf));
  });

  testWidgets('compact navigation shows node and node type pill without map', (
    tester,
  ) async {
    final controller = _createController();
    addTearDown(controller.dispose);
    controller.accept(mapStartEvent);
    await controller.idle;

    await _pumpCard(tester, controller, compact: true);

    expect(find.text('节点 1'), findsOneWidget);
    expect(find.text('普通战斗'), findsOneWidget);
    expect(find.textContaining('1-1'), findsNothing);
  });

  testWidgets('compact battle hides drop before result and omits map', (
    tester,
  ) async {
    final controller = _createController();
    addTearDown(controller.dispose);
    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent);
    await controller.idle;

    await _pumpCard(tester, controller, compact: true);

    expect(find.text('节点 1'), findsOneWidget);
    expect(find.text('敌方舰队'), findsOneWidget);
    expect(find.text('普通战斗'), findsOneWidget);
    expect(find.textContaining('掉落'), findsNothing);
    expect(find.textContaining('1-1'), findsNothing);
    expect(find.byKey(const Key('compact-fleet-grid')), findsOneWidget);
    expect(find.byKey(const Key('compact-fleet-col-friend')), findsOneWidget);
    expect(find.byKey(const Key('compact-fleet-col-enemy')), findsOneWidget);
    expect(find.text('我方舰队（单纵阵）'), findsOneWidget);
    expect(find.text('敌方舰队（单纵阵）'), findsOneWidget);
    expect(find.text('18 / 30 (-12)'), findsWidgets);
    expect(find.text('昼战'), findsOneWidget);
    expect(find.text('己方 单纵阵'), findsNothing);
    expect(find.text('敌方 单纵阵'), findsNothing);
    expect(
      tester.widget<Text>(find.text('普通战斗')).style?.fontWeight,
      FontWeight.w600,
    );
    expect(find.text('同航战'), findsOneWidget);
  });

  testWidgets(
    'phone compact battle moves node and air pills below the enemy name',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = _createController();
      addTearDown(controller.dispose);
      controller
        ..accept(mapStartEvent)
        ..accept(_dayBattleWithAirSuperiority(1));
      await controller.idle;

      await _pumpCard(tester, controller, compact: true);

      final enemy = find.text('敌方舰队');
      final node = find.text('普通战斗');
      final air = find.text('制空：确保');
      expect(enemy, findsOneWidget);
      expect(node, findsOneWidget);
      expect(air, findsOneWidget);
      expect(
        tester.getTopLeft(node).dy,
        greaterThan(tester.getTopLeft(enemy).dy),
      );
      expect(
        tester.getTopLeft(air).dy,
        greaterThan(tester.getTopLeft(enemy).dy),
      );
      expect(
        (tester.getTopLeft(node).dy - tester.getTopLeft(air).dy).abs(),
        lessThan(25),
      );
    },
  );

  testWidgets(
    'narrow card keeps a long enemy fleet name complete and moves status pills below',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const enemyName = '超弩级深海联合打击舰队旗舰护卫部队';

      for (final compact in <bool>[false, true]) {
        final controller = _createController();
        addTearDown(controller.dispose);
        controller
          ..accept(mapStartEvent)
          ..accept(_dayBattleWithAirSuperiority(1))
          ..accept(_battleResultWithEnemyName(enemyName));
        await controller.idle;

        await _pumpCard(tester, controller, compact: compact, width: 320);

        final enemy = find.text(enemyName);
        final nodeType = find.text('普通战斗');
        expect(enemy, findsOneWidget);
        expect(nodeType, findsOneWidget);
        final enemyText = tester.widget<Text>(enemy);
        expect(enemyText.maxLines, isNull);
        expect(enemyText.overflow, isNot(TextOverflow.ellipsis));
        expect(
          tester.getTopLeft(nodeType).dy,
          greaterThan(tester.getTopLeft(enemy).dy),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'battle status pills share one row below the enemy name across large layouts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      for (final size in <Size>[
        const Size(844, 390),
        const Size(1280, 800),
        const Size(910, 700),
      ]) {
        for (final compact in <bool>[false, true]) {
          tester.view.physicalSize = size;
          final controller = _createController();
          controller
            ..accept(mapStartEvent)
            ..accept(_dayBattleWithStatus());
          await controller.idle;

          await _pumpCard(tester, controller, compact: compact);

          final enemyTop = tester.getTopLeft(find.text('敌方舰队')).dy;
          final statusTops = <double>[
            tester.getTopLeft(find.text('普通战斗')).dy,
            tester.getTopLeft(find.text('制空：确保')).dy,
            tester.getTopLeft(find.text('昼战')).dy,
            tester.getTopLeft(find.text('T 字有利')).dy,
          ];
          expect(
            statusTops,
            everyElement(greaterThan(enemyTop)),
            reason: '$size compact=$compact should place status below enemy',
          );
          expect(
            statusTops.reduce((a, b) => a < b ? a : b),
            closeTo(statusTops.reduce((a, b) => a > b ? a : b), 1),
            reason: '$size compact=$compact should use one status row',
          );

          controller.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  testWidgets('compact battle colors engagement like detailed mode', (
    tester,
  ) async {
    for (final entry in <(int, Color, String)>[
      (3, const Color(0xff6fd3a9), 'T 字有利'),
      (4, const Color(0xffff6f68), 'T 字不利'),
    ]) {
      final controller = _createController();
      addTearDown(controller.dispose);
      controller
        ..accept(mapStartEvent)
        ..accept(_dayBattleWithEngagement(entry.$1));
      await controller.idle;

      await _pumpCard(tester, controller, compact: true);

      final chip = tester.widget<Text>(find.text(entry.$3));
      expect(chip.style?.color, entry.$2);
    }
  });

  testWidgets('detailed battle colors T advantage and disadvantage', (
    tester,
  ) async {
    for (final entry in <(int, Color, String)>[
      (3, const Color(0xff6fd3a9), 'T 字有利'),
      (4, const Color(0xffff6f68), 'T 字不利'),
    ]) {
      final controller = _createController();
      addTearDown(controller.dispose);
      controller
        ..accept(mapStartEvent)
        ..accept(_dayBattleWithEngagement(entry.$1));
      await controller.idle;

      await _pumpCard(tester, controller);

      final chip = tester.widget<Text>(find.text(entry.$3));
      expect(chip.style?.color, entry.$2);
    }
  });

  testWidgets('compact battle shows drop capsule only after result', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = _createController();
    addTearDown(controller.dispose);
    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent)
      ..accept(battleResultEvent);
    await controller.idle;

    await _pumpCard(tester, controller, compact: true);

    expect(find.text('掉落：吹雪'), findsOneWidget);
    expect(find.text('掉落：家具コイン'), findsOneWidget);
    expect(find.textContaining('44'), findsNothing);
    final dropText = tester.widget<Text>(find.text('掉落：吹雪'));
    expect(dropText.style?.fontSize, 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact battle shows MVP crown after hp text', (tester) async {
    final controller = _createController();
    addTearDown(controller.dispose);
    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent)
      ..accept(battleResultEvent);
    await controller.idle;

    await _pumpCard(tester, controller, compact: true);

    final row = find.byKey(const Key('compact-bar-friend-0'));
    expect(row, findsOneWidget);
    final hpText = find.descendant(
      of: row,
      matching: find.text('18 / 30 (-12)'),
    );
    expect(hpText, findsOneWidget);
    expect(tester.widget<Text>(hpText).style?.color, const Color(0xffffc940));
    final crown = find.byKey(const Key('compact-mvp-friend-0'));
    expect(crown, findsOneWidget);
    final icon = tester.widget<Icon>(crown);
    expect(icon.icon, Icons.emoji_events_rounded);
    expect(icon.size, 9);
    expect(
      tester.getTopLeft(crown).dx,
      greaterThan(tester.getTopRight(hpText).dx),
    );
    expect(find.byKey(const Key('compact-mvp-enemy-0')), findsNothing);
    final sunkRow = find.byKey(const Key('compact-bar-enemy-0'));
    expect(
      tester
          .widgetList<Text>(
            find.descendant(of: sunkRow, matching: find.byType(Text)),
          )
          .single
          .style
          ?.color,
      const Color(0xff71818b),
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.descendant(
              of: sunkRow,
              matching: find.byType(LinearProgressIndicator),
            ),
          )
          .color,
      const Color(0xff71818b),
    );
  });

  testWidgets('air superiority pill renders with the status color', (
    tester,
  ) async {
    final controller = _createController();
    addTearDown(controller.dispose);
    controller
      ..accept(mapStartEvent)
      ..accept(_dayBattleWithAirSuperiority(1));
    await controller.idle;

    await _pumpCard(tester, controller, compact: true);

    expect(find.text('制空：确保'), findsOneWidget);
    final pill = tester.widget<Container>(
      find.byKey(const Key('air-superiority-pill')),
    );
    final decoration = pill.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xff183e38));
    expect((decoration.border! as Border).top.color, const Color(0xff2f7469));
  });

  testWidgets('detailed battle shows phase formation engagement and no map', (
    tester,
  ) async {
    final controller = _createController();
    addTearDown(controller.dispose);
    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent);
    await controller.idle;

    await _pumpCard(tester, controller);

    expect(find.text('节点 1'), findsOneWidget);
    expect(find.text('敌方舰队'), findsOneWidget);
    expect(find.text('昼战'), findsOneWidget);
    expect(find.text('己方 单纵阵'), findsNothing);
    expect(find.text('敌方 单纵阵'), findsNothing);
    expect(find.text('我方主力（单纵阵）'), findsOneWidget);
    expect(find.text('敌方主力（单纵阵）'), findsOneWidget);
    expect(find.text('同航战'), findsOneWidget);
    expect(find.text('普通战斗'), findsOneWidget);
    expect(find.textContaining('1-1'), findsNothing);
  });

  testWidgets('phone detailed battle header matches compact layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = _createController();
    addTearDown(controller.dispose);
    controller
      ..accept(mapStartEvent)
      ..accept(_dayBattleWithAirSuperiority(1))
      ..accept(battleResultEvent);
    await controller.idle;

    await _pumpCard(tester, controller);

    final enemy = find.text('Test Enemy Fleet');
    final node = find.text('普通战斗');
    final air = find.text('制空：确保');
    final phase = find.text('昼战');
    expect(enemy, findsOneWidget);
    expect(node, findsOneWidget);
    expect(air, findsOneWidget);
    expect(
      tester.getTopLeft(node).dy,
      greaterThan(tester.getTopLeft(enemy).dy),
    );
    expect(tester.getTopLeft(air).dy, greaterThan(tester.getTopLeft(enemy).dy));
    expect(
      (tester.getTopLeft(node).dy - tester.getTopLeft(air).dy).abs(),
      lessThan(25),
    );
    expect(
      (tester.getTopLeft(phase).dy - tester.getTopLeft(node).dy).abs(),
      lessThanOrEqualTo(25),
    );
    expect(find.text('掉落：吹雪'), findsOneWidget);
    expect(find.byKey(const Key('battle-drop-result')), findsNothing);
    final enemyText = tester.widget<Text>(enemy);
    expect(enemyText.style?.fontSize, 13);
    expect(enemyText.style?.fontWeight, FontWeight.w600);
    final rankText = tester.widget<Text>(find.text('S'));
    expect(rankText.style?.fontSize, 21);
  });

  testWidgets('ship cell shows received damage in hp line and no fatigue', (
    tester,
  ) async {
    final controller = _createController();
    addTearDown(controller.dispose);
    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent);
    await controller.idle;

    await _pumpCard(tester, controller);

    expect(find.text('18 / 30 (-12)'), findsOneWidget);
    expect(find.textContaining('疲劳'), findsNothing);
    expect(find.textContaining('伤害 '), findsNothing);

    final shipRow = find.byKey(const Key('battle-ship-friend-0'));
    final hpCenter = tester.getCenter(find.text('18 / 30 (-12)'));
    final nameCenter = tester.getCenter(
      find.descendant(of: shipRow, matching: find.byType(Text)).first,
    );
    final barFinder = find.descendant(
      of: shipRow,
      matching: find.byType(LinearProgressIndicator),
    );
    expect(barFinder, findsOneWidget);
    expect(
      tester.widget<Text>(find.text('18 / 30 (-12)')).style?.color,
      const Color(0xffffc940),
    );
    expect(
      tester.widget<LinearProgressIndicator>(barFinder).color,
      const Color(0xffffc940),
    );
    final barCenter = tester.getCenter(barFinder);
    final hpBlockMid = (hpCenter.dy + barCenter.dy) / 2;
    expect((nameCenter.dy - hpBlockMid).abs(), lessThan(3));

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).first);
    expect(tooltip.message, isNotEmpty);
    expect(find.byKey(const Key('battle-mvp-friend-0')), findsOneWidget);
  });

  testWidgets('forecast hides rank until the official battle result', (
    tester,
  ) async {
    final controller = _createController();
    addTearDown(controller.dispose);
    controller
      ..accept(mapStartEvent)
      ..accept(dayBattleEvent);
    await controller.idle;

    await _pumpCard(tester, controller);
    expect(find.byKey(const Key('battle-rank-badge')), findsNothing);

    controller.accept(battleResultEvent);
    await controller.idle;
    await tester.pump();

    expect(find.byKey(const Key('battle-rank-badge')), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('boss node pill uses red text in battle', (tester) async {
    final controller = _createController();
    addTearDown(controller.dispose);
    final bossStart =
        kcsapiEvent('/kcsapi/api_req_map/start', <String, Object?>{
          'api_maparea_id': 1,
          'api_mapinfo_no': 1,
          'api_no': 5,
          'api_bosscell_no': 5,
          'api_event_id': 5,
          'api_event_kind': 0,
        }, sequence: 20);
    controller
      ..accept(bossStart)
      ..accept(dayBattleEvent);
    await controller.idle;

    await _pumpCard(tester, controller, compact: true);

    final bossText = tester.widget<Text>(find.text('Boss 战'));
    expect(bossText.style?.color, const Color(0xffff8c78));
  });

  testWidgets('detailed navigation uses the red boss node pill', (
    tester,
  ) async {
    final controller = _createController();
    addTearDown(controller.dispose);
    controller.accept(
      kcsapiEvent('/kcsapi/api_req_map/start', <String, Object?>{
        'api_maparea_id': 1,
        'api_mapinfo_no': 1,
        'api_no': 5,
        'api_bosscell_no': 5,
        'api_event_id': 5,
        'api_event_kind': 0,
      }, sequence: 21),
    );
    await controller.idle;

    await _pumpCard(tester, controller);

    final pill = tester.widget<Container>(
      find.byKey(const Key('node-type-pill')),
    );
    final decoration = pill.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xff2b1a17));
    expect(((decoration.border! as Border).top.color), const Color(0xffa0453a));
    expect(
      tester.widget<Text>(find.text('Boss 战')).style?.color,
      const Color(0xffff8c78),
    );
  });

  testWidgets('detailed navigation shows node without map', (tester) async {
    final controller = _createController();
    addTearDown(controller.dispose);
    controller.accept(mapStartEvent);
    await controller.idle;

    await _pumpCard(tester, controller);

    expect(find.text('节点 1'), findsOneWidget);
    expect(find.text('普通战斗'), findsOneWidget);
    expect(find.textContaining('1-1'), findsNothing);
  });
}
