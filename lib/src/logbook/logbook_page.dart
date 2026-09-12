import 'dart:convert';

import 'package:flutter/material.dart';

import '../localization/ui_text.dart';
import '../battle/battle_detail_strings.dart';

import '../../l10n/app_localizations.dart';
import '../battle/battle_controller.dart';
import '../battle/battle_detail_models.dart';
import '../battle/battle_pills.dart';
import '../fleet/equipment_type_icon.dart';
import '../fleet/header_resource_catalog.dart';
import '../fleet/resource_trend_page.dart';
import '../game_state/combat_state.dart';
import '../game_state/game_state.dart';
import '../widgets/filter_controls.dart';
import '../widgets/frozen_data_table.dart';
import 'expedition_log_catalog.dart';
import 'battle_detail_page.dart';
import 'logbook_database.dart';
import 'logbook_filter_panel.dart';

enum _LogbookCategory {
  sortie('出击'),
  expedition('远征'),
  construction('建造'),
  development('开发'),
  retirement('除籍'),
  resource('资源');

  const _LogbookCategory(this.label);
  final String label;
}

const _heavyDamageColumnWidth = 166.0;
const _heavyDamageHorizontalPadding = 6.0;

class LogbookPage extends StatefulWidget {
  const LogbookPage({
    super.key,
    required this.battleController,
    this.database,
    this.selectedTabIndex = 0,
    this.onTabChanged,
  });

  final BattleController battleController;
  final LogbookDatabase? database;
  final int selectedTabIndex;
  final ValueChanged<int>? onTabChanged;

  @override
  State<LogbookPage> createState() => _LogbookPageState();
}

class _LogbookPageState extends State<LogbookPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _reportedTabIndex;

  @override
  void initState() {
    super.initState();
    _reportedTabIndex = widget.selectedTabIndex.clamp(
      0,
      _LogbookCategory.values.length - 1,
    );
    _tabController = TabController(
      length: _LogbookCategory.values.length,
      initialIndex: _reportedTabIndex,
      vsync: this,
    )..addListener(_reportTabChange);
  }

  @override
  void didUpdateWidget(covariant LogbookPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = widget.selectedTabIndex.clamp(
      0,
      _LogbookCategory.values.length - 1,
    );
    if (_tabController.index != nextIndex) {
      _reportedTabIndex = nextIndex;
      _tabController.animateTo(nextIndex);
    }
  }

  void _reportTabChange() {
    final index = _tabController.index;
    if (index == _reportedTabIndex) return;
    _reportedTabIndex = index;
    widget.onTabChanged?.call(index);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_reportTabChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LogbookDatabase.accountSession,
      builder: (context, _) => _buildAccountLogbook(context),
    );
  }

  Widget _buildAccountLogbook(BuildContext context) {
    final database = widget.database ?? LogbookDatabase.instance;
    final scope = LogbookDatabase.accountSession.current;
    return KeyedSubtree(
      key: ValueKey((database, scope.generation)),
      child: ColoredBox(
        color: const Color(0xff081521),
        // Both record lists and details consume device insets exactly once.
        child: SafeArea(
          top: false,
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _LogbookTablePage(
                category: _LogbookCategory.sortie,
                database: database,
                battleController: widget.battleController,
              ),
              _LogbookTablePage(
                category: _LogbookCategory.expedition,
                database: database,
                battleController: widget.battleController,
              ),
              _LogbookTablePage(
                category: _LogbookCategory.construction,
                database: database,
                battleController: widget.battleController,
              ),
              _LogbookTablePage(
                category: _LogbookCategory.development,
                database: database,
                battleController: widget.battleController,
              ),
              _LogbookTablePage(
                category: _LogbookCategory.retirement,
                database: database,
                battleController: widget.battleController,
              ),
              ResourceTrendPage(database: database),
            ],
          ),
        ),
      ),
    );
  }
}

class LogbookSegmented extends StatelessWidget {
  const LogbookSegmented({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Container(
        key: const Key('logbook-segmented'),
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xff0b202d),
          border: Border.all(color: const Color(0xff315064)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            for (var index = 0; index < _LogbookCategory.values.length; index++)
              Expanded(
                child: _LogbookSegmentButton(
                  key: Key(
                    'logbook-tab-${_LogbookCategory.values[index].name}',
                  ),
                  selected: index == selectedIndex,
                  label: _LogbookCategory.values[index].label,
                  onTap: () => onChanged(index),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _LogbookSegmentButton extends StatelessWidget {
  const _LogbookSegmentButton({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xff8a6628) : Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xffffdc88)
                  : const Color(0xff9fb3bf),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _LogbookTablePage extends StatefulWidget {
  const _LogbookTablePage({
    required this.category,
    required this.database,
    required this.battleController,
  });

  final _LogbookCategory category;
  final LogbookDatabase database;
  final BattleController battleController;

  @override
  State<_LogbookTablePage> createState() => _LogbookTablePageState();
}

class _LogbookTablePageState extends State<_LogbookTablePage> {
  static const _batchSize = 50;
  final _filterButtonAnchor = GlobalKey();
  final List<Map<String, dynamic>> _records = [];
  bool _loading = false;
  bool _refreshing = false;
  bool _refreshQueued = false;
  bool _hasMore = true;
  Map<String, String> _filters = const <String, String>{};
  SortieFilterCatalog? _sortieFilterCatalog;
  Future<void>? _sortieCatalogLoading;
  Map<String, List<SortieMapIdentity>> _sortieMapsByLabel = const {};
  Map<String, List<String>> _sortieStatusesByLabel = const {};
  int _catalogGeneration = 0;
  int _queryGeneration = 0;
  BattleDetailSnapshot? _selectedDetail;
  int? _loadingDetailRowId;

  @override
  void initState() {
    super.initState();
    _changeSignal(widget).addListener(_refreshLatest);
    _loadSortieFilterCatalog();
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant _LogbookTablePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database ||
        oldWidget.category != widget.category) {
      _changeSignal(oldWidget).removeListener(_refreshLatest);
      _changeSignal(widget).addListener(_refreshLatest);
      _catalogGeneration += 1;
      _sortieFilterCatalog = null;
      _sortieMapsByLabel = const {};
      _sortieStatusesByLabel = const {};
      _selectedDetail = null;
      _loadingDetailRowId = null;
      _queryGeneration += 1;
      _records.clear();
      _loading = false;
      _refreshing = false;
      _refreshQueued = false;
      _hasMore = true;
      _loadSortieFilterCatalog();
    }
    _refreshLatest();
  }

  @override
  void dispose() {
    _changeSignal(widget).removeListener(_refreshLatest);
    super.dispose();
  }

  Listenable _changeSignal(_LogbookTablePage page) =>
      page.database.changesFor(switch (page.category) {
        _LogbookCategory.sortie => LogbookChangeCategory.battle,
        _LogbookCategory.expedition => LogbookChangeCategory.expedition,
        _LogbookCategory.construction => LogbookChangeCategory.construction,
        _LogbookCategory.development => LogbookChangeCategory.development,
        _LogbookCategory.retirement => LogbookChangeCategory.retirement,
        _LogbookCategory.resource => LogbookChangeCategory.resource,
      });

  Future<void> _refreshLatest() async {
    if (!mounted) return;
    _loadSortieFilterCatalog(force: true);
    if (_refreshing || _loading) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    final generation = _queryGeneration;
    try {
      final latest = await _queryRecords();
      if (!mounted || generation != _queryGeneration) return;
      if (latest.isEmpty) {
        setState(() {
          _records.clear();
          _hasMore = false;
        });
        return;
      }
      final latestIds = latest.map((row) => row['id']).toSet();
      final older = _records
          .where((row) => !latestIds.contains(row['id']))
          .toList(growable: false);
      setState(() {
        _records
          ..clear()
          ..addAll(latest)
          ..addAll(older);
      });
    } finally {
      if (generation == _queryGeneration) _refreshing = false;
      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        Future<void>.microtask(_refreshLatest);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    final generation = _queryGeneration;
    try {
      final beforeId = _records.isEmpty ? null : _records.last['id'] as int?;
      final next = await _queryRecords(beforeId: beforeId);
      if (!mounted || generation != _queryGeneration) return;
      setState(() {
        _records.addAll(next);
        _hasMore = next.length == _batchSize;
      });
    } finally {
      if (generation == _queryGeneration) _loading = false;
    }
  }

  Future<void> _loadSortieFilterCatalog({bool force = false}) {
    if (widget.category != _LogbookCategory.sortie) {
      return Future<void>.value();
    }
    final existing = _sortieCatalogLoading;
    if (!force) {
      if (existing != null) return existing;
      if (_sortieFilterCatalog != null) return Future<void>.value();
    }

    final generation = ++_catalogGeneration;
    late final Future<void> operation;
    operation = widget.database
        .getSortieFilterCatalog()
        .then((catalog) {
          if (!mounted || generation != _catalogGeneration) return;
          final mapsByLabel = <String, List<SortieMapIdentity>>{};
          for (final map in catalog.maps) {
            final label = _formatMapLabel(<String, Object?>{
              'map_area': map.mapArea,
              'map_no': map.mapNo,
              'map_name': map.mapName,
              'map_difficulty': map.mapDifficulty,
            });
            mapsByLabel.putIfAbsent(label, () => []).add(map);
          }
          final statusesByLabel = <String, List<String>>{};
          for (final status in catalog.statuses) {
            final label = status == sortieResourceStatusToken
                ? _l10n.logbookResourceNode
                : sortieStatusLabel(status);
            statusesByLabel.putIfAbsent(label, () => []).add(status);
          }
          final selectedMap = _filters['map'];
          final selectedStatus = _filters['status'];
          setState(() {
            _sortieFilterCatalog = catalog;
            _sortieMapsByLabel = mapsByLabel;
            _sortieStatusesByLabel = statusesByLabel;
            if (selectedMap != null &&
                selectedMap != '全部海域' &&
                !mapsByLabel.containsKey(selectedMap)) {
              _filters = <String, String>{..._filters, 'map': '全部海域'};
            }
            if (selectedStatus != null &&
                selectedStatus != '全部状态' &&
                !statusesByLabel.containsKey(selectedStatus)) {
              _filters = <String, String>{..._filters, 'status': '全部状态'};
            }
          });
        })
        .catchError((Object _) {})
        .whenComplete(() {
          if (identical(_sortieCatalogLoading, operation)) {
            _sortieCatalogLoading = null;
          }
        });
    _sortieCatalogLoading = operation;
    return operation;
  }

  SortieRecordQuery get _sortieRecordQuery {
    final date = _filters['date'] ?? '全部日期';
    final days = switch (date) {
      '最近 7 天' => 7,
      '最近 30 天' => 30,
      _ => null,
    };
    final map = _filters['map'] ?? '全部海域';
    final status = _filters['status'] ?? '全部状态';
    final rank = _filters['rank'] ?? '全部评价';
    return SortieRecordQuery(
      sinceTimestamp: days == null
          ? null
          : DateTime.now()
                .subtract(Duration(days: days))
                .millisecondsSinceEpoch,
      maps: map == '全部海域'
          ? const <SortieMapIdentity>[]
          : _sortieMapsByLabel[map] ?? const <SortieMapIdentity>[],
      statuses: status == '全部状态'
          ? const <String>[]
          : _sortieStatusesByLabel[status] ?? const <String>[],
      rank: rank == '全部评价' ? null : rank,
    );
  }

  Future<List<Map<String, dynamic>>> _queryRecords({int? beforeId}) =>
      switch (widget.category) {
        _LogbookCategory.sortie => widget.database.getSortieRecords(
          limit: _batchSize,
          offset: beforeId == null ? 0 : _records.length,
          query: _sortieRecordQuery,
        ),
        _LogbookCategory.expedition => widget.database.getExpeditionRecords(
          limit: _batchSize,
          beforeId: beforeId,
        ),
        _LogbookCategory.construction => widget.database.getConstructionRecords(
          limit: _batchSize,
          beforeId: beforeId,
        ),
        _LogbookCategory.development => widget.database.getDevelopmentRecords(
          limit: _batchSize,
          beforeId: beforeId,
        ),
        _LogbookCategory.retirement => widget.database.getRetirementRecords(
          limit: _batchSize,
          beforeId: beforeId,
        ),
        _LogbookCategory.resource => Future.value(
          const <Map<String, dynamic>>[],
        ),
      };

  List<Map<String, dynamic>> get _visibleRecords {
    return _records.where(_matchesFilter).toList(growable: false);
  }

  String _sortieStatus(Map<String, dynamic> record) =>
      record['record_type'] == 'resource'
      ? _l10n.logbookResourceNode
      : sortieStatusLabel(record['node_type']);

  AppLocalizations get _l10n =>
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));

  bool _matchesFilter(Map<String, dynamic> record) {
    final date = _filters['date'] ?? '全部日期';
    final timestamp = record['timestamp'] as int? ?? 0;
    if (date != '全部日期') {
      final days = date == '最近 7 天' ? 7 : 30;
      final threshold = DateTime.now()
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch;
      if (timestamp < threshold) return false;
    }

    bool selected(String key, String allLabel, Object? actual) {
      final expected = _filters[key] ?? allLabel;
      return expected == allLabel || expected == '$actual';
    }

    return switch (widget.category) {
      _LogbookCategory.sortie =>
        selected('map', '全部海域', _fullMapLabel(record)) &&
            selected('status', '全部状态', _sortieStatus(record)) &&
            selected('rank', '全部评价', '${record['rank']}'.toUpperCase()),
      _LogbookCategory.expedition =>
        selected('mission', '全部远征', _expeditionName(record)) &&
            selected('result', '全部结果', _expeditionResult(record['result'])) &&
            _matchesRewardFilter(record),
      _LogbookCategory.construction =>
        selected('constructionType', '全部类型', record['construction_type']) &&
            selected('shipType', '全部舰种', record['ship_type']) &&
            selected('secretary', '全部秘书舰', record['secretary_name']),
      _LogbookCategory.development =>
        selected(
              'result',
              '全部结果',
              (record['success'] as int? ?? 0) > 0 ? '成功' : '失败',
            ) &&
            selected('equipmentType', '全部类型', record['equipment_type']) &&
            selected('secretary', '全部秘书舰', record['secretary_name']),
      _LogbookCategory.retirement =>
        selected('type', '全部类型', record['type']) &&
            selected('shipType', '全部舰种', record['ship_type']),
      _LogbookCategory.resource => true,
    };
  }

  bool _matchesRewardFilter(Map<String, dynamic> record) {
    final expected = _filters['item'] ?? '全部道具';
    if (expected == '全部道具') return true;
    final hasItem =
        (record['item1_count'] as int? ?? 0) > 0 ||
        (record['item2_count'] as int? ?? 0) > 0;
    return expected == (hasItem ? '有道具' : '无道具');
  }

  List<String> _distinct(String allLabel, Iterable<String> values) {
    final options = values.where((value) => value.isNotEmpty).toSet().toList()
      ..sort();
    return <String>[allLabel, ...options];
  }

  Map<String, String> get _filterDefaults => switch (widget.category) {
    _LogbookCategory.sortie => const {
      'date': '全部日期',
      'map': '全部海域',
      'status': '全部状态',
      'rank': '全部评价',
    },
    _LogbookCategory.expedition => const {
      'date': '全部日期',
      'mission': '全部远征',
      'result': '全部结果',
      'item': '全部道具',
    },
    _LogbookCategory.construction => const {
      'date': '全部日期',
      'constructionType': '全部类型',
      'shipType': '全部舰种',
      'secretary': '全部秘书舰',
    },
    _LogbookCategory.development => const {
      'date': '全部日期',
      'result': '全部结果',
      'equipmentType': '全部类型',
      'secretary': '全部秘书舰',
    },
    _LogbookCategory.retirement => const {
      'date': '全部日期',
      'type': '全部类型',
      'shipType': '全部舰种',
    },
    _LogbookCategory.resource => const <String, String>{},
  };

  List<LogbookFilterField> get _filterFields {
    const dates = <String>['全部日期', '最近 7 天', '最近 30 天'];
    return switch (widget.category) {
      _LogbookCategory.sortie => [
        const LogbookFilterField(keyName: 'date', label: '日期', options: dates),
        LogbookFilterField(
          keyName: 'map',
          label: '海域',
          options: _distinct(
            '全部海域',
            _sortieFilterCatalog == null
                ? _records.map(_fullMapLabel)
                : _sortieMapsByLabel.keys,
          ),
        ),
        LogbookFilterField(
          keyName: 'status',
          label: '状态',
          options: _distinct(
            '全部状态',
            _sortieFilterCatalog == null
                ? _records.map(_sortieStatus)
                : _sortieStatusesByLabel.keys,
          ),
        ),
        const LogbookFilterField(
          keyName: 'rank',
          label: '评价',
          options: ['全部评价', 'SS', 'S', 'A', 'B', 'C', 'D', 'E'],
        ),
      ],
      _LogbookCategory.expedition => [
        const LogbookFilterField(keyName: 'date', label: '日期', options: dates),
        LogbookFilterField(
          keyName: 'mission',
          label: '远征',
          options: _distinct('全部远征', _records.map(_expeditionName)),
        ),
        const LogbookFilterField(
          keyName: 'result',
          label: '结果',
          options: ['全部结果', '大成功', '成功', '失败'],
        ),
        const LogbookFilterField(
          keyName: 'item',
          label: '道具',
          options: ['全部道具', '有道具', '无道具'],
        ),
      ],
      _LogbookCategory.construction => [
        const LogbookFilterField(keyName: 'date', label: '日期', options: dates),
        const LogbookFilterField(
          keyName: 'constructionType',
          label: '建造类型',
          options: ['全部类型', '普通建造', '大型建造'],
        ),
        LogbookFilterField(
          keyName: 'shipType',
          label: '舰种',
          options: _distinct(
            '全部舰种',
            _records.map((row) => '${row['ship_type']}'),
          ),
        ),
        LogbookFilterField(
          keyName: 'secretary',
          label: '秘书舰',
          options: _distinct(
            '全部秘书舰',
            _records.map((row) => '${row['secretary_name']}'),
          ),
        ),
      ],
      _LogbookCategory.development => [
        const LogbookFilterField(keyName: 'date', label: '日期', options: dates),
        const LogbookFilterField(
          keyName: 'result',
          label: '结果',
          options: ['全部结果', '成功', '失败'],
        ),
        LogbookFilterField(
          keyName: 'equipmentType',
          label: '装备类型',
          options: _distinct(
            '全部类型',
            _records.map((row) => '${row['equipment_type']}'),
          ),
        ),
        LogbookFilterField(
          keyName: 'secretary',
          label: '秘书舰',
          options: _distinct(
            '全部秘书舰',
            _records.map((row) => '${row['secretary_name']}'),
          ),
        ),
      ],
      _LogbookCategory.retirement => [
        const LogbookFilterField(keyName: 'date', label: '日期', options: dates),
        const LogbookFilterField(
          keyName: 'type',
          label: '类型',
          options: ['全部类型', '改修', '解体'],
        ),
        LogbookFilterField(
          keyName: 'shipType',
          label: '舰种',
          options: _distinct(
            '全部舰种',
            _records.map((row) => '${row['ship_type']}'),
          ),
        ),
      ],
      _LogbookCategory.resource => const <LogbookFilterField>[],
    };
  }

  Future<void> _showFilter() async {
    if (widget.category == _LogbookCategory.sortie) {
      await _loadSortieFilterCatalog();
      if (!mounted) return;
    }
    final button =
        _filterButtonAnchor.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) return;
    final origin = button.localToGlobal(Offset.zero);
    final defaults = _filterDefaults;
    final selected = await showLogbookFilterPanel(
      context: context,
      anchor: origin & button.size,
      title: '筛选${widget.category.label}记录',
      fields: _filterFields,
      values: <String, String>{...defaults, ..._filters},
      defaults: defaults,
    );
    if (selected == null || !mounted) return;
    if (widget.category != _LogbookCategory.sortie) {
      setState(() => _filters = selected);
      return;
    }
    _queryGeneration += 1;
    _loading = false;
    _refreshing = false;
    _refreshQueued = false;
    setState(() {
      _filters = selected;
      _records.clear();
      _hasMore = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRecords;
    return IndexedStack(
      index: _selectedDetail == null ? 0 : 1,
      children: <Widget>[
        _buildRecordList(rows),
        if (_selectedDetail case final detail?)
          BattleDetailPage(
            detail: detail,
            onBack: () => setState(() => _selectedDetail = null),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildRecordList(List<Map<String, dynamic>> rows) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  child: UiText(
                    '共 ${rows.length} 条',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff8ba2af),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                KeyedSubtree(
                  key: _filterButtonAnchor,
                  child: HeaderFilterIconButton(
                    key: const Key('logbook-filter-button'),
                    icon: Icons.filter_alt_outlined,
                    active: _filters.entries.any(
                      (entry) => _filterDefaults[entry.key] != entry.value,
                    ),
                    tooltip: uiText(context, '筛选${widget.category.label}记录'),
                    onPressed: _showFilter,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildTable(rows)),
                if (rows.isEmpty && !_loading)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: UiText(
                          '暂无记录',
                          style: TextStyle(
                            color: Color(0xff8197a5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (rows.isEmpty && _loading)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> rows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = _tableSpecForWidth(constraints.maxWidth);
        return FrozenDataTable(
          key: Key('logbook-table-${widget.category.name}'),
          keyPrefix: 'logbook-${widget.category.name}',
          frozenColumnWidths: _frozenColumnWidths,
          frozenHeaders: _frozenHeaders,
          frozenCells: (index) => _frozenCells(rows[index]),
          scrollableColumnWidths: spec.widths,
          scrollableHeaders: spec.headers,
          scrollableCells: (index) => spec.cells(rows[index]),
          rowHeights: [for (final row in rows) _rowHeight(row, context)],
          onEndReached: _loadMore,
          onRowTap: widget.category == _LogbookCategory.sortie
              ? (index) => _openBattleDetail(rows[index])
              : null,
          rowTapEnabled: (index) => _hasBattleDetail(rows[index]),
          selectedRowIndex: _loadingDetailRowId == null
              ? null
              : rows.indexWhere((row) => row['id'] == _loadingDetailRowId),
        );
      },
    );
  }

  bool _hasBattleDetail(Map<String, dynamic> row) =>
      widget.category == _LogbookCategory.sortie &&
      row['record_type'] == 'battle' &&
      (row['has_detail'] as int? ?? 0) == 1;

  Future<void> _openBattleDetail(Map<String, dynamic> row) async {
    if (!_hasBattleDetail(row) || _loadingDetailRowId != null) return;
    final rowId = row['id'] as int?;
    if (rowId == null) return;
    setState(() => _loadingDetailRowId = rowId);
    final detail = await widget.database.getBattleDetail(rowId ~/ 2);
    if (!mounted || _loadingDetailRowId != rowId) return;
    setState(() {
      _loadingDetailRowId = null;
      _selectedDetail = detail;
    });
  }

  double _rowHeight(Map<String, dynamic> row, BuildContext context) {
    if (widget.category != _LogbookCategory.sortie ||
        row['record_type'] != 'battle') {
      return FrozenDataTable.minimumRowHeight;
    }
    final label = _heavyDamageShipNames(row).join('、');
    if (label.isEmpty) return FrozenDataTable.minimumRowHeight;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: _effectiveHeavyDamageTextStyle(context),
      ),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
    try {
      painter.layout(
        maxWidth: _heavyDamageColumnWidth - _heavyDamageHorizontalPadding * 2,
      );
      final measuredHeight = painter.height + 12;
      return measuredHeight > FrozenDataTable.minimumRowHeight
          ? measuredHeight
          : FrozenDataTable.minimumRowHeight;
    } finally {
      painter.dispose();
    }
  }

  List<double> get _frozenColumnWidths => switch (widget.category) {
    _LogbookCategory.sortie => const [220],
    _LogbookCategory.expedition => const [205],
    _LogbookCategory.construction => const [105],
    _LogbookCategory.development => const [220],
    _LogbookCategory.retirement => const [],
    _ => const [112],
  };

  List<Widget> get _frozenHeaders => switch (widget.category) {
    _LogbookCategory.sortie => const [_HeaderCell('海域')],
    _LogbookCategory.expedition => const [_HeaderCell('远征')],
    _LogbookCategory.construction => const [_HeaderCell('舰娘')],
    _LogbookCategory.development => const [_HeaderCell('开发装备')],
    _LogbookCategory.retirement => const [],
    _ => const [_HeaderCell('时间')],
  };

  List<Widget> _frozenCells(Map<String, dynamic> row) =>
      switch (widget.category) {
        _LogbookCategory.sortie => [_TextCell(_mapLabel(row))],
        _LogbookCategory.expedition => [
          _TextCell(_expeditionLabel(row), strong: true),
        ],
        _LogbookCategory.construction => [
          _TextCell('${row['ship_name']}', strong: true),
        ],
        _LogbookCategory.development => [
          _EquipmentCell(
            name: '${row['equipment_name']}',
            iconId: row['equipment_icon_id'] as int? ?? -1,
          ),
        ],
        _LogbookCategory.retirement => const [],
        _ => [_TextCell(_formatTime(row['timestamp']))],
      };

  _TableSpec _tableSpecForWidth(double availableWidth) {
    if (widget.category == _LogbookCategory.sortie) {
      final spec = _tableSpec;
      final widths = List<double>.of(spec.widths);
      final scrollableWidth = availableWidth - 220;
      final baseWidth = widths.fold<double>(0, (sum, width) => sum + width);
      if (scrollableWidth > baseWidth) {
        widths[8] += scrollableWidth - baseWidth;
      }
      return _TableSpec(
        widths: widths,
        headers: spec.headers,
        cells: spec.cells,
      );
    }
    if (widget.category == _LogbookCategory.expedition) {
      final spec = _tableSpec;
      const frozenWidth = 205.0;
      const timeWidth = 92.0;
      const resultWidth = 64.0;
      const resourceWidth = 70.0;
      const minimumRewardWidth = 120.0;
      const fixedScrollableWidth = timeWidth + resultWidth + resourceWidth * 4;
      final scrollableViewportWidth = (availableWidth - frozenWidth).clamp(
        0.0,
        double.infinity,
      );
      final rewardWidth = (scrollableViewportWidth - fixedScrollableWidth)
          .clamp(minimumRewardWidth, double.infinity);
      return _TableSpec(
        widths: [
          timeWidth,
          resultWidth,
          resourceWidth,
          resourceWidth,
          resourceWidth,
          resourceWidth,
          rewardWidth,
        ],
        headers: spec.headers,
        cells: spec.cells,
      );
    }
    if (widget.category != _LogbookCategory.retirement) return _tableSpec;
    final scrollableWidth = availableWidth.clamp(564.0, double.infinity);
    const timeWidth = 112.0;
    final detailWidth = scrollableWidth - timeWidth;
    final typeWidth = detailWidth * 0.2;
    final shipTypeWidth = detailWidth * 0.28;
    return _TableSpec(
      widths: [
        timeWidth,
        typeWidth,
        shipTypeWidth,
        detailWidth - typeWidth - shipTypeWidth,
      ],
      headers: const [
        _HeaderCell('时间'),
        _HeaderCell('类型'),
        _HeaderCell('舰种'),
        _HeaderCell('舰娘'),
      ],
      cells: (row) => [
        _TextCell(_formatTime(row['timestamp'])),
        _RetirementTypeCell('${row['type']}'),
        _TextCell('${row['ship_type']}'),
        _TextCell('${row['ship_name']} Lv.${row['level']}', strong: true),
      ],
    );
  }

  _TableSpec get _tableSpec => switch (widget.category) {
    _LogbookCategory.sortie => _TableSpec(
      widths: const [
        112,
        90,
        85,
        96,
        96,
        102,
        _heavyDamageColumnWidth,
        68,
        180,
        120,
        145,
        220,
        135,
        135,
        135,
        135,
      ],
      headers: [
        const _HeaderCell('时间'),
        const _HeaderCell('节点'),
        const _HeaderCell('状态'),
        _HeaderCell(_l10n.logbookFriendFormation),
        _HeaderCell(_l10n.logbookEnemyFormation),
        _HeaderCell(_l10n.logbookAirSuperiority),
        _HeaderCell(_l10n.logbookHeavyDamageShips),
        const _HeaderCell('评价'),
        const _HeaderCell('敌舰队'),
        const _HeaderCell('掉落'),
        _HeaderCell(_l10n.logbookResourceDrop),
        _HeaderCell(_l10n.logbookItemDrop),
        const _HeaderCell('旗舰'),
        const _HeaderCell('MVP'),
        const _HeaderCell('二队旗舰'),
        const _HeaderCell('二队 MVP'),
      ],
      cells: (row) => [
        _TextCell(_formatTime(row['timestamp'])),
        _TextCell(
          ((row['map_area'] as int? ?? 0) == 0 &&
                      (row['map_no'] as int? ?? 0) == 0) ||
                  row['map_name']?.toString().trim() == '演习'
              ? '-'
              : _sortieNodeLabel(
                  row['node'],
                  row['node_type'],
                  resolvedLabel: row['node_label'],
                ),
        ),
        _TextCell(_sortieStatus(row), strong: true),
        _FormationCell(
          formation: _rowInt(row['friend_formation']),
          friendly: true,
        ),
        _FormationCell(
          formation: _rowInt(row['enemy_formation']),
          friendly: false,
        ),
        _AirSuperiorityCell(row),
        _HeavyDamageCell(row),
        _RankCell('${row['rank']}'),
        _TextCell(
          ((row['map_area'] as int? ?? 0) == 0 &&
                      (row['map_no'] as int? ?? 0) == 0) ||
                  row['map_name']?.toString().trim() == '演习' ||
                  row['enemy_fleet_name'] == '-'
              ? '-'
              : '${row['enemy_fleet_name']}',
        ),
        _TextCell(_dropNames(row), color: const Color(0xff67bce9)),
        _SortieResourceCell(row),
        _SortieRewardItemsCell(row),
        _TextCell(_formatShipName(row['flagship_name']), strong: true),
        _TextCell(_formatShipName(row['mvp_name']), strong: true),
        _TextCell(_formatShipName(row['escort_flagship_name']), strong: true),
        _TextCell(_formatShipName(row['escort_mvp_name']), strong: true),
      ],
    ),
    _LogbookCategory.expedition => _TableSpec(
      widths: const [112, 86, 82, 82, 82, 82, 480],
      headers: const [
        _HeaderCell('时间'),
        _HeaderCell('结果'),
        _ResourceHeader(GameResourceType.fuel),
        _ResourceHeader(GameResourceType.ammunition),
        _ResourceHeader(GameResourceType.steel),
        _ResourceHeader(GameResourceType.bauxite),
        _HeaderCell('道具'),
      ],
      cells: (row) => [
        _TextCell(_formatTime(row['timestamp'])),
        _ResultCell(_expeditionResult(row['result'])),
        _TextCell('${row['yield_fuel'] ?? 0}'),
        _TextCell('${row['yield_ammo'] ?? 0}'),
        _TextCell('${row['yield_steel'] ?? 0}'),
        _TextCell('${row['yield_bauxite'] ?? 0}'),
        _RewardItemsCell(row),
      ],
    ),
    _LogbookCategory.construction => _TableSpec(
      widths: const [112, 110, 95, 82, 82, 82, 82, 105, 190],
      headers: const [
        _HeaderCell('时间'),
        _HeaderCell('建造类型'),
        _HeaderCell('舰种'),
        _ResourceHeader(GameResourceType.fuel),
        _ResourceHeader(GameResourceType.ammunition),
        _ResourceHeader(GameResourceType.steel),
        _ResourceHeader(GameResourceType.bauxite),
        _ResourceHeader(GameResourceType.developmentMaterial),
        _HeaderCell('秘书舰'),
      ],
      cells: (row) => [
        _TextCell(_formatTime(row['timestamp'])),
        _TextCell('${row['construction_type']}'),
        _TextCell('${row['ship_type']}'),
        _TextCell('${row['fuel']}'),
        _TextCell('${row['ammo']}'),
        _TextCell('${row['steel']}'),
        _TextCell('${row['bauxite']}'),
        _TextCell('${row['development_material']}'),
        _TextCell('${row['secretary_name']}'),
      ],
    ),
    _LogbookCategory.development => _TableSpec(
      widths: const [120, 112, 82, 82, 82, 82, 82, 190],
      headers: const [
        _HeaderCell('装备类型'),
        _HeaderCell('时间'),
        _HeaderCell('结果'),
        _ResourceHeader(GameResourceType.fuel),
        _ResourceHeader(GameResourceType.ammunition),
        _ResourceHeader(GameResourceType.steel),
        _ResourceHeader(GameResourceType.bauxite),
        _HeaderCell('秘书舰'),
      ],
      cells: (row) => [
        _TextCell('${row['equipment_type']}'),
        _TextCell(_formatTime(row['timestamp'])),
        _ResultCell((row['success'] as int? ?? 0) > 0 ? '成功' : '失败'),
        _TextCell('${row['fuel']}'),
        _TextCell('${row['ammo']}'),
        _TextCell('${row['steel']}'),
        _TextCell('${row['bauxite']}'),
        _TextCell('${row['secretary_name']}'),
      ],
    ),
    _LogbookCategory.retirement => _TableSpec(
      widths: const [112, 92, 130, 230],
      headers: const [
        _HeaderCell('时间'),
        _HeaderCell('类型'),
        _HeaderCell('舰种'),
        _HeaderCell('舰娘'),
      ],
      cells: (row) => [
        _TextCell(_formatTime(row['timestamp'])),
        _RetirementTypeCell('${row['type']}'),
        _TextCell('${row['ship_type']}'),
        _TextCell('${row['ship_name']} Lv.${row['level']}', strong: true),
      ],
    ),
    _LogbookCategory.resource => throw StateError('资源页不使用日志表格'),
  };

  String _dropName(Object? value) {
    final id = value as int? ?? 0;
    if (id <= 0) return '-';
    return widget.battleController.gameState().masterShips[id]?.name ??
        'ID: $id';
  }

  String _dropNames(Map<String, dynamic> row) {
    final encoded = row['drop_ship_ids_json']?.toString() ?? '';
    if (encoded.isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          final names = <String>[
            for (final value in decoded)
              if (_rowInt(value) > 0) _dropName(_rowInt(value)),
          ];
          if (names.isNotEmpty) return names.join('、');
        }
      } on FormatException {
        // Older rows continue through the legacy single-drop column.
      }
    }
    return _dropName(row['drop_ship_id']);
  }

  String _formatShipName(Object? raw) {
    final str = raw?.toString().trim() ?? '';
    if (str.isEmpty || str == '—' || str == '-') return '-';
    return str;
  }

  String _mapLabel(Map<String, dynamic> row) =>
      _formatMapLabel(row, truncateName: true);

  String _fullMapLabel(Map<String, dynamic> row) => _formatMapLabel(row);

  String _expeditionLabel(Map<String, dynamic> row) {
    final id = row['expedition_id'] as int? ?? 0;
    final master = _expeditionMaster(row);
    final displayNumber = master?.displayNumber.trim() ?? '';
    return '${displayNumber.isEmpty ? _expeditionDisplayId(id) : displayNumber}'
        ' · ${_expeditionName(row)}';
  }

  String _expeditionName(Map<String, dynamic> row) {
    final masterName = _expeditionMaster(row)?.name.trim();
    return masterName == null || masterName.isEmpty
        ? '${row['name']}'
        : masterName;
  }

  MasterMission? _expeditionMaster(Map<String, dynamic> row) {
    final missions = widget.battleController.gameStateSnapshot.masterMissions;
    final id = row['expedition_id'] as int? ?? 0;
    final byId = missions[id];
    if (byId != null) return byId;

    final storedName = row['name']?.toString().trim() ?? '';
    if (storedName.isEmpty) return null;
    for (final mission in missions.values) {
      if (mission.name.trim() == storedName) return mission;
    }
    return null;
  }

  String _formatMapLabel(
    Map<String, dynamic> row, {
    bool truncateName = false,
  }) {
    final area = row['map_area'] as int? ?? 0;
    final map = row['map_no'] as int? ?? 0;
    final storedName = row['map_name']?.toString().trim() ?? '';
    if ((area == 0 && map == 0) || storedName == '演习') {
      return '演习';
    }
    final number = '$area-$map';
    final name = storedName.isNotEmpty
        ? storedName
        : widget.battleController.gameState().mapName(area, map);
    final difficulty = _mapDifficultyLabel(row['map_difficulty']);
    final suffix = difficulty.isEmpty ? number : '$number $difficulty';
    if (name == null || name.isEmpty) return suffix;
    final displayName = truncateName ? _truncateMapName(name) : name;
    return '$displayName ($suffix)';
  }
}

class _TableSpec {
  const _TableSpec({
    required this.widths,
    required this.headers,
    required this.cells,
  });
  final List<double> widths;
  final List<Widget> headers;
  final List<Widget> Function(Map<String, dynamic>) cells;
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        uiText(context, label),
        maxLines: 1,
        style: const TextStyle(
          color: Color(0xff9fb3bf),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _ResourceHeader extends StatelessWidget {
  const _ResourceHeader(this.type);
  final GameResourceType type;

  @override
  Widget build(BuildContext context) {
    final spec = headerResourceById['material-${type.apiId}']!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Image.asset(
            spec.assetPath,
            key: Key('logbook-resource-icon-${type.name}'),
            width: 18,
            height: 18,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              uiText(context, type.label),
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xff9fb3bf),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell(
    this.value, {
    this.color = const Color(0xffd7e3e9),
    this.strong = false,
  });
  final String value;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        BattleDetailStrings.of(context).localize(uiText(context, value)),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ),
  );
}

class _FormationCell extends StatelessWidget {
  const _FormationCell({required this.formation, required this.friendly});

  final int formation;
  final bool friendly;

  @override
  Widget build(BuildContext context) {
    if (formation <= 0) return const _TextCell('-');
    return _SortieSummaryPill(
      pillKey: Key(
        friendly
            ? 'logbook-friend-formation-pill'
            : 'logbook-enemy-formation-pill',
      ),
      label: BattleDetailStrings.of(
        context,
      ).localize(formationLabel(formation)),
      background: friendly ? const Color(0xff183e38) : const Color(0xff46211e),
      foreground: friendly ? const Color(0xff83d5c8) : const Color(0xffff8c78),
      border: friendly ? const Color(0xff2f7469) : const Color(0xffa0453a),
    );
  }
}

class _AirSuperiorityCell extends StatelessWidget {
  const _AirSuperiorityCell(this.row);

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    if (row['record_type'] != 'battle') return const _TextCell('-');
    final label = row['air_superiority']?.toString().trim();
    final displayLabel = _localizedAirSuperiorityLabel(context, label);
    final colors = airSuperiorityPillColors(label ?? '');
    return _SortieSummaryPill(
      pillKey: const Key('logbook-air-superiority-pill'),
      label: displayLabel,
      background: colors.background,
      foreground: colors.foreground,
      border: colors.border,
    );
  }
}

String _localizedAirSuperiorityLabel(BuildContext context, String? label) {
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  final normalized = label == null || label.isEmpty ? -1 : _airStateCode(label);
  return switch (normalized) {
    -1 => l10n.statusUnknown,
    0 => l10n.airSuperiorityParity,
    1 => l10n.airSuperioritySecured,
    2 => l10n.airSuperiorityAdvantage,
    3 => l10n.airSuperiorityDisadvantage,
    4 => l10n.airSuperiorityLost,
    _ => label ?? l10n.statusUnknown,
  };
}

int? _airStateCode(String label) {
  for (final entry in kAirSuperiorityLabels.entries) {
    if (entry.value == label) return entry.key;
  }
  return null;
}

class _SortieSummaryPill extends StatelessWidget {
  const _SortieSummaryPill({
    required this.pillKey,
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Key pillKey;
  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        key: pillKey,
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: SizedBox(
          height: 22,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                BattleDetailStrings.of(context).localize(label),
                maxLines: 1,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

const _heavyDamageTextStyle = TextStyle(
  color: Color(0xffff8c78),
  fontSize: 12,
  fontWeight: FontWeight.w900,
  fontFeatures: [FontFeature.tabularFigures()],
);

TextStyle _effectiveHeavyDamageTextStyle(BuildContext context) =>
    DefaultTextStyle.of(context).style.merge(_heavyDamageTextStyle);

class _HeavyDamageCell extends StatelessWidget {
  const _HeavyDamageCell(this.row);

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final label = _heavyDamageShipNames(row).join('、');
    if (label.isEmpty) return const _TextCell('-');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _heavyDamageHorizontalPadding,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          softWrap: true,
          style: _effectiveHeavyDamageTextStyle(context),
        ),
      ),
    );
  }
}

List<String> _heavyDamageShipNames(Map<String, dynamic> row) {
  if (row['record_type'] != 'battle') return const <String>[];
  final encoded = row['heavy_damage_ship_names_json']?.toString() ?? '[]';
  try {
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return const <String>[];
    final names = <String>[];
    for (final value in decoded) {
      if (value is! String) return const <String>[];
      final name = value.trim();
      if (name.isEmpty) return const <String>[];
      names.add(name);
    }
    return names;
  } catch (_) {
    return const <String>[];
  }
}

class _ResultCell extends StatelessWidget {
  const _ResultCell(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => _TextCell(
    value,
    color: switch (value) {
      '大成功' => const Color(0xffffc857),
      '成功' => const Color(0xff48d88a),
      '失败' => const Color(0xffff6464),
      _ => const Color(0xffd7e3e9),
    },
    strong: true,
  );
}

class _RankCell extends StatelessWidget {
  const _RankCell(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    final label = value.toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          key: Key('logbook-rank-$label'),
          decoration: BoxDecoration(
            color: const Color(0xff2c2015),
            border: Border.all(color: const Color(0xfff9a825)),
            borderRadius: BorderRadius.circular(11),
          ),
          child: SizedBox(
            width: 32,
            height: 22,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xffffd700),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetirementTypeCell extends StatelessWidget {
  const _RetirementTypeCell(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => _TextCell(
    value,
    color: value == '改修' ? const Color(0xff67bce9) : const Color(0xffff6464),
    strong: true,
  );
}

class _EquipmentCell extends StatelessWidget {
  const _EquipmentCell({required this.name, required this.iconId});
  final String name;
  final int iconId;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Row(
      children: [
        EquipmentTypeIconImage(
          iconId: iconId,
          width: 24,
          height: 24,
          imageKey: const Key('logbook-development-equipment-icon'),
        ),
        const SizedBox(width: 5),
        Expanded(child: _TextCell(name, strong: true)),
      ],
    ),
  );
}

class _SortieResourceCell extends StatelessWidget {
  const _SortieResourceCell(this.row);

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final values = <(GameResourceType, int)>[
      (GameResourceType.fuel, _rowInt(row['fuel_delta'])),
      (GameResourceType.ammunition, _rowInt(row['ammo_delta'])),
      (GameResourceType.steel, _rowInt(row['steel_delta'])),
      (GameResourceType.bauxite, _rowInt(row['bauxite_delta'])),
      (GameResourceType.instantBuild, _rowInt(row['instant_build_delta'])),
      (GameResourceType.instantRepair, _rowInt(row['instant_repair_delta'])),
      (
        GameResourceType.developmentMaterial,
        _rowInt(row['development_material_delta']),
      ),
      (
        GameResourceType.improvementMaterial,
        _rowInt(row['improvement_material_delta']),
      ),
    ].where((entry) => entry.$2 != 0).toList(growable: false);
    if (values.isEmpty) return const _TextCell('-');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < values.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 8),
            Image.asset(
              'assets/images/material/${values[index].$1.apiId.toString().padLeft(2, '0')}.png',
              key: Key('logbook-resource-icon-${values[index].$1.apiId}'),
              width: 17,
              height: 17,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 2),
            Text(
              values[index].$2 > 0
                  ? '+${values[index].$2}'
                  : '${values[index].$2}',
              style: TextStyle(
                color: values[index].$2 > 0
                    ? const Color(0xff83d5c8)
                    : const Color(0xffff8c78),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SortieRewardItemsCell extends StatelessWidget {
  const _SortieRewardItemsCell(this.row);

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final rewards = _expeditionRewards(row);
    return _TextCell(
      rewards.isEmpty
          ? '-'
          : rewards
                .map((reward) => '${reward.name} ×${reward.count}')
                .join('　'),
      color: const Color(0xff83d5c8),
      strong: rewards.isNotEmpty,
    );
  }
}

class _RewardItemsCell extends StatelessWidget {
  const _RewardItemsCell(this.row);
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final items = <InlineSpan>[];
    void add(_ExpeditionRewardData reward) {
      final id = reward.id;
      if (items.isNotEmpty) items.add(const TextSpan(text: '　'));
      final spec = expeditionRewardCatalog[id];
      if (spec != null) {
        items.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Image.asset(
                spec.assetPath,
                key: Key('logbook-expedition-reward-icon-$id'),
                width: 18,
                height: 18,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        );
      } else {
        items.add(TextSpan(text: '${reward.name} '));
      }
      items.add(
        TextSpan(
          text: 'X${reward.count}',
          style: const TextStyle(
            color: Color(0xff67bce9),
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    for (final reward in _expeditionRewards(row)) {
      add(reward);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            children: items.isEmpty ? const [TextSpan(text: '—')] : items,
          ),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: const TextStyle(
            color: Color(0xffd7e3e9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

final class _ExpeditionRewardData {
  const _ExpeditionRewardData({
    required this.id,
    required this.name,
    required this.count,
  });

  final int id;
  final String name;
  final int count;
}

List<_ExpeditionRewardData> _expeditionRewards(Map<String, dynamic> row) {
  final rewards = <_ExpeditionRewardData>[];

  void add(Object? rawId, Object? rawName, Object? rawCount) {
    final id = rawId is int ? rawId : int.tryParse('$rawId') ?? 0;
    final count = rawCount is int ? rawCount : int.tryParse('$rawCount') ?? 0;
    if (id <= 0 || count <= 0) return;
    rewards.add(
      _ExpeditionRewardData(
        id: id,
        name: expeditionRewardName(id, rawName?.toString()),
        count: count,
      ),
    );
  }

  final encoded = row['reward_items_json']?.toString() ?? '';
  if (encoded.isNotEmpty) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is List) {
        for (final value in decoded) {
          if (value is Map) {
            add(value['id'], value['name'], value['count']);
          }
        }
      }
    } on FormatException {
      // Older or partially written rows fall back to the two legacy columns.
    }
  }
  if (rewards.isNotEmpty) return rewards;

  add(row['item1_id'], row['item1_name'], row['item1_count']);
  add(row['item2_id'], row['item2_name'], row['item2_count']);
  return rewards;
}

int _rowInt(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text) ?? 0,
  _ => 0,
};

String _formatTime(Object? raw) {
  final timestamp = raw as int? ?? 0;
  // API capture times are stored as absolute instants and always displayed
  // in Japan Standard Time, regardless of the phone's configured time zone.
  final value = DateTime.fromMillisecondsSinceEpoch(
    timestamp,
    isUtc: true,
  ).add(const Duration(hours: 9));
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}

String _nodeLabel(Object? raw) {
  var value = raw as int? ?? 0;
  if (value <= 0) return '—';
  final codes = <int>[];
  while (value > 0) {
    value--;
    codes.add(65 + value % 26);
    value ~/= 26;
  }
  return String.fromCharCodes(codes.reversed);
}

String _sortieNodeLabel(
  Object? node,
  Object? nodeType, {
  Object? resolvedLabel,
}) {
  final resolved = resolvedLabel?.toString().trim() ?? '';
  if (resolved == '-') return '-';
  final label = resolved.isNotEmpty ? resolved : _nodeLabel(node);
  if (label == '—' || label == '-') return label;
  final isBoss = nodeType?.toString().toLowerCase().contains('boss') ?? false;
  return '$label·${isBoss ? 'Boss' : '道中'}';
}

String _mapDifficultyLabel(Object? raw) => switch (raw as int? ?? 0) {
  1 => '丁',
  2 => '丙',
  3 => '乙',
  4 => '甲',
  _ => '',
};

String _truncateMapName(String name, {int maxCharacters = 10}) {
  final characters = name.runes.toList(growable: false);
  if (characters.length <= maxCharacters) return name;
  return '${String.fromCharCodes(characters.take(maxCharacters))}…';
}

String sortieStatusLabel(Object? raw) {
  if (raw case final String label) {
    final trimmed = label.trim();
    if (trimmed.isNotEmpty && int.tryParse(trimmed) == null) {
      return trimmed;
    }
  }
  return '旧版记录';
}

String _expeditionResult(Object? raw) => switch (raw as int? ?? 0) {
  >= 2 => '大成功',
  1 => '成功',
  _ => '失败',
};

String _expeditionDisplayId(Object? raw) {
  final id = raw as int? ?? 0;
  return switch (id) {
    >= 100 && <= 105 => 'A${id - 99}',
    >= 110 && <= 115 => 'B${id - 109}',
    >= 131 && <= 133 => 'D${id - 130}',
    >= 141 && <= 142 => 'E${id - 140}',
    _ => '$id',
  };
}
