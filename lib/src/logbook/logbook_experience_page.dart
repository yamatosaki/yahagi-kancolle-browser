part of 'logbook_page.dart';

class _LogbookExperiencePage extends StatefulWidget {
  const _LogbookExperiencePage({
    required this.database,
    required this.memberId,
    this.sortieExperienceController,
  });

  final LogbookDatabase database;
  final int memberId;
  final SortieExperienceController? sortieExperienceController;

  @override
  State<_LogbookExperiencePage> createState() => _LogbookExperiencePageState();
}

class _LogbookExperiencePageState extends State<_LogbookExperiencePage> {
  static const _batchSize = 50;

  List<LogbookExperienceRecord> _records = const [];
  String? _expandedEventKey;
  int _queryGeneration = 0;
  bool _loading = false;
  bool _hasMore = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    widget.database
        .changesFor(LogbookChangeCategory.experience)
        .addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    widget.database
        .changesFor(LogbookChangeCategory.experience)
        .removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => unawaited(_load(refresh: true));

  Future<void> _load({bool refresh = false}) async {
    if (!refresh && (_loading || !_hasMore)) return;
    final generation = ++_queryGeneration;
    final offset = refresh ? 0 : _records.length;
    setState(() => _loading = true);
    try {
      final page = await widget.database.getExperienceRecords(
        limit: _batchSize,
        offset: offset,
      );
      if (!mounted || generation != _queryGeneration) return;
      setState(() {
        if (refresh) {
          final latestKey = page.firstOrNull?.eventKey;
          if (latestKey != _records.firstOrNull?.eventKey ||
              (_expandedEventKey != null &&
                  !page.any(
                    (record) => record.eventKey == _expandedEventKey,
                  ))) {
            _expandedEventKey = latestKey;
          }
        }
        _records = refresh ? page : [..._records, ...page];
        _hasMore = page.length == _batchSize;
        _loadFailed = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _queryGeneration) return;
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  bool _isCombined(LogbookExperienceRecord record) =>
      !record.isPractice &&
      record.deckId > 0 &&
      record.ships.any((ship) => ship.fleetId != record.deckId);

  List<_ExperienceTableRow> _tableRows(
    LogbookExperienceStrings strings,
    SortieExperienceStrings sortieStrings,
  ) {
    final rows = <_ExperienceTableRow>[];
    for (final record in _records) {
      rows.add(_ExperienceSummaryRow(record));
      if (record.eventKey != _expandedEventKey) continue;
      rows.add(
        _ExperienceHeadingRow(
          sortieStrings.ship,
          strings.gained(record.isPractice),
        ),
      );
      if (record.ships.isEmpty) {
        rows.add(_ExperienceHeadingRow(sortieStrings.emptyRoster));
      }
      final combined = _isCombined(record);
      int? previousFleet;
      for (final ship in record.ships) {
        if (combined && ship.fleetId != previousFleet) {
          rows.add(
            _ExperienceHeadingRow(
              ship.fleetId == record.deckId
                  ? sortieStrings.fleetMain
                  : sortieStrings.fleetEscort,
            ),
          );
        }
        rows.add(_ExperienceShipRow(ship));
        previousFleet = ship.fleetId;
      }
    }
    return rows;
  }

  Widget _shipProgress(LogbookExperienceShip ship, NumberFormat format) {
    final id = ship.ownedShipId;
    Widget progressCell(int? level, int? next) => SortieExperienceProgress(
      levelText: 'Lv.${level ?? '—'}',
      nextText: 'Next. ${next == null ? '—' : format.format(next)}',
      levelKey: ValueKey('logbook-experience-level-$id'),
      nextKey: ValueKey('logbook-experience-next-$id'),
    );

    final controller = widget.sortieExperienceController;
    if (controller == null) return progressCell(null, null);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final progress = controller.memberId == widget.memberId
            ? controller.progressFor(id)
            : null;
        return progressCell(progress?.level, progress?.nextExperience);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = LogbookExperienceStrings.of(context);
    final sortieStrings = SortieExperienceStrings(
      Localizations.localeOf(context),
    );
    final rows = _tableRows(strings, sortieStrings);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 34,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _hasMore && _records.isNotEmpty
                    ? strings.loaded(_records.length)
                    : strings.total(_records.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: appColor(context, const Color(0xff8ba2af)),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) => _buildTable(
                      context,
                      constraints.maxWidth,
                      rows,
                      strings,
                      sortieStrings,
                    ),
                  ),
                ),
                if (_records.isEmpty)
                  Center(
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _loadFailed
                        ? TextButton(
                            onPressed: _refresh,
                            child: Text(strings.retry),
                          )
                        : Text(
                            strings.empty,
                            style: appTextStyle(
                              context,
                              const TextStyle(fontSize: 12),
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

  Widget _buildTable(
    BuildContext context,
    double width,
    List<_ExperienceTableRow> rows,
    LogbookExperienceStrings strings,
    SortieExperienceStrings sortieStrings,
  ) {
    final compact = width < 540;
    final hasTypeColumn = width >= 320;
    final frozenWidth = !hasTypeColumn
        ? width * .57
        : compact
        ? (width * .52).clamp(145.0, 210.0)
        : (width * .42).clamp(225.0, 250.0);
    final progressWidth = (frozenWidth * (compact ? .56 : .38)).clamp(
      0.0,
      100.0,
    );
    final typeWidth = !hasTypeColumn
        ? 0.0
        : compact
        ? (width * .16).clamp(46.0, 58.0)
        : 92.0;
    final fleetWidth = compact ? 0.0 : 118.0;
    final resultWidth = width - frozenWidth - typeWidth - fleetWidth;
    final scrollWidths = [
      if (hasTypeColumn) typeWidth,
      if (!compact) fleetWidth,
      resultWidth,
    ];
    final locale = Localizations.localeOf(context);
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final format = NumberFormat.decimalPattern(locale.toLanguageTag());
    final names = gameNames(context);
    final expColor = appColor(context, const Color(0xff8adac7));
    final mutedColor = appColor(context, const Color(0xff9fb3bf));
    final textLine = (MediaQuery.textScalerOf(context).scale(12) * 1.3)
        .ceilToDouble();

    Widget shipColumns(Widget name, Widget progress) => Row(
      children: [
        Expanded(child: name),
        SizedBox(width: progressWidth, child: progress),
      ],
    );

    Widget result(LogbookExperienceRecord record, String fleet, String area) {
      final battles = sortieStrings.battles(
        format.format(record.battles),
        singular: record.battles == 1,
      );
      return Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!hasTypeColumn) _ExperienceCell(area, color: mutedColor),
                if (compact) _ExperienceCell(fleet),
                _ExperienceCell(battles, maxLines: 2),
                if (record.incomplete)
                  _ExperienceCell(
                    strings.partial,
                    color: appColor(context, const Color(0xffe4bc76)),
                  ),
              ],
            ),
          ),
          if (resultWidth >= 48) ...[
            Icon(
              record.eventKey == _expandedEventKey
                  ? Icons.expand_more
                  : Icons.chevron_right,
              size: 17,
              color: mutedColor,
            ),
            const SizedBox(width: 3),
          ],
        ],
      );
    }

    return FrozenDataTable(
      key: const Key('logbook-table-experience'),
      keyPrefix: 'logbook-experience',
      frozenColumnWidths: [frozenWidth],
      frozenHeaders: [_HeaderCell(strings.completedAt)],
      frozenCells: (index) => [
        switch (rows[index]) {
          _ExperienceSummaryRow(:final record) => KeyedSubtree(
            key: Key('logbook-experience-record-${record.eventKey}'),
            child: _TextCell(
              _formatTime(record.completedAt.millisecondsSinceEpoch),
              color: appColor(context, const Color(0xffd7e3e9)),
              localize: false,
            ),
          ),
          _ExperienceHeadingRow(:final label, :final amountLabel) =>
            amountLabel == null
                ? _HeaderCell(label)
                : shipColumns(_HeaderCell(label), _HeaderCell(l10n.level)),
          _ExperienceShipRow(:final ship) => shipColumns(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SortieExperienceShipName(
                name: ship.name.isEmpty
                    ? sortieStrings.unknownShip
                    : names.shipName(ship.name, shipId: ship.masterShipId),
                retreatedLabel: ship.retreated ? sortieStrings.retreated : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 2),
              child: _shipProgress(ship, format),
            ),
          ),
        },
      ],
      scrollableColumnWidths: scrollWidths,
      scrollableHeaders: [
        if (hasTypeColumn)
          _HeaderCell(compact ? strings.type : strings.areaType),
        if (!compact) _HeaderCell(strings.fleet),
        _HeaderCell(
          !hasTypeColumn
              ? strings.typeFleetAndBattles
              : compact
              ? strings.fleetAndBattles
              : strings.battles,
        ),
      ],
      scrollableCells: (index) {
        final row = rows[index];
        if (row is _ExperienceSummaryRow) {
          final record = row.record;
          final area = record.isPractice
              ? strings.practice
              : record.mapAreaId > 0 && record.mapInfoNo > 0
              ? '${record.mapAreaId}-${record.mapInfoNo}'
              : '—';
          final fleet = _isCombined(record)
              ? strings.combined
              : record.deckId > 0
              ? sortieStrings.fleet(record.deckId)
              : '—';
          return [
            if (hasTypeColumn)
              _TextCell(area, strong: true, localize: false, color: mutedColor),
            if (!compact) _ExperienceCell(fleet),
            result(record, fleet, area),
          ];
        }
        final amount = switch (row) {
          _ExperienceHeadingRow(:final amountLabel) =>
            amountLabel == null
                ? const SizedBox.shrink()
                : _ExperienceCell(
                    amountLabel,
                    trailing: true,
                    color: mutedColor,
                  ),
          _ExperienceShipRow(:final ship) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: SortieExperienceAmount(
                value: switch (ship.experience) {
                  final exp? => '${exp > 0 ? '+' : ''}${format.format(exp)}',
                  null => sortieStrings.uncaptured,
                },
                unit: ship.experience == null ? null : 'EXP',
                color: ship.experience == null ? mutedColor : expColor,
                valueKey: ValueKey(
                  'logbook-experience-value-${ship.ownedShipId}',
                ),
              ),
            ),
          ),
          _ExperienceSummaryRow() => const SizedBox.shrink(),
        };
        return [
          for (var column = 1; column < scrollWidths.length; column++)
            const SizedBox.shrink(),
          amount,
        ];
      },
      rowHeights: [
        for (final row in rows)
          switch (row) {
            _ExperienceSummaryRow(:final record) =>
              (textLine *
                          (2 +
                              (compact ? 1 : 0) +
                              (!hasTypeColumn ? 1 : 0) +
                              (record.incomplete ? 1 : 0)) +
                      10)
                  .clamp(FrozenDataTable.minimumRowHeight, double.infinity),
            _ExperienceShipRow() => (textLine * 2 + 8).clamp(
              FrozenDataTable.minimumRowHeight,
              double.infinity,
            ),
            _ExperienceHeadingRow() => (textLine + 8).clamp(
              30.0,
              double.infinity,
            ),
          },
      ],
      onEndReached: () => unawaited(_load()),
      rowTapEnabled: (index) => rows[index] is _ExperienceSummaryRow,
      onRowTap: (index) {
        final row = rows[index];
        if (row is! _ExperienceSummaryRow) return;
        setState(() {
          final key = row.record.eventKey;
          _expandedEventKey = _expandedEventKey == key ? null : key;
        });
      },
      selectedRowIndex: rows.indexWhere(
        (row) =>
            row is _ExperienceSummaryRow &&
            row.record.eventKey == _expandedEventKey,
      ),
    );
  }
}

sealed class _ExperienceTableRow {
  const _ExperienceTableRow();
}

final class _ExperienceSummaryRow extends _ExperienceTableRow {
  const _ExperienceSummaryRow(this.record);
  final LogbookExperienceRecord record;
}

final class _ExperienceHeadingRow extends _ExperienceTableRow {
  const _ExperienceHeadingRow(this.label, [this.amountLabel]);
  final String label;
  final String? amountLabel;
}

final class _ExperienceShipRow extends _ExperienceTableRow {
  const _ExperienceShipRow(this.ship);
  final LogbookExperienceShip ship;
}

class _ExperienceCell extends StatelessWidget {
  const _ExperienceCell(
    this.text, {
    this.trailing = false,
    this.maxLines = 1,
    this.color,
  });

  final String text;
  final bool trailing;
  final int maxLines;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Align(
      alignment: trailing ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        textAlign: trailing ? TextAlign.right : TextAlign.left,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: appTextStyle(
          context,
          TextStyle(
            color: color ?? appColor(context, const Color(0xffd7e3e9)),
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ),
  );
}
