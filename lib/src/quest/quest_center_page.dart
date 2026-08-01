import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../game_state/game_state.dart';
import '../game_state/game_state_controller.dart';

class QuestCenterPage extends StatefulWidget {
  const QuestCenterPage({super.key, required this.controller});

  final GameStateController controller;

  @override
  State<QuestCenterPage> createState() => _QuestCenterPageState();
}

class _QuestCenterPageState extends State<QuestCenterPage> {
  int? _selectedQuestId;
  GameState? _lastQuestState;
  List<GameQuest>? _cachedSortedQuests;

  List<GameQuest> get _sortedQuests {
    final state = widget.controller.state;
    if (_lastQuestState != state) {
      _lastQuestState = state;
      _cachedSortedQuests = state.quests.values.toList()
        ..sort((a, b) {
          final completed = (b.isCompleted ? 1 : 0).compareTo(
            a.isCompleted ? 1 : 0,
          );
          return completed != 0 ? completed : a.id.compareTo(b.id);
        });
    }
    return _cachedSortedQuests!;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xff081521),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final state = widget.controller.state;
          final quests = _sortedQuests;
          final selected = _selectedQuest(quests);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuestHeader(quests: quests, updatedAt: state.updatedAt),
              Expanded(
                child: quests.isEmpty
                    ? const _WaitingState()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final list = _QuestList(
                            quests: quests,
                            selectedQuestId: selected?.id,
                            onSelected: (id) {
                              setState(() => _selectedQuestId = id);
                            },
                          );
                          final detail = _QuestDetail(quest: selected!);
                          if (constraints.maxWidth < 760) {
                            return Column(
                              children: [
                                Expanded(flex: 5, child: list),
                                const Divider(height: 1),
                                Expanded(flex: 6, child: detail),
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 38, child: list),
                              const VerticalDivider(width: 1),
                              Expanded(flex: 62, child: detail),
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
  }

  GameQuest? _selectedQuest(List<GameQuest> quests) {
    if (quests.isEmpty) {
      return null;
    }
    for (final quest in quests) {
      if (quest.id == _selectedQuestId) {
        return quest;
      }
    }
    return quests.first;
  }
}

class _QuestHeader extends StatelessWidget {
  const _QuestHeader({required this.quests, required this.updatedAt});

  final List<GameQuest> quests;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final localTime = updatedAt?.toLocal();
    final localizations = AppLocalizations.of(context);
    final updateLabel = localTime == null
        ? (localizations?.waitingForData ?? '等待数据')
        : '${localizations?.updatedAt ?? "更新"} ${_two(localTime.hour)}:${_two(localTime.minute)}:${_two(localTime.second)}';
    final completed = quests.where((quest) => quest.isCompleted).length;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xff0d1a26),
        border: Border(bottom: BorderSide(color: Color(0xff294052))),
      ),
      child: Row(
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
          _HeaderCount(
            label:
                '${AppLocalizations.of(context)?.accepted ?? "已接受"} ${quests.length}',
          ),
          const SizedBox(width: 8),
          _HeaderCount(
            label:
                '${AppLocalizations.of(context)?.completed ?? "已完成"} $completed',
            highlighted: completed > 0,
          ),
          const SizedBox(width: 14),
          Text(
            updateLabel,
            style: const TextStyle(color: Color(0xff8197a5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

class _HeaderCount extends StatelessWidget {
  const _HeaderCount({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xff183d32) : const Color(0xff142735),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted
              ? const Color(0xff2f8065)
              : const Color(0xff294052),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted
              ? const Color(0xff6fd5ad)
              : const Color(0xffa7bac5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuestList extends StatelessWidget {
  const _QuestList({
    required this.quests,
    required this.selectedQuestId,
    required this.onSelected,
  });

  final List<GameQuest> quests;
  final int? selectedQuestId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: quests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final quest = quests[index];
        return _QuestCard(
          quest: quest,
          selected: quest.id == selectedQuestId,
          onTap: () => onSelected(quest.id),
        );
      },
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.selected,
    required this.onTap,
  });

  final GameQuest quest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = quest.isCompleted
        ? const Color(0xff66cda4)
        : quest.progressFlag == 2
        ? const Color(0xffd4a85f)
        : const Color(0xff70c5c1);
    return Material(
      key: Key('quest-card-${quest.id}'),
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
          height: 76,
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
                    Text(
                      '${quest.id} · ${quest.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        _SmallTag(
                          label: quest.categoryLabel,
                          color: quest.categoryColor,
                        ),
                        const SizedBox(width: 5),
                        _SmallTag(
                          label: quest.getPeriodLabel(context),
                          color: quest.periodColor,
                        ),
                        const Spacer(),
                        _SmallTag(
                          label: quest.progressPercentLabel,
                          color: _progressColorForQuest(quest),
                        ),
                        const SizedBox(width: 6),
                        _QuestStatusBadge(
                          key: Key('quest-card-status-${quest.id}'),
                          quest: quest,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestDetail extends StatelessWidget {
  const _QuestDetail({required this.quest});

  final GameQuest quest;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${quest.id} · ${quest.title}',
            key: Key('quest-detail-title-${quest.id}'),
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _SmallTag(label: quest.categoryLabel, color: quest.categoryColor),
              _SmallTag(
                label: quest.getPeriodLabel(context),
                color: quest.periodColor,
              ),
              _SmallTag(
                label: quest.progressPercentLabel,
                color: _progressColorForQuest(quest),
              ),
              _QuestStatusBadge(
                key: Key('quest-detail-status-${quest.id}'),
                quest: quest,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: AppLocalizations.of(context)?.questDesc ?? '任务说明',
            child: Text(
              quest.detail.isEmpty ? '游戏接口未提供' : quest.detail,
              style: const TextStyle(
                color: Color(0xffc4d0d7),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _DetailCard(
            title: AppLocalizations.of(context)?.baseReward ?? '基础奖励',
            child: Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                for (var index = 0; index < 4; index++)
                  _MaterialReward(
                    assetIndex: index + 1,
                    value: quest.materials[index],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestStatusBadge extends StatelessWidget {
  const _QuestStatusBadge({super.key, required this.quest});

  final GameQuest quest;

  @override
  Widget build(BuildContext context) {
    final completed = quest.isCompleted;
    final color = completed ? const Color(0xff67d2a6) : const Color(0xffe0ad4f);
    final background = completed
        ? const Color(0xff173a31)
        : const Color(0xff3b3020);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Text(
        completed
            ? (AppLocalizations.of(context)?.completed ?? '已完成')
            : (AppLocalizations.of(context)?.inProgress ?? '进行中'),
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _MaterialReward extends StatelessWidget {
  const _MaterialReward({required this.assetIndex, required this.value});

  final int assetIndex;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Image.asset(
              'assets/images/material/${assetIndex.toString().padLeft(2, '0')}.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
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
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label, this.color = const Color(0xffa9bdc8)});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.transparent),
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
}

class _WaitingState extends StatelessWidget {
  const _WaitingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined, color: Color(0xffd4a85f), size: 42),
          SizedBox(height: 14),
          Text(
            '等待任务数据',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 7),
          Text(
            '打开游戏任务列表后，这里会自动同步当前已接受任务',
            style: TextStyle(color: Color(0xff8197a5)),
          ),
        ],
      ),
    );
  }
}

Color _progressColorForQuest(GameQuest quest) {
  if (quest.progressFlag == 1) return const Color(0xff67d2a6); // 50%
  if (quest.progressFlag == 2) return const Color(0xffe0ad4f); // 80%
  return const Color(0xffa9bdc8); // Default
}
