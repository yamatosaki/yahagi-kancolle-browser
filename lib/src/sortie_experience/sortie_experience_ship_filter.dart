import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../account/account_session.dart';
import '../game_state/game_state_controller.dart';
import '../localization/game_name_localizations.dart';
import '../settings/game_display_settings_dialog.dart';
import '../theme/app_palette.dart';
import 'sortie_experience_controller.dart';
import 'sortie_experience_strings.dart';

Future<void> showSortieExperienceShipFilter({
  required BuildContext context,
  required SortieExperienceController controller,
  required GameStateController gameState,
  required AccountScope account,
  required bool Function() ownerIsCurrent,
}) {
  final locale = Localizations.maybeLocaleOf(context) ?? const Locale('zh');
  final l10n = AppLocalizations.of(context) ?? lookupAppLocalizations(locale);
  final strings = SortieExperienceStrings(locale);
  final format = NumberFormat.decimalPattern(l10n.localeName);
  final names = gameNames(context);
  final masterShips = gameState.state.masterShips;
  // Keep the choices stable while battle capture adds new totals in the background.
  final choices = [
    for (final ship in controller.totals)
      (
        id: ship.ownedShipId,
        name: names.shipName(
          ship.name.isNotEmpty
              ? ship.name
              : masterShips[ship.masterShipId]?.name ?? strings.unknownShip,
          shipId: ship.masterShipId,
        ),
        level: 'Lv.${controller.progressFor(ship.ownedShipId).level ?? '—'}',
        exp: '+${format.format(ship.experience)} EXP',
      ),
  ];
  if (choices.isEmpty) return Future<void>.value();

  Set<int> currentShipIds() => {
    for (final ship in controller.totals) ship.ownedShipId,
  };

  final draft = ValueNotifier(controller.hiddenTotalShipIds);
  void toggle(int id) {
    if (!currentShipIds().contains(id)) return;
    final hidden = {...draft.value};
    if (!hidden.remove(id)) hidden.add(id);
    draft.value = hidden;
  }

  void reset() => draft.value = const <int>{};
  final resetLabel = l10n.panelResourcesCollapsedItemsReset;

  return showGameDisplaySettingsDialog(
    context: context,
    changes: controller,
    ownerIsCurrent: ownerIsCurrent,
    protectInputOnDismiss: false,
    compactShipChecklist: true,
    // Android's existing checklist host accepts at most 64 rows.
    allowNative: choices.length <= 64,
    kind: 'moduleDisplay',
    title: strings.filterTitle,
    doneLabel: l10n.editDone,
    resetLabel: resetLabel,
    items: () {
      final ids = currentShipIds();
      return [
        for (final ship in choices)
          if (ids.contains(ship.id))
            {
              'id': '${ship.id}',
              'label': ship.name,
              'detail': ship.level,
              'value': ship.exp,
              'checked': !draft.value.contains(ship.id),
            },
      ];
    },
    onToggle: (id) => toggle(int.parse(id)),
    onReset: reset,
    onDone: () => controller.setHiddenTotalShipIds(
      draft.value.intersection(currentShipIds()),
      expectedAccount: account,
    ),
    builder: (dialogContext, close) {
      bool canEdit() =>
          dialogContext.mounted &&
          ownerIsCurrent() &&
          ModalRoute.of(dialogContext)?.isCurrent == true;

      return Dialog(
        key: const Key('sortie-exp-filter-dialog'),
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: appColor(dialogContext, const Color(0xff101d27)),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: appColor(dialogContext, const Color(0xff385064)),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 480),
          child: SizedBox(
            width: 440,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final palette = AppPalette.of(context);
                final border = appColor(context, const Color(0xff385064));
                final headerHeight = math.min(40.0, constraints.maxHeight / 3);
                final bodyHeight = math.max(
                  0.0,
                  constraints.maxHeight - headerHeight - 2,
                );
                final footerMaxHeight =
                    bodyHeight - math.min(36.0, bodyHeight / 2);
                final expWidth = math.min(105.0, constraints.maxWidth * .29);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: headerHeight,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.directions_boat_outlined,
                              color: palette.accent,
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                strings.filterTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.foreground,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              key: const Key('sortie-exp-filter-close'),
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).closeButtonTooltip,
                              onPressed: () =>
                                  Navigator.of(dialogContext).maybePop(),
                              icon: Icon(
                                Icons.close,
                                color: palette.muted,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: border),
                    Flexible(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([controller, draft]),
                        builder: (context, _) {
                          final hidden = draft.value;
                          final ids = currentShipIds();
                          final currentChoices = choices
                              .where((ship) => ids.contains(ship.id))
                              .toList();
                          return ListView.separated(
                            key: const Key('sortie-exp-filter-list'),
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(6),
                            itemCount: currentChoices.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 3),
                            itemBuilder: (context, index) {
                              final ship = currentChoices[index];
                              return CheckboxListTile(
                                key: Key('sortie-exp-filter-ship-${ship.id}'),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                minTileHeight: 36,
                                minVerticalPadding: 2,
                                minLeadingWidth: 0,
                                horizontalTitleGap: 6,
                                titleAlignment: ListTileTitleAlignment.center,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                tileColor: appColor(
                                  context,
                                  const Color(0xff172a38),
                                ),
                                activeColor: palette.accent,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: !hidden.contains(ship.id),
                                onChanged: (_) {
                                  if (canEdit()) toggle(ship.id);
                                },
                                title: Text.rich(
                                  TextSpan(
                                    text: ship.name,
                                    children: [
                                      TextSpan(
                                        text: ' ${ship.level}',
                                        style: TextStyle(
                                          color: palette.muted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.foreground,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                secondary: SizedBox(
                                  width: expWidth,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      ship.exp,
                                      style: TextStyle(
                                        color: palette.isDark
                                            ? const Color(0xff8adac7)
                                            : palette.success,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Divider(height: 1, color: border),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: footerMaxHeight),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: OverflowBar(
                            alignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                key: const Key('sortie-exp-filter-reset'),
                                onPressed: () {
                                  if (canEdit()) reset();
                                },
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(resetLabel),
                              ),
                              FilledButton(
                                key: const Key('sortie-exp-filter-done'),
                                onPressed: close,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: Text(l10n.editDone),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  ).whenComplete(draft.dispose);
}
