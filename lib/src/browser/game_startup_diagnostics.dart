import '../../l10n/app_localizations.dart';
import 'game_startup_overlay.dart';

const gameStartupStallDelay = Duration(seconds: 20);
const localHttpProxyUnreachable = 'local_http_proxy_unreachable';
const _gadgetHost = 'w00g.kancolle-server.com';
const _bootstrapPaths = <String>{
  '/gadget_html5/js/kcs_const.js',
  '/gadget_html5/js/kcs_cda.js',
  '/gadget_html5/js/kcs_content.js',
  '/gadget_html5/js/kcs_global.js',
  '/gadget_html5/js/kcs_login.js',
  '/gadget_html5/script/jquery.min.js',
};

bool isGameBootstrapResource(Uri? uri) =>
    uri != null &&
    (uri.scheme == 'https' || uri.scheme == 'http') &&
    uri.host == _gadgetHost &&
    _bootstrapPaths.contains(uri.path);

GameStartupFailure gameStartupWebFailure(
  AppLocalizations l10n, {
  required GameStartupStage stage,
  required Uri? uri,
  int? errorCode,
  String? description,
}) {
  if (stage == GameStartupStage.game && isGameBootstrapResource(uri)) {
    return gameStartupGadgetFailure(
      l10n,
      errorCode: errorCode,
      description: description,
    );
  }
  final message = switch (errorCode ?? 0) {
    403 => l10n.gameStartupPageAccessDenied,
    >= 500 && <= 599 => l10n.gameStartupPageServerError,
    -8 => l10n.gameStartupPageTimedOut,
    _ => l10n.gameStartupPageNetworkError,
  };
  final host = uri?.host;
  return GameStartupFailure(
    message,
    host: host == null || host.isEmpty ? null : host,
    code: _webErrorCode(errorCode, description),
  );
}

GameStartupFailure gameStartupGadgetFailure(
  AppLocalizations l10n, {
  int? errorCode,
  String? description,
}) => GameStartupFailure(
  l10n.gameStartupGadgetError,
  host: _gadgetHost,
  code: _webErrorCode(errorCode, description),
);

GameStartupFailure gameStartupLocalProxyFailure(
  AppLocalizations l10n, {
  String? address,
}) => GameStartupFailure(
  l10n.gameStartupLocalHttpProxyUnavailable,
  host: address,
  code: localHttpProxyUnreachable,
  help: l10n.gameStartupLocalHttpProxyHelp,
);

String? _webErrorCode(int? errorCode, String? description) {
  if (errorCode != null && errorCode >= 400 && errorCode <= 599) {
    return 'HTTP $errorCode';
  }
  final name = RegExp(
    r'^net::ERR_[A-Z0-9_]+$',
  ).stringMatch(description?.trim() ?? '');
  if (name != null) return name;
  return switch (errorCode) {
    -2 => 'ERROR_HOST_LOOKUP (-2)',
    -8 => 'ERROR_TIMEOUT (-8)',
    null || 0 => null,
    _ => 'WebView $errorCode',
  };
}
