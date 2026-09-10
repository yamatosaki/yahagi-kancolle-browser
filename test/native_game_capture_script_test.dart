import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yahagi_kancolle_browser/src/bridge/native_game_capture_script.dart';
import 'package:yahagi_kancolle_browser/src/capture/game_capture_path_catalog.dart';

void main() {
  group('nativeGameCaptureScript', () {
    test('uses the native frame bridge and versioned kcsapi protocol', () {
      expect(
        nativeGameCaptureScript,
        contains('YahagiNativeCapture.postMessage'),
      );
      expect(nativeGameCaptureScript, contains('/kcsapi/'));
      expect(nativeGameCaptureScript, contains("version: 1"));
      expect(nativeGameCaptureScript, contains("kind: 'kcsapi_response'"));
    });

    test('prefers an ArrayBuffer payload with permanent string fallback', () {
      expect(
        nativeGameCaptureScript,
        contains('__YAHAGI_BINARY_CAPTURE_ENABLED__'),
      );
      expect(nativeGameCaptureScript, contains('new TextEncoder()'));
      expect(nativeGameCaptureScript, contains('new ArrayBuffer('));
      expect(nativeGameCaptureScript, contains('publishStringFallback'));
      expect(
        nativeGameCaptureScript,
        contains('YahagiNativeCapture.postMessage(JSON.stringify'),
      );
    });

    test('embeds the complete interested-path allowlist', () {
      for (final path in GameCapturePathCatalog.all) {
        expect(nativeGameCaptureScript, contains('"$path"'));
      }
      expect(nativeGameCaptureScript, contains('targetPaths.has(path)'));
    });

    test('always embeds KCWiki-only paths without a runtime variant', () {
      expect(nativeGameCaptureScript, buildNativeGameCaptureScript());
      for (final path in GameCapturePathCatalog.kcwikiOnly) {
        expect(nativeGameCaptureScript, contains('"$path"'));
      }
    });

    test('observes xhr and cloned fetch responses without cookie access', () {
      expect(nativeGameCaptureScript, contains('.clone()'));
      expect(nativeGameCaptureScript, contains("'loadend'"));
      expect(nativeGameCaptureScript, contains('originalFetch'));
      expect(nativeGameCaptureScript, contains('originalSend'));
      expect(nativeGameCaptureScript, isNot(contains('document.cookie')));
      expect(nativeGameCaptureScript, isNot(contains('localStorage')));
    });

    test(
      'checks the allowlist before copying fetch or xhr response bodies',
      () {
        final fetchGuard = nativeGameCaptureScript.indexOf(
          'if (path !== null)',
        );
        final fetchCopy = nativeGameCaptureScript.indexOf(
          'response.clone().text()',
        );
        final xhrGuard = nativeGameCaptureScript.indexOf(
          'if (path !== null)',
          fetchGuard + 1,
        );
        final xhrCopy = nativeGameCaptureScript.indexOf('this.responseText');

        expect(fetchGuard, greaterThanOrEqualTo(0));
        expect(fetchCopy, greaterThan(fetchGuard));
        expect(xhrGuard, greaterThan(fetchGuard));
        expect(xhrCopy, greaterThan(xhrGuard));
      },
    );

    test('checks the allowlist before cloning a fetch Request body', () {
      final fetchStart = nativeGameCaptureScript.indexOf(
        'window.fetch = function(...args)',
      );
      final fetchEnd = nativeGameCaptureScript.indexOf(
        "if (typeof XMLHttpRequest === 'function')",
        fetchStart,
      );
      final fetchBlock = nativeGameCaptureScript.substring(
        fetchStart,
        fetchEnd,
      );
      final pathCheck = fetchBlock.indexOf('const path = targetPath(url)');
      final requestGuard = fetchBlock.indexOf('if (path !== null)');
      final requestClone = fetchBlock.indexOf('input.clone().text()');

      expect(pathCheck, greaterThanOrEqualTo(0));
      expect(requestGuard, greaterThan(pathCheck));
      expect(requestClone, greaterThan(requestGuard));
    });

    test('is idempotent and removes sensitive request parameters', () {
      expect(
        nativeGameCaptureScript,
        contains('__yahagiMobileNativeCaptureInstalled'),
      );
      expect(nativeGameCaptureScript, contains('api_token'));
      expect(nativeGameCaptureScript, contains('api_starttime'));
      expect(nativeGameCaptureScript, contains('delete'));
    });

    test('preserves formation parameters from modern POST body types', () {
      expect(
        nativeGameCaptureScript,
        contains('body instanceof URLSearchParams'),
      );
      expect(nativeGameCaptureScript, contains('input.clone().text()'));
    });

    test('builds a complete quest snapshot after a quest page opens', () {
      expect(nativeGameCaptureScript, contains('syncCompleteQuestSnapshot'));
      expect(nativeGameCaptureScript, contains('api_get_member/questlist'));
      expect(nativeGameCaptureScript, contains('api_page_no'));
      expect(nativeGameCaptureScript, contains('api_exec_count'));
      expect(nativeGameCaptureScript, contains('yahagi_full_quest_snapshot'));
    });

    test(
      'full snapshots retain unaccepted tasks across pages and reject incomplete lists',
      () {
        const harness = r'''
const messages = [];
global.window = global;
window.location = { href: 'https://example.test/kcs2/' };
global.YahagiNativeCapture = { postMessage: (message) => messages.push(JSON.parse(message)) };
const scenario = process.argv[2];
let requests = 0;
const response = (data) => ({
  ok: true, status: 200,
  text: async () => JSON.stringify({ api_result: 1, api_data: data }),
  clone() { return response(data); },
});
window.fetch = async (url, init) => {
  requests++;
  const page = new URLSearchParams(init.body).get('api_page_no');
  if (requests > 1 && new URLSearchParams(init.body).get('api_tab_id') !== '0') throw new Error('not all tasks');
  if (scenario === 'modern') return response({
    api_count: 12, api_exec_count: 1,
    api_list: Array.from({length: 12}, (_, i) => ({api_no: 101 + i, api_state: i === 0 ? 2 : 1})),
  });
  if (scenario === 'failure' && page === '2') throw new Error('page failed');
  return response({
    api_count: 3, api_page_count: 2, api_exec_count: 2,
    api_list: page === '2'
      ? (scenario === 'incomplete' ? [] : [{ api_no: 103, api_state: 3 }])
      : [{ api_no: 101, api_state: 1 }, { api_no: 102, api_state: 2 }, -1],
  });
};
eval(process.argv[1].replace('__YAHAGI_BINARY_CAPTURE_ENABLED__', 'false'));
(async () => {
  await window.fetch('/kcsapi/api_get_member/questlist', {
    method: 'POST', body: 'api_token=test&api_tab_id=9&api_page_no=1',
  });
  for (let i = 0; i < 10; i++) await new Promise(setImmediate);
  const snapshots = messages.filter((event) => event.requestParams.yahagi_full_quest_snapshot === '1');
  process.stdout.write(JSON.stringify({
    requests,
    data: snapshots.map((event) => JSON.parse(event.responseBody).api_data),
  }));
})().catch((error) => { process.stderr.write(String(error)); process.exitCode = 1; });
''';
        for (final scenario in [
          'complete',
          'incomplete',
          'failure',
          'modern',
        ]) {
          final result = Process.runSync('node', [
            '-e',
            harness,
            nativeGameCaptureScript,
            scenario,
          ]);
          expect(result.exitCode, 0, reason: result.stderr.toString());
          final output =
              jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
          expect(
            output['requests'],
            scenario == 'modern' ? 2 : 3,
            reason: scenario,
          );
          final snapshots = output['data'] as List;
          if (scenario == 'modern') {
            expect(snapshots, hasLength(1));
            expect(snapshots.single['api_list'], hasLength(12));
          } else if (scenario == 'complete') {
            expect(snapshots, hasLength(1));
            expect(snapshots.single['api_count'], 3);
            expect(
              (snapshots.single['api_list'] as List).map((q) => q['api_state']),
              [1, 2, 3],
            );
          } else {
            expect(snapshots, isEmpty, reason: scenario);
          }
        }
      },
    );

    test('quest claim and stop both invalidate older snapshots', () {
      expect(nativeGameCaptureScript, contains('questMutationPaths.has(path)'));
      expect(
        nativeGameCaptureScript,
        contains(
          "'/kcsapi/api_req_quest/clearitemget',\n    '/kcsapi/api_req_quest/stop'",
        ),
      );
    });

    test('publishes only current quest snapshots across mutation races', () {
      const harness = r'''
const captureScript = process.argv[1].replace(
  '__YAHAGI_BINARY_CAPTURE_ENABLED__',
  'false',
);
const mutationPath = process.argv[2];
const mutationResult = Number(process.argv[3]);
const mutationTransport = process.argv[4];
const messages = [];
let questRequestCount = 0;
let resolveSnapshot;

const envelope = (data, apiResult = 1) => `svdata=${JSON.stringify({
  api_result: apiResult,
  api_result_msg: 'OK',
  api_data: data,
})}`;
const response = (body) => ({
  ok: true,
  status: 200,
  text: async () => body,
  clone() { return response(body); },
});
const staleQuestData = {
  api_count: 1,
  api_page_count: 1,
  api_exec_count: 1,
  api_list: [{
    api_no: 201,
    api_category: 2,
    api_type: 1,
    api_state: 3,
    api_progress_flag: 2,
    api_title: 'Bd1',
    api_detail: '',
  }],
};

global.window = global;
window.location = { href: 'https://example.test/kcs2/' };
global.YahagiNativeCapture = {
  postMessage(message) { messages.push(JSON.parse(message)); },
};
class FakeXMLHttpRequest {
  constructor() {
    this.responseType = '';
    this.responseText = envelope({}, mutationResult);
    this.responseURL = '';
    this.status = 200;
    this.listeners = new Map();
  }
  open(method, url) {
    this.method = method;
    this.responseURL = new URL(url, window.location.href).toString();
  }
  addEventListener(type, listener) {
    const listeners = this.listeners.get(type) || [];
    listeners.push(listener);
    this.listeners.set(type, listeners);
  }
  send() {
    setImmediate(() => {
      for (const listener of this.listeners.get('loadend') || []) {
        listener.call(this);
      }
    });
  }
}
global.XMLHttpRequest = FakeXMLHttpRequest;
window.fetch = (url) => {
  const path = new URL(url, window.location.href).pathname;
  if (path === '/kcsapi/api_get_member/questlist') {
    questRequestCount += 1;
    if (questRequestCount === 1) {
      return Promise.resolve(response(envelope(staleQuestData)));
    }
    return new Promise((resolve) => {
      resolveSnapshot = () => resolve(response(envelope(staleQuestData)));
    });
  }
  if (
    path === '/kcsapi/api_req_quest/clearitemget' ||
    path === '/kcsapi/api_req_quest/stop' ||
    path === '/kcsapi/api_req_quest/start'
  ) {
    return Promise.resolve(response(envelope({}, mutationResult)));
  }
  throw new Error(`Unexpected request: ${path}`);
};

eval(captureScript);

(async () => {
  await window.fetch('/kcsapi/api_get_member/questlist', {
    method: 'POST',
    body: 'api_token=token&api_page_no=1',
  });
  await new Promise(setImmediate);
  if (typeof resolveSnapshot !== 'function') {
    throw new Error('The background quest snapshot did not start');
  }

  if (mutationPath !== 'none') {
    const body = 'api_token=token&api_quest_id=201';
    if (mutationTransport === 'xhr') {
      await new Promise((resolve) => {
        const xhr = new XMLHttpRequest();
        xhr.addEventListener('loadend', resolve);
        xhr.open('POST', mutationPath);
        xhr.send(body);
      });
    } else {
      await window.fetch(mutationPath, { method: 'POST', body });
      await new Promise(setImmediate);
    }
  }
  resolveSnapshot();
  await new Promise(setImmediate);
  await new Promise(setImmediate);

  const fullSnapshots = messages.filter((event) =>
    event.requestParams.yahagi_full_quest_snapshot === '1'
  );
  const mutations = messages.filter((event) =>
    event.path === mutationPath
  );
  process.stdout.write(JSON.stringify({
    fullSnapshotCount: fullSnapshots.length,
    mutationCount: mutations.length,
  }));
})().catch((error) => {
  process.stderr.write(String(error && error.stack || error));
  process.exitCode = 1;
});
''';
      const cases =
          <
            ({
              String path,
              int apiResult,
              String transport,
              int expectedSnapshots,
              int expectedMutations,
            })
          >[
            (
              path: 'none',
              apiResult: 1,
              transport: 'fetch',
              expectedSnapshots: 1,
              expectedMutations: 0,
            ),
            (
              path: '/kcsapi/api_req_quest/start',
              apiResult: 1,
              transport: 'fetch',
              expectedSnapshots: 0,
              expectedMutations: 1,
            ),
            (
              path: '/kcsapi/api_req_quest/start',
              apiResult: 1,
              transport: 'xhr',
              expectedSnapshots: 0,
              expectedMutations: 1,
            ),
            (
              path: '/kcsapi/api_req_quest/clearitemget',
              apiResult: 0,
              transport: 'fetch',
              expectedSnapshots: 1,
              expectedMutations: 1,
            ),
            (
              path: '/kcsapi/api_req_quest/clearitemget',
              apiResult: 1,
              transport: 'fetch',
              expectedSnapshots: 0,
              expectedMutations: 1,
            ),
            (
              path: '/kcsapi/api_req_quest/stop',
              apiResult: 1,
              transport: 'fetch',
              expectedSnapshots: 0,
              expectedMutations: 1,
            ),
            (
              path: '/kcsapi/api_req_quest/clearitemget',
              apiResult: 1,
              transport: 'xhr',
              expectedSnapshots: 0,
              expectedMutations: 1,
            ),
            (
              path: '/kcsapi/api_req_quest/stop',
              apiResult: 1,
              transport: 'xhr',
              expectedSnapshots: 0,
              expectedMutations: 1,
            ),
          ];
      for (final scenario in cases) {
        final result = Process.runSync('node', <String>[
          '-e',
          harness,
          nativeGameCaptureScript,
          scenario.path,
          '${scenario.apiResult}',
          scenario.transport,
        ]);

        expect(result.exitCode, 0, reason: result.stderr.toString());
        final output =
            jsonDecode(result.stdout.toString()) as Map<String, Object?>;
        final reason =
            '${scenario.transport} ${scenario.path} '
            'api_result=${scenario.apiResult}';
        expect(
          output['mutationCount'],
          scenario.expectedMutations,
          reason: reason,
        );
        expect(
          output['fullSnapshotCount'],
          scenario.expectedSnapshots,
          reason: reason,
        );
      }
    });
  });
}
