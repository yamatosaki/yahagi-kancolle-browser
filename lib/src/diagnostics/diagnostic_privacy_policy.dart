final class DiagnosticPrivacyViolation implements Exception {
  const DiagnosticPrivacyViolation(this.reason);

  final String reason;

  @override
  String toString() => 'DiagnosticPrivacyViolation($reason)';
}

// Keep the wire names in sync with Android's KanxyDiagnosticStatus enum.
enum DiagnosticKanxyStatus {
  routeVpn('ROUTE_VPN'),
  routeHttp('ROUTE_HTTP'),
  routeInactive('ROUTE_INACTIVE'),
  httpPackageUnrecognized('HTTP_PACKAGE_UNRECOGNIZED'),
  httpListenerUnavailable('HTTP_LISTENER_UNAVAILABLE'),
  httpTlsUntrusted('HTTP_TLS_UNTRUSTED'),
  httpCaMismatch('HTTP_CA_MISMATCH'),
  httpTunnelFailed('HTTP_TUNNEL_FAILED'),
  httpVerified('HTTP_VERIFIED'),
  mainScriptRequested('MAIN_SCRIPT_REQUESTED'),
  mainScriptServed('MAIN_SCRIPT_SERVED'),
  mainScriptWebViewFallback('MAIN_SCRIPT_WEBVIEW_FALLBACK'),
  mainScriptBridgePrefixed('MAIN_SCRIPT_BRIDGE_PREFIXED'),
  mainScriptDropdownPatched('MAIN_SCRIPT_DROPDOWN_PATCHED'),
  mainScriptControllerPointerPatched('MAIN_SCRIPT_CONTROLLER_POINTER_PATCHED'),
  mainScriptKanxyMarker('MAIN_SCRIPT_KANXY_MARKER'),
  mainScriptMarkerMissing('MAIN_SCRIPT_MARKER_MISSING'),
  bridgeDocumentStart('BRIDGE_DOCUMENT_START'),
  bridgeMainScript('BRIDGE_MAIN_SCRIPT'),
  bridgeUnsupported('BRIDGE_UNSUPPORTED'),
  bridgeInstallFailed('BRIDGE_INSTALL_FAILED'),
  bridgePackageUnrecognized('BRIDGE_PACKAGE_UNRECOGNIZED'),
  wsRequested('WS_REQUESTED'),
  wsRouteInactive('WS_ROUTE_INACTIVE'),
  wsPackageUnrecognized('WS_PACKAGE_UNRECOGNIZED'),
  wsLimitReached('WS_LIMIT_REACHED'),
  wsOpen('WS_OPEN'),
  wsSphReceived('WS_SPH_RECEIVED'),
  wsConnectTimeout('WS_CONNECT_TIMEOUT'),
  wsListenerUnavailable('WS_LISTENER_UNAVAILABLE'),
  wsUpgradeFailed('WS_UPGRADE_FAILED'),
  wsTransportFailed('WS_TRANSPORT_FAILED'),
  wsChannelFailed('WS_CHANNEL_FAILED'),
  wsRouteClosed('WS_ROUTE_CLOSED'),
  wsDocumentClosed('WS_DOCUMENT_CLOSED'),
  wsConnectionClosed('WS_CONNECTION_CLOSED'),
  wsPeerClosed('WS_PEER_CLOSED');

  const DiagnosticKanxyStatus(this.wireName);

  final String wireName;

  static DiagnosticKanxyStatus? fromWire(Object? value) {
    if (value is! String) return null;
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

final class DiagnosticPrivacyPolicy {
  const DiagnosticPrivacyPolicy._();

  factory DiagnosticPrivacyPolicy.v1() => const DiagnosticPrivacyPolicy._();

  static final RegExp _safeKey = RegExp(r'^[A-Za-z][A-Za-z0-9]{0,63}$');
  static final RegExp _safeApiPath = RegExp(
    r'^/kcsapi/[A-Za-z0-9_./-]{1,180}$',
  );
  static final RegExp _credentialValue = RegExp(
    r'(api[_-]?token|api[_-]?starttime|authorization|bearer\s+|cookie|session\s*=|password|passwd)',
    caseSensitive: false,
  );
  static final RegExp _urlValue = RegExp(
    r'(?:https?|file|content)://',
    caseSensitive: false,
  );
  static const Set<String> _forbiddenKeyParts = <String>{
    'account',
    'username',
    'password',
    'passwd',
    'token',
    'cookie',
    'authorization',
    'apistarttime',
    'androidid',
    'advertisingid',
    'imei',
    'serial',
    'macaddress',
  };

  void validateField(String key, Object? value) {
    if (!_safeKey.hasMatch(key)) {
      throw const DiagnosticPrivacyViolation('invalid-field-name');
    }
    final normalized = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    if (_forbiddenKeyParts.any(normalized.contains)) {
      throw const DiagnosticPrivacyViolation('forbidden-field-name');
    }
    _validateValue(value);
  }

  void validateRecord(Map<String, Object?> record) {
    for (final entry in record.entries) {
      validateField(entry.key, entry.value);
    }
  }

  void validateExportDocument(Map<String, Object?> document) {
    for (final entry in document.entries) {
      if (entry.key != 'records') {
        validateField(entry.key, entry.value);
        continue;
      }

      validateField(entry.key, null);
      final records = entry.value;
      if (records is! List<Object?>) {
        throw const DiagnosticPrivacyViolation('invalid-records-list');
      }
      for (final record in records) {
        if (record is! Map<String, Object?>) {
          throw const DiagnosticPrivacyViolation('invalid-record');
        }
        validateRecord(record);
        if (record['type'] == 'kanxy') _validateKanxyRecord(record);
      }
    }
  }

  void _validateKanxyRecord(Map<String, Object?> record) {
    final occurredAt = record['occurredAt'];
    final fields = record['fields'];
    if (record.length != 3 ||
        occurredAt is! String ||
        DateTime.tryParse(occurredAt)?.toUtc().toIso8601String() !=
            occurredAt ||
        fields is! Map<String, Object?> ||
        fields.length != 1 ||
        DiagnosticKanxyStatus.fromWire(fields['status']) == null) {
      throw const DiagnosticPrivacyViolation('invalid-kanxy-record');
    }
  }

  String safeApiPath(String value) {
    if (!_safeApiPath.hasMatch(value) ||
        value.contains('?') ||
        value.contains('#')) {
      throw const DiagnosticPrivacyViolation('unsafe-api-path');
    }
    return value;
  }

  List<String> safeStack(StackTrace? stack, {int maxFrames = 24}) {
    if (stack == null) return const <String>[];
    final result = <String>[];
    final framePattern = RegExp(
      r'^#\d+\s+([^\s(]+)[^(]*\('
      r'(package:(?:flutter|yahagi_kancolle_browser)/[A-Za-z0-9_./-]+\.dart|dart:[A-Za-z0-9_./-]+)'
      r':(\d+):(\d+)\)$',
    );
    for (final rawLine in stack.toString().split(RegExp(r'\r?\n'))) {
      if (result.length >= maxFrames) break;
      final line = rawLine.trim();
      final frame = framePattern.firstMatch(line);
      if (frame == null) continue;
      final origin = frame.group(2)!;
      if (origin.split('/').contains('..')) continue;
      final symbol = frame.group(1)!;
      final safeSymbol = symbol.length <= 120
          ? symbol
          : symbol.substring(0, 120);
      // Framework frames are essential for diagnosing layout/build failures.
      // Only public Flutter package locations are retained; local paths and
      // application source locations remain excluded.
      final safeFrame = origin.startsWith('package:flutter/')
          ? '$safeSymbol (${origin.substring('package:'.length)}:${frame.group(3)}:${frame.group(4)})'
          : safeSymbol;
      try {
        _validateValue(safeFrame);
      } on DiagnosticPrivacyViolation {
        continue;
      }
      result.add(safeFrame);
    }
    return List<String>.unmodifiable(result);
  }

  void _validateValue(Object? value) {
    if (value == null || value is num || value is bool) return;
    if (value is String) {
      if (value.length > 256 || value.contains('\n') || value.contains('\r')) {
        throw const DiagnosticPrivacyViolation('unsafe-text-shape');
      }
      if (_urlValue.hasMatch(value) ||
          _credentialValue.hasMatch(value) ||
          value.contains('?')) {
        throw const DiagnosticPrivacyViolation('sensitive-text');
      }
      return;
    }
    if (value is List<Object?>) {
      if (value.length > 64) {
        throw const DiagnosticPrivacyViolation('oversized-list');
      }
      for (final child in value) {
        _validateValue(child);
      }
      return;
    }
    if (value is Map<String, Object?>) {
      validateRecord(value);
      return;
    }
    throw const DiagnosticPrivacyViolation('unsupported-value-type');
  }
}
