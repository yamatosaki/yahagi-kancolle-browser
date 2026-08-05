import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_channel.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_controller.dart';
import 'package:yahagi_kancolle_browser/src/browser/gadget_bypass_store.dart';
import 'package:yahagi_kancolle_browser/src/settings/gadget_bypass_section.dart';

class _MemoryBypassStore implements GadgetBypassStore {
  GadgetBypassSettings settings = const GadgetBypassSettings();

  @override
  Future<GadgetBypassSettings> load() async => settings;

  @override
  Future<void> save(GadgetBypassSettings settings) async {
    this.settings = settings;
  }
}

class _FakeBypassPort implements GadgetBypassPort {
  @override
  Future<bool> configure({
    required bool enabled,
    required String endpoint,
  }) async {
    return true;
  }

  @override
  Future<GadgetBypassStatus> status() async =>
      const GadgetBypassStatus(enabled: false, endpoint: '', supported: true);

  @override
  Future<bool> clearCache() async => true;

  @override
  Future<GadgetBypassDiagnoseResult> diagnose() async {
    return GadgetBypassDiagnoseResult(
      w00g: GadgetBypassProbe(
        reachable: true,
        statusCode: 403,
        elapsedMs: 12,
      ),
      endpoint: GadgetBypassProbe(
        reachable: true,
        statusCode: 200,
        elapsedMs: 34,
      ),
      kcsapi: GadgetBypassProbe(reachable: false, elapsedMs: 5000),
    );
  }
}

void main() {
  testWidgets('toggle persists the bypass switch state', (tester) async {
    final store = _MemoryBypassStore();
    final controller = await GadgetBypassController.load(
      store,
      port: _FakeBypassPort(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GadgetBypassSection(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('gadget-bypass-switch'));
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(controller.enabled, isTrue);
    expect(store.settings.enabled, isTrue);
  });

  testWidgets('successful enable requests an immediate game reload', (
    tester,
  ) async {
    final store = _MemoryBypassStore();
    final controller = await GadgetBypassController.load(
      store,
      port: _FakeBypassPort(),
    );
    var reloads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GadgetBypassSection(
            controller: controller,
            onReloadRequired: () async => reloads++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('gadget-bypass-switch')));
    await tester.pumpAndSettle();

    expect(controller.enabled, isTrue);
    expect(reloads, 1);
  });

  testWidgets('endpoint presets and custom endpoint field work', (
    tester,
  ) async {
    final store = _MemoryBypassStore();
    final controller = await GadgetBypassController.load(
      store,
      port: _FakeBypassPort(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GadgetBypassSection(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('gadget-bypass-endpoint-dropdown')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('gadget-bypass-endpoint-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('luckyjervis.com').last);
    await tester.pumpAndSettle();

    expect(controller.endpoint, 'https://luckyjervis.com/');
    expect(store.settings.endpoint, 'https://luckyjervis.com/');
  });

  testWidgets('diagnose button shows probe results', (tester) async {
    final store = _MemoryBypassStore();
    final controller = await GadgetBypassController.load(
      store,
      port: _FakeBypassPort(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GadgetBypassSection(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('gadget-bypass-diagnose-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('gadget-bypass-diagnose-w00g')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('gadget-bypass-diagnose-endpoint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('gadget-bypass-diagnose-kcsapi')),
      findsNothing,
    );
    expect(find.textContaining('12ms'), findsOneWidget);
    expect(find.textContaining('HTTP 403'), findsOneWidget);
  });
}
