import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _readArb(String name) {
  return jsonDecode(File('lib/l10n/$name').readAsStringSync())
      as Map<String, Object?>;
}

Set<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

Map<String, Object?> _metadataFor(Map<String, Object?> arb, String key) {
  return (arb['@$key'] as Map<String, Object?>?) ?? const {};
}

Set<String> _placeholderNames(Map<String, Object?> metadata) {
  final placeholders = metadata['placeholders'];
  return placeholders is Map<String, Object?> ? placeholders.keys.toSet() : {};
}

void main() {
  final resources = <String, Map<String, Object?>>{
    'zh': _readArb('app_zh.arb'),
    'zh_Hant': _readArb('app_zh_Hant.arb'),
    'ja': _readArb('app_ja.arb'),
  };

  test(
    'all locales have identical message, metadata and placeholder schemas',
    () {
      final template = resources['zh']!;
      final expectedKeys = _messageKeys(template);

      for (final entry in resources.entries) {
        expect(_messageKeys(entry.value), expectedKeys, reason: entry.key);
        for (final key in expectedKeys) {
          final expectedMetadata = _metadataFor(template, key);
          final actualMetadata = _metadataFor(entry.value, key);
          expect(
            actualMetadata.keys.toSet(),
            expectedMetadata.keys.toSet(),
            reason: '${entry.key}: @$key metadata',
          );
          expect(
            _placeholderNames(actualMetadata),
            _placeholderNames(expectedMetadata),
            reason: '${entry.key}: $key placeholders',
          );
        }
      }
    },
  );

  test('identical translations are limited to reviewed terminology', () {
    // Each entry is intentionally shared: product/game terminology, numerals,
    // protocol names, or a language self-name. Adding a key requires review.
    const reviewedZhHant = <String>{
      'appTitle',
      'repair',
      'construction',
      'httpProxy',
      'socks5Proxy',
      'hostHint',
      // These repair mode names and the active-repair status use the same
      // established game terminology in Simplified and Traditional Chinese.
      'repairDockMode',
      'anchorageRepairMode',
      'repairing',
      'forecast',
      'detailed',
      'accepted',
      'completed',
      'questDaily',
      'questWeekly',
      'questMonthly',
      'questOther',
      'questUnknown',
      'latestVersionLabel',
      'cancel',
      'speed',
      'firepower',
      'airPower',
      'fuel',
      'hp',
      'fastSpeed',
      'slowSpeed',
      'gotIt',
      'notRepairing',
      'cost',
      'notConstructing',
      'lsc',
      'constructing',
      'constructComplete',
      'resourceTrend7d',
      'resourceTrend30d',
      'langZh',
      'langZhHant',
      'langJa',
      'friend',
      'drop',
      'fleetStandby',
      'highSpeed',
      'lowSpeed',
      'airStateLabel',
      'back',
      'dropLabel',
      'item',
      // These short status terms use the same standard Han spelling in both
      // Simplified and Traditional Chinese.
      'statusUnknown',
      'statusSuccess',
      // The established formula name is written identically in both locales.
      'formula33',
      // 改修 is the in-game term in both Chinese scripts; 受限 is unchanged.
      'improvement',
      'gadgetBypassRestricted',
      // Short game/UI terms conventionally share the same Han spelling.
      'highSpeedPlus',
      'all',
      'clear',
      'done',
      'questSeasonal',
      'questYearly',
      'notCompleted',
    };
    const reviewedJa = <String>{
      'appTitle',
      'construction',
      // 入渠 and 泊地 are the established Japanese in-game repair mode names.
      'repairDockMode',
      'anchorageRepairMode',
      'firepower',
      'torpedo',
      'airPower',
      'fuel',
      'fastSpeed',
      'slowSpeed',
      'constructing',
      'langZh',
      'langZhHant',
      'langJa',
      'highSpeed',
      'lowSpeed',
      'airStateLabel',
      // 「成功」 is the established Japanese status label as well.
      'statusSuccess',
      // 「33式」 is the in-game formula name in Japanese as well.
      'formula33',
      // 改修 and 画面 are established UI terms shared with Japanese.
      'improvement',
      'settingsTabScreen',
      // These established game terms use the same spelling in Japanese.
      'armor',
      'evasion',
      'highSpeedPlus',
      'questRemodeling',
    };

    Set<String> identical(String locale) {
      final zh = resources['zh']!;
      final other = resources[locale]!;
      return _messageKeys(zh).where((key) => zh[key] == other[key]).toSet();
    }

    expect(identical('zh_Hant'), reviewedZhHant);
    expect(identical('ja'), reviewedJa);
  });
}
