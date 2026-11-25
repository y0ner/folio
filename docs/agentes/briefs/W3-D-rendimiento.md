# Brief W3-D · Rendimiento: Excel virtualizado y WebView precalentado

- **Rama:** `feat/rendimiento` · **Worktree:** `~/Desktop/Projects/worktrees/folio-feat-rendimiento` · **Base:** `fix/visor-inicio`
- **Lee primero:** `AGENTS.md`.
- **Objetivo:** abrir hojas grandes sin trabarse y que el primer Word/Excel/PowerPoint abra más rápido.

## Mediciones del jefe

- Una hoja de 3 000 filas × 24 columnas crea **72 000 `<td>`** de una vez (`assets/engines/xlsx/xlsx-engine.js`, `renderSheet`). En un celular eso cuesta segundos de maquetado y mucha memoria, y el límite actual de 3 000 filas corta hojas reales.
- El primer `InAppWebView` del proceso inicializa Chromium (cientos de ms) justo cuando el usuario abre su primer documento Office.

## Archivos permitidos

- `assets/engines/xlsx/xlsx-engine.js`, `assets/engines/xlsx/xlsx.css`
- `lib/features/viewer/office/webview_prewarm.dart` (**nuevo**)
- `lib/main.dart` (solo para llamar al precalentado)
- `test/features/viewer/office/**`

## Qué hacer

1. **Excel virtualizado** (mismo aspecto que hoy: encabezados fijos, anchos, combinaciones, estilos):
   - Calcula los altos de fila (de `!rows` o 20 px) y arma la tabla con **bloques de 100 filas**: al inicio dibuja solo los bloques visibles + 1 de margen; un espaciador (`<tr>` con alto total restante) mantiene la barra de desplazamiento real; al acercarse al final (IntersectionObserver sobre un centinela, `rootMargin: '800px'`) agrega el siguiente bloque. No es necesario quitar bloques ya dibujados.
   - Combinaciones (`!merges`) que crucen el borde de un bloque: dibuja el bloque que contiene la celda de inicio completo con su `rowspan` (si la combinación se extiende a un bloque aún no dibujado, dibuja también ese bloque).
   - Sube el límite a **20 000 filas** y 200 columnas (con el mismo aviso al final si se recorta).
   - `selectSheet(i)` sigue funcionando (resetea bloques).
   - La hoja debe aparecer (primer bloque pintado + `ready`) en < 300 ms para una hoja de 20 000 × 24 en Chrome de escritorio; mide con `performance.now()` y repórtalo en tu respuesta (puedes abrir `index.html` con Node/Chrome si tu entorno lo permite; si no, explica cómo lo verificaste).
2. **WebView precalentado** (`webview_prewarm.dart`): `Future<void> prewarmWebView()` que, **solo en Android** y una sola vez por proceso, crea un `HeadlessInAppWebView` con `initialData: InAppWebViewInitialData(data: '<html></html>')`, lo ejecuta (`run()`), espera `onLoadStop` (máx. 3 s) y lo libera (`dispose()`). Errores → `debugPrint`, nunca lanzan. API en `~/.pub-cache/hosted/pub.dev/flutter_inappwebview-6.2.0-beta.3/`.
3. `main.dart`: tras `runApp`, en `WidgetsBinding.instance.addPostFrameCallback`, espera 1,5 s (que el inicio ya esté pintado) y llama `prewarmWebView()` sin `await` bloqueante (`unawaited`).
4. Prueba Dart: `prewarmWebView()` en plataforma no Android no hace nada y no lanza (usa `debugDefaultTargetPlatformOverride`).

## Criterios de aceptación

- [ ] `node -e "new Function(require('fs').readFileSync('assets/engines/xlsx/xlsx-engine.js','utf8'))"` sin error.
- [ ] `grep -rnE "TODO|FIXME|catch \(_\)" assets/engines/xlsx lib/features/viewer/office lib/main.dart` sin resultados.
- [ ] `git diff fix/visor-inicio --stat` solo muestra archivos permitidos.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

Una hoja de 10 000+ filas: abre rápido, se desplaza fluido, encabezados fijos; el primer .docx tras abrir la app abre más rápido que antes.
