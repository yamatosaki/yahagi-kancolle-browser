import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../game_state/game_state.dart';
import '../logbook/logbook_database.dart';
import 'resource_trend_sampler.dart';

typedef ResourceTrendLoader =
    Future<List<Map<String, dynamic>>> Function(int selectedDays);

class _SeriesSpec {
  const _SeriesSpec({
    required this.key,
    required this.iconId,
    required this.color,
  });

  final String key;
  final String iconId;
  final Color color;
}

const List<_SeriesSpec> _mainSeries = <_SeriesSpec>[
  _SeriesSpec(key: 'fuel', iconId: '01', color: Color(0xff4caf50)),
  _SeriesSpec(key: 'ammo', iconId: '02', color: Color(0xffff9800)),
  _SeriesSpec(key: 'steel', iconId: '03', color: Color(0xff9e9e9e)),
  _SeriesSpec(key: 'bauxite', iconId: '04', color: Color(0xffffc107)),
];

const List<_SeriesSpec> _auxSeries = <_SeriesSpec>[
  _SeriesSpec(key: 'bucket', iconId: '06', color: Color(0xff8bc34a)),
  _SeriesSpec(key: 'devmat', iconId: '07', color: Color(0xff00bcd4)),
  _SeriesSpec(key: 'blowtorch', iconId: '05', color: Color(0xffff5722)),
  _SeriesSpec(key: 'screw', iconId: '08', color: Color(0xff9c27b0)),
];

final List<_SeriesSpec> _allSeries = <_SeriesSpec>[
  ..._mainSeries,
  ..._auxSeries,
];

String _seriesLabel(String key) {
  switch (key) {
    case 'fuel':
      return GameResourceType.fuel.label;
    case 'ammo':
      return GameResourceType.ammunition.label;
    case 'steel':
      return GameResourceType.steel.label;
    case 'bauxite':
      return GameResourceType.bauxite.label;
    case 'bucket':
      return GameResourceType.instantRepair.label;
    case 'blowtorch':
      return GameResourceType.instantBuild.label;
    case 'devmat':
      return GameResourceType.developmentMaterial.label;
    case 'screw':
      return GameResourceType.improvementMaterial.label;
    default:
      return key;
  }
}

class ResourceTrendPage extends StatefulWidget {
  const ResourceTrendPage({super.key, this.database, this.loadLogs});

  final LogbookDatabase? database;
  final ResourceTrendLoader? loadLogs;

  @override
  State<ResourceTrendPage> createState() => _ResourceTrendPageState();
}

class _ResourceTrendPageState extends State<ResourceTrendPage> {
  static const int _maxChartPoints = 500;
  static const int _maxDotsPoints = 80;
  static const int _maxCurvePoints = 200;

  int _selectedDays = 1; // 1, 7, 30, -1 (all)
  bool _isLoading = true;
  List<Map<String, dynamic>> _data = const <Map<String, dynamic>>[];
  Map<String, List<FlSpot>> _spots = const <String, List<FlSpot>>{};
  int _loadGeneration = 0;
  final Map<String, bool> _visibleSeries = <String, bool>{
    for (final spec in _allSeries) spec.key: true,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    setState(() => _isLoading = true);
    try {
      final raw =
          await (widget.loadLogs?.call(_selectedDays) ??
              _loadStoredLogs(_selectedDays));
      final data = downsampleResourceLogs(raw, maxPoints: _maxChartPoints);
      final spots = <String, List<FlSpot>>{};
      for (final spec in _allSeries) {
        spots[spec.key] = _buildSpots(data, spec.key);
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _data = data;
        _spots = spots;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('资源趋势数据加载失败: $error');
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _data = const <Map<String, dynamic>>[];
        _spots = const <String, List<FlSpot>>{};
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadStoredLogs(int selectedDays) async {
    final database = widget.database ?? LogbookDatabase.instance;
    final end = DateTime.now();
    final start = selectedDays < 0
        ? null
        : end.subtract(Duration(days: selectedDays));
    final count = await database.countResourceLogs(start: start, end: end);
    final sampler = ResourceTrendStreamSampler(
      expectedRows: count,
      maxPoints: _maxChartPoints,
    );
    await for (final row in database.streamResourceLogs(
      start: start,
      end: end,
    )) {
      sampler.add(row);
    }
    return sampler.finish();
  }

  List<FlSpot> _buildSpots(List<Map<String, dynamic>> data, String key) {
    final spots = <FlSpot>[
      for (var i = 0; i < data.length; i++)
        FlSpot(i.toDouble(), (data[i][key] as num?)?.toDouble() ?? 0),
    ];
    // A single record would collapse the X axis; duplicate it so a flat line
    // can still be drawn without a zero-width axis range.
    if (spots.length == 1) {
      spots.add(FlSpot(1, spots.first.y));
    }
    return spots;
  }

  double get _maxX => (_data.length <= 1 ? 1 : _data.length - 1).toDouble();

  void _onFilterChanged(int days) {
    if (_selectedDays == days) return;
    setState(() => _selectedDays = days);
    _loadData();
  }

  void _toggleSeries(String key) {
    setState(() {
      _visibleSeries[key] = !(_visibleSeries[key] ?? true);
    });
  }

  ({double minY, double maxY}) _bounds(
    List<_SeriesSpec> series,
    double fallbackMax,
  ) {
    var minVal = double.infinity;
    var maxVal = 0.0;
    var any = false;
    for (final spec in series) {
      if (_visibleSeries[spec.key] != true) continue;
      for (final spot in _spots[spec.key] ?? const <FlSpot>[]) {
        any = true;
        if (spot.y < minVal) minVal = spot.y;
        if (spot.y > maxVal) maxVal = spot.y;
      }
    }
    if (!any || minVal == double.infinity) {
      return (minY: 0, maxY: fallbackMax);
    }
    if (maxVal == 0) maxVal = fallbackMax;
    // Guarantee a positive-height axis range even when every visible value is
    // identical; fl_chart divides by (maxY - minY) while mapping points.
    if (maxVal <= minVal) maxVal = minVal + fallbackMax;

    final pad = (maxVal - minVal) * 0.1;
    var minY = minVal - pad;
    var maxY = maxVal + pad;
    if (minY < 0) minY = 0;
    if (maxY <= minY) maxY = minY + fallbackMax;
    return (minY: minY, maxY: maxY);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: const Color(0xff081521),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            color: const Color(0xff142735),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildFilterButton(l10n?.resourceTrend24h ?? '24小时', 1),
                _buildFilterButton(l10n?.resourceTrend7d ?? '7天', 7),
                _buildFilterButton(l10n?.resourceTrend30d ?? '30天', 30),
                _buildFilterButton(l10n?.resourceTrendAll ?? '全部记录', -1),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                ? Center(
                    child: Text(
                      l10n?.noResourceRecords ?? '暂无资源记录',
                      style: const TextStyle(color: Color(0xff8197a5)),
                    ),
                  )
                : Column(
                    children: <Widget>[
                      _buildStatsGrid(),
                      _buildLegend(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                          child: RepaintBoundary(
                            key: const Key('resource-trend-chart'),
                            child: Stack(
                              fit: StackFit.expand,
                              children: <Widget>[
                                _buildMainChart(),
                                _buildAuxChart(),
                                _axisGroupLabels(l10n),
                              ],
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

  Widget _buildFilterButton(String label, int days) {
    final isActive = _selectedDays == days;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: InkWell(
        onTap: () => _onFilterChanged(days),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xff403923) : Colors.transparent,
            border: Border.all(
              color: isActive ? const Color(0xffb98a28) : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive
                  ? const Color(0xffffc857)
                  : const Color(0xff9eb2bd),
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_data.isEmpty) return const SizedBox.shrink();
    final startRecord = _data.first;
    final endRecord = _data.last;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              mainAxisExtent: 40,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allSeries.length,
            itemBuilder: (context, index) =>
                _buildStatCard(_allSeries[index], startRecord, endRecord),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    _SeriesSpec spec,
    Map<String, dynamic> startRecord,
    Map<String, dynamic> endRecord,
  ) {
    final isVisible = _visibleSeries[spec.key] ?? true;
    final startVal = (startRecord[spec.key] as num?)?.toInt() ?? 0;
    final endVal = (endRecord[spec.key] as num?)?.toInt() ?? 0;
    final delta = endVal - startVal;
    final trendColor = delta > 0
        ? const Color(0xff4caf50)
        : (delta < 0 ? const Color(0xfff44336) : const Color(0xff5c7482));
    final trendSymbol = delta > 0 ? '▲+' : (delta < 0 ? '▼' : '');
    final trendText = delta == 0
        ? '-'
        : '$trendSymbol${NumberFormat.decimalPattern().format(delta)}';

    return InkWell(
      key: Key('resource-trend-card-${spec.key}'),
      onTap: () => _toggleSeries(spec.key),
      borderRadius: BorderRadius.circular(6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: isVisible
                ? const Color(0x66294052)
                : const Color(0x33141e28),
            // A uniform border is required for a rounded BoxDecoration;
            // the colored accent is drawn as a separate leading bar.
            border: Border.all(
              color: isVisible ? const Color(0x14ffffff) : Colors.transparent,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 3,
                color: isVisible ? spec.color : Colors.transparent,
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isVisible
                      ? spec.color.withAlpha(38)
                      : const Color(0x199e9e9e),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: isVisible ? 1.0 : 0.4,
                  child: Image.asset(
                    'assets/images/material/${spec.iconId}.png',
                    width: 20,
                    height: 20,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Row(
                    children: <Widget>[
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            NumberFormat.decimalPattern().format(endVal),
                            maxLines: 1,
                            style: TextStyle(
                              color: isVisible ? Colors.white : Colors.white54,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                      if (delta != 0) ...<Widget>[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.42,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              trendText,
                              maxLines: 1,
                              style: TextStyle(
                                color: isVisible ? trendColor : Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                        // Keep a comfortable margin from the card's right edge
                        // (about one icon width) so the delta is not cramped.
                        const SizedBox(width: 30),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 2,
              children: <Widget>[
                for (final spec in _mainSeries) _legendItem(spec),
              ],
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 2,
              alignment: WrapAlignment.end,
              children: <Widget>[
                for (final spec in _auxSeries) _legendItem(spec),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(_SeriesSpec spec) {
    final isVisible = _visibleSeries[spec.key] ?? true;
    final color = isVisible ? spec.color : const Color(0xff5c7482);
    return InkWell(
      key: Key('resource-trend-legend-${spec.key}'),
      onTap: () => _toggleSeries(spec.key),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _legendLine(spec, color),
          const SizedBox(width: 5),
          Text(
            _seriesLabel(spec.key),
            style: TextStyle(
              fontSize: 13,
              color: isVisible
                  ? const Color(0xff9eb2bd)
                  : const Color(0xff5c7482),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendLine(_SeriesSpec spec, Color color) {
    // Main resources use solid line markers, auxiliary resources use dashed
    // ones, matching the chart so users can tell the two groups apart.
    if (_mainSeries.contains(spec)) {
      return Container(width: 20, height: 4, color: color);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 5, height: 4, color: color),
        const SizedBox(width: 2),
        Container(width: 5, height: 4, color: color),
        const SizedBox(width: 2),
        Container(width: 5, height: 4, color: color),
      ],
    );
  }

  Widget _axisGroupLabels(AppLocalizations? l10n) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    return Positioned(
      top: 0,
      left: 44,
      right: 40,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n?.resourceTrendMainGroup ?? '四项资源',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n?.resourceTrendAuxGroup ?? '辅助资源',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      ),
    );
  }

  Widget _buildMainChart() {
    final bounds = _bounds(_mainSeries, 1000);
    final showDots = _data.length <= _maxDotsPoints;
    final curved = _data.length <= _maxCurvePoints;
    final lines = <LineChartBarData>[
      for (final spec in _mainSeries)
        if (_visibleSeries[spec.key] == true)
          _mainLine(spec, showDots: showDots, curved: curved),
    ];
    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        lineTouchData: _buildTouchData(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: Color(0xff294052), strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              const FlLine(color: Color(0xff294052), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: _leftTitles(),
          rightTitles: _reservedTitles(40),
          topTitles: _reservedTitles(26),
          bottomTitles: _bottomTitles(),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: _maxX,
        minY: bounds.minY,
        maxY: bounds.maxY,
        lineBarsData: lines,
      ),
      duration: Duration.zero,
    );
  }

  Widget _buildAuxChart() {
    final bounds = _bounds(_auxSeries, 100);
    final lines = <LineChartBarData>[
      for (final spec in _auxSeries)
        if (_visibleSeries[spec.key] == true) _auxLine(spec),
    ];
    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          // Keep the same reserved sizes as the main chart so both plot
          // rectangles overlap exactly; hidden titles still reserve space.
          leftTitles: _reservedTitles(44),
          rightTitles: _rightTitles(),
          topTitles: _reservedTitles(26),
          bottomTitles: _reservedTitles(28),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: _maxX,
        minY: bounds.minY,
        maxY: bounds.maxY,
        lineBarsData: lines,
      ),
      duration: Duration.zero,
    );
  }

  LineChartBarData _mainLine(
    _SeriesSpec spec, {
    required bool showDots,
    required bool curved,
  }) {
    return LineChartBarData(
      spots: _spots[spec.key] ?? const <FlSpot>[],
      isCurved: curved,
      curveSmoothness: 0.2,
      color: spec.color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: showDots,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 3,
          color: const Color(0xff081521),
          strokeWidth: 2,
          strokeColor: spec.color,
        ),
      ),
      // No area fills: overlapping translucent fills wash out the series
      // below them and add large fill paths for every data point.
      belowBarData: BarAreaData(show: false),
    );
  }

  LineChartBarData _auxLine(_SeriesSpec spec) {
    return LineChartBarData(
      spots: _spots[spec.key] ?? const <FlSpot>[],
      isCurved: false,
      color: spec.color,
      barWidth: 2,
      isStrokeCapRound: true,
      dashArray: const <int>[5, 5],
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  AxisTitles _leftTitles() {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 44,
        getTitlesWidget: (value, meta) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(
            _compactNumber(value),
            textAlign: TextAlign.right,
            style: const TextStyle(color: Color(0xff8197a5), fontSize: 11),
          ),
        ),
      ),
    );
  }

  AxisTitles _rightTitles() {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (value, meta) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            _compactNumber(value),
            textAlign: TextAlign.left,
            style: const TextStyle(color: Color(0xff8197a5), fontSize: 11),
          ),
        ),
      ),
    );
  }

  AxisTitles _reservedTitles(double size) {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: size,
        getTitlesWidget: (value, meta) => const SizedBox.shrink(),
      ),
    );
  }

  AxisTitles _bottomTitles() {
    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: _xInterval(),
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (index < 0 || index >= _data.length) {
            return const SizedBox.shrink();
          }
          final timestamp = _data[index]['timestamp'] as int?;
          if (timestamp == null) return const SizedBox.shrink();
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final String text;
          if (_selectedDays == 1) {
            // Snap to the nearest whole hour so the 24-hour axis reads as
            // integer hours (e.g. 06:00, 09:00) instead of raw timestamps.
            final rounded = date.add(const Duration(minutes: 30));
            text = '${rounded.hour.toString().padLeft(2, '0')}:00';
          } else if (_selectedDays == 7 || _selectedDays == 30) {
            text = DateFormat('MM-dd').format(date);
          } else {
            text = DateFormat('yyyy-MM-dd').format(date);
          }
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              text,
              style: const TextStyle(color: Color(0xff8197a5), fontSize: 11),
            ),
          );
        },
      ),
    );
  }

  double _xInterval() {
    final n = _data.length;
    if (n <= 1) return 1;
    if (_selectedDays == 1) {
      final start = _data.first['timestamp'] as num;
      final end = _data.last['timestamp'] as num;
      final hours = (end - start) / 3600000;
      if (hours <= 0) return 1;
      final width = MediaQuery.of(context).size.width;
      final maxTicks = width < 600 ? 5 : 8;
      final ticks = (hours / 3).round().clamp(2, maxTicks);
      return (n - 1) / ticks;
    }
    final width = MediaQuery.of(context).size.width;
    final labelCount = width < 600 ? 3 : 5;
    final raw = (n - 1) / labelCount;
    return raw < 1 ? 1 : raw;
  }

  String _compactNumber(double value) {
    if (value >= 10000) return '${(value / 10000).toStringAsFixed(0)}w';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toInt().toString();
  }

  LineTouchData _buildTouchData() {
    return LineTouchData(
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (touchedSpot) =>
            const Color(0xff142735).withAlpha(230),
        getTooltipItems: (touchedSpots) => <LineTooltipItem>[
          for (final spot in touchedSpots)
            LineTooltipItem(
              '${_seriesLabelForColor(spot.bar.color)}  '
              '${NumberFormat.decimalPattern().format(spot.y)}',
              TextStyle(
                color: spot.bar.color ?? Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }

  String _seriesLabelForColor(Color? color) {
    for (final spec in _allSeries) {
      if (spec.color == color) return _seriesLabel(spec.key);
    }
    return '';
  }
}
