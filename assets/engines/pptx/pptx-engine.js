(() => {
  'use strict';

  const SLIDE_MARGIN_PX = 12;
  const DEFAULT_SLIDE_SIZE = { cx: 12192000, cy: 6858000 }; // 16:9 en EMU
  const EMU_PER_POINT = 12700; // 914400 EMU/pulgada / 72 pt/pulgada
  const LAZY_SLIDE_THRESHOLD = 60;
  const INITIAL_SLIDE_BATCH = 6;
  const CHUNK_SLIDE_BATCH = 4;

  const container = document.getElementById('viewer');
  let slideSlots = [];
  let currentPreviewer = null;
  let lastLayoutWidth = 0;
  let resizeRaf = 0;
  let chunkRaf = 0;
  let lazyObserver = null;
  let renderGeneration = 0;

  function setCanvas(canvas) {
    if (typeof canvas === 'string' && canvas.length > 0) {
      document.documentElement.style.setProperty('--canvas', canvas);
    }
  }

  function getViewportWidth() {
    return document.documentElement.clientWidth || window.innerWidth || 360;
  }

  function getAvailableWidth() {
    return Math.max(80, getViewportWidth() - SLIDE_MARGIN_PX * 2);
  }

  function fitSlot(item, availableWidth) {
    const naturalWidth = item.slide
      ? item.slide.offsetWidth || item.baseWidth
      : item.baseWidth;
    const naturalHeight = item.slide
      ? item.slide.offsetHeight || item.baseHeight
      : item.baseHeight;
    if (!naturalWidth || !naturalHeight) return;

    const scale = availableWidth / naturalWidth;
    item.slot.style.width = `${naturalWidth * scale}px`;
    item.slot.style.height = `${naturalHeight * scale}px`;
    if (item.slide) {
      item.slide.style.transform =
        Math.abs(scale - 1) < 0.001 ? '' : `scale(${scale})`;
    }
  }

  function fitToWidth() {
    if (slideSlots.length === 0) return;
    const viewportWidth = getViewportWidth();
    if (!viewportWidth) return;
    lastLayoutWidth = viewportWidth;

    const availableWidth = getAvailableWidth();
    for (const item of slideSlots) {
      fitSlot(item, availableWidth);
    }
  }

  function scheduleFit() {
    const currentWidth = getViewportWidth();
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
  });

  function cancelPendingWork() {
    renderGeneration += 1;
    if (chunkRaf) {
      cancelAnimationFrame(chunkRaf);
      chunkRaf = 0;
    }
    if (lazyObserver) {
      lazyObserver.disconnect();
      lazyObserver = null;
    }
    if (currentPreviewer && typeof currentPreviewer.destroy === 'function') {
      try {
        currentPreviewer.destroy();
      } catch (err) {
        console.warn('Error al destruir instancia previa de pptxPreview:', err);
      }
    }
    currentPreviewer = null;
  }

  function nextFrame() {
    return new Promise((resolve) => requestAnimationFrame(() => resolve()));
  }

  async function readSlideSize(buffer) {
    if (!window.JSZip || typeof window.JSZip.loadAsync !== 'function') {
      throw new Error('JSZip no está disponible');
    }
    // Si el ZIP es inválido, loadAsync lanza error y se reporta como corrupto.
    const zip = await window.JSZip.loadAsync(buffer);
    try {
      const entry = zip.file('ppt/presentation.xml');
      if (!entry) return DEFAULT_SLIDE_SIZE;
      const xml = await entry.async('string');
      const doc = new DOMParser().parseFromString(xml, 'application/xml');
      const sldSz =
        doc.getElementsByTagNameNS('*', 'sldSz')[0] ||
        doc.getElementsByTagName('p:sldSz')[0] ||
        doc.getElementsByTagName('sldSz')[0];
      if (!sldSz) return DEFAULT_SLIDE_SIZE;

      const cx = Number(sldSz.getAttribute('cx'));
      const cy = Number(sldSz.getAttribute('cy'));
      if (!Number.isFinite(cx) || !Number.isFinite(cy) || cx <= 0 || cy <= 0) {
        return DEFAULT_SLIDE_SIZE;
      }
      return { cx, cy };
    } catch (err) {
      console.warn('No se pudo leer sldSz, se asume proporción 16:9:', err);
      return DEFAULT_SLIDE_SIZE;
    }
  }

  function renderSlideAt(index) {
    const item = slideSlots[index];
    if (
      !item ||
      item.rendered ||
      !currentPreviewer ||
      !currentPreviewer.htmlRender
    ) {
      return;
    }

    item.rendered = true;
    if (lazyObserver) {
      lazyObserver.unobserve(item.slot);
    }

    currentPreviewer.htmlRender.renderSlide(index);
    const slideEl =
      currentPreviewer.wrapper.querySelector(
        `.pptx-preview-slide-wrapper-${index}`
      ) || currentPreviewer.wrapper.lastElementChild;
    if (slideEl && slideEl.classList.contains('pptx-preview-slide-wrapper')) {
      item.slot.appendChild(slideEl);
      item.slide = slideEl;
    }
    fitSlot(item, getAvailableWidth());
  }

  function observeVisibleForLazyRender() {
    if (typeof IntersectionObserver !== 'function') return;
    lazyObserver = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          const idx = Number(entry.target.dataset.slideIndex);
          if (Number.isInteger(idx)) {
            try {
              renderSlideAt(idx);
            } catch (err) {
              console.error(`Error al renderizar diapositiva ${idx + 1}:`, err);
            }
          }
        }
      },
      { rootMargin: '600px 0px' }
    );

    for (const item of slideSlots) {
      if (!item.rendered) {
        lazyObserver.observe(item.slot);
      }
    }
  }

  function renderRemainingSlides(startIndex, generation) {
    let nextIndex = startIndex;

    function step() {
      if (generation !== renderGeneration) return;
      let renderedInChunk = 0;
      while (
        nextIndex < slideSlots.length &&
        renderedInChunk < CHUNK_SLIDE_BATCH
      ) {
        const idx = nextIndex;
        nextIndex += 1;
        if (!slideSlots[idx].rendered) {
          try {
            renderSlideAt(idx);
          } catch (err) {
            console.error(`Error al renderizar diapositiva ${idx + 1}:`, err);
          }
          renderedInChunk += 1;
        }
      }

      if (nextIndex < slideSlots.length) {
        chunkRaf = requestAnimationFrame(step);
      } else {
        chunkRaf = 0;
      }
    }

    chunkRaf = requestAnimationFrame(step);
  }

  function createSlideSlots(wrapper, slideCount, baseWidth, baseHeight) {
    slideSlots = [];
    const fragment = document.createDocumentFragment();
    for (let i = 0; i < slideCount; i += 1) {
      const slot = document.createElement('div');
      slot.className = 'folio-slide-slot';
      slot.dataset.slideIndex = String(i);
      slot.style.width = `${baseWidth}px`;
      slot.style.height = `${baseHeight}px`;
      fragment.appendChild(slot);
      slideSlots.push({
        index: i,
        slot,
        slide: null,
        baseWidth,
        baseHeight,
        rendered: false,
      });
    }
    wrapper.appendChild(fragment);
  }

  function wrapExistingSlides(baseWidth, baseHeight) {
    const slides = Array.from(
      container.querySelectorAll('.pptx-preview-slide-wrapper')
    );
    slideSlots = slides.map((slide, index) => {
      const slot = document.createElement('div');
      slot.className = 'folio-slide-slot';
      slot.dataset.slideIndex = String(index);
      if (slide.parentNode) {
        slide.parentNode.insertBefore(slot, slide);
      }
      slot.appendChild(slide);
      return {
        index,
        slot,
        slide,
        baseWidth: slide.offsetWidth || baseWidth,
        baseHeight: slide.offsetHeight || baseHeight,
        rendered: true,
      };
    });
  }

  async function init(config) {
    const options = config || {};
    cancelPendingWork();
    const generation = renderGeneration;
    setCanvas(options.canvas);

    if (!options.docUrl) {
      window.folio.send({
        type: 'error',
        kind: 'engine',
        detail: 'Falta docUrl al inicializar el motor PowerPoint',
      });
      return;
    }

    container.innerHTML = '';
    slideSlots = [];
    lastLayoutWidth = 0;

    let buffer;
    try {
      buffer = await window.folio.loadDocument(options.docUrl);
    } catch (err) {
      if (generation !== renderGeneration) return;
      if (err && err.folioReported) return;
      const kind = err && err.folioKind ? err.folioKind : 'engine';
      const detail = err && err.message ? err.message : String(err);
      window.folio.send({ type: 'error', kind, detail });
      return;
    }
    if (generation !== renderGeneration) return;

    try {
      if (
        !window.pptxPreview ||
        typeof window.pptxPreview.init !== 'function'
      ) {
        throw new Error('pptx-preview no está disponible');
      }

      const slideSize = await readSlideSize(buffer);
      if (generation !== renderGeneration) return;

      const width = getAvailableWidth();
      const height = Math.round((width * slideSize.cy) / slideSize.cx);

      const previewer = window.pptxPreview.init(container, {
        width,
        height,
        mode: 'list',
      });
      currentPreviewer = previewer;

      let slideCount = 0;
      let deferredStart = 0;

      if (typeof previewer.load === 'function') {
        const pptx = await previewer.load(buffer);
        if (generation !== renderGeneration) return;

        slideCount =
          previewer.slideCount ||
          (pptx && Array.isArray(pptx.slides) ? pptx.slides.length : 0);
        if (!slideCount) {
          throw new Error('La presentación no contiene diapositivas');
        }

        if (!pptx.width || !pptx.height) {
          pptx.width = slideSize.cx / EMU_PER_POINT;
          pptx.height = slideSize.cy / EMU_PER_POINT;
          if (
            previewer.htmlRender &&
            typeof previewer.htmlRender._calcScaleAndRenderPort === 'function'
          ) {
            previewer.htmlRender._calcScaleAndRenderPort();
          }
        }

        const renderPort =
          previewer.htmlRender && previewer.htmlRender.renderPort;
        const baseWidth =
          renderPort && Number.isFinite(renderPort.width)
            ? renderPort.width
            : width;
        const baseHeight =
          renderPort && Number.isFinite(renderPort.height)
            ? renderPort.height
            : height;

        createSlideSlots(previewer.wrapper, slideCount, baseWidth, baseHeight);

        const initialCount =
          slideCount > LAZY_SLIDE_THRESHOLD
            ? Math.min(INITIAL_SLIDE_BATCH, slideCount)
            : slideCount;
        for (let i = 0; i < initialCount; i += 1) {
          renderSlideAt(i);
        }
        deferredStart = initialCount;
      } else {
        await previewer.preview(buffer);
        if (generation !== renderGeneration) return;

        wrapExistingSlides(width, height);
        slideCount = previewer.slideCount || slideSlots.length;
        if (!slideCount || slideSlots.length === 0) {
          throw new Error('La presentación no contiene diapositivas');
        }
      }

      if (document.fonts && document.fonts.ready) {
        await document.fonts.ready;
      }
      if (generation !== renderGeneration) return;

      fitToWidth();
      window.folio.observePages(slideSlots.map((item) => item.slot));
      await nextFrame();
      if (generation !== renderGeneration) return;

      window.folio.send({
        type: 'ready',
        pageCount: slideCount,
        sections: [],
      });

      if (deferredStart > 0 && deferredStart < slideCount) {
        observeVisibleForLazyRender();
        renderRemainingSlides(deferredStart, generation);
      }
    } catch (err) {
      if (generation !== renderGeneration) return;
      const detail = err && err.message ? err.message : String(err);
      window.folio.send({ type: 'error', kind: 'corrupt', detail });
    }
  }

  function goToPage(n) {
    const index = Number(n) - 1;
    if (!Number.isInteger(index) || index < 0 || index >= slideSlots.length) {
      return;
    }

    const from = Math.max(0, index - 1);
    const to = Math.min(slideSlots.length - 1, index + 1);
    for (let i = from; i <= to; i += 1) {
      try {
        renderSlideAt(i);
      } catch (err) {
        console.error(`Error al renderizar diapositiva ${i + 1}:`, err);
      }
    }

    slideSlots[index].slot.scrollIntoView({
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
