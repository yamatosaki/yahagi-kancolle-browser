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

  final draft = ValueNotifier(controller.hiddenTotalShipIds);
  void toggle(int id) {
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
    // Android's existing checklist host accepts at most 64 rows.
    allowNative: choices.length <= 64,
    kind: 'moduleDisplay',
    title: strings.filterTitle,
    doneLabel: l10n.editDone,
    resetLabel: resetLabel,
    items: () => [
      for (final ship in choices)
        {
          'id': '${ship.id}',
          'label': ship.name,
          'value': '${ship.level} · ${ship.exp}',
          'checked': !draft.value.contains(ship.id),
        },
    ],
    onToggle: (id) => toggle(int.parse(id)),
    onReset: reset,
    onDone: () =>
        controller.setHiddenTotalShipIds(draft.value, expectedAccount: account),
    builder: (dialogContext, close) {
      bool canEdit() =>
          dialogContext.mounted &&
          ownerIsCurrent() &&
          ModalRoute.of(dialogContext)?.isCurrent == true;

      return Dialog(
        key: const Key('sortie-exp-filter-dialog'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 440),
          child: SizedBox(
            width: 360,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minimumListHeight = math.min(
                  48.0,
                  constraints.maxHeight / 2,
                );
                final expWidth = math.min(112.0, constraints.maxWidth * .32);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      child: ValueListenableBuilder<Set<int>>(
                        valueListenable: draft,
                        builder: (context, hidden, _) {
                          final palette = AppPalette.of(context);
                          return ListView.builder(
                            key: const Key('sortie-exp-filter-list'),
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: choices.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        16,
                                        20,
                                        10,
                                      ),
                                      child: Text(
                                        strings.filterTitle,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall,
                                      ),
                                    ),
                                    const Divider(height: 1),
                                  ],
                                );
                              }
                              final ship = choices[index - 1];
                              return CheckboxListTile(
                                key: Key('sortie-exp-filter-ship-${ship.id}'),
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
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
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight - minimumListHeight,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          child: OverflowBar(
                            alignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                key: const Key('sortie-exp-filter-reset'),
                                onPressed: () {
                                  if (canEdit()) reset();
                                },
                                child: Text(resetLabel),
                              ),
                              FilledButton(
                                key: const Key('sortie-exp-filter-done'),
                                onPressed: close,
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
