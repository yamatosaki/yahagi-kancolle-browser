import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/battle/battle_pills.dart';
import 'package:yahagi_kancolle_browser/src/fleet/ship_portrait.dart';
import 'package:yahagi_kancolle_browser/src/game_state/game_state.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_models.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_query_page.dart';
import 'package:yahagi_kancolle_browser/src/toolbox/sortie_map_query/sortie_map_selection_store.dart';
import 'package:yahagi_kancolle_browser/src/widgets/app_segmented_style.dart';

void main() {
  testWidgets('tablet landscape enlarges route without shrinking node detail', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1512, 960));

    expect(find.byKey(const Key('sortie-map-tablet-layout')), findsOneWidget);
    final overview = tester.getRect(
      find.byKey(const Key('sortie-map-overview')),
    );
    final route = tester.getRect(find.byKey(const Key('sortie-map-route')));
    final detail = tester.getRect(find.byKey(const Key('sortie-map-detail')));
    final viewport = tester.getRect(
      find.byKey(const Key('sortie-map-route-viewport')),
    );
    expect(overview.bottom, lessThan(route.top));
    expect(route.right, lessThan(detail.left));
    expect(detail.width, greaterThanOrEqualTo(390));
    expect(viewport.width, greaterThan(900));
    expect(overview.height, lessThan(110));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet keeps route controls visible with a taller map image', (
    tester,
  ) async {
    final original = _catalog.maps.first;
    final catalog = SortieMapCatalogData(
      version: 1,
      source: 'test',
      maps: [
        SortieMapInfo(
          id: original.id,
          nameJa: original.nameJa,
          difficulty: original.difficulty,
          coverAsset: original.coverAsset,
          mapAsset: original.mapAsset,
          mapAspectRatio: 5 / 3,
          source: original.source,
          nodes: original.nodes,
        ),
      ],
    );
    await _pumpAt(tester, const Size(1512, 850), catalog: catalog);

    final overview = tester.getRect(
      find.byKey(const Key('sortie-map-overview')),
    );
    final route = tester.getRect(find.byKey(const Key('sortie-map-route')));
    final detail = tester.getRect(find.byKey(const Key('sortie-map-detail')));
    final nodeButton = tester.getRect(
      find.byKey(const Key('sortie-map-node-A')),
    );
    expect((overview.width - route.width).abs(), lessThan(1));
    expect((detail.left - route.right - 12).abs(), lessThan(1));
    expect(detail.width, greaterThan(390));
    expect(nodeButton.bottom, lessThanOrEqualTo(route.bottom - 8));
    expect(find.byKey(const Key('sortie-map-attribution')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet selector strip handles a narrow map ratio', (
    tester,
  ) async {
    final original = _catalog.maps.first;
    final catalog = SortieMapCatalogData(
      version: 1,
      source: 'test',
      maps: [
        SortieMapInfo(
          id: original.id,
          nameJa: original.nameJa,
          difficulty: original.difficulty,
          coverAsset: original.coverAsset,
          mapAsset: original.mapAsset,
          mapAspectRatio: 0.5,
          source: original.source,
          nodes: original.nodes,
        ),
      ],
    );
    await _pumpAt(tester, const Size(1512, 850), catalog: catalog);

    final overview = tester.getRect(
      find.byKey(const Key('sortie-map-overview')),
    );
    final route = tester.getRect(find.byKey(const Key('sortie-map-route')));
    expect(overview.width, greaterThanOrEqualTo(560));
    expect(overview.width, closeTo(route.width, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet selector strip handles narrow map and high difficulty', (
    tester,
  ) async {
    final original = _catalog.maps.first;
    final catalog = SortieMapCatalogData(
      version: 1,
      source: 'test',
      maps: [
        SortieMapInfo(
          id: original.id,
          nameJa: original.nameJa,
          difficulty: 13,
          coverAsset: original.coverAsset,
          mapAsset: original.mapAsset,
          mapAspectRatio: 0.5,
          source: original.source,
          nodes: original.nodes,
        ),
      ],
    );
    await _pumpAt(
      tester,
      const Size(1100, 700),
      catalog: catalog,
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byKey(const Key('sortie-map-difficulty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in const [2.0, 3.0]) {
    testWidgets('tablet selector stays usable with $scale text scale', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        const Size(1512, 850),
        textScaler: TextScaler.linear(scale),
      );

      final selector = find.byKey(const Key('sortie-map-selector'));
      expect(selector, findsOneWidget);
      if (scale > 2) {
        await tester.drag(
          find.byKey(const Key('sortie-map-overview')),
          const Offset(0, -100),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(find.text('1-2 南西諸島沖').last, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in const [2.0, 3.0]) {
    testWidgets('tablet keeps node controls visible at $scale text scale', (
      tester,
    ) async {
      final original = _catalog.maps.first;
      final catalog = SortieMapCatalogData(
        version: 1,
        source: 'test',
        maps: [
          SortieMapInfo(
            id: original.id,
            nameJa: original.nameJa,
            difficulty: original.difficulty,
            coverAsset: original.coverAsset,
            mapAsset: original.mapAsset,
            mapAspectRatio: 1.744360902255639,
            source: original.source,
            nodes: original.nodes,
          ),
        ],
      );
      await _pumpAt(
        tester,
        const Size(1100, 700),
        catalog: catalog,
        textScaler: TextScaler.linear(scale),
      );

      final route = tester.getRect(find.byKey(const Key('sortie-map-route')));
      final node = tester.getRect(find.byKey(const Key('sortie-map-node-A')));
      expect(node.bottom, lessThanOrEqualTo(route.bottom - 8));
      await tester.tap(find.byKey(const Key('sortie-map-node-A')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tablet attribution follows map ratio changes', (tester) async {
    final original = _catalog.maps.first;
    SortieMapInfo map(String id, String name, double ratio) => SortieMapInfo(
      id: id,
      nameJa: name,
      difficulty: original.difficulty,
      coverAsset: original.coverAsset,
      mapAsset: original.mapAsset,
      mapAspectRatio: ratio,
      source: original.source,
      nodes: original.nodes,
    );
    final catalog = SortieMapCatalogData(
      version: 1,
      source: 'test',
      maps: [map('1-1', '鎮守府正面海域', 5 / 3), map('1-2', '南西諸島沖', 2)],
    );
    await _pumpAt(tester, const Size(1512, 850), catalog: catalog);

    final footer = find.byKey(const Key('sortie-map-attribution'));
    expect(footer, findsNothing);
    await tester.tap(find.byKey(const Key('sortie-map-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-2 南西諸島沖').last);
    await tester.pumpAndSettle();

    expect(tester.getRect(footer).bottom, closeTo(846, 1));
    expect(
      tester.getRect(find.byKey(const Key('sortie-map-node-A'))).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('sortie-map-route'))).bottom,
      ),
    );
    await tester.tap(find.byKey(const Key('sortie-map-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-1 鎮守府正面海域').last);
    await tester.pumpAndSettle();
    expect(footer, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet landscape keeps overview, route, and detail visible', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1240, 760));

    expect(find.byKey(const Key('sortie-map-tablet-layout')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-overview')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-route')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-detail')), findsOneWidget);
    expect(find.text('1-1 鎮守府正面海域'), findsWidgets);
    expect(find.text('难度：★'), findsOneWidget);
    final firstCard = tester.getRect(
      find.byKey(const Key('sortie-map-formation-1')),
    );
    final secondCard = tester.getRect(
      find.byKey(const Key('sortie-map-formation-2')),
    );
    expect(secondCard.top, greaterThan(firstCard.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an enemy opens the enemy detail demo card', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(844, 390));

    await tester.tap(find.byKey(const Key('sortie-map-enemy-tile-1-0-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sortie-enemy-details-card')), findsOneWidget);
    expect(find.text('駆逐イ級'), findsWidgets);
    expect(find.byKey(const Key('sortie-enemy-vitals-grid')), findsOneWidget);
    expect(find.text('HP'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('耐久 20'), findsNothing);
    expect(find.text('5inch単装砲'), findsOneWidget);
  });

  testWidgets('enemy rows use compact prophet-style spacing and dividers', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(390, 844));

    final tile = tester.getSize(
      find.byKey(const Key('sortie-map-enemy-tile-1-0-0')),
    );
    expect(tile.height, inInclusiveRange(28, 32));
    expect(find.byKey(const Key('sortie-map-enemy-divider-1-0-0')), findsOne);
  });

  for (final localeAndLabel in const <(Locale, String)>[
    (Locale('ja'), '性能・装備データが一致'),
    (Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'), '精確配置'),
  ]) {
    testWidgets('enemy details localize for ${localeAndLabel.$1}', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(390, 844), locale: localeAndLabel.$1);

      await tester.tap(find.byKey(const Key('sortie-map-enemy-tile-1-0-0')));
      await tester.pumpAndSettle();

      expect(find.text(localeAndLabel.$2), findsOneWidget);
      expect(find.text('精确配置'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('enemy details scroll without overflow on short landscape', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(650, 240));

    await tester.tap(find.byKey(const Key('sortie-map-enemy-tile-1-0-0')));
    await tester.pumpAndSettle();

    final card = tester.getRect(
      find.byKey(const Key('sortie-enemy-details-card')),
    );
    expect(card.top, greaterThanOrEqualTo(16));
    expect(card.bottom, lessThanOrEqualTo(224));
    expect(tester.takeException(), isNull);
  });

  testWidgets('enemy detail demo stays inside a portrait phone viewport', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(390, 844));

    await tester.tap(find.byKey(const Key('sortie-map-enemy-tile-1-0-0')));
    await tester.pumpAndSettle();

    final rect = tester.getRect(
      find.byKey(const Key('sortie-enemy-details-card')),
    );
    expect(rect.left, greaterThanOrEqualTo(16));
    expect(rect.right, lessThanOrEqualTo(374));
    expect(rect.top, greaterThanOrEqualTo(16));
    expect(rect.bottom, lessThanOrEqualTo(828));
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone landscape keeps the same three-column structure', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(844, 390));

    expect(find.byKey(const Key('sortie-map-wide-layout')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-overview')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-route')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-detail')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-selector')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unfolded near-square workspace keeps enemy detail below maps', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(900, 840));

    expect(
      find.byKey(const Key('sortie-map-wide-portrait-layout')),
      findsOneWidget,
    );
    final overview = tester.getRect(
      find.byKey(const Key('sortie-map-overview')),
    );
    final route = tester.getRect(find.byKey(const Key('sortie-map-route')));
    final detail = tester.getRect(find.byKey(const Key('sortie-map-detail')));
    expect((overview.top - route.top).abs(), lessThan(1));
    expect(detail.top, greaterThan(overview.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow unfolded workspace still pairs overview and route', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(680, 720));

    expect(
      find.byKey(const Key('sortie-map-wide-portrait-layout')),
      findsOneWidget,
    );
    final overview = tester.getRect(
      find.byKey(const Key('sortie-map-overview')),
    );
    final route = tester.getRect(find.byKey(const Key('sortie-map-route')));
    final detail = tester.getRect(find.byKey(const Key('sortie-map-detail')));
    expect(overview.right, lessThan(route.left));
    expect(detail.top, greaterThan(overview.bottom));
  });

  testWidgets('narrow landscape still keeps map selection available', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(650, 320));

    expect(find.byKey(const Key('sortie-map-wide-layout')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-selector')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordinary landscape workspace stays usable after app chrome', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(796, 302));

    expect(find.byKey(const Key('sortie-map-wide-layout')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-selector')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-route')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-detail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short phone landscape keeps equal compact panels scrollable', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(796, 270));

    final overview = tester.getRect(
      find.byKey(const Key('sortie-map-overview')),
    );
    final route = tester.getRect(find.byKey(const Key('sortie-map-route')));
    expect((overview.height - route.height).abs(), lessThan(1));
    expect(find.byKey(const Key('sortie-map-route-viewport')), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-node-A')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('route map uses its trimmed asset ratio and raised surface', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1240, 760));

    final overview = tester.getRect(
      find.byKey(const Key('sortie-map-overview')),
    );
    final route = tester.getRect(find.byKey(const Key('sortie-map-route')));
    final detail = tester.getRect(find.byKey(const Key('sortie-map-detail')));
    final viewport = tester.getRect(
      find.byKey(const Key('sortie-map-route-viewport')),
    );
    final routeImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('sortie-map-route-viewport')),
        matching: find.byType(Image),
      ),
    );

    expect(viewport.width / viewport.height, closeTo(2, 0.01));
    final surface = tester.widget<PhysicalModel>(
      find.byKey(const Key('sortie-map-route-surface')),
    );
    expect(surface.elevation, greaterThan(0));
    expect(overview.bottom, lessThan(route.top));
    expect(route.right, lessThan(detail.left));
    expect(routeImage.fit, BoxFit.contain);
  });

  testWidgets('tablet overview strip and route keep comfortable insets', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1240, 760));

    final overview = tester.getRect(
      find.byKey(const Key('sortie-map-overview')),
    );
    final route = tester.getRect(find.byKey(const Key('sortie-map-route')));
    final detail = tester.getRect(find.byKey(const Key('sortie-map-detail')));
    expect(overview.bottom, lessThan(route.top));
    expect(route.right, lessThan(detail.left));
    expect(detail.bottom, greaterThanOrEqualTo(route.bottom));

    final overviewHeading = tester.getRect(find.text('海域选择'));
    final routeHeading = tester.getRect(find.text('路线图'));
    final routeViewport = tester.getRect(
      find.byKey(const Key('sortie-map-route-viewport')),
    );
    expect(overviewHeading.left - overview.left, greaterThanOrEqualTo(8));
    expect(routeHeading.left - route.left, greaterThanOrEqualTo(8));
    expect(routeViewport.top - routeHeading.bottom, greaterThanOrEqualTo(6));
  });

  testWidgets('portrait route image matches the overview image inner width', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(390, 844));

    final cover = tester.getRect(find.byKey(const Key('sortie-map-cover')));
    final routeViewport = tester.getRect(
      find.byKey(const Key('sortie-map-route-viewport')),
    );

    expect((cover.width - routeViewport.width).abs(), lessThan(1));
    expect((cover.left - routeViewport.left).abs(), lessThan(1));
    expect((cover.right - routeViewport.right).abs(), lessThan(1));
  });

  testWidgets('map identity and difficulty remain prominent in compact mode', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(844, 390));

    final identity = tester.widget<Text>(
      find.byKey(const Key('sortie-map-identity')),
    );
    final difficulty = tester.widget<Text>(
      find.byKey(const Key('sortie-map-difficulty')),
    );

    expect(identity.style?.fontSize, greaterThanOrEqualTo(14));
    expect(difficulty.style?.fontSize, greaterThanOrEqualTo(14));
  });

  testWidgets('node controls meet touch and semantics requirements', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(796, 302));

    final nodeButton = find.byKey(const Key('sortie-map-node-A'));
    final nodeVisual = find.byKey(const Key('sortie-map-node-visual-A'));
    expect(tester.getSize(nodeButton).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(nodeButton).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(nodeVisual), const Size(32, 32));
    expect(
      tester.widget<Material>(nodeVisual).color,
      AppSegmentedStyle.selectedBackground(tester.element(nodeVisual)),
    );
    final nodeLabel = tester.widget<Text>(
      find.descendant(of: nodeVisual, matching: find.text('A')),
    );
    expect(
      nodeLabel.style?.color,
      AppSegmentedStyle.foreground(tester.element(nodeVisual), true),
    );
    final nextVisual = tester.getRect(
      find.byKey(const Key('sortie-map-node-visual-基地空袭')),
    );
    expect(nextVisual.left - tester.getRect(nodeVisual).right, lessThan(14));
    expect(
      tester.getSemantics(nodeButton),
      matchesSemantics(
        label: 'A BOSS',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('long node labels scale inside the fixed circular control', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(844, 390));

    final visual = find.byKey(const Key('sortie-map-node-visual-基地空袭'));
    expect(
      find.descendant(of: visual, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(tester.getSize(visual), const Size(32, 32));
    expect(tester.takeException(), isNull);
  });

  testWidgets('formation metadata wraps inside its card without overflow', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1240, 760));

    expect(find.text('配置 1'), findsNothing);
    expect(find.text('阵型 単縦陣'), findsNothing);
    expect(find.text('単縦陣'), findsOneWidget);
    expect(find.text('经验 30'), findsOneWidget);
    expect(find.text('斩杀'), findsOneWidget);
    expect(find.text('ボス'), findsNothing);
    expect(find.text('連合艦隊(6+6)'), findsNothing);
    expect(find.text('最終形態'), findsNothing);
    final formation = tester.getRect(
      find.byKey(const Key('sortie-map-formation-pill-1')),
    );
    final experience = tester.getRect(
      find.byKey(const Key('sortie-map-experience-pill-1')),
    );
    expect((formation.top - experience.top).abs(), lessThan(1));
    final finalPill = tester.getRect(
      find.byKey(const Key('sortie-map-final-pill-2')),
    );
    final finalFormation = tester.getRect(
      find.byKey(const Key('sortie-map-formation-pill-2')),
    );
    expect((finalPill.top - finalFormation.top).abs(), lessThan(1));
    expect(find.text('经验不明'), findsOneWidget);
    expect(find.text('wiki未提供经验值'), findsNothing);

    final airPower = find.byKey(
      const Key('sortie-map-air-power-summary-pill-2'),
    );
    expect(find.text('制空值27（优41/确81）'), findsOneWidget);
    expect(find.text('制空值 27'), findsNothing);
    expect(find.text('空优值 41'), findsNothing);
    expect(find.text('空确值 81'), findsNothing);
    for (final key in const [
      'sortie-map-air-power-pill-1',
      'sortie-map-air-superiority-pill-1',
      'sortie-map-air-supremacy-pill-1',
    ]) {
      expect(find.byKey(Key(key)), findsNothing);
    }
    expect(tester.widget<MetaChip>(airPower).color, const Color(0xff70c7bc));
    final card = tester.getRect(
      find.byKey(const Key('sortie-map-formation-2')),
    );
    final firstPill = tester.getRect(
      find.byKey(const Key('sortie-map-formation-pill-2')),
    );
    expect(tester.getRect(airPower).top, greaterThan(firstPill.top));
    for (final pill in [finalFormation, finalPill, tester.getRect(airPower)]) {
      expect(pill.right, lessThanOrEqualTo(card.right));
    }
  });

  testWidgets('combined formations render main and escort fleet headings', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1240, 760));

    for (final label in const ['敌方主力舰队', '敌方伴随舰队', '攻略后']) {
      final heading = tester.widget<Text>(find.text(label));
      expect(heading.style?.color, const Color(0xffeef6f8));
      expect(heading.style?.fontWeight, FontWeight.w800);
    }
    final clearAfter = tester.getRect(find.text('攻略后'));
    final firstShip = tester.getRect(
      find.byKey(const Key('sortie-map-enemy-tile-1-0-0')),
    );
    expect(clearAfter.bottom, lessThan(firstShip.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('enemy entries use compact banner portraits', (tester) async {
    await _pumpAt(tester, const Size(1240, 760), state: _portraitState);

    final portraitFinder = find.byKey(
      const Key('sortie-map-enemy-portrait-1-0-0'),
    );
    expect(portraitFinder, findsOneWidget);
    final portrait = tester.widget<ShipPortrait>(portraitFinder);
    expect(portrait.ship?.id, 1501);
    expect(portrait.resourceType, ShipPortraitResourceType.banner);
    expect(portrait.width, 48);
    expect(portrait.height, 22);
  });

  testWidgets('missing enemy master data keeps placeholder and name', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1240, 760));

    final portrait = tester.widget<ShipPortrait>(
      find.byKey(const Key('sortie-map-enemy-portrait-1-0-0')),
    );
    expect(portrait.ship, isNull);
    expect(find.text('驱逐イ级'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('sortie-map-enemy-tile-1-0-0')),
        matching: find.byIcon(Icons.directions_boat_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('enemy entries reflow from one to two columns by card width', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(844, 390), state: _portraitState);
    final narrowFirst = tester.getRect(
      find.byKey(const Key('sortie-map-enemy-tile-1-0-0')),
    );
    final narrowSecond = tester.getRect(
      find.byKey(const Key('sortie-map-enemy-tile-1-0-1')),
    );
    expect((narrowFirst.left - narrowSecond.left).abs(), lessThan(1));
    expect(narrowSecond.top, greaterThan(narrowFirst.top));

    await _pumpAt(tester, const Size(1240, 760), state: _portraitState);
    final wideFirst = tester.getRect(
      find.byKey(const Key('sortie-map-enemy-tile-1-0-0')),
    );
    final wideSecond = tester.getRect(
      find.byKey(const Key('sortie-map-enemy-tile-1-0-1')),
    );
    expect((wideFirst.top - wideSecond.top).abs(), lessThan(1));
    expect(wideSecond.left, greaterThan(wideFirst.right));
  });

  testWidgets(
    'panel headings match enemy title emphasis and footer credits KCWiki',
    (tester) async {
      await _pumpAt(tester, const Size(844, 390));

      for (final label in const ['海域选择', '路线图']) {
        final heading = tester.widget<Text>(find.text(label));
        expect(heading.style?.color, const Color(0xffeef6f8));
        expect(heading.style?.fontSize, 13);
        expect(heading.style?.fontWeight, FontWeight.w800);
      }
      expect(find.byKey(const Key('sortie-map-attribution')), findsOneWidget);
      expect(find.textContaining('kcwiki.cn'), findsOneWidget);
    },
  );

  testWidgets('enemy fleet title carries separate point and battle badges', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1240, 760));

    expect(find.text('A · 节点信息'), findsNothing);
    final bossName = tester.getRect(find.text('敵主力艦隊'));
    final pointBadge = find.byKey(const Key('sortie-map-point-type-badge'));
    final battleBadge = find.byKey(const Key('sortie-map-battle-type-badge'));
    expect(
      find.descendant(of: pointBadge, matching: find.text('BOSS')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: battleBadge, matching: find.text('通常戦闘')),
      findsOneWidget,
    );
    expect(tester.getRect(pointBadge).left, greaterThan(bossName.right));
    expect(
      tester.getRect(battleBadge).left,
      greaterThan(tester.getRect(pointBadge).right),
    );
    final bossDecoration = tester.widget<Container>(pointBadge).decoration;
    expect(
      (bossDecoration as BoxDecoration).borderRadius,
      BorderRadius.circular(8),
    );

    await tester.tap(find.byKey(const Key('sortie-map-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-2 南西諸島沖').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sortie-map-node-C')));
    await tester.pump();

    expect(find.text('敵前衛艦隊'), findsOneWidget);
    expect(
      find.descendant(of: pointBadge, matching: find.text('通常')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: battleBadge, matching: find.text('通常戦闘')),
      findsOneWidget,
    );
  });

  testWidgets('every boss node in a multi-boss map shows a BOSS badge', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1240, 760));
    await tester.tap(find.byKey(const Key('sortie-map-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-2 南西諸島沖').last);
    await tester.pumpAndSettle();

    for (final point in const ['D', 'E']) {
      await tester.tap(find.byKey(Key('sortie-map-node-$point')));
      await tester.pump();
      final pointBadge = find.byKey(const Key('sortie-map-point-type-badge'));
      expect(
        find.descendant(of: pointBadge, matching: find.text('BOSS')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pointBadge, matching: find.text('ボス')),
        findsNothing,
      );
    }
  });

  testWidgets(
    'Japanese attribution is reachable at the bottom on short and portrait phones',
    (tester) async {
      await _pumpAt(tester, const Size(796, 270), locale: const Locale('ja'));

      var footer = find.byKey(const Key('sortie-map-attribution'));
      expect(tester.getRect(footer).top, greaterThanOrEqualTo(270));
      await tester.ensureVisible(footer);
      await tester.pumpAndSettle();
      var footerRect = tester.getRect(footer);
      expect(footerRect.top, greaterThanOrEqualTo(0));
      expect(footerRect.bottom, lessThanOrEqualTo(270));
      expect(tester.takeException(), isNull);

      await _pumpAt(tester, const Size(390, 844), locale: const Locale('ja'));
      footer = find.byKey(const Key('sortie-map-attribution'));
      await tester.scrollUntilVisible(
        footer,
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('sortie-map-portrait-layout')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      footerRect = tester.getRect(footer);
      expect(footerRect.top, greaterThanOrEqualTo(0));
      expect(footerRect.bottom, lessThanOrEqualTo(844));
      expect(find.textContaining('kcwiki.cn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('attribution follows portrait content to the bottom', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(390, 844));

    final footer = find.byKey(const Key('sortie-map-attribution'));
    expect(footer, findsNothing);

    await tester.scrollUntilVisible(
      footer,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('sortie-map-portrait-layout')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(tester.getRect(footer).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(footer).bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(700, 1144), Size(900, 840)]) {
    testWidgets('attribution sits at the bottom when content fits $size', (
      tester,
    ) async {
      await _pumpAt(tester, size, catalog: _shortCatalog);

      final footer = tester.getRect(
        find.byKey(const Key('sortie-map-attribution')),
      );
      final detail = tester.getRect(find.byKey(const Key('sortie-map-detail')));
      expect(footer.bottom, closeTo(size.height - 4, 1));
      expect(footer.top, greaterThan(detail.bottom));
      expect(tester.takeException(), isNull);
    });
  }

  for (final (locale, scale) in const [
    (Locale('ja'), 2.0),
    (Locale('ja'), 3.0),
    (Locale('zh', 'TW'), 3.0),
  ]) {
    testWidgets('attribution fits $locale at $scale text scale', (
      tester,
    ) async {
      await _pumpAt(
        tester,
        const Size(320, 1200),
        locale: locale,
        catalog: _shortCatalog,
        textScaler: TextScaler.linear(scale),
      );

      final footer = tester.getRect(
        find.byKey(const Key('sortie-map-attribution')),
      );
      final text = tester.widget<Text>(
        find.byKey(const Key('sortie-map-attribution')),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(const Key('sortie-map-attribution')),
      );
      expect(
        paragraph.getMaxIntrinsicHeight(footer.width),
        lessThanOrEqualTo(footer.height),
      );
      expect(footer.bottom, lessThanOrEqualTo(1200));
      expect(text.data, contains('kcwiki.cn'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('attribution crosses the fit boundary without extra scrolling', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(390, 1200), catalog: _shortCatalog);

    final contentBottom =
        tester.getRect(find.byKey(const Key('sortie-map-detail'))).bottom + 10;
    final fitHeight = contentBottom + 22;
    final footer = find.byKey(const Key('sortie-map-attribution'));
    final scrollable = find
        .descendant(
          of: find.byKey(const Key('sortie-map-portrait-layout')),
          matching: find.byType(Scrollable),
        )
        .first;

    tester.view.physicalSize = Size(390, fitHeight + 1);
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      0,
    );
    expect(tester.getRect(footer).bottom, closeTo(fitHeight - 3, 1));

    tester.view.physicalSize = Size(390, fitHeight - 1);
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
    await tester.drag(scrollable, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(tester.getRect(footer).bottom, lessThanOrEqualTo(fitHeight - 1));

    tester.view.physicalSize = const Size(390, 1200);
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
    expect(tester.getRect(footer).bottom, closeTo(1196, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short landscape can reach attribution by dragging a panel', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(796, 270));

    final scrollable = find
        .descendant(
          of: find.byKey(const Key('sortie-map-wide-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
    for (var attempt = 0; attempt < 12; attempt++) {
      await tester.drag(
        find.byKey(const Key('sortie-map-detail')),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      if (tester.state<ScrollableState>(scrollable).position.pixels > 0) break;
    }
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      greaterThan(0),
    );
    expect(
      tester.getRect(find.byKey(const Key('sortie-map-attribution'))).bottom,
      lessThanOrEqualTo(270),
    );
    for (var attempt = 0; attempt < 12; attempt++) {
      await tester.drag(
        find.byKey(const Key('sortie-map-detail')),
        const Offset(0, 220),
      );
      await tester.pumpAndSettle();
      if (tester.state<ScrollableState>(scrollable).position.pixels == 0) break;
    }
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet attribution sits at bottom when map fits', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1512, 850));

    final footer = find.byKey(const Key('sortie-map-attribution'));
    expect(tester.getRect(footer).bottom, closeTo(846, 1));
    expect(find.byKey(const Key('sortie-map-tablet-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HD landscape uses a spacious three-column workspace', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1872, 988));

    final overview = tester.getRect(
      find.byKey(const Key('sortie-map-overview')),
    );
    final route = tester.getRect(find.byKey(const Key('sortie-map-route')));
    final detail = tester.getRect(find.byKey(const Key('sortie-map-detail')));
    expect(find.byKey(const Key('sortie-map-wide-layout')), findsOneWidget);
    expect(overview.right, lessThan(route.left));
    expect(route.right, lessThan(detail.left));
    expect(route.width, greaterThan(overview.width));
    expect(
      tester.getRect(find.byKey(const Key('sortie-map-attribution'))).bottom,
      closeTo(984, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait stacks full overview above route and detail', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(390, 844));

    expect(find.byKey(const Key('sortie-map-portrait-layout')), findsOneWidget);
    final overview = find.byKey(const Key('sortie-map-overview'));
    expect(overview, findsOneWidget);
    expect(
      find.descendant(
        of: overview,
        matching: find.byKey(const Key('sortie-map-cover')),
      ),
      findsOneWidget,
    );
    expect(find.text('1-1 鎮守府正面海域'), findsWidgets);
    expect(find.text('难度：★'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('extra-wide operation covers are never cropped', (tester) async {
    await _pumpAt(tester, const Size(796, 302));

    final coverImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('sortie-map-cover')),
        matching: find.byType(Image),
      ),
    );
    expect(coverImage.fit, BoxFit.contain);
  });

  testWidgets('HD portrait pairs overview and route above full-width detail', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1080, 1828));

    final overview = tester.getRect(
      find.byKey(const Key('sortie-map-overview')),
    );
    final route = tester.getRect(find.byKey(const Key('sortie-map-route')));
    final detail = tester.getRect(find.byKey(const Key('sortie-map-detail')));
    expect(
      find.byKey(const Key('sortie-map-wide-portrait-layout')),
      findsOneWidget,
    );
    expect(overview.right, lessThan(route.left));
    expect((overview.top - route.top).abs(), lessThan(1));
    expect((overview.height - route.height).abs(), lessThan(1));
    expect(route.height, lessThan(600));
    expect(detail.top, greaterThan(overview.bottom));
    expect(detail.width, greaterThan(route.width));
    final firstCard = tester.getRect(
      find.byKey(const Key('sortie-map-formation-1')),
    );
    final secondCard = tester.getRect(
      find.byKey(const Key('sortie-map-formation-2')),
    );
    expect((firstCard.top - secondCard.top).abs(), lessThan(1));
    expect(firstCard.right, lessThan(secondCard.left));
    expect((firstCard.bottom - secondCard.bottom).abs(), lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('map and node selections update the displayed information', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1240, 760));

    expect(find.byKey(const ValueKey('sortie-map-viewer-1-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sortie-map-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-2 南西諸島沖').last);
    await tester.pumpAndSettle();

    expect(find.text('1-2 南西諸島沖'), findsWidgets);
    expect(find.text('难度：★★'), findsOneWidget);
    expect(find.byKey(const Key('sortie-map-node-D')), findsOneWidget);
    expect(find.byKey(const ValueKey('sortie-map-viewer-1-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('sortie-map-viewer-1-1')), findsNothing);

    await tester.tap(find.byKey(const Key('sortie-map-node-D')));
    await tester.pump();
    expect(find.text('敵主力艦隊'), findsOneWidget);
    expect(find.text('轻巡ホ级'), findsOneWidget);
    expect(find.text('制空值12（优18/确36）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restores map and node selection and defaults a new map to A', (
    tester,
  ) async {
    final store = _MemorySortieMapSelectionStore();
    await _pumpAt(tester, const Size(1240, 760), selectionStore: store);

    await tester.tap(find.byKey(const Key('sortie-map-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-2 南西諸島沖').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Material>(find.byKey(const Key('sortie-map-node-visual-A')))
          .color,
      AppSegmentedStyle.selectedBackground(
        tester.element(find.byKey(const Key('sortie-map-node-visual-A'))),
      ),
    );

    await tester.tap(find.byKey(const Key('sortie-map-node-D')));
    await tester.pump();
    expect(
      store.selection,
      const SortieMapSelection(mapId: '1-2', nodePoint: 'D'),
    );

    await _pumpAt(tester, const Size(1240, 760), selectionStore: store);
    expect(find.text('1-2 南西諸島沖'), findsWidgets);
    expect(
      tester
          .widget<Material>(find.byKey(const Key('sortie-map-node-visual-D')))
          .color,
      AppSegmentedStyle.selectedBackground(
        tester.element(find.byKey(const Key('sortie-map-node-visual-D'))),
      ),
    );
  });

  testWidgets('late selection restore updates the dropdown label', (
    tester,
  ) async {
    final store = _DelayedSortieMapSelectionStore();
    await _pumpAt(tester, const Size(1240, 760), selectionStore: store);

    final selector = find.byKey(const Key('sortie-map-selector'));
    expect(
      find.descendant(of: selector, matching: find.text('1-1 鎮守府正面海域')),
      findsOneWidget,
    );

    store.restored.complete(
      const SortieMapSelection(mapId: '1-2', nodePoint: 'D'),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: selector, matching: find.text('1-2 南西諸島沖')),
      findsOneWidget,
    );
  });

  testWidgets('missing saved map cannot leak its node into the fallback map', (
    tester,
  ) async {
    final store = _MemorySortieMapSelectionStore(
      const SortieMapSelection(mapId: 'removed-map', nodePoint: '基地空袭'),
    );
    await _pumpAt(tester, const Size(1240, 760), selectionStore: store);

    expect(
      tester
          .widget<Material>(find.byKey(const Key('sortie-map-node-visual-A')))
          .color,
      AppSegmentedStyle.selectedBackground(
        tester.element(find.byKey(const Key('sortie-map-node-visual-A'))),
      ),
    );
  });

  testWidgets('missing saved node falls back to A on a valid map', (
    tester,
  ) async {
    final store = _MemorySortieMapSelectionStore(
      const SortieMapSelection(mapId: '1-2', nodePoint: 'removed-node'),
    );
    await _pumpAt(tester, const Size(1240, 760), selectionStore: store);

    expect(
      tester
          .widget<Material>(find.byKey(const Key('sortie-map-node-visual-A')))
          .color,
      AppSegmentedStyle.selectedBackground(
        tester.element(find.byKey(const Key('sortie-map-node-visual-A'))),
      ),
    );
  });

  testWidgets('maps without A fall back to their first node', (tester) async {
    final store = _MemorySortieMapSelectionStore(
      const SortieMapSelection(mapId: 'event', nodePoint: 'removed-node'),
    );
    await _pumpAt(
      tester,
      const Size(1240, 760),
      selectionStore: store,
      catalog: _catalogWithoutA,
    );

    expect(
      tester
          .widget<Material>(find.byKey(const Key('sortie-map-node-visual-X')))
          .color,
      AppSegmentedStyle.selectedBackground(
        tester.element(find.byKey(const Key('sortie-map-node-visual-X'))),
      ),
    );
  });

  testWidgets('resource nodes do not show blank enemy configurations', (
    tester,
  ) async {
    await _pumpAt(tester, const Size(1240, 760));
    await tester.tap(find.byKey(const Key('sortie-map-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-2 南西諸島沖').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sortie-map-node-B')));
    await tester.pump();

    expect(
      find.byKey(const Key('sortie-map-reward-icon-01-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('sortie-map-reward-icon-04-1')),
      findsOneWidget,
    );
    expect(find.textContaining('燃料'), findsNothing);
    expect(find.textContaining('ボーキサイト'), findsNothing);
    expect(find.textContaining('弹药'), findsNothing);
    expect(find.textContaining('高速建造材'), findsNothing);
    final rewardText = tester
        .widget<RichText>(find.byKey(const Key('sortie-map-resource-reward')))
        .text
        .toPlainText();
    expect(rewardText, contains('+40'));
    expect(rewardText, contains('+20'));
    expect(rewardText, isNot(contains('5刻み')));
    expect(rewardText, isNot(contains('ドラム缶')));
    expect(rewardText, isNot(contains('大発系')));
    expect(find.text('資源'), findsNWidgets(2));
    expect(find.text('此节点没有敌方配置'), findsOneWidget);
    expect(find.text('配置 1'), findsNothing);
  });

  testWidgets('Japanese UI uses Japanese enemy names', (tester) async {
    await _pumpAt(tester, const Size(1240, 760), locale: const Locale('ja'));
    await tester.tap(find.byKey(const Key('sortie-map-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-2 南西諸島沖').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sortie-map-node-D')));
    await tester.pump();

    expect(find.text('軽巡ホ級'), findsOneWidget);
    expect(find.text('轻巡ホ级'), findsNothing);
  });

  testWidgets('catalog load failures can be retried in place', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SortieMapQueryPage(
            catalogLoader: () async {
              attempts++;
              if (attempts == 1) throw StateError('test failure');
              return _catalog;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('海域资料加载失败'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sortie-map-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const Key('sortie-map-overview')), findsOneWidget);
  });

  testWidgets('catalog loading waits until the page becomes visible', (
    tester,
  ) async {
    var attempts = 0;
    Future<SortieMapCatalogData> loader() async {
      attempts++;
      return _catalog;
    }

    Widget app({required bool visible}) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SortieMapQueryPage(visible: visible, catalogLoader: loader),
      ),
    );

    await tester.pumpWidget(app(visible: false));
    await tester.pump();
    expect(attempts, 0);

    await tester.pumpWidget(app(visible: true));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.byKey(const Key('sortie-map-overview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sortie-map-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-2 南西諸島沖').last);
    await tester.pumpAndSettle();
    expect(find.text('难度：★★'), findsOneWidget);

    await tester.pumpWidget(app(visible: false));
    await tester.pump();
    await tester.pumpWidget(app(visible: true));
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(find.text('难度：★★'), findsOneWidget);
    expect(find.byKey(const ValueKey('sortie-map-viewer-1-2')), findsOneWidget);
  });

  for (final rotate in [false, true]) {
    testWidgets(
      'retains route transform and enemy details after ${rotate ? 'rotation' : 'hiding'}',
      (tester) async {
        const landscape = Size(900, 400);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = landscape;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final selectionStore = _MemorySortieMapSelectionStore();
        Future<SortieMapCatalogData> loader() async => _catalog;

        Widget app({required bool visible}) => MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SortieMapQueryPage(
              visible: visible,
              catalogLoader: loader,
              selectionStore: selectionStore,
            ),
          ),
        );

        await tester.pumpWidget(app(visible: true));
        await tester.pumpAndSettle();

        final viewer = find.byKey(const ValueKey('sortie-map-viewer-1-1'));
        final transform = find
            .descendant(of: viewer, matching: find.byType(Transform))
            .first;
        final detailScroll = find
            .descendant(
              of: find.byKey(const Key('sortie-map-detail')),
              matching: find.byType(Scrollable),
            )
            .first;
        ScrollPosition detailPosition() =>
            tester.state<ScrollableState>(detailScroll).position;

        await tester.sendEventToBinding(
          PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            position: tester.getCenter(viewer),
            scrollDelta: const Offset(0, -120),
          ),
        );
        await tester.pumpAndSettle();
        final savedTransform = tester.widget<Transform>(transform).transform;
        expect(savedTransform.getMaxScaleOnAxis(), greaterThan(1));
        expect(savedTransform.getTranslation().length, greaterThan(0));
        final savedOffset = detailPosition().maxScrollExtent;
        expect(savedOffset, greaterThan(0));
        detailPosition().jumpTo(savedOffset);
        await tester.pumpAndSettle();

        if (rotate) {
          tester.view.physicalSize = const Size(430, 844);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('sortie-map-portrait-layout')),
            findsOneWidget,
          );
          expect(tester.widget<Transform>(transform).transform, savedTransform);
          tester.view.physicalSize = landscape;
        } else {
          await tester.pumpWidget(app(visible: false));
          await tester.pumpAndSettle();
          expect(viewer, findsNothing);
          await tester.pumpWidget(app(visible: true));
        }
        await tester.pumpAndSettle();

        expect(tester.widget<Transform>(transform).transform, savedTransform);
        expect(detailPosition().pixels, closeTo(savedOffset, .1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size, {
  Locale locale = const Locale('zh'),
  SortieMapSelectionStore? selectionStore,
  SortieMapCatalogData catalog = _catalog,
  GameState state = const GameState(),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SortieMapQueryPage(
          state: state,
          catalogLoader: () async => catalog,
          selectionStore: selectionStore,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _shortCatalog = SortieMapCatalogData(
  version: 1,
  source: 'test',
  maps: [
    SortieMapInfo(
      id: '1-1',
      nameJa: '鎮守府正面海域',
      difficulty: 1,
      coverAsset: 'missing-cover.png',
      mapAsset: 'missing-map.png',
      mapAspectRatio: 2,
      source: null,
      nodes: [],
    ),
  ],
);

const _catalog = SortieMapCatalogData(
  version: 1,
  source: 'test',
  maps: [
    SortieMapInfo(
      id: '1-1',
      nameJa: '鎮守府正面海域',
      difficulty: 1,
      coverAsset: 'missing-cover-1.png',
      mapAsset: 'missing-map-1.png',
      mapAspectRatio: 2,
      source: null,
      nodes: [
        SortieMapNode(
          point: 'A',
          kind: 'boss',
          typeLabel: 'ボス',
          battleTypeLabel: '通常戦闘',
          nameJa: '敵主力艦隊 クリア後の',
          reward: null,
          formations: [
            EnemyFormation(
              variant: 1,
              isFinal: false,
              formation: '単縦陣',
              experience: 30,
              airPower: null,
              fleetGroups: [
                [
                  EnemyShipEntry(id: 1501, nameJa: '駆逐イ級', nameZh: '驱逐イ级'),
                  EnemyShipEntry(id: 1503, nameJa: '駆逐ハ級', nameZh: '驱逐ハ级'),
                ],
                [EnemyShipEntry(id: 1502, nameJa: '駆逐ロ級', nameZh: '驱逐ロ级')],
              ],
              note: '連合艦隊(6+6)；ボス',
            ),
            EnemyFormation(
              variant: 2,
              isFinal: true,
              formation: '複縦陣',
              experience: null,
              airPower: 27,
              airSuperiority: 41,
              airSupremacy: 81,
              fleetGroups: [
                [EnemyShipEntry(id: 1502, nameJa: '駆逐ロ級', nameZh: '驱逐ロ级')],
              ],
              note: 'EXP不明；最終形態；ボス',
            ),
          ],
        ),
        SortieMapNode(
          point: '基地空袭',
          kind: 'air_raid',
          typeLabel: '空襲',
          battleTypeLabel: '空襲戦',
          nameJa: null,
          reward: null,
          formations: [],
        ),
      ],
    ),
    SortieMapInfo(
      id: '1-2',
      nameJa: '南西諸島沖',
      difficulty: 2,
      coverAsset: 'missing-cover-2.png',
      mapAsset: 'missing-map-2.png',
      source: null,
      nodes: [
        SortieMapNode(
          point: 'A',
          kind: 'start',
          typeLabel: '通常',
          battleTypeLabel: '戦闘なし',
          nameJa: null,
          reward: null,
          formations: [],
        ),
        SortieMapNode(
          point: 'B',
          kind: 'resource',
          typeLabel: '資源',
          battleTypeLabel: '資源',
          nameJa: null,
          reward: '燃料+40＆ボーキサイト+20:ドラム缶(+2) 大発系*8(+3)',
          formations: [
            EnemyFormation(
              variant: 1,
              isFinal: false,
              formation: null,
              experience: null,
              airPower: null,
              fleetGroups: [[]],
              note: null,
            ),
          ],
        ),
        SortieMapNode(
          point: 'C',
          kind: 'battle',
          typeLabel: '通常',
          battleTypeLabel: '通常戦闘',
          nameJa: '敵前衛艦隊',
          reward: null,
          formations: [
            EnemyFormation(
              variant: 1,
              isFinal: false,
              formation: '単縦陣',
              experience: 35,
              airPower: null,
              fleetGroups: [
                [EnemyShipEntry(id: 1501, nameJa: '駆逐イ級', nameZh: '驱逐イ级')],
              ],
              note: null,
            ),
          ],
        ),
        SortieMapNode(
          point: 'D',
          kind: 'boss',
          typeLabel: 'ボス',
          battleTypeLabel: '通常戦闘',
          nameJa: '敵主力艦隊',
          reward: null,
          formations: [
            EnemyFormation(
              variant: 1,
              isFinal: false,
              formation: '単縦陣',
              experience: 50,
              airPower: 12,
              airSuperiority: 18,
              airSupremacy: 36,
              fleetGroups: [
                [EnemyShipEntry(id: 1505, nameJa: '軽巡ホ級', nameZh: '轻巡ホ级')],
              ],
              note: null,
            ),
          ],
        ),
        SortieMapNode(
          point: 'E',
          kind: 'boss',
          typeLabel: 'ボス',
          battleTypeLabel: '夜戦',
          nameJa: '敵増援艦隊',
          reward: null,
          formations: [],
        ),
      ],
    ),
  ],
);

const _portraitState = GameState(
  masterShips: <int, MasterShip>{
    1501: MasterShip(
      id: 1501,
      name: '駆逐イ級',
      shipTypeId: 2,
      portraitVersion: '1',
    ),
    1502: MasterShip(
      id: 1502,
      name: '駆逐ロ級',
      shipTypeId: 2,
      portraitVersion: '1',
    ),
    1503: MasterShip(
      id: 1503,
      name: '駆逐ハ級',
      shipTypeId: 2,
      portraitVersion: '1',
    ),
  },
);

const _catalogWithoutA = SortieMapCatalogData(
  version: 1,
  source: 'test',
  maps: [
    SortieMapInfo(
      id: 'event',
      nameJa: '期間限定海域',
      difficulty: 1,
      coverAsset: 'missing-cover.png',
      mapAsset: 'missing-map.png',
      source: null,
      nodes: [
        SortieMapNode(
          point: 'X',
          kind: 'battle',
          typeLabel: '通常',
          battleTypeLabel: '通常戦闘',
          nameJa: '敵艦隊',
          reward: null,
          formations: [],
        ),
        SortieMapNode(
          point: 'Y',
          kind: 'boss',
          typeLabel: 'ボス',
          battleTypeLabel: '通常戦闘',
          nameJa: '敵主力艦隊',
          reward: null,
          formations: [],
        ),
      ],
    ),
  ],
);

final class _MemorySortieMapSelectionStore implements SortieMapSelectionStore {
  _MemorySortieMapSelectionStore([this.selection]);

  SortieMapSelection? selection;

  @override
  Future<SortieMapSelection?> load() async => selection;

  @override
  Future<void> save(SortieMapSelection value) async => selection = value;
}

final class _DelayedSortieMapSelectionStore implements SortieMapSelectionStore {
  final restored = Completer<SortieMapSelection?>();

  @override
  Future<SortieMapSelection?> load() => restored.future;

  @override
  Future<void> save(SortieMapSelection value) async {}
}
