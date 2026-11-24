# Brief W1-D · Motor web de documentos Office + Word (.docx)

- **Rama:** `feat/motor-office-word` · **Worktree:** `../worktrees/folio-feat-motor-office-word`
- **Lee primero:** `AGENTS.md` y `docs/diseno.md` §5 "Visor".
- **Objetivo:** un anfitrión WebView genérico y sin red que renderiza documentos con motores JS empaquetados, y el primer motor: **Word (.docx)** con páginas fieles, ajustadas al ancho y con zoom.

## Contexto

- `lib/features/viewer/office/office_document_view.dart` es un marcador con la firma definitiva `OfficeDocumentView({document, controller, onTap})`: **conserva la firma**.
- Contrato: `lib/features/viewer/viewer_controller.dart` (léelo completo). La barra, el indicador de página y los mensajes de error/carga los dibuja `ViewerScreen` (otro brief): tú **no** dibujas nada de eso.
- Librerías JS ya empaquetadas (NO editar): `assets/engines/vendor/jszip.min.js` (3.10.1), `assets/engines/vendor/docx-preview.min.js` (0.4.1, global `docx`, API en `docs/agentes/ref/docx-preview.d.ts` y `docs/agentes/ref/docx-preview-README.md`). Fuentes: `assets/engines/fonts/Carlito-*.ttf` (sustituto de Calibri) y `Caladea-*.ttf` (sustituto de Cambria). Excel y PowerPoint llegarán en otra oleada reutilizando tu anfitrión (`xlsx.full.min.js`, `pptx-preview.bundle.js` ya están en `vendor/`).
- WebView: **flutter_inappwebview 6.2.0-beta.3** (`~/.pub-cache/hosted/pub.dev/flutter_inappwebview-6.2.0-beta.3/`, `flutter_inappwebview_platform_interface-1.4.0-beta.3/`, `flutter_inappwebview_android-1.2.0-beta.3/`). Usa `WebViewAssetLoader` (busca `class WebViewAssetLoader`, `AssetsPathHandler`, `InternalStoragePathHandler` en el platform_interface) para servir:
  - los assets de Flutter en `https://appassets.androidplatform.net/assets/flutter_assets/assets/engines/...`;
  - la carpeta del documento (`File(document.path).parent`, que está dentro del almacenamiento interno de la app) en `https://appassets.androidplatform.net/doc/`.
  Así el JS hace `fetch()` del documento como `ArrayBuffer` sin `file://` ni base64.
- Los documentos se ven como **papel blanco** en ambos temas; solo el fondo detrás de las páginas usa `context.folio.canvas`.

## Archivos permitidos

- `lib/features/viewer/office/office_document_view.dart`
- `lib/features/viewer/office/office_engine.dart` (**nuevo**)
- `lib/features/viewer/office/engine_message.dart` (**nuevo**)
- `assets/engines/common/bridge.js`, `assets/engines/common/base.css` (**nuevos**; puedes borrar `.gitkeep`)
- `assets/engines/docx/index.html`, `assets/engines/docx/docx-engine.js`, `assets/engines/docx/docx.css` (**nuevos**)
- `test/features/viewer/office/**` (**nuevos**)

## Qué hacer

1. `office_engine.dart`: `enum OfficeEngine { docx, xlsx, pptx }` con `static OfficeEngine? forKind(DocKind)` y `String get entryUrl` (`https://appassets.androidplatform.net/assets/flutter_assets/assets/engines/<nombre>/index.html`). Excel y PowerPoint ya mapean, aunque su HTML aún no exista.
2. `engine_message.dart`: protocolo JS → Dart, puro y probado. `sealed class EngineMessage` con `EngineReady(pageCount, sections)`, `EnginePage(page)`, `EngineTap()`, `EngineError(kind, detail)` y `static EngineMessage? parse(Object? raw)` (acepta `Map` o `String` JSON; devuelve `null` si es inválido). `kind` se mapea a `ViewerFailureKind` (`encrypted`, `corrupt`, `unsupported`, `engine`; desconocido → `engine`).
3. `assets/engines/common/bridge.js` (global `window.folio`):
   - `folio.send(obj)` → `window.flutter_inappwebview.callHandler('folio', obj)` (espera el evento `flutterInAppWebViewPlatformReady` si aún no está).
   - `folio.loadDocument(url)` → `fetch` → `ArrayBuffer`; detecta archivos cifrados (cabecera OLE `D0 CF 11 E0` en un .docx/.xlsx/.pptx = protegido con contraseña → error `encrypted`).
   - Detección de **toque simple**: `click` sin desplazamiento ni zoom, que no sea doble toque (espera 280 ms) ni un enlace → `send({type:'tap'})`.
   - Seguimiento de página con `IntersectionObserver` sobre los elementos de página → `send({type:'page', page})`.
   - `window.onerror` / `unhandledrejection` → `send({type:'error', kind:'engine', detail})`.
4. `assets/engines/common/base.css`: `@font-face` que registra Carlito con los nombres `Calibri` y `Carlito`, y Caladea con `Cambria` y `Caladea` (4 estilos cada una, rutas relativas `../fonts/…`); variable `--canvas` para el fondo; sin márgenes del navegador; selección de texto permitida.
5. `assets/engines/docx/index.html` + `docx-engine.js` + `docx.css`:
   - `<meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=5, user-scalable=yes">`; carga `../vendor/jszip.min.js`, `../vendor/docx-preview.min.js`, `../common/bridge.js`.
   - `folio.init({docUrl, canvas})` (lo llama Dart): fija `--canvas`, carga el documento y `docx.renderAsync(buffer, contenedor, null, {inWrapper: true, breakPages: true, ignoreLastRenderedPageBreak: false, renderHeaders: true, renderFooters: true, renderFootnotes: true, renderEndnotes: true, experimental: true, useBase64URL: true})`.
   - Ajuste al ancho: escala las páginas (`section.docx`) para que quepan en el ancho de la pantalla con 12 px de margen (usa `zoom` CSS o `transform` + altura compensada; recalcula al rotar). Páginas con sombra suave y 12 px de separación, fondo `var(--canvas)`.
   - Al terminar → `send({type:'ready', pageCount: <número de páginas>, sections: []})`; zip inválido → `error` `corrupt`.
   - `folio.goToPage(n)` desplaza suave a la página n.
   - Enlaces externos: no navegar.
6. `office_document_view.dart`:
   - `InAppWebView` con `initialUrlRequest` = `entryUrl`, `initialSettings`: `webViewAssetLoader` (los 2 handlers), `javaScriptEnabled`, `supportZoom: true`, `builtInZoomControls: true`, `displayZoomControls: false`, `allowFileAccess: false`, `allowContentAccess: false`, `transparentBackground: true`, `useShouldOverrideUrlLoading: true`, `cacheEnabled: false`.
   - `shouldOverrideUrlLoading`: permite solo `appassets.androidplatform.net`; cancela todo lo demás.
   - `onWebViewCreated`: `addJavaScriptHandler(handlerName: 'folio', callback: …)` → `EngineMessage.parse` → `markReady` / `setPage` / `onTap` / `fail`.
   - `onLoadStop` → `evaluateJavascript` de `folio.init({docUrl:'https://appassets.androidplatform.net/doc/<nombre de archivo codificado con Uri.encodeComponent>', canvas:'#rrggbb'})` (el color sale de `context.folio.canvas`).
   - `controller.attach(onGoToPage: (p) => webController.evaluateJavascript(source: 'folio.goToPage($p)'))`.
   - `onReceivedError` en la página principal → `fail(engine)`. Tipo sin motor (`forKind` null) → `fail(unsupported)`.
   - Fondo del widget: `context.folio.canvas`.
7. Prueba `test/features/viewer/office/engine_message_test.dart`: cada tipo de mensaje, JSON en texto, campos faltantes → `null`, `kind` desconocido → `engine`. Y `office_engine_test.dart`: `forKind` y `entryUrl`.

## Criterios de aceptación

- [ ] Firma de `OfficeDocumentView` sin cambios.
- [ ] Ninguna URL externa: `grep -rnE "https?://" assets/engines/common assets/engines/docx lib/features/viewer/office | grep -v appassets.androidplatform.net` no devuelve nada.
- [ ] `grep -rnE "TODO|FIXME|catch \(_\)" lib/features/viewer/office assets/engines/common assets/engines/docx` no devuelve nada.
- [ ] Las dos pruebas existen.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

Un .docx sencillo, uno con tablas e imágenes y uno largo (30+ páginas): fidelidad, ajuste al ancho, zoom con pellizco, salto de página, tema oscuro (fondo oscuro, páginas blancas), .docx protegido con contraseña.
