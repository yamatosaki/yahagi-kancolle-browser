import '../../widgets/app_popup_menu_button.dart';
import '../../theme/app_palette.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../game_state/game_state.dart';
import '../../localization/game_name_localizations.dart';
import '../../widgets/app_segmented_style.dart';
import '../../widgets/top_notice.dart';
import '../../theme/app_fonts.dart';
import '../../quest/quest_completion_badge.dart';
import '../sortie_map_query/sortie_map_catalog.dart';
import '../sortie_map_query/sortie_map_catalog_controller.dart';
import '../sortie_map_query/sortie_map_models.dart';
import 'exp_calc_catalog.dart';
import 'exp_calc_strings.dart';
import 'exp_calc_models.dart';
import 'exp_calc_panel_row.dart';
import 'exp_calc_ship_picker.dart';
import 'exp_tracker_store.dart';
import 'ship_exp_table.dart';

abstract final class _ExpCalcPalette {
  static const background = Color(0xff091923);
  static const surface = Color(0xff102732);
  static const surfaceRaised = Color(0xff16333f);
  static const surfaceInset = Color(0xff0c202b);
  static const border = Color(0xff284553);
  static const gold = Color(0xffd7b56d);
  static const goldSoft = Color(0xffffdc88);
  static const text = Color(0xffecf3f5);
  static const textMuted = Color(0xff91aab8);
  static const textFaint = Color(0xff6f8a98);
}

/// Single planned battle node in a multi-node sortie route.
class _RouteNodeState {
  _RouteNodeState({
    required this.id,
    required this.mapId,
    required this.nodeId,
    this.rank = BattleRank.s,
    this.isFlagship = true,
    this.isMvp = false,
  }) : baseExpController = TextEditingController();

  final String id;
  String mapId;
  String nodeId;
  final TextEditingController baseExpController;
  BattleRank rank;
  bool isFlagship;
  bool isMvp;

  bool manual = false;
  bool expanded = false;
  num? automaticExp;

  num? get baseExp {
    if (!manual) return automaticExp;
    final value = num.tryParse(baseExpController.text.trim());
    return value != null && value.isFinite && value >= 0 && value <= 1000000000
        ? value
        : null;
  }

  void usePreset(MapNodePreset point) {
    nodeId = point.id;
    manual = false;
    automaticExp = point.baseExp;
    baseExpController.text = point.baseExp == null
        ? ''
        : formatExperience(point.baseExp!);
  }

  int computeExp() => baseExp == null
      ? 0
      : computeMapExp(
          baseExp: baseExp!,
          rank: rank,
          isFlagship: isFlagship,
          isMvp: isMvp,
        );

  void dispose() {
    baseExpController.dispose();
  }
}

class ExpCalcPage extends StatefulWidget {
  const ExpCalcPage({
    super.key,
    required this.state,
    this.store,
    this.catalogController,
    this.catalogLoader,
  });

  final GameState state;
  final ExpTrackerStore? store;
  final SortieMapCatalogController? catalogController;
  final Future<SortieMapCatalogData> Function()? catalogLoader;

  @override
  State<ExpCalcPage> createState() => _ExpCalcPageState();
}

class _ExpCalcPageState extends State<ExpCalcPage> {
  late final ExpTrackerStore _store;
  BattleRank _routeRank = BattleRank.s;
  bool _routeFlagship = true;
  bool _routeMvp = true;
  List<SortieMapPreset> _catalogMaps = [];
  SortieMapCatalogData? _catalogData;
  bool _catalogLoading = true;
  bool _catalogFailed = false;
  int _catalogGeneration = 0;
  ExpCalcStrings get _strings => ExpCalcStrings(context);

  List<SortieMapPreset> get _maps => [
    ..._catalogMaps,
    SortieMapPreset(
      id: 'pvp',
      name: _strings.exercise,
      nodes: const [MapNodePreset(id: 'manual', name: '—', baseExp: null)],
    ),
    SortieMapPreset(
      id: 'custom',
      name: _strings.custom,
      nodes: const [MapNodePreset(id: 'manual', name: '—', baseExp: null)],
    ),
  ];

  void _onCatalogChanged() {
    final data = widget.catalogController?.data;
    if (data != null && !identical(data, _catalogData)) _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final generation = ++_catalogGeneration;
    try {
      final data =
          widget.catalogController?.data ??
          await (widget.catalogLoader ?? SortieMapCatalog.loadAsset)();
      if (!mounted || generation != _catalogGeneration) return;
      setState(() {
        _catalogData = data;
        _catalogMaps = experienceMaps(data);
        _catalogLoading = false;
        _catalogFailed = false;
        for (final node in _routeNodes) {
          final maps = _catalogMaps.where((map) => map.id == node.mapId);
          final points = maps.isEmpty
              ? <MapNodePreset>[]
              : maps.first.nodes
                    .where((point) => point.id == node.nodeId)
                    .toList();
          if (points.isNotEmpty) {
            if (!node.manual) node.usePreset(points.first);
          } else if (node.mapId != 'custom' && node.mapId != 'pvp') {
            // A removed catalog point must not silently become a different battle.
            node.mapId = 'custom';
            node.nodeId = 'manual';
            if (!node.manual) {
              node.usePreset(
                const MapNodePreset(id: 'manual', name: '', baseExp: null),
              );
            }
          }
        }
      });
    } catch (_) {
      if (!mounted || generation != _catalogGeneration) return;
      setState(() {
        _catalogLoading = false;
        _catalogFailed = true;
      });
    }
  }

  bool get _hasValidRoute => _routeNodes.every((node) => node.baseExp != null);
  bool get _canEstimate =>
      _hasValidRoute && (_totalSortieExp > 0 || _remainExp == 0);

  // Selected ship state
  int? _selectedShipInstanceId;
  String _selectedShipName = '';
  int _currentLevel = 1;
  int _currentExp = 0;
  int _targetLevel = 2;
  int _targetExp = 100;

  // User preference for card vs table view in tracker list

  // Controllers for level inputs
  final TextEditingController _curLevelController = TextEditingController(
    text: '1',
  );
  final TextEditingController _targetLevelController = TextEditingController(
    text: '2',
  );

  // Multi-node route plan
  final List<_RouteNodeState> _routeNodes = <_RouteNodeState>[];

  // Tracker table items
  List<ExpCalcTrackItem> _trackItems = <ExpCalcTrackItem>[];
  int _trackGeneration = 0;
  bool _trackLoading = true;
  bool _trackLoadFailed = false;
  Future<void> _trackWriteQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SharedPreferencesExpTrackerStore();

    // Default node 1 (5-2 C point 150 EXP, S rank, Flagship, MVP)
    _routeNodes.add(
      _RouteNodeState(
        id: 'node_init',
        mapId: '5-2',
        nodeId: 'C',
        rank: BattleRank.s,
        isFlagship: true,
        isMvp: true,
      ),
    );

    widget.catalogController?.addListener(_onCatalogChanged);
    _loadCatalog();
    _initShipSelection();
    _loadTrackItems();
  }

  @override
  void didUpdateWidget(covariant ExpCalcPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalogController != widget.catalogController ||
        oldWidget.catalogLoader != widget.catalogLoader) {
      oldWidget.catalogController?.removeListener(_onCatalogChanged);
      widget.catalogController?.addListener(_onCatalogChanged);
      _loadCatalog();
    }
    if (oldWidget.state.memberId != widget.state.memberId) {
      _trackGeneration++;
      _trackItems = <ExpCalcTrackItem>[];
      _trackLoading = true;
      _trackLoadFailed = false;
      _selectedShipInstanceId = null;
      _selectedShipName = '';
      _initShipSelection();
      _loadTrackItems();
    }
    if (_selectedShipInstanceId != null) {
      final updatedShip = widget.state.ships[_selectedShipInstanceId];
      final oldShip = oldWidget.state.ships[_selectedShipInstanceId];
      if (updatedShip != null &&
          oldShip != null &&
          (updatedShip.experience != oldShip.experience ||
              updatedShip.level != oldShip.level)) {
        setState(() {
          _currentLevel = updatedShip.level;
          _currentExp = updatedShip.experience;
          _curLevelController.text = '$_currentLevel';
          if (_targetLevel <= _currentLevel) {
            _targetLevel = math.min(kShipMaxLevel, _currentLevel + 1);
            _targetExp = shipCumulativeExp(_targetLevel);
            _targetLevelController.text = '$_targetLevel';
          }
        });
      }
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // Refresh derived catalog values when calculation rules change in debug.
    _loadCatalog();
  }

  @override
  void dispose() {
    widget.catalogController?.removeListener(_onCatalogChanged);
    _catalogGeneration++;
    _trackGeneration++;
    _curLevelController.dispose();
    _targetLevelController.dispose();
    for (final node in _routeNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTrackItems() async {
    final generation = _trackGeneration;
    final memberId = widget.state.memberId;
    try {
      final items = await _store.loadTrackItems(memberId);
      if (!mounted ||
          generation != _trackGeneration ||
          memberId != widget.state.memberId) {
        return;
      }
      setState(() {
        _trackItems = items;
        _trackLoading = false;
        _trackLoadFailed = false;
      });
    } catch (_) {
      if (!mounted ||
          generation != _trackGeneration ||
          memberId != widget.state.memberId) {
        return;
      }
      setState(() {
        _trackLoading = false;
        _trackLoadFailed = true;
      });
    }
  }

  void _retryLoadTrackItems() {
    setState(() {
      _trackLoading = true;
      _trackLoadFailed = false;
    });
    _loadTrackItems();
  }

  void _initShipSelection() {
    final sortedShips = _getSortedOwnedShips();
    if (sortedShips.isNotEmpty) {
      final first = sortedShips.first;
      _selectShip(first);
    } else {
      _selectedShipInstanceId = null;
      _selectedShipName = '';
      _currentLevel = 1;
      _currentExp = 0;
      _targetLevel = 2;
      _targetExp = shipCumulativeExp(2);
      _curLevelController.text = '1';
      _targetLevelController.text = '2';
    }
  }

  List<OwnedShip> _getSortedOwnedShips() {
    final list = widget.state.ships.values.toList();
    list.sort((a, b) {
      final lvCmp = b.level.compareTo(a.level);
      if (lvCmp != 0) return lvCmp;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  void _selectShip(OwnedShip? ship) {
    if (ship == null) {
      setState(() {
        _selectedShipInstanceId = null;
        _selectedShipName = '';
        _curLevelController.text = '$_currentLevel';
        _targetLevelController.text = '$_targetLevel';
      });
      return;
    }

    final master = widget.state.masterShips[ship.masterId];
    final shipName = master?.name ?? 'Ship #${ship.id}';
    final afterLv = master?.afterLv ?? 0;

    int targetLv;
    if (afterLv > 0 && ship.level < afterLv) {
      targetLv = math.min(afterLv, kShipMaxLevel);
    } else {
      targetLv = math.min(ship.level + 1, kShipMaxLevel);
    }

    setState(() {
      _selectedShipInstanceId = ship.id;
      _selectedShipName = shipName;
      _currentLevel = math.min(ship.level, kShipMaxLevel);
      _currentExp = ship.experience;
      _targetLevel = targetLv;
      _targetExp = shipCumulativeExp(targetLv);
      _curLevelController.text = '$_currentLevel';
      _targetLevelController.text = '$_targetLevel';
    });
  }

  void _stepTargetLevel(int delta) {
    final newLv = math.max(1, math.min(kShipMaxLevel, _targetLevel + delta));
    setState(() {
      _targetLevel = newLv;
      _targetExp = shipCumulativeExp(newLv);
      _targetLevelController.text = '$newLv';
    });
  }

  void _onTargetLevelInput(String text) {
    final val = int.tryParse(text.trim());
    if (val != null) {
      final clamped = math.max(1, math.min(kShipMaxLevel, val));
      setState(() {
        _targetLevel = clamped;
        _targetExp = shipCumulativeExp(clamped);
      });
    }
  }

  void _onCurLevelInput(String text) {
    if (_selectedShipInstanceId != null) return;
    final val = int.tryParse(text.trim());
    if (val != null) {
      final clamped = math.max(1, math.min(kShipMaxLevel, val));
      setState(() {
        _currentLevel = clamped;
        _currentExp = shipCumulativeExp(clamped);
        if (_targetLevel < _currentLevel) {
          _targetLevel = math.min(kShipMaxLevel, _currentLevel + 1);
          _targetExp = shipCumulativeExp(_targetLevel);
          _targetLevelController.text = '$_targetLevel';
        }
      });
    }
  }

  void _addRouteNode(MapNodePreset point) {
    final node = _RouteNodeState(
      id: 'node_${DateTime.now().microsecondsSinceEpoch}',
      mapId: _routeNodes.first.mapId,
      nodeId: point.id,
      rank: _routeRank,
      isFlagship: _routeFlagship,
      isMvp: _routeMvp,
    )..usePreset(point);
    setState(() => _routeNodes.add(node));
  }

  void _changeRouteMap(SortieMapPreset map) {
    setState(() {
      for (final node in _routeNodes.skip(1)) {
        node.dispose();
      }
      _routeNodes.removeRange(1, _routeNodes.length);
      final first = _routeNodes.first;
      first.mapId = map.id;
      first.usePreset(map.nodes.first);
      first.rank = _routeRank;
      first.isFlagship = _routeFlagship;
      first.isMvp = _routeMvp;
      first.expanded = false;
    });
  }

  void _removeRouteNode(int index) {
    if (_routeNodes.length <= 1) return;
    setState(() {
      final removed = _routeNodes.removeAt(index);
      removed.dispose();
    });
  }

  int get _totalSortieExp =>
      _routeNodes.fold(0, (sum, n) => sum + n.computeExp());

  int get _remainExp => math.max(0, _targetExp - _currentExp);

  int get _sortieCount =>
      computeBattleCount(remainExp: _remainExp, mapExp: _totalSortieExp);

  String get _routeSummary => compactRouteSummary(
    _routeNodes.map((n) => '${n.mapId}(${n.nodeId})').join(' + '),
  );

  Future<void> _addTrackItem() async {
    if (!_canEstimate || _trackLoading || _trackLoadFailed) return;
    final memberId = widget.state.memberId;
    final l10n = AppLocalizations.of(context)!;
    final shipName = _selectedShipInstanceId != null
        ? _selectedShipName
        : l10n.expCalcFreeMode;

    final firstNode = _routeNodes.isNotEmpty ? _routeNodes.first : null;
    final item = ExpCalcTrackItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      shipInstanceId: _selectedShipInstanceId ?? -1,
      shipMasterId: -1,
      shipName: shipName,
      targetLevel: _targetLevel,
      targetExp: _targetExp,
      map: firstNode?.mapId ?? '5-2',
      rank: firstNode?.rank ?? BattleRank.s,
      isFlagship: firstNode?.isFlagship ?? true,
      isMvp: firstNode?.isMvp ?? false,
      baseExp: firstNode?.baseExp ?? 150,
      mapExp: firstNode?.computeExp() ?? 540,
      recordedLevel: _currentLevel,
      recordedExp: _currentExp,
      routeSummary: _routeSummary,
      totalSortieExp: _totalSortieExp,
      createdAt: DateTime.now(),
    );

    final saved = await _mutateTrackItems((items) => [item, ...items]);
    if (!mounted || widget.state.memberId != memberId) return;
    if (!saved) {
      if (!_trackLoadFailed) {
        TopNotice.show(
          context,
          message: l10n.expCalcTrackSaveFailed,
          tone: TopNoticeTone.error,
        );
      }
      return;
    }

    TopNotice.show(context, message: l10n.expCalcTrackAdded);
  }

  Future<void> _deleteTrackItem(String id) async {
    if (_trackLoading || _trackLoadFailed) return;
    final memberId = widget.state.memberId;
    final l10n = AppLocalizations.of(context)!;
    final saved = await _mutateTrackItems(
      (items) => items.where((item) => item.id != id).toList(),
    );
    if (!mounted || widget.state.memberId != memberId) return;
    if (!saved) {
      TopNotice.show(
        context,
        message: l10n.expCalcTrackSaveFailed,
        tone: TopNoticeTone.error,
      );
      return;
    }

    TopNotice.show(context, message: l10n.expCalcTrackDeleted);
  }

  Future<bool> _mutateTrackItems(
    List<ExpCalcTrackItem> Function(List<ExpCalcTrackItem>) update,
  ) {
    final generation = _trackGeneration;
    final memberId = widget.state.memberId;
    final operation = _trackWriteQueue.then((_) async {
      if (!mounted ||
          _trackLoading ||
          _trackLoadFailed ||
          generation != _trackGeneration ||
          memberId != widget.state.memberId) {
        return false;
      }
      final updated = update(_trackItems);
      try {
        if (!await _store.saveTrackItems(memberId, updated)) return false;
      } catch (_) {
        return false;
      }
      if (!mounted ||
          generation != _trackGeneration ||
          memberId != widget.state.memberId) {
        return false;
      }
      setState(() => _trackItems = updated);
      return true;
    });
    _trackWriteQueue = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  String get _fontFamily =>
      Theme.of(context).textTheme.bodyMedium?.fontFamily ??
      AppFonts.forLocale(Localizations.localeOf(context).toString());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: _fontFamily),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: _fontFamily),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: theme.textTheme.bodyMedium?.fontFamilyFallback,
        ),
        child: _buildPage(context),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: appColor(context, _ExpCalcPalette.background),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final setup = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _targetPanel(l10n),
              const SizedBox(height: 12),
              _routePanel(l10n),
            ],
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      ExpCalcPanelRow(
                        key: const Key('exp-calc-wide-workspace'),
                        children: [
                          _targetPanel(l10n),
                          _routePanel(l10n),
                          _resultPanel(l10n),
                        ],
                      )
                    else
                      Column(
                        key: const Key('exp-calc-compact-workspace'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          setup,
                          const SizedBox(height: 12),
                          _resultPanel(l10n),
                        ],
                      ),
                    const SizedBox(height: 12),
                    _buildTrackingTable(l10n),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _panel(String title, List<Widget> children) => Container(
    key: ValueKey('exp-calc-panel-$title'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: appColor(context, _ExpCalcPalette.surface),
      border: Border.all(color: appColor(context, _ExpCalcPalette.border)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: appTextStyle(
            context,
            TextStyle(
              color: appColor(context, _ExpCalcPalette.text),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );

  Widget _label(String text, {Color color = _ExpCalcPalette.textMuted}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: appTextStyle(context, TextStyle(color: color, fontSize: 11)),
        ),
      );

  InputDecoration _inputDecoration({
    String? prefix,
    String? suffix,
  }) => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: appColor(context, _ExpCalcPalette.surfaceInset),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    prefixText: prefix,
    suffixText: suffix,
    prefixStyle: TextStyle(
      color: appColor(context, _ExpCalcPalette.text),
      fontSize: 12,
    ),
    suffixStyle: TextStyle(
      color: appColor(context, _ExpCalcPalette.textMuted),
      fontSize: 10,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: appColor(context, _ExpCalcPalette.border)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: appColor(context, _ExpCalcPalette.gold)),
    ),
  );

  Widget _dropdown<T>({
    required Key key,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool compact = false,
  }) => Container(
    height: 44,
    padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10),
    decoration: BoxDecoration(
      color: appColor(context, _ExpCalcPalette.surfaceInset),
      border: Border.all(color: appColor(context, _ExpCalcPalette.border)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        barrierDismissible: false,
        key: key,
        value: value,
        items: items,
        onChanged: onChanged,
        isExpanded: true,
        isDense: true,
        menuMaxHeight: 380,
        dropdownColor: appColor(context, _ExpCalcPalette.surface),
        icon: Icon(
          Icons.expand_more,
          color: appColor(context, _ExpCalcPalette.textMuted),
          size: compact ? 14 : 18,
        ),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: _fontFamily,
          color: appColor(context, _ExpCalcPalette.text),
          fontSize: 12,
        ),
      ),
    ),
  );

  Widget _targetPanel(AppLocalizations l10n) => _panel(_strings.target, [
    ExpCalcShipPicker(
      state: widget.state,
      ships: _getSortedOwnedShips(),
      selectedId: _selectedShipInstanceId,
      onSelected: _selectShip,
    ),
    const SizedBox(height: 10),
    LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(
            width: constraints.maxWidth < 280
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label(
                  l10n.expCalcCurrentLevel,
                  color: appColor(context, _ExpCalcPalette.text),
                ),
                TextField(
                  key: const Key('exp-calc-current-level'),
                  controller: _curLevelController,
                  readOnly: _selectedShipInstanceId != null,
                  keyboardType: TextInputType.number,
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, _ExpCalcPalette.text),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  decoration: _inputDecoration(prefix: 'Lv. '),
                  onChanged: _onCurLevelInput,
                ),
                const SizedBox(height: 6),
                Text(
                  '$_currentExp EXP',
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, _ExpCalcPalette.goldSoft),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: constraints.maxWidth < 280
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label(
                  l10n.expCalcTargetLevel,
                  color: appColor(context, _ExpCalcPalette.text),
                ),
                TextField(
                  key: const Key('exp-calc-target-level'),
                  controller: _targetLevelController,
                  keyboardType: TextInputType.number,
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, _ExpCalcPalette.text),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  decoration: _inputDecoration(prefix: 'Lv. ').copyWith(
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 52,
                      minHeight: 40,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const Key('exp-calc-target-level-decrease'),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _targetLevel > 1
                              ? () => _stepTargetLevel(-1)
                              : null,
                          tooltip: '${l10n.expCalcTargetLevel} −1',
                          icon: const Icon(Icons.remove, size: 16),
                          color: appColor(context, _ExpCalcPalette.textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 40,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          key: const Key('exp-calc-target-level-increase'),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _targetLevel < kShipMaxLevel
                              ? () => _stepTargetLevel(1)
                              : null,
                          tooltip: '${l10n.expCalcTargetLevel} +1',
                          icon: const Icon(Icons.add, size: 16),
                          color: appColor(context, _ExpCalcPalette.textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 40,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  onChanged: _onTargetLevelInput,
                ),
                const SizedBox(height: 6),
                Text(
                  '$_targetExp EXP',
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, _ExpCalcPalette.goldSoft),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 10),
    Row(
      children: [
        Expanded(
          child: Text(
            '${l10n.expCalcTargetGapLabel}  $_remainExp EXP',
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, _ExpCalcPalette.goldSoft),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    ),
  ]);

  Widget _routePanel(AppLocalizations l10n) {
    final maps = _maps;
    final first = _routeNodes.first;
    if (!maps.any((map) => map.id == first.mapId)) {
      maps.insert(
        0,
        SortieMapPreset(
          id: first.mapId,
          name: first.mapId,
          nodes: [
            MapNodePreset(id: first.nodeId, name: first.nodeId, baseExp: null),
          ],
        ),
      );
    }
    final map = maps.firstWhere((map) => map.id == first.mapId);
    return _panel(_strings.route, [
      if (_catalogLoading) _label(_strings.loading),
      if (_catalogFailed)
        Row(
          children: [
            Expanded(child: _label(_strings.loadFailed)),
            TextButton(onPressed: _loadCatalog, child: Text(_strings.retry)),
          ],
        ),
      _dropdown<String>(
        key: const Key('exp-calc-map-selector'),
        value: first.mapId,
        items: [
          for (final m in maps)
            DropdownMenuItem(
              value: m.id,
              child: Text(m.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) {
          if (id != null) _changeRouteMap(maps.firstWhere((m) => m.id == id));
        },
      ),
      const SizedBox(height: 8),
      _battleOptions(l10n),
      const SizedBox(height: 12),
      Row(
        children: [
          SizedBox(
            width: 54,
            child: _label(
              l10n.expCalcNodePoint,
              color: appColor(context, _ExpCalcPalette.text),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 58,
            child: Tooltip(
              message: _strings.roundedHint,
              child: _label(
                _strings.base,
                color: appColor(context, _ExpCalcPalette.text),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _label(
                  _strings.subtotal,
                  color: appColor(context, _ExpCalcPalette.text),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          if (_routeNodes.length > 1) const SizedBox(width: 24),
        ],
      ),
      for (var i = 0; i < _routeNodes.length; i++) ...[
        if (i > 0) const SizedBox(height: 6),
        _compactPoint(l10n, map, _routeNodes[i], i),
      ],
      const SizedBox(height: 8),
      AppPopupMenuButton<String>(
        key: const Key('exp-calc-add-node-button'),
        tooltip: _strings.addNode,
        color: appColor(context, _ExpCalcPalette.surface),
        onSelected: (id) =>
            _addRouteNode(map.nodes.firstWhere((point) => point.id == id)),
        itemBuilder: (context) => [
          for (final point in map.nodes)
            PopupMenuItem(
              key: Key('exp-calc-add-point-${point.id}'),
              value: point.id,
              child: Text(
                '${point.name}   ·   ${point.baseExp == null ? '—' : formatExperience(point.baseExp!)} EXP',
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, _ExpCalcPalette.text),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: appColor(context, _ExpCalcPalette.border),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: 16,
                color: appColor(context, _ExpCalcPalette.textMuted),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _strings.addNode,
                  textAlign: TextAlign.center,
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, _ExpCalcPalette.textMuted),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 10,
        runSpacing: 4,
        children: [
          Text(
            Localizations.localeOf(context).languageCode == 'en'
                ? '${_routeNodes.length} battle ${_routeNodes.length == 1 ? 'node' : 'nodes'}'
                : '${_routeNodes.length} ${l10n.expCalcCombatNodesSuffix}',
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, _ExpCalcPalette.text),
                fontSize: 11,
              ),
            ),
          ),
          Text(
            '${_strings.perSortie}  ${_hasValidRoute ? _totalSortieExp : '—'} EXP',
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, _ExpCalcPalette.goldSoft),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _battleOptions(
    AppLocalizations l10n, {
    _RouteNodeState? node,
    int index = 0,
  }) {
    final rank = node?.rank ?? _routeRank;
    final flagship = node?.isFlagship ?? _routeFlagship;
    final mvp = node?.isMvp ?? _routeMvp;
    final suffix = node == null ? '0' : 'detail-$index';
    void update({BattleRank? rank, bool? flagship, bool? mvp}) => setState(() {
      if (node == null) {
        if (rank != null) _routeRank = rank;
        if (flagship != null) _routeFlagship = flagship;
        if (mvp != null) _routeMvp = mvp;
      }
      for (final target in node == null ? _routeNodes : [node]) {
        if (rank != null) target.rank = rank;
        if (flagship != null) target.isFlagship = flagship;
        if (mvp != null) target.isMvp = mvp;
      }
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final ranks = Container(
          height: 38,
          padding: AppSegmentedStyle.padding(),
          decoration: AppSegmentedStyle.decoration(context),
          child: Row(
            children: [
              for (final value in BattleRank.values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: rank == value,
                    child: Material(
                      color: AppSegmentedStyle.selection(
                        context,
                        rank == value,
                      ),
                      borderRadius: AppSegmentedStyle.itemRadius(),
                      child: InkWell(
                        key: Key('exp-calc-rank-${value.name}-$suffix'),
                        onTap: () => update(rank: value),
                        borderRadius: AppSegmentedStyle.itemRadius(),
                        child: Center(
                          child: Text(
                            value.label,
                            style: AppSegmentedStyle.textStyle(
                              context,
                              selected: rank == value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        final buffs = Row(
          children: [
            Expanded(
              child: _option(
                Key(
                  node == null
                      ? 'exp-calc-flagship-checkbox'
                      : 'exp-calc-flagship-detail-$index',
                ),
                '${l10n.expCalcFlagship} ×1.5',
                flagship,
                () => update(flagship: !flagship),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _option(
                Key(
                  node == null
                      ? 'exp-calc-mvp-checkbox'
                      : 'exp-calc-mvp-detail-$index',
                ),
                'MVP ×2',
                mvp,
                () => update(mvp: !mvp),
              ),
            ),
          ],
        );
        return Tooltip(
          message: node == null ? _strings.shared : _strings.details,
          child: constraints.maxWidth >= 420
              ? Row(
                  children: [
                    Expanded(child: ranks),
                    const SizedBox(width: 8),
                    Expanded(child: buffs),
                  ],
                )
              : Column(children: [ranks, const SizedBox(height: 6), buffs]),
        );
      },
    );
  }

  Widget _compactPoint(
    AppLocalizations l10n,
    SortieMapPreset map,
    _RouteNodeState node,
    int index,
  ) {
    final point = map.nodes.firstWhere(
      (point) => point.id == node.nodeId,
      orElse: () => map.nodes.first,
    );
    final overridden =
        node.rank != _routeRank ||
        node.isFlagship != _routeFlagship ||
        node.isMvp != _routeMvp;
    return Column(
      key: ValueKey(node.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              key: Key('exp-calc-point-capsule-$index'),
              width: 54,
              height: 44,
              child: _dropdown<String>(
                key: Key('exp-calc-point-selector-$index'),
                compact: true,
                value: point.id,
                items: [
                  for (final p in map.nodes)
                    DropdownMenuItem(
                      value: p.id,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(p.id, maxLines: 1),
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) {
                    setState(
                      () => node.usePreset(
                        map.nodes.firstWhere((p) => p.id == id),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 58,
              height: 44,
              child: Tooltip(
                message: node.manual ? _strings.manual : _strings.roundedHint,
                child: TextField(
                  key: Key(
                    index == 0
                        ? 'exp-calc-base-exp-input'
                        : 'exp-calc-base-exp-input-$index',
                  ),
                  controller: node.baseExpController,
                  expands: true,
                  maxLines: null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, _ExpCalcPalette.text),
                      fontSize: 13,
                    ),
                  ),
                  decoration: _inputDecoration().copyWith(
                    constraints: const BoxConstraints.tightFor(height: 44),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onChanged: (_) => setState(() => node.manual = true),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  key: Key('exp-calc-point-yield-$index'),
                  maxLines: 1,
                  softWrap: false,
                  node.baseExp == null ? '—' : '${node.computeExp()} EXP',
                  textAlign: TextAlign.right,
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, _ExpCalcPalette.goldSoft),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 24,
              child: IconButton(
                key: Key('exp-calc-details-$index'),
                tooltip: _strings.details,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 40),
                onPressed: () => setState(() => node.expanded = !node.expanded),
                icon: Icon(
                  node.expanded ? Icons.expand_less : Icons.tune,
                  size: 16,
                ),
                color: appColor(
                  context,
                  overridden ? _ExpCalcPalette.gold : _ExpCalcPalette.textMuted,
                ),
              ),
            ),
            if (_routeNodes.length > 1)
              SizedBox(
                width: 24,
                child: IconButton(
                  key: Key('exp-calc-remove-node-$index'),
                  tooltip: l10n.expCalcRemoveNode,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 40,
                  ),
                  onPressed: () => _removeRouteNode(index),
                  icon: const Icon(Icons.close, size: 16),
                  color: appColor(context, _ExpCalcPalette.textMuted),
                ),
              ),
          ],
        ),
        if (node.baseExp == null)
          _label(node.manual ? _strings.invalid : _strings.unknown),
        if (point.knownCount > 0 && point.knownCount < point.totalCount)
          _label(_strings.incomplete),
        if (overridden && !node.expanded)
          _label(
            '${node.rank.label} · ${node.isFlagship ? l10n.expCalcFlagship : '—'} · ${node.isMvp ? 'MVP' : '—'}',
          ),
        if (node.expanded)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label(_strings.details),
                _battleOptions(l10n, node: node, index: index),
                const SizedBox(height: 6),
                Text(
                  '${_strings.roundedHint} · ${_strings.coverage(point.knownCount, point.totalCount)}',
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, _ExpCalcPalette.textFaint),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _option(
    Key key,
    String label,
    bool selected,
    VoidCallback onTap,
  ) => Semantics(
    selected: selected,
    button: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: selected
            ? AppSegmentedStyle.selectedBackground(context)
            : appColor(context, _ExpCalcPalette.surfaceInset),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: selected
                ? AppSegmentedStyle.selectedBorder(context)
                : appColor(context, _ExpCalcPalette.border),
          ),
        ),
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            child: Center(
              child: Text(
                label,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: selected
                        ? AppSegmentedStyle.foreground(context, true)
                        : _ExpCalcPalette.textMuted,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _resultPanel(AppLocalizations l10n) => _panel(_strings.result, [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _stat(
            _strings.estimated,
            _canEstimate ? '$_sortieCount' : '—',
            emphasis: true,
            unit:
                Localizations.localeOf(context).languageCode == 'en' &&
                    _canEstimate &&
                    _sortieCount == 1
                ? 'time'
                : _strings.times,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            _strings.perSortie,
            _hasValidRoute ? '$_totalSortieExp' : '—',
            emphasis: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: _stat(l10n.expCalcRemainExp, '$_remainExp', emphasis: true),
        ),
      ],
    ),
    const SizedBox(height: 10),
    Text(
      _routeSummary,
      style: appTextStyle(
        context,
        TextStyle(
          color: appColor(context, _ExpCalcPalette.text),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    if (!_canEstimate) ...[
      const SizedBox(height: 8),
      Text(
        _hasValidRoute ? _strings.zero : _strings.unavailable,
        style: appTextStyle(
          context,
          TextStyle(
            color: appColor(context, _ExpCalcPalette.textMuted),
            fontSize: 11,
          ),
        ),
      ),
    ],
    const SizedBox(height: 10),
    FilledButton.icon(
      key: const Key('exp-calc-add-button'),
      onPressed: _canEstimate && !_trackLoading && !_trackLoadFailed
          ? _addTrackItem
          : null,
      style: FilledButton.styleFrom(
        backgroundColor: appColor(context, _ExpCalcPalette.gold),
        foregroundColor: appOnAccentColor(context, _ExpCalcPalette.background),
        disabledBackgroundColor: appColor(
          context,
          _ExpCalcPalette.surfaceRaised,
        ),
        disabledForegroundColor: appColor(context, _ExpCalcPalette.textFaint),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      icon: const Icon(Icons.playlist_add, size: 18),
      label: Text(_strings.addTrack),
    ),
  ]);

  Widget _stat(
    String label,
    String value, {
    bool emphasis = false,
    String unit = 'EXP',
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SizedBox(
          height: 16,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: appTextStyle(
                context,
                TextStyle(
                  color: emphasis
                      ? _ExpCalcPalette.goldSoft
                      : _ExpCalcPalette.textMuted,
                  fontSize: 11,
                  fontWeight: emphasis ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          maxLines: 1,
          softWrap: false,
          style: appTextStyle(
            context,
            TextStyle(
              color: emphasis ? _ExpCalcPalette.goldSoft : _ExpCalcPalette.text,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      const SizedBox(height: 3),
      Text(
        unit,
        style: appTextStyle(
          context,
          TextStyle(
            color: appColor(context, _ExpCalcPalette.text),
            fontSize: 10,
          ),
        ),
      ),
    ],
  );

  Widget _buildTrackingTable(AppLocalizations l10n) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: appColor(context, _ExpCalcPalette.surface),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: appColor(context, _ExpCalcPalette.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                l10n.expCalcTrackListTitle,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, _ExpCalcPalette.text),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: QuestCompletionBadge(
                inline: true,
                count: _trackItems.length,
                countKey: const Key('exp-calc-track-count'),
                semanticLabel:
                    '${l10n.expCalcTrackListTitle} ${_trackItems.length}',
                child: const SizedBox(width: 12, height: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_trackLoadFailed)
          TextButton.icon(
            key: const Key('exp-calc-track-retry'),
            onPressed: _retryLoadTrackItems,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.expCalcTrackLoadFailed),
          )
        else if (_trackLoading)
          const Center(child: CircularProgressIndicator())
        else if (_trackItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.expCalcEmptyTrackList,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, _ExpCalcPalette.textFaint),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SingleChildScrollView(
                key: const Key('exp-calc-track-list'),
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: math.max(760, constraints.maxWidth),
                  ),
                  child: DataTable(
                    horizontalMargin: 12,
                    columnSpacing: 18,
                    headingRowHeight: 36,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 38,
                    headingRowColor: WidgetStatePropertyAll(
                      appColor(context, const Color(0xff244352)),
                    ),
                    headingTextStyle: TextStyle(
                      color: appColor(context, Color(0xffc0d2dc)),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    border: TableBorder.all(
                      color: appColor(context, Color(0xff315064)),
                      width: 0.5,
                    ),
                    columns: [
                      for (final label in [
                        l10n.expCalcShip,
                        l10n.expCalcCurrentLevel,
                        l10n.expCalcTargetLevel,
                        l10n.expCalcRouteSummary,
                        _strings.total,
                        l10n.expCalcRemainExp,
                        l10n.expCalcBattle,
                        '',
                      ])
                        DataColumn(label: Text(label)),
                    ],
                    rows: [
                      for (final item in _trackItems)
                        _buildTrackDataRow(l10n, item),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  DataRow _buildTrackDataRow(AppLocalizations l10n, ExpCalcTrackItem item) {
    final liveLv = item.resolveCurrentLevel(widget.state);
    final remain = item.resolveRemainExp(widget.state);
    final battles = item.resolveBattleCount(widget.state);
    final isDone = remain == 0;
    final routeText = compactRouteSummary(
      item.routeSummary ?? '${item.map} (基准 ${item.baseExp})',
    );

    return DataRow(
      color: WidgetStatePropertyAll(appColor(context, const Color(0xff14313f))),
      cells: [
        DataCell(
          Text(
            gameNames(context).shipName(
              item.shipName,
              shipId:
                  widget.state.ships[item.shipInstanceId]?.masterId ??
                  item.shipMasterId,
            ),
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, _ExpCalcPalette.text),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            'Lv. $liveLv',
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, _ExpCalcPalette.text),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            'Lv. ${item.targetLevel}',
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, _ExpCalcPalette.text),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            routeText,
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, _ExpCalcPalette.text),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            '${item.effectiveSortieExp} EXP',
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, _ExpCalcPalette.text),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            '$remain',
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, _ExpCalcPalette.text),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            isDone ? l10n.expCalcCompletedTag : '$battles 次',
            style: appTextStyle(
              context,
              TextStyle(
                color: appColor(context, _ExpCalcPalette.text),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        DataCell(
          IconButton(
            key: Key('exp-calc-delete-button-${item.id}'),
            tooltip: l10n.expCalcDelete,
            onPressed: () => _deleteTrackItem(item.id),
            icon: const Icon(Icons.cancel_outlined, size: 20),
            color: appColor(context, Color(0xffff7b82)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}
