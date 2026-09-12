abstract final class AppFonts {
  static const simplifiedChinese = 'HarmonyOS_Sans_SC';
  static const traditionalChinese = 'HarmonyOS_Sans_TC';
  static const common = 'HarmonyOS_Sans';

  static String forLocale(String localeCode) =>
      localeCode == 'zh_Hant' ? traditionalChinese : simplifiedChinese;

  static List<String> fallbackForLocale(String localeCode) =>
      localeCode == 'zh_Hant'
      ? const <String>[simplifiedChinese, common]
      : const <String>[traditionalChinese, common];
}
