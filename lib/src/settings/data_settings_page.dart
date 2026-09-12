import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../account/account_session.dart';

import '../battle/fcd_map_controller.dart';
import '../browser/game_browser_controller.dart';
import '../browser/game_resource_cache_controller.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/capture_mode_selector.dart';
import '../capture/game_capture_controller.dart';
import '../diagnostics/diagnostic_controller.dart';
import '../game_state/game_state_controller.dart';
import '../improvement/improvement_dataset_update_section.dart';
import '../improvement/improvement_planner_controller.dart';
import '../logbook/logbook_database.dart';
import '../prototype_status_controller.dart';
import '../quest/quest_catalog_controller.dart';
import '../senka/senka_controller.dart';
import '../kcwiki_report/kcwiki_report_settings.dart';
import '../widgets/top_notice.dart';
import '../widgets/adaptive_input_dialog.dart';
import 'diagnostic_user_section.dart';
import 'diagnostics_section.dart';
import 'fcd_map_update_section.dart';
import 'game_rendering_mode_controller.dart';
import 'game_resource_cache_section.dart';
import 'quest_catalog_update_section.dart';
import 'settings_ui_helpers.dart';

class DataSettingsPage extends StatelessWidget with SettingsUIHelpers {
  const DataSettingsPage({
    super.key,
    required this.captureModeController,
    required this.browserController,
    required this.gameCaptureController,
    required this.prototypeStatusController,
    required this.gameStateController,
    this.senkaController,
    this.gameResourceCacheController,
    this.kcwikiReportController,
    this.diagnosticController,
    this.showDeveloperDiagnostics = false,
    this.gameRenderingModeController,
    this.fcdMapController,
    this.questCatalogController,
    this.improvementPlannerController,
  });

  final CaptureModeController captureModeController;
  final GameBrowserController browserController;
  final GameCaptureController gameCaptureController;
  final PrototypeStatusController prototypeStatusController;
  final GameStateController gameStateController;
  final SenkaController? senkaController;
  final GameResourceCacheController? gameResourceCacheController;
  final KcwikiReportController? kcwikiReportController;
  final DiagnosticController? diagnosticController;
  final bool showDeveloperDiagnostics;
  final GameRenderingModeController? gameRenderingModeController;
  final FcdMapController? fcdMapController;
  final QuestCatalogController? questCatalogController;
  final ImprovementPlannerController? improvementPlannerController;

  AccountSession get _accountSession =>
      gameStateController.accountSession ?? LogbookDatabase.accountSession;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    return Container(
      color: const Color(0xff0d1a26),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            buildSectionTitle(l10n.logoutAndClear),
            buildCard(
              child: buildActionTile(
                title: l10n.logoutAndClear,
                titleKey: const Key('settings-logout-label'),
                subtitle: l10n.logoutAndClearDesc,
                trailing: const Icon(Icons.logout, color: Color(0xffd4a85f)),
                onTap: () => _logoutAndClear(context, l10n),
              ),
            ),
            const SizedBox(height: 24),
            buildSectionTitle(l10n.captureMode),
            buildCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: CaptureModeSelector(controller: captureModeController),
              ),
            ),
            if (kcwikiReportController case final controller?) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.kcwikiReportSection),
              buildCard(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => buildSwitchTile(
                    switchKey: const Key('kcwiki-report-switch'),
                    title: l10n.kcwikiReportTitle,
                    subtitle: _kcwikiReportSubtitle(l10n, controller),
                    value: controller.enabled,
                    onChanged: (enabled) => unawaited(
                      _setKcwikiReportEnabled(
                        context,
                        l10n,
                        controller,
                        enabled,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (diagnosticController case final diagnostics?) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.diagnosticLoggingSection),
              buildCard(
                child: Column(
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: diagnostics,
                      builder: (context, _) => buildSwitchTile(
                        switchKey: const Key('diagnosticLoggingSwitch'),
                        title: l10n.diagnosticLoggingTitle,
                        subtitle: l10n.diagnosticLoggingDesc,
                        value: diagnostics.enabled,
                        onChanged: diagnostics.setEnabled,
                      ),
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                    DiagnosticUserSection(controller: diagnostics),
                  ],
                ),
              ),
            ],
            if (showDeveloperDiagnostics) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.diagnosticsAndAbout),
              buildCard(
                child: DiagnosticsSection(
                  browserController: browserController,
                  captureModeController: captureModeController,
                  gameCaptureController: gameCaptureController,
                  prototypeStatusController: prototypeStatusController,
                  gameRenderingModeController: gameRenderingModeController,
                ),
              ),
            ],
            if (fcdMapController != null ||
                questCatalogController != null ||
                improvementPlannerController != null) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.fcdMapSectionTitle),
              buildCard(
                child: Column(
                  children: <Widget>[
                    if (fcdMapController case final controller?)
                      FcdMapUpdateSection(controller: controller),
                    if (fcdMapController != null &&
                        questCatalogController != null)
                      const Divider(height: 1),
                    if (questCatalogController case final controller?)
                      QuestCatalogUpdateSection(controller: controller),
                    if ((fcdMapController != null ||
                            questCatalogController != null) &&
                        improvementPlannerController != null)
                      const Divider(height: 1),
                    if (improvementPlannerController case final controller?)
                      ImprovementDatasetUpdateSection(controller: controller),
                  ],
                ),
              ),
            ],
            if (gameResourceCacheController case final controller?) ...<Widget>[
              const SizedBox(height: 24),
              buildSectionTitle(l10n.gameResourceCacheTitle),
              buildCard(
                child: GameResourceCacheSection(controller: controller),
              ),
            ],
            const SizedBox(height: 24),
            buildSectionTitle(l10n.storageAndCache),
            buildCard(
              child: Column(
                children: <Widget>[
                  if (senkaController case final controller?) ...<Widget>[
                    AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => buildActionTile(
                        key: const Key('settings-base-senka-summary'),
                        title: l10n.baseSenkaManualInputLabel,
                        subtitle: l10n.baseSenkaCurrentValue(
                          controller.monthBaseSenka.toStringAsFixed(2),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              key: const Key('settings-set-base-senka'),
                              tooltip: l10n.baseSenkaManualTitle,
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _setBaseSenka(context, l10n, controller),
                            ),
                            IconButton(
                              key: const Key('settings-reset-base-senka'),
                              tooltip: l10n.baseSenkaResetTitle,
                              icon: const Icon(Icons.restart_alt),
                              onPressed: () =>
                                  _resetBaseSenka(context, l10n, controller),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: Color(0xff294052), height: 1),
                  ],
                  buildActionTile(
                    key: const Key('settings-clear-quest-cache'),
                    title: l10n.clearQuestCache,
                    subtitle: l10n.clearQuestCacheDesc,
                    trailing: const Icon(Icons.delete_outline),
                    onTap: () async {
                      final session = _accountSession;
                      final scope = session.current;
                      await gameStateController.clearQuestsCache();
                      if (context.mounted && session.isCurrent(scope)) {
                        TopNotice.show(
                          context,
                          message: l10n.questCacheCleared,
                          tone: TopNoticeTone.success,
                        );
                      }
                    },
                  ),
                  const Divider(color: Color(0xff294052), height: 1),
                  buildActionTile(
                    key: const Key('settings-clear-logbook'),
                    title: l10n.clearLogbook,
                    subtitle: l10n.clearLogbookDesc,
                    trailing: const Icon(Icons.delete_forever_outlined),
                    onTap: () => _clearLogbook(context, l10n),
                  ),
                  const Divider(color: Color(0xff294052), height: 1),
                  buildActionTile(
                    key: const Key('settings-clear-web-cache'),
                    title: l10n.clearWebCache,
                    subtitle: l10n.clearWebCacheDesc,
                    trailing: const Icon(Icons.cleaning_services_outlined),
                    onTap: () => _clearWebCache(context, l10n),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _kcwikiReportSubtitle(
    AppLocalizations l10n,
    KcwikiReportController controller,
  ) {
    if (!controller.enabled) return l10n.kcwikiReportDisabledDesc;
    final status = controller.status;
    final time = status.occurredAt == null
        ? '—'
        : _formatKcwikiTime(status.occurredAt!.toLocal());
    final result = switch (status.activity) {
      KcwikiReportActivity.waiting => l10n.kcwikiReportWaiting,
      KcwikiReportActivity.processing => l10n.kcwikiReportProcessing(
        status.module ?? '—',
        time,
      ),
      KcwikiReportActivity.succeeded => l10n.kcwikiReportLastSuccess(
        status.module ?? '—',
        time,
        status.succeededCount,
        status.failedCount,
        status.droppedCount,
      ),
      KcwikiReportActivity.failed => l10n.kcwikiReportLastFailure(
        status.module ?? '—',
        _kcwikiFailureText(l10n, status),
        time,
        status.succeededCount,
        status.failedCount,
        status.droppedCount,
      ),
      KcwikiReportActivity.parseRecovered =>
        '${l10n.kcwikiReportParseRecovered(time)} · '
            '${l10n.kcwikiReportCounters(status.succeededCount, status.failedCount, status.droppedCount)}',
    };
    return '${l10n.kcwikiReportEnabledDesc}\n$result';
  }

  String _kcwikiFailureText(AppLocalizations l10n, KcwikiReportStatus status) =>
      switch (status.failure ?? KcwikiReportFailure.local) {
        KcwikiReportFailure.httpRejected => l10n.kcwikiReportFailureHttp(
          status.statusCode?.toString() ?? '—',
        ),
        KcwikiReportFailure.bodyTooLarge =>
          l10n.kcwikiReportFailureBodyTooLarge,
        KcwikiReportFailure.timeout => l10n.kcwikiReportFailureTimeout,
        KcwikiReportFailure.network => l10n.kcwikiReportFailureNetwork,
        KcwikiReportFailure.queueFull => l10n.kcwikiReportFailureQueueFull,
        KcwikiReportFailure.local => l10n.kcwikiReportFailureLocal,
      };

  String _formatKcwikiTime(DateTime value) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  Future<void> _setKcwikiReportEnabled(
    BuildContext context,
    AppLocalizations l10n,
    KcwikiReportController controller,
    bool enabled,
  ) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.kcwikiReportConfirmTitle),
          content: Text(l10n.kcwikiReportConfirmDesc),
          backgroundColor: const Color(0xff142735),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('kcwiki-report-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.kcwikiReportEnable),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await controller.setEnabled(enabled);
    } catch (_) {
      if (context.mounted) {
        TopNotice.show(
          context,
          message: l10n.kcwikiReportSaveFailed,
          tone: TopNoticeTone.error,
        );
      }
    }
  }

  Future<void> _logoutAndClear(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final session = _accountSession;
    final scope = session.current;
    final confirmed = await _showAccountDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmDesc),
        backgroundColor: const Color(0xff142735),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirmClear),
          ),
        ],
      ),
    );
    if (confirmed != true || !session.isCurrent(scope)) return;
    try {
      await browserController.logoutAndClearSession();
      if (context.mounted) {
        TopNotice.show(
          context,
          message: l10n.logoutSucceeded,
          tone: TopNoticeTone.success,
        );
      }
    } catch (_) {
      if (context.mounted) {
        TopNotice.show(
          context,
          message: l10n.logoutFailed,
          tone: TopNoticeTone.error,
        );
      }
    }
  }

  Future<void> _clearWebCache(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await _confirmClear(
      context,
      title: l10n.clearWebCacheConfirmTitle,
      description: l10n.clearWebCacheConfirmDesc,
      l10n: l10n,
    );
    if (!confirmed) return;
    await browserController.clearCache();
    if (context.mounted) {
      TopNotice.show(
        context,
        message: l10n.webCacheCleared,
        tone: TopNoticeTone.success,
      );
    }
  }

  Future<void> _resetBaseSenka(
    BuildContext context,
    AppLocalizations l10n,
    SenkaController controller,
  ) async {
    final session = _accountSession;
    final scope = session.current;
    final confirmed = await _showAccountDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('settings-reset-base-senka-dialog'),
        title: Text(l10n.baseSenkaResetConfirmTitle),
        content: Text(l10n.baseSenkaResetConfirmDesc),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('settings-reset-base-senka-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirmClear),
          ),
        ],
      ),
    );
    if (confirmed != true || !session.isCurrent(scope)) return;
    final saved = await controller.resetBaseSenka();
    if (!context.mounted || !session.isCurrent(scope)) return;
    TopNotice.show(
      context,
      message: saved ? l10n.baseSenkaResetSuccess : l10n.baseSenkaSaveFailed,
      tone: saved ? TopNoticeTone.success : TopNoticeTone.error,
    );
  }

  Future<void> _setBaseSenka(
    BuildContext context,
    AppLocalizations l10n,
    SenkaController controller,
  ) async {
    final session = _accountSession;
    final scope = session.current;
    final value = await _showAccountDialog<double>(
      context: context,
      builder: (_) => _BaseSenkaInputDialog(
        l10n: l10n,
        initialValue: controller.monthBaseSenka,
      ),
    );
    if (value == null || !session.isCurrent(scope)) return;
    final saved = await controller.setBaseSenka(value);
    if (!context.mounted || !session.isCurrent(scope)) return;
    TopNotice.show(
      context,
      message: saved
          ? l10n.baseSenkaSetSuccess(value.toStringAsFixed(2))
          : l10n.baseSenkaSaveFailed,
      tone: saved ? TopNoticeTone.success : TopNoticeTone.error,
    );
  }

  Future<void> _clearLogbook(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final session = _accountSession;
    final scope = session.current;
    final database = LogbookDatabase.forAccount(scope.memberId);
    final confirmed = await _confirmClear(
      context,
      title: l10n.clearLogbookConfirmTitle,
      description: l10n.clearLogbookConfirmDesc,
      l10n: l10n,
      accountScoped: true,
    );
    if (!confirmed || !session.isCurrent(scope)) return;
    try {
      await database.clearAll();
    } catch (error) {
      debugPrint('清理航海日志失败: $error');
    }
    if (context.mounted && session.isCurrent(scope)) {
      TopNotice.show(
        context,
        message: l10n.logbookCleared,
        tone: TopNoticeTone.success,
      );
    }
  }

  Future<bool> _confirmClear(
    BuildContext context, {
    required String title,
    required String description,
    required AppLocalizations l10n,
    bool accountScoped = false,
  }) async {
    Widget builder(BuildContext dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(description),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.confirmClear),
        ),
      ],
    );
    final result = accountScoped
        ? _showAccountDialog<bool>(context: context, builder: builder)
        : showDialog<bool>(context: context, builder: builder);
    return await result ?? false;
  }

  Future<T?> _showAccountDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) async {
    final session = _accountSession;
    final scope = session.current;
    final route = DialogRoute<T>(context: context, builder: builder);
    void dismissStaleDialog() {
      if (!session.isCurrent(scope) && route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }

    session.addListener(dismissStaleDialog);
    try {
      return await Navigator.of(context, rootNavigator: true).push<T>(route);
    } finally {
      session.removeListener(dismissStaleDialog);
    }
  }
}

class _BaseSenkaInputDialog extends StatefulWidget {
  const _BaseSenkaInputDialog({required this.l10n, required this.initialValue});

  final AppLocalizations l10n;
  final double initialValue;

  @override
  State<_BaseSenkaInputDialog> createState() => _BaseSenkaInputDialogState();
}

class _BaseSenkaInputDialogState extends State<_BaseSenkaInputDialog> {
  late final TextEditingController _input;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(
      text: widget.initialValue.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveInputDialog(
    dialogKey: const Key('settings-base-senka-dialog'),
    title: Text(widget.l10n.baseSenkaManualDialogTitle),
    content: TextField(
      key: const Key('settings-base-senka-input'),
      controller: _input,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        TextInputFormatter.withFunction((oldValue, newValue) {
          return RegExp(r'^\d*(?:\.\d{0,2})?$').hasMatch(newValue.text)
              ? newValue
              : oldValue;
        }),
      ],
      decoration: InputDecoration(
        labelText: widget.l10n.baseSenkaManualInputLabel,
        error: _invalid
            ? Text(
                widget.l10n.baseSenkaManualInvalid,
                key: const Key('settings-base-senka-error'),
              )
            : null,
      ),
      onChanged: (_) {
        if (_invalid) setState(() => _invalid = false);
      },
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(widget.l10n.cancel),
      ),
      TextButton(
        key: const Key('settings-base-senka-save'),
        onPressed: _submit,
        child: Text(widget.l10n.confirm),
      ),
    ],
  );

  void _submit() {
    final raw = _input.text.trim();
    final parsed = double.tryParse(raw);
    final valid = RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(raw);
    if (!valid || parsed == null || !parsed.isFinite) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, parsed);
  }
}
