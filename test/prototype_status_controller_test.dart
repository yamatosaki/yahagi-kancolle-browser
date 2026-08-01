import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/prototype_status_controller.dart';

void main() {
  group('PrototypeStatusController', () {
    test('tracks WebView lifecycle', () {
      final controller = PrototypeStatusController();

      expect(controller.loadState, WebViewLoadState.idle);

      controller.onPageStarted('https://example.invalid');
      expect(controller.loadState, WebViewLoadState.loading);

      controller.onPageFinished('https://example.invalid');
      expect(controller.loadState, WebViewLoadState.ready);

      controller.onWebResourceError('network unavailable');
      expect(controller.loadState, WebViewLoadState.failed);
      expect(controller.errorMessage, 'network unavailable');
    });

    test('stores valid bridge events without exposing unrelated messages', () {
      final controller = PrototypeStatusController();

      controller.onJavaScriptMessage(
        '{"kind":"kcsapi-response",'
        '"path":"/kcsapi/api_get_member/basic",'
        '"body":"svdata={\\"api_result\\":1}",'
        '"source":"xhr"}',
      );

      expect(controller.capturedEvents, hasLength(1));
      expect(controller.lastEvent?.path, '/kcsapi/api_get_member/basic');

      controller.onJavaScriptMessage(
        '{"kind":"telemetry","path":"/tracking","body":"secret"}',
      );

      expect(controller.capturedEvents, hasLength(1));
      expect(controller.lastBridgeError, isNotNull);
    });

    test('ignores every bridge message when capture is disabled', () {
      final controller = PrototypeStatusController(captureEnabled: () => false);

      controller.onJavaScriptMessage(
        '{"kind":"kcsapi-response",'
        '"path":"/kcsapi/api_get_member/basic",'
        '"body":"svdata={\\"api_result\\":1}",'
        '"source":"xhr"}',
      );

      expect(controller.capturedEvents, isEmpty);
      expect(controller.lastBridgeError, isNull);
    });

    test('bounds prototype bridge event count and message size', () {
      final controller = PrototypeStatusController(
        maxEvents: 2,
        maxMessageBytes: 180,
      );
      const eventPrefix =
          '{"kind":"kcsapi-response",'
          '"path":"/kcsapi/api_get_member/basic",'
          '"body":"svdata={\\"api_result\\":';
      const eventSuffix = '}","source":"xhr"}';

      controller.onJavaScriptMessage('${eventPrefix}1$eventSuffix');
      controller.onJavaScriptMessage('${eventPrefix}2$eventSuffix');
      controller.onJavaScriptMessage('${eventPrefix}3$eventSuffix');

      expect(controller.capturedEvents, hasLength(2));
      expect(controller.capturedEvents.first.responseBody, contains(':2'));
      expect(controller.capturedEvents.last.responseBody, contains(':3'));

      controller.onJavaScriptMessage(
        '${eventPrefix}4,"padding":"${'x' * 200}"$eventSuffix',
      );
      expect(controller.capturedEvents, hasLength(2));
      expect(controller.lastBridgeError, 'Bridge message exceeds size limit');
    });
  });
}
