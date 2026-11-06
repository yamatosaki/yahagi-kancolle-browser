import '../../theme/app_palette.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../battle/battle_pills.dart';
import '../../fleet/ship_portrait.dart';
import '../../game_state/game_state.dart';
import '../../localization/game_name_localizations.dart';
import '../../layout/adaptive_layout.dart';
import '../../widgets/app_segmented_style.dart';
import 'sortie_map_catalog.dart';
import 'sortie_map_catalog_controller.dart';
import 'enemy_catalog.dart';
import 'enemy_catalog_controller.dart';
import 'sortie_enemy_details.dart';
import 'sortie_map_models.dart';
import 'sortie_map_query_strings.dart';
import 'sortie_map_selection_store.dart';

typedef SortieMapCatalogLoader = Future<SortieMapCatalogData> Function();

class SortieMapQueryPage extends StatefulWidget {
  const SortieMapQueryPage({
    super.key,
    this.catalogLoader,
    this.catalogController,
    this.enemyCatalogController,
    this.selectionStore,
    this.visible = true,
    this.state = const GameState(),
  });

  final SortieMapCatalogLoader? catalogLoader;
  final SortieMapCatalogController? catalogController;
  final EnemyCatalogController? enemyCatalogController;
  final SortieMapSelectionStore? selectionStore;
  final bool visible;
  final GameState state;

  @override
  State<SortieMapQueryPage> createState() => _SortieMapQueryPageState();
}

class _SortieMapQueryPageState extends State<SortieMapQueryPage> {
  Future<SortieMapCatalogData>? _catalogFuture;
  String? _selectedMapId;
  String? _selectedNodePoint;
  late SortieMapSelectionStore _selectionStore;
  int _restoreGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selectionStore =
        widget.selectionStore ??
        const SharedPreferencesSortieMapSelectionStore();
    widget.catalogController?.addListener(_onCatalogChanged);
    widget.enemyCatalogController?.addListener(_onEnemyCatalogChanged);
    _restoreSelection();
    if (widget.visible) _catalogFuture = _loadCatalog();
  }

  @override
  void didUpdateWidget(covariant SortieMapQueryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalogController != widget.catalogController) {
      oldWidget.catalogController?.removeListener(_onCatalogChanged);
      widget.catalogController?.addListener(_onCatalogChanged);
      _onCatalogChanged();
    }
    if (oldWidget.enemyCatalogController != widget.enemyCatalogController) {
      oldWidget.enemyCatalogController?.removeListener(_onEnemyCatalogChanged);
      widget.enemyCatalogController?.addListener(_onEnemyCatalogChanged);
    }
    if (oldWidget.selectionStore != widget.selectionStore) {
      _selectionStore =
          widget.selectionStore ??
          const SharedPreferencesSortieMapSelectionStore();
      _restoreSelection();
    }
    if (oldWidget.catalogLoader != widget.catalogLoader) {
      _catalogFuture = widget.visible ? _loadCatalog() : null;
      _selectedMapId = null;
      _selectedNodePoint = null;
      _restoreSelection();
    } else if (widget.visible && _catalogFuture == null) {
      _catalogFuture = _loadCatalog();
    }
  }

  Future<SortieMapCatalogData> _loadCatalog() =>
      widget.catalogController != null
      ? Future<SortieMapCatalogData>.value(widget.catalogController!.data)
      : (widget.catalogLoader ?? SortieMapCatalog.loadAsset)();

  void _onCatalogChanged() {
    if (!mounted) return;
    setState(() => _catalogFuture = _loadCatalog());
  }

  void _onEnemyCatalogChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.catalogController?.removeListener(_onCatalogChanged);
    widget.enemyCatalogController?.removeListener(_onEnemyCatalogChanged);
    super.dispose();
  }

  Future<void> _restoreSelection() async {
    final generation = ++_restoreGeneration;
    final selection = await _selectionStore.load();
    if (!mounted || generation != _restoreGeneration || selection == null) {
      return;
    }
    setState(() {
      _selectedMapId = selection.mapId;
      _selectedNodePoint = selection.nodePoint;
    });
  }

  void _selectMap(SortieMapInfo map) {
    _restoreGeneration++;
    final node = _initialNode(map);
    setState(() {
      _selectedMapId = map.id;
      _selectedNodePoint = node?.point;
    });
    if (node != null) {
      unawaited(
        _selectionStore.save(
          SortieMapSelection(mapId: map.id, nodePoint: node.point),
        ),
      );
    }
  }

  void _selectNode(SortieMapInfo map, SortieMapNode node) {
    _restoreGeneration++;
    setState(() => _selectedNodePoint = node.point);
    unawaited(
      _selectionStore.save(
        SortieMapSelection(mapId: map.id, nodePoint: node.point),
      ),
    );
  }

  void _retryLoading() {
    final future = _loadCatalog();
    setState(() {
      _catalogFuture = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final strings = SortieMapQueryStrings.of(context);
    return ColoredBox(
      color: appColor(context, const Color(0xff091923)),
      child: FutureBuilder<SortieMapCatalogData>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _CenteredStatus(
              icon: Icons.error_outline,
              label: strings.loadFailed,
              actionLabel: strings.retry,
              onAction: _retryLoading,
            );
          }
          final catalog = snapshot.data;
          if (catalog == null) {
            return _CenteredStatus(
              icon: Icons.travel_explore,
              label: strings.loading,
            );
          }
          if (catalog.maps.isEmpty) {
            return _CenteredStatus(
              icon: Icons.map_outlined,
              label: strings.noNodes,
            );
          }
          return _buildCatalog(context, catalog, strings);
        },
      ),
    );
  }

  Widget _buildCatalog(
    BuildContext context,
    SortieMapCatalogData catalog,
    SortieMapQueryStrings strings,
  ) {
    SortieMapInfo? restoredMap;
    for (final candidate in catalog.maps) {
      if (candidate.id == _selectedMapId) {
        restoredMap = candidate;
        break;
      }
    }
    final map = restoredMap ?? catalog.maps.first;
    final node = restoredMap == null ? _initialNode(map) : _selectedNode(map);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final portrait = constraints.maxHeight > constraints.maxWidth;
        final nearSquareUnfolded =
            classifyAdaptiveWindow(
              Size(constraints.maxWidth, constraints.maxHeight),
            ) ==
            AdaptiveWindowClass.nearSquareLarge;
        final verticalWorkspace = portrait || nearSquareUnfolded;
        final widePortrait =
            nearSquareUnfolded || (portrait && constraints.maxWidth >= 720);
        final compact =
            constraints.maxWidth < 960 || constraints.maxHeight < 500;
        final tabletLandscape =
            !verticalWorkspace &&
            constraints.maxWidth >= 1100 &&
            constraints.maxHeight >= 700 &&
            constraints.maxWidth / constraints.maxHeight <= 1.8;
        final overview = _OverviewPanel(
          map: map,
          maps: catalog.maps,
          strings: strings,
          compact: compact,
          tabletStrip: tabletLandscape,
          onMapChanged: _selectMap,
          resolveCachedImage: widget.catalogController?.resolveCachedImage,
        );
        final route = _RoutePanel(
          map: map,
          selectedNode: node,
          strings: strings,
          compact: compact,
          onNodeChanged: (value) => _selectNode(map, value),
          resolveCachedImage: widget.catalogController?.resolveCachedImage,
        );
        final detail = _NodeDetailPanel(
          node: node,
          strings: strings,
          compact: compact,
          multiColumn: widePortrait,
          state: widget.state,
          enemyCatalog: widget.enemyCatalogController?.data,
        );

        if (widePortrait) {
          final gap = constraints.maxWidth >= 960 ? 14.0 : 10.0;
          final overviewWidth = (constraints.maxWidth * .29).clamp(
            220.0,
            310.0,
          );
          final routeWidth = constraints.maxWidth - gap * 3 - overviewWidth;
          final topHeight = _routePanelDesiredHeight(
            width: routeWidth,
            mapAspectRatio: map.mapAspectRatio,
            compact: compact,
            hasNodes: map.nodes.isNotEmpty,
            textScaler: textScaler,
          );
          return _scrollableContentWithAttribution(
            key: const Key('sortie-map-wide-portrait-layout'),
            strings: strings,
            content: Padding(
              padding: EdgeInsets.all(gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: topHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: overviewWidth, child: overview),
                        SizedBox(width: gap),
                        Expanded(child: route),
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                  detail,
                ],
              ),
            ),
          );
        }

        if (verticalWorkspace) {
          return _scrollableContentWithAttribution(
            key: const Key('sortie-map-portrait-layout'),
            strings: strings,
            content: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  overview,
                  const SizedBox(height: 10),
                  route,
                  const SizedBox(height: 10),
                  detail,
                ],
              ),
            ),
          );
        }

        if (tabletLandscape) {
          const outerPadding = 12.0;
          const gap = 12.0;
          const overviewHeight = 100.0;
          final availableHeight = constraints.maxHeight;
          final columnWidth = constraints.maxWidth - outerPadding * 2 - gap;
          final baseDetailWidth = (constraints.maxWidth * .27).clamp(
            290.0,
            390.0,
          );
          const panelPadding = 12.0;
          final panelChromeHeight = _routePanelDesiredHeight(
            width: panelPadding * 2,
            mapAspectRatio: map.mapAspectRatio,
            compact: false,
            hasNodes: map.nodes.isNotEmpty,
            textScaler: textScaler,
          );
          final routeHeight =
              availableHeight - outerPadding * 2 - overviewHeight - gap;
          final overviewWidth =
              ((routeHeight - panelChromeHeight) * map.mapAspectRatio +
                      panelPadding * 2)
                  .clamp(560.0, columnWidth - baseDetailWidth);
          final detailWidth = columnWidth - overviewWidth;
          final contentHeight =
              (outerPadding * 2 +
                      overviewHeight +
                      gap +
                      _routePanelDesiredHeight(
                        width: overviewWidth,
                        mapAspectRatio: map.mapAspectRatio,
                        compact: false,
                        hasNodes: map.nodes.isNotEmpty,
                        textScaler: textScaler,
                      ))
                  .clamp(0.0, availableHeight);
          return _scrollableContentWithAttribution(
            key: const Key('sortie-map-tablet-scroll'),
            strings: strings,
            content: SizedBox(
              height: contentHeight,
              child: Padding(
                padding: const EdgeInsets.all(outerPadding),
                child: Row(
                  key: const Key('sortie-map-tablet-layout'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: overviewWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: overviewHeight, child: overview),
                          const SizedBox(height: gap),
                          Expanded(child: route),
                        ],
                      ),
                    ),
                    const SizedBox(width: gap),
                    SizedBox(width: detailWidth, child: detail),
                  ],
                ),
              ),
            ),
          );
        }

        final availableHeight = constraints.maxHeight;
        final outerPadding = compact && availableHeight < 340
            ? 0.0
            : compact
            ? 8.0
            : 12.0;
        final overviewWidth = (constraints.maxWidth * .20).clamp(
          compact && availableHeight < 340
              ? 180.0
              : compact
              ? 170.0
              : 220.0,
          280.0,
        );
        final detailWidth = (constraints.maxWidth * .27).clamp(
          compact ? 215.0 : 290.0,
          390.0,
        );
        final gap = compact ? 8.0 : 12.0;
        final routeWidth =
            constraints.maxWidth -
            outerPadding * 2 -
            overviewWidth -
            detailWidth -
            gap * 2;
        final desiredPanelHeight = _routePanelDesiredHeight(
          width: routeWidth,
          mapAspectRatio: map.mapAspectRatio,
          compact: compact,
          hasNodes: map.nodes.isNotEmpty,
          textScaler: textScaler,
        );
        final contentHeight = (desiredPanelHeight + outerPadding * 2).clamp(
          0.0,
          availableHeight,
        );
        final sharedPanelHeight = desiredPanelHeight.clamp(
          0.0,
          contentHeight - outerPadding * 2,
        );
        return _scrollableContentWithAttribution(
          key: const Key('sortie-map-wide-scroll'),
          strings: strings,
          content: SizedBox(
            height: contentHeight,
            child: Padding(
              padding: EdgeInsets.all(outerPadding),
              child: Row(
                key: const Key('sortie-map-wide-layout'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: overviewWidth,
                    height: sharedPanelHeight,
                    child: overview,
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: SizedBox(height: sharedPanelHeight, child: route),
                  ),
                  SizedBox(width: gap),
                  SizedBox(
                    width: detailWidth,
                    height: sharedPanelHeight,
                    child: detail,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  SortieMapNode? _selectedNode(SortieMapInfo map) {
    for (final node in map.nodes) {
      if (node.point == _selectedNodePoint) return node;
    }
    return _initialNode(map);
  }

  SortieMapNode? _initialNode(SortieMapInfo map) {
    if (map.nodes.isEmpty) return null;
    for (final node in map.nodes) {
      if (node.point.toUpperCase() == 'A') return node;
    }
    return map.nodes.first;
  }
}

const double _attributionFooterHeight = 22;

Widget _scrollableContentWithAttribution({
  required Key key,
  required Widget content,
  required SortieMapQueryStrings strings,
}) {
  return CustomScrollView(
    key: key,
    slivers: [
      SliverToBoxAdapter(
        child: Builder(
          builder: (context) => NotificationListener<OverscrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis != Axis.vertical) return false;
              final outer = Scrollable.of(context).position;
              final target = (outer.pixels + notification.overscroll).clamp(
                outer.minScrollExtent,
                outer.maxScrollExtent,
              );
              if (target != outer.pixels) outer.jumpTo(target);
              return false;
            },
            child: content,
          ),
        ),
      ),
      SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: _attributionFooterHeight,
              ),
              child: _AttributionFooter(strings: strings),
            ),
          ],
        ),
      ),
    ],
  );
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({
    required this.map,
    required this.maps,
    required this.strings,
    required this.compact,
    required this.tabletStrip,
    required this.onMapChanged,
    this.resolveCachedImage,
  });

  final SortieMapInfo map;
  final List<SortieMapInfo> maps;
  final SortieMapQueryStrings strings;
  final bool compact;
  final bool tabletStrip;
  final ValueChanged<SortieMapInfo> onMapChanged;
  final File? Function(String)? resolveCachedImage;

  @override
  Widget build(BuildContext context) {
    if (tabletStrip) {
      return _Panel(
        key: const Key('sortie-map-overview'),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 270,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PanelHeading(strings.selectMap, compact: compact),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        barrierDismissible: false,
                        key: const Key('sortie-map-selector'),
                        initialValue: map.id,
                        isExpanded: true,
                        dropdownColor: appColor(context, Color(0xff102a39)),
                        iconEnabledColor: appColor(context, Color(0xffffc85a)),
                        style: TextStyle(
                          color: appColor(context, Color(0xffeef6f8)),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 11,
                          ),
                          enabledBorder: _selectorBorder.copyWith(
                            borderSide: _selectorBorder.borderSide.copyWith(
                              color: appColor(
                                context,
                                _selectorBorder.borderSide.color,
                              ),
                            ),
                          ),
                          focusedBorder: _selectorBorder.copyWith(
                            borderSide: BorderSide(
                              color: appColor(context, Color(0xffd8aa4d)),
                            ),
                          ),
                        ),
                        items: [
                          for (final item in maps)
                            DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${item.id} ${item.nameJa}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          if (id == null || id == map.id) return;
                          onMapChanged(
                            maps.firstWhere((item) => item.id == id),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: AspectRatio(
                    aspectRatio: 2.15,
                    child: ClipRRect(
                      key: const Key('sortie-map-cover'),
                      borderRadius: BorderRadius.circular(6),
                      child: ColoredBox(
                        color: appColor(context, Color(0xff07131b)),
                        child: _AssetImage(
                          asset: map.coverAsset,
                          file: resolveCachedImage?.call(map.coverAsset),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${map.id} ${map.nameJa}',
                        key: const Key('sortie-map-identity'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appTextStyle(
                          context,
                          TextStyle(
                            color: appColor(context, Color(0xffffdc88)),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${strings.difficulty}：${'★' * map.difficulty}',
                        key: const Key('sortie-map-difficulty'),
                        style: appTextStyle(
                          context,
                          TextStyle(
                            color: appColor(context, Color(0xffffdc88)),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final content = Padding(
      padding: EdgeInsets.all(compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelHeading(strings.selectMap, compact: compact),
          SizedBox(height: compact ? 6 : 10),
          DropdownButtonFormField<String>(
            barrierDismissible: false,
            key: const Key('sortie-map-selector'),
            initialValue: map.id,
            isExpanded: true,
            dropdownColor: appColor(context, Color(0xff102a39)),
            iconEnabledColor: appColor(context, Color(0xffffc85a)),
            style: TextStyle(
              color: appColor(context, Color(0xffeef6f8)),
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 9 : 11,
              ),
              enabledBorder: _selectorBorder.copyWith(
                borderSide: _selectorBorder.borderSide.copyWith(
                  color: appColor(context, _selectorBorder.borderSide.color),
                ),
              ),
              focusedBorder: _selectorBorder.copyWith(
                borderSide: BorderSide(
                  color: appColor(context, Color(0xffd8aa4d)),
                ),
              ),
            ),
            items: [
              for (final item in maps)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(
                    '${item.id} ${item.nameJa}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              if (id == null || id == map.id) return;
              onMapChanged(maps.firstWhere((item) => item.id == id));
            },
          ),
          SizedBox(height: compact ? 7 : 11),
          AspectRatio(
            aspectRatio: 2.15,
            child: ClipRRect(
              key: const Key('sortie-map-cover'),
              borderRadius: BorderRadius.circular(6),
              child: ColoredBox(
                color: appColor(context, Color(0xff07131b)),
                child: _AssetImage(
                  asset: map.coverAsset,
                  file: resolveCachedImage?.call(map.coverAsset),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 7 : 12),
          Text(
            '${map.id} ${map.nameJa}',
            key: const Key('sortie-map-identity'),
            style: appTextStyle(
              context,
              TextStyle(
                color: const Color(0xffffdc88),
                fontSize: compact ? 14 : 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${strings.difficulty}：${'★' * map.difficulty}',
            key: const Key('sortie-map-difficulty'),
            style: appTextStyle(
              context,
              TextStyle(
                color: const Color(0xffffdc88),
                fontSize: compact ? 14 : 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    return _Panel(
      key: const Key('sortie-map-overview'),
      child: SingleChildScrollView(child: content),
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({
    required this.map,
    required this.selectedNode,
    required this.strings,
    required this.compact,
    required this.onNodeChanged,
    this.resolveCachedImage,
  });

  final SortieMapInfo map;
  final SortieMapNode? selectedNode;
  final SortieMapQueryStrings strings;
  final bool compact;
  final ValueChanged<SortieMapNode> onNodeChanged;
  final File? Function(String)? resolveCachedImage;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final padding = compact ? 8.0 : 12.0;
      final gap = compact ? 6.0 : 10.0;
      final desiredHeight = _routePanelDesiredHeight(
        width: constraints.maxWidth,
        mapAspectRatio: map.mapAspectRatio,
        compact: compact,
        hasNodes: map.nodes.isNotEmpty,
        textScaler: MediaQuery.textScalerOf(context),
      );
      final panelHeight = desiredHeight.clamp(0.0, constraints.maxHeight);
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: double.infinity,
          height: panelHeight,
          child: _Panel(
            key: const Key('sortie-map-route'),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PanelHeading(strings.routeMap, compact: compact),
                  SizedBox(height: gap),
                  AspectRatio(
                    key: const Key('sortie-map-route-viewport'),
                    aspectRatio: map.mapAspectRatio,
                    child: PhysicalModel(
                      key: const Key('sortie-map-route-surface'),
                      color: appColor(context, Color(0xff07131b)),
                      shadowColor: appColor(context, Color(0xff000000)),
                      elevation: 5,
                      borderRadius: BorderRadius.circular(6),
                      clipBehavior: Clip.antiAlias,
                      child: InteractiveViewer(
                        key: ValueKey('sortie-map-viewer-${map.id}'),
                        minScale: 0.8,
                        maxScale: 4,
                        child: _AssetImage(
                          asset: map.mapAsset,
                          file: resolveCachedImage?.call(map.mapAsset),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  if (map.nodes.isEmpty)
                    Text(
                      strings.noNodes,
                      style: appTextStyle(
                        context,
                        TextStyle(color: appColor(context, Color(0xff8fa5b2))),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final node in map.nodes)
                            _NodeButton(
                              node: node,
                              selected: node.point == selectedNode?.point,
                              onTap: () => onNodeChanged(node),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

double _routePanelDesiredHeight({
  required double width,
  required double mapAspectRatio,
  required bool compact,
  required bool hasNodes,
  required TextScaler textScaler,
}) {
  final padding = compact ? 8.0 : 12.0;
  final gap = compact ? 6.0 : 10.0;
  final mapHeight = (width - padding * 2) / mapAspectRatio;
  final nodeHeight = hasNodes ? 44.0 : textScaler.scale(16);
  final headingHeight = textScaler.scale(compact ? 13 : 16);
  return padding * 2 + headingHeight + gap * 2 + mapHeight + nodeHeight;
}

class _NodeDetailPanel extends StatelessWidget {
  const _NodeDetailPanel({
    required this.node,
    required this.strings,
    required this.compact,
    required this.multiColumn,
    required this.state,
    required this.enemyCatalog,
  });

  final SortieMapNode? node;
  final SortieMapQueryStrings strings;
  final bool compact;
  final bool multiColumn;
  final GameState state;
  final EnemyCatalogData? enemyCatalog;

  @override
  Widget build(BuildContext context) {
    final visibleFormations = node?.formations
        .where((formation) => formation.hasShips)
        .toList();
    final reward = strings.sourceDetail(node?.reward);
    final formationCards = [
      for (final formation in visibleFormations ?? const <EnemyFormation>[])
        _FormationCard(
          key: Key('sortie-map-formation-${formation.variant}'),
          formation: formation,
          strings: strings,
          compact: compact,
          state: state,
          enemyCatalog: enemyCatalog,
          twoColumnShips: multiColumn || !compact,
        ),
    ];
    return _Panel(
      key: const Key('sortie-map-detail'),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 8 : 12),
        child: node == null
            ? Text(
                strings.noNodes,
                style: appTextStyle(
                  context,
                  TextStyle(color: appColor(context, Color(0xff8fa5b2))),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_fleetNameWithoutClearAfter(node!.nameJa)
                          case final fleetName?)
                        Text(
                          fleetName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: const Color(0xffeef6f8),
                              fontSize: compact ? 13 : 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      _NodeTypeBadge(
                        badgeKey: const Key('sortie-map-point-type-badge'),
                        label: node!.isBoss ? strings.boss : node!.typeLabel,
                        kind: node!.kind,
                      ),
                      _NodeTypeBadge(
                        badgeKey: const Key('sortie-map-battle-type-badge'),
                        label: node!.battleTypeLabel,
                        kind: 'battle',
                      ),
                    ],
                  ),
                  if (reward != null) ...[
                    const SizedBox(height: 7),
                    _ResourceRewardText(
                      node!.kind == 'resource'
                          ? _conciseResourceReward(reward)
                          : reward,
                    ),
                  ],
                  if (_hasClearAfterMarker(node!.nameJa)) ...[
                    const SizedBox(height: 7),
                    _FleetHeading(strings.clearAfter, compact: compact),
                  ],
                  SizedBox(height: compact ? 8 : 12),
                  if (formationCards.isEmpty)
                    Text(
                      strings.noEnemy,
                      style: appTextStyle(
                        context,
                        TextStyle(color: appColor(context, Color(0xff8fa5b2))),
                      ),
                    )
                  else if (multiColumn)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1260 ? 3 : 2;
                        const gap = 10.0;
                        final cardWidth =
                            (constraints.maxWidth - gap * (columns - 1)) /
                            columns;
                        return _EqualHeightFormationGrid(
                          columns: columns,
                          gap: gap,
                          cardWidth: cardWidth,
                          children: formationCards,
                        );
                      },
                    )
                  else
                    for (final card in formationCards) ...[
                      card,
                      SizedBox(height: compact ? 7 : 10),
                    ],
                ],
              ),
      ),
    );
  }
}

class _EqualHeightFormationGrid extends StatelessWidget {
  const _EqualHeightFormationGrid({
    required this.columns,
    required this.gap,
    required this.cardWidth,
    required this.children,
  });

  final int columns;
  final double gap;
  final double cardWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var start = 0; start < children.length; start += columns) ...[
        if (start > 0) SizedBox(height: gap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) SizedBox(width: gap),
                SizedBox(
                  width: cardWidth,
                  child: start + column < children.length
                      ? children[start + column]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ],
    ],
  );
}

class _ResourceRewardText extends StatelessWidget {
  const _ResourceRewardText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    var iconIndex = 0;
    for (final match in _rewardMaterialPattern.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: value.substring(cursor, match.start)));
      }
      final label = match.group(0)!;
      final assetId = _rewardMaterialIds[label]!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Image.asset(
              'assets/images/material/$assetId.png',
              key: Key('sortie-map-reward-icon-$assetId-${iconIndex++}'),
              width: 16,
              height: 16,
              filterQuality: FilterQuality.medium,
              semanticLabel: label,
            ),
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < value.length) {
      spans.add(TextSpan(text: value.substring(cursor)));
    }
    return RichText(
      key: const Key('sortie-map-resource-reward'),
      text: TextSpan(
        style: appTextStyle(
          context,
          TextStyle(color: appColor(context, Color(0xffdbe9ee)), fontSize: 12),
        ),
        children: spans,
      ),
    );
  }
}

const _rewardMaterialIds = <String, String>{
  '高速建造材': '05',
  '高速修复材': '06',
  '開發資材': '07',
  '开发资材': '07',
  '家具箱（小）': '10',
  '家具箱（中）': '11',
  '家具箱（大）': '12',
  '燃料': '01',
  '弹药': '02',
  '彈藥': '02',
  '钢材': '03',
  '鋼材': '03',
  'ボーキサイト': '04',
  'ボーキ': '04',
  '铝土': '04',
  '鋁土': '04',
  '铝材': '04',
  '鋁材': '04',
};

final _rewardMaterialPattern = RegExp(
  _rewardMaterialIds.keys.map(RegExp.escape).join('|'),
);

String _conciseResourceReward(String value) {
  final conditionStart = [value.indexOf(':'), value.indexOf('：')]
      .where((index) => index >= 0)
      .fold<int?>(null, (earliest, index) {
        if (earliest == null || index < earliest) return index;
        return earliest;
      });
  final withoutConditions = conditionStart == null
      ? value.trim()
      : value.substring(0, conditionStart).trim();
  return withoutConditions
      .replaceFirstMapped(
        RegExp(r'([0-9+?])\s*[（(].*$'),
        (match) => match.group(1)!,
      )
      .trim();
}

bool _isMissingExperienceNote(String note) =>
    const {'wiki未提供经验值', 'exp不明'}.contains(note.trim().toLowerCase());

const _redundantFormationNotes = <String>{'ボス', '最終形態', '連合艦隊(6+6)'};

String? _visibleFormationNote(String? value) {
  if (value == null) return null;
  final visibleParts = value
      .split(RegExp(r'[；;]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .where(
        (part) =>
            !_redundantFormationNotes.contains(part) &&
            !_isMissingExperienceNote(part),
      )
      .toList();
  return visibleParts.isEmpty ? null : visibleParts.join('；');
}

class _FormationCard extends StatelessWidget {
  const _FormationCard({
    super.key,
    required this.formation,
    required this.strings,
    required this.compact,
    required this.state,
    required this.enemyCatalog,
    required this.twoColumnShips,
  });

  final EnemyFormation formation;
  final SortieMapQueryStrings strings;
  final bool compact;
  final GameState state;
  final EnemyCatalogData? enemyCatalog;
  final bool twoColumnShips;

  @override
  Widget build(BuildContext context) {
    final formationValue = formation.formation;
    final metadata = <Widget>[
      if (formationValue != null)
        MetaChip(
          key: Key('sortie-map-formation-pill-${formation.variant}'),
          label: formationValue,
          color: const Color(0xffffc95c),
        ),
      MetaChip(
        key: Key('sortie-map-experience-pill-${formation.variant}'),
        label: formation.experience == null
            ? strings.experienceUnknown
            : '${strings.experience} ${formation.experience}',
        color: const Color(0xff70c7bc),
      ),
      if (formation.isFinal)
        MetaChip(
          key: Key('sortie-map-final-pill-${formation.variant}'),
          label: strings.finalConfiguration,
          color: const Color(0xffff6f68),
        ),
      if (formation.airPower != null ||
          formation.airSuperiority != null ||
          formation.airSupremacy != null)
        MetaChip(
          key: Key('sortie-map-air-power-summary-pill-${formation.variant}'),
          label: strings.locale.languageCode == 'en'
              ? '${strings.airPower} ${formation.airPower ?? '—'} '
                    '(${strings.airSuperiorityShort} ${formation.airSuperiority ?? '—'} / '
                    '${strings.airSupremacyShort} ${formation.airSupremacy ?? '—'})'
              : '${strings.airPower}${formation.airPower ?? '—'}'
                    '（${strings.airSuperiorityShort}${formation.airSuperiority ?? '—'}'
                    '/${strings.airSupremacyShort}${formation.airSupremacy ?? '—'}）',
          color: const Color(0xff70c7bc),
        ),
    ];
    final note = strings.sourceDetail(_visibleFormationNote(formation.note));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appColor(context, const Color(0xff0b1d28)),
        border: Border.all(color: appColor(context, const Color(0xff284858))),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (metadata.isNotEmpty)
              Wrap(spacing: 5, runSpacing: 5, children: metadata),
            for (var index = 0; index < formation.fleetGroups.length; index++)
              if (formation.fleetGroups[index].isNotEmpty) ...[
                const SizedBox(height: 7),
                if (formation.fleetGroups.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: _FleetHeading(
                      strings.fleetNumber(index + 1),
                      compact: compact,
                    ),
                  ),
                _EnemyFleetGrid(
                  formationVariant: formation.variant,
                  groupIndex: index,
                  ships: formation.fleetGroups[index],
                  strings: strings,
                  compact: compact,
                  state: state,
                  enemyCatalog: enemyCatalog,
                  twoColumns: twoColumnShips,
                ),
              ],
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(
                note,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, Color(0xff8098a4)),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EnemyFleetGrid extends StatelessWidget {
  const _EnemyFleetGrid({
    required this.formationVariant,
    required this.groupIndex,
    required this.ships,
    required this.strings,
    required this.compact,
    required this.state,
    required this.enemyCatalog,
    required this.twoColumns,
  });

  final int formationVariant;
  final int groupIndex;
  final List<EnemyShipEntry> ships;
  final SortieMapQueryStrings strings;
  final bool compact;
  final GameState state;
  final EnemyCatalogData? enemyCatalog;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) {
    final columns = twoColumns ? 2 : 1;
    return Column(
      children: [
        for (var start = 0; start < ships.length; start += columns) ...[
          Row(
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) const SizedBox(width: 6),
                Expanded(
                  child: start + column < ships.length
                      ? SizedBox(
                          key: Key(
                            'sortie-map-enemy-tile-$formationVariant-$groupIndex-${start + column}',
                          ),
                          child: _EnemyShipTile(
                            formationVariant: formationVariant,
                            groupIndex: groupIndex,
                            shipIndex: start + column,
                            entry: ships[start + column],
                            label: gameNames(context).shipName(
                              strings.enemyShipName(ships[start + column]),
                              shipId: ships[start + column].id,
                            ),
                            compact: compact,
                            state: state,
                            enemyCatalog: enemyCatalog,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
          if (start + columns < ships.length)
            Container(
              key: Key(
                'sortie-map-enemy-divider-$formationVariant-$groupIndex-$start',
              ),
              height: 1,
              color: appColor(context, const Color(0x263f6374)),
            ),
        ],
      ],
    );
  }
}

class _EnemyShipTile extends StatelessWidget {
  const _EnemyShipTile({
    required this.formationVariant,
    required this.groupIndex,
    required this.shipIndex,
    required this.entry,
    required this.label,
    required this.compact,
    required this.state,
    required this.enemyCatalog,
  });

  final int formationVariant;
  final int groupIndex;
  final int shipIndex;
  final EnemyShipEntry entry;
  final String label;
  final bool compact;
  final GameState state;
  final EnemyCatalogData? enemyCatalog;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Material(
      color: appColor(context, Colors.transparent),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => showSortieEnemyDetails(
          context,
          entry: entry,
          state: state,
          catalog: enemyCatalog,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 29),
          child: Row(
            children: [
              ShipPortrait(
                key: Key(
                  'sortie-map-enemy-portrait-$formationVariant-$groupIndex-$shipIndex',
                ),
                ship: state.masterShips[entry.id],
                serverOrigin: state.serverOrigin,
                width: 48,
                height: 22,
                decodeHeight: 44,
                resourceType: ShipPortraitResourceType.banner,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: const Color(0xffeef6f8),
                      fontSize: compact ? 10.5 : 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NodeButton extends StatelessWidget {
  const _NodeButton({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final SortieMapNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: Key('sortie-map-node-${node.point}'),
      button: true,
      selected: selected,
      label: node.isBoss ? '${node.point} BOSS' : node.point,
      excludeSemantics: true,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(
          child: SizedBox.square(
            dimension: 32,
            child: Material(
              key: Key('sortie-map-node-visual-${node.point}'),
              color: selected
                  ? AppSegmentedStyle.selectedBackground(context)
                  : appColor(context, const Color(0xff132d3b)),
              shape: CircleBorder(
                side: BorderSide(
                  color: selected
                      ? AppSegmentedStyle.selectedBorder(context)
                      : appColor(context, const Color(0xff3b5c6c)),
                ),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (node.isBoss) ...[
                          Icon(
                            Icons.flag,
                            color: selected
                                ? AppSegmentedStyle.foreground(context, true)
                                : appColor(context, const Color(0xffdce9ee)),
                            size: 11,
                          ),
                          const SizedBox(width: 1),
                        ],
                        Text(
                          node.point,
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: selected
                                  ? AppSegmentedStyle.foreground(context, true)
                                  : const Color(0xffdce9ee),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: appColor(context, Color(0xff102431)),
      border: Border.all(color: appColor(context, Color(0xff294657))),
      borderRadius: BorderRadius.circular(9),
    ),
    child: child,
  );
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading(this.label, {required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: appTextStyle(
      context,
      TextStyle(
        color: const Color(0xffeef6f8),
        fontSize: compact ? 13 : 16,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
  );
}

class _AttributionFooter extends StatelessWidget {
  const _AttributionFooter({required this.strings});

  final SortieMapQueryStrings strings;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      strings.attribution,
      key: const Key('sortie-map-attribution'),
      textAlign: TextAlign.center,
      style: appTextStyle(
        context,
        TextStyle(
          color: appColor(context, Color(0xff718b98)),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _FleetHeading extends StatelessWidget {
  const _FleetHeading(this.label, {required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: appTextStyle(
      context,
      TextStyle(
        color: const Color(0xffeef6f8),
        fontSize: compact ? 11 : 13,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _NodeTypeBadge extends StatelessWidget {
  const _NodeTypeBadge({
    required this.badgeKey,
    required this.label,
    required this.kind,
  });

  final Key badgeKey;
  final String label;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final boss = kind == 'boss';
    final battle = kind == 'battle';
    final foreground = boss
        ? const Color(0xffffd2c9)
        : battle
        ? const Color(0xff83d5c8)
        : const Color(0xffffc95c);
    final background = boss
        ? const Color(0xff6e342f)
        : battle
        ? const Color(0xff183e38)
        : const Color(0xff4a3b21);
    return Container(
      key: badgeKey,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: appColor(context, background),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: appTextStyle(
          context,
          TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

const _clearAfterMarker = 'クリア後の';

bool _hasClearAfterMarker(String? value) =>
    value?.contains(_clearAfterMarker) ?? false;

String? _fleetNameWithoutClearAfter(String? value) {
  if (value == null) return null;
  final result = value.replaceAll(_clearAfterMarker, '').trim();
  return result.isEmpty ? null : result;
}

class _AssetImage extends StatelessWidget {
  const _AssetImage({required this.asset, this.file, this.fit = BoxFit.cover});

  final String asset;
  final File? file;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget errorBuilder(context, error, stackTrace) => ColoredBox(
      color: appColor(context, Color(0xff0a1a24)),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: appColor(context, Color(0xff537383)),
        ),
      ),
    );
    final cached = file;
    return cached == null
        ? Image.asset(asset, fit: fit, errorBuilder: errorBuilder)
        : Image.file(
            cached,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'assets/images/sortie_maps/$asset',
              fit: fit,
              errorBuilder: errorBuilder,
            ),
          );
  }
}

class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({
    required this.icon,
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: appColor(context, Color(0xff6e8b99)), size: 30),
        const SizedBox(height: 8),
        Text(
          label,
          style: appTextStyle(
            context,
            TextStyle(color: appColor(context, Color(0xff9bb0ba))),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('sortie-map-retry'),
            onPressed: onAction,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

const _selectorBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(7)),
  borderSide: BorderSide(color: Color(0xff3b5b6a)),
);
