final class SafePageAddress {
  static const Set<String> _trustedGameRoots = <String>{
    'dmm.com',
    'dmm.co.jp',
    'kancolle-server.com',
  };

  const SafePageAddress._(this.displayText);

  final String displayText;

  factory SafePageAddress.fromRaw(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !canNavigate(uri)) {
      return const SafePageAddress._('未知页面');
    }

    final safePathSegments = uri.pathSegments
        .takeWhile((segment) => segment != '=' && !segment.contains('='))
        .toList(growable: false);
    final sanitized = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: safePathSegments,
    );
    return SafePageAddress._(sanitized.toString());
  }

  static bool canNavigate(Uri uri) {
    return (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static bool canNavigateInGameWebView(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return _trustedGameRoots.any(
      (root) => host == root || host.endsWith('.$root'),
    );
  }
}
