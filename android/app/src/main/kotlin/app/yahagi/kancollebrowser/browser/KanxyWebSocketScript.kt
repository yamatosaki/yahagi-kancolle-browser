package app.yahagi.kancollebrowser.browser

/** Observes native loopback sockets and lets Kanxy reconnect after a route change. */
internal object KanxyWebSocketScript {
    const val objectName = "__yahagiKanxySocket"
    val allowedOriginRules = setOf("https://*.kancolle-server.com")

    val source = """
        (() => {
          'use strict';
          const bridge = window.__yahagiKanxySocket;
          const NativeWebSocket = window.WebSocket;
          if (!bridge || window.__yahagiKanxySocketInstalled || typeof NativeWebSocket !== 'function' ||
              location.protocol !== 'https:' || (location.port && location.port !== '443') ||
              !/^w[0-9]+[a-z]\.kancolle-server\.com$/.test(location.hostname)) return;

          const sockets = new Set();
          let active = true;
          let permanentlyRetired = false;
          let lastGeneration = 0;
          const post = status => {
            if (!active) return;
            try {
              bridge.postMessage(status);
            } catch (_) {
              // A detached diagnostics listener must not affect native WebSockets.
            }
          };
          const isLoopback = (value, allowHttpScheme = false) => {
            try {
              const url = new URL(value, location.href);
              return (url.protocol === 'ws:' || url.protocol === 'wss:' ||
                (allowHttpScheme && (url.protocol === 'http:' || url.protocol === 'https:'))) &&
                ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
            } catch (_) {
              return false;
            }
          };

          const observe = socket => {
            sockets.add(socket);
            post('WS_REQUESTED');
            socket.addEventListener('open', () => post('WS_OPEN'));
            socket.addEventListener('error', () => post('WS_TRANSPORT_FAILED'));
            socket.addEventListener('close', () => {
              sockets.delete(socket);
              post('WS_CONNECTION_CLOSED');
            });
            const recordSph = event => {
              if (!active || typeof event.data !== 'string' || event.data.length > 1024 ||
                  !event.data.includes('"SPH"')) return;
              try {
                const message = JSON.parse(event.data);
                if (message?.Command === 'SPH' &&
                    (typeof message.SPH === 'string' || typeof message.SPH === 'number')) {
                  socket.removeEventListener('message', recordSph);
                  post('WS_SPH_RECEIVED');
                }
              } catch (_) {
                // Kanxy owns the protocol. This diagnostic is best effort.
              }
            };
            socket.addEventListener('message', recordSph);
          };

          bridge.onmessage = event => {
            if (permanentlyRetired) return;
            let message;
            try {
              message = JSON.parse(event.data);
            } catch (_) {
              return;
            }
            if (message?.kind === 'retire') {
              permanentlyRetired = true;
              active = false;
              for (const socket of sockets) {
                if (socket.readyState < NativeWebSocket.CLOSING) socket.close();
              }
              sockets.clear();
              return;
            }
            if (!active || message?.kind !== 'reconnect' || !Number.isSafeInteger(message.generation) ||
                message.generation <= lastGeneration) return;
            lastGeneration = message.generation;
            let closed = false;
            for (const socket of [...sockets]) {
              if (socket.readyState !== NativeWebSocket.OPEN) continue;
              socket.close();
              closed = true;
            }
            if (closed) post('WS_ROUTE_CLOSED');
          };

          window.addEventListener('pagehide', () => {
            post('retired');
            active = false;
          });
          window.addEventListener('pageshow', () => {
            if (active || permanentlyRetired) return;
            active = true;
            post('ready');
          });

          window.WebSocket = new Proxy(NativeWebSocket, {
            construct(target, args, newTarget) {
              if (permanentlyRetired && isLoopback(args[0], true)) {
                throw new Error('Kanxy WebSocket document retired');
              }
              let socket;
              try {
                socket = Reflect.construct(target, args, newTarget);
              } catch (error) {
                if (typeof args[0] === 'string' && isLoopback(args[0])) post('WS_TRANSPORT_FAILED');
                throw error;
              }
              if (isLoopback(socket.url)) observe(socket);
              return socket;
            },
          });
          window.__yahagiKanxySocketInstalled = true;
          post('ready');
        })();
    """.trimIndent()
}
