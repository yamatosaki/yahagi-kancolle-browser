import 'package:flutter/material.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

import '../browser/gadget_bypass_channel.dart';
import '../browser/gadget_bypass_controller.dart';
import '../browser/gadget_bypass_store.dart';

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
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _selectedPreset = _presetFor(widget.controller.endpoint);
    _customController = TextEditingController(text: widget.controller.endpoint);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
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

  Future<void> _applyCustomEndpoint() async {
    final value = _customController.text.trim();
    if (value.isEmpty) {
      _customController.text = widget.controller.endpoint;
      return;
    }
    final applied = await _setEndpoint(value);
    if (!applied) {
      _customController.text = widget.controller.endpoint;
    }
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
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SwitchListTile(
              key: const Key('gadget-bypass-switch'),
              value: controller.enabled,
              activeTrackColor: const Color(0xffb98a28),
              activeThumbColor: const Color(0xff403923),
              title: Text(
                l10n?.gadgetBypassEnable ?? '开启绕行',
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                l10n?.gadgetBypassDesc ?? '仅影响游戏客户端文件加载',
                style: const TextStyle(fontSize: 12, color: Color(0xff8197a5)),
              ),
              onChanged: controller.isApplying || !controller.supported
                  ? null
                  : _setEnabled,
            ),
            if (!controller.supported)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l10n?.gadgetBypassUnsupported ?? '当前设备不支持（需要 Android 8.0+）',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xffe0a35f),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: DropdownButtonFormField<String>(
                key: const Key('gadget-bypass-endpoint-dropdown'),
                initialValue: _selectedPreset,
                isExpanded: true,
                dropdownColor: const Color(0xff142735),
                style: const TextStyle(fontSize: 13, color: Color(0xffdce6eb)),
                decoration: InputDecoration(
                  labelText: l10n?.gadgetBypassEndpoint ?? '镜像端点',
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff8197a5),
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
                    child: Text(l10n?.endpointCustom ?? '自定义'),
                  ),
                ],
                onChanged: _onPresetChanged,
              ),
            ),
            if (_selectedPreset == _presetCustom)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  key: const Key('gadget-bypass-custom-endpoint'),
                  controller: _customController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/cache/',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _applyCustomEndpoint(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      controller.enabled
                          ? '${l10n?.gadgetBypassStatusOn ?? '已启用'} · ${controller.endpoint}'
                          : l10n?.gadgetBypassStatusOff ?? '未启用',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: controller.enabled
                            ? const Color(0xff9eb2bd)
                            : const Color(0xff5c7482),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('gadget-bypass-clear-cache'),
                    onPressed: () => controller.clearCache(),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xff8fa8b6),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      l10n?.gadgetBypassClearCache ?? '清空缓存',
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
                        ? (l10n?.gadgetBypassDiagnosing ?? '诊断中...')
                        : l10n?.gadgetBypassDiagnose ?? '运行连通性诊断',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xff8fa8b6),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ),
            if (controller.lastDiagnose != null) ...<Widget>[
              _diagnoseRow(
                key: 'gadget-bypass-diagnose-w00g',
                label: l10n?.gadgetBypassW00g ?? '客户端服务器 (w00g)',
                probe: controller.lastDiagnose!.w00g,
              ),
              _diagnoseRow(
                key: 'gadget-bypass-diagnose-endpoint',
                label: l10n?.gadgetBypassEndpointProbe ?? '镜像端点',
                probe: controller.lastDiagnose!.endpoint,
              ),
            ],
            if (controller.lastError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '${l10n?.gadgetBypassError ?? '绕行配置失败'}: ${controller.lastError}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xffe07a6a),
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
    final statusText = statusCode == 403
        ? 'HTTP 403 · 受限 (${probe.elapsedMs}ms)'
        : ok
        ? '${AppLocalizations.of(context)?.gadgetBypassReachable ?? '通畅'} · HTTP $statusCode (${probe.elapsedMs}ms)'
        : probe.reachable && statusCode != null
        ? 'HTTP $statusCode (${probe.elapsedMs}ms)'
        : AppLocalizations.of(context)?.gadgetBypassUnreachable ?? '无法连接';
    return Padding(
      key: Key(key),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xff8197a5)),
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ok
                  ? const Color(0xff4caf50)
                  : statusCode == 403
                  ? const Color(0xffffc940)
                  : const Color(0xfff44336),
            ),
          ),
        ],
      ),
    );
  }
}
