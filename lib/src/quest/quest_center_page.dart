// ignore_for_file: use_null_aware_elements

import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import '../localization/game_name_localizations.dart';

import '../../l10n/app_localizations.dart';
import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/quest_text_normalizer.dart';
import '../layout/adaptive_layout.dart';
import '../settings/display_mode_store.dart';
import 'quest_catalog.dart';
import 'quest_progress_engine.dart';
import 'quest_catalog_controller.dart';
import 'quest_query_controls.dart';

export 'quest_query_controls.dart';

class QuestCenterPage extends StatefulWidget {
  const QuestCenterPage({
    super.key,
    required this.controller,
    this.initialQuestId,
    this.showTitle = true,
    this.displayMode = DisplayMode.auto,
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
  final DisplayMode displayMode;
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
  late int? _targetQuestId = widget.initialQuestId;
  late bool _explicitTarget = widget.initialQuestId != null;
  late QuestCenterMode _mode = widget.mode;
  final _listController = ScrollController();
  final _detailController = ScrollController();
  final _history = <({int id, int tab, double offset})>[];
  int _detailTab = 0;
  bool _selectionRequired = false;
  QuestQuery? _appliedQuery;
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
  AppLocalizations get _l10n =>
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));

  @override
  void initState() {
    super.initState();
    _catalog = widget.catalogController?.catalog ?? widget.catalog;
    _appliedQuery = _filters.value;
    if (_catalog == null) _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final catalog = await QuestCatalog.loadAsset();
    if (mounted) setState(() => _catalog = catalog);
  }

  @override
  void dispose() {
    if (_filters.previewCount == _previewCount) {
      _filters.previewCount = null;
      _filters.previewChanges = null;
    }
    _listController.dispose();
    _detailController.dispose();
    _localFilters.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(QuestCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuestId != null &&
        widget.initialQuestId != oldWidget.initialQuestId) {
      _selectedQuestId = _targetQuestId = widget.initialQuestId;
      _explicitTarget = true;
      _selectionRequired = false;
      _history.clear();
      _detailTab = 0;
    }
    if (widget.mode != oldWidget.mode) {
      _mode = widget.mode;
      _history.clear();
      if (widget.initialQuestId == oldWidget.initialQuestId) {
        _explicitTarget = false;
      }
    }
    if (widget.catalog != oldWidget.catalog && widget.catalog != null) {
      _catalog = widget.catalog;
    }
    if (widget.catalogController != oldWidget.catalogController &&
        widget.catalogController != null) {
      _catalog = widget.catalogController!.catalog;
    }
    if (widget.filterController != oldWidget.filterController) {
      final previous = oldWidget.filterController ?? _localFilters;
      if (previous.previewCount == _previewCount) {
        previous.previewCount = null;
        previous.previewChanges = null;
      }
      _appliedQuery = null;
    }
  }

  void _changeTranslation(bool enabled) {
    if (widget.translationEnabled == null) {
      setState(() => _localTranslationEnabled = enabled);
    }
    widget.onTranslationChanged?.call(enabled);
  }

  void _changeMode(QuestCenterMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _history.clear();
      _explicitTarget = false;
    });
    widget.onModeChanged?.call(mode);
  }

  double get _detailOffset =>
      _detailController.hasClients ? _detailController.offset : 0;

  void _restoreDetailOffset(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_detailController.hasClients) return;
      _detailController.jumpTo(
        offset.clamp(0, _detailController.position.maxScrollExtent),
      );
    });
  }

  void _openQuest(int id) {
    setState(() {
      _selectedQuestId = _targetQuestId = id;
      _explicitTarget = false;
      _selectionRequired = false;
      _history.clear();
      _detailTab = 0;
    });
    _restoreDetailOffset(0);
  }

  void _selectRelation(int id) {
    if (id == _selectedQuestId || _entryById(id) == null) return;
    final previousId = _selectedQuestId;
    final offset = _detailOffset;
    setState(() {
      if (previousId != null) {
        _history.add((id: previousId, tab: _detailTab, offset: offset));
      }
      _targetQuestId ??= previousId;
      _selectedQuestId = id;
      _detailTab = 0;
    });
    _restoreDetailOffset(0);
  }

  void _back() {
    if (_history.isNotEmpty) {
      final previous = _history.removeLast();
      setState(() {
        _selectedQuestId = previous.id;
        _detailTab = previous.tab;
      });
      _restoreDetailOffset(previous.offset);
    }
  }

  void _returnToTarget() {
    setState(() {
      _selectedQuestId = _targetQuestId;
      _history.clear();
      _detailTab = 0;
    });
    _restoreDetailOffset(0);
  }

  bool _horizontal(Size size) =>
      classifyAdaptiveWindow(size) == AdaptiveWindowClass.nearSquareLarge ||
      switch (widget.displayMode) {
        DisplayMode.landscape => true,
        DisplayMode.portrait => false,
        DisplayMode.auto => size.width > size.height,
      };

  int? _previewCount(QuestQuery query) {
    if (!mounted || (_mode == QuestCenterMode.all && _catalog == null)) {
      return null;
    }
    return _entries(widget.controller.state.quests, query: query).length;
  }

  @override
  Widget build(BuildContext context) => Material(
    color: appColor(context, Color(0xff081521)),
    child: AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        _filters,
        if (widget.catalogController case final controller?) controller,
      ]),
      builder: (context, _) {
        _catalog = widget.catalogController?.catalog ?? _catalog;
        _filters.previewCount = _previewCount;
        _filters.previewChanges = Listenable.merge([
          widget.controller,
          if (widget.catalogController case final controller?) controller,
        ]);
        final horizontal = _horizontal(MediaQuery.sizeOf(context));
        final entries = _entries(widget.controller.state.quests);
        if (_appliedQuery != _filters.value) {
          _appliedQuery = _filters.value;
          _history.clear();
          _explicitTarget = false;
          if (!entries.any((e) => e.id == _selectedQuestId)) {
            _selectedQuestId = null;
            _selectionRequired = true;
          }
          _targetQuestId = _selectedQuestId;
          if (_listController.hasClients) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _listController.hasClients) {
                _listController.jumpTo(0);
              }
            });
          }
        }
        if (_selectedQuestId == null &&
            !_selectionRequired &&
            entries.isNotEmpty) {
          _selectedQuestId = _targetQuestId = entries.first.id;
        }
        final selected = _history.isNotEmpty || _explicitTarget
            ? _entryById(_selectedQuestId)
            : entries.where((e) => e.id == _selectedQuestId).firstOrNull;
        final loading = _mode == QuestCenterMode.all && _catalog == null;
        final list = _QuestListPanel(
          key: const Key('quest-list-panel'),
          entries: entries,
          selectedQuestId: _selectedQuestId,
          filters: _filters,
          controller: _listController,
          translationEnabled: _translationEnabled,
          shrinkWrap: !horizontal,
          onSelected: _openQuest,
          empty: loading
              ? const Center(
                  key: Key('quest-catalog-loading'),
                  heightFactor: 1,
                  child: CircularProgressIndicator(),
                )
              : _mode == QuestCenterMode.active &&
                    !_filters.hasSearch &&
                    !_filters.hasFilters
              ? _WaitingState(
                  syncedEmpty:
                      widget.controller.state.hasQuestData &&
                      widget.controller.state.activeQuestCount == 0,
                )
              : _QuestEmptyResults(
                  filters: _filters,
                  needsSync:
                      !widget.controller.state.hasQuestData &&
                      _filters.unlockState != null,
                ),
        );
        final detail = selected == null
            ? Center(
                key: const Key('quest-detail-placeholder'),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _l10n.questSelectTask,
                    textAlign: TextAlign.center,
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, Color(0xff9fb3bf))),
                    ),
                  ),
                ),
              )
            : _QuestDetail(
                key: const Key('quest-detail-panel'),
                entry: selected,
                title: _questTitle(selected),
                detail: _questDescription(selected),
                translationEnabled: _translationEnabled,
                serverProgress: widget
                    .controller
                    .state
                    .quests[selected.id]
                    ?.serverProgressPercentLabel,
                steps:
                    widget.controller.questProgress?.stepsFor(selected.id) ??
                    const [],
                controller: _detailController,
                tab: _detailTab,
                onTabChanged: (index) {
                  setState(() => _detailTab = index);
                  _restoreDetailOffset(0);
                },
                onRelationSelected: _selectRelation,
                relationEntry: _entryById,
                catalog: _catalog,
                onBack: _history.isNotEmpty ? _back : null,
                hasHistory: _history.isNotEmpty,
                onReturnToTarget:
                    _history.length > 1 &&
                        _selectedQuestId != _targetQuestId &&
                        _history.last.id != _targetQuestId
                    ? _returnToTarget
                    : null,
              );
        return PopScope(
          canPop: _history.isEmpty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: Column(
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
                child: horizontal
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final left = (width * .38).clamp(
                            width < 400
                                ? width * .38
                                : width < 580
                                ? 170.0
                                : 210.0,
                            width * .46,
                          );
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: left, child: list),
                              const VerticalDivider(width: 1),
                              Expanded(child: detail),
                            ],
                          );
                        },
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxHeight <= 1) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: (constraints.maxHeight - 1) / 2,
                                ),
                                child: list,
                              ),
                              const Divider(height: 1, thickness: 1),
                              Expanded(child: detail),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );

  String _questTitle(_QuestViewEntry entry) => _translationEnabled
      ? _catalog?.byGameId(entry.id)?.translatedName ?? entry.title
      : entry.title;
  String _questDescription(_QuestViewEntry entry) => _translationEnabled
      ? _catalog?.byGameId(entry.id)?.translatedDescription ?? entry.detail
      : entry.detail;

  List<_QuestViewEntry> _entries(
    Map<int, GameQuest> live, {
    QuestQuery? query,
  }) {
    final filters = query ?? _filters.value;
    final keywords = filters.query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final names = gameNames(context);
    bool matches(_QuestViewEntry item, QuestCatalogItem? projected) {
      if (projected != null) {
        if (!projected.matchesSearch(keywords, displayText: names.entityText)) {
          return false;
        }
      } else if (keywords.isNotEmpty) {
        final doc = _catalog?.byGameId(item.id);
        final source =
            '${item.id} ${item.code} ${item.title} ${item.detail} ${doc?.translatedName ?? ''} ${doc?.translatedDescription ?? ''} ${item.memo} ${item.rewardsText}';
        if (!keywords.any(source.toLowerCase().contains) &&
            !keywords.any(names.entityText(source).toLowerCase().contains)) {
          return false;
        }
      }
      if (filters.acceptedOnly && !(live[item.id]?.isAccepted ?? false)) {
        return false;
      }
      if (filters.category != null && filters.category != item.category) {
        return false;
      }
      if (filters.period != null && filters.period != item.period) return false;
      if (filters.status != null && filters.status != item.status) return false;
      return projected?.matchesUnlockFilter(filters.unlockState) ??
          (filters.unlockState == null ||
              filters.unlockState == QuestUnlockState.unlocked ||
              filters.unlockState == QuestUnlockState.completed &&
                  item.status == QuestStatus.claimable);
    }

    List<_QuestViewEntry> values;
    if (_mode == QuestCenterMode.active) {
      values =
          live.values
              .where((q) => q.isAccepted)
              .map((q) => _QuestViewEntry.fromLive(q, _catalog))
              .where((q) => matches(q, null))
              .toList()
            ..sort((a, b) {
              final claimable = (b.status == QuestStatus.claimable ? 1 : 0)
                  .compareTo(a.status == QuestStatus.claimable ? 1 : 0);
              return claimable != 0 ? claimable : a.id.compareTo(b.id);
            });
    } else {
      if (_catalog == null) return const [];
      values = _projectionFor(live).items
          .where(
            (item) =>
                matches(_QuestViewEntry.fromCatalog(item, _catalog!), item),
          )
          .map((item) => _QuestViewEntry.fromCatalog(item, _catalog!))
          .toList();
    }
    final exact = filters.query.trim().toLowerCase();
    if (exact.isNotEmpty) {
      final ranked = [
        for (var i = 0; i < values.length; i++) (index: i, entry: values[i]),
      ];
      int priority(_QuestViewEntry e) =>
          e.code.toLowerCase() == exact || '${e.id}' == exact ? 0 : 1;
      ranked.sort((a, b) {
        final p = priority(a.entry).compareTo(priority(b.entry));
        return p != 0 ? p : a.index.compareTo(b.index);
      });
      values = ranked.map((e) => e.entry).toList();
    }
    return values;
  }

  _QuestViewEntry? _entryById(int? id) {
    if (id == null) return null;
    final live = widget.controller.state.quests;
    if (_catalog != null) {
      final item = _projectionFor(
        live,
      ).items.where((e) => e.gameId == id).firstOrNull;
      if (item != null) return _QuestViewEntry.fromCatalog(item, _catalog!);
    }
    final quest = live[id];
    return quest == null ? null : _QuestViewEntry.fromLive(quest, _catalog);
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
        _projectedIsComplete == isComplete &&
        widget.controller.questProgress == null) {
      return cached;
    }
    final projection = catalog.project(
      {...available, ...live},
      isComplete: isComplete,
      confirmedCompleted: widget.controller.completedQuestIds,
    );
    _projectedCatalog = catalog;
    _projectedLiveQuests = live;
    _projectedAvailableQuests = available;
    _projectedIsComplete = isComplete;
    return _cachedProjection = projection;
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
    decoration: BoxDecoration(
      color: appColor(context, Color(0xff0d1a26)),
      border: Border(
        bottom: BorderSide(color: appColor(context, Color(0xff294052))),
      ),
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
          return Align(alignment: Alignment.centerRight, child: controls);
        }
        return Row(
          children: [
            Text(
              (AppLocalizations.of(context) ??
                      lookupAppLocalizations(const Locale('zh')))
                  .quests,
              style: appTextStyle(
                context,
                TextStyle(
                  color: appColor(context, Color(0xffd4a85f)),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: controls),
            ),
          ],
        );
      },
    ),
  );
}

class _QuestListPanel extends StatelessWidget {
  const _QuestListPanel({
    super.key,
    required this.entries,
    required this.selectedQuestId,
    required this.filters,
    required this.controller,
    required this.translationEnabled,
    required this.onSelected,
    required this.empty,
    this.shrinkWrap = false,
  });
  final List<_QuestViewEntry> entries;
  final int? selectedQuestId;
  final QuestFilterController filters;
  final ScrollController controller;
  final bool translationEnabled;
  final ValueChanged<int> onSelected;
  final Widget empty;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final summary = filters.summary(context);
    return Column(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 6, 3),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  l10n.questResultsCount(entries.length),
                  key: const Key('quest-results-count'),
                  style: appTextStyle(
                    context,
                    TextStyle(
                      fontSize: 11,
                      color: appColor(context, Color(0xff9fb3bf)),
                    ),
                  ),
                ),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Tooltip(
                    message: summary,
                    child: Text(
                      summary,
                      key: const Key('quest-query-summary'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: appTextStyle(
                        context,
                        TextStyle(
                          fontSize: 11,
                          color: appColor(context, Color(0xffe4b666)),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    key: const Key('quest-query-clear'),
                    tooltip: l10n.clearAll,
                    padding: EdgeInsets.zero,
                    iconSize: 17,
                    onPressed: filters.clear,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ],
          ),
        ),
        Flexible(
          fit: shrinkWrap ? FlexFit.loose : FlexFit.tight,
          child: entries.isEmpty
              ? empty
              : ListView.separated(
                  key: const PageStorageKey('quest-results-list'),
                  controller: controller,
                  shrinkWrap: shrinkWrap,
                  padding: const EdgeInsets.fromLTRB(8, 3, 8, 10),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 5),
                  itemBuilder: (context, index) => _QuestCard(
                    entry: entries[index],
                    selected: entries[index].id == selectedQuestId,
                    title: translationEnabled
                        ? entries[index].translatedTitle
                        : entries[index].title,
                    onTap: () => onSelected(entries[index].id),
                  ),
                ),
        ),
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.entry,
    required this.selected,
    required this.title,
    required this.onTap,
  });
  final _QuestViewEntry entry;
  final bool selected;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    key: Key('quest-card-${entry.id}'),
    color: appColor(
      context,
      selected ? const Color(0xff183041) : const Color(0xff102331),
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: appColor(
          context,
          selected ? const Color(0xffb28a43) : const Color(0xff294052),
        ),
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final tags = Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _QuestCodeTag(
                      key: Key('quest-card-code-${entry.id}'),
                      code: entry.code,
                    ),
                    _SmallTag(
                      label: entry.categoryLabel(context),
                      color: appColor(context, entry.categoryColor),
                      pill: true,
                    ),
                    _SmallTag(
                      label: entry.periodLabel(context),
                      color: appColor(context, entry.periodColor),
                      pill: true,
                    ),
                  ],
                );
                final statusAndProgress = Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusBadge(
                      key: Key('quest-card-status-${entry.id}'),
                      entry: entry,
                    ),
                    _SmallTag(
                      key: Key('quest-card-progress-${entry.id}'),
                      label: entry.progressLabel,
                      color: appColor(context, entry.progressColor),
                      pill: true,
                    ),
                  ],
                );
                if (constraints.maxWidth <
                    MediaQuery.textScalerOf(context).scale(200)) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      tags,
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: statusAndProgress,
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tags),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * .47,
                      ),
                      child: statusAndProgress,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 5),
            Tooltip(
              message: title,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: appColor(context, Color(0xffe6edf2)),
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuestDetail extends StatelessWidget {
  const _QuestDetail({
    super.key,
    required this.entry,
    required this.title,
    required this.detail,
    required this.translationEnabled,
    required this.controller,
    required this.tab,
    required this.onTabChanged,
    required this.onRelationSelected,
    required this.relationEntry,
    required this.catalog,
    required this.hasHistory,
    this.onBack,
    this.onReturnToTarget,
    this.steps = const [],
    this.serverProgress,
  });
  final _QuestViewEntry entry;
  final String title, detail;
  final bool translationEnabled, hasHistory;
  final ScrollController controller;
  final int tab;
  final ValueChanged<int> onTabChanged, onRelationSelected;
  final _QuestViewEntry? Function(int?) relationEntry;
  final QuestCatalog? catalog;
  final VoidCallback? onBack, onReturnToTarget;
  final List<QuestStepProgress> steps;
  final String? serverProgress;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return DefaultTextStyle.merge(
      style: TextStyle(color: appColor(context, Color(0xffe6edf2))),
      child: Column(
        children: [
          if (onBack != null || onReturnToTarget != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  if (onBack != null)
                    Flexible(
                      child: TextButton.icon(
                        key: Key(
                          hasHistory
                              ? 'quest-relation-back'
                              : 'quest-back-to-list',
                        ),
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: Text(
                          hasHistory ? l10n.back : l10n.questBackToList,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (onReturnToTarget != null) ...[
                    const Spacer(),
                    Flexible(
                      child: TextButton(
                        key: const Key('quest-return-target'),
                        onPressed: onReturnToTarget,
                        child: Text(
                          l10n.questReturnToTarget,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey('quest-detail-scroll'),
              controller: controller,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _QuestCodeTag(
                      key: Key('quest-detail-code-${entry.id}'),
                      code: entry.code,
                      large: true,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Padding(
                    key: Key('quest-detail-title-${entry.id}'),
                    padding: EdgeInsets.zero,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      _SmallTag(
                        label: entry.categoryLabel(context),
                        color: appColor(context, Color(0xff9fb3bf)),
                      ),
                      _SmallTag(
                        label: entry.periodLabel(context),
                        color: appColor(context, Color(0xff9fb3bf)),
                      ),
                      _StatusBadge(
                        key: Key('quest-detail-status-${entry.id}'),
                        entry: entry,
                      ),
                      if (entry.progressLabel != '—')
                        _SmallTag(
                          key: entry.progressLabel == entry.exactProgress
                              ? Key('quest-detail-exact-progress-${entry.id}')
                              : null,
                          label: entry.progressLabel,
                          color: appColor(
                            context,
                            entry.progressLabel == entry.exactProgress
                                ? const Color(0xff8ec6e8)
                                : entry.progressColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final labels = [
                        l10n.questConditionsAndProgress,
                        l10n.baseReward,
                        l10n.questRelations,
                      ];
                      return Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (var index = 0; index < labels.length; index++)
                            TextButton(
                              key: Key(
                                'quest-detail-tab-${['conditions', 'rewards', 'relations'][index]}',
                              ),
                              onPressed: () => onTabChanged(index),
                              style: TextButton.styleFrom(
                                foregroundColor: appColor(
                                  context,
                                  tab == index
                                      ? const Color(0xffffd47a)
                                      : const Color(0xff9fb3bf),
                                ),
                                backgroundColor: appColor(
                                  context,
                                  tab == index
                                      ? const Color(0xff3a3020)
                                      : Colors.transparent,
                                ),
                                minimumSize: const Size(0, 38),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                ),
                              ),
                              child: Text(
                                labels[index],
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  Divider(
                    color: appColor(context, Color(0xff294052)),
                    height: 18,
                  ),
                  if (tab == 0) ...[
                    _DetailCard(
                      title: l10n.completionConditions,
                      child: Text(
                        detail.isEmpty
                            ? l10n.noDescription
                            : normalizeQuestDetail(detail),
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                    ),
                    if (steps.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      _DetailCard(
                        title: l10n.questLocalProgress,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (serverProgress != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  l10n.questServerProgress(serverProgress!),
                                  style: appTextStyle(
                                    context,
                                    TextStyle(
                                      fontSize: 12,
                                      color: appColor(
                                        context,
                                        Color(0xff9fb3bf),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            for (final step in steps)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        step.description,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${step.count}/${step.required}',
                                      style: appTextStyle(
                                        context,
                                        TextStyle(
                                          fontSize: 13,
                                          color: step.count >= step.required
                                              ? const Color(0xff67d6a3)
                                              : const Color(0xffdbe8ef),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (translationEnabled && entry.memo.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      _DetailCard(
                        title: l10n.questDesc,
                        child: Text(
                          entry.memo,
                          style: const TextStyle(fontSize: 13, height: 1.6),
                        ),
                      ),
                    ],
                  ],
                  if (tab == 1)
                    _DetailCard(
                      title: l10n.baseReward,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              for (var index = 0; index < 4; index++) ...[
                                if (index > 0) const SizedBox(width: 6),
                                Expanded(
                                  child: _MaterialReward(
                                    assetIndex: index + 1,
                                    value: entry.materials[index],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (entry.rewardsText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              entry.rewardsText,
                              style: const TextStyle(fontSize: 13, height: 1.6),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (tab == 2) ...[
                    _RelationRow(
                      label: l10n.prerequisiteQuests,
                      entries: entry.prerequisites,
                      unresolvedCodes:
                          catalog?.unresolvedPrerequisitesOf(entry.id) ??
                          const [],
                      keyPrefix: 'quest-relation-pre',
                      onSelected: onRelationSelected,
                      translationEnabled: translationEnabled,
                      relationEntry: relationEntry,
                      catalog: catalog,
                      visited: {entry.id},
                    ),
                    const SizedBox(height: 15),
                    _RelationRow(
                      label: l10n.followingQuests,
                      entries: entry.successors,
                      keyPrefix: 'quest-relation-post',
                      onSelected: onRelationSelected,
                      translationEnabled: translationEnabled,
                      relationEntry: relationEntry,
                      catalog: null,
                      visited: {entry.id},
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
    required this.translationEnabled,
    required this.relationEntry,
    required this.catalog,
    required this.visited,
    this.unresolvedCodes = const [],
    this.depth = 0,
  });
  final String label, keyPrefix;
  final List<QuestCatalogEntry> entries;
  final List<String> unresolvedCodes;
  final ValueChanged<int> onSelected;
  final bool translationEnabled;
  final _QuestViewEntry? Function(int?) relationEntry;
  final QuestCatalog? catalog;
  final Set<int> visited;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: appTextStyle(
            context,
            TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: appColor(context, Color(0xffd4a85f)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty && unresolvedCodes.isEmpty)
          Text(
            keyPrefix.startsWith('quest-relation-post')
                ? l10n.questNoSuccessors
                : l10n.questNoPrerequisites,
            style: appTextStyle(
              context,
              TextStyle(
                fontSize: 12,
                color: appColor(context, Color(0xff9fb3bf)),
              ),
            ),
          ),
        for (final doc in entries) ...[
          Material(
            color: appColor(context, Color(0xff102331)),
            borderRadius: BorderRadius.circular(7),
            child: InkWell(
              key: Key('$keyPrefix-${doc.gameId}'),
              onTap: visited.contains(doc.gameId)
                  ? null
                  : () => onSelected(doc.gameId),
              borderRadius: BorderRadius.circular(7),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _QuestCodeTag(
                              key: Key('quest-relation-code-${doc.gameId}'),
                              code: doc.code,
                            ),
                          ),
                        ),
                        if (relationEntry(doc.gameId) case final status?) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _StatusBadge(entry: status),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            translationEnabled
                                ? doc.translatedName ?? doc.name
                                : doc.name,
                            style: appTextStyle(
                              context,
                              TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: appColor(context, Color(0xffe6edf2)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          size: 19,
                          color: appColor(context, Color(0xff9fb3bf)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (catalog != null &&
              depth < 4 &&
              !visited.contains(doc.gameId) &&
              (catalog!.prerequisitesOf(doc.gameId).isNotEmpty ||
                  catalog!.unresolvedPrerequisitesOf(doc.gameId).isNotEmpty))
            ExpansionTile(
              key: PageStorageKey('quest-expand-pre-${doc.gameId}'),
              tilePadding: const EdgeInsets.only(left: 12),
              visualDensity: VisualDensity.compact,
              title: Text(
                l10n.prerequisiteQuests,
                style: appTextStyle(
                  context,
                  TextStyle(
                    fontSize: 12,
                    color: appColor(context, Color(0xff9fb3bf)),
                  ),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _RelationRow(
                    label: doc.code,
                    entries: catalog!.prerequisitesOf(doc.gameId),
                    unresolvedCodes: catalog!.unresolvedPrerequisitesOf(
                      doc.gameId,
                    ),
                    keyPrefix: '$keyPrefix-${doc.gameId}',
                    onSelected: onSelected,
                    translationEnabled: translationEnabled,
                    relationEntry: relationEntry,
                    catalog: catalog,
                    visited: {...visited, doc.gameId},
                    depth: depth + 1,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
        ],
        for (final code in unresolvedCodes)
          Container(
            key: Key('$keyPrefix-unresolved-$code'),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: appColor(context, Color(0xff102331)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _QuestCodeTag(code: code),
                _SmallTag(
                  label: l10n.questStateUnknown,
                  color: appColor(context, Color(0xffe0ad4f)),
                ),
              ],
            ),
          ),
      ],
    );
  }
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
        color: appColor(context, color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: appColor(context, color.withValues(alpha: 0.65)),
        ),
      ),
      child: Text(
        code,
        maxLines: 1,
        style: appTextStyle(
          context,
          TextStyle(
            color: color,
            fontSize: large ? 13 : 10.5,
            fontWeight: FontWeight.w900,
          ),
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
        color: appColor(
          context,
          positive ? const Color(0xff173a31) : const Color(0xff3b3020),
        ),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: appColor(context, color.withValues(alpha: 0.75)),
        ),
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
        style: appTextStyle(
          context,
          TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
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
      color: appColor(context, Color(0xff142735)),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: appColor(context, Color(0xff294052))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: appTextStyle(
            context,
            TextStyle(
              color: appColor(context, Color(0xffd4a85f)),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
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
  Widget build(BuildContext context) => Row(
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '$value',
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
  );
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({
    super.key,
    required this.label,
    this.color = const Color(0xffa9bdc8),
    this.pill = false,
  });

  final String label;
  final Color color;
  final bool pill;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: appColor(context, color.withValues(alpha: 0.2)),
      borderRadius: BorderRadius.circular(pill ? 20 : 5),
    ),
    child: Text(
      label,
      style: appTextStyle(
        context,
        TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
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
      heightFactor: 1,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                color: appColor(context, Color(0xffd4a85f)),
                size: 36,
              ),
              const SizedBox(height: 10),
              Text(
                needsSync ? l10n.waitingQuestData : l10n.questNoResults,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                needsSync ? l10n.waitingQuestDataDesc : l10n.questNoResultsHint,
                textAlign: TextAlign.center,
                style: appTextStyle(
                  context,
                  TextStyle(color: appColor(context, Color(0xff9fb3bf))),
                ),
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
  const _WaitingState({required this.syncedEmpty});

  final bool syncedEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Center(
      heightFactor: 1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              color: appColor(context, Color(0xffd4a85f)),
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              syncedEmpty ? l10n.noPinnedQuests : l10n.waitingQuestData,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (!syncedEmpty) ...[
              const SizedBox(height: 7),
              Text(
                l10n.waitingQuestDataDesc,
                textAlign: TextAlign.center,
                style: appTextStyle(
                  context,
                  TextStyle(color: appColor(context, Color(0xff8197a5))),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestViewEntry {
  const _QuestViewEntry({
    required this.id,
    required this.code,
    required this.title,
    required this.translatedTitle,
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
      translatedTitle: doc?.translatedName ?? quest.title,
      detail: quest.detail,
      category: switch (quest.category) {
        8 || 9 || 10 => 2,
        11 => 6,
        _ => quest.category,
      },
      // API type 5 covers both seasonal and yearly quests. Only catalog
      // recurrence metadata can distinguish them; retain the API fallback.
      period: quest.type == 5 && doc?.period == 6 ? 6 : quest.type,
      progressLabel: quest.displayProgressLabel,
      completed: quest.isCompleted,
      locked: false,
      unlockState: QuestUnlockState.unlocked,
      status: quest.isServerCompleted
          ? QuestStatus.claimable
          : QuestStatus.inProgress,
      allMode: false,
      materials: quest.materials,
      rewardsText: doc?.rewards ?? '',
      memo: doc?.memo ?? '',
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
      translatedTitle: doc.translatedName ?? doc.name,
      detail: doc.description,
      category: doc.category,
      period: doc.period,
      progressLabel: item.progressLabel,
      completed: live?.isCompleted ?? item.inferredCompleted,
      locked: item.unlockState == QuestUnlockState.locked,
      unlockState: item.unlockState,
      status: item.status,
      allMode: true,
      materials: live?.materials ?? doc.materials,
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
  final String translatedTitle;
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
    if (completed) return const Color(0xff67d2a6);
    final fraction = progressLabel.split('/');
    if (fraction.length == 2) {
      final current = int.tryParse(fraction[0]) ?? 0;
      final total = int.tryParse(fraction[1]) ?? 0;
      if (total > 0 && current * 2 >= total) return const Color(0xffe0ad4f);
    }
    if (progressLabel == '100%' || progressLabel == '50%+') {
      return const Color(0xff67d2a6);
    }
    if (progressLabel == '80%+') return const Color(0xffe0ad4f);
    return const Color(0xffa9bdc8);
  }
}
