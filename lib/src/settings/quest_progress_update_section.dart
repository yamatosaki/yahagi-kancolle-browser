import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../quest/quest_progress_rules_controller.dart';
import '../quest/quest_progress_update_service.dart';
import '../theme/app_palette.dart';
import 'data_update_metadata.dart';

final class QuestProgressUpdateSection extends StatelessWidget {
  const QuestProgressUpdateSection({super.key, required this.controller});

  final QuestProgressRulesController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.questProgressDataTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  DataUpdateMetadata(
                    version: controller.version,
                    lastCheckedAt: controller.lastCheckedAt,
                  ),
                  Text(
                    l10n.questProgressDataSource(
                      controller.sourceHost.isEmpty
                          ? l10n.questProgressBundledSource
                          : controller.sourceHost,
                    ),
                    style: TextStyle(
                      color: appColor(context, const Color(0xff8197a5)),
                    ),
                  ),
                  if (controller.isChecking) Text(l10n.questProgressChecking),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              key: const Key('quest-progress-check-update-button'),
              tooltip: controller.isChecking
                  ? l10n.questProgressChecking
                  : l10n.questProgressCheckUpdates,
              onPressed: controller.isChecking ? null : () => _check(context),
              icon: controller.isChecking
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.sync,
                      color: appColor(context, const Color(0xffd4a85f)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _check(BuildContext context) async {
    final oldVersion = controller.version;
    final result = await controller.checkForUpdates();
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final version = controller.version;
    final message = switch (result) {
      QuestProgressUpToDate() =>
        '${l10n.questProgressUpToDate}\n${l10n.questProgressDataVersion(version)}',
      QuestProgressUpdated() => l10n.questProgressUpdated(oldVersion, version),
      QuestProgressUpdateFailed(kind: QuestProgressUpdateFailure.network) =>
        '${l10n.questProgressNetworkError}\n${l10n.questProgressDataVersion(version)}',
      QuestProgressUpdateFailed(kind: QuestProgressUpdateFailure.validation) =>
        '${l10n.questProgressValidationError}\n${l10n.questProgressDataVersion(version)}',
      QuestProgressUpdateFailed(kind: QuestProgressUpdateFailure.storage) =>
        '${l10n.questProgressStorageError}\n${l10n.questProgressDataVersion(version)}',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.questProgressDataTitle),
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
