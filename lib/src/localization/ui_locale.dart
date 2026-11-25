import 'package:flutter/widgets.dart';

Locale? uiLocaleFromStorageCode(String? code) => switch (code) {
  null => null,
  'zh_Hant' => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  _ => Locale(code),
};

/// Shares the same regional-language rules between UI, fonts and notifications.
String uiLocaleStorageCode(Locale? locale) {
  if (locale?.languageCode == 'ja') return 'ja';
  if (locale?.languageCode == 'ko') return 'ko';
  if (locale?.languageCode == 'en') return 'en';
  if (locale?.languageCode == 'zh' && locale?.scriptCode == 'Hans') return 'zh';
  if (locale?.languageCode == 'zh' &&
      (locale?.scriptCode == 'Hant' ||
          const ['TW', 'HK', 'MO'].contains(locale?.countryCode))) {
    return 'zh_Hant';
  }
  return 'zh';
}

Locale resolveUiLocale(Locale? locale, Iterable<Locale> supportedLocales) {
  final code = uiLocaleStorageCode(locale);
  return supportedLocales.firstWhere(
    (supported) => uiLocaleStorageCode(supported) == code,
    orElse: () => const Locale('zh'),
  );
}
