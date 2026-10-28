import '../theme/app_palette.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../widgets/top_notice.dart';

/// Shares completion notices between the workspace and its header slot.
class QuestCompletionDrawerHost extends StatefulWidget {
  const QuestCompletionDrawerHost({
    super.key,
    required this.child,
    this.controller,
    this.fullscreen = false,
    this.nativeQuestOverlay = false,
  });
  final Widget child;
  final TopNoticeController? controller;
  final bool fullscreen;
  final bool nativeQuestOverlay;

  static void show(
    BuildContext context,
    String message, {
    TopNoticeTone tone = TopNoticeTone.quest,
    IconData? icon,
    Color? color,
    Duration? duration,
    Duration appendWithin = Duration.zero,
  }) {
    context.getInheritedWidgetOfExactType<_DrawerScope>()?.controller.show(
      message: message,
      tone: tone,
      customIcon: icon,
      customColor: color,
      duration: duration ?? const Duration(seconds: 5),
      appendWithin: appendWithin,
    );
  }

  static void hide(BuildContext context) {
    context.getInheritedWidgetOfExactType<_DrawerScope>()?.controller.hide();
  }

  static void removeQuestNotices(BuildContext context) {
    context
        .getInheritedWidgetOfExactType<_DrawerScope>()
        ?.controller
        .removeByTone(TopNoticeTone.quest);
  }

  static Future<bool> showDamageControlNotice(
    BuildContext context,
    String message, {
    VoidCallback? onUnavailable,
    VoidCallback? onDismissed,
  }) async {
    if (!context.mounted) return false;
    final host = context.getInheritedWidgetOfExactType<_DrawerScope>()?.host;
    if (host == null) return false;
    return host._showDamageControlNotice(
      message,
      onUnavailable: onUnavailable,
      onDismissed: onDismissed,
    );
  }

  static void removeDamageControlNotice(BuildContext context) {
    if (!context.mounted) return;
    context
        .getInheritedWidgetOfExactType<_DrawerScope>()
        ?.host
        ._removeDamageControlNotice();
  }

  static VoidCallback? damageControlNoticeRemover(BuildContext context) {
    if (!context.mounted) return null;
    return context
        .dependOnInheritedWidgetOfExactType<_DrawerScope>()
        ?.host
        ._removeDamageControlNotice;
  }

  @override
  State<QuestCompletionDrawerHost> createState() =>
      _QuestCompletionDrawerHostState();
}

class _QuestCompletionDrawerHostState extends State<QuestCompletionDrawerHost> {
  static const _nativeChannel = MethodChannel(
    'app.yahagi.kancollebrowser/game_fullscreen',
  );
  static const _damageControlNoticeKey = 'damage-control';
  static const _nativeDamageControlTimeout = Duration(seconds: 2);
  static int _nextNativeDamageControlId = 0;
  late TopNoticeController _controller;
  final _damageControlController = TopNoticeController();
  late Listenable _noticeListenable;
  final _headerSlots = <_QuestCompletionHeaderSlotState>{};
  int _damageControlGeneration = 0;
  int? _damageControlConfirmedGeneration;
  VoidCallback? _damageControlUnavailable;
  VoidCallback? _damageControlDismissed;
  bool _damageControlMonitorScheduled = false;
  int _damageControlPresentationRevision = 0;
  int? _nativeDamageControlId;
  int? _nativeDamageControlConfirmedId;
  Timer? _nativeDamageControlMonitor;
  bool _nativeDamageControlCheckPending = false;
  bool _ownsController = false;
  Future<void> _nativeNoticeQueue = Future<void>.value();
  String? _lastNativeMessage;

  @override
  void initState() {
    super.initState();
    _damageControlController.addListener(_onDamageControlNoticeChanged);
    _attachController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncNativeNotice();
    });
  }

  void _attachController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TopNoticeController();
    _controller.addListener(_syncNativeNotice);
    _noticeListenable = Listenable.merge([
      _controller,
      _damageControlController,
    ]);
  }

  @override
  void didUpdateWidget(QuestCompletionDrawerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_syncNativeNotice);
      if (_ownsController) _controller.dispose();
      _attachController();
      _syncNativeNotice();
    }
    if (oldWidget.fullscreen != widget.fullscreen ||
        oldWidget.nativeQuestOverlay != widget.nativeQuestOverlay) {
      _syncNativeNotice();
      _reconcileDamageControlPresentation();
    }
  }

  bool get _usesNativeDamageControl =>
      widget.fullscreen && widget.nativeQuestOverlay;

  bool _damageControlDisplayAvailable(String message) =>
      mounted &&
      (_usesNativeDamageControl
          ? _nativeDamageControlId != null &&
                _nativeDamageControlId == _nativeDamageControlConfirmedId
          : _headerSlots.any((slot) => slot._canDisplayMessage(message)));

  void _clearNativeDamageControlNotice([int? noticeId]) {
    final id = noticeId ?? _nativeDamageControlId;
    if (id == null) return;
    if (id == _nativeDamageControlId) {
      _nativeDamageControlId = null;
      _nativeDamageControlConfirmedId = null;
      _nativeDamageControlMonitor?.cancel();
      _nativeDamageControlMonitor = null;
    }
    // Native clears match the id, so a late response from a removed host can
    // never dismiss a newer warning on the shared Activity bubble.
    unawaited(
      _nativeChannel
          .invokeMethod<bool>('damageControlNotice', {'message': '', 'id': id})
          .timeout(_nativeDamageControlTimeout)
          .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }

  Future<bool> _presentNativeDamageControlNotice(
    String message,
    int generation,
  ) async {
    _clearNativeDamageControlNotice();
    final id = ++_nextNativeDamageControlId;
    _nativeDamageControlId = id;
    var shown = false;
    try {
      final request = _nativeChannel.invokeMethod<bool>('damageControlNotice', {
        'message': message,
        'id': id,
      });
      unawaited(
        request.then<void>((_) {
          if (!mounted ||
              generation != _damageControlGeneration ||
              _nativeDamageControlId != id ||
              !_usesNativeDamageControl) {
            _clearNativeDamageControlNotice(id);
          }
        }, onError: (Object _, StackTrace _) {}),
      );
      shown = await request.timeout(_nativeDamageControlTimeout) == true;
    } catch (_) {
      // A missing/failed native overlay must retain the confirmation fallback.
    }
    if (!mounted ||
        generation != _damageControlGeneration ||
        _nativeDamageControlId != id ||
        !_usesNativeDamageControl ||
        _damageControlController.current == null) {
      _clearNativeDamageControlNotice(id);
      return false;
    }
    if (!shown) {
      _clearNativeDamageControlNotice(id);
      return false;
    }
    _nativeDamageControlConfirmedId = id;
    return true;
  }

  void _failDamageControlPresentation() {
    final onUnavailable = _damageControlUnavailable;
    _removeDamageControlNotice();
    onUnavailable?.call();
  }

  void _reconcileDamageControlPresentation() {
    if (_damageControlConfirmedGeneration != _damageControlGeneration ||
        _damageControlController.current == null) {
      return;
    }
    final generation = _damageControlGeneration;
    final revision = ++_damageControlPresentationRevision;
    _nativeDamageControlMonitor?.cancel();
    _nativeDamageControlMonitor = null;
    if (!_usesNativeDamageControl) _clearNativeDamageControlNotice();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          revision != _damageControlPresentationRevision ||
          generation != _damageControlGeneration ||
          _damageControlController.current == null) {
        return;
      }
      final message = _damageControlController.current!.message;
      final available = _usesNativeDamageControl
          ? await _presentNativeDamageControlNotice(message, generation)
          : _damageControlDisplayAvailable(message);
      if (!mounted ||
          revision != _damageControlPresentationRevision ||
          generation != _damageControlGeneration ||
          _damageControlController.current == null) {
        return;
      }
      if (!available) {
        _failDamageControlPresentation();
        return;
      }
      _monitorDamageControlDisplay();
    });
    // A header's existing monitor may request this handoff after the frame.
    // Explicitly schedule the next frame so its callback cannot be stranded.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _checkNativeDamageControlPresentation() async {
    if (_nativeDamageControlCheckPending || !_usesNativeDamageControl) return;
    final id = _nativeDamageControlId;
    final generation = _damageControlGeneration;
    if (id == null || _damageControlController.current == null) return;
    _nativeDamageControlCheckPending = true;
    var visible = false;
    try {
      visible =
          await _nativeChannel
              .invokeMethod<bool>('damageControlNoticeVisible', {'id': id})
              .timeout(_nativeDamageControlTimeout) ==
          true;
    } catch (_) {
      // Losing the Activity bubble is as unsafe as an unavailable header slot.
    } finally {
      _nativeDamageControlCheckPending = false;
    }
    if (!mounted ||
        !_usesNativeDamageControl ||
        id != _nativeDamageControlId ||
        generation != _damageControlGeneration ||
        _damageControlController.current == null) {
      return;
    }
    if (!visible) _failDamageControlPresentation();
  }

  Future<bool> _showDamageControlNotice(
    String message, {
    VoidCallback? onUnavailable,
    VoidCallback? onDismissed,
  }) async {
    if (message.isEmpty ||
        (!_usesNativeDamageControl &&
            !_damageControlDisplayAvailable(message))) {
      return false;
    }
    final generation = ++_damageControlGeneration;
    _damageControlConfirmedGeneration = null;
    _damageControlUnavailable = null;
    _damageControlDismissed = null;
    _clearNativeDamageControlNotice();
    _damageControlController.show(
      message: message,
      tone: TopNoticeTone.damageControl,
      duration: const Duration(seconds: 10),
      replacementKey: _damageControlNoticeKey,
      showIcon: false,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || generation != _damageControlGeneration) return false;
    var available = _usesNativeDamageControl
        ? await _presentNativeDamageControlNotice(message, generation)
        : _damageControlDisplayAvailable(message);
    if (!mounted || generation != _damageControlGeneration) return false;
    // Fullscreen can be exited while the native acknowledgement is pending.
    if (!_usesNativeDamageControl) {
      available = _damageControlDisplayAvailable(message);
    }
    if (!available) {
      _removeDamageControlNotice();
      return false;
    }
    if (_damageControlController.current?.replacementKey !=
        _damageControlNoticeKey) {
      return false;
    }
    _damageControlConfirmedGeneration = generation;
    _damageControlUnavailable = onUnavailable;
    _damageControlDismissed = onDismissed;
    _monitorDamageControlDisplay();
    return true;
  }

  void _onDamageControlNoticeChanged() {
    if (_damageControlController.current != null) return;
    _clearNativeDamageControlNotice();
    final onDismissed = _damageControlDismissed;
    _damageControlConfirmedGeneration = null;
    _damageControlUnavailable = null;
    _damageControlDismissed = null;
    onDismissed?.call();
  }

  void _monitorDamageControlDisplay() {
    if (_damageControlMonitorScheduled ||
        !mounted ||
        _damageControlConfirmedGeneration != _damageControlGeneration ||
        _damageControlController.current == null) {
      return;
    }
    if (_usesNativeDamageControl) {
      _nativeDamageControlMonitor ??= Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => unawaited(_checkNativeDamageControlPresentation()),
      );
      return;
    }
    _damageControlMonitorScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _damageControlMonitorScheduled = false;
      if (!mounted ||
          _damageControlConfirmedGeneration != _damageControlGeneration ||
          _damageControlController.current == null) {
        return;
      }
      if (_usesNativeDamageControl) {
        _reconcileDamageControlPresentation();
        return;
      }
      if (!_damageControlDisplayAvailable(
        _damageControlController.current!.message,
      )) {
        _failDamageControlPresentation();
        return;
      }
      _monitorDamageControlDisplay();
    });
  }

  void _removeDamageControlNotice() {
    if (!mounted) return;
    final generation = ++_damageControlGeneration;
    _damageControlPresentationRevision++;
    _clearNativeDamageControlNotice();
    _damageControlConfirmedGeneration = null;
    _damageControlUnavailable = null;
    _damageControlDismissed = null;
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _damageControlGeneration) return;
        _damageControlController.removeByKey(_damageControlNoticeKey);
      });
      return;
    }
    _damageControlController.removeByKey(_damageControlNoticeKey);
  }

  void _dismissDamageControlNotice(int id) {
    if (_damageControlController.current?.id == id) {
      final onDismissed = _damageControlDismissed;
      _removeDamageControlNotice();
      onDismissed?.call();
    }
  }

  void _syncNativeNotice() {
    if (!widget.nativeQuestOverlay) return;
    final notices = _controller.notices;
    final message = widget.fullscreen
        ? [
            // The native bubble has two lines: put the latest debuff first so
            // queued task messages cannot hide a newly detected game cue.
            ...notices.reversed
                .where((notice) => notice.tone == TopNoticeTone.debuff)
                .map((notice) => notice.message),
            ...notices
                .where((notice) => notice.tone == TopNoticeTone.quest)
                .map((notice) => notice.message),
          ].join('\n')
        : '';
    if (message == _lastNativeMessage) return;
    _lastNativeMessage = message;
    _nativeNoticeQueue = _nativeNoticeQueue.then((_) async {
      try {
        await _nativeChannel.invokeMethod<void>('questNotice', {
          'message': message,
        });
      } catch (_) {
        // Flutter's notice remains available outside the native game overlay.
      }
    });
  }

  @override
  void dispose() {
    _damageControlGeneration++;
    _damageControlPresentationRevision++;
    _clearNativeDamageControlNotice();
    _damageControlDismissed = null;
    _damageControlController.dispose();
    _controller.removeListener(_syncNativeNotice);
    if (widget.nativeQuestOverlay) {
      unawaited(
        _nativeNoticeQueue.then((_) async {
          try {
            await _nativeChannel.invokeMethod<void>('questNotice', {
              'message': '',
            });
          } catch (_) {}
        }),
      );
    }
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _DrawerScope(
    notifier: _noticeListenable,
    controller: _controller,
    damageControlController: _damageControlController,
    host: this,
    child: Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.fullscreen && !widget.nativeQuestOverlay)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 44,
            child: QuestCompletionHeaderSlot(child: SizedBox.shrink()),
          ),
      ],
    ),
  );
}

/// Uses the same header space as the toolbar beside the Yahagi brand button.
/// Task completion stays visible even while the game toolbar is expanded.
class QuestCompletionHeaderSlot extends StatefulWidget {
  const QuestCompletionHeaderSlot({
    super.key,
    required this.child,
    this.toolbarVisible = false,
  });
  final Widget child;
  final bool toolbarVisible;

  static IconData iconFor(TopNoticeData notice) {
    if (notice.customIcon != null) return notice.customIcon!;
    return switch (notice.tone) {
      TopNoticeTone.neutral => Icons.info_outline_rounded,
      TopNoticeTone.success => Icons.check_circle_outline_rounded,
      TopNoticeTone.error => Icons.error_outline_rounded,
      TopNoticeTone.warning => Icons.warning_amber_rounded,
      TopNoticeTone.info => Icons.insights_rounded,
      TopNoticeTone.quest => Icons.assignment_turned_in_outlined,
      TopNoticeTone.marriage => Icons.favorite_rounded,
      TopNoticeTone.damageControl => Icons.shield_outlined,
      TopNoticeTone.debuff => Icons.shield_outlined,
    };
  }

  static Color colorFor(TopNoticeData notice) {
    if (notice.customColor != null) return notice.customColor!;
    return switch (notice.tone) {
      TopNoticeTone.neutral => const Color(0xff8da4b5),
      TopNoticeTone.success => const Color(0xff34d399),
      TopNoticeTone.error => const Color(0xfff87171),
      TopNoticeTone.warning => const Color(0xfffbbf24),
      TopNoticeTone.info => const Color(0xff38bdf8),
      TopNoticeTone.quest => const Color(0xffd4a85f),
      TopNoticeTone.marriage => const Color(0xfff472b6),
      TopNoticeTone.damageControl => const Color(0xffd4a85f),
      TopNoticeTone.debuff => const Color(0xff34d399),
    };
  }

  @override
  State<QuestCompletionHeaderSlot> createState() =>
      _QuestCompletionHeaderSlotState();
}

class _QuestCompletionHeaderSlotState extends State<QuestCompletionHeaderSlot> {
  _QuestCompletionDrawerHostState? _host;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = context
        .dependOnInheritedWidgetOfExactType<_DrawerScope>()
        ?.host;
    if (host == _host) return;
    _host?._headerSlots.remove(this);
    _host = host;
    _host?._headerSlots.add(this);
  }

  bool _canDisplayMessage(String message) {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return false;
    var hidden = false;
    context.visitAncestorElements((element) {
      final ancestor = element.widget;
      if ((ancestor is Offstage && ancestor.offstage) ||
          (ancestor is Visibility && !ancestor.visible) ||
          (ancestor is Opacity && ancestor.opacity == 0) ||
          (ancestor is AnimatedOpacity && ancestor.opacity == 0) ||
          (ancestor is IgnorePointer && ancestor.ignoring) ||
          (ancestor is AbsorbPointer && ancestor.absorbing)) {
        hidden = true;
        return false;
      }
      return true;
    });
    final renderObject = context.findRenderObject();
    if (hidden ||
        renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        renderObject.size.height < _HeaderNoticeCapsule.height) {
      return false;
    }
    final defaultStyle = DefaultTextStyle.of(context);
    var textStyle = defaultStyle.style.merge(
      _HeaderNoticeCapsule.textStyleFor(context),
    );
    if (MediaQuery.boldTextOf(context)) {
      textStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
    }
    final painter = TextPainter(
      text: TextSpan(text: message, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
      textHeightBehavior: defaultStyle.textHeightBehavior,
    )..layout();
    final fits =
        !painter.didExceedMaxLines &&
        painter.width +
                2 *
                    (_HeaderNoticeCapsule.horizontalPadding +
                        _HeaderNoticeCapsule.borderWidth) <=
            renderObject.size.width &&
        painter.height + 2 * _HeaderNoticeCapsule.borderWidth <=
            _HeaderNoticeCapsule.height;
    painter.dispose();
    return fits;
  }

  @override
  void dispose() {
    _host?._headerSlots.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_DrawerScope>();
    final controller = scope?.controller;
    final notices = [
      ...?scope?.damageControlController.notices,
      ...?controller?.notices,
    ];
    final visible =
        notices.isNotEmpty &&
        (!widget.toolbarVisible ||
            notices.any(
              (notice) =>
                  notice.tone == TopNoticeTone.quest ||
                  notice.tone == TopNoticeTone.debuff ||
                  notice.tone == TopNoticeTone.damageControl,
            ));

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        IgnorePointer(
          ignoring: visible,
          child: AnimatedOpacity(
            opacity: visible ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: widget.child,
          ),
        ),
        IgnorePointer(
          ignoring: !visible,
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              reverseDuration: const Duration(milliseconds: 200),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.centerLeft,
                children: [?currentChild],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(-0.2, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              ),
              child: !visible
                  ? const SizedBox.shrink(key: ValueKey('header-notice-empty'))
                  : Semantics(
                      key: const Key('quest-completion-drawer'),
                      liveRegion: true,
                      button: true,
                      child: KeyedSubtree(
                        // Appending preserves position; a new batch starts at
                        // its first message instead of inheriting old offset.
                        key: ValueKey((notices.first.tone, notices.first.id)),
                        child: SingleChildScrollView(
                          key: const Key('header-notice-scroll'),
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (
                                var index = 0;
                                index < notices.length;
                                index++
                              ) ...[
                                if (index > 0) const SizedBox(width: 6),
                                _HeaderNoticeCapsule(
                                  notice: notices[index],
                                  onTap:
                                      notices[index].tone ==
                                          TopNoticeTone.damageControl
                                      ? () => scope?.host
                                            ._dismissDamageControlNotice(
                                              notices[index].id,
                                            )
                                      : controller?.hide,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderNoticeCapsule extends StatelessWidget {
  const _HeaderNoticeCapsule({required this.notice, this.onTap});

  static const height = 34.0;
  static const horizontalPadding = 10.0;
  static const borderWidth = 1.0;

  final TopNoticeData notice;
  final VoidCallback? onTap;

  static TextStyle textStyleFor(BuildContext context) => appTextStyle(
    context,
    TextStyle(
      fontSize: 13,
      color: appColor(context, const Color(0xffe0e6e9)),
      fontWeight: FontWeight.w600,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final color = QuestCompletionHeaderSlot.colorFor(notice);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: appColor(
            context,
            const Color(0xff0a1622).withValues(alpha: 0.92),
          ),
          border: Border.all(
            color: appColor(context, color.withValues(alpha: 0.35)),
            width: borderWidth,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (notice.showIcon) ...[
              Icon(
                QuestCompletionHeaderSlot.iconFor(notice),
                size: 16,
                color: appColor(context, color),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              notice.message,
              maxLines: 1,
              softWrap: false,
              style: textStyleFor(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerScope extends InheritedNotifier<Listenable> {
  const _DrawerScope({
    required super.notifier,
    required super.child,
    required this.controller,
    required this.damageControlController,
    required this.host,
  });

  final TopNoticeController controller;
  final TopNoticeController damageControlController;
  final _QuestCompletionDrawerHostState host;
}
