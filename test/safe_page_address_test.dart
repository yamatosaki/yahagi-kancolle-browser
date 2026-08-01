import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/browser/safe_page_address.dart';

void main() {
  test('display address removes query and fragment', () {
    expect(
      SafePageAddress.fromRaw(
        'https://accounts.dmm.com/login?token=secret#callback',
      ).displayText,
      'https://accounts.dmm.com/login',
    );
  });

  test('display address removes DMM parameters embedded in the path', () {
    expect(
      SafePageAddress.fromRaw(
        'https://accounts.dmm.com/service/login/password/=/path=secret-ticket',
      ).displayText,
      'https://accounts.dmm.com/service/login/password',
    );
  });

  test('invalid address never echoes raw input', () {
    expect(
      SafePageAddress.fromRaw('not a url?token=secret').displayText,
      '未知页面',
    );
  });

  test('only http and https schemes can navigate inside the WebView', () {
    expect(
      SafePageAddress.canNavigate(Uri.parse('https://www.dmm.com')),
      isTrue,
    );
    expect(
      SafePageAddress.canNavigate(Uri.parse('http://example.test')),
      isTrue,
    );
    expect(SafePageAddress.canNavigate(Uri.parse('intent://login')), isFalse);
    expect(
      SafePageAddress.canNavigate(Uri.parse('mailto:user@example.test')),
      isFalse,
    );
  });

  test('real game navigation accepts only trusted HTTPS origins', () {
    expect(
      SafePageAddress.canNavigateInGameWebView(
        Uri.parse('https://accounts.dmm.com/login'),
      ),
      isTrue,
    );
    expect(
      SafePageAddress.canNavigateInGameWebView(
        Uri.parse('https://203.104.209.7.kancolle-server.com/kcs2/'),
      ),
      isTrue,
    );
    expect(
      SafePageAddress.canNavigateInGameWebView(
        Uri.parse('http://www.dmm.com/login'),
      ),
      isFalse,
    );
    expect(
      SafePageAddress.canNavigateInGameWebView(
        Uri.parse('https://dmm.com.attacker.example/login'),
      ),
      isFalse,
    );
    expect(
      SafePageAddress.canNavigateInGameWebView(
        Uri.parse('https://example.com/redirect'),
      ),
      isFalse,
    );
  });
}
