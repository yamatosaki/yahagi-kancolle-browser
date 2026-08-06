/// Resolves ship names, group labels and equipment names against the
/// KCSAPI master data dump (api_start2).
///
/// The resolver only maps *exact* names. Everything else is reported as
/// unresolved; nothing is guessed from strings.
library;

import 'dart:convert';
import 'dart:io';

class MasterData {
  final Map<String, List<int>> shipIdsByName;
  final Map<int, Map<String, dynamic>> shipsById;
  final Map<int, Map<String, dynamic>> itemsById;
  final Map<String, List<int>> itemIdsByName;
  final Map<int, int> ctypeByShip;
  final Map<int, List<int>> shipsByCtype;
  final Map<int, String> stypeNames;
  final Map<int, List<int>> shipsByStype;

  MasterData._({
    required this.shipIdsByName,
    required this.shipsById,
    required this.itemsById,
    required this.itemIdsByName,
    required this.ctypeByShip,
    required this.shipsByCtype,
    required this.stypeNames,
    required this.shipsByStype,
  });

  factory MasterData.fromJsonFile(String path) {
    final raw = File(path).readAsStringSync();
    return MasterData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory MasterData.fromJson(Map<String, dynamic> data) {
    final ships = (data['api_mst_ship'] as List).cast<Map<String, dynamic>>();
    final items =
        (data['api_mst_slotitem'] as List).cast<Map<String, dynamic>>();
    final stypes = (data['api_mst_stype'] as List).cast<Map<String, dynamic>>();

    final byName = <String, List<int>>{};
    final byId = <int, Map<String, dynamic>>{};
    final ctype = <int, int>{};
    final byCtype = <int, List<int>>{};
    for (final s in ships) {
      final id = (s['api_id'] as num).toInt();
      final name = (s['api_name'] as String?) ?? '';
      byId[id] = s;
      byName.putIfAbsent(name, () => []).add(id);
      final ct = (s['api_ctype'] as num?)?.toInt();
      if (ct != null) {
        ctype[id] = ct;
        byCtype.putIfAbsent(ct, () => []).add(id);
      }
    }
    final itemsById = <int, Map<String, dynamic>>{};
    final itemsByName = <String, List<int>>{};
    for (final i in items) {
      final id = (i['api_id'] as num).toInt();
      itemsById[id] = i;
      final name = (i['api_name'] as String?) ?? '';
      if (name.isNotEmpty) {
        itemsByName.putIfAbsent(name, () => []).add(id);
      }
    }
    final stypeNames = <int, String>{};
    final byStype = <int, List<int>>{};
    for (final st in stypes) {
      final id = (st['api_id'] as num).toInt();
      stypeNames[id] = (st['api_name'] as String?) ?? '';
    }
    for (final s in ships) {
      final id = (s['api_id'] as num).toInt();
      final st = (s['api_stype'] as num?)?.toInt();
      if (st != null) {
        byStype.putIfAbsent(st, () => []).add(id);
      }
    }
    return MasterData._(
      shipIdsByName: byName,
      shipsById: byId,
      itemsById: itemsById,
      itemIdsByName: itemsByName,
      ctypeByShip: ctype,
      shipsByCtype: byCtype,
      stypeNames: stypeNames,
      shipsByStype: byStype,
    );
  }

  String? shipName(int id) =>
      (shipsById[id]?['api_name'] as String?) ?? '';
}

/// Resolution of one target token.
sealed class TargetResolution {
  const TargetResolution();
}

class TargetResolved extends TargetResolution {
  /// Explicit ship ids (tipbody group or exact ship name).
  final List<int> shipIds;
  final String sourceLabel;

  /// Master class ids when the group is a strict class (ctype) group.
  final List<int> classIds;

  /// Master ship type ids when the token is a ship-type name.
  final List<int> shipTypeIds;
  const TargetResolved({
    required this.shipIds,
    required this.sourceLabel,
    this.classIds = const [],
    this.shipTypeIds = const [],
  });
}

class TargetUnresolved extends TargetResolution {
  final String token;
  final String reason;
  const TargetUnresolved(this.token, this.reason);
}

/// Japanese ship-type names → master `api_mst_stype` ids.
const Map<String, List<int>> kShipTypeNameToIds = <String, List<int>>{  '海防艦': [1],
  '駆逐艦': [2],
  '駆逐': [2],
  '軽巡洋艦': [3],
  '軽巡': [3],
  '重雷装巡洋艦': [4],
  '雷巡': [4],
  '重巡洋艦': [5],
  '重巡': [5],
  '航空巡洋艦': [6],
  '航巡': [6],
  '軽空母': [7],
  '戦艦': [8, 9, 12],
  '航空戦艦': [10],
  '正規空母': [11],
  '空母': [11],
  '超弩級戦艦': [12],
  '潜水艦': [13],
  '潜水空母': [14],
  '補給艦': [15, 22],
  '水上機母艦': [16],
  '水母': [16],
  '揚陸艦': [17],
  '装甲空母': [18],
  '工作艦': [19],
  '潜水母艦': [20],
  '練習巡洋艦': [21],
  '練巡': [21],
};

/// Ship-type part of nationality+type labels (`駆逐艦`, `軽巡級`, `空母`...)
/// → master `api_mst_stype` ids.
const Map<String, List<int>> _kNationalityTypeSet = <String, List<int>>{
  '駆逐艦': [2],
  '駆逐': [2],
  '軽巡洋艦': [3],
  '軽巡級': [3],
  '軽巡': [3],
  '重巡洋艦': [5],
  '重巡級': [5],
  '重巡': [5],
  '巡洋艦': [3, 4, 5, 6],
  '戦艦': [8, 9, 10, 12],
  '空母': [7, 11, 18],
  '軽空母': [7],
  '正規空母': [11],
  '装甲空母': [18],
  '潜水艦': [13, 14],
  '水母': [16],
  '海防艦': [1],
};

/// Resolves target tokens using the page's tipbody groups plus master data.
class TargetGroupResolver {
  final MasterData master;

  /// tipbody label → ship names, page order.
  final Map<String, List<String>> tipGroups;

  /// Nationality label (アメリカ艦, イタリア艦...) → master ship ids,
  /// sourced from wikiwiki 艦娘名一覧（艦種別）nationality groups.
  final Map<String, List<int>> nationalities;

  TargetGroupResolver(this.master, this.tipGroups,
      {this.nationalities = const {}});

  /// All player ships minus every foreign ship listed in [nationalities].
  /// Enemy ships (id >= 1500) are always excluded.
  List<int> get _japaneseShips {
    final foreign = <int>{};
    for (final ids in nationalities.values) {
      foreign.addAll(ids);
    }
    final all = <int>{};
    for (final ids in master.shipsByStype.values) {
      all.addAll(ids);
    }
    return (all
          ..removeAll(foreign)
          ..removeWhere((id) => id >= 1500))
        .toList()
      ..sort();
  }

  TargetResolution resolve(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      return const TargetUnresolved('', 'empty token');
    }
    // Stacking notes that stand alone (`(重複可)`, `(重複不可)`) contribute
    // nothing.
    if (RegExp(r'^\(重複[^)]*\)$').hasMatch(trimmed)) {
      return const TargetResolved(shipIds: [], sourceLabel: '');
    }
    // `他/その他` prefix: "the remaining ships of the group" — resolve the
    // group itself (the page's exclusion list is not tracked here; the
    // approximation is recorded in the delivery report).
    final otherM = RegExp(r'^(?:その他|他)(.+)$').firstMatch(trimmed);
    if (otherM != null) {
      final inner = resolve(otherM.group(1)!.trim());
      if (inner is TargetResolved) {
        return inner;
      }
    }
    // Exclusion notes: `陽炎型改二(雪風改二・秋雲改二除く)` → resolve the
    // base group and subtract the excluded ships.
    final exclM =
        RegExp(r'^(.+?)\(([^()]*?)(?:を)?除く\)$').firstMatch(trimmed);
    if (exclM != null) {
      final base = resolve(exclM.group(1)!.trim());
      if (base is TargetResolved) {
        final excluded = <int>{};
        for (final n in exclM
            .group(2)!
            .split(RegExp(r'[・、\s]+'))
            .where((p) => p.isNotEmpty)) {
          final ids = _lookupShipName(n);
          if (ids.isEmpty) {
            return TargetUnresolved(trimmed, 'excluded ship "$n" unknown');
          }
          excluded.addAll(ids);
        }
        final remaining =
            base.shipIds.where((id) => !excluded.contains(id)).toList();
        return TargetResolved(
          shipIds: remaining,
          classIds: base.classIds,
          shipTypeIds: base.shipTypeIds,
          sourceLabel: trimmed,
        );
      }
    }
    // 1. Explicit ship name (with normalization: strip stacking notes like
    //    `(重複可)` / `(重複不可)` / form notes, merge `矢矧改二/乙`).
    final direct = _lookupShipName(trimmed);
    if (direct.isNotEmpty) {
      return TargetResolved(shipIds: direct, sourceLabel: trimmed);
    }
    // Trailing note parentheses (`伊勢型改二(重複可)`, `全艦娘(重複可)`):
    // retry the remaining resolution paths on the stripped form.
    final stripped = trimmed.replaceFirst(RegExp(r'\([^()]*\)$'), '').trim();
    if (stripped != trimmed && stripped.isNotEmpty) {
      final inner = resolve(stripped);
      if (inner is TargetResolved) {
        return inner;
      }
    }
    // 2. Tipbody group label? Ships listed there get the same name
    //    normalization as fit targets; a group with ships missing from
    //    master falls back to the other resolution paths instead of
    //    failing the whole token. Labels match whitespace-insensitively
    //    (`赤城型改二 / 戊 / 護` ≡ `赤城型改二/戊/護`).
    final tipShips = tipGroups[trimmed] ??
        tipGroups.entries
            .where((e) => e.key.replaceAll(' ', '') == trimmed.replaceAll(' ', ''))
            .map((e) => e.value)
            .firstOrNull;
    if (tipShips != null && tipShips.isNotEmpty) {
      final shipIds = <int>[];
      var complete = true;
      for (final n in tipShips) {
        final nids = _lookupShipName(n);
        if (nids.isEmpty) {
          complete = false;
          break;
        }
        if (nids.length != 1) {
          complete = false;
          break;
        }
        shipIds.add(nids.first);
      }
      if (complete) {
        return TargetResolved(shipIds: shipIds, sourceLabel: trimmed);
      }
      // Partial resolution: keep the ships that resolve so a typo or a
      // missing master entry does not sink the whole group.
      final partial = <int>[];
      for (final n in tipShips) {
        final nids = _lookupShipName(n);
        if (nids.length == 1) partial.add(nids.first);
      }
      if (partial.isNotEmpty) {
        return TargetResolved(
            shipIds: partial..sort(), sourceLabel: trimmed);
      }
    }
    // 3. Strict class label "X型" via master ctype of ship X.
    if (trimmed.endsWith('型') && !trimmed.contains('改')) {
      final baseName = trimmed.substring(0, trimmed.length - 1);
      final baseIds = master.shipIdsByName[baseName];
      if (baseIds != null && baseIds.length == 1) {
        final ct = master.ctypeByShip[baseIds.first];
        if (ct != null) {
          final classShips = (master.shipsByCtype[ct] ?? const <int>[]).where((id) => id < 1500).toList();
          if (classShips.isNotEmpty) {
            return TargetResolved(
              shipIds: List<int>.from(classShips)..sort(),
              classIds: [ct],
              sourceLabel: trimmed,
            );
          }
        }
      }
    }
    // 4. Ship type name (駆逐艦, 軽巡洋艦, 雷巡, 練巡...) → shipTypeIds.
    final typeIds = kShipTypeNameToIds[trimmed];
    if (typeIds != null) {
      return TargetResolved(
        shipIds: const [],
        classIds: const [],
        sourceLabel: trimmed,
        shipTypeIds: typeIds,
      );
    }
    // 4b. Nationality (+ ship type) labels: `イタリア艦`, `アメリカ駆逐艦`,
    //     `日本軽巡級` → ships of that nationality (from the wikiwiki
    //     nationality groups) filtered by the ship type.
    if (nationalities.isNotEmpty) {
      final natM = RegExp(
              r'^(日本|アメリカ|米国|イギリス|ドイツ|イタリア|フランス|オーストラリア|'
              r'オランダ|スウェーデン|ノルウェー|中華民国|ソ連|フィンランド|ポーランド|カナダ)(.+)$')
          .firstMatch(trimmed);
      if (natM != null) {
        final natName = natM.group(1)!;
        final typePart = natM.group(2)!;
        final typeSet = _kNationalityTypeSet[typePart];
        // `イタリア艦`: the trailing 艦 is a pure-nationality label.
        if (typeSet != null || typePart.isEmpty || typePart == '艦') {
          final groupKey = natName == '日本'
              ? null
              : (natName == '米国' ? 'アメリカ艦' : '$natName艦');
          final group = natName == '日本'
              ? _japaneseShips
              : (nationalities[groupKey] ?? const <int>[]);
          if (group.isNotEmpty) {
            if (typeSet == null) {
              return TargetResolved(
                  shipIds: List<int>.from(group), sourceLabel: trimmed);
            }
            final ids = group.where((id) {
              final st = master.shipsById[id]?['api_stype'];
              return st != null && typeSet.contains(st);
            }).toList()
              ..sort();
            if (ids.isNotEmpty) {
              return TargetResolved(shipIds: ids, sourceLabel: trimmed);
            }
          }
        }
      }
    }
    // 5. All-ship / all-type labels.
    if (trimmed == '全艦娘' ||
        trimmed == '全艦' ||
        trimmed == '装備可能艦' ||
        trimmed == '全装備可能艦') {
      return const TargetResolved(shipIds: [], sourceLabel: '全艦娘');
    }
    if (trimmed == '全駆逐艦') {
      return const TargetResolved(
          shipIds: [], sourceLabel: '全駆逐艦', shipTypeIds: [2]);
    }
    if (trimmed == '全海防艦') {
      return const TargetResolved(
          shipIds: [], sourceLabel: '全海防艦', shipTypeIds: [1]);
    }
    // 6. Slash-separated multi-form lists and alternatives
    //    (`鳳翔改/改二/改二戦`, `丹陽/雪風改二`, `夕張改二/特/丁`,
    //    `翔鶴型改二 / 甲`).
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/').map((p) => p.trim()).toList();
      if (parts.length > 1) {
        var prefix = parts.first;
        // Class-form prefix (`翔鶴型改二/甲` → 翔鶴改二 + 翔鶴改二甲).
        final classPrefixM = RegExp(r'^(.+?)型(改二|改|航戦)$').firstMatch(prefix);
        if (classPrefixM != null) {
          final base = classPrefixM.group(1)!;
          final form = classPrefixM.group(2)!;
          final baseIds = master.shipIdsByName[base];
          if (baseIds != null && baseIds.length == 1) {
            final ct = master.ctypeByShip[baseIds.first];
            if (ct != null) {
              final members = (master.shipsByCtype[ct] ?? const <int>[]).where((id) => id < 1500).toList();
              final resolved = <int>{};
              var ok = true;
              for (final p in parts.sublist(1)) {
                final found = <int>{};
                for (final m in members) {
                  final n = master.shipName(m);
                  for (final cand in {
                    '$n$form$p',
                    '$n' '改' '$form' '$p',
                    '$n$p',
                  }) {
                    final ids = _lookupShipName(cand);
                    found.addAll(ids);
                  }
                }
                if (found.isEmpty) {
                  ok = false;
                  break;
                }
                resolved.addAll(found);
              }
              if (ok && resolved.isNotEmpty) {
                // Include the plain form members too (翔鶴改二, 瑞鶴改二).
                for (final m in members) {
                  final n = master.shipName(m);
                  final ids = master.shipIdsByName['$n$form'];
                  if (ids != null) resolved.addAll(ids);
                }
                return TargetResolved(
                    shipIds: resolved.toList()..sort(),
                    classIds: [ct],
                    sourceLabel: trimmed);
              }
            }
          }
        }
        final resolved = <int>{};
        var ok = true;
        for (var i = 1; i < parts.length; i++) {
          final p = parts[i];
          final candidates = <String>{
            p,
            '$prefix$p',
            '$prefix' '改' '$p',
            if (p == '改' || p == '改二') '${_stripFormSuffix(prefix)}$p',
            if (_isFormSuffix(p)) '${_stripFormSuffix(prefix)}$p',
            // `龍鳳改二戊/改二` = 龍鳳改二戊 + 龍鳳改二 (base form).
            if (p == '改' || p == '改二') _stripFormSuffix(prefix),
          };
          final found = candidates
              .expand((c) => _lookupShipName(c))
              .toSet();
          if (found.isEmpty) {
            ok = false;
            break;
          }
          resolved.addAll(found);
        }
        if (ok && resolved.isNotEmpty) {
          // The first part may itself be a full ship name.
          final prefixIds = master.shipIdsByName[prefix];
          if (prefixIds != null) resolved.addAll(prefixIds);
          return TargetResolved(
              shipIds: resolved.toList()..sort(), sourceLabel: trimmed);
        }
      }
    }
    // 7. Class-form expansion: `扶桑型改二`, `赤城型改`, `伊勢型航戦`,
    //    `秋月型改二` → the members of class X whose names match N+form.
    final formM =
        RegExp(r'^(.+?)型(改二|改|航戦|改二戦|改二護|改二戊|改二甲|改二乙|改二丙|改二丁|改二特)$')
            .firstMatch(trimmed);
    if (formM != null) {
      final base = formM.group(1)!;
      final form = formM.group(2)!;
      final baseIds = master.shipIdsByName[base];
      if (baseIds != null && baseIds.length == 1) {
        final ct = master.ctypeByShip[baseIds.first];
        if (ct != null) {
          final members = (master.shipsByCtype[ct] ?? const <int>[]).where((id) => id < 1500).toList();
          final ids = <int>{};
          for (final m in members) {
            final n = master.shipName(m);
            final forms = <String>{
              '$n$form',
              '$n' '改' '$form',
              if (form == '航戦') '$n' '改二',
              if (form == '航戦') '$n' '改二改',
            };
            for (final f in forms) {
              final ids2 = master.shipIdsByName[f];
              if (ids2 != null) ids.addAll(ids2);
            }
          }
          if (ids.isNotEmpty) {
            return TargetResolved(
                shipIds: ids.toList()..sort(),
                classIds: [ct],
                sourceLabel: trimmed);
          }
        }
      }
    }
    // 8. `X級` / `X型駆逐艦` → class of ship X (Fletcher級, 松型駆逐艦) or
    //    ship type (重巡級, 軽巡級).
    final classSuffixM = RegExp(r'^(.+?)(?:級|型駆逐艦|型空母|型戦艦)$').firstMatch(trimmed);
    if (classSuffixM != null) {
      final base = classSuffixM.group(1)!;
      final typeIds = kShipTypeNameToIds[base];
      if (typeIds != null) {
        return TargetResolved(
          shipIds: const [],
          shipTypeIds: typeIds,
          sourceLabel: trimmed,
        );
      }
      final baseIds = master.shipIdsByName[base];
      if (baseIds != null && baseIds.length == 1) {
        final ct = master.ctypeByShip[baseIds.first];
        if (ct != null) {
          final classShips = (master.shipsByCtype[ct] ?? const <int>[]).where((id) => id < 1500).toList();
          if (classShips.isNotEmpty) {
            return TargetResolved(
              shipIds: List<int>.from(classShips)..sort(),
              classIds: [ct],
              sourceLabel: trimmed,
            );
          }
        }
      }
    }
    return TargetUnresolved(trimmed, 'unknown target token');
  }

  static String _stripFormSuffix(String name) {
    // Single trailing form char (榛名改二乙 → 榛名改二).
    final single = RegExp(r'(特|丁|甲|乙|丙|戊|戦|護)$').firstMatch(name);
    if (single != null) return name.substring(0, name.length - 1);
    return name.replaceFirst(
        RegExp(
            r'(改二戦|改二護|改二戊|改二甲|改二乙|改二丙|改二丁|改二特|改三護|改四|改三|改二|改|航戦)$'),
        '');
  }

  static bool _isFormSuffix(String p) => RegExp(
          r'^(改二戦|改二護|改二戊|改二甲|改二乙|改二丙|改二丁|改二特|改三護|改四|改三|改二|改|特|丁|甲|乙|丙|戊|戦|護|航戦)$')
      .hasMatch(p);

/// Manual aliases for abbreviated ship names used by akashi-list, verified
/// against wikiwiki/kcwiki spelling.
static const Map<String, String> kShipNameAliases = <String, String>{
  'S B.Roberts': 'Samuel B.Roberts',
  'Samuel B.R': 'Samuel B.Roberts',
  'S B.Roberts Mk.II': 'Samuel B.Roberts Mk.II',
  'Samuel B.R Mk.II': 'Samuel B.Roberts Mk.II',
  'C.d.C': 'Conte di Cavour',
  'C.d.C nuovo': 'Conte di Cavour nuovo',
  // akashi-list spelling quirks vs master names.
  'South Dakotao': 'South Dakota',
  '吹雪改三護': '吹雪改三護(六式)',
  '吹雪改三': '吹雪改三',
  // akashi abbreviates the リシュシュー級 kai as a class label; the
  // wikiwiki target is the single ship Richelieu改.
  'Richelieu級改': 'Richelieu改',
};

/// Looks up a ship name with normalization: character variants
/// (曽/曾), trailing stacking notes, slash-merged forms and the
/// numbered-海防艦 suffix.
List<int> _lookupShipName(String name) {
  for (final candidate in _candidates(name)) {
    final ids = master.shipIdsByName[candidate];
    if (ids != null && ids.isNotEmpty) return ids;
    // Numbered escort ships: akashi writes 第二十二号, master has
    // 第二十二号海防艦.
    if (RegExp(r'^第.+号$').hasMatch(candidate)) {
      final ids2 = master.shipIdsByName['$candidate' '海防艦'];
      if (ids2 != null && ids2.isNotEmpty) return ids2;
    }
    // Manual aliases for abbreviations.
    final alias = kShipNameAliases[candidate];
    if (alias != null) {
      final ids3 = master.shipIdsByName[alias];
      if (ids3 != null && ids3.isNotEmpty) return ids3;
    }
  }
  return const [];
}

  /// Candidate name forms: the token itself, token minus trailing note
  /// parentheses, slash-merged forms like `矢矧改二/乙` → `矢矧改二乙`,
  /// and character variants (木曽 → 木曾).
  List<String> _candidates(String token) {
    final out = <String>[];
    out.add(token);
    final noParen = token.replaceFirst(RegExp(r'\([^()]*\)$'), '');
    if (noParen != token && noParen.trim().isNotEmpty) {
      out.add(noParen.trim());
    }
    final slashM = RegExp(r'^(.+?)/([乙特丁甲丙戊戦護])(?:改)?$').firstMatch(noParen);
    if (slashM != null) {
      out.add('${slashM.group(1)}${slashM.group(2)}');
      out.add('${slashM.group(1)}改${slashM.group(2)}');
    }
    // Character variants.
    if (token.contains('曽')) {
      out.add(token.replaceAll('曽', '曾'));
      out.add(noParen.replaceAll('曽', '曾'));
    }
    if (token.contains('曾')) {
      out.add(token.replaceAll('曾', '曽'));
      out.add(noParen.replaceAll('曾', '曽'));
    }
    return out;
  }
}
