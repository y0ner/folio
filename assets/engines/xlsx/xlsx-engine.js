(() => {
  'use strict';

  const MAX_ROWS = 20000;
  const MAX_COLS = 200;
  const BLOCK_SIZE = 100;
  const BUFFER_ROWS = 50;
  const MAX_DOM_BLOCKS = 6;
  const MAX_CACHED_BLOCKS = 48;

  const container = document.getElementById('viewer');
  let worker = null;
  let loadGeneration = 0;
  let renderGeneration = 0;
  let nextRequestId = 1;
  let visibleSections = [];
  let sheetMetas = [];
  let sheetCaches = [];
  let currentSheetIndex = 0;

  let activeVirtual = null;
  let pendingScrollFrame = null;

  function setCanvas(canvas) {
    if (typeof canvas === 'string' && canvas.length > 0) {
      document.documentElement.style.setProperty('--canvas', canvas);
    }
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function formatCount(value) {
    return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  }

  function buildTruncationMessage(totalRows, totalCols) {
    const rowsTruncated = totalRows > MAX_ROWS;
    const colsTruncated = totalCols > MAX_COLS;
    if (rowsTruncated && colsTruncated) {
      return `Se muestran las primeras ${formatCount(MAX_ROWS)} filas de ${formatCount(totalRows)} y las primeras ${formatCount(MAX_COLS)} columnas de ${formatCount(totalCols)}.`;
    }
    if (rowsTruncated) {
      return `Se muestran las primeras ${formatCount(MAX_ROWS)} filas de ${formatCount(totalRows)}.`;
    }
    if (colsTruncated) {
      return `Se muestran las primeras ${formatCount(MAX_COLS)} columnas de ${formatCount(totalCols)}.`;
    }
    return '';
  }

  function buildTruncationRowHtml(colCount, notice) {
    return `<tr class="sheet-truncation-row"><td class="sheet-truncation-cell" colspan="${colCount + 1}"><div class="sheet-truncation-text">${escapeHtml(notice)}</div></td></tr>`;
  }

  function getInsetTopPx() {
    const raw = getComputedStyle(document.documentElement).getPropertyValue(
      '--inset-top'
    );
    const parsed = parseFloat(raw);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  function getViewportHeight() {
    return Math.max(
      container.clientHeight ||
        window.innerHeight ||
        (document.documentElement ? document.documentElement.clientHeight : 0) ||
        0,
      800
    );
  }

  function cleanupVirtualization() {
    renderGeneration += 1;
    if (pendingScrollFrame !== null) {
      cancelAnimationFrame(pendingScrollFrame);
      pendingScrollFrame = null;
    }
    activeVirtual = null;
  }

  function terminateWorker() {
    if (worker) {
      worker.terminate();
      worker = null;
    }
  }

  function renderEmptyState() {
    cleanupVirtualization();
    container.innerHTML =
      '<div class="sheet-stage sheet-stage--empty"><div class="sheet-paper sheet-paper--empty"><p class="sheet-empty-message">Esta hoja está vacía</p></div></div>';
  }

  function getBlockCache(sheetIndex) {
    if (!sheetCaches[sheetIndex]) {
      sheetCaches[sheetIndex] = new Map();
    }
    return sheetCaches[sheetIndex];
  }

  function cacheBlockHtml(cache, blockIndex, html) {
    if (cache.has(blockIndex)) {
      cache.delete(blockIndex);
    }
    cache.set(blockIndex, html);
    while (cache.size > MAX_CACHED_BLOCKS) {
      const oldestKey = cache.keys().next().value;
      cache.delete(oldestKey);
    }
  }

  function findRowAtOffset(rowTops, rowCount, y) {
    if (y <= 0 || rowCount <= 0) return 0;
    if (y >= rowTops[rowCount]) return rowCount - 1;
    let lo = 0;
    let hi = rowCount - 1;
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1;
      if (rowTops[mid] <= y) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  function resolveBlockRange(meta, firstVisibleRow, lastVisibleRow) {
    const numBlocks = meta.numBlocks;
    if (numBlocks <= 0) return { startBlock: 0, endBlock: -1 };

    let desiredFirst = Math.max(0, firstVisibleRow - BUFFER_ROWS);
    let desiredLast = Math.min(meta.rowCount - 1, lastVisibleRow + BUFFER_ROWS);

    let sb = Math.floor(desiredFirst / BLOCK_SIZE);
    let eb = Math.floor(desiredLast / BLOCK_SIZE);

    // Si el viewport fuese muy alto, recorta el margen alrededor del centro
    // para no superar MAX_DOM_BLOCKS sin perder las filas visibles.
    if (eb - sb + 1 > MAX_DOM_BLOCKS) {
      const visSb = Math.floor(firstVisibleRow / BLOCK_SIZE);
      const visEb = Math.floor(lastVisibleRow / BLOCK_SIZE);
      const span = Math.max(MAX_DOM_BLOCKS, visEb - visSb + 1);
      const extra = Math.max(0, span - (visEb - visSb + 1));
      sb = Math.max(0, visSb - Math.floor(extra / 2));
      eb = Math.min(numBlocks - 1, sb + span - 1);
      sb = Math.max(0, eb - span + 1);
    }

    // Expande ambos extremos para que cualquier combinación (!merges) que
    // cruce fronteras de bloque se dibuje completa con su rowspan exacto.
    let changed = true;
    while (changed) {
      changed = false;
      for (let b = sb; b <= eb; b += 1) {
        const neededSb = Math.floor(meta.blockMinStartRow[b] / BLOCK_SIZE);
        const neededEb = Math.floor(meta.blockMaxEndRow[b] / BLOCK_SIZE);
        if (neededSb < sb) {
          sb = neededSb;
          changed = true;
        }
        if (neededEb > eb) {
          eb = neededEb;
          changed = true;
        }
      }
    }

    return { startBlock: sb, endBlock: eb };
  }

  function parseBlockRows(html) {
    const probe = document.createElement('table');
    probe.innerHTML = `<tbody>${html}</tbody>`;
    return Array.from(probe.tBodies[0].children);
  }

  function updateSpacerRow(row, cell, height) {
    if (height > 0) {
      row.style.display = '';
      row.style.height = `${height}px`;
      cell.style.height = `${height}px`;
    } else {
      row.style.display = 'none';
      row.style.height = '0px';
      cell.style.height = '0px';
    }
  }

  function mountSheet(sheetIndex, meta, initialBlocks) {
    cleanupVirtualization();
    currentSheetIndex = sheetIndex;

    if (!meta || meta.empty) {
      renderEmptyState();
      return;
    }

    const cache = getBlockCache(sheetIndex);
    for (let i = 0; i < initialBlocks.length; i += 1) {
      cacheBlockHtml(cache, initialBlocks[i].blockIndex, initialBlocks[i].html);
    }

    const {
      totalRows,
      totalCols,
      rowCount,
      colCount,
      rowHeaderWidth,
      totalTableWidth,
      colWidths,
      colLetters,
      rowTops,
      totalBodyHeight,
      numBlocks,
    } = meta;

    const notice = buildTruncationMessage(totalRows, totalCols);

    const html = [];
    html.push('<div class="sheet-stage"><div class="sheet-paper">');
    html.push(`<table class="sheet-table" style="width:${totalTableWidth}px">`);
    html.push('<colgroup>');
    html.push(`<col style="width:${rowHeaderWidth}px" />`);
    for (let c = 0; c < colCount; c += 1) {
      html.push(`<col style="width:${colWidths[c]}px" />`);
    }
    html.push('</colgroup>');

    html.push('<thead><tr>');
    html.push('<th class="sheet-corner" scope="col"></th>');
    for (let c = 0; c < colCount; c += 1) {
      html.push(`<th scope="col">${colLetters[c]}</th>`);
    }
    html.push('</tr></thead>');

    html.push('<tbody>');
    html.push(
      `<tr class="sheet-spacer-row sheet-spacer-top" aria-hidden="true" style="display:none;height:0px"><td class="sheet-spacer-cell" colspan="${colCount + 1}" style="height:0px"></td></tr>`
    );
    html.push(
      `<tr class="sheet-spacer-row sheet-spacer-bottom" aria-hidden="true" style="display:none;height:0px"><td class="sheet-spacer-cell" colspan="${colCount + 1}" style="height:0px"></td></tr>`
    );
    if (notice) {
      html.push(buildTruncationRowHtml(colCount, notice));
    }
    html.push('</tbody></table></div></div>');

    container.innerHTML = html.join('');

    const tableEl = container.querySelector('table.sheet-table');
    const theadEl = tableEl.querySelector('thead');
    const tbodyEl = tableEl.querySelector('tbody');
    const topSpacerRow = tbodyEl.querySelector('tr.sheet-spacer-top');
    const topSpacerCell = topSpacerRow.querySelector('td.sheet-spacer-cell');
    const bottomSpacerRow = tbodyEl.querySelector('tr.sheet-spacer-bottom');
    const bottomSpacerCell = bottomSpacerRow.querySelector('td.sheet-spacer-cell');
    const truncationRow = tbodyEl.querySelector('tr.sheet-truncation-row');

    const theadHeight = theadEl ? theadEl.offsetHeight || 22 : 22;
    const containerRect = container.getBoundingClientRect();
    const bodyStartInScroll =
      tableEl.getBoundingClientRect().top -
      containerRect.top +
      container.scrollTop +
      theadHeight;

    const currentGen = renderGeneration;
    const activeBlocks = new Map();
    let renderedStartBlock = -1;
    let renderedEndBlock = -1;
    let inFlightRequest = false;
    let queuedBlocks = null;

    const state = {
      sheetIndex,
      meta,
      cache,
      tbodyEl,
      topSpacerRow,
      topSpacerCell,
      bottomSpacerRow,
      bottomSpacerCell,
      truncationRow,
      bodyStartInScroll,
      theadHeight,
      activeBlocks,
      get renderedStartBlock() {
        return renderedStartBlock;
      },
      get renderedEndBlock() {
        return renderedEndBlock;
      },
      applyRange(sb, eb) {
        if (currentGen !== renderGeneration) return;
        if (sb > eb || numBlocks === 0) return;

        for (let b = sb; b <= eb; b += 1) {
          if (!cache.has(b)) return;
        }

        if (renderedStartBlock === sb && renderedEndBlock === eb) {
          return;
        }

        const startRow = sb * BLOCK_SIZE;
        const endRow = Math.min(rowCount, (eb + 1) * BLOCK_SIZE);
        const topHeight = rowTops[startRow];
        const bottomHeight = totalBodyHeight - rowTops[endRow];

        const overlaps =
          renderedStartBlock !== -1 &&
          sb <= renderedEndBlock &&
          eb >= renderedStartBlock;

        if (!overlaps) {
          for (const nodes of activeBlocks.values()) {
            for (let i = 0; i < nodes.length; i += 1) {
              nodes[i].remove();
            }
          }
          activeBlocks.clear();

          const frag = document.createDocumentFragment();
          for (let b = sb; b <= eb; b += 1) {
            const nodes = parseBlockRows(cache.get(b));
            activeBlocks.set(b, nodes);
            for (let i = 0; i < nodes.length; i += 1) {
              frag.appendChild(nodes[i]);
            }
          }
          tbodyEl.insertBefore(frag, bottomSpacerRow);
        } else {
          // Elimina bloques que salieron del rango y conserva los visibles.
          for (const [b, nodes] of activeBlocks.entries()) {
            if (b < sb || b > eb) {
              for (let i = 0; i < nodes.length; i += 1) {
                nodes[i].remove();
              }
              activeBlocks.delete(b);
            }
          }

          if (sb < renderedStartBlock) {
            const frag = document.createDocumentFragment();
            for (let b = sb; b < renderedStartBlock; b += 1) {
              const nodes = parseBlockRows(cache.get(b));
              activeBlocks.set(b, nodes);
              for (let i = 0; i < nodes.length; i += 1) {
                frag.appendChild(nodes[i]);
              }
            }
            tbodyEl.insertBefore(frag, topSpacerRow.nextSibling);
          }

          if (eb > renderedEndBlock) {
            const frag = document.createDocumentFragment();
            for (let b = renderedEndBlock + 1; b <= eb; b += 1) {
              const nodes = parseBlockRows(cache.get(b));
              activeBlocks.set(b, nodes);
              for (let i = 0; i < nodes.length; i += 1) {
                frag.appendChild(nodes[i]);
              }
            }
            tbodyEl.insertBefore(frag, bottomSpacerRow);
          }
        }

        renderedStartBlock = sb;
        renderedEndBlock = eb;

        updateSpacerRow(topSpacerRow, topSpacerCell, topHeight);
        updateSpacerRow(bottomSpacerRow, bottomSpacerCell, bottomHeight);
        if (truncationRow) {
          truncationRow.style.display = endRow >= rowCount ? '' : 'none';
        }
      },
      requestMissingBlocks(sb, eb) {
        if (currentGen !== renderGeneration) return;
        const missing = [];
        for (let b = sb; b <= eb; b += 1) {
          if (!cache.has(b)) {
            missing.push(b);
          }
        }
        if (missing.length === 0) {
          state.applyRange(sb, eb);
          return;
        }

        // Si saltamos a una zona totalmente distinta, ajustamos espaciadores de
        // inmediato para mantener la altura real mientras el worker responde.
        if (
          renderedStartBlock !== -1 &&
          (eb < renderedStartBlock || sb > renderedEndBlock)
        ) {
          for (const nodes of activeBlocks.values()) {
            for (let i = 0; i < nodes.length; i += 1) {
              nodes[i].remove();
            }
          }
          activeBlocks.clear();
          renderedStartBlock = -1;
          renderedEndBlock = -1;
          updateSpacerRow(topSpacerRow, topSpacerCell, totalBodyHeight);
          updateSpacerRow(bottomSpacerRow, bottomSpacerCell, 0);
        }

        if (inFlightRequest) {
          queuedBlocks = { sb, eb };
          return;
        }

        inFlightRequest = true;
        queuedBlocks = null;
        const requestId = nextRequestId++;
        state.pendingRequestId = requestId;
        state.pendingTarget = { sb, eb };
        worker.postMessage({
          type: 'getBlocks',
          requestId,
          sheetIndex,
          blockIndices: missing,
        });
      },
      onBlocksReceived(msg) {
        if (currentGen !== renderGeneration) return;
        if (msg.sheetIndex !== sheetIndex) return;

        const blocks = msg.blocks || [];
        for (let i = 0; i < blocks.length; i += 1) {
          cacheBlockHtml(cache, blocks[i].blockIndex, blocks[i].html);
        }

        inFlightRequest = false;

        if (queuedBlocks) {
          const next = queuedBlocks;
          queuedBlocks = null;
          state.requestMissingBlocks(next.sb, next.eb);
          return;
        }

        updateVirtualWindow();
      },
    };

    activeVirtual = state;
    updateVirtualWindow();
  }

  function computeVisibleBlockRange(state) {
    const meta = state.meta;
    const insetTop = getInsetTopPx();
    const scrollTop = container.scrollTop;
    const vh = getViewportHeight();

    const visibleTopY = Math.max(
      0,
      scrollTop + insetTop + state.theadHeight - state.bodyStartInScroll
    );
    const visibleBottomY = Math.max(
      visibleTopY,
      scrollTop + vh - state.bodyStartInScroll
    );

    const firstVisibleRow = findRowAtOffset(
      meta.rowTops,
      meta.rowCount,
      visibleTopY
    );
    const lastVisibleRow = findRowAtOffset(
      meta.rowTops,
      meta.rowCount,
      visibleBottomY
    );

    return resolveBlockRange(meta, firstVisibleRow, lastVisibleRow);
  }

  function updateVirtualWindow() {
    const state = activeVirtual;
    if (!state || state.meta.empty) return;

    const { startBlock, endBlock } = computeVisibleBlockRange(state);
    if (
      startBlock === state.renderedStartBlock &&
      endBlock === state.renderedEndBlock
    ) {
      return;
    }

    state.requestMissingBlocks(startBlock, endBlock);
  }

  function scheduleVirtualUpdate() {
    if (!activeVirtual || pendingScrollFrame !== null) return;
    pendingScrollFrame = requestAnimationFrame(() => {
      pendingScrollFrame = null;
      updateVirtualWindow();
    });
  }

  container.addEventListener('scroll', scheduleVirtualUpdate, { passive: true });
  window.addEventListener('resize', scheduleVirtualUpdate, { passive: true });

  function resetScrollPosition() {
    if (container) {
      container.scrollLeft = 0;
      container.scrollTop = 0;
    }
    window.scrollTo(0, 0);
  }

  function createWorker(currentLoadGen) {
    terminateWorker();
    const w = new Worker('xlsx-worker.js');
    worker = w;

    w.addEventListener('error', (event) => {
      if (currentLoadGen !== loadGeneration) return;
      const detail =
        event && event.message
          ? String(event.message)
          : 'Error inesperado en el worker de Excel';
      window.folio.send({ type: 'error', kind: 'engine', detail });
    });

    w.addEventListener('message', async (event) => {
      if (currentLoadGen !== loadGeneration) return;
      const msg = event.data;
      if (!msg || !msg.type) return;

      if (msg.type === 'error') {
        window.folio.send({
          type: 'error',
          kind: msg.kind || 'engine',
          detail: msg.detail || 'Error al procesar el libro Excel',
        });
        return;
      }

      if (msg.type === 'loaded') {
        visibleSections = msg.sections || [];
        sheetMetas = new Array(visibleSections.length);
        sheetCaches = new Array(visibleSections.length);

        if (document.fonts && document.fonts.ready) {
          await document.fonts.ready;
          if (currentLoadGen !== loadGeneration) return;
        }

        if (visibleSections.length > 0 && msg.initialSheet) {
          sheetMetas[0] = msg.initialSheet;
          mountSheet(0, msg.initialSheet, msg.initialBlocks || []);
        } else {
          renderEmptyState();
        }

        window.folio.send({
          type: 'ready',
          pageCount: 0,
          sections: visibleSections,
        });
        return;
      }

      if (msg.type === 'sheet') {
        const index = msg.sheetIndex;
        sheetMetas[index] = msg.meta;
        if (index !== currentSheetIndex) return;
        mountSheet(index, msg.meta, msg.initialBlocks || []);
        resetScrollPosition();
        return;
      }

      if (msg.type === 'blocks') {
        if (activeVirtual && activeVirtual.sheetIndex === msg.sheetIndex) {
          activeVirtual.onBlocksReceived(msg);
        }
      }
    });

    return w;
  }

  async function init(config) {
    const options = config || {};
    setCanvas(options.canvas);

    if (!options.docUrl) {
      window.folio.send({
        type: 'error',
        kind: 'engine',
        detail: 'Falta docUrl al inicializar el motor Excel',
      });
      return;
    }

    loadGeneration += 1;
    const currentLoadGen = loadGeneration;

    cleanupVirtualization();
    terminateWorker();
    container.innerHTML = '';
    visibleSections = [];
    sheetMetas = [];
    sheetCaches = [];
    currentSheetIndex = 0;

    let buffer;
    try {
      buffer = await window.folio.loadDocument(options.docUrl, {
        allowOle: true,
      });
    } catch (err) {
      if (currentLoadGen !== loadGeneration) return;
      if (err && err.folioReported) return;
      const kind = err && err.folioKind ? err.folioKind : 'engine';
      const detail = err && err.message ? err.message : String(err);
      window.folio.send({ type: 'error', kind, detail });
      return;
    }

    if (currentLoadGen !== loadGeneration) return;

    try {
      if (typeof Worker !== 'function') {
        throw new Error('Web Workers no soportados en este entorno');
      }
      const w = createWorker(currentLoadGen);
      const isCsv = /\.csv(?:[?#]|$)/i.test(options.docUrl);
      w.postMessage(
        {
          type: 'load',
          buffer,
          isCsv,
          viewportHeight: getViewportHeight(),
        },
        [buffer]
      );
    } catch (err) {
      const detail = err && err.message ? err.message : String(err);
      window.folio.send({ type: 'error', kind: 'engine', detail });
    }
  }

  function selectSheet(i) {
    const index = Number(i);
    if (
      !Number.isInteger(index) ||
      index < 0 ||
      index >= visibleSections.length
    ) {
      return;
    }

    currentSheetIndex = index;
    resetScrollPosition();

    const cachedMeta = sheetMetas[index];
    if (cachedMeta) {
      if (cachedMeta.empty) {
        renderEmptyState();
        return;
      }
      const cache = getBlockCache(index);
      const lastVisible = findRowAtOffset(
        cachedMeta.rowTops,
        cachedMeta.rowCount,
        getViewportHeight()
      );
      const { startBlock, endBlock } = resolveBlockRange(
        cachedMeta,
        0,
        lastVisible
      );
      let allCached = true;
      const initialBlocks = [];
      for (let b = startBlock; b <= endBlock; b += 1) {
        if (!cache.has(b)) {
          allCached = false;
          break;
        }
        initialBlocks.push({ blockIndex: b, html: cache.get(b) });
      }
      if (allCached) {
        mountSheet(index, cachedMeta, initialBlocks);
        return;
      }
    }

    if (worker) {
      worker.postMessage({
        type: 'getSheet',
        requestId: nextRequestId++,
        sheetIndex: index,
        viewportHeight: getViewportHeight(),
      });
    }
  }

  window.folio = Object.assign(window.folio || {}, {
    init,
    selectSheet,
    setCanvas,
  });
})();
