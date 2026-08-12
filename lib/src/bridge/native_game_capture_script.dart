import 'dart:convert';

import '../capture/game_capture_path_catalog.dart';

final String nativeGameCaptureScript = _buildNativeGameCaptureScript();

String _buildNativeGameCaptureScript() {
  final paths = GameCapturePathCatalog.all.toList(growable: false)..sort();
  final encodedPaths = jsonEncode(paths);
  return '''
(() => {
  'use strict';

  if (window.__yahagiMobileNativeCaptureInstalled === true) return;
  window.__yahagiMobileNativeCaptureInstalled = true;

  const targetPrefix = '/kcsapi/';
  const targetPaths = new Set($encodedPaths);
  const sensitiveKeys = new Set(['api_token', 'api_starttime']);
  const questListPath = '/kcsapi/api_get_member/questlist';
  const questSnapshotCooldownMs = 15000;
  const xhrUrl = Symbol('yahagiCaptureUrl');
  const xhrMethod = Symbol('yahagiCaptureMethod');
  const binaryCaptureEnabled = __YAHAGI_BINARY_CAPTURE_ENABLED__;
  const utf8Encoder = binaryCaptureEnabled && typeof TextEncoder === 'function'
    ? new TextEncoder()
    : null;
  const nativeFetch = typeof window.fetch === 'function'
    ? window.fetch.bind(window)
    : null;
  let questSnapshotInFlight = false;
  let lastQuestSnapshotStartedAt = 0;

  const targetPath = (value) => {
    try {
      const path = new URL(String(value), window.location.href).pathname;
      return path.startsWith(targetPrefix) && targetPaths.has(path)
        ? path
        : null;
    } catch (_) {
      return null;
    }
  };

  const sanitizeValue = (value) => {
    if (Array.isArray(value)) return value.map(sanitizeValue);
    if (value !== null && typeof value === 'object') {
      const output = {};
      for (const [key, child] of Object.entries(value)) {
        if (!sensitiveKeys.has(key)) output[key] = sanitizeValue(child);
      }
      return output;
    }
    return value;
  };

  const parseRequestParams = (body) => {
    const output = {};
    try {
      if (typeof body === 'string') {
        for (const [key, value] of new URLSearchParams(body).entries()) {
          if (!sensitiveKeys.has(key)) output[key] = value;
        }
      } else if (
        typeof URLSearchParams !== 'undefined' &&
        body instanceof URLSearchParams
      ) {
        for (const [key, value] of body.entries()) {
          if (!sensitiveKeys.has(key)) output[key] = value;
        }
      } else if (typeof FormData !== 'undefined' && body instanceof FormData) {
        for (const [key, value] of body.entries()) {
          if (!sensitiveKeys.has(key) && typeof value === 'string') {
            output[key] = value;
          }
        }
      }
    } catch (_) {}
    delete output.api_token;
    delete output.api_starttime;
    return sanitizeValue(output);
  };

  const publishStringFallback = (event) => {
    YahagiNativeCapture.postMessage(JSON.stringify(event));
  };

  const publish = ({
    method,
    url,
    requestBody,
    responseBody,
    statusCode,
    transport,
  }) => {
    try {
      const path = targetPath(url);
      if (path === null || typeof responseBody !== 'string') return;
      if (
        typeof YahagiNativeCapture !== 'object' ||
        typeof YahagiNativeCapture.postMessage !== 'function'
      ) return;

      const event = {
        version: 1,
        kind: 'kcsapi_response',
        method: String(method || 'GET').toUpperCase(),
        path,
        requestParams: parseRequestParams(requestBody),
        responseBody,
        statusCode: Number.isInteger(statusCode) ? statusCode : 0,
        transport,
      };

      if (utf8Encoder !== null) {
        try {
          const { responseBody: body, ...metadata } = event;
          const metadataBytes = utf8Encoder.encode(JSON.stringify(metadata));
          const bodyBytes = utf8Encoder.encode(body);
          const payload = new ArrayBuffer(
            4 + metadataBytes.byteLength + bodyBytes.byteLength,
          );
          new DataView(payload).setUint32(0, metadataBytes.byteLength, false);
          new Uint8Array(payload, 4, metadataBytes.byteLength)
            .set(metadataBytes);
          new Uint8Array(payload, 4 + metadataBytes.byteLength)
            .set(bodyBytes);
          YahagiNativeCapture.postMessage(payload);
          return;
        } catch (_) {
          // Fall through to the string protocol for this individual event.
        }
      }
      publishStringFallback(event);
    } catch (_) {}
  };

  const requestBodyParams = (body) => {
    try {
      if (typeof body === 'string') return new URLSearchParams(body);
      if (
        typeof URLSearchParams !== 'undefined' &&
        body instanceof URLSearchParams
      ) {
        return new URLSearchParams(body.toString());
      }
      if (typeof FormData !== 'undefined' && body instanceof FormData) {
        const params = new URLSearchParams();
        for (const [key, value] of body.entries()) {
          if (typeof value === 'string') params.append(key, value);
        }
        return params;
      }
    } catch (_) {}
    return null;
  };

  const decodeKcsapiEnvelope = (body) => {
    if (typeof body !== 'string') return null;
    const json = body.startsWith('svdata=') ? body.slice(7) : body;
    try {
      const envelope = JSON.parse(json);
      return envelope && typeof envelope === 'object' ? envelope : null;
    } catch (_) {
      return null;
    }
  };

  const fetchQuestPage = async (url, baseParams, pageNo) => {
    if (nativeFetch === null) throw new Error('fetch unavailable');
    const params = new URLSearchParams(baseParams.toString());
    params.set('api_tab_id', '0');
    params.set('api_page_no', String(pageNo));
    const response = await nativeFetch(url, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      },
      body: params.toString(),
    });
    if (!response.ok) throw new Error('quest snapshot request failed');
    const responseBody = await response.text();
    const envelope = decodeKcsapiEnvelope(responseBody);
    if (
      !envelope ||
      Number(envelope.api_result) !== 1 ||
      !envelope.api_data ||
      typeof envelope.api_data !== 'object'
    ) {
      throw new Error('invalid quest snapshot response');
    }
    return { response, responseBody, envelope };
  };

  const syncCompleteQuestSnapshot = async (url, requestBody) => {
    const path = targetPath(url);
    const now = Date.now();
    if (
      path !== questListPath ||
      nativeFetch === null ||
      questSnapshotInFlight ||
      now - lastQuestSnapshotStartedAt < questSnapshotCooldownMs
    ) {
      return;
    }
    const baseParams = requestBodyParams(requestBody);
    if (baseParams === null || !baseParams.has('api_token')) return;

    questSnapshotInFlight = true;
    lastQuestSnapshotStartedAt = now;
    try {
      const first = await fetchQuestPage(url, baseParams, 1);
      const firstData = first.envelope.api_data;
      const questCount = Math.max(0, Number(firstData.api_count) || 0);
      const declaredPageCount = Number(firstData.api_page_count) || 0;
      const pageCount = Math.max(
        1,
        Math.min(100, declaredPageCount || Math.ceil(questCount / 5)),
      );
      const pages = [first];
      for (let pageNo = 2; pageNo <= pageCount; pageNo += 1) {
        pages.push(await fetchQuestPage(url, baseParams, pageNo));
      }

      const activeById = new Map();
      for (const page of pages) {
        const list = Array.isArray(page.envelope.api_data.api_list)
          ? page.envelope.api_data.api_list
          : [];
        for (const quest of list) {
          if (
            quest &&
            typeof quest === 'object' &&
            Number(quest.api_no) > 0 &&
            Number(quest.api_state) >= 2
          ) {
            activeById.set(Number(quest.api_no), quest);
          }
        }
      }

      const activeCount = Math.max(0, Number(firstData.api_exec_count) || 0);
      if (activeById.size !== activeCount) return;
      const snapshotParams = new URLSearchParams(baseParams.toString());
      snapshotParams.set('api_tab_id', '0');
      snapshotParams.set('api_page_no', '1');
      snapshotParams.set('yahagi_full_quest_snapshot', '1');
      publish({
        method: 'POST',
        url,
        requestBody: snapshotParams,
        responseBody: JSON.stringify({
          api_result: 1,
          api_result_msg: 'OK',
          api_data: {
            ...firstData,
            api_count: activeById.size,
            api_list: Array.from(activeById.values()),
          },
        }),
        statusCode: first.response.status,
        transport: 'fetch',
      });
    } catch (_) {
      // Keep the previous cache when any page cannot be read or validated.
    } finally {
      questSnapshotInFlight = false;
    }
  };

  if (typeof window.fetch === 'function') {
    const originalFetch = window.fetch;
    window.fetch = function(...args) {
      const input = args[0];
      const init = args[1];
      const url =
        typeof Request !== 'undefined' && input instanceof Request
          ? input.url
          : input;
      const method =
        init && init.method
          ? init.method
          : typeof Request !== 'undefined' && input instanceof Request
            ? input.method
            : 'GET';
      const requestBody = init ? init.body : null;
      const path = targetPath(url);
      let requestBodyPromise = Promise.resolve(null);
      if (path !== null) {
        requestBodyPromise = requestBody !== null && requestBody !== undefined
          ? Promise.resolve(requestBody)
          : typeof Request !== 'undefined' && input instanceof Request
            ? input.clone().text().catch(() => null)
            : Promise.resolve(null);
      }

      return originalFetch.apply(this, args).then((response) => {
        if (path !== null) {
          Promise.all([response.clone().text(), requestBodyPromise])
            .then(([responseBody, capturedRequestBody]) => {
              publish({
                method,
                url,
                requestBody: capturedRequestBody,
                responseBody,
                statusCode: response.status,
                transport: 'fetch',
              });
              void syncCompleteQuestSnapshot(url, capturedRequestBody);
            })
            .catch(() => {});
        }
        return response;
      });
    };
  }

  if (typeof XMLHttpRequest === 'function') {
    const originalOpen = XMLHttpRequest.prototype.open;
    const originalSend = XMLHttpRequest.prototype.send;

    XMLHttpRequest.prototype.open = function(method, url, ...rest) {
      this[xhrMethod] = method;
      this[xhrUrl] = url;
      return originalOpen.call(this, method, url, ...rest);
    };

    XMLHttpRequest.prototype.send = function(body) {
      const path = targetPath(this[xhrUrl]);
      
      if (path !== null) {
        this.addEventListener('loadend', () => {
          try {
            if (
              (this.responseType === '' || this.responseType === 'text') &&
              typeof this.responseText === 'string'
            ) {
              publish({
                method: this[xhrMethod],
                url: this.responseURL || this[xhrUrl],
                requestBody: body,
                responseBody: this.responseText,
                statusCode: this.status,
                transport: 'xhr',
              });
              void syncCompleteQuestSnapshot(
                this.responseURL || this[xhrUrl],
                body,
              );
            }
          } catch (_) {}
        }, { once: true });
      }
      return originalSend.call(this, body);
    };
  }
})();
''';
}
