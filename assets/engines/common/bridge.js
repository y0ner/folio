(() => {
  'use strict';

  const DOUBLE_TAP_DELAY_MS = 280;
  const MOVE_SLOP_PX = 10;

  let bridgeReady = Boolean(
    window.flutter_inappwebview &&
      typeof window.flutter_inappwebview.callHandler === 'function'
  );
  const pendingQueue = [];

  function callNative(obj) {
    try {
      if (
        window.flutter_inappwebview &&
        typeof window.flutter_inappwebview.callHandler === 'function'
      ) {
        window.flutter_inappwebview.callHandler('folio', obj);
      }
    } catch (err) {
      console.error('Folio bridge error:', err);
    }
  }

  function send(obj) {
    if (bridgeReady) {
      callNative(obj);
    } else {
      pendingQueue.push(obj);
    }
  }

  window.addEventListener('flutterInAppWebViewPlatformReady', () => {
    bridgeReady = true;
    while (pendingQueue.length > 0) {
      callNative(pendingQueue.shift());
    }
  });

  // Detecta archivos Office cifrados (cabecera OLE2: D0 CF 11 E0).
  function hasOleHeader(buffer) {
    if (!(buffer instanceof ArrayBuffer) || buffer.byteLength < 4) {
      return false;
    }
    const header = new Uint8Array(buffer, 0, 4);
    return (
      header[0] === 0xd0 &&
      header[1] === 0xcf &&
      header[2] === 0x11 &&
      header[3] === 0xe0
    );
  }

  // options.allowOle: el formato admite archivos OLE legítimos (p. ej. .xls
  // antiguo); entonces la cabecera OLE no se trata como cifrado.
  async function loadDocument(url, options) {
    const allowOle = Boolean(options && options.allowOle);
    let response;
    try {
      response = await fetch(url);
    } catch (err) {
      const error = new Error(
        err && err.message ? err.message : 'No se pudo obtener el documento'
      );
      error.folioKind = 'engine';
      throw error;
    }

    if (!response.ok) {
      const error = new Error(`HTTP ${response.status}`);
      error.folioKind = 'engine';
      throw error;
    }

    const buffer = await response.arrayBuffer();
    if (!allowOle && hasOleHeader(buffer)) {
      const detail = 'Documento protegido con contraseña (OLE)';
      send({ type: 'error', kind: 'encrypted', detail });
      const error = new Error(detail);
      error.folioKind = 'encrypted';
      error.folioReported = true;
      throw error;
    }
    return buffer;
  }

  // Detección de toque simple sin desplazamiento, zoom, doble toque ni enlaces.
  let startX = 0;
  let startY = 0;
  let startScale = currentScale();
  let sawTouch = false;
  let moved = false;
  let multiTouch = false;
  let tapTimer = null;
  let lastTapAt = 0;

  function currentScale() {
    return window.visualViewport ? window.visualViewport.scale : 1;
  }

  function cancelPendingTap() {
    if (tapTimer !== null) {
      clearTimeout(tapTimer);
      tapTimer = null;
    }
  }

  document.addEventListener(
    'touchstart',
    (event) => {
      sawTouch = true;
      if (event.touches.length > 1) {
        multiTouch = true;
        cancelPendingTap();
        return;
      }
      const touch = event.touches[0];
      if (!touch) return;
      startX = touch.clientX;
      startY = touch.clientY;
      startScale = currentScale();
      moved = false;
      multiTouch = false;
      if (tapTimer !== null && Date.now() - lastTapAt < DOUBLE_TAP_DELAY_MS) {
        cancelPendingTap();
        lastTapAt = Date.now();
      }
    },
    { passive: true }
  );

  document.addEventListener(
    'touchmove',
    (event) => {
      if (event.touches.length > 1) {
        multiTouch = true;
        cancelPendingTap();
        return;
      }
      const touch = event.touches[0];
      if (!touch) return;
      const dx = touch.clientX - startX;
      const dy = touch.clientY - startY;
      if (Math.hypot(dx, dy) > MOVE_SLOP_PX) {
        moved = true;
        cancelPendingTap();
      }
    },
    { passive: true }
  );

  document.addEventListener('click', (event) => {
    const scaleChanged = sawTouch && Math.abs(currentScale() - startScale) > 0.01;
    const gestureInvalid = moved || multiTouch || scaleChanged;
    sawTouch = false;
    moved = false;
    multiTouch = false;
    startScale = currentScale();

    if (gestureInvalid) {
      cancelPendingTap();
      return;
    }

    const target = event.target instanceof Element ? event.target : null;
    if (target && target.closest('a[href]')) {
      cancelPendingTap();
      return;
    }

    const selection = window.getSelection ? window.getSelection() : null;
    if (selection && selection.toString().length > 0) {
      cancelPendingTap();
      return;
    }

    const now = Date.now();
    if (
      event.detail > 1 ||
      tapTimer !== null ||
      now - lastTapAt < DOUBLE_TAP_DELAY_MS
    ) {
      cancelPendingTap();
      lastTapAt = now;
      return;
    }

    lastTapAt = now;
    tapTimer = setTimeout(() => {
      tapTimer = null;
      send({ type: 'tap' });
    }, DOUBLE_TAP_DELAY_MS);
  });

  // Seguimiento de la página más visible en pantalla.
  let pageObserver = null;
  let lastReportedPage = 0;

  function observePages(elements) {
    if (pageObserver) {
      pageObserver.disconnect();
      pageObserver = null;
    }
    lastReportedPage = 0;

    const list = Array.from(elements || []);
    if (list.length === 0 || typeof IntersectionObserver !== 'function') {
      return;
    }

    const visibleHeights = new Map();
    pageObserver = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          const height = entry.isIntersecting ? entry.intersectionRect.height : 0;
          visibleHeights.set(entry.target, height);
        }

        let bestPage = 0;
        let bestHeight = 0;
        for (let i = 0; i < list.length; i += 1) {
          const h = visibleHeights.get(list[i]) || 0;
          if (h > bestHeight) {
            bestHeight = h;
            bestPage = i + 1;
          }
        }

        if (bestPage > 0 && bestPage !== lastReportedPage) {
          lastReportedPage = bestPage;
          send({ type: 'page', page: bestPage });
        }
      },
      { threshold: [0, 0.1, 0.25, 0.5, 0.75, 1] }
    );

    for (const el of list) {
      visibleHeights.set(el, 0);
      pageObserver.observe(el);
    }
  }

  // Errores globales del motor no capturados.
  window.addEventListener('error', (event) => {
    const detail =
      event && event.message
        ? String(event.message)
        : 'Error inesperado en el motor';
    send({ type: 'error', kind: 'engine', detail });
  });

  window.addEventListener('unhandledrejection', (event) => {
    const reason = event ? event.reason : null;
    if (reason && reason.folioReported) return;
    const detail =
      reason && reason.message
        ? String(reason.message)
        : String(reason || 'Promesa rechazada sin manejar');
    send({ type: 'error', kind: 'engine', detail });
  });

  window.folio = Object.assign(window.folio || {}, {
    send,
    loadDocument,
    observePages,
  });
})();
