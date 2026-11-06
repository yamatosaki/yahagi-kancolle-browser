import '../theme/app_palette.dart';
import 'package:flutter/material.dart';

import '../localization/ui_text.dart';
import '../localization/game_name_localizations.dart';

class LogbookFilterField {
  const LogbookFilterField({
    required this.keyName,
    required this.label,
    required this.options,
    this.optionLabelFormatter,
    this.preserveOptionNames = false,
  });

  final String keyName;
  final String label;
  final List<String> options;
  final String Function(String)? optionLabelFormatter;

  /// The first option is the app's "all" choice; remaining names are data.
  final bool preserveOptionNames;
}

Future<Map<String, String>?> showLogbookFilterPanel({
  required BuildContext context,
  required Rect anchor,
  required String title,
  required List<LogbookFilterField> fields,
  required Map<String, String> values,
  required Map<String, String> defaults,
}) {
  final overlay = Navigator.of(
    context,
    rootNavigator: true,
  ).overlay?.context.findRenderObject();
  final localAnchor = overlay is RenderBox
      ? Rect.fromPoints(
          overlay.globalToLocal(anchor.topLeft),
          overlay.globalToLocal(anchor.bottomRight),
        )
      : anchor;
  return showGeneralDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    barrierLabel: uiText(context, '关闭筛选'),
    barrierColor: appColor(context, Colors.transparent),
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (context, animation, secondaryAnimation) => _FilterPanelRoute(
      anchor: localAnchor,
      title: title,
      fields: fields,
      values: values,
      defaults: defaults,
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
  );
}

class _FilterPanelRoute extends StatefulWidget {
  const _FilterPanelRoute({
    required this.anchor,
    required this.title,
    required this.fields,
    required this.values,
    required this.defaults,
  });

  final Rect anchor;
  final String title;
  final List<LogbookFilterField> fields;
  final Map<String, String> values;
  final Map<String, String> defaults;

  @override
  State<_FilterPanelRoute> createState() => _FilterPanelRouteState();
}

class _FilterPanelRouteState extends State<_FilterPanelRoute> {
  late Map<String, String> _draft;

  @override
  void initState() {
    super.initState();
    _draft = Map<String, String>.from(widget.values);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final panelWidth = (screen.width - 16).clamp(280.0, 304.0).toDouble();
    final estimatedHeight = widget.fields.length > 2 ? 224.0 : 164.0;
    final top = widget.anchor.bottom + 4 + estimatedHeight <= screen.height
        ? widget.anchor.bottom + 4
        : (widget.anchor.top - estimatedHeight - 4).clamp(8.0, screen.height);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            top: top.toDouble(),
            right: 8,
            width: panelWidth,
            child: _panel(),
          ),
        ],
      ),
    );
  }

  Widget _panel() => Container(
    key: const Key('logbook-filter-panel'),
    padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
    decoration: BoxDecoration(
      color: appColor(context, Color(0xff0b202d)),
      border: Border.all(color: appColor(context, Color(0xff315064))),
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: appColor(context, Color(0x66000000)),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          uiText(context, widget.title),
          style: appTextStyle(
            context,
            TextStyle(
              color: appColor(context, Color(0xffffc84d)),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                for (final field in widget.fields)
                  SizedBox(width: width, child: _field(field)),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _FilterActionButton(
              key: const Key('logbook-filter-reset'),
              label: uiText(context, '重置'),
              onTap: () => setState(
                () => _draft = Map<String, String>.from(widget.defaults),
              ),
            ),
            const SizedBox(width: 8),
            _FilterActionButton(
              key: const Key('logbook-filter-apply'),
              label: uiText(context, '应用'),
              emphasized: true,
              onTap: () => Navigator.of(context).pop(_draft),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _field(LogbookFilterField field) {
    final fallback = field.options.first;
    final value = field.options.contains(_draft[field.keyName])
        ? _draft[field.keyName]!
        : fallback;
    return Column(
      key: Key('logbook-filter-field-${field.keyName}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          uiText(context, field.label),
          style: appTextStyle(
            context,
            TextStyle(
              color: appColor(context, Color(0xff8fa5b2)),
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: appColor(context, const Color(0xff0a1b27)),
            border: Border.all(color: appColor(context, Color(0xff315064))),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              barrierDismissible: false,
              value: value,
              isExpanded: true,
              dropdownColor: appColor(context, Color(0xff102936)),
              borderRadius: BorderRadius.circular(8),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: appColor(context, Color(0xffd7e3e9)),
                size: 18,
              ),
              style: TextStyle(
                color: appColor(context, Color(0xffd7e3e9)),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              items: [
                for (final option in field.options)
                  DropdownMenuItem<String>(
                    value: option,
                    child: Text(
                      field.preserveOptionNames && option != field.options.first
                          ? gameNames(context).entityText(
                              field.optionLabelFormatter?.call(option) ??
                                  option,
                            )
                          : uiText(
                              context,
                              gameNames(context).entityText(
                                field.optionLabelFormatter?.call(option) ??
                                    option,
                              ),
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (next) {
                if (next == null) return;
                setState(() => _draft[field.keyName] = next);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterActionButton extends StatelessWidget {
  const _FilterActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 60,
    height: 34,
    child: Material(
      color: appColor(
        context,
        emphasized ? const Color(0xff6d4b0f) : const Color(0xff183342),
      ),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: appColor(
            context,
            emphasized ? const Color(0xffc58d27) : const Color(0xff496574),
          ),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Text(
            label,
            style: appTextStyle(
              context,
              TextStyle(
                color: emphasized
                    ? const Color(0xffffd36b)
                    : const Color(0xffa9bbc5),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
