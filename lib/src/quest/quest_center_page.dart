// ignore_for_file: use_null_aware_elements

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/quest_text_normalizer.dart';
import '../widgets/filter_controls.dart';
import '../widgets/adaptive_input_dialog.dart';
import 'quest_catalog.dart';
import 'quest_catalog_controller.dart';

enum QuestCenterMode { active, all }

class QuestFilterController extends ChangeNotifier {
  String query = '';
  int? category;
  int? period;
  QuestUnlockState? unlockState;
  bool acceptedOnly = false;

  bool get hasSearch => query.trim().isNotEmpty;
  bool get hasFilters =>
      category != null || period != null || unlockState != null || acceptedOnly;

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
    acceptedOnly = false;
    notifyListeners();
  }

  void setAcceptedOnly(bool value) {
    if (acceptedOnly == value) return;
    acceptedOnly = value;
    notifyListeners();
  }
}

class QuestModeTabs extends StatelessWidget {
  const QuestModeTabs({super.key, required this.mode, required this.onChanged});

  final QuestCenterMode mode;
  final ValueChanged<QuestCenterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return SizedBox(
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
                label: l10n.inProgress,
                onTap: () => onChanged(QuestCenterMode.active),
              ),
            ),
            Expanded(
              child: _QuestModeButton(
                selected: mode == QuestCenterMode.all,
                label: l10n.questAll,
                onTap: () => onChanged(QuestCenterMode.all),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    required this.translationEnabled,
    required this.onTranslationChanged,
    this.compactTranslation = false,
  });

  final QuestCenterMode mode;
  final ValueChanged<QuestCenterMode> onModeChanged;
  final QuestFilterController filters;
  final bool translationEnabled;
  final ValueChanged<bool> onTranslationChanged;
  final bool compactTranslation;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: filters,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          QuestTranslationToggle(
            enabled: translationEnabled,
            compact: compactTranslation,
            onChanged: onTranslationChanged,
          ),
          const SizedBox(width: 8),
          QuestModeTabs(mode: mode, onChanged: onModeChanged),
          if (mode == QuestCenterMode.all) ...[
            const SizedBox(width: 6),
            HeaderFilterIconButton(
              key: const Key('quest-search-button'),
              icon: Icons.search,
              active: filters.hasSearch,
              tooltip: l10n.searchQuest,
              onPressed: () => _showQuestSearch(context, filters),
            ),
            const SizedBox(width: 4),
            HeaderFilterIconButton(
              key: const Key('quest-filter-button'),
              icon: Icons.filter_alt_outlined,
              active: filters.hasFilters,
              tooltip: l10n.filterQuest,
              onPressed: () => _showQuestFilters(context, filters),
            ),
          ],
        ],
      ),
    );
  }
}

class QuestTranslationToggle extends StatelessWidget {
  const QuestTranslationToggle({
    super.key,
    required this.enabled,
    required this.onChanged,
    this.compact = false,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final color = enabled ? const Color(0xffffd47a) : const Color(0xff9fb3bf);
    return SizedBox(
      key: const Key('quest-translation-toggle'),
      height: 38,
      width: compact ? 38 : 100,
      child: Material(
        color: enabled ? const Color(0xff5b4420) : const Color(0xff0b202d),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
          side: BorderSide(
            color: enabled ? const Color(0xffb88b38) : const Color(0xff315064),
          ),
        ),
        child: InkWell(
          onTap: () => onChanged(!enabled),
          borderRadius: BorderRadius.circular(19),
          child: Tooltip(
            message: l10n.chineseTranslation,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.translate, size: 17, color: color),
                if (!compact) ...[
                  const SizedBox(width: 5),
                  Text(
                    l10n.chineseTranslation,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showQuestSearch(
  BuildContext context,
  QuestFilterController filters,
) async {
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  final textController = TextEditingController(text: filters.query);
  await showDialog<void>(
    context: context,
    builder: (context) => AdaptiveInputDialog(
      title: Text(l10n.searchQuest),
      content: TextField(
        key: const Key('quest-search-field'),
        controller: textController,
        autofocus: true,
        onChanged: filters.setQuery,
        decoration: InputDecoration(
          hintText: l10n.searchQuestHint,
          prefixIcon: const Icon(Icons.search),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            textController.clear();
            filters.setQuery('');
          },
          child: Text(l10n.clear),
        ),
        FilledButton(
          key: const Key('quest-search-close'),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.done),
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
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: SingleChildScrollView(child: content),
        ),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: SizedBox(width: 520, child: SingleChildScrollView(child: content)),
    ),
  );
}

class _QuestFilterSheet extends StatelessWidget {
  const _QuestFilterSheet({required this.filters});

  final QuestFilterController filters;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final categories = <(int, String)>[
      (2, l10n.questSortie),
      (1, l10n.questFormation),
      (3, l10n.questExercise),
      (4, l10n.expedition),
      (5, l10n.questSupplyRepair),
      (6, l10n.questFactory),
      (7, l10n.questRemodeling),
      (0, l10n.questOther),
    ];
    final periods = <(int, String)>[
      (1, l10n.questDaily),
      (2, l10n.questWeekly),
      (3, l10n.questMonthly),
      (4, l10n.questOneTime),
      (5, l10n.questSeasonal),
      (6, l10n.questYearly),
    ];
    return AnimatedBuilder(
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
                Text(
                  l10n.filterQuest,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('quest-filter-clear'),
                  onPressed: filters.clear,
                  child: Text(l10n.clearAll),
                ),
                IconButton(
                  key: const Key('quest-filter-close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.questType),
            const SizedBox(height: 5),
            Wrap(
              runSpacing: 5,
              children: [
                CompactFilterChip(
                  key: const Key('quest-filter-category-all'),
                  label: l10n.allTypes,
                  selected: filters.category == null,
                  onTap: () => filters.setCategory(null),
                ),
                for (final item in categories)
                  CompactFilterChip(
                    key: Key('quest-filter-category-${item.$1}'),
                    label: item.$2,
                    selected: filters.category == item.$1,
                    onTap: () => filters.setCategory(item.$1),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(l10n.questPeriod),
            const SizedBox(height: 5),
            Wrap(
              runSpacing: 5,
              children: [
                CompactFilterChip(
                  key: const Key('quest-filter-period-all'),
                  label: l10n.allPeriods,
                  selected: filters.period == null,
                  onTap: () => filters.setPeriod(null),
                ),
                for (final item in periods)
                  CompactFilterChip(
                    key: Key('quest-filter-period-${item.$1}'),
                    label: item.$2,
                    selected: filters.period == item.$1,
                    onTap: () => filters.setPeriod(item.$1),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(l10n.unlockStatus),
            const SizedBox(height: 5),
            Wrap(
              children: [
                CompactFilterChip(
                  key: const Key('quest-filter-unlock-all'),
                  label: l10n.allStatuses,
                  selected: filters.unlockState == null,
                  onTap: () => filters.setUnlockState(null),
                ),
                CompactFilterChip(
                  key: const Key('quest-filter-unlock-unlocked'),
                  label: l10n.questUnlocked,
                  selected: filters.unlockState == QuestUnlockState.unlocked,
                  onTap: () =>
                      filters.setUnlockState(QuestUnlockState.unlocked),
                ),
                CompactFilterChip(
                  key: const Key('quest-filter-unlock-locked'),
                  label: l10n.questLocked,
                  selected: filters.unlockState == QuestUnlockState.locked,
                  onTap: () => filters.setUnlockState(QuestUnlockState.locked),
                ),
                CompactFilterChip(
                  key: const Key('quest-filter-unlock-completed'),
                  label: l10n.completed,
                  selected: filters.unlockState == QuestUnlockState.completed,
                  onTap: () =>
                      filters.setUnlockState(QuestUnlockState.completed),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.questFilterHelp,
              style: const TextStyle(fontSize: 11, color: Color(0xff9fb3bf)),
            ),
            CheckboxListTile(
              key: const Key('quest-filter-accepted-only'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.questAcceptedOnly),
              value: filters.acceptedOnly,
              onChanged: (value) => filters.setAcceptedOnly(value ?? false),
            ),
          ],
        ),
      ),
    );
  }
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
    this.translationEnabled,
    this.onTranslationChanged,
  });

  final GameStateController controller;
  final int? initialQuestId;
  final bool showTitle;
  final QuestCenterMode mode;
  final ValueChanged<QuestCenterMode>? onModeChanged;
  final QuestCatalog? catalog;
  final QuestCatalogController? catalogController;
  final QuestFilterController? filterController;
  final bool? translationEnabled;
  final ValueChanged<bool>? onTranslationChanged;

  @override
  State<QuestCenterPage> createState() => _QuestCenterPageState();
}

class _QuestCenterPageState extends State<QuestCenterPage> {
  late int? _selectedQuestId = widget.initialQuestId;
  late QuestCenterMode _mode = widget.mode;
  QuestCatalog? _catalog;
  QuestCatalog? _projectedCatalog;
  Map<int, GameQuest>? _projectedLiveQuests;
  Map<int, GameQuest>? _projectedAvailableQuests;
  bool? _projectedIsComplete;
  QuestCatalogProjection? _cachedProjection;
  final QuestFilterController _localFilters = QuestFilterController();
  bool _localTranslationEnabled = false;

  QuestFilterController get _filters =>
      widget.filterController ?? _localFilters;
  bool get _translationEnabled =>
      widget.translationEnabled ?? _localTranslationEnabled;

  void _changeTranslation(bool enabled) {
    if (widget.translationEnabled == null) {
      setState(() => _localTranslationEnabled = enabled);
    }
    widget.onTranslationChanged?.call(enabled);
  }

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
                  translationEnabled: _translationEnabled,
                  onTranslationChanged: _changeTranslation,
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
                translationEnabled: _translationEnabled,
                onTranslationChanged: _changeTranslation,
              ),
            Expanded(
              child: entries.isEmpty
                  ? _mode == QuestCenterMode.all
                        ? _QuestEmptyResults(
                            filters: _filters,
                            needsSync:
                                !widget.controller.state.hasQuestData &&
                                _filters.unlockState != null,
                          )
                        : const _WaitingState()
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
                          title: _translationEnabled
                              ? _catalog
                                        ?.byGameId(selected.id)
                                        ?.translatedName ??
                                    selected.title
                              : selected.title,
                          detail: _translationEnabled
                              ? _catalog
                                        ?.byGameId(selected.id)
                                        ?.translatedDescription ??
                                    selected.detail
                              : selected.detail,
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
    final projection = _projectionFor(live);
    final keywords = _filters.query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    return projection.items
        .where((item) {
          final entry = item.entry;
          if (!item.matchesSearch(keywords)) {
            return false;
          }
          if (_filters.acceptedOnly && !(item.liveQuest?.isAccepted ?? false)) {
            return false;
          }
          if (_filters.category != null &&
              entry.category != _filters.category) {
            return false;
          }
          if (_filters.period != null && entry.period != _filters.period) {
            return false;
          }
          return item.matchesUnlockFilter(_filters.unlockState);
        })
        .map((item) => _QuestViewEntry.fromCatalog(item, _catalog!))
        .toList(growable: false);
  }

  QuestCatalogProjection _projectionFor(Map<int, GameQuest> live) {
    final catalog = _catalog!;
    final available = widget.controller.state.availableQuests;
    final isComplete = widget.controller.state.hasCompleteQuestData;
    final cached = _cachedProjection;
    if (cached != null &&
        identical(_projectedCatalog, catalog) &&
        identical(_projectedLiveQuests, live) &&
        identical(_projectedAvailableQuests, available) &&
        _projectedIsComplete == isComplete) {
      return cached;
    }
    final projection = catalog.project({
      ...available,
      ...live,
    }, isComplete: isComplete);
    _projectedCatalog = catalog;
    _projectedLiveQuests = live;
    _projectedAvailableQuests = available;
    _projectedIsComplete = isComplete;
    _cachedProjection = projection;
    return projection;
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
    required this.translationEnabled,
    required this.onTranslationChanged,
  });

  final QuestCenterMode mode;
  final QuestFilterController filters;
  final ValueChanged<QuestCenterMode> onModeChanged;
  final bool translationEnabled;
  final ValueChanged<bool> onTranslationChanged;

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
          translationEnabled: translationEnabled,
          onTranslationChanged: onTranslationChanged,
          compactTranslation: constraints.maxWidth < 560,
        );
        if (constraints.maxWidth < 430) {
          return Align(
            alignment: Alignment.centerRight,
            child: FittedBox(fit: BoxFit.scaleDown, child: controls),
          );
        }
        return Row(
          children: [
            Text(
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('zh')))
                  .quests,
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
      if (allMode)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Text(
            (AppLocalizations.of(context) ??
                    lookupAppLocalizations(const Locale('zh')))
                .questResultsCount(entries.length),
            key: const Key('quest-results-count'),
            style: const TextStyle(fontSize: 11, color: Color(0xff9fb3bf)),
          ),
        ),
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
                          label: entry.categoryLabel(context),
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
    required this.title,
    required this.detail,
    required this.onRelationSelected,
  });

  final _QuestViewEntry entry;
  final String title;
  final String detail;
  final ValueChanged<int> onRelationSelected;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: SingleChildScrollView(
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
                    title,
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
                _SmallTag(
                  label: entry.categoryLabel(context),
                  color: entry.categoryColor,
                ),
                _SmallTag(
                  label: entry.periodLabel(context),
                  color: entry.periodColor,
                ),
                _SmallTag(
                  label: entry.progressLabel,
                  color: entry.progressColor,
                ),
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
              title: l10n.questDesc,
              child: Text(
                detail.isEmpty
                    ? l10n.noDescription
                    : normalizeQuestDetail(detail),
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
            if (entry.memo.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailCard(
                title: l10n.completionConditions,
                child: Text(entry.memo),
              ),
            ],
            const SizedBox(height: 8),
            _DetailCard(
              title: l10n.baseReward,
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
            if (entry.prerequisites.isNotEmpty ||
                entry.successors.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailCard(
                title: l10n.questRelations,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry.prerequisites.isNotEmpty)
                      _RelationRow(
                        label: l10n.prerequisiteQuests,
                        entries: entry.prerequisites,
                        keyPrefix: 'quest-relation-pre',
                        onSelected: onRelationSelected,
                      ),
                    if (entry.successors.isNotEmpty) ...[
                      if (entry.prerequisites.isNotEmpty)
                        const SizedBox(height: 8),
                      _RelationRow(
                        label: l10n.followingQuests,
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
      ),
    );
  }
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
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(width: 58, child: Text(label)),
      const SizedBox(width: 12),
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
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final positive =
        entry.status != QuestStatus.locked &&
        entry.status != QuestStatus.unknown;
    final color = positive ? const Color(0xff67d2a6) : const Color(0xffe0ad4f);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: positive ? const Color(0xff173a31) : const Color(0xff3b3020),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Text(
        switch (entry.status) {
          QuestStatus.available => l10n.questAvailable,
          QuestStatus.inProgress => l10n.inProgress,
          QuestStatus.claimable => l10n.questClaimable,
          QuestStatus.locked => l10n.questLocked,
          QuestStatus.completed => l10n.questInferredCompleted,
          QuestStatus.unknown => l10n.questStateUnknown,
        },
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

class _QuestEmptyResults extends StatelessWidget {
  const _QuestEmptyResults({required this.filters, required this.needsSync});
  final QuestFilterController filters;
  final bool needsSync;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, color: Color(0xffd4a85f), size: 36),
              const SizedBox(height: 10),
              Text(
                needsSync ? l10n.waitingQuestData : l10n.questNoResults,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                needsSync ? l10n.waitingQuestDataDesc : l10n.questNoResultsHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xff9fb3bf)),
              ),
              if (filters.hasFilters || filters.hasSearch)
                TextButton(
                  key: const Key('quest-empty-clear'),
                  onPressed: filters.clear,
                  child: Text(l10n.clearAll),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
    required this.unlockState,
    required this.status,
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
      unlockState: QuestUnlockState.unlocked,
      status: quest.isServerCompleted
          ? QuestStatus.claimable
          : QuestStatus.inProgress,
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
      unlockState: item.unlockState,
      status: item.status,
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
  final QuestUnlockState unlockState;
  final QuestStatus status;
  final bool allMode;
  final List<int> materials;
  final String rewardsText;
  final String memo;
  final String? exactProgress;
  final List<QuestCatalogEntry> prerequisites;
  final List<QuestCatalogEntry> successors;

  String categoryLabel(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return switch (category) {
      1 => l10n.questFormation,
      2 => l10n.questSortie,
      3 => l10n.questExercise,
      4 => l10n.expedition,
      5 => l10n.questSupplyRepair,
      6 => l10n.questFactory,
      7 => l10n.questRemodeling,
      _ => l10n.questOther,
    };
  }

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

  String periodLabel(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return switch (period) {
      1 => l10n.questDaily,
      2 => l10n.questWeekly,
      3 => l10n.questMonthly,
      4 => l10n.questOneTime,
      5 => l10n.questSeasonal,
      6 => l10n.questYearly,
      _ => l10n.questOther,
    };
  }

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
