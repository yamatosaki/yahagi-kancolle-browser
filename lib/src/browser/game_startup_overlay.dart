import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_palette.dart';

enum GameStartupStage { preparing, page, game }

@immutable
class GameStartupFailure {
  const GameStartupFailure(this.message, {this.host, this.code, this.help});

  final String message;
  final String? host;
  final String? code;
  final String? help;
}

class GameStartupOverlay extends StatefulWidget {
  const GameStartupOverlay({
    super.key,
    required this.stage,
    this.pageProgress,
    this.compact = false,
    this.requestCount,
    this.stalled = false,
    this.failure,
    this.onRetry,
    this.onRetryWithSystemNetwork,
    this.onClose,
    this.extra,
    this.statusText,
    this.retryKey,
    this.retryLabel,
    this.failureMessageKey,
    this.statusTextKey,
  });

  final GameStartupStage stage;
  final int? pageProgress;
  final bool compact;
  final int? requestCount;
  final bool stalled;
  final GameStartupFailure? failure;
  final VoidCallback? onRetry;
  final VoidCallback? onRetryWithSystemNetwork;
  final VoidCallback? onClose;
  final Widget? extra;
  final String? statusText;
  final Key? retryKey;
  final String? retryLabel;
  final Key? failureMessageKey;
  final Key? statusTextKey;

  @override
  State<GameStartupOverlay> createState() => _GameStartupOverlayState();
}

class _GameStartupOverlayState extends State<GameStartupOverlay> {
  static final _bareHost = RegExp(
    r'^(?:[A-Za-z0-9.-]+|\[[A-Fa-f0-9:.]+\])(?::[0-9]{1,5})?$',
  );
  static final _safeCode = RegExp(r'^[A-Za-z0-9_.:() +\-]{1,80}$');

  String? _copiedDetails;
  bool _copySucceeded = false;

  Future<void> _copyDetails(String details) async {
    var succeeded = false;
    try {
      await Clipboard.setData(ClipboardData(text: details));
      succeeded = true;
    } on PlatformException {
      // The visible details are still available as text.
    } on MissingPluginException {
      // Clipboard access is not available on this device.
    }
    if (mounted) {
      setState(() {
        _copiedDetails = details;
        _copySucceeded = succeeded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final failure = widget.failure;
    final compact = widget.compact && failure == null;
    final stalled = failure == null && widget.stalled;
    final detailRows = <(String, String)>[];
    if (failure != null) {
      detailRows.add((
        l10n.gameStartupStageLabel,
        _stepLabel(l10n, widget.stage),
      ));
      if (failure.host case final host?
          when host.length <= 260 && _bareHost.hasMatch(host)) {
        detailRows.add((l10n.gameStartupHostLabel, host));
      }
      if (failure.code case final code? when _safeCode.hasMatch(code)) {
        detailRows.add((l10n.gameStartupCodeLabel, code));
      }
    }
    final details = detailRows.map((row) => '${row.$1}: ${row.$2}').join('\n');
    final percentage = widget.stage == GameStartupStage.page && !compact
        ? widget.pageProgress?.clamp(0, 100)
        : null;
    final status =
        failure?.message ??
        (compact ? l10n.gameStartupLoadingResources : null) ??
        widget.statusText ??
        switch (widget.stage) {
          GameStartupStage.preparing => l10n.gameStartupPreparing,
          GameStartupStage.page => l10n.gameStartupPage,
          GameStartupStage.game => l10n.gameStartupLoadingGame,
        };
    final accent = appColor(context, const Color(0xff6fc3bd));
    final amber = appColor(context, const Color(0xfff0d088));
    final red = appColor(context, const Color(0xffffada1));
    final foreground = appColor(context, const Color(0xffe0eaf0));
    final muted = appColor(context, const Color(0xffa5b7be));
    final border = appColor(context, const Color(0xff3a515d));
    final tone = failure != null
        ? red
        : stalled
        ? amber
        : accent;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 360 : 452),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: appColor(context, const Color(0xff142735)),
              border: Border.all(
                color: failure != null || stalled
                    ? Color.lerp(border, tone, 0.45)!
                    : border,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 10 : 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!compact)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final stage in GameStartupStage.values)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: stage == widget.stage
                                          ? tone
                                          : stage.index < widget.stage.index
                                          ? accent
                                          : border,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _stepLabel(l10n, stage),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: stage == widget.stage
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: stage == widget.stage
                                          ? tone
                                          : muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (!compact) const SizedBox(height: 13),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!compact || stalled)
                        Icon(
                          failure != null
                              ? Icons.error_outline
                              : stalled
                              ? Icons.schedule
                              : Icons.hourglass_top,
                          color: tone,
                          size: 22,
                        ),
                      if (!compact || stalled) const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            status,
                            key: failure != null
                                ? widget.failureMessageKey
                                : widget.statusTextKey,
                            style: TextStyle(
                              color: failure == null ? foreground : tone,
                              fontSize: compact ? 14 : 17,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (failure == null && percentage != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$percentage%',
                          style: TextStyle(color: tone, fontSize: 13),
                        ),
                      ],
                      if (widget.requestCount case final count?
                          when compact) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.gameStartupResourceRequests(count),
                            textAlign: TextAlign.end,
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (stalled || failure?.help != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      failure?.help ?? l10n.gameStartupStalled,
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                  if (failure == null && (!stalled || percentage != null)) ...[
                    SizedBox(height: compact ? 7 : 11),
                    if (compact)
                      _ResourceProgressBar(color: tone, trackColor: border)
                    else
                      LinearProgressIndicator(
                        value: percentage == null ? null : percentage / 100,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(4),
                        color: tone,
                        backgroundColor: border,
                      ),
                  ],
                  if (failure != null)
                    ExpansionTile(
                      key: const Key('game-startup-connection-details'),
                      initiallyExpanded: true,
                      dense: true,
                      tilePadding: EdgeInsets.zero,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      textColor: foreground,
                      collapsedTextColor: foreground,
                      iconColor: muted,
                      collapsedIconColor: muted,
                      title: Text(
                        l10n.gameStartupConnectionDetails,
                        style: const TextStyle(fontSize: 13),
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: appColor(context, const Color(0xff0d1c25)),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Column(
                            children: [
                              for (final (label, value) in detailRows)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                            color: foreground,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (failure != null || stalled) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (widget.onRetry != null)
                          FilledButton(
                            key:
                                widget.retryKey ??
                                const Key('game-startup-retry'),
                            onPressed: widget.onRetry,
                            style: FilledButton.styleFrom(
                              backgroundColor: amber,
                              foregroundColor: AppPalette.of(context).isDark
                                  ? const Color(0xff261d10)
                                  : Colors.white,
                            ),
                            child: Text(widget.retryLabel ?? l10n.reloadGame),
                          ),
                        if (widget.onRetryWithSystemNetwork != null)
                          OutlinedButton(
                            onPressed: widget.onRetryWithSystemNetwork,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: foreground,
                              side: BorderSide(color: border),
                            ),
                            child: Text(l10n.retryWithSystemNetwork),
                          ),
                        if (failure != null)
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton(
                                onPressed: () => _copyDetails(details),
                                style: TextButton.styleFrom(
                                  foregroundColor: foreground,
                                ),
                                child: Text(l10n.gameStartupCopyDetails),
                              ),
                              if (widget.onClose case final onClose?)
                                TextButton(
                                  key: const Key('game-startup-close'),
                                  onPressed: onClose,
                                  style: TextButton.styleFrom(
                                    foregroundColor: foreground,
                                  ),
                                  child: Text(l10n.close),
                                ),
                            ],
                          ),
                      ],
                    ),
                    if (failure != null && _copiedDetails == details)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _copySucceeded
                              ? l10n.gameStartupDetailsCopied
                              : l10n.gameStartupCopyFailed,
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                  ],
                  if (widget.extra case final extra?) ...[
                    const SizedBox(height: 8),
                    extra,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _stepLabel(AppLocalizations l10n, GameStartupStage stage) =>
      switch (stage) {
        GameStartupStage.preparing => l10n.gameStartupPreparingStep,
        GameStartupStage.page => l10n.gameStartupPageStep,
        GameStartupStage.game => l10n.gameStartupGameStep,
      };
}

class _ResourceProgressBar extends StatefulWidget {
  const _ResourceProgressBar({required this.color, required this.trackColor});

  final Color color;
  final Color trackColor;

  @override
  State<_ResourceProgressBar> createState() => _ResourceProgressBarState();
}

class _ResourceProgressBarState extends State<_ResourceProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _position
        ..stop()
        ..value = 0.5;
    } else if (!_position.isAnimating) {
      _position.repeat();
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    role: SemanticsRole.loadingSpinner,
    child: RepaintBoundary(
      child: SizedBox(
        height: 4,
        width: double.infinity,
        child: CustomPaint(
          key: const Key('game-startup-resource-progress'),
          painter: _ResourceProgressPainter(
            position: _position,
            color: widget.color,
            trackColor: widget.trackColor,
          ),
        ),
      ),
    ),
  );
}

class _ResourceProgressPainter extends CustomPainter {
  _ResourceProgressPainter({
    required this.position,
    required this.color,
    required this.trackColor,
  }) : super(repaint: position);

  final Animation<double> position;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = trackColor,
    );
    final width = size.width * 0.28;
    final left = (size.width - width) * position.value;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, 0, width, size.height),
        radius,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ResourceProgressPainter oldDelegate) =>
      oldDelegate.position != position ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}
