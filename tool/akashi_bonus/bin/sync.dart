/// Akashi List equipment bonus dataset builder.
///
/// Usage:
///   dart run tool/akashi_bonus/bin/sync.dart --equipment-id 266
///   dart run tool/akashi_bonus/bin/sync.dart --all
///   dart run tool/akashi_bonus/bin/sync.dart --cross-check
///   dart run tool/akashi_bonus/bin/sync.dart --validate-only
///
/// Exit codes: 0 ok, 1 parse/schema/mapping, 2 unresolved, 3 unreviewed
/// source conflicts, 4 network throttled/refused, 5 structure changed.
library;

// ignore_for_file: avoid_relative_lib_imports

import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;

import '../lib/cross_source_checker.dart';
import '../lib/dataset_validator.dart';
import '../lib/dataset_writer.dart';
import '../lib/detail_parser.dart';
import '../lib/fetcher.dart';
import '../lib/models.dart';
import '../lib/name_resolver.dart';
import '../lib/overrides.dart';
import '../lib/page_discovery.dart';
import '../lib/rule_builder.dart';

const String kHomeUrl = 'https://akashi-list.me/';
const String kDetailPrefix = 'https://akashi-list.me/detail/';
const String kRobotsUrl = 'https://akashi-list.me/robots.txt';

const String kDefaultMaster = 'tool/wiki_bonus/cache/raw/start2.json';
const String kDefaultDataset = 'assets/data/equipment_fit_bonuses.json';
const String kDefaultEo = 'tool/akashi_bonus/cache/raw/FitBonuses.json';

String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String _datasetVersion(String existingPath) {
  final date = _today();
  var n = 1;
  if (File(existingPath).existsSync()) {
    try {
      final raw = jsonDecode(File(existingPath).readAsStringSync());
      final v = (raw as Map<String, dynamic>)['datasetVersion'] as String? ?? '';
      if (v.startsWith(date)) {
        final m = RegExp(r'\.(\d+)$').firstMatch(v);
        n = (m != null ? int.parse(m.group(1)!) : 0) + 1;
      }
    } catch (_) {}
  }
  return '$date.$n';
}

String _fetchedAt() =>
    DateTime.now().toUtc().toIso8601String().replaceFirst('Z', '+00:00');

Future<void> main(List<String> args) async {
  exitCode = await run(args);
}

Future<int> run(List<String> args) async {
  String? eqArg;
  var doAll = false;
  var doCrossCheck = false;
  var doValidate = false;
  var masterPath = kDefaultMaster;
  var datasetPath = kDefaultDataset;
  var eoPath = kDefaultEo;
  var noFetch = false;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--equipment-id':
        eqArg = args[++i];
      case '--all':
        doAll = true;
      case '--cross-check':
        doCrossCheck = true;
      case '--validate-only':
        doValidate = true;
      case '--master':
        masterPath = args[++i];
      case '--dataset':
        datasetPath = args[++i];
      case '--eo':
        eoPath = args[++i];
      case '--no-fetch':
        noFetch = true;
      default:
        stderr.writeln('unknown argument ${args[i]}');
        return 1;
    }
  }

  final cwd = Directory.current.path;
  final masterFile = File('$cwd\\$masterPath');
  if (!masterFile.existsSync()) {
    stderr.writeln('master data not found at $masterFile');
    return 1;
  }
  final master = MasterData.fromJsonFile(masterFile.path);

  if (doValidate) {
    return _validateOnly(master, datasetPath);
  }
  if (doCrossCheck) {
    return _crossCheck(master, datasetPath, eoPath, cwd);
  }

  if (eqArg == null && !doAll) {
    stderr.writeln('nothing to do: pass --equipment-id N, --all, --validate-only or --cross-check');
    return 1;
  }

  final toolDir = '$cwd\\tool\\akashi_bonus';
  final reportsDir = '$toolDir\\reports';
  final cacheDir = '$toolDir\\cache\\raw';
  final writer = DatasetWriter(reportsDir);

  // robots.txt check (recorded once per run).
  final robotsRecord = await _checkRobots(cacheDir);
  if (robotsRecord == 'blocked') {
    stderr.writeln('robots.txt disallows crawling; stopping.');
    return 4;
  }

  final fetcher = AkashiFetcher(cacheDir: cacheDir);
  try {
    // Homepage discovery (always done: needed for the manifest).
    FetchResult? home;
    if (noFetch) {
      home = fetcher.readCache('homepage');
    } else {
      try {
        home = await fetcher.fetch(kHomeUrl, cacheKey: 'homepage');
      } on FetchStopException catch (e) {
        stderr.writeln('homepage fetch stopped: ${e.reason}');
        return 4;
      }
    }
    if (home == null) {
      stderr.writeln('homepage unavailable (--no-fetch with empty cache?)');
      return 4;
    }
    final homeDoc = html_parser.parse(home.body);
    final discovery = discoverWeapons(homeDoc.body!);
    if (discovery.problems.isNotEmpty) {
      stderr.writeln('homepage structure problems: ${discovery.problems}');
      return 5;
    }
    writer.writeJson('discovery.json', {
      'entryUrl': kHomeUrl,
      'fetchedAt': DateTime.now().toIso8601String(),
      'homepageSha256': home.sha256.replaceFirst('sha256:sha256:', 'sha256:'),
      'discoveredEquipment': discovery.weapons.length,
      'detailsFetched': 0,
      'detailsWithBonus': 0,
      'detailsWithoutBonus': 0,
      'items': [
        for (final w in (List<DiscoveredWeapon>.of(discovery.weapons)
          ..sort((a, b) => a.equipmentId.compareTo(b.equipmentId))))
          {
            'equipmentId': w.equipmentId,
            'name': w.name,
            'detailUrl': w.detailUrl,
          },
      ],
    });

    // Determine ids to process.
    final ids = <int>[];
    if (doAll) {
      ids.addAll(discovery.sortedIds);
    } else {
      final n = int.parse(eqArg!);
      if (!discovery.weapons.any((w) => w.equipmentId == n)) {
        stderr.writeln('equipment $n not found on homepage');
        return 1;
      }
      ids.add(n);
    }

    // Build rules per equipment.
    final allRules = <BonusRule>[];
    final allUnresolved = <UnresolvedEntry>[];
    var fetched = 0;
    var withBonus = 0;
    var withoutBonus = 0;
    final nationalities = _loadNationalities(toolDir);
    final overridePath = '$toolDir\\overrides\\bonuses.json';
    final overrides = loadOverrides(overridePath);
    final overrideCovered = <int>{
      for (final o in overrides)
        if (o.kind == 'addRule' && o.rule != null) ...o.rule!.shipCondition.shipIds,
    };
    final builder = RuleBuilder(master,
        nationalities: nationalities, overrideCoveredShips: overrideCovered);

    for (final id in ids) {
      final detailUrl = '$kDetailPrefix' 'w$id.html';
      FetchResult? res;
      try {
        if (noFetch) {
          res = fetcher.readCache('detail_$id');
        } else {
          res = await fetcher.fetch(detailUrl, cacheKey: 'detail_$id');
        }
      } on FetchMissingException catch (e) {
        stdout.writeln('w$id: detail page missing (HTTP ${e.statusCode}); '
            'sourceStatus=missing, skipped');
        continue;
      } on FetchStopException catch (e) {
        stderr.writeln('fetch stopped for w$id: ${e.reason}');
        fetcher.close();
        return 4;
      }
      if (res == null) {
        if (noFetch) {
          stdout.writeln('w$id: no cache entry; skipped (missing or '
              'never fetched in --no-fetch mode)');
          continue;
        }
        stderr.writeln('detail page unavailable for w$id');
        fetcher.close();
        return 4;
      }
      fetched++;

      final doc = html_parser.parse(res.body);
      final DetailParseResult page;
      try {
        page = parseDetailDocument(doc, id);
      } on DetailParseException catch (e) {
        stderr.writeln('w$id parse failed: $e');
        allUnresolved.add(UnresolvedEntry(
          equipmentId: id,
          kind: 'parse',
          detail: e.message,
        ));
        continue;
      }
      if (page.equipmentIdFromUrl != page.pageNo) {
        stderr.writeln('w$id identity mismatch: url=$id page=${page.pageNo}');
        allUnresolved.add(UnresolvedEntry(
          equipmentId: id,
          kind: 'identity',
          detail: 'url id $id != page no ${page.pageNo}',
        ));
        continue;
      }
      if (page.fits.isEmpty) {
        withoutBonus++;
        continue;
      }
      withBonus++;

      final built = builder.buildForPage(
        page: page,
        detailUrl: detailUrl,
        pageContent: res.body,
        fetchedAt: _fetchedAt(),
        httpLastModified: res.lastModified,
      );
      allRules.addAll(built.rules);
      allUnresolved.addAll(built.unresolved);
      stdout.writeln('w$id: ${built.rules.length} rules, '
          '${built.unresolved.length} unresolved (${page.pageName})');
    }

    // Apply reviewed overrides.
    final applied = applyOverrides(allRules, overrides);
    if (applied.problems.isNotEmpty) {
      stderr.writeln('override problems: ${applied.problems}');
      return 1;
    }
    for (final o in overrides) {
      stdout.writeln('override applied: ${o.overrideId} (${o.kind})');
    }

    // Override-added rules carry no page hash; backfill the equipment page's
    // content hash so provenance checks stay meaningful.
    final contentShaById = <int, String>{};
    for (final id in ids) {
      final cached = fetcher.readCache('detail_$id');
      if (cached != null) contentShaById[id] = cached.sha256;
    }
    final patchedRules = <BonusRule>[];
    for (final r in applied.rules) {
      if (r.source.contentSha256.isEmpty && r.equipment.ids.isNotEmpty) {
        final sha = contentShaById[r.equipment.ids.first];
        if (sha != null) {
          patchedRules.add(BonusRule(
            ruleId: r.ruleId,
            equipment: r.equipment,
            category: r.category,
            shipCondition: r.shipCondition,
            equipmentCondition: r.equipmentCondition,
            requires: r.requires,
            effect: r.effect,
            source: SourceInfo(
              url: r.source.url,
              pageName: r.source.pageName,
              fetchedAt:
                  r.source.fetchedAt.isEmpty ? _fetchedAt() : r.source.fetchedAt,
              httpLastModified: r.source.httpLastModified,
              contentSha256: sha,
              fragmentHash: r.source.fragmentHash,
              sourceGroupLabel: r.source.sourceGroupLabel,
              rawEffect: r.source.rawEffect,
              rawCondition: r.source.rawCondition,
              annotation: r.source.annotation,
            ),
            notes: r.notes,
          ));
          continue;
        }
      }
      patchedRules.add(r);
    }

    // Re-number addRule rules: their placeholder ruleIds (e.g. 9xx) must be
    // unique and schema-conformant per equipment.
    final counters = <String, int>{};
    final renumbered = <BonusRule>[];
    for (final r in patchedRules) {
      if (r.source.fragmentHash == 'override') {
        final eq = r.equipment.ids.isNotEmpty ? r.equipment.ids.first : 0;
        final cat = r.category.name;
        final key = '$eq/$cat';
        final n = (counters[key] ?? 0) + 1;
        counters[key] = n;
        renumbered.add(BonusRule(
          ruleId: 'akashi-$eq-$cat-${n.toString().padLeft(3, '0')}',
          equipment: r.equipment,
          category: r.category,
          shipCondition: r.shipCondition,
          equipmentCondition: r.equipmentCondition,
          requires: r.requires,
          effect: r.effect,
          source: r.source,
          notes: r.notes,
        ));
      } else {
        renumbered.add(r);
      }
    }
    // Check for collisions with generated ruleIds and bump as needed.
    final seen = <String>{};
    final finalRules = <BonusRule>[];
    for (final r in renumbered) {
      var id = r.ruleId;
      var bump = 0;
      while (seen.contains(id)) {
        bump++;
        id = r.ruleId.replaceFirst(
            RegExp(r'-(\d{3})$'), '-${bump.toString().padLeft(3, '0')}');
      }
      seen.add(id);
      finalRules.add(BonusRule(
        ruleId: id,
        equipment: r.equipment,
        category: r.category,
        shipCondition: r.shipCondition,
        equipmentCondition: r.equipmentCondition,
        requires: r.requires,
        effect: r.effect,
        source: r.source,
        notes: r.notes,
      ));
    }
    final patchedRules2 = finalRules;

    // Unresolved entries addressed by reviewed overrides do not block the
    // publish gate; they are kept in the report with a marker.
    final resolvedEqIds = <int>{
      for (final o in overrides) ...o.resolvesEquipmentIds,
    };
    final gateUnresolved = allUnresolved
        .where((u) => !resolvedEqIds.contains(u.equipmentId))
        .toList();

    // Round 1 validation + Round 2 manual review merge.
    final validation = DatasetValidator(master).validate(
      rules: patchedRules2,
      unresolvedEmpty: gateUnresolved.isEmpty,
    );
    final round2Path = '$reportsDir\\wiki_manual_review.json';
    Object? round2;
    if (File(round2Path).existsSync()) {
      try {
        round2 = jsonDecode(File(round2Path).readAsStringSync());
      } catch (_) {}
    }
    writer.writeJson('validation.json', {
      'round1': {
        'passed': validation.passed,
        'issues': [
          for (final i in validation.issues)
            {'code': i.code, 'detail': i.detail},
        ],
      },
      'round2': ?round2,
    });
    // Unresolved entries addressed by reviewed overrides do not block the
    // publish gate; they are kept in the report with a marker.
    writer.writeJson('unresolved.json', {
      'count': allUnresolved.length,
      'blocking': gateUnresolved.length,
      'items': [
        for (final e in allUnresolved)
          {
            ...e.toJson(),
            if (resolvedEqIds.contains(e.equipmentId))
              'resolvedByOverride': true,
          },
      ],
    });

    final rulesHash = rulesCanonicalHash(patchedRules2);
    writer.writeManifest({
      'toolVersion': '1.0.0',
      'gitCommit': _gitHead(),
      'robots': robotsRecord,
      'homepageSha256': home.sha256.replaceFirst('sha256:sha256:', 'sha256:'),
      'discoveredEquipment': discovery.weapons.length,
      'detailsFetched': fetched,
      'detailsWithBonus': withBonus,
      'detailsWithoutBonus': withoutBonus,
      'rules': patchedRules2.length,
      'unresolved': allUnresolved.length,
      'unresolvedBlocking': gateUnresolved.length,
      'rulesCanonicalSha256': rulesHash,
      'overridesApplied': overrides.length,
      'datasetPath': datasetPath,
      'published': validation.passed && gateUnresolved.isEmpty,
    });

    stdout.writeln('rules: ${patchedRules.length}, hash: $rulesHash');
    stdout.writeln('unresolved: ${allUnresolved.length} '
        '(${gateUnresolved.length} blocking)');

    if (!validation.passed) {
      stderr.writeln('round-1 validation FAILED');
      return 1;
    }
    if (gateUnresolved.isNotEmpty) {
      stderr.writeln('unresolved entries exist; dataset NOT published '
          '(previous version kept)');
      return 2;
    }
    final version = _datasetVersion(datasetPath);
    writer.writeDataset(datasetPath, patchedRules2, datasetVersion: version);
    stdout.writeln('dataset written: $datasetPath (version $version)');
    return 0;
  } finally {
    fetcher.close();
  }
}

Future<String?> _checkRobots(String cacheDir) async {
  final meta = File('$cacheDir\\robots.meta.json');
  if (meta.existsSync()) {
    try {
      final m = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
      if (m.containsKey('result')) return m['result'] as String;
    } catch (_) {}
  }
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  try {
    final req = await client.getUrl(Uri.parse(kRobotsUrl));
    req.headers.set(
        'User-Agent', 'YahagiKancolleBonusDatasetBuilder/1.0 (+https://github.com/)');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final result = body.contains('Disallow: /') ? 'blocked' : 'allowed';
    Directory(cacheDir).createSync(recursive: true);
    meta.writeAsStringSync(jsonEncode({'result': result, 'body': body}));
    return result;
  } catch (e) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Loads the wikiwiki-derived nationality→shipIds table used to resolve
/// 国籍+舰型 target tokens (e.g. アメリカ駆逐艦).
Map<String, List<int>> _loadNationalities(String toolDir) {
  final f = File('$toolDir\\data\\nationality_ships.json');
  if (!f.existsSync()) return const {};
  try {
    final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final nats = raw['nationalities'] as Map<String, dynamic>;
    return {
      for (final e in nats.entries)
        e.key: (e.value as List).cast<int>(),
    };
  } catch (_) {
    return const {};
  }
}

String _gitHead() {
  try {
    final p = Process.runSync('git', ['rev-parse', 'HEAD'],
        workingDirectory: Directory.current.path);
    if (p.exitCode == 0) return (p.stdout as String).trim();
  } catch (_) {}
  return 'unknown';
}

int _validateOnly(MasterData master, String datasetPath) {
  if (!File(datasetPath).existsSync()) {
    stderr.writeln('dataset not found: $datasetPath');
    return 1;
  }
  final (rules, version) = DatasetReader.read(datasetPath);
  final validation = DatasetValidator(master).validate(
    rules: rules,
    unresolvedEmpty: true,
  );
  stdout.writeln('dataset $datasetPath (version $version): '
      '${rules.length} rules, validation ${validation.passed ? 'PASS' : 'FAIL'}');
  for (final i in validation.issues) {
    stderr.writeln('  [${i.code}] ${i.detail}');
  }
  return validation.passed ? 0 : 1;
}

int _crossCheck(MasterData master, String datasetPath, String eoPath, String cwd) {
  if (!File(datasetPath).existsSync()) {
    stderr.writeln('dataset not found: $datasetPath');
    return 1;
  }
  final (rules, version) = DatasetReader.read(datasetPath);
  final toolDir = '$cwd\\tool\\akashi_bonus';
  final reportsDir = '$toolDir\\reports';

  final diffs = <DiffEntry>[];
  if (File(eoPath).existsSync()) {
    final eoRaw = jsonDecode(File(eoPath).readAsStringSync());
    final eo = eoRaw is Map<String, dynamic>
        ? eoRaw
        : <String, dynamic>{'entries': eoRaw as List};
    final itemTypes = <int, List<int>>{};
    for (final e in master.itemsById.entries) {
      final t = e.value['api_type'];
      if (t is List) {
        itemTypes[e.key] = t.map((x) => (x as num).toInt()).toList();
      }
    }
    diffs.addAll(compareWithEo(rules, eo, itemTypes));
  } else {
    stderr.writeln('EO data not found at $eoPath; skipping EO comparison');
  }

  // Merge manual wiki/EO review records: they either review an existing
  // generated diff (matched by ruleId + checkType) or stand alone.
  final manualPath = '$reportsDir\\wiki_manual_review.json';
  final manual = <WikiCrossCheckEntry>[];
  if (File(manualPath).existsSync()) {
    final raw = jsonDecode(File(manualPath).readAsStringSync()) as Map<String, dynamic>;
    for (final e in (raw['entries'] as List).cast<Map<String, dynamic>>()) {
      manual.add(WikiCrossCheckEntry(
        equipmentId: e['equipmentId'] as int,
        ruleId: e['ruleId'] as String,
        checkType: (e['checkType'] as String?) ?? 'manual',
        status: e['status'] as String,
        detail: e['detail'] as String,
        checkedAt: e['checkedAt'] as String,
        checkedBy: e['checkedBy'] as String,
        diffClass: e['diffClass'] == null
            ? null
            : DiffClass.values
                .firstWhere((d) => d.label == e['diffClass'],
                    orElse: () => DiffClass.sourceConflict),
      ));
    }
  }

  final manualByKey = <String, WikiCrossCheckEntry>{
    for (final m in manual) '${m.ruleId}|${m.checkType}': m,
  };
  final merged = <DiffEntry>[];
  final usedManual = <String>{};
  for (final d in diffs) {
    final key = '${d.ruleId}|eo';
    final m = manualByKey[key] ??
        manualByKey.entries
            .where((e) =>
                e.key.endsWith('*|eo') &&
                d.ruleId.startsWith(e.key.substring(0, e.key.length - 4)))
            .map((e) => e.value)
            .firstOrNull;
    if (m != null) {
      usedManual.add(key);
      merged.add(DiffEntry(
        equipmentId: d.equipmentId,
        ruleId: d.ruleId,
        kind: m.diffClass ?? d.kind,
        detail: '${d.detail} // ${m.detail}',
        reviewedBy: m.checkedBy,
        reviewedAt: m.checkedAt,
        resolution: m.status,
      ));
    } else {
      merged.add(d);
    }
  }
  for (final m in manual) {
    final key = '${m.ruleId}|${m.checkType}';
    if (usedManual.contains(key)) continue;
    merged.add(DiffEntry(
      equipmentId: m.equipmentId,
      ruleId: m.ruleId,
      kind: m.diffClass ?? DiffClass.matched,
      detail: m.detail,
      reviewedBy: m.checkedBy,
      reviewedAt: m.checkedAt,
      resolution: m.status,
    ));
  }

  final unreviewed = merged.where((d) => d.reviewedBy == null).toList();
  File('$reportsDir\\cross_source_diff.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(merged.map((d) => d.toJson()).toList())}\n');
  File('$reportsDir\\wiki_cross_check.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manual.map((e) => e.toJson()).toList())}\n');
  stdout.writeln('cross-source diffs: ${merged.length} total, '
      '${unreviewed.length} unreviewed');
  for (final d in merged) {
    stdout.writeln('  [${d.kind.label}] ${d.ruleId}: ${d.detail}');
  }
  return unreviewed.isEmpty ? 0 : 3;
}

