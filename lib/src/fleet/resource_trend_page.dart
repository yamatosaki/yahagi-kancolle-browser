import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../logbook/logbook_database.dart';
import '../widgets/filter_controls.dart';
import '../widgets/top_notice.dart';
import 'resource_trend_chart.dart';
import 'resource_trend_data.dart';

typedef ResourceTrendLoader =
    Future<List<Map<String, dynamic>>> Function(int selectedDays);
const resourceTrendVisibleResourcesKey = 'resource_trend_visible_resources_v1';

class _Resource {
  const _Resource(this.key, this.icon, this.color);
  final String key, icon;
  final Color color;
  String label(AppLocalizations l) => switch (key) {
    'fuel' => l.fuel,
    'ammo' => l.ammo,
    'steel' => l.steel,
    'bauxite' => l.bauxite,
    'bucket' => l.resourceTrendRepairMaterial,
    'devmat' => l.resourceTrendDevMaterial,
    'blowtorch' => l.resourceTrendBuildMaterial,
    _ => l.resourceTrendImproveMaterial,
  };
}

const _resources = [
  _Resource('fuel', '01', Color(0xff6bcd91)),
  _Resource('ammo', '02', Color(0xffe7a666)),
  _Resource('steel', '03', Color(0xffb1c7d3)),
  _Resource('bauxite', '04', Color(0xffe2c05a)),
  _Resource('blowtorch', '05', Color(0xffeab079)),
  _Resource('bucket', '06', Color(0xff88ce9f)),
  _Resource('devmat', '07', Color(0xff69c7db)),
  _Resource('screw', '08', Color(0xffbf9bdf)),
];

class ResourceTrendPage extends StatefulWidget {
  const ResourceTrendPage({super.key, this.database, this.loadLogs, this.now});
  final LogbookDatabase? database;
  final ResourceTrendLoader? loadLogs;
  final DateTime Function()? now;
  @override
  State<ResourceTrendPage> createState() => _ResourceTrendPageState();
}

class _ResourceTrendPageState extends State<ResourceTrendPage>
    with WidgetsBindingObserver {
  int _days = 1, _generation = 0;
  String _selected = 'fuel';
  Set<String> _visible = _resources.map((r) => r.key).toSet();
  ResourceTrendData? _data;
  bool _loading = true, _error = false, _preferencesEdited = false;
  Timer? _midnight, _refreshDebounce;
  final _chartRevision = ValueNotifier(0);
  late LogbookDatabase _database;
  final Set<Route<dynamic>> _accountDialogs = {};
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  AppLocalizations get _l =>
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? LogbookDatabase.instance;
    LogbookDatabase.accountSession.addListener(_accountChanged);
    WidgetsBinding.instance.addObserver(this);
    _database
        .changesFor(LogbookChangeCategory.resource)
        .addListener(_recordsChanged);
    _restorePreferences();
    _load();
    _scheduleMidnight();
  }

  @override
  void didUpdateWidget(covariant ResourceTrendPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database) {
      _database
          .changesFor(LogbookChangeCategory.resource)
          .removeListener(_recordsChanged);
      _database = widget.database ?? LogbookDatabase.instance;
      _database
          .changesFor(LogbookChangeCategory.resource)
          .addListener(_recordsChanged);
    }
    if (oldWidget.database != widget.database ||
        oldWidget.loadLogs != widget.loadLogs ||
        oldWidget.now != widget.now) {
      _load(clear: true);
      _scheduleMidnight();
    }
  }

  void _accountChanged() {
    _closeAccountDialogs();
    _generation++;
    _refreshDebounce?.cancel();
    if (!mounted) return;
    setState(() {
      _data = null;
      _loading = false;
      _error = false;
    });
    if (widget.database == null) {
      _database
          .changesFor(LogbookChangeCategory.resource)
          .removeListener(_recordsChanged);
      _database = LogbookDatabase.instance;
      _database
          .changesFor(LogbookChangeCategory.resource)
          .addListener(_recordsChanged);
      _load(clear: true);
    }
  }

  Future<T?> _showAccountDialog<T>({
    required WidgetBuilder builder,
    bool useSafeArea = true,
  }) {
    final route = DialogRoute<T>(
      context: context,
      builder: builder,
      useSafeArea: useSafeArea,
    );
    _accountDialogs.add(route);
    return Navigator.of(context, rootNavigator: true).push(route).whenComplete(
      () {
        _accountDialogs.remove(route);
      },
    );
  }

  void _closeAccountDialogs() {
    final routes = _accountDialogs.toList();
    _accountDialogs.clear();
    void close() {
      for (final route in routes) {
        if (route.isActive) route.navigator?.removeRoute(route);
      }
    }

    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => close());
    } else {
      close();
    }
  }

  void _recordsChanged() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 200), _load);
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = _now;
    final today = ResourceTrendWindow.at(now, 1).start;
    _midnight = Timer(
      today.add(const Duration(days: 1)).difference(now.toUtc()) +
          const Duration(milliseconds: 50),
      () {
        _load(clear: true);
        _scheduleMidnight();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(clear: true);
      _scheduleMidnight();
    }
  }

  Future<void> _restorePreferences() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getStringList(
        resourceTrendVisibleResourcesKey,
      );
      if (!mounted || saved == null || _preferencesEdited) return;
      final valid = _resources.map((r) => r.key).where(saved.contains).toSet();
      if (valid.isEmpty) return;
      setState(() {
        _visible = valid;
        if (!valid.contains(_selected)) _selected = valid.first;
      });
    } catch (error) {
      debugPrint('Resource display preferences could not be read: $error');
    }
  }

  Future<void> _load({bool clear = false}) async {
    final generation = ++_generation;
    final window = ResourceTrendWindow.at(_now, _days);
    setState(() {
      _loading = true;
      _error = false;
      if (clear) _data = null;
    });
    // Dialogs have their own subtree: the page's setState alone cannot publish
    // loading/cleared state to an already open fullscreen chart.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _generation) _chartRevision.value++;
      });
    } else {
      _chartRevision.value++;
    }
    try {
      final data = widget.loadLogs == null
          ? await loadResourceTrend(_database, window)
          : ResourceTrendData.fromRows(window, await widget.loadLogs!(_days));
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      _chartRevision.value++;
    } catch (error) {
      debugPrint('Resource history could not be loaded: $error');
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = true;
        _loading = false;
        _data = null;
      });
      _chartRevision.value++;
    }
  }

  @override
  void dispose() {
    _generation++;
    LogbookDatabase.accountSession.removeListener(_accountChanged);
    _closeAccountDialogs();
    _midnight?.cancel();
    _refreshDebounce?.cancel();
    _database
        .changesFor(LogbookChangeCategory.resource)
        .removeListener(_recordsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _chartRevision.dispose();
    super.dispose();
  }

  Future<void> _customize() async {
    final draft = {..._visible};
    final result = await _showAccountDialog<Set<String>>(
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          backgroundColor: const Color(0xff102532),
          title: Text(_l.resourceTrendCustomize),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final resource in _resources)
                    CheckboxListTile(
                      key: ValueKey('resource-filter-${resource.key}'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: const Color(0xffbd9349),
                      value: draft.contains(resource.key),
                      secondary: Image.asset(
                        'assets/images/material/${resource.icon}.png',
                        width: 22,
                        height: 22,
                      ),
                      title: Text(
                        resource.label(_l),
                        style: const TextStyle(fontSize: 14),
                      ),
                      onChanged: (value) => update(() {
                        if (value == true) {
                          draft.add(resource.key);
                        } else {
                          draft.remove(resource.key);
                        }
                      }),
                    ),
                  if (draft.isEmpty)
                    Text(
                      _l.resourceTrendAtLeastOne,
                      style: const TextStyle(
                        color: Color(0xffffaa91),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_l.cancel),
            ),
            TextButton(
              onPressed: draft.isEmpty
                  ? null
                  : () => Navigator.pop(context, draft),
              child: Text(_l.confirm),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    _preferencesEdited = true;
    setState(() {
      _visible = result;
      if (!result.contains(_selected)) {
        _selected = _resources.firstWhere((r) => result.contains(r.key)).key;
      }
    });
    try {
      final saved = await (await SharedPreferences.getInstance()).setStringList(
        resourceTrendVisibleResourcesKey,
        _resources
            .where((r) => result.contains(r.key))
            .map((r) => r.key)
            .toList(),
      );
      if (!saved) {
        throw StateError('Saving resource display preferences returned false');
      }
    } catch (error) {
      if (mounted) {
        TopNotice.show(
          context,
          message: _l.resourceTrendSaveError,
          tone: TopNoticeTone.error,
        );
      }
    }
  }

  Widget _chart(double height, {bool expanded = false, VoidCallback? onClose}) {
    final resource = _resources.firstWhere((r) => r.key == _selected);
    return ResourceTrendChart(
      key: ValueKey(
        expanded ? 'resource-trend-fullscreen' : 'resource-trend-chart',
      ),
      data: _data!,
      resourceKey: resource.key,
      label: resource.label(_l),
      color: resource.color,
      iconId: resource.icon,
      plotHeight: height,
      expanded: expanded,
      onExpand: onClose ?? _expand,
    );
  }

  void _expand() {
    _showAccountDialog<void>(
      useSafeArea: false,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: const Color(0xff091b28),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => ValueListenableBuilder(
              valueListenable: _chartRevision,
              builder: (context, revision, child) => SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: _data == null
                    ? Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: _l.close,
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          _status(),
                        ],
                      )
                    : _chart(
                        math.max(
                          140,
                          constraints.maxHeight -
                              (constraints.maxHeight < 500 ? 118 : 290),
                        ),
                        expanded: true,
                        onClose: () => Navigator.pop(dialogContext),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status() => SizedBox(
    height: 310,
    child: Center(
      child: _loading
          ? const CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xffbfa16b),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _l.resourceTrendLoadError,
                  style: const TextStyle(color: Color(0xffa7bbc6)),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  key: const ValueKey('resource-trend-retry'),
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(_l.developmentRetry),
                ),
              ],
            ),
    ),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff091b28),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final landscape =
            size.width > size.height && constraints.maxWidth >= 600;
        final columns = landscape
            ? 4
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final compact = landscape && constraints.maxWidth < 960;
        final gap = 8.0;
        final width =
            (constraints.maxWidth - 24 - gap * (columns - 1)) / columns;
        final plotHeight = landscape && size.height < 500
            ? 270.0
            : !landscape && constraints.maxWidth >= 600
            ? 410.0
            : constraints.maxWidth >= 1100
            ? 340.0
            : 310.0;
        return SingleChildScrollView(
          key: const PageStorageKey('resource-trend-scroll'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: const Color(0xff142735),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final days in [1, 7, 30, 90])
                              Padding(
                                padding: const EdgeInsets.only(right: 3),
                                child: Semantics(
                                  selected: days == _days,
                                  child: TextButton(
                                    key: ValueKey('resource-range-$days'),
                                    onPressed: () {
                                      if (_days == days) return;
                                      setState(() => _days = days);
                                      _load(clear: true);
                                    },
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 32),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 13,
                                      ),
                                      foregroundColor: days == _days
                                          ? const Color(0xffffc857)
                                          : const Color(0xff9eb2bd),
                                      backgroundColor: days == _days
                                          ? const Color(0xff403923)
                                          : Colors.transparent,
                                      side: BorderSide(
                                        color: days == _days
                                            ? const Color(0xffb98a28)
                                            : Colors.transparent,
                                      ),
                                      shape: const StadiumBorder(),
                                      textStyle: TextStyle(
                                        fontFamily: Theme.of(
                                          context,
                                        ).textTheme.labelLarge?.fontFamily,
                                        fontSize: 12,
                                        fontWeight: days == _days
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    child: Text(switch (days) {
                                      1 => _l.senkaToday,
                                      7 => _l.resourceTrend7d,
                                      30 => _l.resourceTrend30d,
                                      _ => _l.resourceTrend90d,
                                    }),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    HeaderFilterIconButton(
                      key: const ValueKey('resource-trend-filter'),
                      icon: Icons.filter_alt_outlined,
                      active: _visible.length != _resources.length,
                      tooltip: _l.resourceTrendCustomize,
                      onPressed: _customize,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final resource in _resources.where(
                          (r) => _visible.contains(r.key),
                        ))
                          SizedBox(
                            width: width,
                            child: _ResourceCapsule(
                              key: ValueKey('resource-card-${resource.key}'),
                              resource: resource,
                              label: resource.label(_l),
                              current: _data?.current(resource.key),
                              delta: _data?.delta(resource.key),
                              selected: resource.key == _selected,
                              fontSize: compact ? 14 : 16,
                              onTap: () =>
                                  setState(() => _selected = resource.key),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_data == null || _error)
                      _status()
                    else
                      _chart(plotHeight),
                    if (_loading && _data != null)
                      const LinearProgressIndicator(
                        minHeight: 2,
                        color: Color(0xffbfa16b),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ResourceCapsule extends StatelessWidget {
  const _ResourceCapsule({
    super.key,
    required this.resource,
    required this.label,
    required this.current,
    required this.delta,
    required this.selected,
    required this.fontSize,
    required this.onTap,
  });
  final _Resource resource;
  final String label;
  final int? current, delta;
  final bool selected;
  final double fontSize;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final value = resourceTrendNumber(current);
    final change = delta == null
        ? '—'
        : '${delta! > 0
              ? '▲+'
              : delta! < 0
              ? '▼'
              : ''}${resourceTrendNumber(delta)}';
    final changeColor = delta == null || delta == 0
        ? const Color(0xff8da8b8)
        : delta! > 0
        ? const Color(0xff70d7b2)
        : const Color(0xffff7464);
    return Semantics(
      button: true,
      onTap: onTap,
      selected: selected,
      label: '$label, $value, $change',
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? const Color(0xff1b3543) : const Color(0xff142735),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: selected
                  ? resource.color.withValues(alpha: .7)
                  : const Color(0xff29404e),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: resource.color, width: 3),
                ),
              ),
              padding: const EdgeInsets.only(left: 7, right: 9),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final style = TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  );
                  final scaler = MediaQuery.textScalerOf(context);
                  double measure(String s) => (TextPainter(
                    text: TextSpan(
                      text: s,
                      style: DefaultTextStyle.of(context).style.merge(style),
                    ),
                    textDirection: TextDirection.ltr,
                    textScaler: scaler,
                  )..layout()).width;
                  final contentWidth = math.max(
                    constraints.maxWidth,
                    26 + 8 + measure(value) + 12 + measure(change) + 1,
                  );
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: contentWidth,
                      height: 40,
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: resource.color.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/images/material/${resource.icon}.png',
                              width: scaler.scale(fontSize),
                              height: scaler.scale(fontSize),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            value,
                            style: style.copyWith(
                              color: const Color(0xffeff5f8),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 12),
                          Text(
                            change,
                            style: style.copyWith(color: changeColor),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
