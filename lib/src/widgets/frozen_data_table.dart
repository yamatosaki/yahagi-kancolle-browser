import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

class FrozenDataTable extends StatefulWidget {
  const FrozenDataTable({
    super.key,
    required this.frozenColumnWidths,
    required this.frozenHeaders,
    required this.frozenCells,
    required this.scrollableColumnWidths,
    required this.scrollableHeaders,
    required this.scrollableCells,
    required this.rowHeights,
    this.scrollableRowWidths,
    this.headerExtent = headerHeight,
    this.keyPrefix = 'frozen-table',
    this.restoreScrollOffsets = false,
    this.verticalAnchorKeys,
    this.onEndReached,
    this.onRowTap,
    this.rowTapEnabled,
    this.selectedRowIndex,
  }) : assert(frozenColumnWidths.length == frozenHeaders.length),
       assert(scrollableColumnWidths.length == scrollableHeaders.length),
       assert(
         verticalAnchorKeys == null ||
             verticalAnchorKeys.length == rowHeights.length,
       );

  static const double headerHeight = 34;
  static const double minimumRowHeight = 44;

  final List<double> frozenColumnWidths;
  final List<Widget> frozenHeaders;
  final List<Widget> Function(int index) frozenCells;
  final List<double> scrollableColumnWidths;
  final List<Widget> scrollableHeaders;
  final List<Widget> Function(int index) scrollableCells;

  /// Alternate body column widths that still fill the scrollable pane.
  final List<double> Function(int index)? scrollableRowWidths;
  final List<double> rowHeights;
  final double headerExtent;
  final String keyPrefix;

  /// Restores each pane's offset when remounted under the same page storage.
  final bool restoreScrollOffsets;

  /// Preserves the first visible row across insertions or removals before it.
  final List<Object?>? verticalAnchorKeys;
  final VoidCallback? onEndReached;
  final ValueChanged<int>? onRowTap;
  final bool Function(int index)? rowTapEnabled;
  final int? selectedRowIndex;

  @override
  State<FrozenDataTable> createState() => _FrozenDataTableState();
}

class _FrozenDataTableState extends State<FrozenDataTable> {
  late final _horizontal = ScrollController(onAttach: _onHorizontalAttach);
  final _vertical = ScrollController();
  final _frozenVertical = ScrollController();
  bool _syncingFrozen = false;
  bool _syncingMainVertical = false;

  Key _scrollKey(String pane) {
    final name = '${widget.keyPrefix}-$pane-scroll';
    return widget.restoreScrollOffsets
        ? PageStorageKey<String>(name)
        : Key(name);
  }

  @override
  void initState() {
    super.initState();
    _vertical.addListener(_syncFrozen);
    _frozenVertical.addListener(_syncMainVertical);
  }

  void _onHorizontalAttach(ScrollPosition position) {
    if (!widget.restoreScrollOffsets) return;
    // PageStorage restores pixels before attachment without notifying the header.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _horizontal.hasClients && _horizontal.offset != 0) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant FrozenDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.rowHeights, widget.rowHeights) ||
        !identical(
          oldWidget.scrollableColumnWidths,
          widget.scrollableColumnWidths,
        ) ||
        !identical(oldWidget.frozenColumnWidths, widget.frozenColumnWidths)) {
      final anchoredOffset = _anchorOffset(oldWidget);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _clampOffset(_horizontal);
        _clampOffset(_vertical, targetOffset: anchoredOffset);
        _syncFrozen();
      });
    }
  }

  double? _anchorOffset(FrozenDataTable oldWidget) {
    final oldKeys = oldWidget.verticalAnchorKeys;
    final keys = widget.verticalAnchorKeys;
    if (oldKeys == null || keys == null || !_vertical.hasClients) return null;
    final offset = _vertical.offset;
    if (offset <= 0.1) return null;

    var oldTop = 0.0;
    for (var index = 0; index < oldKeys.length; index++) {
      final height = oldWidget.rowHeights[index];
      if (offset < oldTop + height) {
        final key = oldKeys[index];
        if (key == null) return null;
        final newIndex = keys.indexOf(key);
        if (newIndex < 0) return null;
        var newTop = 0.0;
        for (var preceding = 0; preceding < newIndex; preceding++) {
          newTop += widget.rowHeights[preceding];
        }
        return newTop +
            (offset - oldTop).clamp(0.0, widget.rowHeights[newIndex]);
      }
      oldTop += height;
    }
    return null;
  }

  void _syncFrozen() {
    if (_syncingFrozen || _syncingMainVertical || !_frozenVertical.hasClients) {
      return;
    }
    final target = _vertical.offset;
    if ((_frozenVertical.offset - target).abs() <= 0.1) return;
    _syncingFrozen = true;
    try {
      _frozenVertical.jumpTo(target);
    } finally {
      _syncingFrozen = false;
    }
    _checkEndReached();
  }

  void _syncMainVertical() {
    if (_syncingFrozen || _syncingMainVertical || !_vertical.hasClients) {
      return;
    }
    final target = _frozenVertical.offset;
    if ((_vertical.offset - target).abs() <= 0.1) return;
    _syncingMainVertical = true;
    try {
      _vertical.jumpTo(target);
    } finally {
      _syncingMainVertical = false;
    }
    _checkEndReached();
  }

  void _checkEndReached() {
    if (_vertical.hasClients && _vertical.position.extentAfter <= 120) {
      widget.onEndReached?.call();
    }
  }

  void _clampOffset(ScrollController controller, {double? targetOffset}) {
    if (!controller.hasClients) return;
    final target = (targetOffset ?? controller.offset)
        .clamp(
          controller.position.minScrollExtent,
          controller.position.maxScrollExtent,
        )
        .toDouble();
    if ((controller.offset - target).abs() > 0.1) {
      controller.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _horizontal.dispose();
    _vertical.dispose();
    _frozenVertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frozenWidth = widget.frozenColumnWidths.fold<double>(
      0,
      (sum, width) => sum + width,
    );
    final contentWidth = widget.scrollableColumnWidths.fold<double>(
      0,
      (sum, width) => sum + width,
    );
    final fixedRowHeight =
        widget.rowHeights.isNotEmpty &&
            widget.rowHeights.every(
              (height) => height == widget.rowHeights.first,
            )
        ? widget.rowHeights.first
        : null;

    Widget row(
      List<Widget> cells,
      List<double> widths,
      double height, {
      required Color background,
      bool strongTrailingBorder = false,
    }) => SizedBox(
      width: widths.fold<double>(0, (sum, width) => sum + width),
      height: height,
      child: Row(
        children: [
          for (var index = 0; index < cells.length; index++)
            SizedBox(
              width: widths[index],
              height: height,
              child: ClipRect(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: appColor(context, background),
                    border: Border(
                      right: BorderSide(
                        color: appColor(
                          context,
                          strongTrailingBorder && index == cells.length - 1
                              ? const Color(0xff38586b)
                              : const Color(0xff294052),
                        ),
                      ),
                      bottom: BorderSide(
                        color: appColor(context, Color(0xff294052)),
                      ),
                    ),
                  ),
                  child: cells[index],
                ),
              ),
            ),
        ],
      ),
    );

    Widget interactiveRow(
      int index,
      Widget child, {
      required bool exposeButtonSemantics,
    }) {
      final onTap = widget.onRowTap;
      if (onTap == null || widget.rowTapEnabled?.call(index) == false) {
        return child;
      }
      final tappable = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: child,
      );
      if (!exposeButtonSemantics) return tappable;
      return Semantics(
        button: true,
        selected: widget.selectedRowIndex == index,
        child: tappable,
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: appColor(context, const Color(0xff0b202c)),
            border: Border.all(
              color: appColor(context, const Color(0xff294052)),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: widget.headerExtent,
                child: Row(
                  children: [
                    SizedBox(
                      width: frozenWidth,
                      child: row(
                        widget.frozenHeaders,
                        widget.frozenColumnWidths,
                        widget.headerExtent,
                        background: const Color(0xff17303e),
                        strongTrailingBorder: true,
                      ),
                    ),
                    Expanded(
                      child: ClipRect(
                        child: AnimatedBuilder(
                          animation: _horizontal,
                          builder: (context, child) {
                            final offset = _horizontal.hasClients
                                ? _horizontal.offset
                                : 0.0;
                            return OverflowBox(
                              alignment: Alignment.centerLeft,
                              maxWidth: double.infinity,
                              child: Transform.translate(
                                offset: Offset(-offset, 0),
                                child: child,
                              ),
                            );
                          },
                          child: row(
                            widget.scrollableHeaders,
                            widget.scrollableColumnWidths,
                            widget.headerExtent,
                            background: const Color(0xff17303e),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: frozenWidth,
                      child: ClipRect(
                        child: ListView.builder(
                          key: _scrollKey('frozen'),
                          controller: _frozenVertical,
                          physics: const ClampingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          primary: false,
                          addRepaintBoundaries: false,
                          itemCount: widget.rowHeights.length,
                          itemExtent: fixedRowHeight,
                          itemExtentBuilder: fixedRowHeight == null
                              ? (index, dimensions) => widget.rowHeights[index]
                              : null,
                          itemBuilder: (context, index) => RepaintBoundary(
                            child: interactiveRow(
                              index,
                              row(
                                widget.frozenCells(index),
                                widget.frozenColumnWidths,
                                widget.rowHeights[index],
                                background: widget.selectedRowIndex == index
                                    ? const Color(0xff173f4c)
                                    : const Color(0xff0d2330),
                                strongTrailingBorder: true,
                              ),
                              exposeButtonSemantics: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _horizontal,
                        thumbVisibility: true,
                        scrollbarOrientation: ScrollbarOrientation.bottom,
                        child: SingleChildScrollView(
                          key: _scrollKey('horizontal'),
                          controller: _horizontal,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: SizedBox(
                            width: contentWidth,
                            child: Scrollbar(
                              controller: _vertical,
                              thumbVisibility: true,
                              child: ListView.builder(
                                key: _scrollKey('body'),
                                controller: _vertical,
                                physics: const ClampingScrollPhysics(),
                                padding: EdgeInsets.zero,
                                primary: false,
                                addRepaintBoundaries: false,
                                itemCount: widget.rowHeights.length,
                                itemExtent: fixedRowHeight,
                                itemExtentBuilder: fixedRowHeight == null
                                    ? (index, dimensions) =>
                                          widget.rowHeights[index]
                                    : null,
                                itemBuilder: (context, index) =>
                                    RepaintBoundary(
                                      child: interactiveRow(
                                        index,
                                        row(
                                          widget.scrollableCells(index),
                                          widget.scrollableRowWidths?.call(
                                                index,
                                              ) ??
                                              widget.scrollableColumnWidths,
                                          widget.rowHeights[index],
                                          background:
                                              widget.selectedRowIndex == index
                                              ? const Color(0xff173f4c)
                                              : Colors.transparent,
                                        ),
                                        exposeButtonSemantics: false,
                                      ),
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
      ),
    );
  }
}
