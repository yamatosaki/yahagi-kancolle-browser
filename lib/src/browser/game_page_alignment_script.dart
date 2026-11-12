const String gamePageAlignmentScript = r'''
(() => {
  const runtimeVersion = 8;
  if (
    window.__yahagiMobilePresentationRuntimeVersion === runtimeVersion &&
    typeof window.__yahagiMobileSyncPresentation === 'function' &&
    typeof window.__yahagiMobileReadPresentation === 'function'
  ) {
    return window.__yahagiMobileSyncPresentation(true);
  }
  // Release snapshots held by a previous runtime before taking ownership again.
  window.__yahagiMobileDisposePresentation?.();
  window.__yahagiMobileRestoreGameViewport?.();
  window.__yahagiMobileRestoreOoiFrameScrolling?.();
  const styleId = '__yahagi_mobile_fixed_canvas__';
  const ooiBrowserStyleId = '__yahagi_mobile_ooi_browser__';
  const ooiBrowserFrameWidth = 1280;
  const ooiBrowserFrameHeight = 800;
  const ooiBrowserGameWidth = 1200;
  const ooiBrowserGameHeight = 720;
  const wrappedOoiBrowserFrame = '#ooi-page #ooi-game > div.ooi-frame-wrap > iframe#externalswf';
  const ooiBrowserSurfaceSelector =
    '#ooi-page #ooi-game > iframe#externalswf, ' +
    '#ooi-page #ooi-game > embed#externalswf, ' +
    '#ooi-page #ooi-game > iframe#htmlWrap, ' +
    '#flashWrap > iframe#externalswf, #flashWrap > embed#externalswf, ' +
    '#flashWrap > iframe#htmlWrap, #ooi-game > iframe#htmlWrap, ' +
    wrappedOoiBrowserFrame;
  const ooiFrameScrolling = new Map();
  const gameViewportMetas = new Map();
  let hadOoiGameSurface = false;
  const restoreGameViewport = () => {
    for (const [meta, original] of gameViewportMetas) {
      if (original.created) meta.remove();
      else if (original.content === null) {
        if (meta.getAttribute('content') !== null) meta.removeAttribute('content');
      } else if (meta.getAttribute('content') !== original.content) {
        meta.setAttribute('content', original.content);
      }
    }
    gameViewportMetas.clear();
  };
  window.__yahagiMobileRestoreGameViewport = restoreGameViewport;
  const applyGameViewport = () => {
    const metas = Array.from(document.querySelectorAll('meta[name]')).filter(
      (meta) => meta.getAttribute('name')?.toLowerCase() === 'viewport',
    );
    if (metas.length === 0) {
      const meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      gameViewportMetas.set(meta, {content: null, created: true});
      document.head.appendChild(meta);
      metas.push(meta);
    }
    for (const meta of metas) {
      if (!gameViewportMetas.has(meta)) {
        gameViewportMetas.set(meta, {content: meta.getAttribute('content'), created: false});
      }
      const preserved = (meta.getAttribute('content') || '').split(/[,;]/).filter(
        (part) => !/^\s*(minimum-scale|maximum-scale|user-scalable)\s*=/i.test(part),
      ).map((part) => part.trim()).filter(Boolean);
      const content = [...preserved, 'minimum-scale=0.01', 'maximum-scale=10', 'user-scalable=yes'].join(', ');
      // A same-value viewport write may reset Chromium's current page scale.
      if (meta.getAttribute('content') !== content) meta.setAttribute('content', content);
    }
  };
  const fixedCanvasCss = `
    html, body {
      margin: 0 !important;
      padding: 0 !important;
      min-width: 1200px !important;
      min-height: 720px !important;
      overflow: hidden !important;
      overscroll-behavior: none !important;
      touch-action: none !important;
    }

    #w,
    #main-ntg {
      position: fixed !important;
      inset: 0 !important;
      z-index: 2147483640 !important;
      width: 1200px !important;
      height: 720px !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    #game_frame,
    #game-container {
      display: block !important;
      width: 1200px !important;
      height: 720px !important;
      position: fixed !important;
      top: 0 !important;
      left: 0 !important;
      z-index: 2147483641 !important;
      margin: 0 !important;
      padding: 0 !important;
      border: 0 !important;
      transform: none !important;
      transform-origin: 0 0 !important;
      overscroll-behavior: none !important;
      touch-action: none !important;
    }

    .naviapp,
    #ntg-recommend,
    #spacing_top,
    aside,
    footer,
    ul:has([aria-label="close"]) {
      display: none !important;
    }
  `;

  const ooiBrowserCss = `
    #ooi-header,
    #ooi-footer,
    #spacing_top,
    #ooi-game > :not(iframe#externalswf):not(embed#externalswf):not(iframe#htmlWrap):not(#flashWrap):not(div.ooi-frame-wrap:has(> iframe#externalswf)):not(dialog):not(:has(dialog[open], input[type="password"], input[name="password"], input[autocomplete="current-password"], input[autocomplete="new-password"])),
    #flashWrap > :not(iframe#externalswf):not(embed#externalswf):not(iframe#htmlWrap):not(dialog):not(:has(dialog[open], input[type="password"], input[name="password"], input[autocomplete="current-password"], input[autocomplete="new-password"])) {
      display: none !important;
    }

    #ooi-game > iframe#externalswf,
    #ooi-game > embed#externalswf,
    #ooi-game > iframe#htmlWrap,
    #flashWrap > iframe#externalswf,
    #flashWrap > embed#externalswf,
    #flashWrap > iframe#htmlWrap,
    ${wrappedOoiBrowserFrame} {
      position: fixed !important;
      left: 0 !important;
      top: 0 !important;
      z-index: 2147483641 !important;
      width: ${ooiBrowserFrameWidth}px !important;
      height: ${ooiBrowserFrameHeight}px !important;
      max-width: none !important;
      max-height: none !important;
      transform: none !important;
      margin: 0 !important;
      padding: 0 !important;
      border: 0 !important;
    }
  `;

  const restoreOoiFrameScrolling = () => {
    for (const [frame, original] of ooiFrameScrolling) {
      if (frame.getAttribute('scrolling') === original) continue;
      if (original === null) frame.removeAttribute('scrolling');
      else frame.setAttribute('scrolling', original);
    }
    ooiFrameScrolling.clear();
  };
  window.__yahagiMobileRestoreOoiFrameScrolling = restoreOoiFrameScrolling;

  const cleanupOoiBrowserPresentation = () => {
    document.getElementById(ooiBrowserStyleId)?.remove();
    restoreOoiFrameScrolling();
    delete window.__yahagiMobileOoiAlignGame;
  };

  const cleanupGamePresentation = () => {
    restoreGameViewport();
    document.getElementById(styleId)?.remove();

    if (window.__yahagiMobileScrollLock) {
      window.removeEventListener('scroll', window.__yahagiMobileScrollLock);
    }
    if (window.__yahagiMobileAlignGame) {
      window.removeEventListener('load', window.__yahagiMobileAlignGame);
    }

    document.getElementById('game_frame')?.removeAttribute('scrolling');
    delete window.__yahagiMobileScrollLock;
    delete window.__yahagiMobileAlignGame;
  };

  const host = location.hostname.toLowerCase();
  const pathname = location.pathname.toLowerCase();
  const isAccountPage =
    host === 'accounts.dmm.com' || host === 'accounts.dmm.co.jp';
  const isKancolleServerPage =
    host === 'kancolle-server.com' ||
    host.endsWith('.kancolle-server.com');
  const isCurrentDmmGamePage =
    host === 'play.games.dmm.com' &&
    (pathname === '/game/kancolle' || pathname === '/game/kancolle/');
  const isLegacyDmmGamePage =
    (host === 'www.dmm.com' ||
      host === 'dmm.com' ||
      host === 'games.dmm.com') &&
    (pathname === '/netgame/social/-/gadgets/=/app_id=854854' ||
      pathname === '/netgame/social/-/gadgets/=/app_id=854854/');
  const isOoiBrowserPage =
    host === 'ooi.moe' &&
    ['/kancolle', '/poi', '/flash', '/kcs2/index.php'].includes(
      pathname.replace(/\/$/, ''),
    );
  const isGamePage =
    isCurrentDmmGamePage ||
    isLegacyDmmGamePage ||
    host === 'osapi.dmm.com' ||
    isKancolleServerPage ||
    isOoiBrowserPage;

  const isVisibleElement = (element) => {
    if (!element || !element.isConnected || element.hidden) return false;
    const style = getComputedStyle(element);
    if (
      style.display === 'none' ||
      style.visibility === 'hidden' ||
      style.visibility === 'collapse'
    ) {
      return false;
    }
    const rect = element.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  };

  const hasBlockingPageDialog = () =>
    Array.from(document.querySelectorAll('dialog[open]')).some(
      isVisibleElement,
    );

  const hasStandaloneGameCanvas = () =>
    Array.from(document.querySelectorAll('canvas')).some(
      (canvas) =>
        canvas.width === 1200 &&
        canvas.height === 720 &&
        isVisibleElement(canvas),
    );

  const findOoiBrowserSurface = () =>
    Array.from(document.querySelectorAll(ooiBrowserSurfaceSelector)).find(
      isVisibleElement,
    );

  // Password visibility toggles may change type to text; the field name and
  // autocomplete intent still identify an ordinary OOI authentication form.
  const hasOoiLoginForm = () => isOoiBrowserPage && Array.from(
    document.querySelectorAll('input[type="password"], input[name="password"], input[autocomplete="current-password"], input[autocomplete="new-password"]'),
  ).some(isVisibleElement);

  const notifyPresentationState = (nextState, forceFit = false) => {
    // Explicit fits must survive both JS and native state deduplication.
    if (forceFit && nextState === 'game') {
      window.__yahagiMobilePresentationState = nextState;
      window.YahagiPresentation?.postMessage('game-fit');
      return;
    }
    if (window.__yahagiMobilePresentationState === nextState) return;
    window.__yahagiMobilePresentationState = nextState;
    if (window.YahagiPresentation) {
      window.YahagiPresentation.postMessage(nextState);
    }
  };

  const applyGamePresentation = () => {
    if (isOoiBrowserPage) hadOoiGameSurface = true;
    applyGameViewport();
    let style = document.getElementById(styleId);
    if (!style) {
      style = document.createElement('style');
      style.id = styleId;
      document.head.appendChild(style);
    }
    if (style.textContent !== fixedCanvasCss) {
      style.textContent = fixedCanvasCss;
    }

    if (!window.__yahagiMobileAlignGame) {
      window.__yahagiMobileAlignGame = () => {
        window.__yahagiMobileOoiAlignGame?.();
        window.scrollTo(0, 0);
        if (document.documentElement) document.documentElement.scrollTop = 0;
        if (document.body) document.body.scrollTop = 0;

        const gameFrame = document.getElementById('game_frame');
        if (gameFrame) {
          gameFrame.setAttribute('scrolling', 'no');
          try {
            gameFrame.contentWindow?.scrollTo(0, 0);
          } catch (_) {
            // A cross-origin game frame is still locked by touch-action above.
          }
        }
      };
    }

    if (!window.__yahagiMobileScrollLock) {
      window.__yahagiMobileScrollLock = () => {
        window.__yahagiMobileAlignGame?.();
      };
      window.addEventListener('scroll', window.__yahagiMobileScrollLock, {
        passive: true,
      });
    }

    if (document.readyState === 'complete') {
      window.__yahagiMobileAlignGame();
    } else {
      window.addEventListener('load', window.__yahagiMobileAlignGame);
    }
  };

  const applyOoiBrowserPresentation = () => {
    let style = document.getElementById(ooiBrowserStyleId);
    if (!style) {
      style = document.createElement('style');
      style.id = ooiBrowserStyleId;
      document.head.appendChild(style);
    }
    if (style.textContent !== ooiBrowserCss) {
      style.textContent = ooiBrowserCss;
    }

    if (!window.__yahagiMobileOoiAlignGame) {
      window.__yahagiMobileOoiAlignGame = () => {
        const frame = findOoiBrowserSurface();
        if (!frame || !document.documentElement) return;

        window.scrollTo(0, 0);
        document.documentElement.scrollTop = 0;
        if (document.body) document.body.scrollTop = 0;
        if (!ooiFrameScrolling.has(frame)) {
          restoreOoiFrameScrolling();
          ooiFrameScrolling.set(frame, frame.getAttribute('scrolling'));
        }
        if (frame.getAttribute('scrolling') !== 'no') frame.setAttribute('scrolling', 'no');
        try {
          // HTML embed surfaces expose their window through window.frames.
          const childWindow = frame.contentWindow || Array.from(window.frames || []).find((child) => {
            try {
              return child.frameElement === frame;
            } catch (_) {
              return false;
            }
          });
          childWindow?.scrollTo(0, 0);
        } catch (_) {
          // Cross-origin children remain protected by the browser's origin policy.
        }
      };
    }
    window.__yahagiMobileOoiAlignGame();
  };

  let scheduledFrame = null;
  let scheduledTimer = null;
  const cancelScheduledSync = () => {
    if (scheduledFrame !== null) {
      window.cancelAnimationFrame?.(scheduledFrame);
      scheduledFrame = null;
    }
    if (scheduledTimer !== null) {
      clearTimeout(scheduledTimer);
      scheduledTimer = null;
    }
  };
  const scheduleSync = () => {
    if (scheduledFrame !== null || scheduledTimer !== null) return;
    const synchronize = () => {
      cancelScheduledSync();
      window.__yahagiMobileSyncPresentation();
    };
    // Animation frames may pause in a hidden/folding WebView. Bound that wait.
    scheduledTimer = setTimeout(synchronize, 100);
    if (typeof window.requestAnimationFrame === 'function') {
      scheduledFrame = window.requestAnimationFrame(synchronize);
    }
  };

  const readPresentation = () => {
    if (!document.documentElement || !document.head || !document.body) {
      return {state: isGamePage && !isAccountPage ? 'pending' : 'web', unparsed: true};
    }
    if (!isGamePage || isAccountPage || hasBlockingPageDialog() || hasOoiLoginForm()) {
      return {state: 'web'};
    }
    const hasOoiBrowserSurface = isOoiBrowserPage && Boolean(findOoiBrowserSurface());
    if (isOoiBrowserPage && hasOoiBrowserSurface) {
      // Android WebView does not scale an embed/iframe's composited surface
      // with CSS transform. Pin the original frame and use the native
      // 1200x720 fixed-canvas fit, the same path as the DMM game.
      return {state: 'game', ooi: true};
    }

    const hasGameSurface =
      Array.from(
        document.querySelectorAll('#game_frame, #game-container'),
      ).some(isVisibleElement) || hasStandaloneGameCanvas();

    // Initial loading is pending. Once OOI has shown a game, removing its
    // surface releases the viewport and native fit for ordinary page content.
    // Mutation batching keeps a synchronous frame replacement in game mode.
    return {state: hasGameSurface ? 'game' : isOoiBrowserPage && hadOoiGameSurface ? 'web' : 'pending'};
  };
  // Native hints may be queued by an older document. Re-read without fitting
  // or notifying the bridge again, so acknowledgement cannot form a loop.
  window.__yahagiMobileReadPresentation = () => readPresentation().state;

  window.__yahagiMobileSyncPresentation = (forceFit = false) => {
    cancelScheduledSync();
    const presentation = readPresentation();
    if (presentation.unparsed) {
      notifyPresentationState(presentation.state);
      return presentation.state;
    }
    if (presentation.ooi) {
      applyGamePresentation();
      applyOoiBrowserPresentation();
      notifyPresentationState('game', forceFit);
      return 'game';
    }
    cleanupOoiBrowserPresentation();
    if (presentation.state === 'web') {
      cleanupGamePresentation();
      notifyPresentationState('web');
      return 'web';
    }
    if (presentation.state === 'pending') {
      notifyPresentationState('pending');
      return 'pending';
    }

    applyGamePresentation();
    notifyPresentationState('game', forceFit);
    return 'game';
  };

  // Replace cached OOI hooks when upgrading a runtime in a retained document.
  cleanupOoiBrowserPresentation();
  cleanupGamePresentation();
  if (window.__yahagiMobileOoiResize) {
    window.removeEventListener('resize', window.__yahagiMobileOoiResize);
    delete window.__yahagiMobileOoiResize;
  }
  window.__yahagiMobilePresentationObserver?.disconnect();
  if ((isGamePage && !isAccountPage) || isOoiBrowserPage) {
    window.__yahagiMobilePresentationObserver = new MutationObserver(() => {
      scheduleSync();
    });
    window.__yahagiMobilePresentationObserver.observe(document.documentElement || document, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['class', 'hidden', 'style', 'width', 'height', 'id', 'open', 'content', 'name', 'type', 'autocomplete'],
    });
    window.addEventListener('resize', scheduleSync, {passive: true});
    window.visualViewport?.addEventListener('resize', scheduleSync, {passive: true});
    document.addEventListener('DOMContentLoaded', scheduleSync, {once: true});
  }

  window.__yahagiMobileDisposePresentation = () => {
    cancelScheduledSync();
    window.__yahagiMobilePresentationObserver?.disconnect();
    window.removeEventListener('resize', scheduleSync);
    window.visualViewport?.removeEventListener?.('resize', scheduleSync);
    document.removeEventListener('DOMContentLoaded', scheduleSync);
    cleanupOoiBrowserPresentation();
    cleanupGamePresentation();
  };

  window.__yahagiMobilePresentationRuntimeVersion = runtimeVersion;
  return window.__yahagiMobileSyncPresentation(true);
})();
''';
