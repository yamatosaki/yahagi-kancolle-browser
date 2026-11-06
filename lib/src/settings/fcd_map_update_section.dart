import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import 'data_update_metadata.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../battle/fcd_map_controller.dart';
import '../battle/fcd_map_update_service.dart';

final class FcdMapUpdateSection extends StatelessWidget {
  const FcdMapUpdateSection({super.key, required this.controller});

  final FcdMapController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
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
                    l10n.fcdMapDataTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  DataUpdateMetadata(
                    version: controller.version.toString(),
                    lastCheckedAt: controller.lastCheckedAt,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              key: const Key('fcd-map-check-button'),
              tooltip: l10n.fcdMapCheckUpdates,
              onPressed: controller.isChecking ? null : () => _check(context),
              icon: controller.isChecking
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.sync,
                      color: appColor(context, Color(0xffd4a85f)),
                    ),
            ),
          ],
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
      barrierDismissible: false,
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
}
