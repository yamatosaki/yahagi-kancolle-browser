import '../theme/app_palette.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../account/account_session.dart';
import '../subtitles/ship_subtitle_catalog_controller.dart';
import '../subtitles/ship_subtitle_update_section.dart';
import '../subtitles/ship_subtitle_data_strings.dart';
import '../backup/record_backup.dart';

import '../battle/fcd_map_controller.dart';
import '../browser/game_browser_controller.dart';
import '../browser/game_resource_cache_controller.dart';
import '../capture/capture_mode_controller.dart';
import '../capture/game_capture_controller.dart';
import '../diagnostics/diagnostic_controller.dart';
import '../game_state/game_state_controller.dart';
import '../improvement/improvement_dataset_update_section.dart';
import '../improvement/improvement_planner_controller.dart';
import '../logbook/logbook_database.dart';
import '../localization/record_backup_strings.dart';
import '../prototype_status_controller.dart';
import '../quest/quest_catalog_controller.dart';
import '../quest/quest_progress_rules_controller.dart';
import '../senka/senka_controller.dart';
import '../telemetry/telemetry_controller.dart';
import '../toolbox/composition_record_store.dart';
import '../toolbox/sortie_map_query/sortie_map_catalog_controller.dart';
import '../toolbox/sortie_map_query/enemy_catalog_controller.dart';
import '../kcwiki_report/kcwiki_report_settings.dart';
import '../kcwiki_report/kcwiki_report_transport.dart';
import '../widgets/top_notice.dart';
import 'fcd_map_update_section.dart';
import 'game_rendering_mode_controller.dart';
import 'game_resource_cache_section.dart';
import 'quest_catalog_update_section.dart';
import 'quest_progress_update_section.dart';
import 'sortie_map_catalog_update_section.dart';
import 'enemy_catalog_update_section.dart';
import 'settings_ui_helpers.dart';
import 'record_backup_section.dart';
import 'data_update_metadata.dart';
import 'settings_detail_page.dart';
import 'settings_organization_strings.dart';
import '../browser/game_resource_cache_store.dart';

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
    this.kcwikiEndpointAvailable,
    this.diagnosticController,
    this.showDeveloperDiagnostics = false,
    this.gameRenderingModeController,
    this.fcdMapController,
    this.questCatalogController,
    this.questProgressRulesController,
    this.sortieMapCatalogController,
    this.enemyCatalogController,
    this.improvementPlannerController,
    this.shipSubtitleCatalogController,
    this.telemetryController,
    this.backupService,
  });

  final CaptureModeController captureModeController;
  final GameBrowserController browserController;
  final GameCaptureController gameCaptureController;
  final PrototypeStatusController prototypeStatusController;
  final GameStateController gameStateController;
  final SenkaController? senkaController;
  final GameResourceCacheController? gameResourceCacheController;
  final KcwikiReportController? kcwikiReportController;
  final bool? kcwikiEndpointAvailable;
  final DiagnosticController? diagnosticController;
  final bool showDeveloperDiagnostics;
  final GameRenderingModeController? gameRenderingModeController;
  final FcdMapController? fcdMapController;
  final QuestCatalogController? questCatalogController;
  final QuestProgressRulesController? questProgressRulesController;
  final SortieMapCatalogController? sortieMapCatalogController;
  final EnemyCatalogController? enemyCatalogController;
  final ImprovementPlannerController? improvementPlannerController;
  final ShipSubtitleCatalogController? shipSubtitleCatalogController;
  final TelemetryController? telemetryController;
  final RecordBackupService? backupService;

  RecordBackupService? get _backupService =>
      backupService ?? RecordBackupService.shared;

  AccountSession get _accountSession =>
      gameStateController.accountSession ?? LogbookDatabase.accountSession;

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final updates = <Widget>[
      if (fcdMapController case final controller?)
        _updateEntry(
          context,
          key: const Key('settings-data-update-fcd'),
          title: l10n.fcdMapDataTitle,
          controller: controller,
          version: () => controller.version.toString(),
          child: FcdMapUpdateSection(controller: controller),
        ),
      if (sortieMapCatalogController case final controller?)
        _updateEntry(
          context,
          key: const Key('settings-data-update-maps'),
          title: l10n.sortieMapDataTitle,
          controller: controller,
          version: () => controller.data.dataVersion,
          child: SortieMapCatalogUpdateSection(controller: controller),
        ),
      if (enemyCatalogController case final controller?)
        _updateEntry(
          context,
          key: const Key('settings-data-update-enemies'),
          title: l10n.enemyDataTitle,
          controller: controller,
          version: () => controller.data.dataVersion,
          child: EnemyCatalogUpdateSection(controller: controller),
        ),
      if (questCatalogController case final controller?)
        _updateEntry(
          context,
          key: const Key('settings-data-update-quests'),
          title: l10n.questCatalogDataTitle,
          controller: controller,
          version: () => controller.version.shortLabel,
          child: QuestCatalogUpdateSection(controller: controller),
        ),
      if (questProgressRulesController case final controller?)
        _updateEntry(
          context,
          key: const Key('settings-data-update-quest-progress'),
          title: l10n.questProgressDataTitle,
          controller: controller,
          version: () => controller.version,
          child: QuestProgressUpdateSection(controller: controller),
        ),
      if (improvementPlannerController case final controller?)
        _updateEntry(
          context,
          key: const Key('settings-data-update-improvement'),
          title: l10n.improvementDatasetTitle,
          controller: controller,
          version: () => controller.dataset.version.dataVersion,
          child: ImprovementDatasetUpdateSection(controller: controller),
        ),
      if (shipSubtitleCatalogController case final controller?)
        _updateEntry(
          context,
          key: const Key('settings-data-update-translations'),
          title: ShipSubtitleDataStrings(l10n.localeName).title,
          controller: controller,
          version: () => controller.data.version,
          child: ShipSubtitleUpdateSection(controller: controller),
        ),
    ];
    return Container(
      color: appColor(context, const Color(0xff0d1a26)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (updates.isNotEmpty) ...[
              buildSectionTitle(
                settingsOrganizationText(context, 'settingsGroupDataUpdates'),
              ),
              buildCard(child: Column(children: _divided(updates))),
              const SizedBox(height: 24),
            ],
            if (gameResourceCacheController case final controller?) ...[
              buildSectionTitle(l10n.gameResourceCacheTitle),
              buildCard(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => buildActionTile(
                    key: const Key('settings-resource-cache-entry'),
                    title: l10n.gameResourceCacheTitle,
                    subtitle:
                        '${controller.mode == GameResourceCacheMode.full ? l10n.gameResourceCacheFull : l10n.gameResourceCacheNone} · ${l10n.gameResourceCacheStoredSize(controller.completenessLine)}',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openSettingsDetail(
                      context,
                      title: l10n.gameResourceCacheTitle,
                      child: GameResourceCacheSection(controller: controller),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_backupService case final backup?) ...[
              buildSectionTitle(RecordBackupStrings.of(context).section),
              buildCard(
                child: AnimatedBuilder(
                  animation: backup,
                  builder: (context, _) {
                    final strings = RecordBackupStrings.of(context);
                    final status = backup.lastError != null
                        ? strings.syncFailed(backup.lastError!)
                        : backup.pending
                        ? strings.syncPending
                        : backup.lastSync != null
                        ? strings.lastSync(backup.lastSync!.toLocal())
                        : strings.neverSynced;
                    return buildActionTile(
                      key: const Key('settings-record-backup-entry'),
                      title: strings.section,
                      subtitle:
                          '${settingsOrganizationText(context, backup.enabled ? 'settingsStatusEnabled' : 'settingsStatusDisabled')} · $status',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openSettingsDetail(
                        context,
                        title: strings.section,
                        child: RecordBackupSection(service: backup),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (kcwikiReportController != null ||
                telemetryController != null) ...[
              buildSectionTitle(
                settingsOrganizationText(
                  context,
                  'settingsGroupDataSharingPrivacy',
                ),
              ),
              buildCard(
                child: Column(
                  children: _divided([
                    if (kcwikiReportController case final controller?)
                      AnimatedBuilder(
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
                    if (telemetryController case final telemetry?)
                      AnimatedBuilder(
                        animation: telemetry,
                        builder: (context, _) => Column(
                          children: [
                            buildSwitchTile(
                              switchKey: const Key('telemetryStatsSwitch'),
                              title: l10n.telemetryAnonymousStatsTitle,
                              subtitle: l10n.telemetryAnonymousStatsDesc,
                              value: telemetry.enabled,
                              onChanged: telemetry.setEnabled,
                            ),
                            if (telemetry.saveFailed)
                              buildActionTile(
                                key: const Key('telemetry-save-retry'),
                                title: l10n.telemetryRetrySave,
                                subtitle: l10n.telemetrySaveFailed,
                                trailing: const Icon(Icons.refresh),
                                onTap: () =>
                                    telemetry.setEnabled(telemetry.enabled),
                              ),
                          ],
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
            ],
            buildSectionTitle(
              settingsOrganizationText(context, 'settingsGroupClearLocalData'),
            ),
            buildCard(
              child: Column(
                children: _divided([
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
                  buildActionTile(
                    key: const Key('settings-clear-web-cache'),
                    title: l10n.clearWebCache,
                    subtitle: l10n.clearWebCacheDesc,
                    trailing: const Icon(Icons.cleaning_services_outlined),
                    onTap: () => _clearWebCache(context, l10n),
                  ),
                  buildActionTile(
                    key: const Key('settings-clear-logbook'),
                    title: RecordBackupStrings.of(context).clearLogbook,
                    subtitle: RecordBackupStrings.of(context).clearLogbookHint,
                    trailing: const Icon(Icons.delete_forever_outlined),
                    onTap: () => _clearLogbook(context, l10n),
                  ),
                  buildActionTile(
                    key: const Key('settings-clear-composition-records'),
                    title: RecordBackupStrings.of(context).clearComposition,
                    subtitle: RecordBackupStrings.of(
                      context,
                    ).clearCompositionHint,
                    trailing: const Icon(Icons.delete_forever_outlined),
                    onTap: () => _clearCompositionRecords(context, l10n),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<Widget> _divided(List<Widget> children) => [
    for (var index = 0; index < children.length; index++) ...[
      if (index > 0) const Divider(height: 1),
      children[index],
    ],
  ];

  Widget _updateEntry(
    BuildContext context, {
    required Key key,
    required String title,
    required Listenable controller,
    required String Function() version,
    required Widget child,
  }) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l10n =
          AppLocalizations.of(context) ??
          lookupAppLocalizations(const Locale('zh'));
      return buildActionTile(
        key: key,
        title: title,
        subtitle:
            '${l10n.dataVersionLabel}：${DataUpdateMetadata.versionDate(version())}',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openSettingsDetail(context, title: title, child: child),
      );
    },
  );

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
      if (!(kcwikiEndpointAvailable ??
          configuredKcwikiReportEndpoint() != null)) {
        TopNotice.show(
          context,
          message: l10n.kcwikiReportUnavailable,
          tone: TopNoticeTone.error,
        );
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.kcwikiReportConfirmTitle),
          content: Text(l10n.kcwikiReportConfirmDesc),
          backgroundColor: appColor(context, const Color(0xff142735)),
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

  Future<void> _clearLogbook(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final session = _accountSession;
    final scope = session.current;
    final strings = RecordBackupStrings.of(context);
    if (!scope.isKnown) {
      TopNotice.show(
        context,
        message: strings.loginRequired,
        tone: TopNoticeTone.error,
      );
      return;
    }
    final database = LogbookDatabase.forAccount(scope.memberId);
    final tables = await database.backupSnapshot();
    if (!context.mounted || !session.isCurrent(scope)) return;
    final count = tables.entries
        .where((entry) => entry.key != 'pending_construction_logs')
        .fold<int>(0, (sum, entry) => sum + entry.value.length);
    final backedUp =
        _backupService?.enabled == true && _backupService?.hasDirectory == true;
    final confirmed = await _confirmClear(
      context,
      title: strings.clearLogbookTitle,
      description: strings.clearLogbookDescription(count, backedUp),
      l10n: l10n,
      accountScoped: true,
    );
    if (!confirmed || !session.isCurrent(scope)) return;
    try {
      if (!session.isCurrent(scope)) return;
      if (_backupService != null) {
        await _backupService!.clearLogbookMain();
      } else {
        await database.clearAll();
      }
    } catch (error) {
      debugPrint('Logbook cleanup failed: $error');
      if (context.mounted && session.isCurrent(scope)) {
        TopNotice.show(
          context,
          message: strings.clearFailed(error),
          tone: TopNoticeTone.error,
        );
      }
      return;
    }
    if (context.mounted && session.isCurrent(scope)) {
      TopNotice.show(
        context,
        message: l10n.logbookCleared,
        tone: TopNoticeTone.success,
      );
    }
  }

  Future<void> _clearCompositionRecords(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final session = _accountSession;
    final scope = session.current;
    final strings = RecordBackupStrings.of(context);
    if (!scope.isKnown) {
      TopNotice.show(
        context,
        message: strings.loginRequired,
        tone: TopNoticeTone.error,
      );
      return;
    }
    final store = FileCompositionRecordStore();
    late final List<CompositionRecord> records;
    try {
      records = await store.load(scope.memberId);
    } catch (error) {
      if (context.mounted && session.isCurrent(scope)) {
        TopNotice.show(
          context,
          message: strings.clearFailed(error),
          tone: TopNoticeTone.error,
        );
      }
      return;
    }
    if (!context.mounted || !session.isCurrent(scope)) return;
    final backedUp =
        _backupService?.enabled == true && _backupService?.hasDirectory == true;
    final confirmed = await _confirmClear(
      context,
      title: strings.clearCompositionTitle,
      description: strings.clearCompositionDescription(
        records.length,
        backedUp,
      ),
      l10n: l10n,
      accountScoped: true,
    );
    if (!confirmed || !session.isCurrent(scope)) return;
    try {
      if (!session.isCurrent(scope)) return;
      final removed = _backupService != null
          ? await _backupService!.clearCompositionMain()
          : await store.clearAll(scope.memberId);
      if (context.mounted && session.isCurrent(scope)) {
        TopNotice.show(
          context,
          message: strings.compositionCleared(removed),
          tone: TopNoticeTone.success,
        );
      }
    } catch (error) {
      if (context.mounted && session.isCurrent(scope)) {
        TopNotice.show(
          context,
          message: strings.clearFailed(error),
          tone: TopNoticeTone.error,
        );
      }
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
