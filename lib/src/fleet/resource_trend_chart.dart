import '../theme/app_palette.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import '../../l10n/app_localizations.dart';
import 'resource_trend_data.dart';

/// Integer, locally scaled ticks: small changes remain legible without implying
/// that a truncated Y axis starts at zero.
class ResourceTrendScale {
  const ResourceTrendScale(this.min, this.max, this.step);
  factory ResourceTrendScale.forValues(Iterable<int> values, {int? baseline}) {
    final all = [...values, ?baseline];
    if (all.isEmpty) return const ResourceTrendScale(0, 4, 1);
    final low = all.reduce(math.min).toDouble();
    final high = all.reduce(math.max).toDouble();
    final padding = math.max(1.0, (high - low) * .15);
    final rawStep = math.max(1.0, (high - low + padding * 2) / 4);
    final magnitude = math
        .pow(10, (math.log(rawStep) / math.ln10).floor())
        .toDouble();
    final fraction = rawStep / magnitude;
    final step =
        (fraction <= 1
            ? 1
            : fraction <= 2
            ? 2
            : fraction <= 5
            ? 5
            : 10) *
        magnitude;
    final min = math.max(0.0, ((low - padding) / step).floor() * step);
    final max = math.max(
      min + step * 2,
      ((high + padding) / step).ceil() * step,
    );
    return ResourceTrendScale(min, max, step);
  }
  final double min, max, step;
  List<double> get ticks =>
      List.generate(((max - min) / step).round() + 1, (i) => min + i * step);
}

int nearestResourceTrendPoint(List<ResourceTrendPoint> points, DateTime time) {
  assert(points.isNotEmpty);
  var low = 0;
  var high = points.length - 1;
  while (low < high) {
    final mid = (low + high) ~/ 2;
    if (points[mid].time.isBefore(time)) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  if (low > 0 &&
      time.difference(points[low - 1].time).abs() <
          points[low].time.difference(time).abs()) {
    low--;
  }
  // Multiple API snapshots may share a timestamp. Inspection agrees with the
  // latest inventory and highlighted endpoint by selecting the newest one.
  while (low + 1 < points.length && points[low + 1].time == points[low].time) {
    low++;
  }
  return low;
}

String resourceTrendTime(DateTime time, {bool seconds = false}) => DateFormat(
  seconds ? 'MM-dd HH:mm:ss' : 'MM-dd HH:mm',
).format(resourceTrendJst(time));
String resourceTrendNumber(int? value) =>
    value == null ? '—' : NumberFormat.decimalPattern().format(value);
const _muted = Color(0xff8da8b8);
const _line = Color(0xff294555);

class ResourceTrendChart extends StatefulWidget {
  const ResourceTrendChart({
    super.key,
    required this.data,
    required this.resourceKey,
    required this.label,
    required this.color,
    required this.iconId,
    required this.plotHeight,
    required this.onExpand,
    this.expanded = false,
  });
  final ResourceTrendData data;
  final String resourceKey, label, iconId;
  final Color color;
  final double plotHeight;
  final VoidCallback onExpand;
  final bool expanded;
  @override
  State<ResourceTrendChart> createState() => _ResourceTrendChartState();
}

class _ResourceTrendChartState extends State<ResourceTrendChart> {
  int? _inspection;
  double? _scrubPosition;
  AppLocalizations get l10n =>
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('zh'));
  List<ResourceTrendPoint> get points => widget.data.points(widget.resourceKey);

  @override
  void didUpdateWidget(covariant ResourceTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resourceKey != widget.resourceKey ||
        !identical(oldWidget.data, widget.data)) {
      _inspection = null;
      _scrubPosition = null;
    }
  }

  void _inspect(double fraction) {
    if (points.isEmpty) return;
    final window = widget.data.window;
    final time = window.start.add(
      Duration(
        microseconds:
            (window.end.difference(window.start).inMicroseconds *
                    fraction.clamp(0, 1))
                .round(),
      ),
    );
    setState(() {
      // Preserve continuous input separately from the nearest observed sample.
      // Keyboard/TalkBack increments must accumulate across gaps in the data.
      _scrubPosition = fraction.clamp(0.0, 1.0);
      _inspection = nearestResourceTrendPoint(points, time);
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final current = data.current(widget.resourceKey);
    final delta = data.delta(widget.resourceKey);
    final chosen = points.isEmpty
        ? null
        : points[_inspection ?? points.length - 1];
    final short = widget.expanded && MediaQuery.sizeOf(context).height < 500;
    final window = data.window;
    final duration = math.max(
      1,
      window.end.difference(window.start).inMicroseconds,
    );
    final position =
        _scrubPosition ??
        (chosen == null
            ? 0.0
            : (chosen.time.difference(window.start).inMicroseconds / duration)
                  .clamp(0.0, 1.0));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: appColor(context, Color(0xff102532)),
        border: Border.all(color: appColor(context, _line)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 6, top: 2),
            child: Row(
              children: [
                if (widget.expanded) ...[
                  Image.asset(
                    'assets/images/material/${widget.iconId}.png',
                    width: 18,
                    height: 18,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Text(
                    widget.expanded
                        ? '${widget.label} · ${l10n.resourceTrendInventoryTitle}'
                        : l10n.resourceTrendInventoryTitle,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, Color(0xffc3d2da)),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (short) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.resourceTrendLatest} ',
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _muted), fontSize: 11),
                    ),
                  ),
                  Text(
                    resourceTrendNumber(current),
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, const Color(0xffeff5f8)),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${l10n.resourceTrendChange} ',
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _muted), fontSize: 11),
                    ),
                  ),
                  Text(
                    delta == null
                        ? '—'
                        : '${delta > 0 ? '+' : ''}${resourceTrendNumber(delta)}',
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: delta == null || delta == 0
                            ? appColor(context, _muted)
                            : delta > 0
                            ? const Color(0xff70d7b2)
                            : const Color(0xffff7464),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  key: ValueKey(
                    widget.expanded
                        ? 'resource-trend-close'
                        : 'resource-trend-expand',
                  ),
                  tooltip: widget.expanded
                      ? l10n.close
                      : l10n.resourceTrendExpand,
                  onPressed: widget.onExpand,
                  icon: Icon(
                    widget.expanded ? Icons.close : Icons.open_in_full,
                    size: 17,
                    color: appColor(context, _muted),
                  ),
                ),
              ],
            ),
          ),
          if (!short)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!widget.expanded) ...[
                              Image.asset(
                                'assets/images/material/${widget.iconId}.png',
                                width: 18,
                                height: 18,
                              ),
                              const SizedBox(width: 7),
                            ],
                            Flexible(
                              child: Text(
                                widget.expanded
                                    ? l10n.resourceTrendLatest
                                    : '${widget.label} · ${l10n.resourceTrendLatest}',
                                style: appTextStyle(
                                  context,
                                  TextStyle(
                                    color: appColor(context, _muted),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            resourceTrendNumber(current),
                            style: appTextStyle(
                              context,
                              TextStyle(
                                color: appColor(context, Color(0xffeff5f8)),
                                fontSize: 28,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          l10n.resourceTrendChange,
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: appColor(context, _muted),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            delta == null
                                ? '—'
                                : '${delta > 0 ? '+' : ''}${resourceTrendNumber(delta)}',
                            style: appTextStyle(
                              context,
                              TextStyle(
                                color: delta == null || delta == 0
                                    ? _muted
                                    : delta > 0
                                    ? const Color(0xff70d7b2)
                                    : const Color(0xffff7464),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
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
          if (points.isEmpty)
            SizedBox(
              height: widget.plotHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.resourceTrendNoPeriodData,
                    textAlign: TextAlign.center,
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _muted)),
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                height: widget.plotHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale =
                        MediaQuery.textScalerOf(context).scale(11) / 11;
                    final scale = ResourceTrendScale.forValues(
                      points.map((p) => p.value),
                      baseline: data.baseline?.value(widget.resourceKey),
                    );
                    final painter = ResourceTrendPainter(
                      palette: AppPalette.of(context),
                      points: points,
                      window: window,
                      scale: scale,
                      color: appColor(context, widget.color),
                      selected: _inspection,
                      baseline: data.baseline?.value(widget.resourceKey),
                      baselineLabel: l10n.resourceTrendBaseShort,
                      textScale: textScale.clamp(1, 1.5),
                      locale: l10n.localeName,
                      fontFamily: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.fontFamily,
                    );
                    final rect = painter.plotRect(
                      Size(constraints.maxWidth, constraints.maxHeight),
                    );
                    void touch(Offset offset) =>
                        _inspect((offset.dx - rect.left) / rect.width);
                    return Semantics(
                      label:
                          '${widget.label}, ${l10n.resourceTrendInventoryTitle}. ${chosen == null ? '' : '${resourceTrendTime(chosen.time, seconds: true)} JST, ${chosen.value}'}',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => touch(details.localPosition),
                        onHorizontalDragStart: (details) =>
                            touch(details.localPosition),
                        onHorizontalDragUpdate: (details) =>
                            touch(details.localPosition),
                        child: CustomPaint(
                          key: const ValueKey('resource-trend-canvas'),
                          painter: painter,
                          size: Size.infinite,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(11) / 11;
                  final narrow = constraints.maxWidth / textScale < 250;
                  final instruction = Text(
                    l10n.resourceTrendInspect,
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _muted), fontSize: 11),
                    ),
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (narrow) ...[instruction, const SizedBox(height: 4)],
                      Row(
                        children: [
                          if (!narrow) instruction,
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2,
                                activeTrackColor: appColor(
                                  context,
                                  widget.color.withValues(alpha: .7),
                                ),
                                inactiveTrackColor: appColor(context, _line),
                                thumbColor: appColor(context, widget.color),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 13,
                                ),
                              ),
                              child: Slider(
                                key: const ValueKey('resource-trend-scrubber'),
                                value: position,
                                onChanged: points.length > 1 ? _inspect : null,
                                semanticFormatterCallback: (value) {
                                  final time = window.start.add(
                                    Duration(
                                      microseconds: (duration * value).round(),
                                    ),
                                  );
                                  final p =
                                      points[nearestResourceTrendPoint(
                                        points,
                                        time,
                                      )];
                                  return '${resourceTrendTime(p.time, seconds: true)} JST, ${p.value}';
                                },
                              ),
                            ),
                          ),
                          Text(
                            DateFormat(
                              window.days == 1 ? 'HH:mm' : 'MM-dd',
                            ).format(resourceTrendJst(chosen!.time)),
                            style: appTextStyle(
                              context,
                              TextStyle(
                                color: appColor(context, Color(0xffd6e2e8)),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          if (!short)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: appColor(context, _line)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 18,
                    runSpacing: 4,
                    children: [
                      Text(
                        data.baseline == null
                            ? l10n.resourceTrendInsufficient
                            : l10n.resourceTrendBaseline(
                                resourceTrendTime(data.baseline!.time),
                              ),
                        style: appTextStyle(
                          context,
                          TextStyle(
                            color: appColor(context, _muted),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (data.latest != null)
                        Text(
                          l10n.resourceTrendObserved(
                            resourceTrendTime(data.latest!.time),
                          ),
                          style: appTextStyle(
                            context,
                            TextStyle(
                              color: appColor(context, _muted),
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    delta == null
                        ? l10n.resourceTrendInsufficient
                        : data.baseline!.time.isAfter(window.start)
                        ? l10n.resourceTrendPartial
                        : l10n.resourceTrendLocalScale,
                    style: appTextStyle(
                      context,
                      TextStyle(color: appColor(context, _muted), fontSize: 10),
                    ),
                  ),
                  if (data.recordCount > points.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.resourceTrendSampled,
                        style: appTextStyle(
                          context,
                          TextStyle(
                            color: appColor(context, _muted),
                            fontSize: 10,
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
}

class ResourceTrendPainter extends CustomPainter {
  ResourceTrendPainter({
    required this.palette,
    required this.points,
    required this.window,
    required this.scale,
    required this.color,
    required this.selected,
    required this.baseline,
    required this.baselineLabel,
    this.textScale = 1,
    this.fontFamily,
    this.locale = 'zh',
  });
  final List<ResourceTrendPoint> points;
  final AppPalette palette;
  final ResourceTrendWindow window;
  final ResourceTrendScale scale;
  final Color color;
  final int? selected, baseline;
  final String baselineLabel;
  final double textScale;
  final String? fontFamily;
  final String locale;
  Rect plotRect(Size size) {
    final labelWidth = scale.ticks
        .map((value) => text(tick(value)).width)
        .fold(0.0, math.max);
    final left = math.max(52 * textScale, labelWidth + 10);
    return Rect.fromLTRB(
      left,
      24,
      math.max(left + 1, size.width - 24 * textScale),
      math.max(25, size.height - 30 * textScale),
    );
  }

  double fraction(DateTime time) =>
      time.difference(window.start).inMicroseconds /
      math.max(1, window.end.difference(window.start).inMicroseconds);
  double y(double value, Rect rect) =>
      rect.bottom - (value - scale.min) / (scale.max - scale.min) * rect.height;
  Offset offset(ResourceTrendPoint p, Rect rect) => Offset(
    rect.left + fraction(p.time) * rect.width,
    y(p.value.toDouble(), rect),
  );

  TextPainter text(
    String value, {
    Color ink = _muted,
    double size = 11,
    FontWeight weight = FontWeight.w400,
  }) => TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        color: palette.color(ink),
        fontSize: size * textScale,
        fontFamily: fontFamily,
        fontWeight: weight,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  void dash(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double length = 4,
    double gap = 5,
  }) {
    final vector = end - start;
    final distance = vector.distance;
    if (distance == 0) return;
    for (double i = 0; i < distance; i += length + gap) {
      canvas.drawLine(
        start + vector * (i / distance),
        start + vector * (math.min(i + length, distance) / distance),
        paint,
      );
    }
  }

  String tick(double value) {
    if (value.abs() >= 10000 && scale.step >= 1000) {
      final digits = scale.step >= 10000
          ? 0
          : scale.step >= 1000
          ? 1
          : 2;
      final formatter = NumberFormat.compact(locale: locale)
        ..minimumFractionDigits = digits
        ..maximumFractionDigits = digits;
      return formatter.format(value);
    }
    return NumberFormat.decimalPattern().format(value.round());
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final rect = plotRect(size);
    final grid = Paint()
      ..color = palette.color(const Color(0xff365262)).withValues(alpha: .5)
      ..strokeWidth = 1;
    for (final value in scale.ticks) {
      final yy = y(value, rect);
      dash(canvas, Offset(rect.left, yy), Offset(rect.right, yy), grid);
      final label = text(tick(value));
      label.paint(
        canvas,
        Offset(math.max(0, rect.left - label.width - 9), yy - label.height / 2),
      );
    }
    final labels = rect.width < 380 ? 3 : 5;
    final duration = window.end.difference(window.start).inMicroseconds;
    // Very early in a natural day, second labels avoid identical HH:mm ticks.
    final format = DateFormat(
      window.days == 1
          ? duration < 240000000
                ? 'HH:mm:ss'
                : 'HH:mm'
          : 'MM-dd',
    );
    for (var i = 0; i < labels; i++) {
      final time = window.start.add(
        Duration(microseconds: (duration * i / (labels - 1)).round()),
      );
      final label = text(format.format(resourceTrendJst(time)), size: 10);
      final x = rect.left + rect.width * i / (labels - 1);
      label.paint(
        canvas,
        Offset(
          (x - label.width / 2).clamp(
            0.0,
            math.max(0, size.width - label.width),
          ),
          rect.bottom + 11,
        ),
      );
    }
    canvas.save();
    canvas.clipRect(rect.inflate(5));
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = offset(points[i], rect);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (points.length > 1) {
      final fill = Path.from(path)
        ..lineTo(offset(points.last, rect).dx, rect.bottom)
        ..lineTo(offset(points.first, rect).dx, rect.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: .23),
              color.withValues(alpha: .08),
              color.withValues(alpha: .005),
            ],
            stops: const [0, .55, 1],
          ).createShader(rect),
      );
    }
    if (baseline != null) {
      dash(
        canvas,
        Offset(rect.left, y(baseline!.toDouble(), rect)),
        Offset(rect.right, y(baseline!.toDouble(), rect)),
        Paint()
          ..color = palette
              .color(const Color(0xffc2a56a))
              .withValues(alpha: .65)
          ..strokeWidth = 1,
        length: 7,
        gap: 5,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: .07)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.25
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final last = offset(points.last, rect);
    canvas.drawCircle(last, 8, Paint()..color = color.withValues(alpha: .1));
    canvas.drawCircle(last, 4, Paint()..color = color);
    canvas.drawCircle(
      last,
      2,
      Paint()..color = palette.color(const Color(0xffe8fff6)),
    );
    canvas.restore();
    if (baseline != null && selected == null) {
      final label = text(
        '$baselineLabel ${resourceTrendNumber(baseline)}',
        ink: const Color(0xffc4ad81),
        size: 10,
      );
      final origin = Offset(
        rect.left + 6,
        (y(baseline!.toDouble(), rect) - label.height - 5).clamp(
          rect.top,
          rect.bottom - label.height,
        ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            origin.dx - 3,
            origin.dy - 2,
            label.width + 6,
            label.height + 4,
          ),
          const Radius.circular(3),
        ),
        Paint()
          ..color = palette
              .color(const Color(0xff102532))
              .withValues(alpha: .9),
      );
      label.paint(canvas, origin);
    }
    if (selected != null) {
      final chosen = points[selected!.clamp(0, points.length - 1)];
      final p = offset(chosen, rect);
      dash(
        canvas,
        Offset(p.dx, rect.top),
        Offset(p.dx, rect.bottom),
        Paint()
          ..color = color.withValues(alpha: .65)
          ..strokeWidth = 1,
        length: 3,
        gap: 4,
      );
      canvas.drawCircle(p, 8, Paint()..color = color.withValues(alpha: .18));
      canvas.drawCircle(
        p,
        4,
        Paint()..color = palette.color(const Color(0xff102532)),
      );
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final date = text(
        '${resourceTrendTime(chosen.time, seconds: true)} JST',
        size: 10,
      );
      final value = text(
        resourceTrendNumber(chosen.value),
        ink: color,
        size: 17,
        weight: FontWeight.w700,
      );
      final width = math.max(date.width, value.width) + 24;
      final height = date.height + value.height + 22;
      final left = (p.dx > rect.center.dx ? p.dx - width - 14 : p.dx + 14)
          .clamp(1.0, math.max(1, size.width - width - 1));
      final top = (p.dy - height - 14).clamp(
        2.0,
        math.max(2, rect.bottom - height),
      );
      final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(left.toDouble(), top.toDouble(), width, height),
        const Radius.circular(7),
      );
      canvas.drawShadow(Path()..addRRect(box), Colors.black54, 6, false);
      canvas.drawRRect(
        box,
        Paint()..color = palette.color(const Color(0xff183444)),
      );
      canvas.drawRRect(
        box,
        Paint()
          ..color = palette.color(const Color(0xff517082))
          ..style = PaintingStyle.stroke,
      );
      date.paint(canvas, Offset(left + 12, top + 8));
      value.paint(canvas, Offset(left + 12, top + 12 + date.height));
    }
  }

  @override
  bool shouldRepaint(covariant ResourceTrendPainter oldDelegate) => true;
}
