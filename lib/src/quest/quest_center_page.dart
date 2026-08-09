// ignore_for_file: use_null_aware_elements

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import 'quest_catalog.dart';
import 'quest_catalog_controller.dart';

enum QuestCenterMode { active, all }

class QuestFilterController extends ChangeNotifier {
  String query = '';
  int? category;
  int? period;
  QuestUnlockState? unlockState;

  bool get hasSearch => query.trim().isNotEmpty;
  bool get hasFilters =>
      category != null || period != null || unlockState != null;

  void setQuery(String value) {
    if (query == value) return;
    query = value;
    notifyListeners();
  }

  void setCategory(int? value) {
    if (category == value) return;
    category = value;
    notifyListeners();
  }

  void setPeriod(int? value) {
    if (period == value) return;
    period = value;
    notifyListeners();
  }

  void setUnlockState(QuestUnlockState? value) {
    if (unlockState == value) return;
    unlockState = value;
    notifyListeners();
  }

  void clear() {
    query = '';
    category = null;
    period = null;
    unlockState = null;
    notifyListeners();
  }
}

class QuestModeTabs extends StatelessWidget {
  const QuestModeTabs({super.key, required this.mode, required this.onChanged});

  final QuestCenterMode mode;
  final ValueChanged<QuestCenterMode> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    height: 38,
    child: Container(
      key: const Key('quest-mode-tabs'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xff0b202d),
        border: Border.all(color: const Color(0xff315064)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuestModeButton(
              selected: mode == QuestCenterMode.active,
              label: '进行中',
              onTap: () => onChanged(QuestCenterMode.active),
            ),
          ),
          Expanded(
            child: _QuestModeButton(
              selected: mode == QuestCenterMode.all,
              label: '全任务',
              onTap: () => onChanged(QuestCenterMode.all),
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuestModeButton extends StatelessWidget {
  const _QuestModeButton({
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
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xffffdc88) : const Color(0xff9fb3bf),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class QuestHeaderControls extends StatelessWidget {
  const QuestHeaderControls({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.filters,
  });

  final QuestCenterMode mode;
  final ValueChanged<QuestCenterMode> onModeChanged;
  final QuestFilterController filters;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: filters,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        QuestModeTabs(mode: mode, onChanged: onModeChanged),
        if (mode == QuestCenterMode.all) ...[
          const SizedBox(width: 6),
          _QuestHeaderIconButton(
            key: const Key('quest-search-button'),
            icon: Icons.search,
            active: filters.hasSearch,
            tooltip: '搜索任务',
            onPressed: () => _showQuestSearch(context, filters),
          ),
          const SizedBox(width: 4),
          _QuestHeaderIconButton(
            key: const Key('quest-filter-button'),
            icon: Icons.filter_alt_outlined,
            active: filters.hasFilters,
            tooltip: '筛选任务',
            onPressed: () => _showQuestFilters(context, filters),
          ),
        ],
      ],
    ),
  );
}

class _QuestHeaderIconButton extends StatelessWidget {
  const _QuestHeaderIconButton({
    super.key,
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 34,
    height: 34,
    child: IconButton(
      padding: EdgeInsets.zero,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: active
            ? const Color(0xff8a6628)
            : const Color(0xff0b202d),
        side: const BorderSide(color: Color(0xff315064)),
      ),
      icon: Icon(
        icon,
        size: 18,
        color: active ? const Color(0xffffdc88) : const Color(0xff9fb3bf),
      ),
    ),
  );
}

Future<void> _showQuestSearch(
  BuildContext context,
  QuestFilterController filters,
) async {
  final textController = TextEditingController(text: filters.query);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('搜索任务'),
      content: TextField(
        key: const Key('quest-search-field'),
        controller: textController,
        autofocus: true,
        onChanged: filters.setQuery,
        decoration: const InputDecoration(
          hintText: '搜索编号、任务名或说明',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            textController.clear();
            filters.setQuery('');
          },
          child: const Text('清除'),
        ),
        FilledButton(
          key: const Key('quest-search-close'),
          onPressed: () => Navigator.pop(context),
          child: const Text('完成'),
        ),
      ],
    ),
  );
}

Future<void> _showQuestFilters(
  BuildContext context,
  QuestFilterController filters,
) {
  final content = _QuestFilterSheet(filters: filters);
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff142735),
      builder: (_) => SafeArea(child: content),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(child: SizedBox(width: 520, child: content)),
  );
}

class _QuestFilterSheet extends StatelessWidget {
  const _QuestFilterSheet({required this.filters});

  final QuestFilterController filters;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    key: const Key('quest-filter-sheet'),
    animation: filters,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '筛选任务',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                key: const Key('quest-filter-clear'),
                onPressed: filters.clear,
                child: const Text('清除全部'),
              ),
              IconButton(
                key: const Key('quest-filter-close'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('任务类型'),
          const SizedBox(height: 5),
          Wrap(
            runSpacing: 5,
            children: [
              _FilterChip(
                key: const Key('quest-filter-category-all'),
                label: '全部类型',
                selected: filters.category == null,
                onTap: () => filters.setCategory(null),
              ),
              for (final item in const <(int, String)>[
                (2, '出击'),
                (1, '编成'),
                (3, '演习'),
                (4, '远征'),
                (5, '补给/入渠'),
                (6, '工厂'),
                (7, '改装'),
                (0, '其他'),
              ])
                _FilterChip(
                  key: Key('quest-filter-category-${item.$1}'),
                  label: item.$2,
                  selected: filters.category == item.$1,
                  onTap: () => filters.setCategory(item.$1),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('任务周期'),
          const SizedBox(height: 5),
          Wrap(
            runSpacing: 5,
            children: [
              _FilterChip(
                key: const Key('quest-filter-period-all'),
                label: '全部周期',
                selected: filters.period == null,
                onTap: () => filters.setPeriod(null),
              ),
              for (final item in const <(int, String)>[
                (1, '日常'),
                (2, '周常'),
                (3, '月常'),
                (4, '单次'),
                (5, '季常'),
                (6, '年常'),
              ])
                _FilterChip(
                  key: Key('quest-filter-period-${item.$1}'),
                  label: item.$2,
                  selected: filters.period == item.$1,
                  onTap: () => filters.setPeriod(item.$1),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('解锁状态'),
          const SizedBox(height: 5),
          Wrap(
            children: [
              _FilterChip(
                key: const Key('quest-filter-unlock-all'),
                label: '全部状态',
                selected: filters.unlockState == null,
                onTap: () => filters.setUnlockState(null),
              ),
              _FilterChip(
                key: const Key('quest-filter-unlock-unlocked'),
                label: '已解锁',
                selected: filters.unlockState == QuestUnlockState.unlocked,
                onTap: () => filters.setUnlockState(QuestUnlockState.unlocked),
              ),
              _FilterChip(
                key: const Key('quest-filter-unlock-locked'),
                label: '未解锁',
                selected: filters.unlockState == QuestUnlockState.locked,
                onTap: () => filters.setUnlockState(QuestUnlockState.locked),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class QuestCenterPage extends StatefulWidget {
  const QuestCenterPage({
    super.key,
    required this.controller,
    this.initialQuestId,
    this.showTitle = true,
    this.mode = QuestCenterMode.active,
    this.onModeChanged,
    this.catalog,
    this.catalogController,
    this.filterController,
  });

  final GameStateController controller;
  final int? initialQuestId;
  final bool showTitle;
  final QuestCenterMode mode;
  final ValueChanged<QuestCenterMode>? onModeChanged;
  final QuestCatalog? catalog;
  final QuestCatalogController? catalogController;
  final QuestFilterController? filterController;

  @override
  State<QuestCenterPage> createState() => _QuestCenterPageState();
}

class _QuestCenterPageState extends State<QuestCenterPage> {
  late int? _selectedQuestId = widget.initialQuestId;
  late QuestCenterMode _mode = widget.mode;
  QuestCatalog? _catalog;
  final QuestFilterController _localFilters = QuestFilterController();

  QuestFilterController get _filters =>
      widget.filterController ?? _localFilters;

  @override
  void initState() {
    super.initState();
    _catalog = widget.catalogController?.catalog ?? widget.catalog;
    if (_catalog == null) _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final catalog = await QuestCatalog.loadAsset();
    if (mounted) setState(() => _catalog = catalog);
  }

  @override
  void dispose() {
    _localFilters.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(QuestCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuestId != null &&
        widget.initialQuestId != oldWidget.initialQuestId) {
      _selectedQuestId = widget.initialQuestId;
    }
    if (widget.mode != oldWidget.mode) _mode = widget.mode;
    if (widget.catalog != oldWidget.catalog && widget.catalog != null) {
      _catalog = widget.catalog;
    }
    if (widget.catalogController != oldWidget.catalogController &&
        widget.catalogController != null) {
      _catalog = widget.catalogController!.catalog;
    }
  }

  void _changeMode(QuestCenterMode mode) {
    setState(() => _mode = mode);
    widget.onModeChanged?.call(mode);
  }

  void _selectRelation(int id) {
    setState(() {
      _selectedQuestId = id;
      _mode = QuestCenterMode.all;
    });
    _filters.clear();
    widget.onModeChanged?.call(QuestCenterMode.all);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xff081521),
    child: AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller,
        _filters,
        if (widget.catalogController case final controller?) controller,
      ]),
      builder: (context, _) {
        _catalog = widget.catalogController?.catalog ?? _catalog;
        if (_mode == QuestCenterMode.all && _catalog == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showTitle)
                _QuestHeader(
                  mode: _mode,
                  filters: _filters,
                  onModeChanged: _changeMode,
                ),
              const Expanded(
                child: Center(
                  key: Key('quest-catalog-loading'),
                  child: CircularProgressIndicator(),
                ),
              ),
            ],
          );
        }
        final live = widget.controller.state.quests;
        final entries = _entries(live);
        final selected = _selected(entries);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showTitle)
              _QuestHeader(
                mode: _mode,
                filters: _filters,
                onModeChanged: _changeMode,
              ),
            Expanded(
              child: entries.isEmpty
                  ? const _WaitingState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final list = _QuestListPanel(
                          entries: entries,
                          selectedQuestId: selected!.id,
                          allMode: _mode == QuestCenterMode.all,
                          onSelected: (id) =>
                              setState(() => _selectedQuestId = id),
                        );
                        final detail = _QuestDetail(
                          key: const Key('quest-detail-panel'),
                          entry: selected,
                          onRelationSelected: _selectRelation,
                        );
                        if (constraints.maxWidth < 760) {
                          final detailMin = _mode == QuestCenterMode.all
                              ? 310.0
                              : 330.0;
                          final naturalList = 18.0 + entries.length * 70.0;
                          final listHeight = naturalList.clamp(
                            84.0,
                            (constraints.maxHeight - detailMin).clamp(
                              84.0,
                              constraints.maxHeight * 0.55,
                            ),
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: listHeight, child: list),
                              const Divider(height: 1),
                              Expanded(child: detail),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 42, child: list),
                            const VerticalDivider(width: 1),
                            Expanded(flex: 58, child: detail),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );

  List<_QuestViewEntry> _entries(Map<int, GameQuest> live) {
    if (_mode == QuestCenterMode.active) {
      final values =
          live.values
              .map((quest) => _QuestViewEntry.fromLive(quest, _catalog))
              .toList()
            ..sort((a, b) {
              final completed = (b.completed ? 1 : 0).compareTo(
                a.completed ? 1 : 0,
              );
              return completed != 0 ? completed : a.id.compareTo(b.id);
            });
      return values;
    }
    final projection = _catalog!.project(live);
    return projection.items
        .where((item) {
          final entry = item.entry;
          final query = _filters.query.trim().toLowerCase();
          if (query.isNotEmpty &&
              !entry.code.toLowerCase().contains(query) &&
              !entry.name.toLowerCase().contains(query) &&
              !entry.description.toLowerCase().contains(query)) {
            return false;
          }
          if (_filters.category != null &&
              entry.category != _filters.category) {
            return false;
          }
          if (_filters.period != null && entry.period != _filters.period) {
            return false;
          }
          return _filters.unlockState == null ||
              item.unlockState == _filters.unlockState;
        })
        .map((item) => _QuestViewEntry.fromCatalog(item, _catalog!))
        .toList(growable: false);
  }

  _QuestViewEntry? _selected(List<_QuestViewEntry> entries) {
    if (entries.isEmpty) return null;
    for (final entry in entries) {
      if (entry.id == _selectedQuestId) return entry;
    }
    _selectedQuestId = entries.first.id;
    return entries.first;
  }
}

class _QuestHeader extends StatelessWidget {
  const _QuestHeader({
    required this.mode,
    required this.filters,
    required this.onModeChanged,
  });

  final QuestCenterMode mode;
  final QuestFilterController filters;
  final ValueChanged<QuestCenterMode> onModeChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: const BoxDecoration(
      color: Color(0xff0d1a26),
      border: Border(bottom: BorderSide(color: Color(0xff294052))),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final controls = QuestHeaderControls(
          mode: mode,
          filters: filters,
          onModeChanged: onModeChanged,
        );
        if (constraints.maxWidth < 430) {
          return Align(alignment: Alignment.centerRight, child: controls);
        }
        return Row(
          children: [
            Text(
              AppLocalizations.of(context)?.quests ?? '任务',
              style: const TextStyle(
                color: Color(0xffd4a85f),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            controls,
          ],
        );
      },
    ),
  );
}

class _QuestListPanel extends StatelessWidget {
  const _QuestListPanel({
    required this.entries,
    required this.selectedQuestId,
    required this.allMode,
    required this.onSelected,
  });

  final List<_QuestViewEntry> entries;
  final int selectedQuestId;
  final bool allMode;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _QuestCard(
              entry: entry,
              selected: entry.id == selectedQuestId,
              onTap: () => onSelected(entry.id),
            );
          },
        ),
      ),
    ],
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 5, bottom: 3),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff287e6a) : const Color(0xffd3dae0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xff24333c),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _QuestViewEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = entry.completed
        ? const Color(0xff66cda4)
        : entry.locked
        ? const Color(0xff728793)
        : const Color(0xff70c5c1);
    return Material(
      key: Key('quest-card-${entry.id}'),
      color: selected ? const Color(0xff183041) : const Color(0xff142735),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(
          color: selected ? const Color(0xff8d7040) : const Color(0xff294052),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _QuestCodeTag(
                          key: Key('quest-card-code-${entry.id}'),
                          code: entry.code,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _SmallTag(
                          label: entry.categoryLabel,
                          color: entry.categoryColor,
                        ),
                        const SizedBox(width: 5),
                        _SmallTag(
                          label: entry.periodLabel(context),
                          color: entry.periodColor,
                        ),
                        const SizedBox(width: 5),
                        _SmallTag(
                          label: entry.progressLabel,
                          color: entry.progressColor,
                        ),
                        const Spacer(),
                        _StatusBadge(
                          key: Key('quest-card-status-${entry.id}'),
                          entry: entry,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestDetail extends StatelessWidget {
  const _QuestDetail({
    super.key,
    required this.entry,
    required this.onRelationSelected,
  });

  final _QuestViewEntry entry;
  final ValueChanged<int> onRelationSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          key: Key('quest-detail-title-${entry.id}'),
          children: [
            _QuestCodeTag(
              key: Key('quest-detail-code-${entry.id}'),
              code: entry.code,
              large: true,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _SmallTag(label: entry.categoryLabel, color: entry.categoryColor),
            _SmallTag(
              label: entry.periodLabel(context),
              color: entry.periodColor,
            ),
            _SmallTag(label: entry.progressLabel, color: entry.progressColor),
            _StatusBadge(
              key: Key('quest-detail-status-${entry.id}'),
              entry: entry,
            ),
            if (entry.exactProgress case final progress?)
              _SmallTag(
                key: Key('quest-detail-exact-progress-${entry.id}'),
                label: progress,
                color: const Color(0xff8ec6e8),
              ),
          ],
        ),
        const SizedBox(height: 13),
        _DetailCard(
          title: AppLocalizations.of(context)?.questDesc ?? '任务说明',
          child: Text(
            entry.detail.isEmpty ? '暂无说明' : entry.detail,
            style: const TextStyle(
              color: Color(0xffc4d0d7),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        if (entry.memo.isNotEmpty) ...[
          const SizedBox(height: 8),
          _DetailCard(title: '完成条件', child: Text(entry.memo)),
        ],
        const SizedBox(height: 8),
        _DetailCard(
          title: AppLocalizations.of(context)?.baseReward ?? '基础奖励',
          child: entry.rewardsText.isNotEmpty
              ? Text(entry.rewardsText)
              : Wrap(
                  spacing: 18,
                  runSpacing: 9,
                  children: [
                    for (var index = 0; index < 4; index++)
                      _MaterialReward(
                        assetIndex: index + 1,
                        value: entry.materials[index],
                      ),
                  ],
                ),
        ),
        if (entry.prerequisites.isNotEmpty || entry.successors.isNotEmpty) ...[
          const SizedBox(height: 8),
          _DetailCard(
            title: '任务关系',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.prerequisites.isNotEmpty)
                  _RelationRow(
                    label: '前置任务',
                    entries: entry.prerequisites,
                    keyPrefix: 'quest-relation-pre',
                    onSelected: onRelationSelected,
                  ),
                if (entry.successors.isNotEmpty) ...[
                  if (entry.prerequisites.isNotEmpty) const SizedBox(height: 8),
                  _RelationRow(
                    label: '后置任务',
                    entries: entry.successors,
                    keyPrefix: 'quest-relation-post',
                    onSelected: onRelationSelected,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _RelationRow extends StatelessWidget {
  const _RelationRow({
    required this.label,
    required this.entries,
    required this.keyPrefix,
    required this.onSelected,
  });

  final String label;
  final List<QuestCatalogEntry> entries;
  final String keyPrefix;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 58,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(label, style: const TextStyle(color: Color(0xff91a5b0))),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          key: Key('$keyPrefix-scroll'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                if (index > 0) const SizedBox(width: 6),
                Material(
                  key: Key('$keyPrefix-${entries[index].gameId}'),
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: () => onSelected(entries[index].gameId),
                    child: _QuestCodeTag(
                      key: Key('quest-relation-code-${entries[index].gameId}'),
                      code: entries[index].code,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _QuestCodeTag extends StatelessWidget {
  const _QuestCodeTag({super.key, required this.code, this.large = false});

  final String code;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = _questCodeColor(code);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 9 : 7,
        vertical: large ? 3 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        code,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: large ? 13 : 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

Color _questCodeColor(String code) {
  final category = RegExp(r'[A-G]', caseSensitive: false).firstMatch(code);
  return switch (category?.group(0)?.toUpperCase()) {
    'A' => const Color(0xff19bb2e),
    'B' => const Color(0xffe73939),
    'C' => const Color(0xff87da61),
    'D' => const Color(0xff16c2a3),
    'E' => const Color(0xffe2c609),
    'F' => const Color(0xff805444),
    'G' => const Color(0xffc792e8),
    _ => const Color(0xffa9bdc8),
  };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({super.key, required this.entry});

  final _QuestViewEntry entry;

  @override
  Widget build(BuildContext context) {
    final positive = entry.allMode ? !entry.locked : entry.completed;
    final color = positive ? const Color(0xff67d2a6) : const Color(0xffe0ad4f);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: positive ? const Color(0xff173a31) : const Color(0xff3b3020),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Text(
        entry.allMode
            ? (entry.locked ? '未解锁' : '已解锁')
            : (entry.completed ? '已完成' : '未完成'),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xff142735),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xff294052)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xffd4a85f),
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _MaterialReward extends StatelessWidget {
  const _MaterialReward({required this.assetIndex, required this.value});

  final int assetIndex;
  final int value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 78,
    child: Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Image.asset(
            'assets/images/material/${assetIndex.toString().padLeft(2, '0')}.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({
    super.key,
    required this.label,
    this.color = const Color(0xffa9bdc8),
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _WaitingState extends StatelessWidget {
  const _WaitingState();

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.assignment_outlined,
            color: Color(0xffd4a85f),
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(
            l10n.waitingQuestData,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            l10n.waitingQuestDataDesc,
            style: const TextStyle(color: Color(0xff8197a5)),
          ),
        ],
      ),
    );
  }
}

class _QuestViewEntry {
  const _QuestViewEntry({
    required this.id,
    required this.code,
    required this.title,
    required this.detail,
    required this.category,
    required this.period,
    required this.progressLabel,
    required this.completed,
    required this.locked,
    required this.allMode,
    required this.materials,
    required this.rewardsText,
    required this.memo,
    required this.exactProgress,
    required this.prerequisites,
    required this.successors,
  });

  factory _QuestViewEntry.fromLive(GameQuest quest, QuestCatalog? catalog) {
    final doc = catalog?.byGameId(quest.id);
    return _QuestViewEntry(
      id: quest.id,
      code: doc?.code ?? quest.id.toString(),
      title: quest.title,
      detail: quest.detail,
      category: quest.category,
      period: quest.type,
      progressLabel: quest.progressPercentLabel,
      completed: quest.isCompleted,
      locked: false,
      allMode: false,
      materials: quest.materials,
      rewardsText: '',
      memo: '',
      exactProgress: quest.exactProgressLabel,
      prerequisites: doc == null
          ? const <QuestCatalogEntry>[]
          : catalog!.prerequisitesOf(quest.id),
      successors: doc == null
          ? const <QuestCatalogEntry>[]
          : catalog!.successorsOf(quest.id),
    );
  }

  factory _QuestViewEntry.fromCatalog(
    QuestCatalogItem item,
    QuestCatalog catalog,
  ) {
    final live = item.liveQuest;
    final doc = item.entry;
    return _QuestViewEntry(
      id: doc.gameId,
      code: doc.code,
      title: doc.name,
      detail: doc.description,
      category: doc.category,
      period: doc.period,
      progressLabel: item.progressLabel,
      completed: live?.isCompleted ?? item.inferredCompleted,
      locked: item.unlockState == QuestUnlockState.locked,
      allMode: true,
      materials: live?.materials ?? const <int>[0, 0, 0, 0],
      rewardsText: doc.rewards,
      memo: doc.memo,
      exactProgress: live?.exactProgressLabel,
      prerequisites: catalog.prerequisitesOf(doc.gameId),
      successors: catalog.successorsOf(doc.gameId),
    );
  }

  final int id;
  final String code;
  final String title;
  final String detail;
  final int category;
  final int period;
  final String progressLabel;
  final bool completed;
  final bool locked;
  final bool allMode;
  final List<int> materials;
  final String rewardsText;
  final String memo;
  final String? exactProgress;
  final List<QuestCatalogEntry> prerequisites;
  final List<QuestCatalogEntry> successors;

  String get categoryLabel => switch (category) {
    1 => '编成',
    2 => '出击',
    3 => '演习',
    4 => '远征',
    5 => '补给/入渠',
    6 => '工厂',
    7 => '改装',
    _ => '其他',
  };

  Color get categoryColor => switch (category) {
    1 => const Color(0xff19bb2e),
    2 => const Color(0xffe73939),
    3 => const Color(0xff87da61),
    4 => const Color(0xff16c2a3),
    5 => const Color(0xffe2c609),
    6 => const Color(0xff805444),
    7 => const Color(0xffc792e8),
    _ => Colors.white,
  };

  String periodLabel(BuildContext context) => switch (period) {
    1 => AppLocalizations.of(context)?.questDaily ?? '日常',
    2 => AppLocalizations.of(context)?.questWeekly ?? '周常',
    3 => AppLocalizations.of(context)?.questMonthly ?? '月常',
    4 => AppLocalizations.of(context)?.questOneTime ?? '单次',
    5 => '季常',
    6 => '年常',
    _ => AppLocalizations.of(context)?.questOther ?? '其他',
  };

  Color get periodColor => switch (period) {
    1 => const Color(0xff4b9fd5),
    2 => const Color(0xffdb6565),
    3 => const Color(0xff80c16b),
    4 => const Color(0xffe0c345),
    5 => const Color(0xffb78ad7),
    6 => const Color(0xffe58c4f),
    _ => const Color(0xffe58c4f),
  };

  Color get progressColor {
    if (progressLabel == '100%' || progressLabel == '50%+') {
      return const Color(0xff67d2a6);
    }
    if (progressLabel == '80%+') return const Color(0xffe0ad4f);
    return const Color(0xffa9bdc8);
  }
}
