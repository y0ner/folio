(() => {
  'use strict';

  const MAX_ROWS = 20000;
  const MAX_COLS = 200;
  const BLOCK_SIZE = 100;
  const DEFAULT_COL_WIDTH_PX = 64;
  const DEFAULT_ROW_HEIGHT_PX = 20;

  let visibleSheets = [];
  let sheetStates = [];

  try {
    importScripts('../vendor/xlsx.full.min.js');
  } catch (err) {
    self.postMessage({
      type: 'error',
      kind: 'engine',
      detail:
        err && err.message
          ? `No se pudo cargar SheetJS en el worker: ${err.message}`
          : 'No se pudo cargar SheetJS en el worker',
    });
    return;
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
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

  function buildSheetState(sheetIndex) {
    if (sheetStates[sheetIndex]) {
      return sheetStates[sheetIndex];
    }

    const entry = visibleSheets[sheetIndex];
    if (!entry || !entry.sheet || !entry.sheet['!ref']) {
      const emptyState = { empty: true };
      sheetStates[sheetIndex] = emptyState;
      return emptyState;
    }

    const sheet = entry.sheet;
    const range = self.XLSX.utils.decode_range(sheet['!ref']);
    if (isEmptySheet(sheet, range)) {
      const emptyState = { empty: true };
      sheetStates[sheetIndex] = emptyState;
      return emptyState;
    }

    const totalRows = range.e.r + 1;
    const totalCols = range.e.c + 1;
    const rowCount = Math.min(totalRows, MAX_ROWS);
    const colCount = Math.min(totalCols, MAX_COLS);
    const rowHeaderWidth = rowCount >= 10000 ? 52 : rowCount >= 1000 ? 48 : 40;

    const colsMeta = sheet['!cols'] || [];
    const rowsMeta = sheet['!rows'] || [];

    const numBlocks = Math.ceil(rowCount / BLOCK_SIZE);
    const blockMinStartRow = new Int32Array(numBlocks);
    const blockMaxEndRow = new Int32Array(numBlocks);
    for (let b = 0; b < numBlocks; b += 1) {
      blockMinStartRow[b] = b * BLOCK_SIZE;
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

      // Cada bloque cubierto por la combinación registra el rango completo para
      // garantizar que al dibujar cualquiera de ellos se incluyan todos.
      const startBlock = Math.floor(startR / BLOCK_SIZE);
      const endBlock = Math.floor(endR / BLOCK_SIZE);
      for (let b = startBlock; b <= endBlock; b += 1) {
        if (startR < blockMinStartRow[b]) {
          blockMinStartRow[b] = startR;
        }
        if (endR > blockMaxEndRow[b]) {
          blockMaxEndRow[b] = endR;
        }
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
      colLetters[c] = self.XLSX.utils.encode_col(c);
      totalTableWidth += w;
    }

    const rowHeights = new Int32Array(rowCount);
    const rowTops = new Int32Array(rowCount + 1);
    for (let r = 0; r < rowCount; r += 1) {
      const h = getRowHeight(rowsMeta, r);
      rowHeights[r] = h;
      rowTops[r + 1] = rowTops[r] + h;
    }

    const state = {
      empty: false,
      sheet,
      totalRows,
      totalCols,
      rowCount,
      colCount,
      rowHeaderWidth,
      totalTableWidth,
      colWidths,
      colLetters,
      rowHeights,
      rowTops,
      totalBodyHeight: rowTops[rowCount],
      numBlocks,
      blockMinStartRow,
      blockMaxEndRow,
      mergeOrigins,
      coveredCells,
      hasMerges: rowsWithMerges.size > 0,
      rowsWithMerges,
    };

    sheetStates[sheetIndex] = state;
    return state;
  }

  function exportMeta(state) {
    if (state.empty) {
      return { empty: true };
    }
    return {
      empty: false,
      totalRows: state.totalRows,
      totalCols: state.totalCols,
      rowCount: state.rowCount,
      colCount: state.colCount,
      rowHeaderWidth: state.rowHeaderWidth,
      totalTableWidth: state.totalTableWidth,
      colWidths: state.colWidths,
      colLetters: state.colLetters,
      rowTops: state.rowTops,
      totalBodyHeight: state.totalBodyHeight,
      numBlocks: state.numBlocks,
      blockMinStartRow: state.blockMinStartRow,
      blockMaxEndRow: state.blockMaxEndRow,
    };
  }

  function renderBlockHtml(state, blockIndex) {
    const startRow = blockIndex * BLOCK_SIZE;
    const endRow = Math.min(state.rowCount, startRow + BLOCK_SIZE);
    const {
      sheet,
      colCount,
      colLetters,
      rowHeights,
      hasMerges,
      rowsWithMerges,
      coveredCells,
      mergeOrigins,
    } = state;

    const parts = [];
    for (let r = startRow; r < endRow; r += 1) {
      const rowHeight = rowHeights[r];
      const rowNum = r + 1;
      const rowMerged = hasMerges && rowsWithMerges.has(r);
      const rowBaseKey = r * colCount;
      parts.push(
        `<tr data-row="${r}" style="height:${rowHeight}px"><th class="sheet-row-header" scope="row">${rowNum}</th>`
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

  function resolveInitialBlockRange(state, viewportHeight) {
    if (state.empty || state.numBlocks === 0) {
      return [];
    }
    const vh = Math.max(Number(viewportHeight) || 0, 800);
    const rowTops = state.rowTops;
    let lastVisibleRow = state.rowCount - 1;
    for (let r = 0; r < state.rowCount; r += 1) {
      if (rowTops[r + 1] >= vh) {
        lastVisibleRow = r;
        break;
      }
    }
    const desiredLastRow = Math.min(state.rowCount - 1, lastVisibleRow + 50);
    let eb = Math.floor(desiredLastRow / BLOCK_SIZE);
    let sb = 0;
    let changed = true;
    while (changed) {
      changed = false;
      for (let b = sb; b <= eb; b += 1) {
        const neededEb = Math.floor(state.blockMaxEndRow[b] / BLOCK_SIZE);
        if (neededEb > eb) {
          eb = neededEb;
          changed = true;
        }
      }
    }

    const indices = [];
    for (let b = sb; b <= eb; b += 1) {
      indices.push(b);
    }
    return indices;
  }

  function buildBlocksPayload(state, blockIndices) {
    const blocks = [];
    for (let i = 0; i < blockIndices.length; i += 1) {
      const b = blockIndices[i];
      if (b < 0 || b >= state.numBlocks) continue;
      blocks.push({
        blockIndex: b,
        html: renderBlockHtml(state, b),
      });
    }
    return blocks;
  }

  self.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || !msg.type) return;

    if (msg.type === 'load') {
      try {
        if (!self.XLSX || typeof self.XLSX.read !== 'function') {
          throw new Error('SheetJS no está disponible');
        }

        const readOptions = {
          cellStyles: true,
          cellDates: true,
          cellNF: true,
          sheetStubs: true,
        };

        const workbook = msg.isCsv
          ? self.XLSX.read(
              decodeCsvText(msg.buffer),
              Object.assign({ type: 'string' }, readOptions)
            )
          : self.XLSX.read(
              new Uint8Array(msg.buffer),
              Object.assign({ type: 'array' }, readOptions)
            );

        if (
          !workbook ||
          !Array.isArray(workbook.SheetNames) ||
          workbook.SheetNames.length === 0
        ) {
          self.postMessage({
            type: 'error',
            kind: 'corrupt',
            detail: 'El libro no contiene hojas',
          });
          return;
        }

        visibleSheets = extractVisibleSheets(workbook);
        sheetStates = new Array(visibleSheets.length);
        const sections = visibleSheets.map((item) => item.name);

        if (visibleSheets.length === 0) {
          self.postMessage({
            type: 'loaded',
            sections,
            initialSheet: null,
            initialBlocks: [],
          });
          return;
        }

        const state0 = buildSheetState(0);
        const blockIndices = resolveInitialBlockRange(state0, msg.viewportHeight);
        const initialBlocks = state0.empty
          ? []
          : buildBlocksPayload(state0, blockIndices);

        self.postMessage({
          type: 'loaded',
          sections,
          initialSheet: exportMeta(state0),
          initialBlocks,
        });
      } catch (err) {
        const detail = err && err.message ? err.message : String(err);
        const kind = isEncryptedError(err) ? 'encrypted' : 'corrupt';
        self.postMessage({ type: 'error', kind, detail });
      }
      return;
    }

    if (msg.type === 'getSheet') {
      try {
        const index = Number(msg.sheetIndex);
        if (!Number.isInteger(index) || index < 0 || index >= visibleSheets.length) {
          return;
        }
        const state = buildSheetState(index);
        const blockIndices = resolveInitialBlockRange(state, msg.viewportHeight);
        const initialBlocks = state.empty
          ? []
          : buildBlocksPayload(state, blockIndices);
        self.postMessage({
          type: 'sheet',
          requestId: msg.requestId,
          sheetIndex: index,
          meta: exportMeta(state),
          initialBlocks,
        });
      } catch (err) {
        const detail = err && err.message ? err.message : String(err);
        self.postMessage({ type: 'error', kind: 'engine', detail });
      }
      return;
    }

    if (msg.type === 'getBlocks') {
      try {
        const index = Number(msg.sheetIndex);
        if (!Number.isInteger(index) || index < 0 || index >= visibleSheets.length) {
          return;
        }
        const state = buildSheetState(index);
        const blocks = state.empty
          ? []
          : buildBlocksPayload(state, msg.blockIndices || []);
        self.postMessage({
          type: 'blocks',
          requestId: msg.requestId,
          sheetIndex: index,
          blocks,
        });
      } catch (err) {
        const detail = err && err.message ? err.message : String(err);
        self.postMessage({ type: 'error', kind: 'engine', detail });
      }
    }
  });
})();
