enum NetworkValidationError {
  hostEmpty,
  controlCharacter,
  httpScheme,
  socksScheme,
  scheme,
  path,
  credentials,
  ipv6,
  portEmpty,
  portDecimal,
  portNegative,
  portZero,
  portInteger,
  portRange,
}

class NetworkSettingsValidator {
  static NetworkValidationError? validateHost(String host) {
    final trimmed = host.trim();
    if (trimmed.isEmpty) return NetworkValidationError.hostEmpty;
    if (trimmed.contains(RegExp(r'[\r\n\t]'))) {
      return NetworkValidationError.controlCharacter;
    }
    if (trimmed.contains(RegExp(r'^https?://', caseSensitive: false))) {
      return NetworkValidationError.httpScheme;
    }
    if (trimmed.contains(RegExp(r'^socks5?h?://', caseSensitive: false))) {
      return NetworkValidationError.socksScheme;
    }
    if (trimmed.contains('://')) return NetworkValidationError.scheme;
    if (trimmed.contains('/')) return NetworkValidationError.path;
    if (trimmed.contains('@')) return NetworkValidationError.credentials;

    // Check if IPv6 (contains colons).
    final colonCount = trimmed.split(':').length - 1;
    if (colonCount > 1) {
      if (trimmed.contains(RegExp(r'[^a-fA-F0-9:\[\]]'))) {
        return NetworkValidationError.ipv6;
      }
    }

    return null;
  }

  static NetworkValidationError? validatePort(String portStr) {
    final trimmed = portStr.trim();
    if (trimmed.isEmpty) return NetworkValidationError.portEmpty;
    if (trimmed.contains('.')) return NetworkValidationError.portDecimal;
    if (trimmed.contains('-') || trimmed.startsWith('-')) {
      return NetworkValidationError.portNegative;
    }
    if (trimmed == '0') return NetworkValidationError.portZero;

    final port = int.tryParse(trimmed);
    if (port == null) return NetworkValidationError.portInteger;
    if (port <= 0 || port > 65535) return NetworkValidationError.portRange;

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
