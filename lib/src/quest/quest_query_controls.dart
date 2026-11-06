import '../theme/app_palette.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/app_segmented_style.dart';
import 'quest_catalog.dart';

enum QuestCenterMode { active, all }

const _unchanged = Object();

/// A complete, immutable query that can be edited without changing the list.
@immutable
class QuestQuery {
  const QuestQuery({
    this.query = '',
    this.category,
    this.period,
    this.unlockState,
    this.acceptedOnly = false,
    this.status,
  });

  final String query;
  final int? category;
  final int? period;
  final QuestUnlockState? unlockState;
  final bool acceptedOnly;
  final QuestStatus? status;

  QuestQuery copyWith({
    String? query,
    Object? category = _unchanged,
    Object? period = _unchanged,
    Object? unlockState = _unchanged,
    bool? acceptedOnly,
    Object? status = _unchanged,
  }) => QuestQuery(
    query: query ?? this.query,
    category: identical(category, _unchanged)
        ? this.category
        : category as int?,
    period: identical(period, _unchanged) ? this.period : period as int?,
    unlockState: identical(unlockState, _unchanged)
        ? this.unlockState
        : unlockState as QuestUnlockState?,
    acceptedOnly: acceptedOnly ?? this.acceptedOnly,
    status: identical(status, _unchanged)
        ? this.status
        : status as QuestStatus?,
  );

  @override
  bool operator ==(Object other) =>
      other is QuestQuery &&
      query == other.query &&
      category == other.category &&
      period == other.period &&
      unlockState == other.unlockState &&
      acceptedOnly == other.acceptedOnly &&
      status == other.status;

  @override
  int get hashCode =>
      Object.hash(query, category, period, unlockState, acceptedOnly, status);
}

class QuestFilterController extends ChangeNotifier {
  // Keep these public fields for callers using the original controller API.
  String query = '';
  int? category;
  int? period;
  QuestUnlockState? unlockState;
  bool acceptedOnly = false;
  QuestStatus? status;

  /// The page supplies the same projection used to build its result list.
  int? Function(QuestQuery)? previewCount;
  Listenable? previewChanges;

  QuestQuery get value => QuestQuery(
    query: query,
    category: category,
    period: period,
    unlockState: unlockState,
    acceptedOnly: acceptedOnly,
    status: status,
  );

  bool get hasSearch => query.trim().isNotEmpty;
  bool get hasFilters =>
      category != null ||
      period != null ||
      unlockState != null ||
      acceptedOnly ||
      status != null;

  int get activeCount =>
      (hasSearch ? 1 : 0) +
      (category != null ? 1 : 0) +
      (period != null ? 1 : 0) +
      (unlockState != null ? 1 : 0) +
      (acceptedOnly ? 1 : 0) +
      (status != null ? 1 : 0);

  /// Notify once, after every field has been replaced.
  void apply(QuestQuery next) {
    if (value == next) return;
    query = next.query;
    category = next.category;
    period = next.period;
    unlockState = next.unlockState;
    acceptedOnly = next.acceptedOnly;
    status = next.status;
    notifyListeners();
  }

  void setQuery(String value) => apply(this.value.copyWith(query: value));
  void setCategory(int? value) => apply(this.value.copyWith(category: value));
  void setPeriod(int? value) => apply(this.value.copyWith(period: value));
  void setUnlockState(QuestUnlockState? value) =>
      apply(this.value.copyWith(unlockState: value));
  void setAcceptedOnly(bool value) =>
      apply(this.value.copyWith(acceptedOnly: value));
  void setStatus(QuestStatus? value) =>
      apply(this.value.copyWith(status: value));
  void clear() => apply(const QuestQuery());

  String summary(BuildContext context) {
    final l10n = _localizations(context);
    final parts = <String>[
      if (hasSearch) query.trim(),
      if (category case final category?)
        _categories(l10n)[category] ?? category.toString(),
      if (period case final period?)
        _periods(l10n)[period] ?? period.toString(),
      if (status case final status?) _statusLabel(l10n, status),
      if (unlockState case final unlockState?)
        switch (unlockState) {
          QuestUnlockState.unlocked => l10n.questUnlocked,
          QuestUnlockState.locked => l10n.questLocked,
          QuestUnlockState.completed => l10n.questInferredCompleted,
          QuestUnlockState.unknown => l10n.questStateUnknown,
        },
      if (acceptedOnly) l10n.questAcceptedOnly,
    ];
    return parts.join(' · ');
  }
}

AppLocalizations _localizations(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('zh'));

Map<int, String> _categories(AppLocalizations l10n) => <int, String>{
  2: l10n.questSortie,
  1: l10n.questFormation,
  3: l10n.questExercise,
  4: l10n.expedition,
  5: l10n.questSupplyRepair,
  6: l10n.questFactory,
  7: l10n.questRemodeling,
  0: l10n.questOther,
};

Map<int, String> _periods(AppLocalizations l10n) => <int, String>{
  1: l10n.questDaily,
  2: l10n.questWeekly,
  3: l10n.questMonthly,
  4: l10n.questOneTime,
  5: l10n.questSeasonal,
  6: l10n.questYearly,
};

String _statusLabel(AppLocalizations l10n, QuestStatus status) =>
    switch (status) {
      QuestStatus.available => l10n.questAvailable,
      QuestStatus.inProgress => l10n.inProgress,
      QuestStatus.claimable => l10n.questClaimable,
      QuestStatus.completed => l10n.questInferredCompleted,
      QuestStatus.locked => l10n.questLocked,
      QuestStatus.unknown => l10n.questUnknown,
    };

class QuestModeTabs extends StatelessWidget {
  const QuestModeTabs({super.key, required this.mode, required this.onChanged});

  final QuestCenterMode mode;
  final ValueChanged<QuestCenterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = _localizations(context);
    return Container(
      key: const Key('quest-mode-tabs'),
      width: 220,
      height: 40,
      padding: AppSegmentedStyle.padding(),
      decoration: AppSegmentedStyle.decoration(context),
      child: Row(
        children: [
          for (final item in <(QuestCenterMode, String)>[
            (QuestCenterMode.active, l10n.questAccepted),
            (QuestCenterMode.all, l10n.questAll),
          ])
            Expanded(
              child: Semantics(
                button: true,
                selected: item.$1 == mode,
                child: Material(
                  color: AppSegmentedStyle.selection(context, item.$1 == mode),
                  borderRadius: AppSegmentedStyle.itemRadius(),
                  child: InkWell(
                    onTap: () => onChanged(item.$1),
                    borderRadius: AppSegmentedStyle.itemRadius(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Center(
                        child: Text(
                          item.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppSegmentedStyle.textStyle(
                            context,
                            selected: item.$1 == mode,
                          ),
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
  }
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: filters,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final compact = compactTranslation || available < 360;
        final translationWidth = compact ? 40.0 : 112.0;
        final tabsWidth = available.isFinite
            ? math.min(
                220.0,
                math.max(112.0, available - translationWidth - 60),
              )
            : 220.0;
        final l10n = _localizations(context);
        final active = filters.activeCount > 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: translationWidth,
              child: QuestTranslationToggle(
                enabled: translationEnabled,
                compact: compact,
                onChanged: onTranslationChanged,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: tabsWidth,
              child: QuestModeTabs(mode: mode, onChanged: onModeChanged),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: active,
              label: Text('${filters.activeCount}'),
              backgroundColor: appColor(context, const Color(0xffd8a74b)),
              textColor: appColor(context, const Color(0xff11202b)),
              child: SizedBox(
                width: 44,
                height: 40,
                child: IconButton(
                  key: const Key('quest-search-button'),
                  tooltip: active
                      ? '${l10n.questQueryTitle} · ${l10n.questQueryActive(filters.activeCount)}'
                      : l10n.questQueryTitle,
                  onPressed: () => _showQuestQuery(context, filters, mode),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: active
                        ? AppSegmentedStyle.selectedBackground(context)
                        : appColor(context, const Color(0xff0b202d)),
                    side: BorderSide(
                      color: active
                          ? AppSegmentedStyle.selectedBorder(context)
                          : appColor(context, const Color(0xff315064)),
                    ),
                  ),
                  icon: Icon(
                    Icons.search,
                    size: 20,
                    color: active
                        ? AppSegmentedStyle.foreground(context, true)
                        : appColor(context, const Color(0xff9fb3bf)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
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
    final l10n = _localizations(context);
    final label = enabled ? l10n.japaneseOriginal : l10n.chineseTranslation;
    final color = enabled
        ? AppSegmentedStyle.foreground(context, true)
        : appColor(context, const Color(0xff9fb3bf));
    return SizedBox(
      key: const Key('quest-translation-toggle'),
      height: 40,
      width: compact ? 40 : null,
      child: Semantics(
        button: true,
        toggled: enabled,
        label: label,
        child: Material(
          color: enabled
              ? AppSegmentedStyle.selectedBackground(context)
              : appColor(context, const Color(0xff0b202d)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: enabled
                  ? AppSegmentedStyle.selectedBorder(context)
                  : appColor(context, const Color(0xff315064)),
            ),
          ),
          child: InkWell(
            onTap: () => onChanged(!enabled),
            borderRadius: BorderRadius.circular(20),
            child: Tooltip(
              message: label,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.translate,
                      size: 17,
                      color: appColor(context, color),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showQuestQuery(
  BuildContext context,
  QuestFilterController filters,
  QuestCenterMode mode,
) => showDialog<void>(
  barrierDismissible: false,
  context: context,
  requestFocus: false,
  builder: (context) => _QuestQueryDialog(filters: filters, mode: mode),
);

class _QuestQueryDialog extends StatefulWidget {
  const _QuestQueryDialog({required this.filters, required this.mode});

  final QuestFilterController filters;
  final QuestCenterMode mode;

  @override
  State<_QuestQueryDialog> createState() => _QuestQueryDialogState();
}

class _QuestQueryDialogState extends State<_QuestQueryDialog> {
  late QuestQuery _draft = widget.filters.value;
  late final TextEditingController _text = TextEditingController(
    text: _draft.query,
  );
  late final Listenable? _previewChanges = widget.filters.previewChanges;

  @override
  void initState() {
    super.initState();
    _previewChanges?.addListener(_previewChanged);
  }

  void _previewChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _previewChanges?.removeListener(_previewChanged);
    _text.dispose();
    super.dispose();
  }

  void _reset() {
    _text.clear();
    setState(() => _draft = const QuestQuery());
  }

  void _apply() {
    FocusScope.of(context).unfocus();
    widget.filters.apply(_draft);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _localizations(context);
    final count = widget.filters.previewCount?.call(_draft);
    return Dialog(
      key: const Key('quest-query-dialog'),
      backgroundColor: appColor(context, Color(0xff142735)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: 560,
        height: 620,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.questQueryTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('quest-query-reset'),
                    onPressed: _reset,
                    child: Text(l10n.resetFilter),
                  ),
                  IconButton(
                    key: const Key('quest-query-cancel'),
                    tooltip: l10n.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.questQueryScope(
                        widget.mode == QuestCenterMode.active
                            ? l10n.questAccepted
                            : l10n.questAll,
                      ),
                      style: appTextStyle(
                        context,
                        TextStyle(
                          fontSize: 12,
                          color: appColor(context, Color(0xff9fb3bf)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('quest-search-field'),
                      controller: _text,
                      autofocus: false,
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(query: value),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _apply(),
                      decoration: InputDecoration(
                        hintText: l10n.searchQuestHint,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.questType),
                    const SizedBox(height: 6),
                    _choices<int>(
                      values: _categories(l10n),
                      allLabel: l10n.allTypes,
                      selected: _draft.category,
                      keyPrefix: 'quest-filter-category',
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(category: value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.questPeriod),
                    const SizedBox(height: 6),
                    _choices<int>(
                      values: _periods(l10n),
                      allLabel: l10n.allPeriods,
                      selected: _draft.period,
                      keyPrefix: 'quest-filter-period',
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(period: value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.allStatuses),
                    const SizedBox(height: 6),
                    _choices<QuestStatus>(
                      values: {
                        for (final status in QuestStatus.values)
                          status: _statusLabel(l10n, status),
                      },
                      allLabel: l10n.allStatuses,
                      selected: _draft.status,
                      keyPrefix: 'quest-filter-status',
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(
                          status: value,
                          unlockState: null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton(
                key: const Key('quest-query-apply'),
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(
                  count == null ? l10n.done : l10n.questApplyQuery(count),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choices<T>({
    required Map<T, String> values,
    required String allLabel,
    required T? selected,
    required String keyPrefix,
    required ValueChanged<T?> onChanged,
  }) => Wrap(
    spacing: 6,
    runSpacing: 4,
    children: [
      ChoiceChip(
        key: Key('$keyPrefix-all'),
        label: Text(allLabel),
        selected: selected == null,
        onSelected: (_) => onChanged(null),
      ),
      for (final item in values.entries)
        ChoiceChip(
          key: Key(
            '$keyPrefix-${item.key is Enum ? (item.key as Enum).name : item.key}',
          ),
          label: Text(item.value),
          selected: selected == item.key,
          onSelected: (_) => onChanged(selected == item.key ? null : item.key),
        ),
    ],
  );
}
