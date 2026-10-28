import 'dart:math' as math;

import '../theme/app_palette.dart';
import '../settings/settings_ui_helpers.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/app_segmented_style.dart';
import '../account/account_session.dart';
import 'base_senka_section.dart';
import 'senka_catalog.dart';
import 'senka_controller.dart';
import 'senka_state.dart';
import 'senka_ui.dart';

class SenkaInfoView extends StatefulWidget {
  const SenkaInfoView({
    super.key,
    required this.state,
    required this.controller,
    required this.now,
    required this.compact,
    this.onOpenSortieLog,
    this.accountSession,
  });
  final AccountSession? accountSession;
  final SenkaState state;
  final SenkaController controller;
  final DateTime now;
  final bool compact;
  final VoidCallback? onOpenSortieLog;
  @override
  State<SenkaInfoView> createState() => _SenkaInfoViewState();
}

class _SenkaInfoViewState extends State<SenkaInfoView> {
  bool showHidden = false;
  String timeFilter = 'month';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final english = Localizations.localeOf(context).languageCode == 'en';
      final gap = widget.compact ? 4.0 : 10.0;
      final minimumSortieHeight =
          (widget.compact ? 34 : 44) +
          (widget.compact ? 26 : 34) +
          44 +
          (widget.compact ? 26 : 34);
      final horizontal =
          constraints.maxWidth > constraints.maxHeight * 1.15 &&
          constraints.maxHeight >= minimumSortieHeight;
      final server = _ServerOverview(
        state: widget.state,
        compact: widget.compact,
      );
      final ranking = _RankingPanel(
        state: widget.state,
        compact: widget.compact,
      );
      final sortieStats = timeFilter == 'today'
          ? widget.state.sortieStatsForDay(widget.now)
          : widget.state.sortieStats;
      final sorties = _SortiePanel(
        state: widget.state,
        sortieStats: sortieStats,
        controller: widget.controller,
        compact: widget.compact,
        showHidden: showHidden,
        onShowHidden: (value) => setState(() => showHidden = value),
        timeFilter: timeFilter,
        onTimeFilterChanged: (value) => setState(() => timeFilter = value),
        scrollRows: horizontal,
        onOpenSortieLog: widget.onOpenSortieLog,
      );
      final baseSenka = BaseSenkaSection(
        controller: widget.controller,
        accountSession: widget.accountSession,
      );
      if (horizontal) {
        final minimumOverviewHeight = _horizontalInfoMinimumHeight(
          context,
          constraints,
          widget.compact,
          widget.controller,
          gap,
        );
        final overview = Column(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                key: const Key('senka-info-server'),
                child: server,
              ),
            ),
            SizedBox(height: gap),
            Expanded(
              flex: 7,
              child: SizedBox(
                key: const Key('senka-info-ranking'),
                child: ranking,
              ),
            ),
            SizedBox(height: gap),
            baseSenka,
          ],
        );
        return Row(
          key: const Key('senka-info-horizontal'),
          children: [
            Expanded(
              key: const Key('senka-info-left'),
              child: constraints.maxHeight < minimumOverviewHeight
                  ? SingleChildScrollView(
                      key: const Key('senka-info-overview-scroll'),
                      child: SizedBox(
                        height: minimumOverviewHeight,
                        child: overview,
                      ),
                    )
                  : overview,
            ),
            SizedBox(width: gap),
            Expanded(key: const Key('senka-info-right'), child: sorties),
          ],
        );
      }
      return SingleChildScrollView(
        key: const Key('senka-info-vertical'),
        child: Column(
          children: [
            SizedBox(
              key: const Key('senka-info-server'),
              height: 150,
              child: server,
            ),
            SizedBox(height: gap),
            SizedBox(
              key: const Key('senka-info-ranking'),
              height: 330,
              child: ranking,
            ),
            SizedBox(height: gap),
            baseSenka,
            SizedBox(height: gap),
            SizedBox(
              key: const Key('senka-info-sorties'),
              height: english
                  ? null
                  : _sortiePanelHeight(
                      sortieStats,
                      widget.state.hiddenSortieMapKeys,
                      showHidden,
                      widget.compact,
                    ),
              child: sorties,
            ),
          ],
        ),
      );
    },
  );
}

// The server and ranking keep their existing 3:7 flex allocation. Include the
// relocated action tile in the scrollable column's minimum height; text
// measurement also accounts for narrow columns and the system text scale.
double _horizontalInfoMinimumHeight(
  BuildContext context,
  BoxConstraints constraints,
  bool compact,
  SenkaController controller,
  double gap,
) {
  final l10n = AppLocalizations.of(context)!;
  final scaler = MediaQuery.textScalerOf(context);
  final columnWidth = (constraints.maxWidth - gap) / 2;
  final defaultStyle = Theme.of(context).textTheme.bodyMedium!;
  Size measure(String text, TextStyle style, {double width = double.infinity}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: defaultStyle.merge(appTextStyle(context, style)),
      ),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout(maxWidth: math.max(1, width));
    final size = painter.size;
    painter.dispose();
    return size;
  }

  double line(double fontSize) => measure(
    '\u56fdAg',
    TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
  ).height;

  final serverRowHeight = math.max(
    line(compact ? 11 : 13),
    line(compact ? 22 : 30),
  );
  final serverMinimum =
      2 * serverRowHeight + (compact ? 8 : 12) + (compact ? 12 : 20);
  final rowHeight = line(compact ? 10 : 14);
  final currentHeight = line(compact ? 9 : 11) + 2;
  var rankingHeader = compact ? 28.0 : 36.0;
  if (Localizations.localeOf(context).languageCode == 'en') {
    final title = measure(
      l10n.senkaRanking,
      TextStyle(fontSize: compact ? 12 : 15, fontWeight: FontWeight.w800),
    );
    final updated = measure(
      l10n.senkaUpdated(
        senkaJstTimestamp(controller.state.latestRankingUpdatedAt),
      ),
      TextStyle(fontSize: compact ? 9 : 11, fontWeight: FontWeight.w600),
    );
    rankingHeader = math.max(
      rankingHeader,
      (title.width + updated.width + 12 <= columnWidth - (compact ? 14 : 22)
              ? math.max(title.height, updated.height)
              : title.height + updated.height + 4) +
          8,
    );
  }
  final rankingMinimum =
      rankingHeader + (compact ? 8 : 16) + currentHeight + 6 * rowHeight;

  final contentWidth = columnWidth - 32;
  final stacked = contentWidth / (scaler.scale(14) / 14) < 280;
  final labelWidth = stacked ? contentWidth : contentWidth - 12 - 96;
  final labelHeight =
      measure(
        l10n.baseSenkaManualInputLabel,
        SettingsTileTypography.title,
        width: labelWidth,
      ).height +
      3 +
      measure(
        l10n.baseSenkaCurrentValue(
          controller.monthBaseSenka.toStringAsFixed(2),
        ),
        SettingsTileTypography.description,
        width: labelWidth,
      ).height;
  final actionMinimum =
      24 + (stacked ? labelHeight + 8 + 48 : math.max(labelHeight, 48));
  final panelsMinimum = math.max(serverMinimum / .3, rankingMinimum / .7);
  return panelsMinimum + actionMinimum + 2 * gap;
}

double _sortiePanelHeight(
  Map<String, SenkaSortieStats> stats,
  Set<String> hiddenMapKeys,
  bool showHidden,
  bool compact,
) {
  final rowCount = stats.values
      .where((item) => showHidden || !hiddenMapKeys.contains(item.mapKey))
      .length;
  const panelHeaderHeight = 44.0;
  final subHeaderHeight = compact ? 26.0 : 34.0;
  const filterBarHeight = 44.0;
  final tableHeaderHeight = compact ? 26.0 : 34.0;
  const dataRowHeight = 44.0;
  return panelHeaderHeight +
      subHeaderHeight +
      filterBarHeight +
      tableHeaderHeight +
      rowCount * dataRowHeight +
      8;
}

class _ServerOverview extends StatelessWidget {
  const _ServerOverview({required this.state, required this.compact});
  final SenkaState state;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = state.playerRankingRow;
    return Material(
      color: appColor(context, senkaPanel),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: appColor(context, senkaLine)),
        borderRadius: BorderRadius.circular(compact ? 7 : 11),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 16,
          vertical: compact ? 6 : 10,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.senkaServer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: senkaMuted,
                        fontSize: compact ? 10 : 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      senkaServerName(
                        state.serverOrigin,
                        unknown: l10n.senkaUnknownServer,
                      ),
                      maxLines: 1,
                      style: appTextStyle(
                        context,
                        TextStyle(
                          color: senkaText,
                          fontSize: compact ? 16 : 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: compact ? 44 : 60,
              color: appColor(context, senkaLine),
              margin: EdgeInsets.symmetric(horizontal: compact ? 10 : 18),
            ),
            Expanded(
              flex: 50,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        l10n.senkaUnit,
                        style: appTextStyle(
                          context,
                          TextStyle(
                            color: senkaMuted,
                            fontSize: compact ? 11 : 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            senkaNumber(current.senka),
                            style: appTextStyle(
                              context,
                              TextStyle(
                                color: senkaYellow,
                                fontSize: compact ? 22 : 30,
                                fontWeight: FontWeight.w900,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  Row(
                    children: [
                      Text(
                        l10n.senkaRank,
                        style: appTextStyle(
                          context,
                          TextStyle(
                            color: senkaMuted,
                            fontSize: compact ? 11 : 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            senkaInteger(current.rank),
                            style: appTextStyle(
                              context,
                              TextStyle(
                                color: senkaYellow,
                                fontSize: compact ? 22 : 30,
                                fontWeight: FontWeight.w900,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingPanel extends StatelessWidget {
  const _RankingPanel({required this.state, required this.compact});
  final SenkaState state;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeStr = senkaJstTimestamp(state.latestRankingUpdatedAt);
    return SenkaPanel(
      title: l10n.senkaRanking,
      compact: compact,
      trailing: Text(
        l10n.senkaUpdated(timeStr),
        style: appTextStyle(
          context,
          TextStyle(
            color: senkaMuted,
            fontSize: compact ? 9 : 11,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 4 : 8),
        child: Column(
          children: [
            Expanded(
              child: _row(
                context,
                l10n.senkaOrder,
                l10n.senkaUnit,
                l10n.senkaChange,
                compact,
                header: true,
              ),
            ),
            for (final rank in const [5, 20, 100, 501])
              Expanded(
                key: Key('ranking-row-$rank'),
                child: _anchorRow(
                  context,
                  rank,
                  state.rankingRow(rank),
                  compact,
                ),
              ),
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Text(
                l10n.senkaCurrent,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: senkaMuted,
                    fontSize: compact ? 9 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _playerRow(context, state.playerRankingRow, compact),
            ),
          ],
        ),
      ),
    );
  }

  Widget _anchorRow(
    BuildContext context,
    int rank,
    SenkaRankingRow row,
    bool compact,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      color: appColor(context, senkaPanelAlt),
      borderRadius: BorderRadius.circular(4),
    ),
    child: _row(
      context,
      '$rank',
      senkaNumber(row.senka),
      _delta(row.senkaDelta),
      compact,
      deltaColor: _deltaColor(row.senkaDelta),
      deltaKey: Key('ranking-delta-$rank'),
    ),
  );

  Widget _playerRow(BuildContext context, SenkaRankingRow row, bool compact) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: appColor(context, Color(0xff0b1e2a)),
          border: Border.all(
            color: appColor(context, Color(0xff8a6628)),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 42,
              child: Row(
                key: const Key('player-rank-subcolumns'),
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        senkaInteger(row.rank),
                        key: const Key('player-rank'),
                        style: appTextStyle(
                          context,
                          _style(compact).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _rankDelta(row),
                      style: appTextStyle(
                        context,
                        _style(compact).copyWith(
                          color: _rankColor(row.rankDirection),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 30,
              child: Text(
                senkaNumber(row.senka),
                key: const Key('player-senka'),
                style: appTextStyle(
                  context,
                  _style(compact).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Expanded(
              flex: 28,
              child: Text(
                _delta(row.senkaDelta),
                key: const Key('player-senka-delta'),
                style: appTextStyle(
                  context,
                  _style(
                    compact,
                  ).copyWith(color: senkaGreen, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
}

Widget _row(
  BuildContext context,
  String rank,
  String senka,
  String delta,
  bool compact, {
  bool header = false,
  Color? deltaColor,
  Key? deltaKey,
}) => Row(
  children: [
    Expanded(
      flex: 42,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          rank,
          maxLines: 1,
          style: appTextStyle(context, _style(compact, header: header)),
        ),
      ),
    ),
    Expanded(
      flex: 30,
      child: Text(
        senka,
        maxLines: 1,
        style: appTextStyle(context, _style(compact, header: header)),
      ),
    ),
    Expanded(
      flex: 28,
      child: Text(
        delta,
        key: deltaKey,
        maxLines: 1,
        style: appTextStyle(
          context,
          _style(compact, header: header).copyWith(color: deltaColor),
        ),
      ),
    ),
  ],
);

TextStyle _style(bool compact, {bool header = false}) => TextStyle(
  color: senkaText,
  fontSize: compact ? 10 : 14,
  fontWeight: header ? FontWeight.w800 : FontWeight.w700,
  fontFeatures: const [FontFeature.tabularFigures()],
);
String _delta(double? value) => value == null
    ? '--'
    : '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';
Color _deltaColor(double? value) => value == null || value == 0
    ? senkaText
    : value > 0
    ? senkaGreen
    : senkaRed;
String _rankDelta(SenkaRankingRow row) => switch (row.rankDirection) {
  SenkaRankDirection.up || SenkaRankDirection.same => '↑${row.rankDelta ?? 0}',
  SenkaRankDirection.down => '↓${row.rankDelta ?? 0}',
  SenkaRankDirection.unknown => '--',
};
Color _rankColor(SenkaRankDirection direction) =>
    direction == SenkaRankDirection.down
    ? senkaRed
    : direction == SenkaRankDirection.unknown
    ? senkaText
    : senkaGreen;

class _SortiePanel extends StatelessWidget {
  const _SortiePanel({
    required this.state,
    required this.sortieStats,
    required this.controller,
    required this.compact,
    required this.showHidden,
    required this.onShowHidden,
    required this.timeFilter,
    required this.onTimeFilterChanged,
    required this.scrollRows,
    this.onOpenSortieLog,
  });
  final SenkaState state;
  final Map<String, SenkaSortieStats> sortieStats;
  final SenkaController controller;
  final bool compact;
  final bool showHidden;
  final ValueChanged<bool> onShowHidden;
  final String timeFilter;
  final ValueChanged<String> onTimeFilterChanged;
  final bool scrollRows;
  final VoidCallback? onOpenSortieLog;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final english = Localizations.localeOf(context).languageCode == 'en';
    final rows =
        sortieStats.values
            .where(
              (item) =>
                  showHidden ||
                  !state.hiddenSortieMapKeys.contains(item.mapKey),
            )
            .toList()
          ..sort((a, b) {
            final favorite =
                (state.favoriteSortieMapKeys.contains(b.mapKey) ? 1 : 0) -
                (state.favoriteSortieMapKeys.contains(a.mapKey) ? 1 : 0);
            return favorite != 0 ? favorite : a.mapKey.compareTo(b.mapKey);
          });

    final totalSorties = rows.fold<int>(0, (sum, s) => sum + s.sorties);
    final totalBoss = rows.fold<int>(0, (sum, s) => sum + s.bossArrivals);
    final totalS = rows.fold<int>(0, (sum, s) => sum + s.sWins);

    return SenkaPanel(
      title: l10n.senkaSortieStats,
      compact: compact,
      fitContent: english && !scrollRows,
      headerHeight: compact ? 34 : 44,
      trailing: Semantics(
        button: true,
        label: l10n.senkaLatestRecord,
        excludeSemantics: true,
        child: Material(
          color: appColor(context, Colors.transparent),
          child: InkWell(
            key: const Key('senka-recent-records'),
            onTap: onOpenSortieLog,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: appColor(context, const Color(0xff142b3a)),
                border: Border.all(
                  color: appColor(context, const Color(0xff2a4c62)),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                l10n.senkaLatestRecord,
                style: appTextStyle(
                  context,
                  TextStyle(
                    color: senkaText,
                    fontSize: compact ? 10 : 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: english
                ? null
                : compact
                ? 26
                : 34,
            constraints: english
                ? BoxConstraints(minHeight: compact ? 26 : 34)
                : null,
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: english ? 4 : 0,
            ),
            decoration: BoxDecoration(
              color: appColor(context, Color(0xff071822)),
              border: Border(
                bottom: BorderSide(color: appColor(context, senkaLine)),
              ),
            ),
            child: _responsiveHeader(context, [
              _summaryMetric(
                context,
                timeFilter == 'today'
                    ? l10n.senkaTodaySorties
                    : l10n.senkaMonthSorties,
                '$totalSorties',
                compact,
              ),
              _summaryMetric(
                context,
                l10n.senkaBossArrivals,
                '$totalBoss',
                compact,
              ),
              _summaryMetric(context, l10n.senkaSWins, '$totalS', compact),
            ], distribute: true),
          ),
          Container(
            height: english ? null : 44,
            constraints: english ? const BoxConstraints(minHeight: 44) : null,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _responsiveHeader(context, [
              Container(
                height: compact ? 24 : 28,
                decoration: BoxDecoration(
                  color: appColor(context, Color(0xff0b1e2a)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: appColor(context, senkaLine)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _timeFilterButton(
                      context,
                      l10n.senkaMonth,
                      'month',
                      timeFilter == 'month',
                      compact,
                    ),
                    _timeFilterButton(
                      context,
                      l10n.senkaToday,
                      'today',
                      timeFilter == 'today',
                      compact,
                    ),
                  ],
                ),
              ),
              if (!english) const Spacer(),
              Semantics(
                label: l10n.senkaShowHiddenAreas,
                button: true,
                toggled: showHidden,
                excludeSemantics: true,
                child: Container(
                  key: const Key('senka-show-hidden'),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: InkWell(
                    onTap: () => onShowHidden(!showHidden),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          showHidden
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: compact ? 14 : 18,
                          color: appColor(
                            context,
                            showHidden ? senkaGold : senkaMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.senkaShowHidden,
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: showHidden ? senkaText : senkaMuted,
                              fontSize: compact ? 10 : 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Container(
            height: compact ? 26 : 34,
            decoration: BoxDecoration(
              color: appColor(context, Color(0xff091a26)),
              border: Border(
                top: BorderSide(color: appColor(context, senkaLine)),
                bottom: BorderSide(color: appColor(context, senkaLine)),
              ),
            ),
            child: _sortieRow(
              context,
              [
                l10n.senkaArea,
                l10n.senkaBoss,
                l10n.senkaSorties,
                l10n.senkaResult,
                l10n.senkaActions,
              ],
              compact,
              header: true,
            ),
          ),
          if (scrollRows)
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) =>
                    _sortieData(context, rows[index], index, l10n),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++)
              _sortieData(context, rows[i], i, l10n),
        ],
      ),
    );
  }

  Widget _responsiveHeader(
    BuildContext context,
    List<Widget> children, {
    bool distribute = false,
  }) => Localizations.localeOf(context).languageCode == 'en'
      ? Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        )
      : Row(
          mainAxisAlignment: distribute
              ? MainAxisAlignment.spaceAround
              : MainAxisAlignment.start,
          children: children,
        );

  Widget _summaryMetric(
    BuildContext context,
    String label,
    String value,
    bool compact,
  ) {
    final children = <Widget>[
      Text(
        label,
        style: appTextStyle(
          context,
          TextStyle(
            color: senkaMuted,
            fontSize: compact ? 9 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      if (Localizations.localeOf(context).languageCode != 'en')
        const SizedBox(width: 6),
      Text(
        value,
        style: appTextStyle(
          context,
          TextStyle(
            color: senkaText,
            fontSize: compact ? 11 : 14,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ];
    return Localizations.localeOf(context).languageCode == 'en'
        ? Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          )
        : Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _timeFilterButton(
    BuildContext context,
    String label,
    String value,
    bool active,
    bool compact,
  ) => Material(
    color: AppSegmentedStyle.selection(context, active),
    borderRadius: BorderRadius.circular(5),
    child: InkWell(
      onTap: () => onTimeFilterChanged(value),
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 2 : 4,
        ),
        child: Text(
          label,
          style: appTextStyle(
            context,
            TextStyle(
              color: active
                  ? AppSegmentedStyle.foreground(context, true)
                  : senkaMuted,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _sortieData(
    BuildContext context,
    SenkaSortieStats stats,
    int index,
    AppLocalizations l10n,
  ) {
    final isFavorite = state.favoriteSortieMapKeys.contains(stats.mapKey);
    final isHidden = state.hiddenSortieMapKeys.contains(stats.mapKey);
    final isEven = index % 2 == 0;
    final rowBg = isFavorite
        ? const Color(0xff182c2b)
        : (isEven ? const Color(0xff0d2230) : const Color(0xff06141e));
    final rowHeight = compact ? 30.0 : 36.0;

    return SizedBox(
      key: Key('senka-sortie-row-${stats.mapKey}'),
      height: rowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: appColor(context, rowBg),
          border: Border(
            top: BorderSide(
              color: appColor(context, Color(0xff173245)),
              width: 0.5,
            ),
            bottom: BorderSide(
              color: appColor(context, Color(0xff173245)),
              width: 0.5,
            ),
            left: isFavorite
                ? BorderSide(color: appColor(context, senkaGold), width: 3.0)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            _cell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFavorite)
                    Text(
                      '★ ',
                      style: appTextStyle(
                        context,
                        _sortieStyle(compact).copyWith(color: senkaGold),
                      ),
                    ),
                  Text(
                    stats.mapKey,
                    maxLines: 1,
                    style: appTextStyle(
                      context,
                      _sortieStyle(
                        compact,
                      ).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              20,
            ),
            _cell(
              Text(
                '${stats.bossArrivals}',
                maxLines: 1,
                style: appTextStyle(
                  context,
                  _sortieStyle(compact).copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              14,
            ),
            _cell(
              Text(
                '${stats.sorties}',
                maxLines: 1,
                style: appTextStyle(
                  context,
                  _sortieStyle(compact).copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              14,
            ),
            _cell(
              Text(
                '${stats.sWins} / ${stats.aWins}',
                maxLines: 1,
                style: appTextStyle(
                  context,
                  _sortieStyle(compact).copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              20,
            ),
            Expanded(
              flex: 26,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Tooltip(
                    message: l10n.senkaFavoriteArea(stats.mapKey),
                    child: Semantics(
                      button: true,
                      toggled: isFavorite,
                      label: l10n.senkaFavoriteArea(stats.mapKey),
                      excludeSemantics: true,
                      child: SizedBox(
                        key: Key('senka-favorite-${stats.mapKey}'),
                        width: rowHeight,
                        height: rowHeight,
                        child: InkWell(
                          onTap: () =>
                              controller.toggleSortieFavorite(stats.mapKey),
                          child: Center(
                            child: Icon(
                              isFavorite ? Icons.star : Icons.star_border,
                              size: compact ? 17 : 20,
                              color: appColor(
                                context,
                                isFavorite ? senkaGold : senkaMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: l10n.senkaHideArea(stats.mapKey),
                    child: Semantics(
                      button: true,
                      toggled: isHidden,
                      label: l10n.senkaHideArea(stats.mapKey),
                      excludeSemantics: true,
                      child: SizedBox(
                        key: Key('senka-hide-${stats.mapKey}'),
                        width: rowHeight,
                        height: rowHeight,
                        child: InkWell(
                          onTap: () =>
                              controller.toggleSortieHidden(stats.mapKey),
                          child: Center(
                            child: Icon(
                              Icons.block,
                              size: compact ? 15 : 18,
                              color: appColor(
                                context,
                                isHidden ? senkaRed : senkaMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sortieRow(
  BuildContext context,
  List<String> values,
  bool compact, {
  bool header = false,
}) => Row(
  children: [
    _cell(
      Text(
        values[0],
        style: appTextStyle(context, _sortieStyle(compact, header: header)),
      ),
      20,
    ),
    _cell(
      Text(
        values[1],
        style: appTextStyle(context, _sortieStyle(compact, header: header)),
      ),
      14,
    ),
    _cell(
      Text(
        values[2],
        style: appTextStyle(context, _sortieStyle(compact, header: header)),
      ),
      14,
    ),
    _cell(
      Text(
        values[3],
        style: appTextStyle(context, _sortieStyle(compact, header: header)),
      ),
      20,
    ),
    _cell(
      Text(
        values[4],
        style: appTextStyle(context, _sortieStyle(compact, header: header)),
      ),
      26,
    ),
  ],
);
Widget _cell(Widget child, int flex) => Expanded(
  flex: flex,
  child: Center(child: child),
);
TextStyle _sortieStyle(bool compact, {bool header = false}) => TextStyle(
  color: header ? senkaMuted : senkaText,
  fontSize: compact ? 10 : 13,
  fontWeight: header ? FontWeight.w800 : FontWeight.w700,
  fontFeatures: const [FontFeature.tabularFigures()],
);
