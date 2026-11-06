import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../backup/record_backup.dart';
import '../localization/record_backup_strings.dart';
import '../widgets/top_notice.dart';
import 'settings_ui_helpers.dart';

enum _ExportDestination { device, share }

class RecordBackupSection extends StatelessWidget with SettingsUIHelpers {
  const RecordBackupSection({super.key, required this.service});
  final RecordBackupService service;

  void _notice(BuildContext context, String message, {bool error = false}) {
    if (!context.mounted) return;
    TopNotice.show(
      context,
      message: message,
      tone: error ? TopNoticeTone.error : TopNoticeTone.success,
    );
  }

  Future<void> _run(
    BuildContext context,
    Future<String?> Function() operation,
  ) async {
    try {
      final result = await operation();
      if (result != null && context.mounted) _notice(context, result);
    } catch (error) {
      if (context.mounted) _notice(context, '$error', error: true);
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final scope = service.session.current;
      final archive = await service.selectImport();
      if (archive == null ||
          !context.mounted ||
          !service.session.isCurrent(scope)) {
        return;
      }
      final strings = RecordBackupStrings.of(context);
      final count = archive.tables.entries
          .where((entry) => entry.key != 'pending_construction_logs')
          .fold<int>(0, (sum, entry) => sum + entry.value.length);
      final confirmed = await showDialog<bool>(
        barrierDismissible: false,
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(strings.restoreTitle),
          content: Text(
            strings.restoreDescription(count, archive.compositions.length),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              key: const Key('settings-backup-restore-confirm'),
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(strings.restoreConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !service.session.isCurrent(scope)) return;
      await service.restore(archive);
      if (context.mounted) _notice(context, strings.restoreDone);
    } catch (error) {
      if (context.mounted) _notice(context, '$error', error: true);
    }
  }

  Future<void> _export(BuildContext context) async {
    final scope = service.session.current;
    final strings = RecordBackupStrings.of(context);
    final destination = await showDialog<_ExportDestination>(
      barrierDismissible: false,
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(strings.export),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('settings-backup-save-device'),
              leading: const Icon(Icons.save_alt_outlined),
              title: Text(strings.saveToDevice),
              onTap: () => Navigator.pop(dialog, _ExportDestination.device),
            ),
            ListTile(
              key: const Key('settings-backup-share-apps'),
              leading: const Icon(Icons.share_outlined),
              title: Text(strings.shareWithApps),
              onTap: () => Navigator.pop(dialog, _ExportDestination.share),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('settings-backup-export-cancel'),
            onPressed: () => Navigator.pop(dialog),
            child: Text(strings.cancel),
          ),
        ],
      ),
    );
    if (!context.mounted || destination == null) return;
    await _run(context, () async {
      if (!service.session.isCurrent(scope)) {
        throw StateError(strings.accountChanged);
      }
      if (destination == _ExportDestination.device) {
        final saved = await service.saveExport(expectedScope: scope);
        return saved ? strings.savedToDevice : null;
      }
      await service.export(expectedScope: scope);
      return null;
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: service,
    builder: (context, _) {
      final strings = RecordBackupStrings.of(context);
      final known = service.session.current.isKnown;
      final busy = service.busy;
      final status = service.lastError != null
          ? strings.syncFailed(service.lastError!)
          : service.pending
          ? strings.syncPending
          : service.lastSync != null
          ? strings.lastSync(service.lastSync!.toLocal())
          : strings.neverSynced;
      return Column(
        children: [
          buildSwitchTile(
            title: strings.enabled,
            titleKey: const Key('settings-backup-enabled-title'),
            switchKey: const Key('settings-backup-enabled'),
            value: service.enabled,
            onChanged: busy
                ? null
                : (value) => _run(context, () async {
                    await service.setEnabled(value);
                    return null;
                  }),
          ),
          Divider(color: appColor(context, Color(0xff294052)), height: 1),
          buildActionTile(
            key: const Key('settings-backup-folder'),
            title: strings.folder,
            subtitle: strings.folderHint,
            trailing: Icon(
              Icons.folder_open_outlined,
              color: appColor(
                context,
                service.enabled ? null : const Color(0xff526776),
              ),
            ),
            enabled: service.enabled && !busy,
            onTap: () => _run(context, () async {
              final selected = await service.chooseDirectory();
              return selected ? strings.folderSelected : null;
            }),
          ),
          Divider(color: appColor(context, Color(0xff294052)), height: 1),
          buildActionTile(
            key: const Key('settings-backup-sync'),
            title: strings.sync,
            subtitle: status,
            trailing: Icon(
              Icons.sync,
              color: appColor(
                context,
                service.enabled ? null : const Color(0xff526776),
              ),
            ),
            enabled: service.enabled && known && service.hasDirectory && !busy,
            onTap: () => _run(context, () async {
              await service.sync();
              return strings.syncDone;
            }),
          ),
          Divider(color: appColor(context, Color(0xff294052)), height: 1),
          buildActionTile(
            key: const Key('settings-backup-export'),
            title: strings.export,
            subtitle: strings.exportHint,
            trailing: Icon(
              Icons.ios_share_outlined,
              color: appColor(
                context,
                service.enabled ? null : const Color(0xff526776),
              ),
            ),
            enabled: service.enabled && known && service.hasDirectory && !busy,
            onTap: () => _export(context),
          ),
          Divider(color: appColor(context, Color(0xff294052)), height: 1),
          buildActionTile(
            key: const Key('settings-backup-import'),
            title: strings.import,
            subtitle: strings.importHint,
            trailing: Icon(
              Icons.restore_outlined,
              color: appColor(
                context,
                service.enabled ? null : const Color(0xff526776),
              ),
            ),
            enabled: service.enabled && known && !busy,
            onTap: () => _restore(context),
          ),
        ],
      );
    },
  );
}
