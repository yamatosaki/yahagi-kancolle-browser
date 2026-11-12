part of 'sortie_experience_card.dart';

enum _ResourceKind {
  fuel('material-1'),
  ammo('material-2'),
  steel('material-3'),
  bauxite('material-4'),
  buckets('material-6');

  const _ResourceKind(this.resourceId);

  final String resourceId;

  String label(AppLocalizations l10n) => switch (this) {
    fuel => l10n.fuel,
    ammo => l10n.ammo,
    steel => l10n.steel,
    bauxite => l10n.bauxite,
    buckets =>
      l10n.localeName.startsWith('zh') ? '桶' : l10n.resourceTrendRepairMaterial,
  };

  int amount(SortieResourceAmounts amounts) => switch (this) {
    fuel => amounts.fuel,
    ammo => amounts.ammo,
    steel => amounts.steel,
    bauxite => amounts.bauxite,
    buckets => amounts.buckets,
  };

  Widget icon({double size = 13}) => Image.asset(
    headerResourceById[resourceId]!.assetPath,
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

String _resourceAmountsText(
  AppLocalizations l10n,
  NumberFormat format,
  SortieResourceAmounts amounts,
  Iterable<_ResourceKind> kinds,
) => kinds
    .map((kind) => '${kind.label(l10n)} ${format.format(kind.amount(amounts))}')
    .join(' · ');

class _WarehouseSpendingSummary extends StatelessWidget {
  const _WarehouseSpendingSummary({
    required this.strings,
    required this.localizations,
    required this.format,
    required this.confirmed,
    required this.unallocated,
    required this.incomplete,
  });

  final SortieExperienceStrings strings;
  final AppLocalizations localizations;
  final NumberFormat format;
  final SortieResourceAmounts confirmed;
  final SortieResourceAmounts unallocated;
  final bool incomplete;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final flat = PanelStyleScope.isFlat(context);
    final recorded = !confirmed.isEmpty;
    String amounts(SortieResourceAmounts data) => _resourceAmountsText(
      localizations,
      format,
      data,
      _ResourceKind.values.where((kind) => kind.amount(data) > 0),
    );
    return DecoratedBox(
      key: const Key('sortie-exp-resource-summary'),
      decoration: BoxDecoration(
        color: flat ? Colors.transparent : palette.inner,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(flat ? 0 : 7),
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _summary(context, strings.warehouseSpending),
            const SizedBox(height: 5),
            _resourceGroups(context, recorded),
            if (!recorded) _secondary(context, strings.resourceUnrecorded),
            if (!unallocated.isEmpty)
              _secondary(
                context,
                '${strings.unallocatedSpending} · ${amounts(unallocated)}',
              ),
            if (incomplete) _secondary(context, strings.resourceIncomplete),
          ],
        ),
      ),
    );
  }

  Widget _resourceGroups(BuildContext context, bool recorded) {
    const columnGap = 4.0;
    const rowGap = 6.0;
    const iconWidth = 13.0;
    const iconGap = 2.0;
    final groups = [
      for (final kind in _ResourceKind.values)
        (
          kind: kind,
          label: kind.label(localizations),
          value: recorded ? format.format(kind.amount(confirmed)) : '—',
        ),
    ];
    final labelStyle = _secondaryStyle(context);
    final numberStyle = _summaryValueStyle(context);
    final compactNumberStyle = numberStyle.copyWith(
      fontFamily: 'HarmonyOS_Sans_Condensed',
    );
    final inheritedStyle = DefaultTextStyle.of(context).style;
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final boldText = MediaQuery.boldTextOf(context);

    double measure(String value, TextStyle style) {
      final effectiveStyle = inheritedStyle.merge(style);
      return TextPainter.computeWidth(
        text: TextSpan(
          text: value,
          style: boldText
              ? effectiveStyle.copyWith(fontWeight: FontWeight.w700)
              : effectiveStyle,
        ),
        textDirection: direction,
        locale: locale,
        textScaler: textScaler,
        maxLines: 1,
      );
    }

    final widestLabel = groups
        .map((group) => measure(group.label, labelStyle) + iconWidth + iconGap)
        .reduce(math.max);
    double widestNumber(TextStyle style) =>
        groups.map((group) => measure(group.value, style)).reduce(math.max);
    final regularWidth = math.max(widestLabel, widestNumber(numberStyle));
    final compactWidth = widestNumber(compactNumberStyle);

    return LayoutBuilder(
      builder: (context, constraints) {
        bool fits(int count, double width) =>
            count * width + (count - 1) * columnGap <= constraints.maxWidth;

        final regularFits = fits(5, regularWidth);
        final columns =
            regularFits || fits(5, math.max(widestLabel, compactWidth))
            ? 5
            : fits(3, compactWidth)
            ? 3
            : fits(2, compactWidth)
            ? 2
            : 1;
        final valueStyle = regularFits ? numberStyle : compactNumberStyle;

        Widget groupAt(int index) {
          if (index >= groups.length) return const SizedBox.shrink();
          final group = groups[index];
          return Column(
            key: Key('sortie-exp-resource-group-${group.kind.name}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  group.kind.icon(size: iconWidth),
                  const SizedBox(width: iconGap),
                  Flexible(child: Text(group.label, style: labelStyle)),
                ],
              ),
              Text(group.value, style: valueStyle),
            ],
          );
        }

        return Column(
          children: [
            for (var start = 0; start < groups.length; start += columns) ...[
              if (start > 0) const SizedBox(height: rowGap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: columnGap),
                      Expanded(child: groupAt(start + column)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _WarehouseShipSpending extends StatelessWidget {
  const _WarehouseShipSpending({
    required this.strings,
    required this.localizations,
    required this.format,
    required this.spending,
  });

  final SortieExperienceStrings strings;
  final AppLocalizations localizations;
  final NumberFormat format;
  final SortieShipResourceSpending? spending;

  @override
  Widget build(BuildContext context) {
    final data = spending;
    final palette = AppPalette.of(context);
    final warning = data?.incomplete == true
        ? Tooltip(
            message: strings.resourceIncomplete,
            child: Icon(Icons.info_outline, color: palette.warning, size: 12),
          )
        : null;
    if (data == null || data.total.isEmpty) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _secondary(context, strings.resourceUnrecorded),
            if (warning != null) ...[const SizedBox(width: 3), warning],
          ],
        ),
      );
    }
    final style = appTextStyle(
      context,
      TextStyle(
        color: palette.foreground,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final kind in _ResourceKind.values)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Semantics(
              label:
                  '${kind.label(localizations)} ${format.format(kind.amount(data.total))}',
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  kind.icon(size: 12),
                  const SizedBox(width: 2),
                  Text(format.format(kind.amount(data.total)), style: style),
                ],
              ),
            ),
          ),
        ?warning,
      ],
    );
  }
}

Future<void> _showWarehouseSpendingDialog(
  BuildContext context,
  SortieExperienceStrings strings,
  AppLocalizations l10n,
  NumberFormat format,
  String name,
  SortieShipResourceSpending? spending,
) async {
  final title = strings.shipBill(name);
  String amounts(
    SortieResourceAmounts? data,
    List<_ResourceKind> kinds, {
    bool knownZero = false,
  }) => data == null || (data.isEmpty && !knownZero)
      ? strings.resourceUnrecorded
      : _resourceAmountsText(l10n, format, data, kinds);
  final sections = [
    (
      strings.supplySpending,
      amounts(spending?.supply, const [
        _ResourceKind.fuel,
        _ResourceKind.ammo,
        _ResourceKind.bauxite,
      ]),
    ),
    (
      strings.repairSpending,
      amounts(spending?.repair, const [
        _ResourceKind.fuel,
        _ResourceKind.steel,
        _ResourceKind.buckets,
      ]),
    ),
    (
      strings.pendingSupply,
      amounts(spending?.pending, const [
        _ResourceKind.fuel,
        _ResourceKind.ammo,
        _ResourceKind.bauxite,
      ], knownZero: spending != null && !spending.total.isEmpty),
    ),
  ];
  await showGameSurfaceDialog<bool>(
    context: context,
    title: title,
    protectInputOnDismiss: false,
    rows: [
      for (final (label, value) in sections) '$label · $value',
      if (spending?.incomplete ?? false) strings.resourceIncomplete,
    ],
    actions: [
      GameSurfaceDialogAction(id: 'close', label: l10n.close, value: true),
    ],
    builder: (context, close) => AlertDialog(
      key: const Key('sortie-exp-resource-dialog'),
      scrollable: true,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in sections) ...[
            _summary(context, label),
            _secondary(context, value),
            const SizedBox(height: 8),
          ],
          if (spending?.incomplete ?? false)
            _secondary(context, strings.resourceIncomplete),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('sortie-exp-resource-close'),
          onPressed: () => close(true),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}
