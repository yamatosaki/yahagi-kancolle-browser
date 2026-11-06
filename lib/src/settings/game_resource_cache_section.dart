import 'dart:async';

import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/game_resource_cache_channel.dart';
import '../browser/game_resource_cache_controller.dart';
import '../browser/game_resource_cache_store.dart';
import '../widgets/top_notice.dart';
import 'settings_ui_helpers.dart';

class GameResourceCacheSection extends StatefulWidget {
  const GameResourceCacheSection({super.key, required this.controller});

  final GameResourceCacheController controller;

  @override
  State<GameResourceCacheSection> createState() =>
      _GameResourceCacheSectionState();
}

class _GameResourceCacheSectionState extends State<GameResourceCacheSection>
    with WidgetsBindingObserver {
  bool _integrityChecked = false;
  bool _tickerEnabled = true;
  bool _foreground = true;
  bool _visible = false;
  bool _visibilityInitialized = false;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground =
        state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _syncVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _syncVisibility();
  }

  void _syncVisibility() {
    final initialized = _visibilityInitialized;
    _visibilityInitialized = true;
    final visible = _foreground && _tickerEnabled;
    if (_visible == visible) return;
    _visible = visible;
    widget.controller.setPageVisible(visible);
    // Retained settings tabs must catch up immediately when shown again.
    // This only controls idle UI polling; running downloads keep their clock.
    if (visible && initialized) unawaited(widget.controller.refresh());
  }

  @override
  void didUpdateWidget(GameResourceCacheSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.setPageVisible(false);
    widget.controller.setPageVisible(_visible);
    if (_visible) unawaited(widget.controller.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.setPageVisible(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final status = controller.status;
        final isFullCache = controller.mode == GameResourceCacheMode.full;
        final hasIntegrityIssues =
            status.missingCount > 0 ||
            status.damagedCount > 0 ||
            status.outdatedCount > 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _modeTile(
              mode: GameResourceCacheMode.temporary,
              title: l10n.gameResourceCacheNone,
              subtitle: l10n.gameResourceCacheNoneDesc,
            ),
            Divider(color: appColor(context, Color(0xff294052)), height: 1),
            _modeTile(
              mode: GameResourceCacheMode.full,
              title: l10n.gameResourceCacheFull,
              subtitle: l10n.gameResourceCacheFullDesc,
            ),
            if (!status.supported)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.gameResourceCacheUnsupported,
                  style: TextStyle(color: appColor(context, Color(0xffffb4a9))),
                ),
              ),
            if (!controller.initialized || status.policyError)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.gameResourceCacheUnavailable,
                  style: TextStyle(color: appColor(context, Color(0xffffb4a9))),
                ),
              ),
            if (isFullCache && controller.manifestError)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.gameResourceCacheManifestFailed,
                  style: TextStyle(color: appColor(context, Color(0xffffb4a9))),
                ),
              ),
            Divider(color: appColor(context, Color(0xff294052)), height: 1),
            if (isFullCache && status.capacityBlocked)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.gameResourceCacheCapacityBlocked,
                  style: TextStyle(color: appColor(context, Color(0xffffb4a9))),
                ),
              ),
            if (isFullCache && status.waitingForWifi)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.gameResourceCacheWaitingForWifi,
                  style: TextStyle(color: appColor(context, Color(0xff9bc7e4))),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    l10n.gameResourceCacheStoredSize(
                      controller.completenessLine,
                    ),
                    key: const Key('cache-completeness-line'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isFullCache)
                    FilledButton.icon(
                      key: const Key('cache-download-toggle'),
                      onPressed: !controller.initialized || controller.busy
                          ? null
                          : () =>
                                status.state ==
                                    GameResourceCacheState.downloading
                                ? _run(controller.pauseDownload)
                                : _confirmDownload(l10n),
                      icon: Icon(
                        status.state == GameResourceCacheState.downloading
                            ? Icons.pause
                            : Icons.download,
                      ),
                      label: Text(switch (status.state) {
                        GameResourceCacheState.downloading =>
                          l10n.gameResourceCachePause,
                        GameResourceCacheState.paused =>
                          l10n.gameResourceCacheResume,
                        _ => l10n.gameResourceCacheStart,
                      }),
                    ),
                  if (isFullCache)
                    OutlinedButton.icon(
                      key: const Key('cache-check-integrity'),
                      onPressed: !controller.initialized || controller.busy
                          ? null
                          : _checkIntegrity,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(l10n.gameResourceCacheCheck),
                    ),
                  if (isFullCache &&
                      _integrityChecked &&
                      (status.missingCount > 0 ||
                          status.damagedCount > 0 ||
                          status.outdatedCount > 0))
                    OutlinedButton.icon(
                      key: const Key('cache-repair'),
                      onPressed: !controller.initialized || controller.busy
                          ? null
                          : () => _confirmRepair(l10n),
                      icon: const Icon(Icons.build_outlined),
                      label: Text(l10n.gameResourceCacheRepair),
                    ),
                  TextButton.icon(
                    key: const Key('cache-clear'),
                    onPressed: !controller.initialized || controller.busy
                        ? null
                        : () => _confirmClear(l10n),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.gameResourceCacheClear),
                  ),
                ],
              ),
            ),
            if (isFullCache && _integrityChecked && hasIntegrityIssues)
              Container(
                key: const Key('cache-integrity-result'),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: appColor(context, Color(0xff152d3b)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: appColor(context, Color(0xff294f63)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.gameResourceCacheIntegritySummary(
                        status.missingCount,
                        status.damagedCount,
                        status.outdatedCount,
                      ),
                    ),
                    if (status.outdatedCount > 0) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        l10n.gameResourceCachePendingRetained,
                        style: TextStyle(
                          color: appColor(context, Color(0xff9bc7e4)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _modeTile({
    required GameResourceCacheMode mode,
    required String title,
    required String subtitle,
  }) {
    final selected =
        widget.controller.initialized && widget.controller.mode == mode;
    return InkWell(
      key: Key('cache-mode-${mode.name}'),
      onTap:
          !widget.controller.initialized ||
              widget.controller.busy ||
              selected ||
              (!widget.controller.status.supported &&
                  mode == GameResourceCacheMode.full)
          ? null
          : () => _run(() => widget.controller.setMode(mode)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: appTextStyle(context, SettingsTileTypography.title),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: appTextStyle(
                      context,
                      SettingsTileTypography.description,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: appColor(
                context,
                selected ? const Color(0xff70c7bc) : const Color(0xff8197a5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkIntegrity() async {
    try {
      await widget.controller.checkIntegrity();
      if (mounted) setState(() => _integrityChecked = true);
    } catch (_) {
      _showFailure();
    }
  }

  Future<void> _confirmDownload(AppLocalizations l10n) async {
    final isMetered = widget.controller.status.isMetered;
    final confirmed = await _confirm(
      title: l10n.gameResourceCacheDownloadConfirmTitle,
      description: isMetered
          ? l10n.gameResourceCacheMobileConfirmDesc
          : l10n.gameResourceCacheDownloadConfirmDesc,
      confirmLabel: l10n.confirm,
    );
    if (confirmed) {
      await _run(
        () => widget.controller.startDownload(allowMetered: isMetered),
      );
    }
  }

  Future<void> _confirmRepair(AppLocalizations l10n) async {
    final isMetered = widget.controller.status.isMetered;
    if (isMetered) {
      final confirmed = await _confirm(
        title: l10n.gameResourceCacheDownloadConfirmTitle,
        description: l10n.gameResourceCacheMobileConfirmDesc,
        confirmLabel: l10n.confirm,
      );
      if (!confirmed) return;
    }
    await _run(() => widget.controller.repair(allowMetered: isMetered));
  }

  Future<void> _confirmClear(AppLocalizations l10n) async {
    final confirmed = await _confirm(
      title: l10n.gameResourceCacheClearConfirmTitle,
      description: l10n.gameResourceCacheClearConfirmDesc,
      confirmLabel: l10n.gameResourceCacheClear,
    );
    if (confirmed) {
      await _run(widget.controller.clear);
      if (mounted) setState(() => _integrityChecked = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String description,
    required String confirmLabel,
  }) async =>
      await showDialog<bool>(
        barrierDismissible: false,
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                (AppLocalizations.of(context) ??
                        lookupAppLocalizations(const Locale('zh')))
                    .cancel,
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _run(Future<bool> Function() action) async {
    try {
      if (!await action()) _showFailure();
    } catch (_) {
      _showFailure();
    }
  }

  void _showFailure() {
    if (!mounted) return;
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    TopNotice.show(
      context,
      message: l10n.gameResourceCacheActionFailed,
      tone: TopNoticeTone.error,
    );
  }
}
