package app.yahagi.kancollebrowser.browser

/** Receives only physical wheel input forwarded by the Android host. */
internal object GameMouseWheelScript {
    const val objectName = "YahagiMouseWheel"
    val origins = setOf("https://*.kancolle-server.com")
    val source = """
        (() => {
          'use strict';
          const bridge = window.YahagiMouseWheel;
          if (!bridge || window.__yahagiMouseWheelInstalled ||
              !location.pathname.startsWith('/kcs2/')) return;
          window.__yahagiMouseWheelInstalled = true;
          const token = String(Date.now()) + ':' + Math.random();
          let enabled = false;
          let revision = -1;
          let suspended = false;
          let observer = null;
          let active = false;
          const canvas = () => {
            if (!location.pathname.startsWith('/kcs2/')) return null;
            const target = document.querySelector('canvas');
            if (!target || !target.isConnected) return null;
            const rect = target.getBoundingClientRect();
            return rect.width > 0 && rect.height > 0 ? target : null;
          };
          const report = () => {
            const available = enabled && !suspended && !!canvas();
            if (active === available) return;
            active = available;
            bridge.postMessage(JSON.stringify({kind: 'availability', token, available, revision}));
          };
          const configure = (value) => {
            const next = value && !suspended;
            if (enabled === next) return;
            enabled = next;
            if (enabled) {
              if (!observer) observer = new MutationObserver(report);
              observer.observe(document, {
                childList: true, subtree: true, attributes: true,
                attributeFilter: ['style', 'class', 'width', 'height'],
              });
              window.addEventListener('resize', report);
              active = null; // Acknowledge enable even when the canvas has not appeared yet.
            } else {
              if (observer) observer.disconnect();
              window.removeEventListener('resize', report);
            }
            report();
          };
          bridge.onmessage = (event) => {
            let data;
            try { data = JSON.parse(event.data); } catch (_) { return; }
            if (!data || data.token !== token) return;
            if (data.kind === 'configure') {
              if (typeof data.enabled !== 'boolean' || !Number.isSafeInteger(data.revision) ||
                  data.revision < revision) return;
              revision = data.revision;
              configure(data.enabled);
              return;
            }
            if (!enabled || suspended || data.kind !== 'wheel' ||
                ![data.x, data.y, data.deltaX, data.deltaY].every(Number.isFinite) ||
                data.x < 0 || data.x >= 1 || data.y < 0 || data.y >= 1 ||
                data.deltaY === 0 || document.hidden) return;
            const target = canvas();
            if (!target) return;
            const rect = target.getBoundingClientRect();
            target.dispatchEvent(new WheelEvent('wheel', {
              bubbles: true, cancelable: true, view: window,
              clientX: rect.left + rect.width * data.x,
              clientY: rect.top + rect.height * data.y,
              deltaX: data.deltaX, deltaY: data.deltaY, deltaMode: 0,
            }));
          };
          const ready = () => bridge.postMessage(JSON.stringify({kind: 'ready', token}));
          window.addEventListener('pageshow', () => {
            if (!suspended) return;
            suspended = false;
            ready();
          });
          window.addEventListener('pagehide', () => {
            suspended = true;
            configure(false);
            bridge.postMessage(JSON.stringify({kind: 'gone', token}));
          });
          ready();
        })();
    """.trimIndent()
}
