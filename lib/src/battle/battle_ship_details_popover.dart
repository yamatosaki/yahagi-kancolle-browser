import '../theme/app_palette.dart';
import '../localization/game_name_localizations.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../fleet/equipment_type_icon.dart';
import '../fleet/fleet_ui_strings.dart';
import '../browser/game_workspace_visibility.dart';
import '../game_state/game_state.dart';
import 'battle_models.dart';
import 'battle_detail_strings.dart';
import 'battle_ship_details.dart';

/// One shared, nonmodal popover for all ships in a displayed battle panel.
class BattleShipDetailsHost extends StatefulWidget {
  const BattleShipDetailsHost({
    super.key,
    required this.battle,
    required this.child,
    this.latestGameState,
  });

  final LiveBattle battle;
  final Widget child;
  final GameState Function()? latestGameState;

  @override
  State<BattleShipDetailsHost> createState() => _BattleShipDetailsHostState();
}

class _BattleShipDetailsHostState extends State<BattleShipDetailsHost>
    with WidgetsBindingObserver {
  final _portal = OverlayPortalController();
  final _focus = FocusNode();
  BattleShipSnapshot? _selected;
  Rect _anchor = Rect.zero;
  Rect? _viewport;
  ScrollPosition? _scroll;
  LocalHistoryEntry? _history;
  BuildContext? _rowContext;
  BuildContext? _viewportContext;
  int _selectionRevision = 0;

  void _afterSelectionFrame(VoidCallback action) {
    final revision = _selectionRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selected != null && revision == _selectionRevision) {
        action();
      }
    });
  }

  Rect? _rectInOverlay(BuildContext? target) {
    if (target == null || !target.mounted) return null;
    final box = target.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox ||
        overlay is! RenderBox ||
        !box.attached ||
        !overlay.attached ||
        !box.hasSize ||
        !overlay.hasSize) {
      return null;
    }
    final origin = overlay.globalToLocal(box.localToGlobal(Offset.zero));
    final rect = origin & box.size;
    return rect.isFinite ? rect : null;
  }

  String? get selection => _selected == null ? null : _identity(_selected!);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(BattleShipDetailsHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && oldWidget.battle != widget.battle) {
      // A new node/phase must not leave the old fleet's details on screen.
      _afterSelectionFrame(_close);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workspaceActive = GameWorkspaceActive.of(context);
    final routeActive = ModalRoute.isCurrentOf(context) ?? true;
    if (_selected != null && (!workspaceActive || !routeActive)) {
      _afterSelectionFrame(_close);
    }
  }

  @override
  void didChangeMetrics() => _close();

  void _detach() {
    _scroll?.removeListener(_close);
    _scroll = null;
    final history = _history;
    _history = null;
    history?.remove();
  }

  void _close() {
    if (!mounted || _selected == null) return;
    _selected = null;
    _selectionRevision++;
    _rowContext = null;
    _viewportContext = null;
    _portal.hide();
    _detach();
    setState(() {});
  }

  void _toggle(BuildContext rowContext, BattleShipSnapshot ship) {
    if (selection == _identity(ship)) {
      _close();
      return;
    }
    final anchor = _rectInOverlay(rowContext);
    if (anchor == null) return;
    _detach();
    _selectionRevision++;
    _rowContext = rowContext;
    _anchor = anchor;
    final scrollable = Scrollable.maybeOf(rowContext);
    _viewportContext = scrollable?.context;
    _viewport = _rectInOverlay(_viewportContext);
    _scroll = scrollable?.position;
    _scroll?.addListener(_close);
    final route = ModalRoute.of(rowContext);
    if (route != null) {
      _history = LocalHistoryEntry(
        onRemove: () {
          _history = null;
          _close();
        },
      );
      route.addLocalHistoryEntry(_history!);
    }
    final latest = widget.latestGameState?.call();
    setState(
      () => _selected = latest == null
          ? ship
          : ship.withLatestFriendlyProficiency(latest),
    );
    _portal.show();
    _afterSelectionFrame(_focus.requestFocus);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _selected = null;
    _detach();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      // Resizing/moving the panel need not produce window metrics or scrolling.
      // Check after layout and dismiss coordinates captured for the old panel.
      _afterSelectionFrame(() {
        if (_rectInOverlay(_rowContext) != _anchor ||
            _rectInOverlay(_viewportContext) != _viewport) {
          _close();
        }
      });
    }
    return _DetailsScope(
      owner: this,
      selection: selection,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) {
          final ship = _selected;
          if (ship == null) return const SizedBox.shrink();
          // Positioning uses overlay coordinates, so use the overlay's safe
          // area too. The panel may sit below a SafeArea that consumed padding.
          final media = MediaQuery.of(Overlay.of(context).context);
          // Keep the card's shadow inside the information panel too.
          return ClipRect(
            clipper: _PopoverViewportClipper(_viewport),
            child: CustomSingleChildLayout(
              delegate: _PopoverPosition(
                anchor: _anchor,
                insets: media.padding + media.viewInsets,
                viewport: _viewport,
              ),
              child: TapRegion(
                groupId: this,
                onTapOutside: (_) => _close(),
                child: Focus(
                  focusNode: _focus,
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      _close();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: _ShipPopover(
                    key: ValueKey(_identity(ship)),
                    ship: ship,
                    onClose: _close,
                  ),
                ),
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

String _identity(BattleShipSnapshot ship) =>
    '${ship.side.name}-${ship.fleetRole.name}-${ship.position}';

class _DetailsScope extends InheritedWidget {
  const _DetailsScope({
    required this.owner,
    required this.selection,
    required super.child,
  });
  final _BattleShipDetailsHostState owner;
  final String? selection;

  @override
  bool updateShouldNotify(_DetailsScope oldWidget) =>
      selection != oldWidget.selection;
}

/// Wraps the existing row without changing its layout or HP animations.
class BattleShipDetailsTap extends StatelessWidget {
  const BattleShipDetailsTap({
    super.key,
    required this.ship,
    required this.child,
  });
  final BattleShipSnapshot ship;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DetailsScope>();
    if (scope == null) return child;
    final selected = scope.selection == _identity(ship);
    final color = ship.side == BattleSide.enemy
        ? const Color(0xffff907e)
        : const Color(0xff70c7bc);
    return TapRegion(
      groupId: scope.owner,
      child: Semantics(
        selected: selected,
        child: Material(
          color: appColor(
            context,
            selected ? color.withValues(alpha: .13) : Colors.transparent,
          ),
          child: InkWell(
            onTap: () => scope.owner._toggle(context, ship),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: appColor(
                      context,
                      selected ? color : Colors.transparent,
                    ),
                    width: 2,
                  ),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _PopoverViewportClipper extends CustomClipper<Rect> {
  const _PopoverViewportClipper(this.viewport);

  final Rect? viewport;

  @override
  Rect getClip(Size size) => viewport ?? (Offset.zero & size);

  @override
  bool shouldReclip(_PopoverViewportClipper oldClipper) =>
      viewport != oldClipper.viewport;
}

class _PopoverPosition extends SingleChildLayoutDelegate {
  const _PopoverPosition({
    required this.anchor,
    required this.insets,
    this.viewport,
  });
  final Rect anchor;
  final EdgeInsets insets;
  final Rect? viewport;

  Rect _bounds(Size size) {
    final safe = Rect.fromLTRB(
      insets.left + 8,
      insets.top + 8,
      math.max(insets.left + 8, size.width - insets.right - 8),
      math.max(insets.top + 8, size.height - insets.bottom - 8),
    );
    // The adjacent Android game WebView can draw above Flutter. Keep the
    // popover inside the information panel's scroll viewport when present.
    final panel = viewport;
    final bounds = panel == null ? safe : safe.intersect(panel.deflate(8));
    return Rect.fromLTWH(
      bounds.left,
      bounds.top,
      math.max(0, bounds.width),
      math.max(0, bounds.height),
    );
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final bounds = _bounds(constraints.biggest);
    final width = math.min(270.0, bounds.width);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: bounds.height,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final bounds = _bounds(size);
    const gap = 8.0;
    double x;
    double y;
    if (anchor.right + gap + childSize.width <= bounds.right) {
      x = anchor.right + gap;
      y = anchor.top;
    } else if (anchor.left - gap - childSize.width >= bounds.left) {
      x = anchor.left - gap - childSize.width;
      y = anchor.top;
    } else {
      x = anchor.center.dx - childSize.width / 2;
      y = anchor.bottom + gap;
      if (y + childSize.height > bounds.bottom &&
          anchor.top - gap - childSize.height >= bounds.top) {
        y = anchor.top - gap - childSize.height;
      }
    }
    return Offset(
      x.clamp(
        bounds.left,
        math.max(bounds.left, bounds.right - childSize.width),
      ),
      y.clamp(
        bounds.top,
        math.max(bounds.top, bounds.bottom - childSize.height),
      ),
    );
  }

  @override
  bool shouldRelayout(_PopoverPosition oldDelegate) =>
      anchor != oldDelegate.anchor ||
      insets != oldDelegate.insets ||
      viewport != oldDelegate.viewport;
}

class _ShipPopover extends StatefulWidget {
  const _ShipPopover({super.key, required this.ship, required this.onClose});
  final BattleShipSnapshot ship;
  final VoidCallback onClose;

  @override
  State<_ShipPopover> createState() => _ShipPopoverState();
}

class _ShipPopoverState extends State<_ShipPopover> {
  // The ancestor card stores its mode as a String in PageStorage. A transient
  // popover must neither restore that value as a scroll offset nor overwrite it.
  final _scrollController = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ship = widget.ship;
    final onClose = widget.onClose;
    final l =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final details = ship.details;
    final equipment = details?.equipment;
    final enemy = ship.side == BattleSide.enemy;
    final color = enemy ? const Color(0xffff907e) : const Color(0xff70c7bc);
    final strings = BattleDetailStrings.of(context);
    String number(int? value) => value?.toString() ?? '—';
    final labelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: appColor(context, Color(0xffa9bac4)),
    );
    final valueStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: appColor(context, Color(0xffe5ebee)),
    );
    final metaLabelStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: appColor(context, Color(0xffa9bac4)),
    );
    final metaValueStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: appColor(context, Color(0xffe5ebee)),
    );
    final remodelValue =
        details?.remodelShipId == 0 && details?.remodelLevel == 0
        ? fleetText(context, FleetUiKeys.noFurtherRemodel)
        : (details?.remodelShipId ?? 0) > 0 &&
              (details?.remodelLevel ?? 0) > 0 &&
              (details?.remodelName?.trim().isNotEmpty ?? false)
        ? 'Lv.${details!.remodelLevel} ${gameNames(context).shipName(details.remodelName!, shipId: details.remodelShipId)}'
        : fleetText(context, FleetUiKeys.dataIncomplete);
    Widget labeledValue(String label, String value) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: appTextStyle(context, enemy ? labelStyle : metaLabelStyle),
          ),
          TextSpan(
            text: value,
            style: appTextStyle(context, enemy ? valueStyle : metaValueStyle),
          ),
        ],
      ),
    );
    Widget supply(String label, String asset, int? value) => Semantics(
      label: '$label ${value == null ? '—' : '$value%'}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(asset, width: 14, height: 14),
            const SizedBox(width: 3),
            Text(
              value == null ? '—' : '$value%',
              style: appTextStyle(context, enemy ? valueStyle : metaValueStyle),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Material(
        key: const Key('battle-ship-details-popover'),
        color: appColor(context, const Color(0xff192f3d)),
        elevation: 14,
        shadowColor: appColor(context, Colors.black87),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: appColor(context, color.withValues(alpha: .55)),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: DefaultTextStyle(
          style: appTextStyle(
            context,
            (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                .copyWith(color: Color(0xffe5ebee), fontSize: 12, height: 1.25),
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            primary: false,
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                gameNames(
                                  context,
                                ).shipName(ship.name, shipId: ship.masterId),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (details?.enemyVariant case final variant?)
                                Text(
                                  variant,
                                  style: appTextStyle(
                                    context,
                                    TextStyle(
                                      fontSize: 12,
                                      color: appColor(
                                        context,
                                        Color(0xffffbe67),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('battle-ship-details-close'),
                      tooltip: l.close,
                      onPressed: onClose,
                      icon: Icon(
                        Icons.close,
                        size: 19,
                        color: appColor(context, Color(0xffa5bac4)),
                      ),
                      visualDensity: VisualDensity.compact,
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      constraints: const BoxConstraints.tightFor(
                        width: 22,
                        height: 22,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (!enemy)
                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(0.38),
                      1: FlexColumnWidth(0.62),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.top,
                    children: [
                      TableRow(
                        children: [
                          Align(
                            key: const Key('battle-ship-level'),
                            alignment: Alignment.centerLeft,
                            child: labeledValue('Lv.', number(details?.level)),
                          ),
                          Wrap(
                            key: const Key('battle-ship-fuel'),
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              supply(
                                l.fuel,
                                'assets/images/material/01.png',
                                details?.fuelPercent,
                              ),
                              supply(
                                l.ammo,
                                'assets/images/material/02.png',
                                details?.ammoPercent,
                              ),
                            ],
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4, right: 6),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Next ',
                                    style: appTextStyle(
                                      context,
                                      metaLabelStyle,
                                    ),
                                  ),
                                  TextSpan(
                                    text: number(details?.nextExperience),
                                    style: appTextStyle(
                                      context,
                                      metaValueStyle,
                                    ),
                                  ),
                                ],
                              ),
                              key: const Key('battle-ship-next'),
                              style: metaValueStyle,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '${fleetText(context, FleetUiKeys.remodel)}：',
                                    style: appTextStyle(
                                      context,
                                      metaLabelStyle,
                                    ),
                                  ),
                                  TextSpan(
                                    text: remodelValue,
                                    style: appTextStyle(
                                      context,
                                      metaValueStyle,
                                    ),
                                  ),
                                ],
                              ),
                              key: const Key('battle-ship-remodel'),
                              style: metaValueStyle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (enemy) labeledValue('ID', '${ship.masterId}'),
                      labeledValue('Lv.', number(details?.level)),
                      supply(
                        l.fuel,
                        'assets/images/material/01.png',
                        details?.fuelPercent,
                      ),
                      supply(
                        l.ammo,
                        'assets/images/material/02.png',
                        details?.ammoPercent,
                      ),
                    ],
                  ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: appColor(context, Color(0xff10232e)),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final stat in [
                        (l.firepower, details?.firepower),
                        (l.torpedo, details?.torpedo),
                        (l.antiAir, details?.antiAir),
                        (l.armor, details?.armor),
                      ])
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 3,
                            children: [
                              Text(
                                stat.$1,
                                textAlign: TextAlign.center,
                                style: appTextStyle(context, labelStyle),
                              ),
                              Text(
                                number(stat.$2),
                                style: appTextStyle(context, valueStyle),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                if (equipment == null)
                  Text(
                    strings.equipmentUnavailable,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, Color(0xff93aab8)),
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (equipment.isEmpty)
                  Text(
                    strings.noEquipment,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, Color(0xff93aab8)),
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  for (final item in equipment) _EquipmentRow(item: item),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EquipmentRow extends StatelessWidget {
  const _EquipmentRow({required this.item});
  final BattleEquipmentDetails item;

  @override
  Widget build(BuildContext context) {
    final l =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final strings = BattleDetailStrings.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          EquipmentTypeIconImage(iconId: item.iconId, width: 20, height: 20),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              (item.name == null
                      ? null
                      : gameNames(context).equipmentName(item.name!)) ??
                  (item.masterId == null
                      ? l.unknownEquip
                      : '${l.unknownEquip} #${item.masterId}'),
              style: appTextStyle(
                context,
                TextStyle(
                  color: appColor(context, Color(0xffe5ebee)),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (item.improvement > 0 || item.proficiency > 0 || item.extra) ...[
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.improvement > 0)
                  Text(
                    '★+${item.improvement}',
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, Color(0xff7bcba7)),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (item.proficiency > 0)
                  Semantics(
                    label: '${strings.proficiency} ${item.proficiency}',
                    child: Image.asset(
                      'assets/images/airplane/alv${item.proficiency.clamp(1, 7)}.png',
                      key: Key('battle-equipment-proficiency-${item.masterId}'),
                      width: 18,
                      height: 16,
                    ),
                  ),
                if (item.extra)
                  Text(
                    strings.expansionSlot,
                    style: appTextStyle(
                      context,
                      TextStyle(
                        color: appColor(context, Color(0xffa9bac4)),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
