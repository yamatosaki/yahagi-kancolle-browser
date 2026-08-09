import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../quest/quest_catalog_controller.dart';
import '../quest/quest_catalog_update_service.dart';

final class QuestCatalogUpdateSection extends StatelessWidget {
  const QuestCatalogUpdateSection({super.key, required this.controller});

  final QuestCatalogController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const metadataStyle = TextStyle(color: Color(0xff8197a5));
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListTile(
        title: Text(
          l10n.questCatalogDataTitle,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Wrap(
          spacing: 16,
          runSpacing: 2,
          children: [
            Text(
              l10n.questCatalogDataVersion(controller.version.shortLabel),
              style: metadataStyle,
            ),
            Text(
              controller.lastCheckedAt == null
                  ? l10n.questCatalogNeverChecked
                  : l10n.questCatalogLastChecked(
                      _formatTime(controller.lastCheckedAt!.toLocal()),
                    ),
              style: metadataStyle,
            ),
          ],
        ),
        trailing: IconButton(
          key: const Key('quest-catalog-check-button'),
          tooltip: l10n.questCatalogCheckUpdates,
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
    final oldVersion = controller.version.shortLabel;
    final result = await controller.checkForUpdates();
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final current = controller.version.shortLabel;
    final message = switch (result) {
      QuestCatalogUpToDate() =>
        '${l10n.questCatalogUpToDate}\n${l10n.questCatalogDataVersion(current)}',
      QuestCatalogUpdated() => l10n.questCatalogUpdated(oldVersion, current),
      QuestCatalogUpdateFailed(kind: QuestCatalogUpdateFailure.network) =>
        '${l10n.questCatalogNetworkError}\n${l10n.questCatalogDataVersion(current)}',
      QuestCatalogUpdateFailed(kind: QuestCatalogUpdateFailure.validation) =>
        '${l10n.questCatalogValidationError}\n${l10n.questCatalogDataVersion(current)}',
      QuestCatalogUpdateFailed(kind: QuestCatalogUpdateFailure.storage) =>
        '${l10n.questCatalogStorageError}\n${l10n.questCatalogDataVersion(current)}',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.questCatalogDataTitle),
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
