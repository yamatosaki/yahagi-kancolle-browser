import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../settings/data_update_metadata.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import 'improvement_dataset_update_service.dart';
import 'improvement_planner_controller.dart';

class ImprovementDatasetUpdateSection extends StatelessWidget {
  const ImprovementDatasetUpdateSection({super.key, required this.controller});
  final ImprovementPlannerController controller;

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
                    l10n.improvementDatasetTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  DataUpdateMetadata(
                    version: controller.dataset.version.dataVersion,
                    lastCheckedAt: controller.lastCheckedAt,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              key: const Key('improvement-data-check-button'),
              tooltip: l10n.improvementDatasetManualUpdate,
              onPressed: controller.isCheckingUpdates
                  ? null
                  : () => _check(context),
              icon: controller.isCheckingUpdates
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
    final before = controller.dataset.version.dataVersion;
    final result = await controller.checkForUpdates();
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final after = controller.dataset.version.dataVersion;
    final message = switch (result) {
      ImprovementUpToDate() => l10n.improvementDatasetUpToDate(after),
      ImprovementUpdated() => l10n.improvementDatasetUpdated(before, after),
      ImprovementUpdateFailed(kind: ImprovementUpdateFailure.network) =>
        l10n.improvementDatasetNetworkError(after),
      ImprovementUpdateFailed(kind: ImprovementUpdateFailure.validation) =>
        l10n.improvementDatasetValidationError(after),
      ImprovementUpdateFailed(kind: ImprovementUpdateFailure.storage) =>
        l10n.improvementDatasetStorageError(after),
    };
    await showDialog<void>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.improvementDatasetTitle),
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
