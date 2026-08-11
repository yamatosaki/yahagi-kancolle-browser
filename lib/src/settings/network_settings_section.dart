import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'network_settings_controller.dart';
import 'network_settings_store.dart';
import 'network_settings_validator.dart';
import '../browser/network_proxy_channel.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';

class NetworkSettingsSection extends StatefulWidget {
  const NetworkSettingsSection({
    super.key,
    required this.controller,
    required this.onApplySuccess,
  });

  final NetworkSettingsController controller;
  final VoidCallback onApplySuccess;

  @override
  State<NetworkSettingsSection> createState() => _NetworkSettingsSectionState();
}

class _NetworkSettingsSectionState extends State<NetworkSettingsSection> {
  late NetworkMode _selectedMode;
  final _hostController = TextEditingController();
  final _portController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.controller.settings.mode;
    _hostController.text = widget.controller.settings.host;
    _portController.text = widget.controller.settings.port.toString();
    widget.controller.refreshNetworkStatus();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _onModeChanged(NetworkMode? mode) {
    if (mode == null) return;
    setState(() {
      _selectedMode = mode;
      if (mode == NetworkMode.httpProxy) {
        if (_portController.text.isEmpty) {
          _portController.text = '8080';
        }
      } else if (mode == NetworkMode.socks5Proxy) {
        if (_portController.text.isEmpty || _portController.text == '8080') {
          _portController.text = '1080';
        }
      }
    });
    widget.controller.clearTestResult();
  }

  void _testConnection() {
    if (widget.controller.isTesting || widget.controller.isApplying) return;

    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();

    if (_selectedMode != NetworkMode.system) {
      final hostError = NetworkSettingsValidator.validateHost(host);
      if (hostError != null) {
        _showErrorSnackBar(_validationMessage(hostError));
        return;
      }
      final portError = NetworkSettingsValidator.validatePort(portStr);
      if (portError != null) {
        _showErrorSnackBar(_validationMessage(portError));
        return;
      }
    }

    final port = int.tryParse(portStr) ?? 8080;
    FocusScope.of(context).unfocus();
    widget.controller.testConnection(
      _selectedMode,
      NetworkSettingsValidator.formatProxyHost(host),
      port,
    );
  }

  Future<void> _applySettings() async {
    if (widget.controller.isTesting || widget.controller.isApplying) return;

    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();

    if (_selectedMode != NetworkMode.system) {
      final hostError = NetworkSettingsValidator.validateHost(host);
      if (hostError != null) {
        _showErrorSnackBar(_validationMessage(hostError));
        return;
      }
      final portError = NetworkSettingsValidator.validatePort(portStr);
      if (portError != null) {
        _showErrorSnackBar(_validationMessage(portError));
        return;
      }
    }

    final port = int.tryParse(portStr) ?? 8080;
    final formattedHost = NetworkSettingsValidator.formatProxyHost(host);
    FocusScope.of(context).unfocus();

    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.applyingNetworkSettings),
        duration: const Duration(seconds: 1),
      ),
    );

    final result = await widget.controller.applySettings(
      _selectedMode,
      formattedHost,
      port,
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.networkSettingsApplied(result.message))),
      );
      widget.onApplySuccess();
    } else {
      _showErrorSnackBar(
        l10n.networkApplyFailed(
          result.code,
          _localizedProxyResultMessage(l10n, result),
        ),
      );
    }
  }

  Future<void> _restoreSystemNetwork() async {
    if (widget.controller.isTesting || widget.controller.isApplying) return;

    setState(() {
      _selectedMode = NetworkMode.system;
    });

    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.clearingProxy),
        duration: const Duration(seconds: 1),
      ),
    );

    final result = await widget.controller.applySettings(
      NetworkMode.system,
      '',
      8080,
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.systemNetworkRestored)));
      widget.onApplySuccess();
    } else {
      _showErrorSnackBar(
        l10n.networkRestoreFailed(result.code, result.message),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade800),
    );
  }

  String _validationMessage(NetworkValidationError error) {
    final l10n = AppLocalizations.of(context)!;
    return switch (error) {
      NetworkValidationError.hostEmpty => l10n.networkValidationHostEmpty,
      NetworkValidationError.controlCharacter =>
        l10n.networkValidationControlCharacter,
      NetworkValidationError.httpScheme => l10n.networkValidationHttpScheme,
      NetworkValidationError.socksScheme => l10n.networkValidationSocksScheme,
      NetworkValidationError.scheme => l10n.networkValidationScheme,
      NetworkValidationError.path => l10n.networkValidationPath,
      NetworkValidationError.credentials => l10n.networkValidationCredentials,
      NetworkValidationError.ipv6 => l10n.networkValidationIpv6,
      NetworkValidationError.portEmpty => l10n.networkValidationPortEmpty,
      NetworkValidationError.portDecimal => l10n.networkValidationPortDecimal,
      NetworkValidationError.portNegative => l10n.networkValidationPortNegative,
      NetworkValidationError.portZero => l10n.networkValidationPortZero,
      NetworkValidationError.portInteger => l10n.networkValidationPortInteger,
      NetworkValidationError.portRange => l10n.networkValidationPortRange,
    };
  }

  String _localizedProxyResultMessage(
    AppLocalizations l10n,
    ProxyResult result,
  ) => switch (result.code) {
    'proxy_operation_busy' => l10n.networkProxyOperationBusy,
    'unknown_mode' => l10n.networkUnknownProxyMode,
    _ => result.message,
  };

  Widget _buildDiagnosticCard(AppLocalizations l10n, ProxyResult? result) {
    if (result == null) return const SizedBox.shrink();

    final success = result.success;
    final isWarning = result.code == 'warning';

    Color headerColor = success ? Colors.green.shade400 : Colors.red.shade400;
    if (isWarning) headerColor = Colors.orange.shade400;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff142a35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: headerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: headerColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.message,
                  style: TextStyle(
                    color: headerColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${result.elapsedMs}ms',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          if (result.details.isNotEmpty) ...[
            const Divider(color: Color(0xff294052)),
            _buildDetailRow(l10n, l10n.tcpConnection, result.details['proxy']),
            _buildDetailRow(
              l10n,
              l10n.gameService,
              result.details['gameTarget'],
            ),
            _buildDetailRow(
              l10n,
              l10n.externalNetwork,
              result.details['google'],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(AppLocalizations l10n, String label, dynamic detail) {
    if (detail == null) return const SizedBox.shrink();

    final status = detail['status'] as String? ?? 'unknown';
    final elapsedMs = detail['elapsedMs'] as int? ?? 0;

    Color color = Colors.white70;
    IconData icon = Icons.help_outline;
    String statusText = l10n.statusUnknown;

    if (status == 'success') {
      color = Colors.green.shade400;
      icon = Icons.check;
      statusText = l10n.statusSuccess;
    } else if (status == 'failed') {
      color = Colors.red.shade400;
      icon = Icons.close;
      statusText = l10n.statusFailed;
    } else if (status == 'skipped') {
      color = Colors.grey.shade500;
      icon = Icons.remove;
      statusText = l10n.statusSkipped;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
          if (status == 'success' || status == 'failed')
            Text(
              '${elapsedMs}ms',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final l10n =
            AppLocalizations.of(context) ??
            lookupAppLocalizations(const Locale('zh'));
        final c = widget.controller;
        final bool isProxySupported = c.isProxyOverrideSupported;
        final bool isVpnActive = c.networkStatus.hasVpn;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isProxySupported)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700),
                ),
                child: Text(
                  l10n.proxyNotSupported,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),

            RadioGroup<NetworkMode>(
              groupValue: _selectedMode,
              onChanged: _onModeChanged,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RadioListTile<NetworkMode>(
                    title: Text(
                      l10n.systemNetwork,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.systemNetworkDesc,
                      style: const TextStyle(
                        color: Color(0xff8197a5),
                        fontSize: 12,
                      ),
                    ),
                    value: NetworkMode.system,
                    activeColor: const Color(0xffd4a85f),
                  ),
                  RadioListTile<NetworkMode>(
                    title: Text(
                      l10n.httpProxy,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.httpProxyDesc,
                      style: const TextStyle(
                        color: Color(0xff8197a5),
                        fontSize: 12,
                      ),
                    ),
                    value: NetworkMode.httpProxy,
                    activeColor: const Color(0xffd4a85f),
                    enabled: isProxySupported,
                  ),
                  RadioListTile<NetworkMode>(
                    title: Text(
                      l10n.socks5Proxy,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.socks5ProxyDesc,
                      style: const TextStyle(
                        color: Color(0xff8197a5),
                        fontSize: 12,
                      ),
                    ),
                    value: NetworkMode.socks5Proxy,
                    activeColor: const Color(0xffd4a85f),
                    enabled: isProxySupported,
                  ),
                ],
              ),
            ),

            if (_selectedMode != NetworkMode.system)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _hostController,
                        decoration: InputDecoration(
                          labelText: l10n.hostAddress,
                          hintText: l10n.hostHint,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.port,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(color: Color(0xff294052), height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${l10n.currentSavedMode}: ${c.settings.mode.name}',
                    style: const TextStyle(
                      color: Color(0xff8197a5),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${l10n.vpnStatus}: ${isVpnActive ? l10n.vpnActive : l10n.vpnInactive}',
                    style: const TextStyle(
                      color: Color(0xff8197a5),
                      fontSize: 13,
                    ),
                  ),

                  _buildDiagnosticCard(l10n, c.lastTestResult),

                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: c.isTesting || c.isApplying
                        ? null
                        : _testConnection,
                    icon: c.isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.speed, size: 18),
                    label: Text(l10n.testConnection),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff183631),
                      foregroundColor: const Color(0xff80c8bd),
                    ),
                  ),

                  const SizedBox(height: 8),

                  ElevatedButton.icon(
                    onPressed: c.isApplying || c.isTesting
                        ? null
                        : _applySettings,
                    icon: c.isApplying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(l10n.applySettings),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffd4a85f),
                      foregroundColor: Colors.black87,
                    ),
                  ),

                  if (_selectedMode != NetworkMode.system) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: c.isApplying || c.isTesting
                          ? null
                          : _restoreSystemNetwork,
                      child: Text(
                        l10n.restoreSystemNetwork,
                        style: const TextStyle(color: Color(0xff8197a5)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
