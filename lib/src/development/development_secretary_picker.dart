import '../theme/app_palette.dart';
import '../widgets/app_segmented_style.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'development_dataset.dart';
import 'development_name_labels.dart';

class DevelopmentSecretaryPoolGroup {
  const DevelopmentSecretaryPoolGroup({
    required this.label,
    required this.pools,
  });

  final String label;
  final List<DevelopmentPoolRecord> pools;
}

List<DevelopmentSecretaryPoolGroup> groupDevelopmentSecretaryPools(
  Iterable<DevelopmentPoolRecord> pools,
  Locale locale, {
  required String otherLabel,
}) {
  final grouped = <String, List<DevelopmentPoolRecord>>{};
  for (final pool in pools) {
    final parts = _poolLabelParts(pool.label(locale), otherLabel);
    grouped.putIfAbsent(parts.$1, () => []).add(pool);
  }
  return List.unmodifiable(
    grouped.entries.map(
      (entry) => DevelopmentSecretaryPoolGroup(
        label: entry.key,
        pools: List.unmodifiable(entry.value),
      ),
    ),
  );
}

class DevelopmentSecretaryPicker extends StatelessWidget {
  const DevelopmentSecretaryPicker({
    super.key,
    required this.pools,
    required this.selectedPoolKey,
    required this.locale,
    required this.label,
    required this.dialogTitle,
    required this.otherLabel,
    required this.onSelected,
  });

  final List<DevelopmentPoolRecord> pools;
  final String? selectedPoolKey;
  final Locale locale;
  final String label;
  final String dialogTitle;
  final String otherLabel;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    DevelopmentPoolRecord? selected;
    for (final pool in pools) {
      if (pool.key == selectedPoolKey) {
        selected = pool;
        break;
      }
    }
    return OutlinedButton(
      key: const Key('development-secretary-picker'),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        side: BorderSide(color: appColor(context, Color(0xff78919c))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: pools.isEmpty
          ? null
          : () async {
              final key = await showDialog<String>(
                barrierDismissible: false,
                context: context,
                builder: (context) => _DevelopmentSecretaryPickerDialog(
                  groups: groupDevelopmentSecretaryPools(
                    pools,
                    locale,
                    otherLabel: otherLabel,
                  ),
                  selectedPoolKey: selectedPoolKey,
                  locale: locale,
                  title: dialogTitle,
                  otherLabel: otherLabel,
                ),
              );
              if (key != null) onSelected(key);
            },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, Color(0xff91aab5)),
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  selected == null
                      ? '—'
                      : developmentPoolText(
                          context,
                          _poolDisplayLabel(selected, locale),
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appTextStyle(
                    context,
                    TextStyle(
                      color: appColor(context, Color(0xffedf4f6)),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: appColor(context, Color(0xffa9bac1)),
          ),
        ],
      ),
    );
  }
}

class _DevelopmentSecretaryPickerDialog extends StatefulWidget {
  const _DevelopmentSecretaryPickerDialog({
    required this.groups,
    required this.selectedPoolKey,
    required this.locale,
    required this.title,
    required this.otherLabel,
  });

  final List<DevelopmentSecretaryPoolGroup> groups;
  final String? selectedPoolKey;
  final Locale locale;
  final String title;
  final String otherLabel;

  @override
  State<_DevelopmentSecretaryPickerDialog> createState() =>
      _DevelopmentSecretaryPickerDialogState();
}

class _DevelopmentSecretaryPickerDialogState
    extends State<_DevelopmentSecretaryPickerDialog> {
  late int groupIndex = _initialGroupIndex();

  int _initialGroupIndex() {
    for (var index = 0; index < widget.groups.length; index++) {
      if (widget.groups[index].pools.any(
        (pool) => pool.key == widget.selectedPoolKey,
      )) {
        return index;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(720.0, math.max(300.0, screen.width - 32));
    final height = math.min(560.0, math.max(360.0, screen.height * 0.72));
    final leftWidth = (width * 0.3).clamp(112.0, 190.0);
    final group = widget.groups[groupIndex];
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: appColor(context, Colors.transparent),
      child: Container(
        key: const Key('development-secretary-picker-dialog'),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: appColor(context, const Color(0xff101d27)),
          border: Border.all(color: appColor(context, const Color(0xff385064))),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: appColor(context, Colors.black54),
              blurRadius: 22,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(
                    Icons.flag_outlined,
                    size: 20,
                    color: appColor(context, Color(0xffd4a85f)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Divider(height: 1, color: appColor(context, Color(0xff385064))),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: ColoredBox(
                      color: appColor(context, const Color(0xff0b1720)),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: widget.groups.length,
                        itemBuilder: (context, index) {
                          final selected = index == groupIndex;
                          return Material(
                            color: AppSegmentedStyle.selection(
                              context,
                              selected,
                            ),
                            child: InkWell(
                              key: Key('development-secretary-group-$index'),
                              onTap: () => setState(() => groupIndex = index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                                child: Text(
                                  developmentPoolText(
                                    context,
                                    widget.groups[index].label,
                                  ),
                                  style: appTextStyle(
                                    context,
                                    TextStyle(
                                      color: selected
                                          ? AppSegmentedStyle.foreground(
                                              context,
                                              true,
                                            )
                                          : null,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: appColor(context, Color(0xff385064)),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(10),
                      itemCount: group.pools.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 5),
                      itemBuilder: (context, index) {
                        final pool = group.pools[index];
                        final selected = pool.key == widget.selectedPoolKey;
                        return Material(
                          color: appColor(
                            context,
                            selected
                                ? const Color(0xff1d5f91)
                                : const Color(0xff172a38),
                          ),
                          borderRadius: BorderRadius.circular(7),
                          child: InkWell(
                            key: Key(
                              'development-secretary-option-${pool.key}',
                            ),
                            borderRadius: BorderRadius.circular(7),
                            onTap: () => Navigator.of(context).pop(pool.key),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      developmentPoolText(
                                        context,
                                        _poolDisplayLabel(
                                          pool,
                                          widget.locale,
                                          otherLabel: widget.otherLabel,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: appTextStyle(
                                        context,
                                        TextStyle(
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 19,
                                      color: appColor(
                                        context,
                                        Color(0xff68b7ef),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _poolDisplayLabel(
  DevelopmentPoolRecord pool,
  Locale locale, {
  String? otherLabel,
}) {
  final label = otherLabel == null
      ? pool.label(locale)
      : _poolLabelParts(pool.label(locale), otherLabel).$2;
  final description = pool.description(locale).trim();
  return description.isEmpty ? label : '$label（$description）';
}

(String, String) _poolLabelParts(String label, String otherLabel) {
  final hyphen = label.indexOf(RegExp('[-－]'));
  if (hyphen <= 0 || hyphen >= label.length - 1) return (otherLabel, label);
  return (
    label.substring(0, hyphen).trim(),
    label.substring(hyphen + 1).trim(),
  );
}
