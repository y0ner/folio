(() => {
  'use strict';

  const MAX_ROWS = 20000;
  const MAX_COLS = 200;
  const BLOCK_SIZE = 100;
  const DEFAULT_COL_WIDTH_PX = 64;
  const DEFAULT_ROW_HEIGHT_PX = 20;
  const INTERSECTION_ROOT_MARGIN = '800px';

  const container = document.getElementById('viewer');
  let visibleSheets = [];
  let blockObserver = null;
  let pendingCatchUpFrame = null;
  let renderGeneration = 0;

  function cleanupVirtualization() {
    renderGeneration += 1;
    if (blockObserver) {
      blockObserver.disconnect();
      blockObserver = null;
    }
    if (pendingCatchUpFrame !== null) {
      cancelAnimationFrame(pendingCatchUpFrame);
      pendingCatchUpFrame = null;
    }
  }

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

  function formatUtcDate(date) {
    const year = date.getUTCFullYear();
    const month = String(date.getUTCMonth() + 1).padStart(2, '0');
    const day = String(date.getUTCDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  function getCellText(cell) {
    if (!cell || cell.t === 'z') return '';
    if (cell.w !== undefined && cell.w !== null) return String(cell.w);
    if (cell.v === undefined || cell.v === null) return '';
    if (cell.t === 'd' && cell.v instanceof Date) {
      return formatUtcDate(cell.v);
    }
    return String(cell.v);
  }

  function normalizeRgb(raw) {
    if (typeof raw !== 'string') return null;
    const hex = raw.trim().replace(/^#/, '');
    if (/^[0-9a-fA-F]{6}$/.test(hex)) {
      return `#${hex}`;
    }
    if (/^[0-9a-fA-F]{8}$/.test(hex)) {
      const alpha = hex.slice(0, 2).toUpperCase();
      if (alpha === '00') return null;
      if (alpha === 'FF') return `#${hex.slice(2)}`;
      return `#${hex.slice(2)}${alpha}`;
    }
    return null;
  }

  function resolveAlignmentClass(cell) {
    const horizontal =
      cell &&
      cell.s &&
      cell.s.alignment &&
      typeof cell.s.alignment.horizontal === 'string'
        ? cell.s.alignment.horizontal.toLowerCase()
        : '';

    if (horizontal === 'center' || horizontal === 'centercontinuous') {
      return 'align-center';
    }
    if (horizontal === 'right') {
      return 'align-right';
    }
    if (horizontal === 'left') {
      return 'align-left';
    }

    if (cell && (cell.t === 'n' || cell.t === 'd')) {
      return 'align-right';
    }
    if (cell && (cell.t === 'b' || cell.t === 'e')) {
      return 'align-center';
    }
    return 'align-left';
  }

  function buildCellInlineStyle(cell) {
    if (!cell || !cell.s || typeof cell.s !== 'object') return '';
    const s = cell.s;
    const parts = [];

    const font = s.font;
    if (font && typeof font === 'object') {
      if (font.bold) {
        parts.push('font-weight:700');
      }
      if (font.italic) {
        parts.push('font-style:italic');
      }
      if (font.color && font.color.rgb) {
        const fontColor = normalizeRgb(font.color.rgb);
        if (fontColor) {
          parts.push(`color:${fontColor}`);
        }
      }
    }

    const fill = s.fill && typeof s.fill === 'object' ? s.fill : s;
    const patternType = fill.patternType || s.patternType;
    if (patternType !== 'none') {
      const fgColor = fill.fgColor || s.fgColor;
      if (fgColor && fgColor.rgb) {
        const bgColor = normalizeRgb(fgColor.rgb);
        if (bgColor) {
          parts.push(`background-color:${bgColor}`);
        }
      }
    }

    if (
      s.alignment &&
      typeof s.alignment.horizontal === 'string' &&
      s.alignment.horizontal.toLowerCase() === 'justify'
    ) {
      parts.push('text-align:justify');
    }

    return parts.length > 0 ? parts.join(';') : '';
  }

  function getColumnWidth(cols, index) {
    const col = cols && cols[index];
    if (!col) return DEFAULT_COL_WIDTH_PX;
    if (typeof col.wpx === 'number' && col.wpx > 0) {
      return Math.round(col.wpx);
    }
    if (typeof col.wch === 'number' && col.wch > 0) {
      return Math.round(col.wch * 7 + 5);
    }
    return DEFAULT_COL_WIDTH_PX;
  }

  function getRowHeight(rows, index) {
    const row = rows && rows[index];
    if (!row) return DEFAULT_ROW_HEIGHT_PX;
    if (typeof row.hpx === 'number' && row.hpx > 0) {
      return Math.round(row.hpx);
    }
    if (typeof row.hpt === 'number' && row.hpt > 0) {
      return Math.round((row.hpt * 96) / 72);
    }
    return DEFAULT_ROW_HEIGHT_PX;
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
    return `<tr><td class="sheet-truncation-cell" colspan="${colCount + 1}"><div class="sheet-truncation-text">${escapeHtml(notice)}</div></td></tr>`;
  }

  function isEmptySheet(sheet, range) {
    if (!sheet || !range) return true;
    if (range.e.r < 0 || range.e.c < 0) return true;
    if (range.e.r === 0 && range.e.c === 0) {
      const a1 = sheet.A1;
      const hasMerges =
        Array.isArray(sheet['!merges']) && sheet['!merges'].length > 0;
      if (!hasMerges && getCellText(a1) === '' && buildCellInlineStyle(a1) === '') {
        return true;
      }
    }
    return false;
  }

  function renderEmptyState() {
    cleanupVirtualization();
    container.innerHTML =
      '<div class="sheet-paper sheet-paper--empty"><p class="sheet-empty-message">Esta hoja está vacía</p></div>';
  }

  function renderSheet(index) {
    cleanupVirtualization();

    const entry = visibleSheets[index];
    if (!entry || !entry.sheet || !entry.sheet['!ref']) {
      renderEmptyState();
      return;
    }

    const sheet = entry.sheet;
    const range = window.XLSX.utils.decode_range(sheet['!ref']);
    if (isEmptySheet(sheet, range)) {
      renderEmptyState();
      return;
    }

    const totalRows = range.e.r + 1;
    const totalCols = range.e.c + 1;
    const rowCount = Math.min(totalRows, MAX_ROWS);
    const colCount = Math.min(totalCols, MAX_COLS);
    const rowHeaderWidth = rowCount >= 10000 ? 52 : rowCount >= 1000 ? 48 : 40;

    const colsMeta = sheet['!cols'] || [];
    const rowsMeta = sheet['!rows'] || [];

    const numBlocks = Math.ceil(rowCount / BLOCK_SIZE);
    const blockMaxEndRow = new Int32Array(numBlocks);
    for (let b = 0; b < numBlocks; b += 1) {
      blockMaxEndRow[b] = Math.min(rowCount, (b + 1) * BLOCK_SIZE) - 1;
    }

    const mergeOrigins = new Map();
    const coveredCells = new Set();
    const rowsWithMerges = new Set();
    const merges = sheet['!merges'] || [];
    for (let i = 0; i < merges.length; i += 1) {
      const m = merges[i];
      if (!m || !m.s || !m.e) continue;
      if (m.s.r >= rowCount || m.s.c >= colCount) continue;
      const startR = Math.max(0, m.s.r);
      const startC = Math.max(0, m.s.c);
      const endR = Math.min(m.e.r, rowCount - 1);
      const endC = Math.min(m.e.c, colCount - 1);
      const rowspan = endR - startR + 1;
      const colspan = endC - startC + 1;
      if (rowspan <= 1 && colspan <= 1) continue;

      const originKey = startR * colCount + startC;
      if (coveredCells.has(originKey)) continue;

      mergeOrigins.set(originKey, { rowspan, colspan });
      const startBlock = Math.floor(startR / BLOCK_SIZE);
      if (endR > blockMaxEndRow[startBlock]) {
        blockMaxEndRow[startBlock] = endR;
      }

      for (let r = startR; r <= endR; r += 1) {
        rowsWithMerges.add(r);
        for (let c = startC; c <= endC; c += 1) {
          if (r === startR && c === startC) continue;
          coveredCells.add(r * colCount + c);
        }
      }
    }

    let totalTableWidth = rowHeaderWidth;
    const colWidths = new Array(colCount);
    const colLetters = new Array(colCount);
    for (let c = 0; c < colCount; c += 1) {
      const w = getColumnWidth(colsMeta, c);
      colWidths[c] = w;
      colLetters[c] = window.XLSX.utils.encode_col(c);
      totalTableWidth += w;
    }

    const rowHeights = new Int32Array(rowCount);
    const rowTops = new Int32Array(rowCount + 1);
    for (let r = 0; r < rowCount; r += 1) {
      const h = getRowHeight(rowsMeta, r);
      rowHeights[r] = h;
      rowTops[r + 1] = rowTops[r] + h;
    }
    const totalBodyHeight = rowTops[rowCount];

    function resolveEndRow(fromRow, desiredEndRow) {
      let endRow = Math.min(rowCount, desiredEndRow);
      let b = Math.floor(fromRow / BLOCK_SIZE);
      while (b * BLOCK_SIZE < endRow) {
        const maxEnd = blockMaxEndRow[b];
        if (maxEnd >= endRow) {
          const neededBlock = Math.floor(maxEnd / BLOCK_SIZE);
          endRow = Math.min(rowCount, (neededBlock + 1) * BLOCK_SIZE);
        }
        b += 1;
      }
      return endRow;
    }

    const hasMerges = rowsWithMerges.size > 0;
    function renderRowsHtml(startRow, endRow) {
      const parts = [];
      for (let r = startRow; r < endRow; r += 1) {
        const rowHeight = rowHeights[r];
        const rowNum = r + 1;
        const rowMerged = hasMerges && rowsWithMerges.has(r);
        const rowBaseKey = r * colCount;
        parts.push(
          `<tr style="height:${rowHeight}px"><th class="sheet-row-header" scope="row">${rowNum}</th>`
        );

        for (let c = 0; c < colCount; c += 1) {
          let merge = null;
          if (rowMerged) {
            const key = rowBaseKey + c;
            if (coveredCells.has(key)) continue;
            merge = mergeOrigins.get(key);
          }

          const cell = sheet[colLetters[c] + rowNum];
          const alignClass = resolveAlignmentClass(cell);
          const inlineStyle = buildCellInlineStyle(cell);
          const text = getCellText(cell);

          parts.push(`<td class="${alignClass}"`);
          if (merge) {
            if (merge.colspan > 1) parts.push(` colspan="${merge.colspan}"`);
            if (merge.rowspan > 1) parts.push(` rowspan="${merge.rowspan}"`);
          }
          if (inlineStyle) {
            parts.push(` style="${inlineStyle}"`);
          }
          parts.push('>');
          if (text) {
            parts.push(escapeHtml(text));
          }
          parts.push('</td>');
        }

        parts.push('</tr>');
      }
      return parts.join('');
    }

    const viewportHeight = Math.max(
      window.innerHeight ||
        (document.documentElement ? document.documentElement.clientHeight : 0) ||
        0,
      800
    );
    let firstOutsideRow = rowCount;
    for (let r = 0; r < rowCount; r += 1) {
      if (rowTops[r + 1] >= viewportHeight) {
        firstOutsideRow = r;
        break;
      }
    }
    const lastVisibleBlock = Math.floor(
      Math.min(firstOutsideRow, rowCount - 1) / BLOCK_SIZE
    );
    const initialTargetBlock = Math.min(numBlocks - 1, lastVisibleBlock + 1);
    const initialDesiredEndRow = Math.min(
      rowCount,
      (initialTargetBlock + 1) * BLOCK_SIZE
    );
    let renderedRows = resolveEndRow(0, initialDesiredEndRow);

    const notice = buildTruncationMessage(totalRows, totalCols);
    const remainingHeight = totalBodyHeight - rowTops[renderedRows];

    const html = [];
    html.push('<div class="sheet-paper">');
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
    html.push(renderRowsHtml(0, renderedRows));
    if (renderedRows < rowCount) {
      html.push(
        `<tr class="sheet-spacer-row" aria-hidden="true" style="height:${remainingHeight}px"><td class="sheet-spacer-cell" colspan="${colCount + 1}" style="height:${remainingHeight}px"></td></tr>`
      );
    } else if (notice) {
      html.push(buildTruncationRowHtml(colCount, notice));
    }
    html.push('</tbody></table></div>');
    container.innerHTML = html.join('');

    if (renderedRows >= rowCount) {
      return;
    }

    const currentGen = renderGeneration;
    const spacerRow = container.querySelector('tr.sheet-spacer-row');
    const spacerCell = spacerRow
      ? spacerRow.querySelector('td.sheet-spacer-cell')
      : null;
    if (!spacerRow || !spacerCell) {
      return;
    }

    function appendNextBlock() {
      if (currentGen !== renderGeneration || renderedRows >= rowCount) {
        return false;
      }
      const nextBlockEnd = Math.min(rowCount, renderedRows + BLOCK_SIZE);
      const targetEnd = resolveEndRow(renderedRows, nextBlockEnd);
      const chunkHtml = renderRowsHtml(renderedRows, targetEnd);
      spacerRow.insertAdjacentHTML('beforebegin', chunkHtml);
      renderedRows = targetEnd;

      if (renderedRows >= rowCount) {
        if (notice) {
          spacerRow.insertAdjacentHTML(
            'beforebegin',
            buildTruncationRowHtml(colCount, notice)
          );
        }
        cleanupVirtualization();
        spacerRow.remove();
        return false;
      }

      const nextRemaining = totalBodyHeight - rowTops[renderedRows];
      spacerRow.style.height = `${nextRemaining}px`;
      spacerCell.style.height = `${nextRemaining}px`;
      return true;
    }

    function isSpacerNearViewport() {
      const rect = spacerCell.getBoundingClientRect();
      const vh =
        window.innerHeight ||
        (document.documentElement ? document.documentElement.clientHeight : 0) ||
        800;
      return rect.top <= vh + 800 && rect.bottom >= -800;
    }

    function scheduleCatchUp() {
      if (pendingCatchUpFrame !== null || currentGen !== renderGeneration) {
        return;
      }
      pendingCatchUpFrame = requestAnimationFrame(() => {
        pendingCatchUpFrame = null;
        if (currentGen !== renderGeneration || renderedRows >= rowCount) {
          return;
        }
        const vh =
          window.innerHeight ||
          (document.documentElement ? document.documentElement.clientHeight : 0) ||
          800;
        const rect = spacerCell.getBoundingClientRect();
        let top = rect.top;
        const bottom = rect.bottom;
        const deadline = performance.now() + 8;
        let hasMore = true;

        while (hasMore && top <= vh + 800 && bottom >= -800) {
          const prevRows = renderedRows;
          hasMore = appendNextBlock();
          top += rowTops[renderedRows] - rowTops[prevRows];
          if (performance.now() >= deadline) {
            break;
          }
        }
        if (hasMore && top <= vh + 800 && bottom >= -800) {
          scheduleCatchUp();
        }
      });
    }

    if (typeof IntersectionObserver === 'function') {
      blockObserver = new IntersectionObserver(
        (entries) => {
          if (currentGen !== renderGeneration) return;
          let intersecting = false;
          for (let i = 0; i < entries.length; i += 1) {
            if (entries[i].isIntersecting) {
              intersecting = true;
              break;
            }
          }
          if (!intersecting) return;

          const hasMore = appendNextBlock();
          if (hasMore && isSpacerNearViewport()) {
            scheduleCatchUp();
          }
        },
        { root: null, rootMargin: INTERSECTION_ROOT_MARGIN }
      );
      blockObserver.observe(spacerCell);
    } else {
      scheduleCatchUp();
    }
  }

  function decodeCsvText(buffer) {
    const bytes = new Uint8Array(buffer);
    try {
      return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
    } catch (err) {
      console.warn(
        'CSV no válido como UTF-8, usando windows-1252:',
        err && err.message ? err.message : err
      );
      return new TextDecoder('windows-1252').decode(bytes);
    }
  }

  function extractVisibleSheets(workbook) {
    const names = Array.isArray(workbook.SheetNames) ? workbook.SheetNames : [];
    const sheetsMeta =
      workbook.Workbook && Array.isArray(workbook.Workbook.Sheets)
        ? workbook.Workbook.Sheets
        : [];
    const result = [];

    for (let i = 0; i < names.length; i += 1) {
      const meta = sheetsMeta[i];
      const hidden = meta ? meta.Hidden : 0;
      if (hidden === 1 || hidden === 2 || hidden === '1' || hidden === '2') {
        continue;
      }
      const name = names[i];
      result.push({
        name,
        sheet: workbook.Sheets ? workbook.Sheets[name] : null,
      });
    }

    return result;
  }

  function isEncryptedError(err) {
    const message = err && err.message ? String(err.message) : String(err || '');
    const lower = message.toLowerCase();
    return lower.includes('password') || lower.includes('encrypt');
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

    cleanupVirtualization();
    container.innerHTML = '';
    visibleSheets = [];

    let buffer;
    try {
      buffer = await window.folio.loadDocument(options.docUrl, {
        allowOle: true,
      });
    } catch (err) {
      if (err && err.folioReported) return;
      const kind = err && err.folioKind ? err.folioKind : 'engine';
      const detail = err && err.message ? err.message : String(err);
      window.folio.send({ type: 'error', kind, detail });
      return;
    }

    try {
      if (!window.XLSX || typeof window.XLSX.read !== 'function') {
        throw new Error('SheetJS no está disponible');
      }

      const isCsv = /\.csv(?:[?#]|$)/i.test(options.docUrl);
      const readOptions = {
        cellStyles: true,
        cellDates: true,
        cellNF: true,
        sheetStubs: true,
      };

      const workbook = isCsv
        ? window.XLSX.read(
            decodeCsvText(buffer),
            Object.assign({ type: 'string' }, readOptions)
          )
        : window.XLSX.read(
            new Uint8Array(buffer),
            Object.assign({ type: 'array' }, readOptions)
          );

      if (
        !workbook ||
        !Array.isArray(workbook.SheetNames) ||
        workbook.SheetNames.length === 0
      ) {
        window.folio.send({
          type: 'error',
          kind: 'corrupt',
          detail: 'El libro no contiene hojas',
        });
        return;
      }

      visibleSheets = extractVisibleSheets(workbook);
      const sectionNames = visibleSheets.map((item) => item.name);

      if (document.fonts && document.fonts.ready) {
        await document.fonts.ready;
      }

      if (visibleSheets.length > 0) {
        renderSheet(0);
      } else {
        renderEmptyState();
      }

      window.folio.send({
        type: 'ready',
        pageCount: 0,
        sections: sectionNames,
      });
    } catch (err) {
      const detail = err && err.message ? err.message : String(err);
      const kind = isEncryptedError(err) ? 'encrypted' : 'corrupt';
      window.folio.send({ type: 'error', kind, detail });
    }
  }

  function selectSheet(i) {
    const index = Number(i);
    if (!Number.isInteger(index) || index < 0 || index >= visibleSheets.length) {
      return;
    }
    renderSheet(index);
    window.scrollTo(0, 0);
    if (document.documentElement) {
      document.documentElement.scrollLeft = 0;
      document.documentElement.scrollTop = 0;
    }
    if (document.body) {
      document.body.scrollLeft = 0;
      document.body.scrollTop = 0;
    }
    if (container) {
      container.scrollLeft = 0;
      container.scrollTop = 0;
    }
  }

  window.folio = Object.assign(window.folio || {}, {
    init,
    selectSheet,
    setCanvas,
  });
})();
