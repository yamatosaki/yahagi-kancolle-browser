import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/l10n/app_localizations.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_controller.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_dataset.dart';
import 'package:yahagi_kancolle_browser/src/quest/quest_catalog_update_service.dart';
import 'package:yahagi_kancolle_browser/src/settings/quest_catalog_update_section.dart';

void main() {
  testWidgets('shows version and disables duplicate manual checks', (
    tester,
  ) async {
    final completer = Completer<QuestCatalogUpdateResult>();
    final controller = QuestCatalogController(
      dataset: _dataset('old', 1),
      updater: _Updater(completer.future),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    expect(find.text('任务资料'), findsOneWidget);
    expect(find.textContaining(controller.version.shortLabel), findsOneWidget);
    await tester.tap(find.byKey(const Key('quest-catalog-check-button')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('quest-catalog-check-button')),
          )
          .onPressed,
      isNull,
    );
    completer.complete(QuestCatalogUpToDate(controller.version));
    await tester.pumpAndSettle();
    expect(find.textContaining('任务资料已经是最新版本'), findsOneWidget);
  });

  testWidgets('reports a hot-applied update', (tester) async {
    final controller = QuestCatalogController(
      dataset: _dataset('old', 1),
      updater: _Updater(Future.value(QuestCatalogUpdated(_dataset('new', 2)))),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('quest-catalog-check-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('已立即生效'), findsOneWidget);
    expect(find.textContaining(controller.version.shortLabel), findsWidgets);
  });
}

QuestCatalogDataset _dataset(String name, int day) {
  final raw = jsonEncode(<String, Object?>{
    '1': <String, Object?>{'code': 'A1', 'name': name, 'desc': ''},
  });
  return QuestCatalogDataset.parse(
    rawJson: raw,
    version: QuestCatalogVersion(
      committedAt: DateTime.utc(2026, 8, day),
      commitSha: day.toRadixString(16).padLeft(40, '0'),
      sha256: sha256.convert(utf8.encode(raw)).toString(),
    ),
    minimumQuestCount: 1,
  );
}

Widget _app(QuestCatalogController controller) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: QuestCatalogUpdateSection(controller: controller)),
);

final class _Updater implements QuestCatalogUpdateClient {
  _Updater(this.result);
  final Future<QuestCatalogUpdateResult> result;
  @override
  Future<QuestCatalogUpdateResult> checkAndUpdate({
    required QuestCatalogDataset current,
  }) => result;
}
