import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

import '../game_state/game_state.dart';

enum ExternalFleetTool { noro6, noro6Mirror, jervis }

typedef FleetToolLaunchCallback = Future<bool> Function(Uri uri);

Uri externalFleetToolUri(
  ExternalFleetTool tool,
  String deckBuilderJson, {
  required GameState state,
}) {
  if (tool == ExternalFleetTool.noro6 ||
      tool == ExternalFleetTool.noro6Mirror) {
    final importJson = _noro6ImportJson(deckBuilderJson, state);
    final baseUrl = tool == ExternalFleetTool.noro6
        ? 'https://noro6.github.io/kc-web/'
        : 'https://noro6.kcwiki.cn/';
    return Uri.parse('$baseUrl#import:${Uri.encodeComponent(importJson)}');
  }

  return Uri.parse(
    'https://fleethub.madonoharu.workers.dev/',
  ).replace(queryParameters: <String, String>{'predeck': deckBuilderJson});
}

String _noro6ImportJson(String deckBuilderJson, GameState state) {
  final ships = state.ships.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final items = state.slotItems.values.toList()
    ..sort((a, b) => a.instanceId.compareTo(b.instanceId));
  return jsonEncode(<String, Object?>{
    'ships': ships
        .map(
          (ship) => <String, Object?>{
            'id': ship.id,
            'ship_id': ship.masterId,
            'lv': ship.level,
            'exp': <int>[ship.experience, ship.nextExperience, 0],
            'ex': ship.extraSlotId != 0 ? 1 : 0,
            'area': ship.sallyArea,
            if (ship.specialEffectKinds.isNotEmpty)
              'sp': ship.specialEffectKinds,
            if (ship.maxSlotCounts.isNotEmpty) 'slots': ship.maxSlotCounts,
            if (ship.modernization.length >= 7)
              'st': ship.modernization.take(7).toList(),
          },
        )
        .toList(),
    'items': items
        .map(
          (item) => <String, Object?>{
            'id': item.masterSlotItemId,
            'lv': item.level,
          },
        )
        .toList(),
    'predeck': jsonDecode(deckBuilderJson),
  });
}

class ExternalFleetToolLauncher {
  const ExternalFleetToolLauncher({FleetToolLaunchCallback? launch})
    : _launch = launch ?? _launchInExternalApplication;

  final FleetToolLaunchCallback _launch;

  Future<bool> open(
    ExternalFleetTool tool,
    String deckBuilderJson, {
    required GameState state,
  }) => _launch(externalFleetToolUri(tool, deckBuilderJson, state: state));

  static Future<bool> _launchInExternalApplication(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
