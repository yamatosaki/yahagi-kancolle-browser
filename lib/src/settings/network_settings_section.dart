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
        _showErrorSnackBar(hostError);
        return;
      }
      final portError = NetworkSettingsValidator.validatePort(portStr);
      if (portError != null) {
        _showErrorSnackBar(portError);
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
        _showErrorSnackBar(hostError);
        return;
      }
      final portError = NetworkSettingsValidator.validatePort(portStr);
      if (portError != null) {
        _showErrorSnackBar(portError);
        return;
      }
    }

    final port = int.tryParse(portStr) ?? 8080;
    final formattedHost = NetworkSettingsValidator.formatProxyHost(host);
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在应用网络设置...'),
        duration: Duration(seconds: 1),
      ),
    );

    final result = await widget.controller.applySettings(
      _selectedMode,
      formattedHost,
      port,
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('网络设置应用成功: ${result.message}')));
      widget.onApplySuccess();
    } else {
      _showErrorSnackBar('设置失败 [${result.code}]: ${result.message}');
    }
  }

  Future<void> _restoreSystemNetwork() async {
    if (widget.controller.isTesting || widget.controller.isApplying) return;

    setState(() {
      _selectedMode = NetworkMode.system;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在清除应用内代理...'),
        duration: Duration(seconds: 1),
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
      ).showSnackBar(const SnackBar(content: Text('已恢复系统网络。')));
      widget.onApplySuccess();
    } else {
      _showErrorSnackBar('恢复失败 [${result.code}]: ${result.message}');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade800),
    );
  }

  Widget _buildDiagnosticCard(ProxyResult? result) {
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
            _buildDetailRow('TCP 连接', result.details['proxy']),
            _buildDetailRow('游戏服务', result.details['gameTarget']),
            _buildDetailRow('Google (外网)', result.details['google']),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic detail) {
    if (detail == null) return const SizedBox.shrink();

    final status = detail['status'] as String? ?? 'unknown';
    final elapsedMs = detail['elapsedMs'] as int? ?? 0;

    Color color = Colors.white70;
    IconData icon = Icons.help_outline;
    String statusText = '未知';

    if (status == 'success') {
      color = Colors.green.shade400;
      icon = Icons.check;
      statusText = '成功';
    } else if (status == 'failed') {
      color = Colors.red.shade400;
      icon = Icons.close;
      statusText = '失败';
    } else if (status == 'skipped') {
      color = Colors.grey.shade500;
      icon = Icons.remove;
      statusText = '跳过';
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
                  AppLocalizations.of(context)?.proxyNotSupported ??
                      '当前设备的 Android System WebView 不支持应用内代理设置。\n您只能使用系统网络或全局 VPN。',
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
                      AppLocalizations.of(context)?.systemNetwork ??
                          '系统网络 / VPN',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)?.systemNetworkDesc ??
                          '不使用应用内代理，跟随系统网络环境。',
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
                      AppLocalizations.of(context)?.httpProxy ?? 'HTTP 代理',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)?.httpProxyDesc ??
                          '连接自定义 HTTP 代理服务器。',
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
                      AppLocalizations.of(context)?.socks5Proxy ?? 'SOCKS5 代理',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)?.socks5ProxyDesc ??
                          '连接自定义 SOCKS5 代理服务器。',
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
                          labelText:
                              AppLocalizations.of(context)?.hostAddress ??
                              '主机地址 (IP 或域名)',
                          hintText:
                              AppLocalizations.of(context)?.hostHint ??
                              '如 192.168.1.10',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
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
                          labelText: AppLocalizations.of(context)?.port ?? '端口',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
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
                    '${AppLocalizations.of(context)?.currentSavedMode ?? "当前已保存模式"}: ${c.settings.mode.name}',
                    style: const TextStyle(
                      color: Color(0xff8197a5),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${AppLocalizations.of(context)?.vpnStatus ?? "VPN 状态"}: ${isVpnActive ? (AppLocalizations.of(context)?.vpnActive ?? "已检测到活动 VPN") : (AppLocalizations.of(context)?.vpnInactive ?? "未检测到活动 VPN")}',
                    style: const TextStyle(
                      color: Color(0xff8197a5),
                      fontSize: 13,
                    ),
                  ),

                  _buildDiagnosticCard(c.lastTestResult),

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
                    label: Text(
                      AppLocalizations.of(context)?.testConnection ?? '网络连接测试',
                    ),
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
                    label: Text(
                      AppLocalizations.of(context)?.applySettings ??
                          '应用设置并重新加载游戏',
                    ),
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
                        AppLocalizations.of(context)?.restoreSystemNetwork ??
                            '恢复系统网络',
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
