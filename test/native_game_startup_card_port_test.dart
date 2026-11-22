import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/native_game_startup_card_port.dart';

void main() {
  test('encodes native startup content without a configurable position', () {
    const opening = NativeGameStartupCardData(title: 'Opening entry page');
    const preloading = NativeGameStartupCardData(
      title: 'Loading game resources',
      stage: 'Starting game',
      requests: '13 resources',
      stalled: true,
    );

    expect(opening.toMap(), {'title': 'Opening entry page', 'stalled': false});
    expect(preloading.toMap(), {
      'title': 'Loading game resources',
      'stage': 'Starting game',
      'requests': '13 resources',
      'stalled': true,
    });
    expect(
      const NativeGameStartupCardData(
        title: 'Opening entry page',
        pageProgress: 34,
      ).toMap()['pageProgress'],
      34,
    );
  });
}
