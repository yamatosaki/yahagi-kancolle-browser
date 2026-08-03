import 'package:flutter/material.dart';

import '../battle/battle_controller.dart';
import '../battle/battle_records_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'logbook_database.dart';
import '../../l10n/app_localizations.dart';
import '../fleet/resource_trend_page.dart';

class LogbookPage extends StatefulWidget {
  const LogbookPage({super.key, required this.battleController});

  final BattleController battleController;

  @override
  State<LogbookPage> createState() => _LogbookPageState();
}

class _LogbookPageState extends State<LogbookPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xff081521),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LogbookHeader(tabController: _tabController),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Current Session
                _CurrentSessionTab(controller: widget.battleController),
                // 2. Battle History Stats
                _BattleStatsTab(controller: widget.battleController),
                // 3. Resource Trends
                const ResourceTrendPage(),
                // 4. Expedition Income
                const _ExpeditionStatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogbookHeader extends StatelessWidget {
  const _LogbookHeader({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xff0d1a26),
        border: Border(bottom: BorderSide(color: Color(0xff294052))),
      ),
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        labelColor: const Color(0xffd4a85f),
        unselectedLabelColor: const Color(0xff8197a5),
        indicatorColor: const Color(0xffd4a85f),
        indicatorSize: TabBarIndicatorSize.label,
        tabs: [
          Tab(text: AppLocalizations.of(context)?.thisSortie ?? '本次出击'),
          Tab(text: AppLocalizations.of(context)?.historicalRecords ?? '历史战果'),
          Tab(text: AppLocalizations.of(context)?.resourceTrend ?? '资源趋势'),
          Tab(text: AppLocalizations.of(context)?.expeditionIncome ?? '远征收益'),
        ],
      ),
    );
  }
}

class _CurrentSessionTab extends StatelessWidget {
  const _CurrentSessionTab({required this.controller});
  final BattleController controller;

  @override
  Widget build(BuildContext context) {
    // We pass hideTitle parameter so we can hide the redundant '战斗记录' text
    return BattleRecordsPage(controller: controller, hideTitle: true);
  }
}

class _BattleStatsTab extends StatelessWidget {
  const _BattleStatsTab({required this.controller});
  final BattleController controller;

  String _alphabeticNode(int node) {
    var value = node;
    final characters = <int>[];
    while (value > 0) {
      value--;
      characters.add(65 + value % 26);
      value ~/= 26;
    }
    return String.fromCharCodes(characters.reversed);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LogbookDatabase.instance.getBattleRecords(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!;
        if (records.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)?.noHistoricalRecords ?? '暂无历史战果',
              style: const TextStyle(color: Color(0xff8197a5)),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final dropShipId = record['drop_ship_id'] as int?;
            final dropShipName = dropShipId != null && dropShipId > 0
                ? (controller.gameState().masterShips[dropShipId]?.name ??
                      'ID: $dropShipId')
                : (AppLocalizations.of(context)?.none ?? '无');

            final mapArea = record['map_area'];
            final mapNo = record['map_no'];
            final node = record['node'] as int;
            final nodeLabel = node > 0
                ? '${_alphabeticNode(node)}${AppLocalizations.of(context)?.node ?? "点"}'
                : (AppLocalizations.of(context)?.unknownNode ?? '未知点');

            final friendState = record['friend_fleet_state'] ?? '?/?';
            final enemyState = record['enemy_fleet_state'] ?? '?/?';

            final rank = record['rank'] as String;

            return Card(
              color: const Color(0xff142735),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xff292314),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xffd4a85f).withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    rank,
                    style: const TextStyle(
                      color: Color(0xffd4a85f),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  '${record['enemy_fleet_name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    '$mapArea-$mapNo · $nodeLabel  ${AppLocalizations.of(context)?.friend ?? "我方"} $friendState  ${AppLocalizations.of(context)?.enemy ?? "敌方"} $enemyState  ${AppLocalizations.of(context)?.drop ?? "掉落"}: $dropShipName',
                    style: const TextStyle(
                      color: Color(0xff8197a5),
                      fontSize: 12,
                    ),
                  ),
                ),
                trailing: Text(
                  DateTime.fromMillisecondsSinceEpoch(
                    record['timestamp'] as int,
                  ).toString().split('.')[0].substring(11),
                  style: const TextStyle(
                    color: Color(0xff567080),
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}



class _ExpeditionStatsTab extends StatelessWidget {
  const _ExpeditionStatsTab();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LogbookDatabase.instance.getDailyExpeditionYields(limitDays: 7),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)?.noExpeditionRecords ?? '暂无远征记录',
              style: const TextStyle(color: Color(0xff8197a5)),
            ),
          );
        }

        final barGroups = <BarChartGroupData>[];
        double maxYield = 0;

        for (var i = 0; i < data.length; i++) {
          final row = data[i];
          final f = (row['fuel'] as num).toDouble();
          final a = (row['ammo'] as num).toDouble();
          final s = (row['steel'] as num).toDouble();
          final b = (row['bauxite'] as num).toDouble();

          final total = f + a + s + b;
          if (total > maxYield) maxYield = total;

          barGroups.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: total,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                  rodStackItems: [
                    BarChartRodStackItem(0, f, const Color(0xff4B9FD5)),
                    BarChartRodStackItem(f, f + a, const Color(0xffE58C4F)),
                    BarChartRodStackItem(
                      f + a,
                      f + a + s,
                      const Color(0xff8197a5),
                    ),
                    BarChartRodStackItem(
                      f + a + s,
                      total,
                      const Color(0xffE0C345),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocalizations.of(context)?.expeditionIncomeChart ??
                    '远征收益统计 (最近 7 天)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffd4a85f),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Indicator(
                    color: const Color(0xff4B9FD5),
                    text: AppLocalizations.of(context)?.fuel ?? '燃料',
                  ),
                  const SizedBox(width: 12),
                  _Indicator(
                    color: const Color(0xffE58C4F),
                    text: AppLocalizations.of(context)?.ammo ?? '弹药',
                  ),
                  const SizedBox(width: 12),
                  _Indicator(
                    color: const Color(0xff8197a5),
                    text: AppLocalizations.of(context)?.steel ?? '钢材',
                  ),
                  const SizedBox(width: 12),
                  _Indicator(
                    color: const Color(0xffE0C345),
                    text: AppLocalizations.of(context)?.bauxite ?? '铝土',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxYield > 0 ? maxYield * 1.1 : 100,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < data.length) {
                              final dayStr = data[idx]['day'] as String;
                              // e.g., '2023-10-25' -> '10-25'
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  dayStr.substring(5),
                                  style: const TextStyle(
                                    color: Color(0xff8197a5),
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (val, _) => Text(
                            val.toInt().toString(),
                            style: const TextStyle(
                              color: Color(0xff8197a5),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: const Color(0xff294052),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: barGroups,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;

  const _Indicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Color(0xff8197a5), fontSize: 12),
        ),
      ],
    );
  }
}
