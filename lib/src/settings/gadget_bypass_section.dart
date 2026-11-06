import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/gadget_bypass_channel.dart';
import '../browser/gadget_bypass_controller.dart';
import '../browser/gadget_bypass_store.dart';
import '../widgets/standalone_text_input_dialog.dart';
import 'settings_ui_helpers.dart';

class GadgetBypassSection extends StatefulWidget {
  const GadgetBypassSection({
    super.key,
    required this.controller,
    this.onReloadRequired,
  });

  final GadgetBypassController controller;
  final Future<void> Function()? onReloadRequired;

  @override
  State<GadgetBypassSection> createState() => _GadgetBypassSectionState();
}

class _GadgetBypassSectionState extends State<GadgetBypassSection> {
  static const String _presetKcwiki = 'kcwiki';
  static const String _presetLuckyjervis = 'luckyjervis';
  static const String _presetCustom = 'custom';

  late String _selectedPreset;

  @override
  void initState() {
    super.initState();
    _selectedPreset = _presetFor(widget.controller.endpoint);
  }

  String _presetFor(String endpoint) {
    if (endpoint == kDefaultGadgetBypassEndpoint) return _presetKcwiki;
    if (endpoint == kLuckyjervisGadgetBypassEndpoint) {
      return _presetLuckyjervis;
    }
    return _presetCustom;
  }

  Future<void> _onPresetChanged(String? preset) async {
    if (preset == null) return;
    setState(() => _selectedPreset = preset);
    switch (preset) {
      case _presetKcwiki:
        await _setEndpoint(kDefaultGadgetBypassEndpoint);
      case _presetLuckyjervis:
        await _setEndpoint(kLuckyjervisGadgetBypassEndpoint);
      case _presetCustom:
        break;
    }
  }

  Future<void> _editCustomEndpoint(AppLocalizations l10n) async {
    final value = await showDialog<String>(
      barrierDismissible: false,
      context: context,
      builder: (_) => StandaloneTextInputDialog(
        key: const Key('gadget-bypass-endpoint-dialog'),
        title: l10n.gadgetBypassEndpoint,
        label: l10n.endpointCustom,
        initialValue: widget.controller.endpoint,
        fieldKey: const Key('gadget-bypass-endpoint-dialog-field'),
        cancelKey: const Key('gadget-bypass-endpoint-dialog-cancel'),
        confirmKey: const Key('gadget-bypass-endpoint-dialog-confirm'),
        cancelLabel: l10n.cancel,
        confirmLabel: l10n.confirm,
        keyboardType: TextInputType.url,
        validate: (raw) =>
            normalizeGadgetBypassEndpoint(raw) == null ? 'HTTPS URL' : null,
      ),
    );
    if (!mounted || value == null) return;
    await _setEndpoint(value);
  }

  Future<bool> _setEndpoint(String endpoint) async {
    final wasEnabled = widget.controller.enabled;
    final applied = await widget.controller.setEndpoint(endpoint);
    if (applied && wasEnabled) await widget.onReloadRequired?.call();
    return applied;
  }

  Future<void> _setEnabled(bool enabled) async {
    final applied = await widget.controller.setEnabled(enabled);
    if (applied) await widget.onReloadRequired?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
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
                          l10n.gadgetBypassEnable,
                          style: appTextStyle(
                            context,
                            SettingsTileTypography.title,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.gadgetBypassDesc,
                          style: appTextStyle(
                            context,
                            SettingsTileTypography.description,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    key: const Key('gadget-bypass-switch'),
                    value: controller.enabled,
                    activeTrackColor: appColor(
                      context,
                      const Color(0xffb98a28),
                    ),
                    activeThumbColor: appColor(
                      context,
                      const Color(0xff403923),
                    ),
                    onChanged: controller.isApplying || !controller.supported
                        ? null
                        : _setEnabled,
                  ),
                ],
              ),
            ),
            if (!controller.supported)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n.gadgetBypassUnsupported,
                  style: TextStyle(
                    fontSize: 12,
                    color: appColor(context, Color(0xffe0a35f)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: DropdownButtonFormField<String>(
                barrierDismissible: false,
                key: const Key('gadget-bypass-endpoint-dropdown'),
                initialValue: _selectedPreset,
                isExpanded: true,
                dropdownColor: appColor(context, const Color(0xff142735)),
                style: TextStyle(
                  fontSize: 13,
                  color: appColor(context, Color(0xffdce6eb)),
                ),
                decoration: InputDecoration(
                  labelText: l10n.gadgetBypassEndpoint,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: appColor(context, Color(0xff8197a5)),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: _presetKcwiki,
                    child: Text('kcwiki.github.io/cache'),
                  ),
                  DropdownMenuItem(
                    value: _presetLuckyjervis,
                    child: Text('luckyjervis.com'),
                  ),
                  DropdownMenuItem(
                    value: _presetCustom,
                    child: Text(l10n.endpointCustom),
                  ),
                ],
                onChanged: _onPresetChanged,
              ),
            ),
            if (_selectedPreset == _presetCustom)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  key: const Key('gadget-bypass-custom-endpoint'),
                  color: appColor(context, Colors.transparent),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: appColor(context, Color(0xff8197a5)),
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _editCustomEndpoint(l10n),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              controller.endpoint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const Icon(Icons.edit_outlined, size: 17),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      controller.enabled
                          ? '${l10n.gadgetBypassStatusOn} · ${controller.endpoint}'
                          : l10n.gadgetBypassStatusOff,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: appTextStyle(
                        context,
                        TextStyle(
                          fontSize: 11,
                          color: controller.enabled
                              ? const Color(0xff9eb2bd)
                              : const Color(0xff5c7482),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('gadget-bypass-clear-cache'),
                    onPressed: () => controller.clearCache(),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: appColor(context, Color(0xff8fa8b6)),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      l10n.gadgetBypassClearCache,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('gadget-bypass-diagnose-button'),
                  onPressed: controller.isDiagnosing
                      ? null
                      : () => controller.diagnose(),
                  icon: const Icon(Icons.network_check, size: 16),
                  label: Text(
                    controller.isDiagnosing
                        ? l10n.gadgetBypassDiagnosing
                        : l10n.gadgetBypassDiagnose,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: appColor(context, Color(0xff8fa8b6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ),
            if (controller.lastDiagnose != null) ...<Widget>[
              _diagnoseRow(
                key: 'gadget-bypass-diagnose-w00g',
                label: l10n.gadgetBypassW00g,
                probe: controller.lastDiagnose!.w00g,
              ),
              _diagnoseRow(
                key: 'gadget-bypass-diagnose-endpoint',
                label: l10n.gadgetBypassEndpointProbe,
                probe: controller.lastDiagnose!.endpoint,
              ),
            ],
            if (controller.lastError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '${l10n.gadgetBypassError}: ${controller.lastError}',
                  style: TextStyle(
                    fontSize: 11,
                    color: appColor(context, Color(0xffe07a6a)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _diagnoseRow({
    required String key,
    required String label,
    required GadgetBypassProbe probe,
  }) {
    final statusCode = probe.statusCode;
    final ok = statusCode != null && statusCode >= 200 && statusCode < 300;
    final l10n = AppLocalizations.of(context)!;
    final statusText = statusCode == 403
        ? 'HTTP 403 · ${l10n.gadgetBypassRestricted} (${probe.elapsedMs}ms)'
        : ok
        ? '${l10n.gadgetBypassReachable} · HTTP $statusCode (${probe.elapsedMs}ms)'
        : probe.reachable && statusCode != null
        ? 'HTTP $statusCode (${probe.elapsedMs}ms)'
        : l10n.gadgetBypassUnreachable;
    return Padding(
      key: Key(key),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: appColor(context, Color(0xff8197a5)),
              ),
            ),
          ),
          Text(
            statusText,
            style: appTextStyle(
              context,
              TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ok
                    ? const Color(0xff4caf50)
                    : statusCode == 403
                    ? const Color(0xffffc940)
                    : const Color(0xfff44336),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
