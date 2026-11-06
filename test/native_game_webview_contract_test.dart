import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_webview_contract.dart';

void main() {
  group('NativeGameWebViewBounds', () {
    test(
      'serializes a separate optional clip and rejects partial or empty clips',
      () {
        NativeGameWebViewBounds bounds({
          double? left,
          double? top,
          double? width,
          double? height,
        }) => NativeGameWebViewBounds(
          left: -100,
          top: -50,
          width: 1000,
          height: 600,
          devicePixelRatio: 2,
          clipLeft: left,
          clipTop: top,
          clipWidth: width,
          clipHeight: height,
        );
        expect(bounds(left: 40, top: 10, width: 260, height: 470).toMap(), {
          'left': -100.0,
          'top': -50.0,
          'width': 1000.0,
          'height': 600.0,
          'devicePixelRatio': 2.0,
          'clipLeft': 40.0,
          'clipTop': 10.0,
          'clipWidth': 260.0,
          'clipHeight': 470.0,
        });
        expect(() => bounds(left: 0), throwsArgumentError);
        expect(
          () => bounds(left: 0, top: 0, width: 0, height: 100),
          throwsArgumentError,
        );
        expect(
          () => bounds(left: 0, top: 0, width: 100, height: double.nan),
          throwsArgumentError,
        );
      },
    );

    test('serializes the exact native bounds schema', () {
      final bounds = NativeGameWebViewBounds(
        left: 1.5,
        top: 2.5,
        width: 3.5,
        height: 4.5,
        devicePixelRatio: 2,
      );

      expect(bounds.toMap(), <String, double>{
        'left': 1.5,
        'top': 2.5,
        'width': 3.5,
        'height': 4.5,
        'devicePixelRatio': 2,
      });
    });

    test('rejects every non-finite and non-positive bound value', () {
      for (final invalid in <double>[double.nan, double.infinity]) {
        expect(
          () => NativeGameWebViewBounds(
            left: invalid,
            top: 0,
            width: 1,
            height: 1,
            devicePixelRatio: 1,
          ),
          throwsArgumentError,
        );
        expect(
          () => NativeGameWebViewBounds(
            left: 0,
            top: invalid,
            width: 1,
            height: 1,
            devicePixelRatio: 1,
          ),
          throwsArgumentError,
        );
      }
      for (final invalid in <double>[0, -1, double.nan, double.infinity]) {
        expect(
          () => NativeGameWebViewBounds(
            left: 0,
            top: 0,
            width: invalid,
            height: 1,
            devicePixelRatio: 1,
          ),
          throwsArgumentError,
        );
        expect(
          () => NativeGameWebViewBounds(
            left: 0,
            top: 0,
            width: 1,
            height: invalid,
            devicePixelRatio: 1,
          ),
          throwsArgumentError,
        );
        expect(
          () => NativeGameWebViewBounds(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            devicePixelRatio: invalid,
          ),
          throwsArgumentError,
        );
      }
    });
  });

  group('NativeGameWebViewEvent.decode', () {
    test(
      'pending presentation is distinct and old bool events stay compatible',
      () {
        final pending = NativeGameWebViewEvent.decode(<String, Object?>{
          'type': 'presentationChanged',
          'generationId': 7,
          'isGame': false,
          'state': 'pending',
        });
        expect(pending.presentationState, NativeGamePresentationState.pending);
        final oldGame = NativeGameWebViewEvent.decode(<String, Object?>{
          'type': 'presentationChanged',
          'generationId': 7,
          'isGame': true,
        });
        expect(oldGame.presentationState, NativeGamePresentationState.game);
        final oldWeb = NativeGameWebViewEvent.decode(<String, Object?>{
          'type': 'presentationChanged',
          'generationId': 7,
          'isGame': false,
        });
        expect(oldWeb.presentationState, NativeGamePresentationState.web);
        for (final state in <String>['unknown', 'game']) {
          expect(
            () => NativeGameWebViewEvent.decode(<String, Object?>{
              'type': 'presentationChanged',
              'generationId': 7,
              'isGame': false,
              'state': state,
            }),
            throwsA(isA<NativeGameWebViewSchemaException>()),
          );
        }
      },
    );

    test('decodes every event schema and sanitizes page URLs', () {
      final created = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'created',
        'generationId': 0,
      });
      final started = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'pageStarted',
        'generationId': 1,
        'url': 'https://www.dmm.com/game?token=secret#fragment',
      });
      final finished = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'pageFinished',
        'generationId': 1,
        'url': 'https://www.dmm.com/game',
      });
      final error = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'mainFrameError',
        'generationId': 1,
        'errorCode': -2,
        'description': 'network error',
      });
      final blocked = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'navigationBlocked',
        'generationId': 1,
        'scheme': 'intent+app',
      });
      final gone = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'renderProcessGone',
        'generationId': 1,
        'didCrash': true,
      });
      final presentation = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'presentationChanged',
        'generationId': 1,
        'isGame': true,
      });
      final destroyed = NativeGameWebViewEvent.decode(<String, Object?>{
        'type': 'destroyed',
        'generationId': 1,
      });

      expect(created.type, NativeGameWebViewEventType.created);
      expect(started.type, NativeGameWebViewEventType.pageStarted);
      expect(started.url, 'https://www.dmm.com/game');
      expect(
        started.navigationUri,
        Uri.parse('https://www.dmm.com/game?token=secret#fragment'),
      );
      expect(finished.type, NativeGameWebViewEventType.pageFinished);
      expect(error.errorCode, -2);
      expect(error.description, 'network error');
      expect(blocked.scheme, 'intent+app');
      expect(gone.didCrash, isTrue);
      expect(presentation.type.name, 'presentationChanged');
      expect(destroyed.type, NativeGameWebViewEventType.destroyed);
    });

    test('rejects malformed event data and unsafe values', () {
      final invalidEvents = <Object?>[
        'not a map',
        <String, Object?>{'type': 'created'},
        <String, Object?>{'type': 'created', 'generationId': 0, 'extra': true},
        <String, Object?>{'type': 'unknown', 'generationId': 0},
        <String, Object?>{'type': 'created', 'generationId': -1},
        <String, Object?>{'type': 'created', 'generationId': '0'},
        <String, Object?>{
          'type': 'pageStarted',
          'generationId': 0,
          'url': 'intent://private',
        },
        <String, Object?>{
          'type': 'navigationBlocked',
          'generationId': 0,
          'scheme': 'not valid!',
        },
        <String, Object?>{
          'type': 'mainFrameError',
          'generationId': 0,
          'errorCode': 'bad',
          'description': 'x',
        },
        <String, Object?>{
          'type': 'renderProcessGone',
          'generationId': 0,
          'didCrash': 'true',
        },
        <String, Object?>{
          'type': 'pageFinished',
          'generationId': 0,
          'url': 'https://www.dmm.com/${'a' * 2049}',
        },
        <String, Object?>{
          'type': 'mainFrameError',
          'generationId': 0,
          'errorCode': 1,
          'description': 'a' * 257,
        },
      ];

      for (final event in invalidEvents) {
        expect(
          () => NativeGameWebViewEvent.decode(event),
          throwsA(isA<NativeGameWebViewSchemaException>()),
        );
      }
    });
  });
}
