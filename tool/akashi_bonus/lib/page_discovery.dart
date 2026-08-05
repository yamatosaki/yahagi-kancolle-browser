/// Discovers equipment ids from the akashi-list.me homepage.
library;

import 'package:html/dom.dart';

class DiscoveredWeapon {
  final int equipmentId;
  final String name;
  final String detailUrl;
  const DiscoveredWeapon(this.equipmentId, this.name, this.detailUrl);
}

class DiscoveryResult {
  final List<DiscoveredWeapon> weapons;
  final List<String> problems;
  const DiscoveryResult(this.weapons, this.problems);

  List<int> get sortedIds =>
      weapons.map((w) => w.equipmentId).toList()..sort();
}

/// Parses `.weapon[id^="w"]` nodes. Rejects malformed ids, duplicates and
/// missing alt attributes instead of guessing.
DiscoveryResult discoverWeapons(Element root, {String baseUrl = 'https://akashi-list.me'}) {
  final weapons = <DiscoveredWeapon>[];
  final problems = <String>[];
  final seen = <int>{};

  final idPattern = RegExp(r'^w(\d{3,})$');
  for (final node in root.querySelectorAll('.weapon')) {
    final idAttr = node.id;
    final m = idPattern.firstMatch(idAttr);
    if (m == null) {
      problems.add('malformed weapon id "$idAttr"');
      continue;
    }
    final equipmentId = int.parse(m.group(1)!);
    final img = node.querySelector('img');
    final alt = img?.attributes['alt'] ?? '';
    // alt is normally "266: 12.7cm連装砲C型改二"; some entries omit the
    // colon (e.g. "527 Type281 対空砲"). The id is always the leading digits.
    final nameMatch = RegExp(r'^\d+[:：]?\s*(.+)$').firstMatch(alt);
    if (nameMatch == null) {
      problems.add('weapon w$equipmentId missing alt name');
      continue;
    }
    if (!seen.add(equipmentId)) {
      problems.add('duplicate weapon id w$equipmentId');
      continue;
    }
    weapons.add(DiscoveredWeapon(
      equipmentId,
      nameMatch.group(1)!.trim(),
      '$baseUrl/detail/w$equipmentId.html',
    ));
  }
  return DiscoveryResult(weapons, problems);
}
