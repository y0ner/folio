(() => {
  'use strict';

  const PAGE_MARGIN_PX = 12;

  const container = document.getElementById('viewer');
  let pageSlots = [];
  let lastLayoutWidth = 0;
  let resizeRaf = 0;

  function setCanvas(canvas) {
    if (typeof canvas === 'string' && canvas.length > 0) {
      document.documentElement.style.setProperty('--canvas', canvas);
    }
  }

  function fitToWidth() {
    if (pageSlots.length === 0) return;
    const viewportWidth = document.documentElement.clientWidth || window.innerWidth;
    if (!viewportWidth) return;
    lastLayoutWidth = viewportWidth;

    const availableWidth = Math.max(80, viewportWidth - PAGE_MARGIN_PX * 2);

    for (const item of pageSlots) {
      const naturalWidth = item.page.offsetWidth;
      const naturalHeight = item.page.offsetHeight;
      if (!naturalWidth || !naturalHeight) continue;

      const scale = Math.min(2, availableWidth / naturalWidth);
      item.page.style.transform = `scale(${scale})`;
      item.slot.style.width = `${naturalWidth * scale}px`;
      item.slot.style.height = `${naturalHeight * scale}px`;
    }
  }

  function scheduleFit() {
    const currentWidth = document.documentElement.clientWidth || window.innerWidth;
    if (currentWidth === lastLayoutWidth) return;
    if (resizeRaf) {
      cancelAnimationFrame(resizeRaf);
    }
    resizeRaf = requestAnimationFrame(() => {
      resizeRaf = 0;
      fitToWidth();
    });
  }

  window.addEventListener('resize', scheduleFit);
  window.addEventListener('orientationchange', () => {
    lastLayoutWidth = 0;
    scheduleFit();
  });

  // Evita navegar fuera del documento al tocar enlaces.
  document.addEventListener('click', (event) => {
    const target = event.target instanceof Element ? event.target : null;
    const anchor = target ? target.closest('a[href]') : null;
    if (!anchor) return;

    event.preventDefault();
    const href = anchor.getAttribute('href') || '';
    if (href.startsWith('#') && href.length > 1) {
      const id = decodeURIComponent(href.slice(1));
      const destination = document.getElementById(id);
      if (destination) {
        destination.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }
  });

  function wrapPages() {
    const pages = Array.from(container.querySelectorAll('section.docx'));
    pageSlots = pages.map((page) => {
      const slot = document.createElement('div');
      slot.className = 'folio-page-slot';
      if (page.parentNode) {
        page.parentNode.insertBefore(slot, page);
      }
      slot.appendChild(page);
      return { slot, page };
    });
  }

  async function init(config) {
    const options = config || {};
    setCanvas(options.canvas);

    if (!options.docUrl) {
      window.folio.send({
        type: 'error',
        kind: 'engine',
        detail: 'Falta docUrl al inicializar el motor Word',
      });
      return;
    }

    container.innerHTML = '';
    pageSlots = [];
    lastLayoutWidth = 0;

    let buffer;
    try {
      buffer = await window.folio.loadDocument(options.docUrl);
    } catch (err) {
      if (err && err.folioReported) return;
      const kind = err && err.folioKind ? err.folioKind : 'engine';
      const detail = err && err.message ? err.message : String(err);
      window.folio.send({ type: 'error', kind, detail });
      return;
    }

    try {
      if (!window.docx || typeof window.docx.renderAsync !== 'function') {
        throw new Error('docx-preview no está disponible');
      }

      await window.docx.renderAsync(buffer, container, null, {
        inWrapper: true,
        breakPages: true,
        ignoreLastRenderedPageBreak: false,
        renderHeaders: true,
        renderFooters: true,
        renderFootnotes: true,
        renderEndnotes: true,
        experimental: true,
        useBase64URL: true,
      });

      if (document.fonts && document.fonts.ready) {
        await document.fonts.ready;
      }

      wrapPages();
      fitToWidth();
      window.folio.observePages(pageSlots.map((item) => item.slot));
      window.folio.send({
        type: 'ready',
        pageCount: pageSlots.length,
        sections: [],
      });
    } catch (err) {
      const detail = err && err.message ? err.message : String(err);
      window.folio.send({ type: 'error', kind: 'corrupt', detail });
    }
  }

  function goToPage(n) {
    const index = Number(n) - 1;
    if (!Number.isInteger(index) || index < 0 || index >= pageSlots.length) {
      return;
    }
    pageSlots[index].slot.scrollIntoView({
      behavior: 'smooth',
      block: 'start',
    });
  }

  window.folio = Object.assign(window.folio || {}, {
    init,
    goToPage,
    setCanvas,
  });
})();
