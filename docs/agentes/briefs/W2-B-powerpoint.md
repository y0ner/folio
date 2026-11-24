# Brief W2-B · Motor PowerPoint (.pptx, .ppsx)

- **Rama:** `feat/motor-powerpoint` · **Worktree:** `../worktrees/folio-feat-motor-powerpoint` · **Base:** `integracion/oleada-1`
- **Lee primero:** `AGENTS.md`, `docs/diseno.md` §5 "Visor".
- **Objetivo:** ver presentaciones como una lista vertical de diapositivas ajustadas al ancho, con el indicador "3 / 24" y salto a diapositiva.

## Contexto

- Anfitrión ya hecho (NO editar): `lib/features/viewer/office/office_document_view.dart` abre `…/assets/engines/pptx/index.html`, llama `folio.init({docUrl, canvas})`, traduce mensajes (`ready`, `page`, `tap`, `error`) y llama `folio.goToPage(n)`.
- Puente común (NO editar): `assets/engines/common/bridge.js` → `folio.send`, `folio.loadDocument(url)` (detecta cifrado OLE), `folio.observePages(elements)` (envía `page` al cambiar la diapositiva visible), toque simple. `assets/engines/common/base.css` (fuentes Calibri→Carlito, Arial→Liberation Sans, `--canvas`).
- Guíate por el motor Word ya hecho: `assets/engines/docx/index.html`, `docx-engine.js` (ajuste al ancho con `transform: scale` y contenedores compensados), `docx.css`.
- Librerías (NO editar): `assets/engines/vendor/pptx-preview.bundle.js` → global `window.pptxPreview.init(dom, {width, height, mode: 'list'})` devuelve un previewer con `preview(arrayBuffer)` y `slideCount`. Tipos en `docs/agentes/ref/pptx-preview/`. `assets/engines/vendor/jszip.min.js` (global `JSZip`) para leer `ppt/presentation.xml` → `<p:sldSz cx cy>` (EMU; 914 400 EMU = 96 px) y así conocer la proporción real (16:9, 4:3…).

## Archivos permitidos

- `assets/engines/pptx/index.html`, `assets/engines/pptx/pptx-engine.js`, `assets/engines/pptx/pptx.css` (**nuevos**; borra `assets/engines/pptx/.gitkeep`)

## Qué hacer

1. `index.html`: viewport como el de Word; carga `../common/base.css`, `pptx.css`, `../vendor/jszip.min.js`, `../vendor/pptx-preview.bundle.js`, `../common/bridge.js`, `pptx-engine.js`. Sin URLs externas.
2. `folio.init({docUrl, canvas})`: fija `--canvas`; carga el buffer; lee `sldSz` con JSZip (si falla, asume 16:9); calcula `width = anchoPantalla − 24` y `height = width * cy / cx`; `pptxPreview.init(contenedor, {width, height, mode: 'list'})` y `await previewer.preview(buffer)`.
3. Inspecciona el DOM que genera la librería (en `list` dibuja todas las diapositivas): identifica el elemento de cada diapositiva, quítale/oculta los controles propios de la librería (botones, paginación) con CSS, separa las diapositivas 12 px, fondo `var(--canvas)`, cada diapositiva con radio 4 px y sombra suave.
4. Si la diapositiva generada no coincide con el ancho de pantalla (p. ej. la librería fija tamaños), ajústala con `transform: scale` y un contenedor de alto compensado, como en Word. Recalcula al rotar.
5. `folio.observePages(diapositivas)`; envía `{type:'ready', pageCount: slideCount, sections: []}`.
6. `folio.goToPage(n)`: desplazamiento suave a la diapositiva n.
7. Errores: zip inválido o la librería falla → `{type:'error', kind:'corrupt', detail}`.
8. Rendimiento: si la presentación tiene más de 60 diapositivas, que el primer `ready` llegue cuando ya se ven las primeras (no bloquees con trabajo síncrono enorme; si la librería lo hace todo junto, acéptalo pero mide y reporta el tiempo en tu respuesta).

## Criterios de aceptación

- [ ] `grep -rnE "https?://" assets/engines/pptx` no devuelve nada.
- [ ] `grep -rnE "TODO|FIXME|catch \(_\)" assets/engines/pptx` no devuelve nada.
- [ ] `node -e "new Function(require('fs').readFileSync('assets/engines/pptx/pptx-engine.js','utf8'))"` sin error.
- [ ] `git diff --stat integracion/oleada-1` solo muestra `assets/engines/pptx/`.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

Una presentación 16:9 con imágenes y tablas, una 4:3, una con 80 diapositivas; indicador "x / N", ir a diapositiva, zoom, tema oscuro.
