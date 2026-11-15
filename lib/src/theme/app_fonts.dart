abstract final class AppFonts {
  static const simplifiedChinese = 'HarmonyOS_Sans_SC';
  static const traditionalChinese = 'HarmonyOS_Sans_TC';
  static const common = 'HarmonyOS_Sans';
  static const condensed = 'HarmonyOS_Sans_Condensed';

  static String forLocale(String localeCode) => switch (localeCode) {
    'zh_Hant' => traditionalChinese,
    // HarmonyOS Sans contains Latin glyphs; Android's system fallback supplies
    // Hangul, while CJK fallback below keeps original Japanese game names legible.
    'ko' => common,
    'en' => common,
    _ => simplifiedChinese,
  };

  static List<String> fallbackForLocale(
    String localeCode,
  ) => switch (localeCode) {
    'ko' => const <String>['sans-serif', simplifiedChinese, traditionalChinese],
    'zh_Hant' => const <String>[simplifiedChinese, common],
    'en' => const <String>[simplifiedChinese, traditionalChinese, 'sans-serif'],
    _ => const <String>[traditionalChinese, common],
  };
}
