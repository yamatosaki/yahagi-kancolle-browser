import 'package:flutter/material.dart';
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
      builder: (context, _) => ListTile(
        title: Text(
          l10n.improvementDatasetTitle,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Wrap(
          spacing: 16,
          runSpacing: 2,
          children: [
            Text(
              l10n.improvementDatasetVersion(
                controller.dataset.version.dataVersion,
              ),
              style: const TextStyle(color: Color(0xff8197a5)),
            ),
            Text(
              controller.lastCheckedAt == null
                  ? l10n.improvementDatasetNeverChecked
                  : l10n.improvementDatasetLastChecked(
                      _time(controller.lastCheckedAt!.toLocal()),
                    ),
              style: const TextStyle(color: Color(0xff8197a5)),
            ),
          ],
        ),
        trailing: IconButton(
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
              : const Icon(Icons.sync, color: Color(0xffd4a85f)),
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

  static String _time(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
