const String nativeGameCaptureScript = r'''
(() => {
  'use strict';

  if (window.__yahagiMobileNativeCaptureInstalled === true) return;
  window.__yahagiMobileNativeCaptureInstalled = true;

  const targetPrefix = '/kcsapi/';
  const sensitiveKeys = new Set(['api_token', 'api_starttime']);
  const xhrUrl = Symbol('yahagiCaptureUrl');
  const xhrMethod = Symbol('yahagiCaptureMethod');

  const targetPath = (value) => {
    try {
      const path = new URL(String(value), window.location.href).pathname;
      return path.startsWith(targetPrefix) ? path : null;
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

      YahagiNativeCapture.postMessage(JSON.stringify({
        version: 1,
        kind: 'kcsapi_response',
        method: String(method || 'GET').toUpperCase(),
        path,
        requestParams: parseRequestParams(requestBody),
        responseBody,
        statusCode: Number.isInteger(statusCode) ? statusCode : 0,
        transport,
      }));
    } catch (_) {}
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

      return originalFetch.apply(this, args).then((response) => {
        if (path !== null) {
          response
            .clone()
            .text()
            .then((responseBody) => publish({
              method,
              url,
              requestBody,
              responseBody,
              statusCode: response.status,
              transport: 'fetch',
            }))
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
            }
          } catch (_) {}
        }, { once: true });
      }
      return originalSend.call(this, body);
    };
  }
})();
''';
