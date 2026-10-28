import '../localization/game_name_localizations.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../game_state/game_state_controller.dart';
import '../game_state/game_state.dart';
import '../settings/layout_settings_controller.dart';
import '../widgets/top_notice.dart';
import 'quest_completion_drawer.dart';
import 'quest_completion_tracker.dart';
import 'quest_progress_rules.dart';

/// Mount once above the workspace layout so navigation cannot reset alerts.
class QuestCompletionFeedback extends StatefulWidget {
  const QuestCompletionFeedback({
    super.key,
    required this.controller,
    required this.layoutSettingsController,
    required this.builder,
  });

  final GameStateController controller;
  final LayoutSettingsController layoutSettingsController;
  final Widget Function(BuildContext context, int completedCount) builder;

  @override
  State<QuestCompletionFeedback> createState() =>
      _QuestCompletionFeedbackState();
}

class _QuestCompletionFeedbackState extends State<QuestCompletionFeedback> {
  late QuestCompletionTracker _tracker;
  bool _noticeScheduled = false;
  int _generation = 0;
  int? _pendingMemberId;
  final Map<int, GameQuest> _pendingQuests = {};
  final Map<int, GameQuest> _pendingVerification = {};
  final Map<int, String> _fullUnverified = {};
  final Map<int, String> _announcedVerification = {};

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _pendingMemberId = widget.controller.state.memberId;
    _seedVerification(widget.controller.state, DateTime.now().toUtc());
    _tracker = QuestCompletionTracker(
      widget.controller.state,
      now: DateTime.now().toUtc(),
      periodFor: widget.controller.questProgress?.periodFor,
    );
    widget.controller.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(QuestCompletionFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onStateChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) QuestCompletionDrawerHost.removeQuestNotices(context);
      });
      _generation++;
      _noticeScheduled = false;
      _pendingQuests.clear();
      _pendingVerification.clear();
      _pendingMemberId = null;
      _attach();
    }
  }

  void _onStateChanged() {
    final state = widget.controller.state;
    final now = DateTime.now().toUtc();
    final previousCount = _tracker.completedCount;
    final newlyCompleted = _tracker.update(state, now: now);
    if (_tracker.completedCount != previousCount) setState(() {});
    if (_pendingMemberId != state.memberId) {
      _pendingQuests.clear();
      _pendingVerification.clear();
      _pendingMemberId = state.memberId;
      _seedVerification(state, now);
      QuestCompletionDrawerHost.removeQuestNotices(context);
    } else {
      for (final quest in _newlyFullUnverified(state, now)) {
        _pendingVerification[quest.id] = quest;
      }
    }
    if ((!newlyCompleted && _pendingVerification.isEmpty) ||
        !widget.layoutSettingsController.topNoticeEnabled) {
      return;
    }
    for (final quest in _tracker.latestCompletedQuests) {
      _pendingQuests[quest.id] = quest;
    }
    if (_noticeScheduled) return;
    _noticeScheduled = true;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      _noticeScheduled = false;
      final currentState = widget.controller.state;
      if (currentState.memberId != _pendingMemberId) {
        _pendingQuests.clear();
        _pendingVerification.clear();
        return;
      }
      final noticeTime = DateTime.now().toUtc();
      final recent = _pendingQuests.values.where((quest) {
        final current = currentState.quests[quest.id];
        // The completed snapshot remains valid after a quick claim. Keep
        // rejecting a local prediction that a live task has since contradicted.
        final show =
            _isCurrentPeriod(quest, noticeTime) &&
            (quest.isServerCompleted ||
                current == null ||
                (current.isCompleted && current.isAccepted));
        if (!show) _tracker.cancelPendingAlert(quest.id);
        return show;
      }).toList();
      _pendingQuests.clear();
      final completedIds = recent.map((quest) => quest.id).toSet();
      final awaiting = _pendingVerification.values.where((quest) {
        if (completedIds.contains(quest.id)) return false;
        final current = currentState.quests[quest.id];
        final show =
            _isCurrentPeriod(quest, noticeTime) &&
            (current == null || _isFullUnverified(current, noticeTime));
        if (!show) _announcedVerification.remove(quest.id);
        return show;
      }).toList();
      _pendingVerification.clear();
      if ((recent.isEmpty && awaiting.isEmpty) ||
          !widget.layoutSettingsController.topNoticeEnabled) {
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      if (recent.isNotEmpty) {
        final message = recent.length == 1
            ? l10n.questCompletionSingleNotice(
                gameNames(context).entityText(recent.first.title),
              )
            : l10n.questCompletionMultiNotice(recent.length);
        _showNotice(message);
      }
      if (awaiting.isNotEmpty) {
        final message = awaiting.length == 1
            ? l10n.questPendingConfirmationSingleNotice(
                gameNames(context).entityText(awaiting.first.title),
              )
            : l10n.questPendingConfirmationMultiNotice(awaiting.length);
        _showNotice(message);
      }
    });
    // A newly completed task can replace a claimed task without changing count.
    // In that case no setState above requested the frame needed by this notice.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _showNotice(String message) => QuestCompletionDrawerHost.show(
    context,
    message,
    tone: TopNoticeTone.quest,
    duration: Duration(
      seconds: widget.layoutSettingsController.topNoticeDurationSeconds,
    ),
    appendWithin: const Duration(milliseconds: 500),
  );

  String _period(GameQuest quest, DateTime now) =>
      widget.controller.questProgress?.periodFor(quest, now) ??
      questPeriodKey(0, quest.type, now);

  bool _isCurrentPeriod(GameQuest quest, DateTime now) =>
      !quest.isExpired(now) &&
      (quest.updatedAt == null ||
          _period(quest, quest.updatedAt!) == _period(quest, now));

  bool _isFullUnverified(GameQuest quest, DateTime now) =>
      quest.isAccepted &&
      !quest.isCompleted &&
      !quest.isExpired(now) &&
      (quest.progressRequired ?? 0) > 0 &&
      (quest.progressCurrent ?? 0) >= quest.progressRequired!;

  void _seedVerification(GameState state, DateTime now) {
    _fullUnverified.clear();
    _announcedVerification.clear();
    for (final quest in state.quests.values) {
      if (!_isFullUnverified(quest, now)) continue;
      final period = _period(quest, now);
      _fullUnverified[quest.id] = period;
      _announcedVerification[quest.id] = period;
    }
  }

  List<GameQuest> _newlyFullUnverified(GameState state, DateTime now) {
    final current = <int, String>{};
    final newlyFull = <GameQuest>[];
    for (final quest in state.quests.values) {
      final period = _period(quest, now);
      if (_announcedVerification[quest.id] != period) {
        _announcedVerification.remove(quest.id);
      }
      if (!_isFullUnverified(quest, now)) continue;
      current[quest.id] = period;
      if (_fullUnverified.containsKey(quest.id) && quest.updatedAt == null) {
        _announcedVerification[quest.id] = period;
      }
      if (_fullUnverified[quest.id] != period &&
          _announcedVerification[quest.id] != period) {
        newlyFull.add(quest);
        _announcedVerification[quest.id] = period;
      }
    }
    _fullUnverified
      ..clear()
      ..addAll(current);
    return newlyFull;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _tracker.completedCount);
}
