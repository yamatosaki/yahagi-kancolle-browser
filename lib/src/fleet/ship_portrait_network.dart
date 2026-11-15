import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Uses the Android TLS stack so game assets follow the app's trust policy.
final class ShipPortraitNetwork extends ChangeNotifier {
  ShipPortraitNetwork([
    this._channel = const MethodChannel(
      'app.yahagi.kancollebrowser/ship_portrait_network',
    ),
  ]) {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  final MethodChannel _channel;
  ShipPortraitRoute? _route;
  Future<ShipPortraitRoute?>? _loading;

  static final _gameHost = RegExp(r'^w[0-9]+[a-z]\.kancolle-server\.com$');

  static bool appliesTo(Uri uri) =>
      uri.scheme == 'https' && _gameHost.hasMatch(uri.host);

  Future<ShipPortraitRoute?> currentRoute() {
    final route = _route;
    if (route != null) return SynchronousFuture(route);
    return _loading ??= _readRoute().whenComplete(() => _loading = null);
  }

  bool isCurrent(ShipPortraitRoute route) => _route?.token == route.token;

  Future<Uint8List?> fetch(Uri uri, ShipPortraitRoute route) =>
      _channel.invokeMethod<Uint8List>('fetch', {
        'uri': uri.toString(),
        'token': route.token,
      });

  Future<ShipPortraitRoute?> _readRoute() async {
    final value = await _channel
        .invokeMethod<Object?>('getRoute')
        .timeout(const Duration(seconds: 5));
    return _route ??= ShipPortraitRoute.fromMessage(value);
  }

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method != 'routeChanged') return;
    final next = ShipPortraitRoute.fromMessage(call.arguments);
    if (next == null || _route?.token == next.token) return;
    _route = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}

final class ShipPortraitRoute {
  const ShipPortraitRoute(this.token, this.kanxyActive);

  final String token;
  final bool kanxyActive;

  static ShipPortraitRoute? fromMessage(Object? message) {
    if (message is! Map) return null;
    final token = message['token'];
    final active = message['kanxyActive'];
    if (token is! String || token.isEmpty || active is! bool) return null;
    return ShipPortraitRoute(token, active);
  }
}
