import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../battle/fcd_map_controller.dart';
import '../battle/fcd_map_update_service.dart';

final class FcdMapUpdateSection extends StatelessWidget {
  const FcdMapUpdateSection({super.key, required this.controller});

  final FcdMapController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const metadataStyle = TextStyle(color: Color(0xff8197a5));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListTile(
        title: Text(l10n.fcdMapDataTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        subtitle: Wrap(
          spacing: 16,
          runSpacing: 2,
          children: [
            Text(
              l10n.fcdMapDataVersion(controller.version.toString()),
              style: metadataStyle,
            ),
            Text(
              controller.lastCheckedAt == null
                  ? l10n.fcdMapNeverChecked
                  : l10n.fcdMapLastChecked(
                      _formatTime(controller.lastCheckedAt!.toLocal()),
                    ),
              style: metadataStyle,
            ),
          ],
        ),
        trailing: IconButton(
          key: const Key('fcd-map-check-button'),
          tooltip: l10n.fcdMapCheckUpdates,
          onPressed: controller.isChecking ? null : () => _check(context),
          icon: controller.isChecking
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync, color: Color(0xffd4a85f)),
        ),
      ),
    );
  }

  Future<void> _check(BuildContext context) async {
    final oldVersion = controller.version.toString();
    final result = await controller.checkForUpdates();
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final message = switch (result) {
      FcdMapUpToDate() =>
        '${l10n.fcdMapUpToDate}\n${l10n.fcdMapDataVersion(controller.version.toString())}',
      FcdMapUpdated(:final dataset) => l10n.fcdMapUpdated(
        oldVersion,
        dataset.version.toString(),
      ),
      FcdMapUpdateFailed(kind: FcdMapUpdateFailure.network) =>
        '${l10n.fcdMapNetworkError}\n${l10n.fcdMapDataVersion(controller.version.toString())}',
      FcdMapUpdateFailed(kind: FcdMapUpdateFailure.validation) =>
        '${l10n.fcdMapValidationError}\n${l10n.fcdMapDataVersion(controller.version.toString())}',
      FcdMapUpdateFailed(kind: FcdMapUpdateFailure.storage) =>
        '${l10n.fcdMapStorageError}\n${l10n.fcdMapDataVersion(controller.version.toString())}',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.fcdMapDataTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';
}
