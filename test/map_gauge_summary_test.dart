import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/fleet/pre_sortie_check_summary.dart';
import 'package:yahagi_kancolle_browser/src/game_state/combat_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_controller.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_reducer.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_serializer.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_controller.dart';
import 'package:yahagi_kancolle_browser/src/settings/layout_settings_store.dart';

import 'fixtures/kcsapi_fixtures.dart';

void main() {
  group('Map Gauge GameState & Reducer', () {
    test('parses member map info with EO defeat counts and event map HP', () {
      final reducer = GameStateReducer();
      var state = reducer.reduce(
        GameState.empty,
        kcsapiEvent('/kcsapi/api_start2/getData', <String, Object?>{
          'api_mst_mapinfo': <Object?>[
            <String, Object?>{
              'api_id': 16,
              'api_maparea_id': 1,
              'api_no': 6,
              'api_name': '鎮守府近海航路',
              'api_required_defeat_count': 7,
            },
            <String, Object?>{
              'api_id': 25,
              'api_maparea_id': 2,
              'api_no': 5,
              'api_name': '沖ノ島沖',
              'api_required_defeat_count': 4,
            },
            <String, Object?>{
              'api_id': 72,
              'api_maparea_id': 7,
              'api_no': 2,
              'api_name': 'タウィタウィ泊地沖',
              'api_required_defeat_count': 3,
            },
            <String, Object?>{
              'api_id': 621,
              'api_maparea_id': 62,
              'api_no': 1,
              'api_name': '九州沖/南西諸島沖',
            },
          ],
        }),
      );

      state = reducer.reduce(
        state,
        kcsapiEvent('/kcsapi/api_get_member/mapinfo', <String, Object?>{
          'api_map_info': <Object?>[
            <String, Object?>{
              'api_id': 16,
              'api_cleared': 0,
              'api_defeat_count': 2,
            },
            <String, Object?>{
              'api_id': 25,
              'api_cleared': 1,
              'api_defeat_count': 4,
            },
            <String, Object?>{
              'api_id': 72,
              'api_cleared': 1,
              'api_defeat_count': 0,
              'api_gauge_num': 1,
              'api_gauge_max_num': 2,
            },
            <String, Object?>{
              'api_id': 621,
              'api_cleared': 0,
              'api_eventmap': <String, Object?>{
                'api_now_maphp': 200,
                'api_max_maphp': 300,
                'api_selected_rank': 4,
              },
            },
          ],
        }),
      );

      expect(state.memberMapInfos, hasLength(4));

      final map72 = state.memberMapInfos[702];
      expect(map72, isNotNull);
      expect(map72!.code, '7-2');
      expect(map72.displayName, 'タウィタウィ泊地沖');
      expect(map72.isSpNormal, isTrue);
      expect(map72.categoryTag, 'SP Normal');
      expect(map72.isGaugeCleared, isFalse);
      expect(map72.currentGaugeValue, 3); // 3 - 0 = 3 (full gauge!)
      expect(map72.maxGaugeValue, 3);
      expect(map72.percentage, 1.0);

      final map16 = state.memberMapInfos[106];
      expect(map16, isNotNull);
      expect(map16!.code, '1-6');
      expect(map16.displayName, '鎮守府近海航路');
      expect(map16.isExtra, isTrue);
      expect(map16.categoryTag, 'Extra');
      expect(map16.cleared, isFalse);
      expect(map16.currentGaugeValue, 5); // 7 - 2 = 5
      expect(map16.maxGaugeValue, 7);
      expect(map16.percentage, closeTo(5 / 7, 0.01));

      final map25 = state.memberMapInfos[205];
      expect(map25, isNotNull);
      expect(map25!.code, '2-5');
      expect(map25.cleared, isTrue);
      expect(map25.currentGaugeValue, 0);
      expect(map25.maxGaugeValue, 4);
      expect(map25.percentage, 0.0);

      final map621 = state.memberMapInfos[6201];
      expect(map621, isNotNull);
      expect(map621!.code, '62-1');
      expect(map621.isEvent, isTrue);
      expect(map621.categoryTag, 'Event');
      expect(map621.rankName, '甲');
      expect(map621.currentGaugeValue, 200);
      expect(map621.maxGaugeValue, 300);
      expect(map621.percentage, closeTo(200 / 300, 0.01));
    });

    test('treats member map info as an authoritative snapshot', () {
      final reducer = GameStateReducer();
      const staleMap = MemberMapInfo(
        id: 16,
        mapAreaId: 1,
        mapNo: 6,
        name: '鎮守府近海航路',
        cleared: true,
        defeatCount: 7,
        requiredDefeatCount: 7,
      );

      final state = reducer.reduce(
        const GameState(memberMapInfos: <int, MemberMapInfo>{106: staleMap}),
        kcsapiEvent('/kcsapi/api_get_member/mapinfo', <String, Object?>{
          'api_map_info': <Object?>[
            <String, Object?>{
              'api_id': 56,
              'api_cleared': 0,
              'api_defeat_count': 0,
              'api_required_defeat_count': 5,
            },
            <String, Object?>{
              'api_id': 74,
              'api_cleared': 0,
              'api_defeat_count': 0,
              'api_required_defeat_count': 3,
            },
          ],
        }),
      );

      expect(state.memberMapInfos.keys, unorderedEquals(<int>[506, 704]));
      expect(state.memberMapInfos[506]?.currentGaugeValue, 5);
      expect(state.memberMapInfos[704]?.currentGaugeValue, 3);
    });

    test('serializes and deserializes memberMapInfos', () {
      final state = GameState(
        memberMapInfos: <int, MemberMapInfo>{
          106: const MemberMapInfo(
            id: 16,
            mapAreaId: 1,
            mapNo: 6,
            name: '鎮守府近海航路',
            cleared: false,
            defeatCount: 3,
            requiredDefeatCount: 7,
          ),
          6201: const MemberMapInfo(
            id: 621,
            mapAreaId: 62,
            mapNo: 1,
            name: '九州沖/南西諸島沖',
            cleared: false,
            currentHp: 150,
            maxHp: 300,
            selectedRank: 4,
            isEvent: true,
          ),
        },
      );

      final json = GameStateSerializer.serialize(state);
      final restored = GameStateSerializer.deserialize(json);

      expect(restored.memberMapInfos, hasLength(2));
      expect(restored.memberMapInfos[106]?.name, '鎮守府近海航路');
      expect(restored.memberMapInfos[106]?.currentGaugeValue, 4);
      expect(restored.memberMapInfos[6201]?.currentGaugeValue, 150);
      expect(restored.memberMapInfos[6201]?.rankName, '甲');
    });

    test('select_eventmap_rank updates difficulty rank and map HP', () {
      final reducer = GameStateReducer();
      var state = GameState(
        memberMapInfos: <int, MemberMapInfo>{
          6201: const MemberMapInfo(
            id: 621,
            mapAreaId: 62,
            mapNo: 1,
            name: '九州沖/南西諸島沖',
            cleared: false,
            currentHp: 200,
            maxHp: 300,
            selectedRank: 4,
            isEvent: true,
          ),
        },
      );

      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_map/select_eventmap_rank',
          <String, Object?>{
            'api_maphp': <String, Object?>{
              'api_now_maphp': 250,
              'api_max_maphp': 250,
              'api_gauge_num': 1,
              'api_gauge_max_num': 2,
            },
          },
          requestParams: <String, Object?>{
            'api_maparea_id': '62',
            'api_map_no': '1',
            'api_rank': '3',
          },
        ),
      );

      final map = state.memberMapInfos[6201];
      expect(map, isNotNull);
      expect(map!.selectedRank, 3);
      expect(map.rankName, '乙');
      expect(map.currentGaugeValue, 250);
      expect(map.maxGaugeValue, 250);
      expect(map.gaugeNum, 1);
      expect(map.gaugeMaxNum, 2);
    });

    test('battleresult updates map HP in real-time', () {
      final reducer = GameStateReducer();
      var state = GameState(
        combatState: const CombatState(mapArea: 62, mapInfo: 1),
        memberMapInfos: <int, MemberMapInfo>{
          6201: const MemberMapInfo(
            id: 621,
            mapAreaId: 62,
            mapNo: 1,
            name: '九州沖/南西諸島沖',
            cleared: false,
            currentHp: 250,
            maxHp: 250,
            selectedRank: 3,
            isEvent: true,
          ),
        },
      );

      // Boss battle dealt 150 damage, now remaining 100
      state = reducer.reduce(
        state,
        kcsapiEvent(
          '/kcsapi/api_req_combined_battle/battleresult',
          <String, Object?>{
            'api_maphp': <String, Object?>{
              'api_now_maphp': 100,
              'api_max_maphp': 250,
              'api_gauge_num': 1,
              'api_gauge_max_num': 2,
            },
          },
        ),
      );

      final map = state.memberMapInfos[6201];
      expect(map, isNotNull);
      expect(map!.currentGaugeValue, 100);
      expect(map.maxGaugeValue, 250);
      expect(map.percentage, closeTo(100 / 250, 0.01));
    });
  });

  group('PreSortieCheckSummary Widget', () {
    testWidgets('defaults to ships mode and switches to maps gauge mode', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final layoutSettings = await LayoutSettingsController.load(
        SharedPreferencesLayoutSettingsStore(),
      );
      addTearDown(layoutSettings.dispose);
      final state = GameState(
        hasMasterData: true,
        hasPortData: true,
        memberMapInfos: <int, MemberMapInfo>{
          101: const MemberMapInfo(
            id: 11,
            mapAreaId: 1,
            mapNo: 1,
            name: '鎮守府正面海域',
            cleared: true,
          ),
          701: const MemberMapInfo(
            id: 71,
            mapAreaId: 7,
            mapNo: 1,
            name: 'ブルネイ泊地沖',
            cleared: true,
          ),
          106: const MemberMapInfo(
            id: 16,
            mapAreaId: 1,
            mapNo: 6,
            name: '鎮守府近海航路',
            cleared: false,
            defeatCount: 2,
            requiredDefeatCount: 7,
          ),
          205: const MemberMapInfo(
            id: 25,
            mapAreaId: 2,
            mapNo: 5,
            name: '沖ノ島沖',
            cleared: true,
            defeatCount: 4,
            requiredDefeatCount: 4,
          ),
          6201: const MemberMapInfo(
            id: 621,
            mapAreaId: 62,
            mapNo: 1,
            name: '九州沖/南西諸島沖',
            cleared: false,
            currentHp: 200,
            maxHp: 300,
            selectedRank: 4,
            isEvent: true,
          ),
        },
      );

      final controller = GameStateController(
        gameStateStore: _StaticStore(state),
      );
      addTearDown(controller.dispose);
      await controller.idle;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PreSortieCheckSummary(
              controller: controller,
              settingsController: layoutSettings,
              collapsed: false,
              onToggleCollapse: () {},
              onOpenFleet: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Defaults to Ships mode
      expect(
        find.byKey(const Key('sortie-check-mode-selector')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('sortie-check-mode-ships')), findsOneWidget);
      expect(find.byKey(const Key('sortie-check-mode-maps')), findsOneWidget);
      expect(find.text('暂无出击警告'), findsOneWidget);

      // Switch to Maps mode
      await tester.tap(find.byKey(const Key('sortie-check-mode-maps')));
      await tester.pumpAndSettle();

      // Cleared maps are hidden by default.
      expect(find.text('1-6 鎮守府近海航路'), findsOneWidget);
      expect(find.text('5 / 7'), findsOneWidget);
      expect(find.text('额外作战'), findsOneWidget);
      expect(find.text('62-1 九州沖/南西諸島沖 甲'), findsOneWidget);
      expect(find.text('200 / 300'), findsOneWidget);
      expect(find.text('活动海域'), findsOneWidget);
      expect(find.text('2-5 沖ノ島沖'), findsNothing);
      // Normal single-kill maps are never shown
      expect(find.text('1-1 鎮守府正面海域'), findsNothing);
      expect(find.text('7-1 ブルネイ泊地沖'), findsNothing);

      // Opt in to showing cleared maps.
      await tester.tap(find.byKey(const Key('map-gauge-toggle-show-cleared')));
      await tester.pumpAndSettle();

      expect(find.text('2-5 沖ノ島沖'), findsOneWidget);
      expect(find.text('0 / 4'), findsOneWidget);
      expect(find.text('1-6 鎮守府近海航路'), findsOneWidget);

      // Rebuilding the card keeps the user's choice.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PreSortieCheckSummary(
              controller: controller,
              settingsController: layoutSettings,
              collapsed: false,
              onToggleCollapse: () {},
              onOpenFleet: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sortie-check-mode-maps')));
      await tester.pumpAndSettle();
      expect(find.text('2-5 沖ノ島沖'), findsOneWidget);

      // Switch back to Ships mode
      await tester.tap(find.byKey(const Key('sortie-check-mode-ships')));
      await tester.pumpAndSettle();
      expect(find.text('暂无出击警告'), findsOneWidget);
    });
  });
}

class _StaticStore extends GameStateStore {
  _StaticStore(this.value);

  final GameState value;

  @override
  Future<GameState> load() async => value;
}
