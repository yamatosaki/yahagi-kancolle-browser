class NetworkSettingsValidator {
  static String? validateHost(String host) {
    final trimmed = host.trim();
    if (trimmed.isEmpty) return '地址不能为空';
    if (trimmed.contains(RegExp(r'[\r\n\t]'))) return '不允许包含换行或控制字符';
    if (trimmed.contains(RegExp(r'^https?://', caseSensitive: false))) {
      return '地址中不要包含http://，只需填写服务器地址。';
    }
    if (trimmed.contains(RegExp(r'^socks5?h?://', caseSensitive: false))) {
      return '地址中不要包含socks://，只需填写服务器地址。';
    }
    if (trimmed.contains('://')) return '地址中不要包含协议头';
    if (trimmed.contains('/')) return '不允许包含路径';
    if (trimmed.contains('@')) return '不允许包含用户名或密码';

    // Check if IPv6 (contains colons).
    final colonCount = trimmed.split(':').length - 1;
    if (colonCount > 1) {
      if (trimmed.contains(RegExp(r'[^a-fA-F0-9:\[\]]'))) {
        return 'IPv6地址格式不正确 (含有非法字符)';
      }
    }

    return null;
  }

  static String? validatePort(String portStr) {
    final trimmed = portStr.trim();
    if (trimmed.isEmpty) return '不允许为空';
    if (trimmed.contains('.')) return '不允许小数';
    if (trimmed.contains('-') || trimmed.startsWith('-')) return '不允许负数';
    if (trimmed == '0') return '不允许0';

    final port = int.tryParse(trimmed);
    if (port == null) return '必须为整数';
    if (port <= 0 || port > 65535) return '范围1至65535';

    return null;
  }

  static String formatProxyHost(String host) {
    final trimmed = host.trim();
    final colonCount = trimmed.split(':').length - 1;
    if (colonCount > 1 && !trimmed.startsWith('[')) {
      return '[$trimmed]';
    }
    return trimmed;
  }

  static String buildHttpProxyRule(String host, int port) {
    final formattedHost = formatProxyHost(host);
    return 'http://$formattedHost:$port';
  }

  static String buildSocksProxyRule(String host, int port) {
    final formattedHost = formatProxyHost(host);
    return 'socks://$formattedHost:$port';
  }
}
