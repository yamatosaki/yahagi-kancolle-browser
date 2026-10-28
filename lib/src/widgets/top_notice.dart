import '../theme/app_palette.dart';
import 'dart:async';

import 'package:flutter/material.dart';

enum TopNoticeTone {
  neutral,
  success,
  error,
  warning,
  info,
  quest,
  marriage,
  damageControl,
  debuff,
}

const topNoticeKey = Key('top-notice');
const topNoticeTextKey = Key('top-notice-text');

@immutable
class TopNoticeData {
  const TopNoticeData({
    required this.id,
    required this.message,
    required this.tone,
    this.customIcon,
    this.customColor,
    this.replacementKey,
    this.showIcon = true,
  });

  final int id;
  final String message;
  final TopNoticeTone tone;
  final IconData? customIcon;
  final Color? customColor;
  final String? replacementKey;
  final bool showIcon;
}

class TopNoticeController extends ChangeNotifier {
  TopNoticeData? get current => _notices.isEmpty ? null : _notices.last;
  List<TopNoticeData> get notices => List.unmodifiable(_notices);

  final List<TopNoticeData> _notices = [];
  DateTime? _batchStartedAt;
  Timer? _timer;
  final Map<int, Timer> _noticeTimers = {};
  int _nextId = 0;

  static bool _hasOwnDeadline(TopNoticeTone tone) =>
      tone == TopNoticeTone.quest || tone == TopNoticeTone.debuff;

  void show({
    required String message,
    TopNoticeTone tone = TopNoticeTone.neutral,
    Duration duration = const Duration(seconds: 4),
    IconData? customIcon,
    Color? customColor,
    Duration appendWithin = Duration.zero,
    String? replacementKey,
    bool showIcon = true,
  }) {
    _timer?.cancel();
    final now = DateTime.now();
    final append =
        _notices.isNotEmpty &&
        (replacementKey != null ||
            (appendWithin > Duration.zero &&
                _batchStartedAt != null &&
                now.difference(_batchStartedAt!) <= appendWithin));
    final id = _nextId++;
    final notice = TopNoticeData(
      id: id,
      message: message,
      tone: tone,
      customIcon: customIcon,
      customColor: customColor,
      replacementKey: replacementKey,
      showIcon: showIcon,
    );
    if (append) {
      if (replacementKey != null) {
        _removeWhere((notice) => notice.replacementKey == replacementKey);
      }
    } else {
      // Quest and debuff alerts keep their own deadlines while routine notices
      // replace each other. A new quest still starts a fresh quest batch.
      _removeWhere(
        (notice) =>
            !_hasOwnDeadline(notice.tone) ||
            (tone == TopNoticeTone.quest && notice.tone == TopNoticeTone.quest),
      );
      _batchStartedAt = now;
    }
    _notices.add(notice);
    if (_hasOwnDeadline(tone)) {
      _noticeTimers[id] = Timer(duration, () {
        _noticeTimers.remove(id);
        if (!_removeWhere((notice) => notice.id == id)) return;
        _resetEmptyBatch();
        notifyListeners();
      });
    }
    notifyListeners();
    _timer = Timer(duration, () {
      if (_notices.isEmpty || _nextId != id + 1) {
        return;
      }
      _timer = null;
      if (!_removeWhere((notice) => !_hasOwnDeadline(notice.tone))) return;
      _resetEmptyBatch();
      notifyListeners();
    });
  }

  /// Removes a live-updating notice without dismissing unrelated messages.
  void removeByKey(String replacementKey) {
    if (!_removeWhere((notice) => notice.replacementKey == replacementKey)) {
      return;
    }
    _resetEmptyBatch();
    notifyListeners();
  }

  void removeByTone(TopNoticeTone tone) {
    if (!_removeWhere((notice) => notice.tone == tone)) return;
    _resetEmptyBatch();
    notifyListeners();
  }

  bool _removeWhere(bool Function(TopNoticeData) shouldRemove) {
    final oldLength = _notices.length;
    _notices.removeWhere((notice) {
      if (!shouldRemove(notice)) return false;
      _noticeTimers.remove(notice.id)?.cancel();
      return true;
    });
    return _notices.length != oldLength;
  }

  void _resetEmptyBatch() {
    if (_notices.isEmpty) {
      _timer?.cancel();
      _timer = null;
      _batchStartedAt = null;
    }
  }

  void hide() {
    _timer?.cancel();
    _timer = null;
    if (!_removeWhere((_) => true)) return;
    _batchStartedAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    for (final timer in _noticeTimers.values) {
      timer.cancel();
    }
    _noticeTimers.clear();
    super.dispose();
  }
}

abstract final class TopNotice {
  static void show(
    BuildContext context, {
    required String message,
    TopNoticeTone tone = TopNoticeTone.neutral,
    Duration duration = const Duration(seconds: 4),
    bool showIcon = true,
  }) {
    _controllerOf(context)?.show(
      message: message,
      tone: tone,
      duration: duration,
      showIcon: showIcon,
    );
  }

  static void hide(BuildContext context) {
    _controllerOf(context)?.hide();
  }

  static TopNoticeController? _controllerOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_TopNoticeScope>();
    assert(
      scope != null,
      'TopNotice requires a TopNoticeHost above the supplied BuildContext.',
    );
    return scope?.notifier;
  }
}

class TopNoticeHost extends StatefulWidget {
  const TopNoticeHost({super.key, required this.child});

  final Widget child;

  @override
  State<TopNoticeHost> createState() => _TopNoticeHostState();
}

class _TopNoticeHostState extends State<TopNoticeHost> {
  late final TopNoticeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TopNoticeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TopNoticeScope(
      notifier: _controller,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final notice = _controller.current;
              return Positioned(
                top: MediaQuery.paddingOf(context).top + 4,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 720,
                        minHeight: 36,
                        maxHeight: 36,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        reverseDuration: const Duration(milliseconds: 140),
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: Alignment.topCenter,
                            children: notice == null
                                ? [...previousChildren, ?currentChild]
                                : [?currentChild],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            alwaysIncludeSemantics: true,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, -0.25),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: notice == null
                            ? const SizedBox.shrink(
                                key: ValueKey('top-notice-empty'),
                              )
                            : _NoticeCapsule(
                                key: const ValueKey('top-notice-visible'),
                                notice: notice,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopNoticeScope extends InheritedNotifier<TopNoticeController> {
  const _TopNoticeScope({required super.notifier, required super.child});
}

class _NoticeCapsule extends StatelessWidget {
  const _NoticeCapsule({super.key, required this.notice});

  final TopNoticeData notice;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(notice.tone);
    final foreground = notice.customColor ?? palette.foreground;
    final icon = notice.customIcon ?? palette.icon;
    return Semantics(
      key: topNoticeKey,
      container: true,
      liveRegion: true,
      label: notice.message,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: appColor(context, palette.background),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: appColor(context, palette.border)),
              boxShadow: [
                BoxShadow(
                  color: appColor(context, Colors.black45),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (notice.showIcon) ...[
                    Icon(icon, size: 20, color: appColor(context, foreground)),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      notice.message,
                      key: topNoticeTextKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appTextStyle(
                        context,
                        TextStyle(
                          color: foreground,
                          fontSize: 14,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

_TopNoticePalette _paletteFor(TopNoticeTone tone) {
  return switch (tone) {
    TopNoticeTone.neutral => const _TopNoticePalette(
      background: Color(0xff1a3447),
      border: Color(0xff3c586b),
      foreground: Colors.white,
      icon: Icons.info_outline_rounded,
    ),
    TopNoticeTone.success => const _TopNoticePalette(
      background: Color(0xff173d3b),
      border: Color(0xff4fa79b),
      foreground: Color(0xffb9f1e8),
      icon: Icons.check_circle_outline_rounded,
    ),
    TopNoticeTone.error => const _TopNoticePalette(
      background: Color(0xff54292d),
      border: Color(0xff9b464c),
      foreground: Color(0xffffaaa4),
      icon: Icons.error_outline_rounded,
    ),
    TopNoticeTone.warning => const _TopNoticePalette(
      background: Color(0xff3d3217),
      border: Color(0xffa78b4f),
      foreground: Color(0xfffde68a),
      icon: Icons.warning_amber_rounded,
    ),
    TopNoticeTone.info => const _TopNoticePalette(
      background: Color(0xff132b3d),
      border: Color(0xff388ab8),
      foreground: Color(0xffbae6fd),
      icon: Icons.insights_rounded,
    ),
    TopNoticeTone.quest => const _TopNoticePalette(
      background: Color(0xff2d2417),
      border: Color(0xffa7874f),
      foreground: Color(0xfff7e2ba),
      icon: Icons.assignment_turned_in_outlined,
    ),
    TopNoticeTone.marriage => const _TopNoticePalette(
      background: Color(0xff3d172e),
      border: Color(0xffb83889),
      foreground: Color(0xfffbcfe8),
      icon: Icons.favorite_rounded,
    ),
    TopNoticeTone.damageControl => const _TopNoticePalette(
      background: Color(0xff2d2417),
      border: Color(0xffa7874f),
      foreground: Color(0xfff7e2ba),
      icon: Icons.shield_outlined,
    ),
    TopNoticeTone.debuff => const _TopNoticePalette(
      background: Color(0xff173d3b),
      border: Color(0xff4fa79b),
      foreground: Color(0xffb9f1e8),
      icon: Icons.shield_outlined,
    ),
  };
}

@immutable
class _TopNoticePalette {
  const _TopNoticePalette({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}
