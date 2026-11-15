package app.yahagi.kancollebrowser.mods

/** Runs before game code. Only the game's view of successful startup data is modified. */
internal object GameModCoordinateScript {
    val allowedOriginRules = setOf("https://*.kancolle-server.com")

    val source: String =
        """
        (() => {
          'use strict';
          if (window.__yahagiModCoordinatesInstalled) return;
          if (location.protocol !== 'https:' ||
              !/^w[0-9]+[a-z]\.kancolle-server\.com$/.test(location.hostname) ||
              (location.port && location.port !== '443')) return;
          const NativeXhr = window.XMLHttpRequest;
          if (typeof NativeXhr !== 'function') return;
          const proto = NativeXhr.prototype;
          const nativeOpen = proto.open;
          const nativeSend = proto.send;
          const textDescriptor = Object.getOwnPropertyDescriptor(proto, 'responseText');
          const responseDescriptor = Object.getOwnPropertyDescriptor(proto, 'response');
          let config;
          try {
            const request = new NativeXhr();
            nativeOpen.call(request, 'GET', '/__yahagi_mods__/coordinates.json', false);
            nativeSend.call(request);
            if (request.status !== 200) return;
            config = JSON.parse(textDescriptor.get.call(request));
          } catch (_) { return; }
          if (!config || !config.ships || (config.kanxy !== true && !Object.keys(config.ships).length) ||
              !Number.isSafeInteger(config.sessionId) || typeof config.token !== 'string') return;
          window.__yahagiModCoordinatesInstalled = true;
          const xhrState = new WeakMap();
          const rawFetch = new WeakMap();
          const knownIds = [...new Set(Object.values(config.ships).flatMap(ship => ship.resourceIds))];
          const nativeParse = JSON.parse;
          const kanxy = config.kanxy === true;
          if (kanxy) {
            // PIXI can reuse Chromium's cached image before native interception.
            // Keep the resource path intact so Yahagi's local replacements still win.
            const imageProto = window.HTMLImageElement?.prototype;
            const src = imageProto && Object.getOwnPropertyDescriptor(imageProto, 'src');
            const documentVersion = 'yahagi-' + Date.now().toString(36) + Math.random().toString(36).slice(2);
            const origin = new URL(location.href).origin;
            const shipArtPath = /^\/kcs2\/resources\/ship\/[a-z0-9_]+\/[A-Za-z0-9_-]+\.png$/;
            if (src?.configurable && src.set) {
              Object.defineProperty(imageProto, 'src', {...src, set(value) {
                let target = value;
                if (typeof value === 'string') {
                  try {
                    const url = new URL(value, window.document?.baseURI || location.href);
                    if (url.origin === origin && !url.username && !url.password && !url.hash &&
                        shipArtPath.test(url.pathname) && (!url.search || /^\?version=[A-Za-z0-9._~-]+$/.test(url.search))) {
                      url.search = (url.search ? url.search + '-' : '?version=') + documentVersion;
                      target = url.href;
                    }
                  } catch (_) {}
                }
                src.set.call(this, target);
              }});
            }
          }
          const localArtShips = new Set(config.localArtShips || []);
          const externalCoordinates = new Map();
          const retryAfter = new Map();
          const startupBodies = new Set();
          const coordinateField = /^api_(?:(?:boko|kaisyu|kaizo|map|ensyuf|ensyue|battle)_[nd]|wed[a-d])$/;
          const readKanxy = (filename) => {
            if (externalCoordinates.has(filename)) return externalCoordinates.get(filename);
            if ((retryAfter.get(filename) || 0) > Date.now()) return null;
            let graph = null;
            try {
              const request = new NativeXhr();
              nativeOpen.call(request, 'GET', '/__yahagi_mods__/kanxy-coordinates/' + filename + '.json', false);
              nativeSend.call(request);
              if (request.status === 200) graph = nativeParse(textDescriptor.get.call(request));
            } catch (_) {}
            // A temporary connection failure or a pack switch can change the next result.
            if (graph) {
              externalCoordinates.set(filename, graph);
              retryAfter.delete(filename);
            } else retryAfter.set(filename, Date.now() + 2_000);
            return graph;
          };
          const attachKanxy = (data) => {
            const ships = data?.api_data?.api_mst_shipgraph;
            if (!Array.isArray(ships)) return data;
            for (const [index, ship] of ships.entries()) {
              const filename = ship?.api_filename;
              if (!/^[a-z0-9]{12}$/.test(filename || '') || localArtShips.has(ship.api_id)) continue;
              const local = config.ships[ship.api_id]?.graph;
              ships[index] = new Proxy(ship, {
                get(row, field, receiver) {
                  if (field === 'toJSON' && !Object.hasOwn(row, field)) return () => row;
                  if (typeof field === 'string' && coordinateField.test(field) && (!local || !Object.hasOwn(local, field))) {
                    const pair = readKanxy(filename)?.[field];
                    if (Array.isArray(pair) && pair.length === 2 && pair.every(Number.isSafeInteger)) return pair;
                  }
                  return Reflect.get(row, field, receiver);
                },
              });
            }
            return data;
          };
          if (kanxy) {
            // The game parses a marked text response; capture still sees the original body.
            JSON.parse = function (...args) {
              const data = Reflect.apply(nativeParse, this, args);
              return startupBodies.has(args[0]) ? attachKanxy(data) : data;
            };
          }
          const report = (resourceIds, failure) => {
            if (!resourceIds.length) return;
            if (resourceIds.length > 256) {
              for (let index = 0; index < resourceIds.length; index += 256) {
                report(resourceIds.slice(index, index + 256), failure);
              }
              return;
            }
            try {
              const request = new NativeXhr();
              nativeOpen.call(request, 'GET', '/__yahagi_mods__/coordinates-report?payload=' +
                encodeURIComponent(JSON.stringify({sessionId: config.sessionId,
                  token: config.token, resourceIds: resourceIds, failure: failure || null})), true);
              nativeSend.call(request);
            } catch (_) {}
          };
          const isStartup = (value) => {
            try {
              const url = new URL(String(value), location.href);
              const current = new URL(location.href);
              return url.origin === current.origin && url.pathname === '/kcsapi/api_start2/getData';
            } catch (_) { return false; }
          };
          const isFalseName = (value) => value === false ||
            (typeof value === 'string' && value.trim().toLowerCase() === 'false');
          const usableName = (value) => typeof value === 'string' && value.trim() && !isFalseName(value)
            ? value : null;
          const repairNames = (rows) => {
            if (!kanxy || !Array.isArray(rows)) return false;
            let repaired = false;
            for (const row of rows) {
              if (!row || !isFalseName(row.api_name)) continue;
              const id = typeof row.api_id === 'string' && /^[1-9][0-9]*$/.test(row.api_id)
                ? Number(row.api_id) : row.api_id;
              if (!Number.isSafeInteger(id) || id <= 0) continue;
              row.api_name = usableName(config.stockShipNames?.[id]) ?? usableName(row.api_yomi) ?? '#' + id;
              repaired = true;
            }
            return repaired;
          };
          const patchObject = (data) => {
            if (!data || data.api_result !== 1 || !data.api_data) throw new Error('startup_shape');
            const namesRepaired = repairNames(data.api_data.api_mst_ship);
            if (!Array.isArray(data.api_data.api_mst_shipgraph)) {
              if (namesRepaired) return {data, applied: [], failed: knownIds};
              throw new Error('startup_shape');
            }
            const ships = new Map(data.api_data.api_mst_shipgraph.map(ship => [String(ship.api_id), ship]));
            const applied = [], failed = [];
            for (const [id, selected] of Object.entries(config.ships)) {
              const ship = ships.get(id);
              if (!ship) { failed.push(...selected.resourceIds); continue; }
              for (const [key, value] of Object.entries(selected.graph)) ship[key] = value.slice();
              applied.push(...selected.resourceIds);
            }
            return {data, applied: [...new Set(applied)], failed: [...new Set(failed)]};
          };
          const patchText = (text) => {
            const prefix = text.startsWith('svdata=') ? 'svdata=' : '';
            const result = patchObject(nativeParse(text.slice(prefix.length)));
            let body = JSON.stringify(result.data);
            if (kanxy) {
              body = ' \n' + body;
              startupBodies.add(body);
              if (startupBodies.size > 4) startupBodies.delete(startupBodies.values().next().value);
            }
            return {...result, text: prefix + body};
          };
          const acknowledge = (result) => {
            report(result.applied);
            report(result.failed, 'coordinate_apply_failed');
          };
          // Capture reads raw values dynamically, irrespective of script installation order.
          window.__yahagiModOriginalResponses = Object.freeze({
            xhrText: xhr => textDescriptor.get.call(xhr),
            xhrJson: xhr => responseDescriptor.get.call(xhr),
            fetch: response => rawFetch.get(response) || response,
          });
          const patchedXhr = (xhr) => {
            const state = xhrState.get(xhr);
            if (!state || !state.target || xhr.readyState !== 4 || xhr.status !== 200 ||
                (xhr.responseURL && !isStartup(xhr.responseURL))) return null;
            if (state.done) return state.result;
            state.done = true;
            try {
              let result;
              if (xhr.responseType === 'json') {
                // Never mutate the native object: capture and other consumers retain the original.
                const original = responseDescriptor.get.call(xhr);
                if (typeof original === 'string') {
                  result = patchText(original);
                  result.data = result.text;
                } else {
                  result = patchObject(nativeParse(JSON.stringify(original)));
                  if (kanxy) attachKanxy(result.data);
                }
              } else if (xhr.responseType === '' || xhr.responseType === 'text') {
                result = patchText(textDescriptor.get.call(xhr));
              } else throw new Error('response_type');
              state.result = result;
              acknowledge(result);
            } catch (_) { report(knownIds, 'coordinate_apply_failed'); }
            return state.result;
          };
          try {
            Object.defineProperty(proto, 'responseText', {...textDescriptor, get() {
              const original = textDescriptor.get.call(this);
              return patchedXhr(this)?.text ?? original;
            }});
            Object.defineProperty(proto, 'response', {...responseDescriptor, get() {
              const original = responseDescriptor.get.call(this);
              const result = patchedXhr(this);
              return result ? (this.responseType === 'json' ? result.data : result.text) : original;
            }});
            proto.open = function(method, url, ...rest) {
              const value = nativeOpen.call(this, method, url, ...rest);
              xhrState.set(this, {target: isStartup(url), done: false, result: null});
              return value;
            };
          } catch (_) { report(knownIds, 'coordinate_apply_failed'); }
          if (typeof window.fetch === 'function') {
            const nativeFetch = window.fetch;
            const decorate = (modified, original) => {
              rawFetch.set(modified, original);
              if (kanxy) Object.defineProperty(modified, 'json', {value: async () => JSON.parse(await modified.text())});
              for (const key of ['url', 'redirected', 'type']) {
                Object.defineProperty(modified, key, {value: original[key], configurable: true});
              }
              const clone = modified.clone.bind(modified);
              Object.defineProperty(modified, 'clone', {value: () => decorate(clone(), original.clone())});
              return modified;
            };
            window.fetch = function(...args) {
              const input = args[0];
              const target = isStartup(typeof Request !== 'undefined' && input instanceof Request ? input.url : input);
              return nativeFetch.apply(this, args).then(async response => {
                if (!target || response.status !== 200 || (response.url && !isStartup(response.url))) return response;
                try {
                  const result = patchText(await response.clone().text());
                  const headers = new Headers(response.headers);
                  headers.delete('content-length'); headers.delete('content-encoding');
                  const modified = decorate(new Response(result.text, {status: response.status,
                    statusText: response.statusText, headers}), response);
                  acknowledge(result);
                  return modified;
                } catch (_) { report(knownIds, 'coordinate_apply_failed'); return response; }
              });
            };
          }
        })();
        """.trimIndent()
}
