/// Assembles normalized [BonusRule]s from parsed detail pages.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

import 'detail_parser.dart';
import 'models.dart';
import 'name_resolver.dart';

/// One unresolved item that blocks publishing until reviewed.
class UnresolvedEntry {
  final int equipmentId;
  final String kind;
  final String detail;
  final String? rawHtml;
  final String? rawEffect;
  final String? rawCondition;
  final String? sourceGroupLabel;

  const UnresolvedEntry({
    required this.equipmentId,
    required this.kind,
    required this.detail,
    this.rawHtml,
    this.rawEffect,
    this.rawCondition,
    this.sourceGroupLabel,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'equipmentId': equipmentId,
        'kind': kind,
        'detail': detail,
        if (rawHtml != null) 'rawHtmlHash': _sha(rawHtml!),
        if (rawEffect != null) 'rawEffect': rawEffect,
        if (rawCondition != null) 'rawCondition': rawCondition,
        if (sourceGroupLabel != null) 'sourceGroupLabel': sourceGroupLabel,
      };
}

String _sha(String s) => 'sha256:${sha256.convert(utf8.encode(s))}';

class RuleBuildResult {
  final List<BonusRule> rules;
  final List<UnresolvedEntry> unresolved;
  const RuleBuildResult(this.rules, this.unresolved);
}

class RuleBuilder {
  final MasterData master;

  /// Nationality label → master ship ids (wikiwiki nationality groups).
  final Map<String, List<int>> nationalities;

  /// Equipment type ids of the page's own equipment (from master).
  final Map<int, List<int>> itemTypeIds;

  /// Ships explicitly covered by reviewed overrides; remodel expansion must
  /// not pull these into base-form fits (their values come from the override).
  final Set<int> overrideCoveredShips;

  RuleBuilder(this.master,
      {this.nationalities = const {}, this.overrideCoveredShips = const {}})
      : itemTypeIds = _indexItemTypes(master);

  static Map<int, List<int>> _indexItemTypes(MasterData m) {
    final out = <int, List<int>>{};
    for (final entry in m.itemsById.entries) {
      final t = entry.value['api_type'];
      if (t is List && t.isNotEmpty) {
        out[entry.key] = t.map((e) => (e as num).toInt()).toList();
      }
    }
    return out;
  }

  /// Resolves a 水上電探 icon into a predicate.
  ///
  /// The concrete thresholds are confirmed against WikiWiki:
  ///   * 水上電探 → 索敵+5以上 (wikiwiki 12.7cm連装砲C型改二 脚注 *6)
  ///   * 対空電探 → 素対空値+2以上 (wikiwiki 94式高射装置 脚注 *6, and the
  ///     高射装置-family pages use the same wording)
  EquipmentPredicate? predicateForIcon(BonusIcon icon) {
    final title = icon.title.trim();
    if (title == '水上電探') {
      return const EquipmentPredicate(lineOfSightGte: 5);
    }
    if (title == '対空電探') {
      return const EquipmentPredicate(antiAirGte: 2);
    }
    if (icon.cssClass == 'equipmentLink' && icon.equipmentId != null) {
      return EquipmentPredicate(itemIds: [icon.equipmentId!]);
    }
    return null;
  }

  RuleBuildResult buildForPage({
    required DetailParseResult page,
    required String detailUrl,
    required String pageContent,
    required String fetchedAt,
    required String? httpLastModified,
  }) {
    final rawRules = <BonusRule>[];
    final unresolved = <UnresolvedEntry>[];
    final eqId = page.equipmentIdFromUrl;
    final contentSha = 'sha256:${sha256.convert(utf8.encode(pageContent))}';

    final resolver = TargetGroupResolver(master, {
      for (final g in page.tipGroups) g.label: g.shipNames,
    }, nationalities: nationalities);

    // All fit target texts of this page, used to decide remodel expansion:
    // a base-form token expands to its remodel stages only when no other fit
    // on the page targets that stage by name (`秋月型` expands to 秋月改二
    // unless a `秋月型改二` fit already covers it). Separators are stripped
    // so `赤城型改二・護` matches `赤城型改二護`.
    final allTargetTexts =
        page.fits.expand((f) => f.targetTokens).join(' ').replaceAll(
            RegExp(r'[・、\s]'), '');

    List<int> expandRemodelsUnlessCovered(List<int> ids) {
      bool coveredByFit(int baseId, int cid) {
        if (overrideCoveredShips.contains(cid)) return true;
        final nn = master.shipName(cid) ?? '';
        if (nn.isEmpty) return false;
        final normNn = nn.replaceAll(RegExp(r'[・、\s]'), '');
        if (normNn.isNotEmpty && allTargetTexts.contains(normNn)) return true;
        final formM = RegExp(
                r'^(.+?)(改二戦|改二護|改二戊|改二甲|改二乙|改二丙|改二丁|改二特|'
                r'改三|改四|改二|改|特|丁|甲|乙|丙|戊|戦|護)$')
            .firstMatch(nn);
        if (formM == null) return false;
        final base = formM.group(1)!;
        final form = formM.group(2)!;
        if (allTargetTexts.contains('$base型$form')) return true;
        // Same-class coverage: `武蔵改二` is covered by a `大和型改二` fit,
        // `加賀改二護` by a `赤城型改二護` fit.
        final ct = master.ctypeByShip[baseId];
        if (ct != null) {
          for (final m in master.shipsByCtype[ct] ?? const <int>[]) {
            final mn = master.shipName(m) ?? '';
            final mBase = mn.replaceFirst(
                RegExp(
                    r'(改二戦|改二護|改二戊|改二甲|改二乙|改二丙|改二丁|改二特|'
                    r'改三|改四|改二|改|特|丁|甲|乙|丙|戊|戦|護)$'),
                '');
            if (mBase.isNotEmpty && allTargetTexts.contains('$mBase型$form')) {
              return true;
            }
          }
        }
        return false;
      }

      final out = <int>{};
      for (final id in ids) {
        if (id >= 1500) {
          out.add(id);
          continue;
        }
        final chain = <int>[id];
        var cur = id;
        var guard = 0;
        while (cur > 0 && guard++ < 20) {
          final next = master.shipsById[cur]?['api_aftershipid'];
          int? ni;
          if (next is int) {
            ni = next;
          } else if (next is String) {
            ni = int.tryParse(next);
          }
          if (ni == null || ni <= 0 || ni >= 1500) break;
          chain.add(ni);
          cur = ni;
        }
        final covered = chain.skip(1).any((cid) => coveredByFit(id, cid));
        if (covered) {
          out.add(id);
        } else {
          out.addAll(chain);
        }
      }
      return out.toList()..sort();
    }

    var fitIndex = 0;
    for (var fit in page.fits) {
      fitIndex++;
      final fragmentHash = 'sha256:${sha256.convert(utf8.encode(fit.rawHtml))}';
      final groupLabel = fit.targetTokens.join('・');
      final fitAnnotations = <String>[
        if (fit.annotation != null) fit.annotation!,
      ];
      final resolvedTargets = <TargetResolved>[];
      var targetFailed = false;
      var hasOtherToken = false;
      final excludedByOther = <int>{};
      for (final token in fit.targetTokens) {
        if (token == 'その他' || token == '他') {
          hasOtherToken = true;
          continue;
        }
        // `Киров以外` = every ship except the named one.
        final exceptM = RegExp(r'^(.+)以外$').firstMatch(token);
        if (exceptM != null) {
          final r = resolver.resolve(exceptM.group(1)!.trim());
          if (r is TargetResolved) {
            hasOtherToken = true;
            excludedByOther.addAll(r.shipIds);
            continue;
          }
        }
        final r = resolver.resolve(token);
        if (r is TargetResolved) {
          resolvedTargets.add(r);
        } else {
          final ur = r as TargetUnresolved;
          targetFailed = true;
          unresolved.add(UnresolvedEntry(
            equipmentId: eqId,
            kind: 'target',
            detail: 'fit #$fitIndex token "${ur.token}": ${ur.reason}',
            rawHtml: fit.rawHtml,
            sourceGroupLabel: groupLabel,
          ));
        }
      }
      if (hasOtherToken) {
        // `その他` = every ship not listed elsewhere on this page.
        final listed = <int>{};
        for (final t in resolvedTargets) {
          listed.addAll(t.shipIds);
        }
        listed.addAll(excludedByOther);
        final all = <int>{};
        for (final ids in master.shipsByStype.values) {
          all.addAll(ids);
        }
        all.removeWhere((id) => id >= 1500);
        all.removeAll(listed);
        if (all.isNotEmpty) {
          resolvedTargets.add(TargetResolved(
              shipIds: all.toList()..sort(), sourceLabel: 'その他'));
        } else {
          targetFailed = true;
          unresolved.add(UnresolvedEntry(
            equipmentId: eqId,
            kind: 'target',
            detail: 'fit #$fitIndex token "その他": no remaining ships',
            rawHtml: fit.rawHtml,
            sourceGroupLabel: groupLabel,
          ));
        }
      }
      if (targetFailed) {
        // No partial rules: the whole fit goes to unresolved.
        continue;
      }
      final allShipIds = <int>{};
      final classIds = <int>{};
      final shipTypeIds = <int>{};
      for (final t in resolvedTargets) {
        final ships = t.sourceLabel == 'その他'
            ? t.shipIds
            : expandRemodelsUnlessCovered(t.shipIds);
        allShipIds.addAll(ships);
        classIds.addAll(t.classIds);
        shipTypeIds.addAll(t.shipTypeIds);
      }
      final sortedShips = (allShipIds.toList()..sort());

      // Count-gated blocks (`1つ目:` / `2~4つ目:` / `2機目～`) of one fit
      // combine into a single countTable: segments may span multiple spans.
      final countSegmentBlocks =
          fit.blocks.where((b) => b.countSegments.isNotEmpty).toList();
      if (countSegmentBlocks.isNotEmpty) {
        final segments = <CountSegment>[];
        final baseStats = <String, int>{};
        var countOk = true;
        final countBlockIdx = <int>{};
        for (var i = 0; i < fit.blocks.length; i++) {
          final b = fit.blocks[i];
          if (b.isSynergy) continue;
          if (b.countGateTexts.isNotEmpty) countOk = false;
          countBlockIdx.add(i);
          segments.addAll(b.countSegments);
          for (final s in b.statBonuses) {
            if (s.increments.length == 1) {
              baseStats[s.stat] = (baseStats[s.stat] ?? 0) + s.increments.first;
            } else {
              countOk = false;
            }
          }
        }
        segments.sort((a, b) => a.start.compareTo(b.start));
        // The start==1 segment's stats are the first-equipment baseline, not
        // per-slot increments stacked on later counts.
        for (final seg in segments.where((s) => s.start == 1)) {
          for (final s in seg.stats) {
            baseStats[s.stat] = (baseStats[s.stat] ?? 0) + s.increments.first;
          }
        }
        if (!countOk) {
          // Fall through: the count block will be reported via countGateTexts.
        } else if (segments.isNotEmpty) {
          final maxEnd = segments
              .map((s) => s.end ?? 4)
              .reduce((a, b) => a > b ? a : b);
          final hasRepeat = segments.any((s) => s.end == null);
          final byCount = <int, Bonus>{};
          final increments = <int, Bonus>{};
          Bonus? prev;
          for (var n = 1; n <= maxEnd; n++) {
            final total = <String, int>{...baseStats};
            for (final seg in segments) {
              if (seg.start == 1) continue;
              if (seg.start > n) continue;
              if (seg.end != null && seg.end! < n) continue;
              for (final s in seg.stats) {
                total[s.stat] = (total[s.stat] ?? 0) + s.increments.first;
              }
            }
            final bonus = Bonus(total);
            final inc = prev == null
                ? bonus
                : Bonus({
                    for (final e in bonus.stats.entries)
                      e.key: e.value - (prev.stats[e.key] ?? 0),
                  });
            increments[n] = inc;
            byCount[n] = bonus;
            prev = bonus;
          }
          if (byCount.isNotEmpty) {
            rawRules.add(BonusRule(
              ruleId: _ruleId(eqId, 'count', rawRules),
              equipment: EquipmentRef(ids: [eqId]),
              category: RuleCategory.count,
              shipCondition: ShipCondition(
                shipIds: sortedShips,
                classIds: classIds.toList()..sort(),
                shipTypeIds: shipTypeIds.toList()..sort(),
              ),
              effect: CountTableEffect(
                increments,
                byCount,
                overflow:
                    hasRepeat ? 'repeat' : (maxEnd < 10 ? 'cap' : 'unresolved'),
              ),
              source: _source(
                detailUrl,
                page,
                pageContent,
                fetchedAt,
                httpLastModified,
                contentSha,
                fragmentHash,
                groupLabel,
                fit.blocks
                    .where((b) => countBlockIdx.contains(fit.blocks.indexOf(b)))
                    .map((b) => b.statBonuses.map((s) => s.rawText).join(' '))
                    .join(' '),
                fitAnnotations,
              ),
            ));
          }
          // The count blocks are fully consumed.
          final remainingBlocks = <BonusBlock>[];
          for (var i = 0; i < fit.blocks.length; i++) {
            if (countBlockIdx.contains(i)) continue;
            remainingBlocks.add(fit.blocks[i]);
          }
          fit = BonusFit(
            blocks: remainingBlocks,
            targetTokens: fit.targetTokens,
            rawHtml: fit.rawHtml,
            annotation: fit.annotation,
          );
        }
      }

      var blockIndex = 0;
      for (final block in fit.blocks) {
        blockIndex++;
        final rawEffect = block.statBonuses
            .map((b) => b.rawText)
            .join(' ');
        final annotations = fitAnnotations;
        if (block.countGateTexts.isNotEmpty) {
          unresolved.add(UnresolvedEntry(
            equipmentId: eqId,
            kind: 'countGate',
            detail: 'fit #$fitIndex block #$blockIndex unsupported count '
                'gate: ${block.countGateTexts.join("/")}',
            rawHtml: fit.rawHtml,
            rawEffect: rawEffect,
            sourceGroupLabel: groupLabel,
          ));
          continue;
        }
        if (block.isSynergy) {
          final predicates = <EquipmentPredicate>[];
          final unresolvedIcons = <String>[];
          for (final icon in block.icons) {
            final p = predicateForIcon(icon);
            if (p == null) {
              unresolvedIcons.add(icon.title);
            } else {
              predicates.add(p);
            }
          }
          if (unresolvedIcons.isNotEmpty) {
            unresolved.add(UnresolvedEntry(
              equipmentId: eqId,
              kind: 'synergyPredicate',
              detail:
                  'fit #$fitIndex block #$blockIndex icons ${unresolvedIcons.join("/")} lack verified predicate',
              rawHtml: fit.rawHtml,
              rawEffect: rawEffect,
              sourceGroupLabel: groupLabel,
            ));
            continue;
          }
          final bonus = Bonus({
            for (final b in block.statBonuses) b.stat: b.increments.first,
          });
          // Synergy bonus written as a star table (star-none + rbonus)
          // carries no plain stats; it must be handled before the empty
          // check below.
          final synergyStarTable = block.starAdditions.isNotEmpty;
          if (bonus.isEmpty && !synergyStarTable) {
            unresolved.add(UnresolvedEntry(
              equipmentId: eqId,
              kind: 'synergyEmpty',
              detail: 'fit #$fitIndex block #$blockIndex has no stats',
              rawHtml: fit.rawHtml,
              sourceGroupLabel: groupLabel,
            ));
            continue;
          }
          // Parenthetical-only texts (`(沖波改二)`, `(白露型・朝潮型)`)
          // restrict the rule.
          var shipIds = sortedShips;
          final classIds2 = classIds.toList()..sort();
          if (block.onlyShipNames.isNotEmpty) {
            final onlyIds = <int>{};
            var ok = true;
            for (final raw in block.onlyShipNames) {
              for (final n in raw.split(RegExp(r'[・、\s]+'))) {
                if (n.isEmpty) continue;
                final ids = master.shipIdsByName[n];
                if (ids != null && ids.isNotEmpty) {
                  onlyIds.addAll(ids);
                  continue;
                }
                // Class names (`(白露型)`) expand to the whole class.
                if (n.endsWith('型')) {
                  final base = n.substring(0, n.length - 1);
                  final baseIds = master.shipIdsByName[base];
                  if (baseIds != null && baseIds.length == 1) {
                    final ct = master.ctypeByShip[baseIds.first];
                    if (ct != null) {
                      final members = master.shipsByCtype[ct] ?? const <int>[];
                      onlyIds.addAll(members);
                      continue;
                    }
                  }
                }
                ok = false;
                unresolved.add(UnresolvedEntry(
                  equipmentId: eqId,
                  kind: 'synergyOnly',
                  detail: 'fit #$fitIndex block #$blockIndex only-ship "$n" '
                      'not in master',
                  rawHtml: fit.rawHtml,
                  rawEffect: rawEffect,
                  sourceGroupLabel: groupLabel,
                ));
              }
            }
            if (ok) {
              shipIds = onlyIds.toList()..sort();
            }
          }
          // Stat thresholds written in the group (`命中8以上`).
          for (final pt in block.predicateTexts) {
            final m = RegExp(r'^(命中|索敵|対空|火力|回避|装甲|雷装|対潜|爆装)\s*(\d+)以上$')
                .firstMatch(pt);
            if (m == null) continue;
            final v = int.parse(m.group(2)!);
            switch (m.group(1)) {
              case '命中':
                predicates.add(EquipmentPredicate(accuracyGte: v));
              case '索敵':
                predicates.add(EquipmentPredicate(lineOfSightGte: v));
              case '対空':
                predicates.add(EquipmentPredicate(antiAirGte: v));
              default:
                unresolved.add(UnresolvedEntry(
                  equipmentId: eqId,
                  kind: 'predicateText',
                  detail: 'fit #$fitIndex block #$blockIndex unsupported '
                      'threshold "$pt"',
                  rawHtml: fit.rawHtml,
                  sourceGroupLabel: groupLabel,
                ));
            }
          }
          if (block.requirementStarGte != null && predicates.isNotEmpty) {
            final base = predicates.removeLast();
            predicates.add(EquipmentPredicate(
              lineOfSightGte: base.lineOfSightGte,
              antiAirGte: base.antiAirGte,
              accuracyGte: base.accuracyGte,
              improvementGte: block.requirementStarGte,
              itemIds: base.itemIds,
              typeIds: base.typeIds,
            ));
          }
          // Synergy bonus written as a star table (star-none + rbonus).
          if (block.starAdditions.isNotEmpty) {
            final base = <String, int>{
              for (final b in block.statBonuses)
                if (b.increments.length == 1) b.stat: b.increments.first,
            };
            final cumulative = <String, int>{...base};
            final byStar = <int, Bonus>{};
            if (base.isNotEmpty) byStar[0] = Bonus({...cumulative});
            for (var star = 1; star <= 10; star++) {
              for (final a in block.starAdditions.where((a) => a.star == star)) {
                for (final s in a.additions) {
                  cumulative[s.stat] = (cumulative[s.stat] ?? 0) + s.increments.first;
                }
              }
              if (cumulative.isNotEmpty) byStar[star] = Bonus({...cumulative});
            }
            if (byStar.isEmpty) continue;
            rawRules.add(BonusRule(
              ruleId: _ruleId(eqId, 'synergy', rawRules),
              equipment: EquipmentRef(ids: [eqId]),
              category: RuleCategory.synergy,
              shipCondition: ShipCondition(
                shipIds: shipIds,
                classIds: classIds2,
                shipTypeIds: shipTypeIds.toList()..sort(),
              ),
              requires: [
                for (final p in predicates)
                  RuleRequirement(
                    predicate: p,
                    sourceLabel: block.icons.map((i) => i.title).join('/'),
                    minCount: block.requirementMinCount ?? 1,
                  ),
              ],
              effect: ImprovementTableEffect(byStar),
              source: _source(
                detailUrl,
                page,
                pageContent,
                fetchedAt,
                httpLastModified,
                contentSha,
                fragmentHash,
                groupLabel,
                rawEffect,
                annotations,
              ),
            ));
            continue;
          }
          rawRules.add(BonusRule(
            ruleId: _ruleId(eqId, 'synergy', rawRules),
            equipment: EquipmentRef(ids: [eqId]),
            category: RuleCategory.synergy,
            shipCondition: ShipCondition(
              shipIds: shipIds,
              classIds: classIds2,
              shipTypeIds: shipTypeIds.toList()..sort(),
            ),
            requires: [
              for (final p in predicates)
                RuleRequirement(
                  predicate: p,
                  sourceLabel: block.icons.map((i) => i.title).join('/'),
                  minCount: block.requirementMinCount ?? 1,
                ),
            ],
            effect: page.titleNotes.synergyNoStack
                ? OnceEffect(bonus)
                : PerEquipmentEffect(bonus),
            source: _source(
              detailUrl,
              page,
              pageContent,
              fetchedAt,
              httpLastModified,
              contentSha,
              fragmentHash,
              groupLabel,
              rawEffect,
              annotations,
            ),
          ));
          continue;
        }

        // Base effect block.
        final starGte = block.starGte;
        final hasStarTable = block.starAdditions.isNotEmpty;

        // Count-gated segments (`2機目～`, `1つ目`, `2~4つ目`) → countTable.
        if (block.countSegments.isNotEmpty) {
          final baseStats = <String, int>{
            for (final b in block.statBonuses)
              if (b.increments.length == 1) b.stat: b.increments.first,
          };
          for (final seg in block.countSegments.where((s) => s.start == 1)) {
            for (final s in seg.stats) {
              baseStats[s.stat] = (baseStats[s.stat] ?? 0) + s.increments.first;
            }
          }
          final maxEnd = block.countSegments
              .map((s) => s.end ?? 4)
              .reduce((a, b) => a > b ? a : b);
          final hasRepeat = block.countSegments.any((s) => s.end == null);
          final byCount = <int, Bonus>{};
          final increments = <int, Bonus>{};
          Bonus? prev;
          for (var n = 1; n <= maxEnd; n++) {
            final total = <String, int>{...baseStats};
            for (final seg in block.countSegments) {
              if (seg.start == 1) continue;
              if (seg.start > n) continue;
              if (seg.end != null && seg.end! < n) continue;
              for (final s in seg.stats) {
                total[s.stat] = (total[s.stat] ?? 0) + s.increments.first;
              }
            }
            final bonus = Bonus(total);
            final inc = prev == null
                ? bonus
                : Bonus({
                    for (final e in bonus.stats.entries)
                      e.key: e.value - (prev.stats[e.key] ?? 0),
                  });
            increments[n] = inc;
            byCount[n] = bonus;
            prev = bonus;
          }
          if (byCount.isEmpty) {
            unresolved.add(UnresolvedEntry(
              equipmentId: eqId,
              kind: 'countSegments',
              detail: 'fit #$fitIndex block #$blockIndex count segments empty',
              rawHtml: fit.rawHtml,
              sourceGroupLabel: groupLabel,
            ));
            continue;
          }
          rawRules.add(BonusRule(
            ruleId: _ruleId(eqId, 'count', rawRules),
            equipment: EquipmentRef(ids: [eqId]),
            category: RuleCategory.count,
            shipCondition: ShipCondition(
              shipIds: sortedShips,
              classIds: classIds.toList()..sort(),
              shipTypeIds: shipTypeIds.toList()..sort(),
            ),
            effect: CountTableEffect(
              increments,
              byCount,
              overflow: hasRepeat
                  ? 'repeat'
                  : (maxEnd < 10 ? 'cap' : 'unresolved'),
            ),
            source: _source(
              detailUrl,
              page,
              pageContent,
              fetchedAt,
              httpLastModified,
              contentSha,
              fragmentHash,
              groupLabel,
              rawEffect,
              annotations,
            ),
          ));
          continue;
        }

        // Named-equipment synergy (`15.2cm三連装砲：火力+2`): resolve the
        // equipment name against master; emit a synergy rule.
        if (block.equipmentNames.isNotEmpty) {
          final itemIds = <int>[];
          final unresolvedNames = <String>[];
          for (final name in block.equipmentNames) {
            final ids = master.itemIdsByName[name];
            if (ids == null || ids.isEmpty) {
              unresolvedNames.add(name);
            } else {
              itemIds.addAll(ids);
            }
          }
          if (unresolvedNames.isNotEmpty) {
            unresolved.add(UnresolvedEntry(
              equipmentId: eqId,
              kind: 'synergyEquipment',
              detail:
                  'fit #$fitIndex block #$blockIndex unknown equipment ${unresolvedNames.join("/")}',
              rawHtml: fit.rawHtml,
              rawEffect: rawEffect,
              sourceGroupLabel: groupLabel,
            ));
            continue;
          }
          final bonus = Bonus({
            for (final b in block.statBonuses) b.stat: b.increments.first,
          });
          if (bonus.isEmpty) {
            unresolved.add(UnresolvedEntry(
              equipmentId: eqId,
              kind: 'synergyEmpty',
              detail: 'fit #$fitIndex block #$blockIndex has no stats',
              rawHtml: fit.rawHtml,
              sourceGroupLabel: groupLabel,
            ));
            continue;
          }
          rawRules.add(BonusRule(
            ruleId: _ruleId(eqId, 'synergy', rawRules),
            equipment: EquipmentRef(ids: [eqId]),
            category: RuleCategory.synergy,
            shipCondition: ShipCondition(
              shipIds: sortedShips,
              classIds: classIds.toList()..sort(),
              shipTypeIds: shipTypeIds.toList()..sort(),
            ),
            requires: [
              for (final name in block.equipmentNames)
                RuleRequirement(
                  predicate: EquipmentPredicate(
                      itemIds: master.itemIdsByName[name] ?? const []),
                  sourceLabel: name,
                ),
            ],
            effect: page.titleNotes.synergyNoStack
                ? OnceEffect(bonus)
                : PerEquipmentEffect(bonus),
            source: _source(
              detailUrl,
              page,
              pageContent,
              fetchedAt,
              httpLastModified,
              contentSha,
              fragmentHash,
              groupLabel,
              rawEffect,
              annotations,
            ),
          ));
          continue;
        }

        if (hasStarTable) {
          // improvementTable: total at each star = base + cumulative
          // additions up to that star. Star 0 carries the base bonus.
          final base = <String, int>{
            for (final b in block.statBonuses)
              if (b.increments.length == 1) b.stat: b.increments.first,
          };
          final cumulative = <String, int>{...base};
          final byStar = <int, Bonus>{};
          if (base.isNotEmpty) {
            byStar[0] = Bonus({...cumulative});
          }
          final seenStars = <int>{};
          for (var star = 1; star <= 10; star++) {
            final add = block.starAdditions.where((a) => a.star == star);
            for (final a in add) {
              for (final s in a.additions) {
                if (s.increments.length != 1) {
                  unresolved.add(UnresolvedEntry(
                    equipmentId: eqId,
                    kind: 'starTable',
                    detail:
                        'fit #$fitIndex star $star has count sequence "${s.rawText}"',
                    rawHtml: fit.rawHtml,
                    sourceGroupLabel: groupLabel,
                  ));
                } else {
                  cumulative[s.stat] =
                      (cumulative[s.stat] ?? 0) + s.increments.first;
                }
              }
              seenStars.add(star);
            }
            if (cumulative.isNotEmpty) {
              byStar[star] = Bonus({...cumulative});
            }
          }
          if (byStar.isEmpty) {
            // All stars are なし: the row grants nothing at any star level,
            // so there is nothing to represent.
            continue;
          }
          rawRules.add(BonusRule(
            ruleId: _ruleId(eqId, 'improvement', rawRules),
            equipment: EquipmentRef(ids: [eqId]),
            category: RuleCategory.improvement,
            shipCondition: ShipCondition(
              shipIds: sortedShips,
              classIds: classIds.toList()..sort(),
              shipTypeIds: shipTypeIds.toList()..sort(),
            ),
            equipmentCondition: EquipmentCondition(
              minImprovement: 0,
              maxImprovement: 10,
            ),
            effect: ImprovementTableEffect(byStar),
            source: _source(
              detailUrl,
              page,
              pageContent,
              fetchedAt,
              httpLastModified,
              contentSha,
              fragmentHash,
              groupLabel,
              rawEffect,
              annotations,
            ),
          ));
          continue;
        }

        for (final sb in block.statBonuses) {
          // Split sub-rules by condition.
          final condition = sb.condition;
          final condShipIds = <int>{...sortedShips};
          final condClassIds = <int>{...classIds};
          final condShipTypeIds = <int>{...shipTypeIds};
          var rawCondition = condition.raw;
          final condNotes = <String>[];
          if (condition.onlyShipNames.isNotEmpty) {
            final onlyIds = <int>[];
            for (final n in condition.onlyShipNames) {
              final ids = master.shipIdsByName[n];
              if (ids == null || ids.isEmpty) {
                unresolved.add(UnresolvedEntry(
                  equipmentId: eqId,
                  kind: 'only',
                  detail: 'fit #$fitIndex only-ship "$n" not in master',
                  rawHtml: fit.rawHtml,
                  rawEffect: sb.rawText,
                  sourceGroupLabel: groupLabel,
                ));
              } else {
                onlyIds.addAll(ids);
              }
            }
            condShipIds
              ..clear()
              ..addAll(onlyIds);
            condClassIds.clear();
          }
          if (condition.excludeShipNames.isNotEmpty) {
            final exclIds = <int>[];
            for (final n in condition.excludeShipNames) {
              final ids = master.shipIdsByName[n];
              if (ids == null || ids.isEmpty) {
                unresolved.add(UnresolvedEntry(
                  equipmentId: eqId,
                  kind: 'exclude',
                  detail: 'fit #$fitIndex exclude-ship "$n" not in master',
                  rawHtml: fit.rawHtml,
                  rawEffect: sb.rawText,
                  sourceGroupLabel: groupLabel,
                ));
              } else {
                exclIds.addAll(ids);
              }
            }
            condShipIds.removeWhere(exclIds.contains);
          }
          final minImp = condition.minImprovement ?? starGte;
          final maxImp = condition.maxImprovement;
          if (minImp != null && maxImp != null && maxImp < minImp) {
            unresolved.add(UnresolvedEntry(
              equipmentId: eqId,
              kind: 'improvement',
              detail:
                  'fit #$fitIndex invalid star range ${sb.rawText}',
              rawHtml: fit.rawHtml,
              sourceGroupLabel: groupLabel,
            ));
            continue;
          }

          if (sb.isCountSequence) {
            final increments = <int, Bonus>{};
            final byCount = <int, Bonus>{};
            var cum = <String, int>{};
            for (var i = 0; i < sb.increments.length; i++) {
              final v = sb.increments[i];
              increments[i + 1] = Bonus({sb.stat: v});
              cum = {...cum, sb.stat: (cum[sb.stat] ?? 0) + v};
              byCount[i + 1] = Bonus(cum);
            }
            rawRules.add(BonusRule(
              ruleId: _ruleId(eqId, 'count', rawRules),
              equipment: EquipmentRef(ids: [eqId]),
              category: RuleCategory.count,
              shipCondition: ShipCondition(
                shipIds: condShipIds.toList()..sort(),
                classIds: condClassIds.toList()..sort(),
                shipTypeIds: condShipTypeIds.toList()..sort(),
              ),
              equipmentCondition: EquipmentCondition(
                minImprovement: minImp ?? 0,
                maxImprovement: maxImp ?? 10,
              ),
              effect: CountTableEffect(increments, byCount),
              source: _source(
                detailUrl,
                page,
                pageContent,
                fetchedAt,
                httpLastModified,
                contentSha,
                fragmentHash,
                groupLabel,
                sb.rawText,
                annotations,
                rawCondition,
                condNotes,
              ),
            ));
            continue;
          }

          final bonus = Bonus({sb.stat: sb.increments.first});
          final isImprovement = minImp != null || maxImp != null;
          rawRules.add(BonusRule(
            ruleId: _ruleId(
                eqId,
                isImprovement ? 'improvement' : 'single',
                rawRules),
            equipment: EquipmentRef(ids: [eqId]),
            category:
                isImprovement ? RuleCategory.improvement : RuleCategory.single,
            shipCondition: ShipCondition(
              shipIds: condShipIds.toList()..sort(),
              classIds: condClassIds.toList()..sort(),
            ),
            equipmentCondition: EquipmentCondition(
              minImprovement: minImp ?? 0,
              maxImprovement: maxImp ?? 10,
            ),
            effect: (minImp == null && maxImp == null)
                ? (page.titleNotes.singleNoStack
                    ? OnceEffect(bonus)
                    : PerEquipmentEffect(bonus))
                : PerEquipmentEffect(bonus),
            source: _source(
              detailUrl,
              page,
              pageContent,
              fetchedAt,
              httpLastModified,
              contentSha,
              fragmentHash,
              groupLabel,
              sb.rawText,
              annotations,
              rawCondition,
              condNotes,
            ),
          ));
        }
      }
    }
    // Assign final ruleIds in a deterministic order: per category, ordered
    // by source group label, raw effect text, then fragment hash.
    final ordered = List<BonusRule>.of(rawRules)..sort((a, b) {
        final c = a.category.name.compareTo(b.category.name);
        if (c != 0) return c;
        final g = a.source.sourceGroupLabel.compareTo(b.source.sourceGroupLabel);
        if (g != 0) return g;
        final e = a.source.rawEffect.compareTo(b.source.rawEffect);
        if (e != 0) return e;
        return a.source.fragmentHash.compareTo(b.source.fragmentHash);
      });
    final rules = <BonusRule>[];
    final counters = <String, int>{};
    for (final r in ordered) {
      final cat = r.category.name;
      final n = (counters[cat] ?? 0) + 1;
      counters[cat] = n;
      rules.add(BonusRule(
        ruleId: 'akashi-$eqId-$cat-${n.toString().padLeft(3, '0')}',
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
    return RuleBuildResult(rules, unresolved);
  }

  SourceInfo _source(
    String url,
    DetailParseResult page,
    String pageContent,
    String fetchedAt,
    String? httpLastModified,
    String contentSha,
    String fragmentHash,
    String groupLabel,
    String rawEffect,
    List<String> annotations, [
    String? rawCondition,
    List<String> notes = const [],
  ]) {
    final joined = [
      ...annotations,
      ...notes,
    ];
    return SourceInfo(
      url: url,
      pageName: page.pageName,
      fetchedAt: fetchedAt,
      httpLastModified: httpLastModified,
      contentSha256: contentSha,
      fragmentHash: fragmentHash,
      sourceGroupLabel: groupLabel,
      rawEffect: rawEffect,
      rawCondition: rawCondition,
      annotation: joined.isEmpty ? null : joined.join(' '),
    );
  }
}

String _ruleId(int eqId, String category, List<BonusRule> rules) {
  final count = rules
          .where((r) => r.category.name == category)
          .length +
      1;
  return 'akashi-$eqId-$category-${count.toString().padLeft(3, '0')}';
}
