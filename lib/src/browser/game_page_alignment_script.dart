const String gamePageAlignmentScript = r'''
(() => {
  const isGamePage =
    location.pathname.includes('kancolle') ||
    location.pathname.includes('854854') ||
    location.hostname === 'osapi.dmm.com' ||
    location.pathname.includes('/kcs');
  if (!isGamePage || location.hostname === 'accounts.dmm.com') return;

  const styleId = '__yahagi_mobile_fixed_canvas__';
  let style = document.getElementById(styleId);

  if (!style) {
    style = document.createElement('style');
    style.id = styleId;
    document.head.appendChild(style);
  }

  style.textContent = `
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

  window.__yahagiMobileAlignGame = () => {
    window.scrollTo(0, 0);
    document.documentElement.scrollTop = 0;
    document.body.scrollTop = 0;

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

  if (window.__yahagiMobileScrollLock) {
    window.removeEventListener('scroll', window.__yahagiMobileScrollLock);
  }
  window.__yahagiMobileScrollLock = () => {
    window.__yahagiMobileAlignGame();
  };
  window.addEventListener('scroll', window.__yahagiMobileScrollLock, {
    passive: true,
  });
  
  if (document.readyState === 'complete') {
    window.__yahagiMobileAlignGame();
  } else {
    window.addEventListener('load', window.__yahagiMobileAlignGame);
  }
})();
''';
