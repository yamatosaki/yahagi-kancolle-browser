import 'package:flutter/material.dart';

import '../battle/battle_controller.dart';
import '../fleet/equipment_type_icon.dart';
import '../fleet/header_resource_catalog.dart';
import '../fleet/resource_trend_page.dart';
import '../game_state/game_state.dart';
import '../widgets/frozen_data_table.dart';
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

const double _logbookControlHeight = 28;

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
    final database = widget.database ?? LogbookDatabase.instance;
    return ColoredBox(
      color: const Color(0xff081521),
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
          const ResourceTrendPage(),
        ],
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
  final _searchController = TextEditingController();
  final _filterButtonAnchor = GlobalKey();
  final List<Map<String, dynamic>> _records = [];
  bool _loading = false;
  bool _refreshing = false;
  bool _refreshQueued = false;
  bool _hasMore = true;
  Map<String, String> _filters = const <String, String>{};

  @override
  void initState() {
    super.initState();
    widget.database.addListener(_refreshLatest);
    if (widget.category == _LogbookCategory.sortie) {
      widget.battleController.addListener(_refreshAfterBattleChange);
    }
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant _LogbookTablePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database) {
      oldWidget.database.removeListener(_refreshLatest);
      widget.database.addListener(_refreshLatest);
    }
    if (oldWidget.battleController != widget.battleController &&
        widget.category == _LogbookCategory.sortie) {
      oldWidget.battleController.removeListener(_refreshAfterBattleChange);
      widget.battleController.addListener(_refreshAfterBattleChange);
    }
    _refreshLatest();
  }

  @override
  void dispose() {
    widget.database.removeListener(_refreshLatest);
    if (widget.category == _LogbookCategory.sortie) {
      widget.battleController.removeListener(_refreshAfterBattleChange);
    }
    _searchController.dispose();
    super.dispose();
  }

  void _refreshAfterBattleChange() {
    Future<void>.delayed(const Duration(milliseconds: 120), _refreshLatest);
  }

  Future<void> _refreshLatest() async {
    if (!mounted) return;
    if (_refreshing || _loading) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      final latest = await _queryRecords();
      if (!mounted || latest.isEmpty) return;
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
      _refreshing = false;
      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        Future<void>.microtask(_refreshLatest);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    try {
      final beforeId = _records.isEmpty ? null : _records.last['id'] as int?;
      final next = await _queryRecords(beforeId: beforeId);
      if (!mounted) return;
      setState(() {
        _records.addAll(next);
        _hasMore = next.length == _batchSize;
      });
    } finally {
      _loading = false;
    }
  }

  Future<List<Map<String, dynamic>>> _queryRecords({int? beforeId}) =>
      switch (widget.category) {
        _LogbookCategory.sortie => widget.database.getBattleRecords(
          limit: _batchSize,
          beforeId: beforeId,
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
    final query = _searchController.text.trim().toLowerCase();
    return _records
        .where((record) {
          if (query.isNotEmpty &&
              !record.values.any(
                (value) => value.toString().toLowerCase().contains(query),
              )) {
            return false;
          }
          return _matchesFilter(record);
        })
        .toList(growable: false);
  }

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
        selected('map', '全部海域', _mapLabel(record)) &&
            selected('status', '全部状态', _sortieStatus(record['node_type'])) &&
            selected('rank', '全部评价', '${record['rank']}'.toUpperCase()),
      _LogbookCategory.expedition =>
        selected('mission', '全部远征', record['name']) &&
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
            selected('shipType', '全部舰种', record['ship_type']) &&
            selected('ship', '全部舰娘', record['ship_name']),
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
      'ship': '全部舰娘',
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
          options: _distinct('全部海域', _records.map(_mapLabel)),
        ),
        const LogbookFilterField(
          keyName: 'status',
          label: '状态',
          options: [
            '全部状态',
            '普通战斗',
            'Boss 战',
            '空袭战',
            '长距离空袭战',
            '航空战',
            '夜战',
            '敌联合舰队',
            '进击',
          ],
        ),
        const LogbookFilterField(
          keyName: 'rank',
          label: '评价',
          options: ['全部评价', 'S', 'A', 'B', 'C', 'D', 'E'],
        ),
      ],
      _LogbookCategory.expedition => [
        const LogbookFilterField(keyName: 'date', label: '日期', options: dates),
        LogbookFilterField(
          keyName: 'mission',
          label: '远征',
          options: _distinct('全部远征', _records.map((row) => '${row['name']}')),
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
        LogbookFilterField(
          keyName: 'ship',
          label: '舰娘',
          options: _distinct(
            '全部舰娘',
            _records.map((row) => '${row['ship_name']}'),
          ),
        ),
      ],
      _LogbookCategory.resource => const <LogbookFilterField>[],
    };
  }

  Future<void> _showFilter() async {
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
    if (selected != null && mounted) setState(() => _filters = selected);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visibleRecords;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(
                  child: Text(
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
                SizedBox(
                  width: 210,
                  height: _logbookControlHeight,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(
                      color: Color(0xffd7e3e9),
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      hintText: _searchHint,
                      hintStyle: const TextStyle(
                        color: Color(0xff667f8d),
                        fontSize: 11,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xff315064)),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xffb7832a)),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                KeyedSubtree(
                  key: _filterButtonAnchor,
                  child: _LogbookFilterButton(
                    key: const Key('logbook-filter-button'),
                    active: _filters.entries.any(
                      (entry) => _filterDefaults[entry.key] != entry.value,
                    ),
                    onTap: _showFilter,
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
                        child: Text(
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

  String get _searchHint => switch (widget.category) {
    _LogbookCategory.sortie => '搜索海域、敌舰队、掉落…',
    _LogbookCategory.expedition => '搜索远征、道具…',
    _LogbookCategory.construction => '搜索舰娘、舰种、秘书舰…',
    _LogbookCategory.development => '搜索装备、类型、秘书舰…',
    _LogbookCategory.retirement => '搜索舰娘、舰种…',
    _LogbookCategory.resource => '搜索…',
  };

  Widget _buildTable(List<Map<String, dynamic>> rows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = _tableSpecForWidth(constraints.maxWidth);
        return FrozenDataTable(
          key: Key('logbook-table-${widget.category.name}'),
          keyPrefix: 'logbook-${widget.category.name}',
          frozenColumnWidths: const [112],
          frozenHeaders: const [_HeaderCell('时间')],
          frozenCells: (index) => [
            _TextCell(_formatTime(rows[index]['timestamp'])),
          ],
          scrollableColumnWidths: spec.widths,
          scrollableHeaders: spec.headers,
          scrollableCells: (index) => spec.cells(rows[index]),
          rowHeights: List<double>.filled(
            rows.length,
            FrozenDataTable.minimumRowHeight,
          ),
          onEndReached: _loadMore,
        );
      },
    );
  }

  _TableSpec _tableSpecForWidth(double availableWidth) {
    if (widget.category == _LogbookCategory.sortie) {
      final spec = _tableSpec;
      final widths = List<double>.of(spec.widths);
      final scrollableWidth = availableWidth - 112;
      final baseWidth = widths.fold<double>(0, (sum, width) => sum + width);
      if (scrollableWidth > baseWidth) {
        widths[4] += scrollableWidth - baseWidth;
      }
      return _TableSpec(
        widths: widths,
        headers: spec.headers,
        cells: spec.cells,
      );
    }
    if (widget.category != _LogbookCategory.retirement) return _tableSpec;
    final scrollableWidth = (availableWidth - 112).clamp(
      452.0,
      double.infinity,
    );
    final typeWidth = scrollableWidth * 0.2;
    final shipTypeWidth = scrollableWidth * 0.28;
    return _TableSpec(
      widths: [
        typeWidth,
        shipTypeWidth,
        scrollableWidth - typeWidth - shipTypeWidth,
      ],
      headers: const [_HeaderCell('类型'), _HeaderCell('舰种'), _HeaderCell('舰娘')],
      cells: (row) => [
        _RetirementTypeCell('${row['type']}'),
        _TextCell('${row['ship_type']}'),
        _TextCell('${row['ship_name']} Lv.${row['level']}', strong: true),
      ],
    );
  }

  _TableSpec get _tableSpec => switch (widget.category) {
    _LogbookCategory.sortie => _TableSpec(
      widths: const [460, 90, 85, 68, 180, 120, 135, 135, 135, 135],
      headers: const [
        _HeaderCell('海域'),
        _HeaderCell('节点'),
        _HeaderCell('状态'),
        _HeaderCell('评价'),
        _HeaderCell('敌舰队'),
        _HeaderCell('掉落'),
        _HeaderCell('旗舰'),
        _HeaderCell('二队旗舰'),
        _HeaderCell('MVP'),
        _HeaderCell('二队 MVP'),
      ],
      cells: (row) => [
        _TextCell(_mapLabel(row)),
        _TextCell(
          _sortieNodeLabel(
            row['node'],
            row['node_type'],
            resolvedLabel: row['node_label'],
          ),
        ),
        _TextCell(_sortieStatus(row['node_type']), strong: true),
        _RankCell('${row['rank']}'),
        _TextCell('${row['enemy_fleet_name']}'),
        _TextCell(
          _dropName(row['drop_ship_id']),
          color: const Color(0xff67bce9),
        ),
        _TextCell('${row['flagship_name'] ?? '—'}', strong: true),
        _TextCell('${row['escort_flagship_name'] ?? '—'}', strong: true),
        _TextCell('${row['mvp_name'] ?? '—'}', strong: true),
        _TextCell('${row['escort_mvp_name'] ?? '—'}', strong: true),
      ],
    ),
    _LogbookCategory.expedition => _TableSpec(
      widths: const [205, 86, 82, 82, 82, 82, 270],
      headers: const [
        _HeaderCell('远征'),
        _HeaderCell('结果'),
        _ResourceHeader(GameResourceType.fuel),
        _ResourceHeader(GameResourceType.ammunition),
        _ResourceHeader(GameResourceType.steel),
        _ResourceHeader(GameResourceType.bauxite),
        _HeaderCell('道具'),
      ],
      cells: (row) => [
        _TextCell(
          '${_expeditionDisplayId(row['expedition_id'])} · ${row['name']}',
          strong: true,
        ),
        _ResultCell(_expeditionResult(row['result'])),
        _TextCell('${row['yield_fuel'] ?? 0}'),
        _TextCell('${row['yield_ammo'] ?? 0}'),
        _TextCell('${row['yield_steel'] ?? 0}'),
        _TextCell('${row['yield_bauxite'] ?? 0}'),
        _RewardItemsCell(row),
      ],
    ),
    _LogbookCategory.construction => _TableSpec(
      widths: const [110, 105, 95, 82, 82, 82, 82, 105, 190],
      headers: const [
        _HeaderCell('建造类型'),
        _HeaderCell('舰娘'),
        _HeaderCell('舰种'),
        _ResourceHeader(GameResourceType.fuel),
        _ResourceHeader(GameResourceType.ammunition),
        _ResourceHeader(GameResourceType.steel),
        _ResourceHeader(GameResourceType.bauxite),
        _ResourceHeader(GameResourceType.developmentMaterial),
        _HeaderCell('秘书舰'),
      ],
      cells: (row) => [
        _TextCell('${row['construction_type']}'),
        _TextCell('${row['ship_name']}', strong: true),
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
      widths: const [82, 220, 120, 82, 82, 82, 82, 190],
      headers: const [
        _HeaderCell('结果'),
        _HeaderCell('开发装备'),
        _HeaderCell('装备类型'),
        _ResourceHeader(GameResourceType.fuel),
        _ResourceHeader(GameResourceType.ammunition),
        _ResourceHeader(GameResourceType.steel),
        _ResourceHeader(GameResourceType.bauxite),
        _HeaderCell('秘书舰'),
      ],
      cells: (row) => [
        _ResultCell((row['success'] as int? ?? 0) > 0 ? '成功' : '失败'),
        _EquipmentCell(
          name: '${row['equipment_name']}',
          iconId: row['equipment_icon_id'] as int? ?? -1,
        ),
        _TextCell('${row['equipment_type']}'),
        _TextCell('${row['fuel']}'),
        _TextCell('${row['ammo']}'),
        _TextCell('${row['steel']}'),
        _TextCell('${row['bauxite']}'),
        _TextCell('${row['secretary_name']}'),
      ],
    ),
    _LogbookCategory.retirement => _TableSpec(
      widths: const [92, 130, 230],
      headers: const [_HeaderCell('类型'), _HeaderCell('舰种'), _HeaderCell('舰娘')],
      cells: (row) => [
        _RetirementTypeCell('${row['type']}'),
        _TextCell('${row['ship_type']}'),
        _TextCell('${row['ship_name']} Lv.${row['level']}', strong: true),
      ],
    ),
    _LogbookCategory.resource => throw StateError('资源页不使用日志表格'),
  };

  String _dropName(Object? value) {
    final id = value as int? ?? 0;
    if (id <= 0) return '—';
    return widget.battleController.gameState().masterShips[id]?.name ??
        'ID: $id';
  }

  String _mapLabel(Map<String, dynamic> row) {
    final area = row['map_area'] as int? ?? 0;
    final map = row['map_no'] as int? ?? 0;
    final number = '$area-$map';
    final storedName = row['map_name']?.toString().trim() ?? '';
    final name = storedName.isNotEmpty
        ? storedName
        : widget.battleController.gameState().mapName(area, map);
    final difficulty = _mapDifficultyLabel(row['map_difficulty']);
    final suffix = difficulty.isEmpty ? number : '$number $difficulty';
    return name == null || name.isEmpty ? suffix : '$name ($suffix)';
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

class _LogbookFilterButton extends StatelessWidget {
  const _LogbookFilterButton({
    super.key,
    required this.active,
    required this.onTap,
  });
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 68,
    height: _logbookControlHeight,
    child: Material(
      color: active ? const Color(0xff60491f) : const Color(0xff102936),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: active ? const Color(0xffb7832a) : const Color(0xff315064),
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: Text(
              '筛选',
              style: TextStyle(
                color: Color(0xffa8bac4),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
        label,
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
              type.label,
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
        value,
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

class _RewardItemsCell extends StatelessWidget {
  const _RewardItemsCell(this.row);
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final items = <InlineSpan>[];
    void add(String? name, Object? count) {
      if (name == null || name.isEmpty || (count as int? ?? 0) <= 0) return;
      if (items.isNotEmpty) items.add(const TextSpan(text: '　'));
      items
        ..add(TextSpan(text: '$name '))
        ..add(
          TextSpan(
            text: 'X$count',
            style: const TextStyle(
              color: Color(0xff67bce9),
              fontWeight: FontWeight.w900,
            ),
          ),
        );
    }

    add(row['item1_name'] as String?, row['item1_count']);
    add(row['item2_name'] as String?, row['item2_count']);
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

String _formatTime(Object? raw) {
  final timestamp = raw as int? ?? 0;
  final value = DateTime.fromMillisecondsSinceEpoch(timestamp);
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
  final label = resolved.isNotEmpty ? resolved : _nodeLabel(node);
  if (label == '—') return label;
  final isBoss = nodeType?.toString().toLowerCase().contains('boss') ?? false;
  return '$label${isBoss ? 'Boss' : '道中'}';
}

String _mapDifficultyLabel(Object? raw) => switch (raw as int? ?? 0) {
  1 => '丁',
  2 => '丙',
  3 => '乙',
  4 => '甲',
  _ => '',
};

String _sortieStatus(Object? raw) {
  if (raw case final String label when label.trim().isNotEmpty) return label;
  return switch (raw as int? ?? 0) {
    6 => '空袭战',
    7 => '航空战',
    8 => '夜战',
    1 => '进击',
    _ => '进击',
  };
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
