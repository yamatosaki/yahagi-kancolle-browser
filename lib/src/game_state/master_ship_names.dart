import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Restores ship names when a mod's disabled name override reaches the API.
final class MasterShipNames {
  const MasterShipNames([this._stockNames = const {}]);

  final Map<int, String> _stockNames;

  static Future<MasterShipNames> loadBundled() async {
    try {
      final json = await rootBundle.loadString(
        'assets/data/master_ship_names.json',
      );
      final data = jsonDecode(json) as Map<String, dynamic>;
      final names = data['names'] as Map<String, dynamic>;
      return MasterShipNames(
        Map.unmodifiable({
          for (final entry in names.entries)
            int.parse(entry.key): entry.value as String,
        }),
      );
    } catch (error) {
      debugPrint('Could not load bundled master ship names: $error');
      return const MasterShipNames();
    }
  }

  String resolve(int id, Object? name, {String? previous, String? reading}) {
    // Kanxy 1.00.1 can stringify the false sentinel before forwarding start2.
    if (name == false ||
        (name is String && name.trim().toLowerCase() == 'false')) {
      return _stockNames[id] ??
          _usableFallback(previous) ??
          _usableFallback(reading) ??
          '#$id';
    }
    return name is String ? name : '';
  }

  String? _usableFallback(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        trimmed.toLowerCase() == 'false') {
      return null;
    }
    return name;
  }
}
