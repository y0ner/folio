# Brief W2-A · Motor Excel (.xlsx, .xls, .csv) con pestañas de hojas

- **Rama:** `feat/motor-excel` · **Worktree:** `../worktrees/folio-feat-motor-excel` · **Base:** `integracion/oleada-1`
- **Lee primero:** `AGENTS.md`, `docs/diseno.md` §5 "Visor" (Excel: pestañas abajo).
- **Objetivo:** ver hojas de cálculo con aspecto de Excel (cuadrícula, encabezados de filas y columnas fijos, anchos, combinaciones y formato de números) y cambiar de hoja con la barra nativa de pestañas.

## Contexto

- Anfitrión ya hecho: `lib/features/viewer/office/office_document_view.dart` abre `OfficeEngine.xlsx.entryUrl` (`…/assets/engines/xlsx/index.html`), llama `folio.init({docUrl, canvas})` y traduce los mensajes con `EngineMessage.parse` (`lib/features/viewer/office/engine_message.dart`). Hoy **no** registra `onSelectSection`.
- Puente común (NO editar): `assets/engines/common/bridge.js` → `window.folio.send(obj)`, `folio.loadDocument(url, {allowOle: true})` (usa `allowOle: true`: los `.xls` antiguos son OLE legítimos), `folio.observePages(elements)`, detección de toque simple. `assets/engines/common/base.css` (fuentes Calibri→Carlito, Arial→Liberation Sans, `--canvas`).
- Guíate por el motor Word ya hecho: `assets/engines/docx/index.html`, `docx-engine.js`, `docx.css`.
- Librería (NO editar): `assets/engines/vendor/xlsx.full.min.js` = **SheetJS CE 0.20.3** (global `XLSX`). Usa `XLSX.read(buffer, {type:'array', cellStyles:true, cellDates:true, cellNF:true, sheetStubs:true})`, `sheet['!ref']`, `XLSX.utils.decode_range`, `encode_cell`, `cell.w` (texto ya formateado), `cell.t`, `sheet['!merges']`, `sheet['!cols']` (`wpx`/`wch`), `sheet['!rows']` (`hpx`), `workbook.Workbook.Sheets[i].Hidden`, `cell.s` (estilo, puede faltar). La barra de hojas la dibuja la pantalla del visor (`SectionBar`), **no** el HTML.

## Archivos permitidos

- `assets/engines/xlsx/index.html`, `assets/engines/xlsx/xlsx-engine.js`, `assets/engines/xlsx/xlsx.css` (**nuevos**; borra `assets/engines/xlsx/.gitkeep`)
- `lib/features/viewer/office/office_document_view.dart` (**solo** para registrar `onSelectSection` en `controller.attach` → `folio.selectSheet(i)`)
- `test/features/viewer/office/**` (si agregas pruebas Dart)

## Qué hacer

1. `index.html`: viewport `width=device-width, initial-scale=1, minimum-scale=0.25, maximum-scale=4, user-scalable=yes`; carga `../common/base.css`, `xlsx.css`, `../vendor/xlsx.full.min.js`, `../common/bridge.js`, `xlsx-engine.js`. Sin URLs externas.
2. `folio.init({docUrl, canvas})`: fija `--canvas`, carga con `allowOle: true`, `XLSX.read`. Hojas visibles (omite `Hidden` 1 y 2). Envía `{type:'ready', pageCount: 0, sections: [nombres visibles]}` y muestra la primera.
3. Render de una hoja (`renderSheet(i)`), como **tabla HTML** sobre papel blanco:
   - Esquina + fila de letras de columna (A, B, …, AA) **fija arriba** y columna de números **fija a la izquierda** (`position: sticky`), fondo gris muy claro `#F3F3F1`, texto `#6B6B6B`, Inter/sistema 11 px, bordes `#E1E1DE`.
   - Celdas: borde de cuadrícula 1 px `#E6E6E3`; texto `cell.w` (o `String(cell.v)`); números y fechas alineados a la derecha, texto a la izquierda, booleanos centrados; `white-space: nowrap; overflow: hidden; text-overflow: clip` como Excel; fuente por defecto Calibri 11 pt (→ Carlito).
   - Anchos de columna de `!cols` (`wpx`, o `wch * 7 + 5`; por defecto 64 px) y altos de fila de `!rows` (`hpx`; por defecto 20 px).
   - Combinaciones `!merges` con `colspan`/`rowspan` (y omite las celdas cubiertas).
   - Estilos si `cell.s` los trae: negrita, cursiva, color de fuente, relleno sólido (`fgColor.rgb`), alineación horizontal. Si no hay estilo, no inventes.
   - Límite: si la hoja pasa de 3 000 filas o 200 columnas, dibuja solo ese rango y agrega al final una fila de aviso en español: "Se muestran las primeras 3 000 filas de N.".
   - Hoja vacía: texto centrado "Esta hoja está vacía".
4. Desplazamiento en ambos ejes dentro de la página (el contenedor ocupa toda la pantalla); fondo `var(--canvas)` alrededor del papel; margen 12 px; el papel lleva una sombra suave como en Word.
5. `folio.selectSheet(i)`: renderiza la hoja `i` (de la lista visible) y vuelve arriba a la izquierda.
6. `.csv`: `XLSX.read` también lo abre; una sola hoja → `sections` con un solo nombre (la pantalla oculta la barra si hay ≤ 1).
7. Errores: `XLSX.read` falla → `{type:'error', kind:'corrupt', detail}`; libro cifrado (SheetJS lanza error con "password"/"encrypt") → `kind:'encrypted'`.
8. Dart (`office_document_view.dart`): en `controller.attach(...)` agrega `onSelectSection: (i) => _webController?.evaluateJavascript(source: 'window.folio && folio.selectSheet($i)')`. Nada más en ese archivo.
9. Prueba manual del jefe: el jefe abrirá `index.html` en Chrome sin interfaz con un `.xlsx` real; asegúrate de que todo funcione sin `flutter_inappwebview` presente (el puente ya encola los mensajes).

## Criterios de aceptación

- [ ] `grep -rnE "https?://" assets/engines/xlsx` no devuelve nada.
- [ ] `grep -rnE "TODO|FIXME|catch \(_\)" assets/engines/xlsx lib/features/viewer/office` no devuelve nada.
- [ ] `git diff integracion/oleada-1 -- lib/features/viewer/office/office_document_view.dart` solo agrega `onSelectSection`.
- [ ] `node -e "new Function(require('fs').readFileSync('assets/engines/xlsx/xlsx-engine.js','utf8'))"` no da error de sintaxis.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

Un .xlsx con varias hojas, celdas combinadas, colores y fechas; un .xls antiguo; un .csv; una hoja de 10 000 filas; cambio de hojas con la barra inferior; zoom con pellizco; tema oscuro.
