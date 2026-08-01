import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/game_page_alignment_script.dart';

void main() {
  test('alignment pins the 1200 by 720 game frame without touching data', () {
    expect(
      gamePageAlignmentScript,
      contains("location.pathname.includes('kancolle')"),
    );
    expect(gamePageAlignmentScript, contains('854854'));
    expect(gamePageAlignmentScript, contains('osapi.dmm.com'));
    expect(gamePageAlignmentScript, contains('/kcs'));
    expect(gamePageAlignmentScript, contains('#game_frame'));
    expect(gamePageAlignmentScript, contains('width: 1200px !important'));
    expect(gamePageAlignmentScript, contains('height: 720px !important'));
    expect(gamePageAlignmentScript, contains('position: fixed !important'));
    expect(gamePageAlignmentScript, isNot(contains('document.cookie')));
    expect(gamePageAlignmentScript, isNot(contains('XMLHttpRequest')));
    expect(gamePageAlignmentScript, isNot(contains('fetch(')));
  });

  test('alignment hides the DMM page shell around the game viewport', () {
    expect(gamePageAlignmentScript, contains('#spacing_top'));
    expect(gamePageAlignmentScript, contains('#ntg-recommend'));
    expect(gamePageAlignmentScript, contains('.naviapp'));
    expect(gamePageAlignmentScript, contains('aside'));
    expect(gamePageAlignmentScript, contains('footer'));
    expect(gamePageAlignmentScript, contains('inset: 0 !important'));
    expect(gamePageAlignmentScript, contains('overflow: hidden !important'));
    expect(
      gamePageAlignmentScript,
      contains('transform-origin: 0 0 !important'),
    );
  });

  test('alignment skips non-game and DMM account pages', () {
    expect(gamePageAlignmentScript, contains('accounts.dmm.com'));
    expect(gamePageAlignmentScript, contains('isGamePage'));
  });

  test('alignment exposes a manual align hook on window', () {
    expect(gamePageAlignmentScript, contains('window.__yahagiMobileAlignGame'));
    expect(gamePageAlignmentScript, contains('window.scrollTo(0, 0)'));
  });
}
