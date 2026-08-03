import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../game_state/game_state.dart';
import 'operation_progress.dart';
import 'ship_portrait.dart';
import 'ship_status_style.dart';

const _cardColor = Color(0xff142735);
const _borderColor = Color(0xff294052);
const _mutedColor = Color(0xff8197a5);
const _progressColor = Color(0xff6fc9c1);

double _operationPortraitWidth(BuildContext context) {
  return shipCardPortraitWidth(context);
}

class ExpeditionStatusView extends StatelessWidget {
  const ExpeditionStatusView({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final portraitWidth = _operationPortraitWidth(context);
    final fleets = state.fleets
        .where((fleet) => fleet.mission.isActive)
        .toList(growable: false);
    if (fleets.isEmpty) {
      return _EmptyPage(
        label: AppLocalizations.of(context)?.noExpeditionFleet ?? '暂无远征中的舰队',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: fleets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final fleet = fleets[index];
        final flagship = state.shipsForFleet(fleet.id).firstOrNull;
        final flagshipMaster = flagship == null
            ? null
            : state.masterForShip(flagship);
        final masterMission = state.masterMissions[fleet.mission.missionId];
        final start = masterMission?.startedAt(fleet.mission.completionTime);
        return _OperationCard(
          key: Key('expedition-row-${fleet.id}'),
          portrait: ShipPortrait(
            key: Key('expedition-portrait-${fleet.id}'),
            ship: flagshipMaster,
            serverOrigin: state.serverOrigin,
            width: portraitWidth,
            height: shipCardPortraitHeight,
          ),
          identity: _OperationIdentity(
            eyebrow:
                '${fleet.name}　${AppLocalizations.of(context)?.expeditionInProgress ?? '远征中'}',
            title:
                masterMission?.name ??
                '${AppLocalizations.of(context)?.expedition ?? '远征'} ${fleet.mission.missionId}',
          ),
          body: start != null && fleet.mission.completionTime != null
              ? _TimedProgress(
                  progressKey: Key('expedition-progress-${fleet.id}'),
                  label: AppLocalizations.of(context)?.progress ?? '进行进度',
                  start: start,
                  end: fleet.mission.completionTime!,
                )
              : Text(
                  AppLocalizations.of(context)?.expeditionInProgress ?? '远征进行中',
                  style: const TextStyle(color: _mutedColor, fontSize: 12),
                ),
          trailing: OperationCountdownText(
            completionTime: fleet.mission.completionTime,
            completedText: (AppLocalizations.of(context)?.completed ?? '已完成'),
            textAlign: TextAlign.right,
            maxLines: 1,
          ),
        );
      },
    );
  }
}

class RepairDockStatusView extends StatelessWidget {
  const RepairDockStatusView({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final id = index + 1;
        final dock = state.repairDocks
            .where((candidate) => candidate.id == id)
            .firstOrNull;
        return _RepairDockCard(
          key: Key('repair-dock-row-$id'),
          state: state,
          dock: dock ?? RepairDock(id: id),
        );
      },
    );
  }
}

class _RepairDockCard extends StatelessWidget {
  const _RepairDockCard({super.key, required this.state, required this.dock});

  final GameState state;
  final RepairDock dock;

  @override
  Widget build(BuildContext context) {
    if (dock.isLocked) {
      return _UnavailableCard(
        label: AppLocalizations.of(context)?.unlocked ?? '未解锁',
      );
    }
    final ship = state.ships[dock.shipId];
    if (!dock.isRepairing || ship == null) {
      return _UnavailableCard(
        label: AppLocalizations.of(context)?.notRepairing ?? '未入渠',
      );
    }
    final master = state.masterForShip(ship);
    final portraitWidth = _operationPortraitWidth(context);
    final hpRatio = ship.maxHp <= 0 ? 0.0 : ship.currentHp / ship.maxHp;
    final hpColor = shipHpValueColor(hpRatio);
    final start =
        dock.completionTime == null || ship.repairDurationMilliseconds <= 0
        ? null
        : dock.completionTime!.subtract(
            Duration(milliseconds: ship.repairDurationMilliseconds),
          );
    return _OperationCard(
      portrait: ShipPortrait(
        key: Key('repair-portrait-${dock.id}'),
        ship: master,
        serverOrigin: state.serverOrigin,
        width: portraitWidth,
        height: shipCardPortraitHeight,
      ),
      identity: _OperationIdentity(
        eyebrow: 'Lv. ${ship.level}',
        title:
            master?.name ?? AppLocalizations.of(context)?.unknownShip ?? '未知舰娘',
      ),
      body: Row(
        children: [
          SizedBox(
            key: Key('repair-hp-${dock.id}'),
            width: 92,
            child: Text(
              'HP ${ship.currentHp}/${ship.maxHp}',
              maxLines: 1,
              style: TextStyle(
                color: hpColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (start != null && dock.completionTime != null)
                  _TimedProgress(
                    progressKey: Key('repair-progress-${dock.id}'),
                    label:
                        AppLocalizations.of(context)?.repairProgress ?? '修理进度',
                    start: start,
                    end: dock.completionTime!,
                  ),
                const SizedBox(height: 8),
                _ResourceLine(
                  prefix: AppLocalizations.of(context)?.cost ?? '消耗',
                  resources: <_ResourceValue>[
                    _ResourceValue(
                      keyName: 'fuel',
                      assetId: 1,
                      value: dock.fuelCost,
                    ),
                    _ResourceValue(
                      keyName: 'steel',
                      assetId: 3,
                      value: dock.steelCost,
                    ),
                  ],
                  keyPrefix: 'repair-resource-${dock.id}',
                ),
              ],
            ),
          ),
        ],
      ),
      trailing: OperationCountdownText(
        completionTime: dock.completionTime,
        completedText: (AppLocalizations.of(context)?.completed ?? '已完成'),
        textAlign: TextAlign.right,
        maxLines: 1,
      ),
    );
  }
}

class ConstructionDockStatusView extends StatelessWidget {
  const ConstructionDockStatusView({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final id = index + 1;
        final dock = state.constructionDocks
            .where((candidate) => candidate.id == id)
            .firstOrNull;
        return _ConstructionDockCard(
          key: Key('construction-dock-row-$id'),
          state: state,
          dock: dock ?? ConstructionDock(id: id),
        );
      },
    );
  }
}

class _ConstructionDockCard extends StatelessWidget {
  const _ConstructionDockCard({
    super.key,
    required this.state,
    required this.dock,
  });

  final GameState state;
  final ConstructionDock dock;

  @override
  Widget build(BuildContext context) {
    if (dock.isLocked) {
      return _UnavailableCard(
        label: AppLocalizations.of(context)?.unlocked ?? '未解锁',
      );
    }
    if (!dock.isBuilding) {
      return _UnavailableCard(
        label: AppLocalizations.of(context)?.notConstructing ?? '未建造',
      );
    }
    final master = state.masterShips[dock.createdShipMasterId];
    final portraitWidth = _operationPortraitWidth(context);
    final completed = dock.isCompletedAt(DateTime.now().toUtc());
    final calculatedStart =
        dock.completionTime != null && (master?.buildTimeMinutes ?? 0) > 0
        ? dock.completionTime!.subtract(
            Duration(minutes: master!.buildTimeMinutes),
          )
        : null;
    final progressStart = dock.startedAt ?? calculatedStart;
    return _OperationCard(
      portrait: ShipPortrait(
        key: Key('construction-portrait-${dock.id}'),
        ship: master,
        serverOrigin: state.serverOrigin,
        width: portraitWidth,
        height: shipCardPortraitHeight,
      ),
      identity: _OperationIdentity(
        eyebrow: dock.isLargeConstruction
            ? (AppLocalizations.of(context)?.lsc ?? '大型建造')
            : (AppLocalizations.of(context)?.normalConstruct ?? '常规建造'),
        eyebrowColor: dock.isLargeConstruction
            ? const Color(0xffffc940)
            : const Color(0xff64c894),
        title:
            master?.name ?? AppLocalizations.of(context)?.constructing ?? '建造中',
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (completed)
            _StaticProgress(
              progressKey: Key('construction-progress-${dock.id}'),
              label: AppLocalizations.of(context)?.constructProgress ?? '建造进度',
              value: 1,
              status: '100%',
            )
          else if (progressStart != null && dock.completionTime != null)
            _TimedProgress(
              progressKey: Key('construction-progress-${dock.id}'),
              label: AppLocalizations.of(context)?.constructProgress ?? '建造进度',
              start: progressStart,
              end: dock.completionTime!,
            )
          else
            _UnavailableProgress(
              progressKey: Key('construction-progress-${dock.id}'),
              label: AppLocalizations.of(context)?.constructProgress ?? '建造进度',
            ),
          const SizedBox(height: 8),
          _ResourceLine(
            prefix: '',
            resources: <_ResourceValue>[
              _ResourceValue(keyName: 'fuel', assetId: 1, value: dock.fuel),
              _ResourceValue(
                keyName: 'ammo',
                assetId: 2,
                value: dock.ammunition,
              ),
              _ResourceValue(keyName: 'steel', assetId: 3, value: dock.steel),
              _ResourceValue(
                keyName: 'bauxite',
                assetId: 4,
                value: dock.bauxite,
              ),
              _ResourceValue(
                keyName: 'development',
                assetId: 7,
                value: dock.developmentMaterial,
              ),
            ],
            keyPrefix: 'construction-resource-${dock.id}',
          ),
        ],
      ),
      trailing: completed
          ? _CompletedLabel(
              label: AppLocalizations.of(context)?.constructComplete ?? '建造完成',
            )
          : OperationCountdownText(
              completionTime: dock.completionTime,
              completedText: (AppLocalizations.of(context)?.completed ?? '已完成'),
              textAlign: TextAlign.right,
              maxLines: 1,
            ),
    );
  }
}

class _OperationCard extends StatelessWidget {
  const _OperationCard({
    super.key,
    required this.portrait,
    required this.identity,
    required this.body,
    required this.trailing,
  });

  final Widget portrait;
  final Widget identity;
  final Widget body;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final phone = constraints.maxWidth < 420;
        final gap = compact ? 10.0 : 18.0;
        return Container(
          constraints: const BoxConstraints(
            minHeight: shipCardCapsuleMinHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderColor),
          ),
          child: phone
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        portrait,
                        const SizedBox(width: 10),
                        SizedBox(width: 118, child: identity),
                        const Spacer(),
                        SizedBox(width: 74, child: trailing),
                      ],
                    ),
                    const SizedBox(height: 8),
                    body,
                  ],
                )
              : Row(
                  children: [
                    portrait,
                    SizedBox(width: compact ? 10 : 14),
                    SizedBox(width: compact ? 145 : 210, child: identity),
                    SizedBox(width: gap),
                    Expanded(child: body),
                    SizedBox(width: gap),
                    SizedBox(width: compact ? 82 : 100, child: trailing),
                  ],
                ),
        );
      },
    );
  }
}

class _OperationIdentity extends StatelessWidget {
  const _OperationIdentity({
    required this.eyebrow,
    required this.title,
    this.eyebrowColor = _mutedColor,
  });

  final String eyebrow;
  final String title;
  final Color eyebrowColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: eyebrowColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TimedProgress extends StatefulWidget {
  const _TimedProgress({
    required this.progressKey,
    required this.label,
    required this.start,
    required this.end,
  });

  final Key progressKey;
  final String label;
  final DateTime start;
  final DateTime end;

  @override
  State<_TimedProgress> createState() => _TimedProgressState();
}

class _UnavailableProgress extends StatelessWidget {
  const _UnavailableProgress({required this.progressKey, required this.label});

  final Key progressKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: progressKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xffdce6eb),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              AppLocalizations.of(context)?.questUnknown ?? '进度未知',
              style: const TextStyle(color: Color(0xffa9c6d2), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: 0,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
          color: _progressColor,
          backgroundColor: const Color(0xff263f4d),
        ),
      ],
    );
  }
}

class _StaticProgress extends StatelessWidget {
  const _StaticProgress({
    required this.progressKey,
    required this.label,
    required this.value,
    required this.status,
  });

  final Key progressKey;
  final String label;
  final double value;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: progressKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xffdce6eb),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              status,
              style: const TextStyle(
                color: Color(0xffa9c6d2),
                fontSize: 11,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
          color: _progressColor,
          backgroundColor: const Color(0xff263f4d),
        ),
      ],
    );
  }
}

class _TimedProgressState extends State<_TimedProgress> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final done =
          operationProgress(
            now: DateTime.now().toUtc(),
            start: widget.start,
            end: widget.end,
          ) >=
          1;
      if (done) {
        _timer?.cancel();
        _timer = null;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = operationProgress(
      now: DateTime.now().toUtc(),
      start: widget.start,
      end: widget.end,
    );
    final percentage = (progress * 100).round();
    return Column(
      key: widget.progressKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                color: Color(0xffdce6eb),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '$percentage%',
              style: const TextStyle(
                color: Color(0xffa9c6d2),
                fontSize: 11,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
          color: _progressColor,
          backgroundColor: const Color(0xff263f4d),
        ),
      ],
    );
  }
}

class _ResourceValue {
  const _ResourceValue({
    required this.keyName,
    required this.assetId,
    required this.value,
  });

  final String keyName;
  final int assetId;
  final int value;
}

class _ResourceLine extends StatelessWidget {
  const _ResourceLine({
    required this.prefix,
    required this.resources,
    required this.keyPrefix,
  });

  final String prefix;
  final List<_ResourceValue> resources;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (prefix.isNotEmpty)
          Text(
            prefix,
            style: const TextStyle(color: _mutedColor, fontSize: 12),
          ),
        for (final resource in resources)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/material/${resource.assetId.toString().padLeft(2, '0')}.png',
                key: Key('$keyPrefix-${resource.keyName}'),
                width: 18,
                height: 18,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(width: 4),
              Text(
                '${resource.value}',
                style: const TextStyle(
                  color: Color(0xffc6d4db),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: shipCardCapsuleMinHeight),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _mutedColor,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyPage extends StatelessWidget {
  const _EmptyPage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: const TextStyle(color: _mutedColor)),
    );
  }
}

class _CompletedLabel extends StatelessWidget {
  const _CompletedLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: Color(0xff64c894),
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
