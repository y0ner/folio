# Brief W1-E · Pantalla del visor (barras, modo inmersivo, indicador y errores)

- **Rama:** `feat/visor-pantalla` · **Worktree:** `../worktrees/folio-feat-visor-pantalla`
- **Lee primero:** `AGENTS.md` y `docs/diseno.md` §5 "Visor" (obligatorio).
- **Objetivo:** el marco común de todos los visores: barra superior, modo inmersivo con un toque, indicador de página, barra de hojas para Excel, carga y errores claros.

## Contexto

- `lib/features/viewer/viewer_screen.dart` es una versión base: complétala. Elige el cuerpo (`PdfDocumentView` u `OfficeDocumentView`, que implementan otros briefs; en tu rama son marcadores vacíos: **no los toques**).
- Contrato: `lib/features/viewer/viewer_controller.dart` (léelo completo). Tú **lees** `status`, `failure`, `pageCount`, `currentPage`, `sections`, `currentSection` y **llamas** `goToPage` / `selectSection`.
- Modelo y tokens: `DocumentRef`, `DocKind`, `FolioTokens`, `context.folio`. Iconos `LucideIcons` (`~/.pub-cache/hosted/pub.dev/lucide_icons_flutter-4.0.3/`). Compartir: `share_plus` 13 (`~/.pub-cache/hosted/pub.dev/share_plus-13.3.1/`).
- La insignia de tipo (`DocBadge`) la crea otro brief en `lib/ui/`: **no la uses**; dibuja tu propia insignia pequeña privada dentro de tus archivos (cuadro 22 dp, radio 6, `kind.tint(context)`, abreviatura en `labelSmall` color `kind.color(context)`).

## Archivos permitidos

- `lib/features/viewer/viewer_screen.dart`
- `lib/features/viewer/widgets/**` (**nuevos**: `viewer_top_bar.dart`, `page_indicator.dart`, `section_bar.dart`, `viewer_error_view.dart`, `document_info_sheet.dart`, `go_to_page_dialog.dart`)
- `lib/features/viewer/viewer_messages.dart` (**nuevo**)
- `test/features/viewer/viewer_screen_test.dart`, `test/features/viewer/viewer_messages_test.dart` (**nuevos**)

## Qué hacer

1. `ViewerScreen({required document, @visibleForTesting ViewerController? controller})`: si recibe controlador, lo usa y no lo libera; si no, crea y libera el suyo. Envuelve todo en `ListenableBuilder(listenable: controller)`.
2. Al iniciar: si `File(document.path)` no existe → `controller.fail(ViewerFailure(ViewerFailureKind.missing))` y no construye el cuerpo.
3. **Diseño** (`Scaffold` con `backgroundColor: context.folio.canvas`, `extendBodyBehindAppBar: true`, el cuerpo ocupa toda la pantalla):
   - Barra superior propia (no `AppBar` por defecto) en `surface` con borde inferior de 1 px `border`, respetando el `SafeArea` superior: botón atrás (`LucideIcons.arrowLeft`, tooltip "Atrás"), insignia pequeña + nombre (`titleMedium`, 1 línea, elipsis) y acciones: compartir (`LucideIcons.share2`, tooltip "Compartir") y menú (`LucideIcons.ellipsisVertical`) con "Información del archivo" e "Ir a la página…" (esta última solo si `pageCount > 1`).
   - **Modo inmersivo**: `onTap` del cuerpo alterna las barras. Ocultas: la barra sube y se desvanece (`AnimatedSlide` + `AnimatedOpacity`, `FolioTokens.normal`, `FolioTokens.curve`) y se llama `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`; visibles: `SystemUiMode.edgeToEdge`. Al salir de la pantalla restaura `edgeToEdge`. Mientras carga o hay error, las barras siempre visibles.
   - **Indicador de página** (`page_indicator.dart`): píldora flotante abajo al centro (encima del `SafeArea` inferior), `surface` + borde `border` + `context.folio.floatingShadow`, texto `"$currentPage / $pageCount"` en `labelMedium` con cifras tabulares (`FontFeature.tabularFigures()`). Visible solo si `status == ready && pageCount > 1`; se oculta con las barras. Al tocarla → `GoToPageDialog`.
   - **Barra de secciones** (`section_bar.dart`): solo si `sections.length > 1` (Excel): barra inferior `surface` con borde superior, `ListView` horizontal de chips (seleccionado en `ink`/`onInk`) → `controller.selectSection(i)`. Si hay barra de secciones, el indicador de página no se muestra.
   - **Carga**: si `status == loading`, encima del cuerpo, centrado: `CircularProgressIndicator` de 2 px de trazo y 24 dp + "Abriendo documento…" (`bodyMedium`). Aparece solo si la carga tarda más de 300 ms (evita parpadeo).
   - **Error** (`viewer_error_view.dart`): cubre el cuerpo; icono en trazo fino 40 dp (`LucideIcons.lock` para `encrypted`, `fileQuestion` para `missing`, `fileX` para el resto), título y explicación de `viewer_messages.dart`, y botón relleno "Compartir con otra app" (salvo `missing`, que muestra "Volver").
4. `viewer_messages.dart`: `({String title, String body}) messageFor(ViewerFailureKind)`, en español, p. ej.:
   - encrypted: "Documento protegido" / "Este archivo tiene contraseña y no se puede mostrar.";
   - corrupt: "No se pudo abrir el archivo" / "Parece estar dañado o incompleto.";
   - unsupported: "Formato no compatible" / "Folio aún no puede mostrar este tipo de archivo.";
   - missing: "El archivo ya no está" / "Se movió o se borró del dispositivo.";
   - engine: "Algo salió mal" / "Hubo un problema al mostrar el documento.".
5. `GoToPageDialog`: campo numérico con `hintText` "1 – N", valida el rango ("Escribe un número entre 1 y N"), botones "Cancelar" / "Ir" → `controller.goToPage(n)`.
6. `DocumentInfoSheet` (hoja inferior): nombre, tipo (`kind.label`), tamaño (formatea tú: B/KB/MB con coma decimal), fecha de apertura (`dd/mm/aaaa hh:mm`, sin `intl`), y páginas si `pageCount > 0`.
7. Pruebas (`FolioTheme.light()`, un `ViewerController` inyectado y un `DocumentRef` apuntando a un archivo temporal real creado en `setUp` con `Directory.systemTemp.createTempSync`):
   - `viewer_messages_test.dart`: cada tipo tiene título y cuerpo no vacíos y distintos.
   - `viewer_screen_test.dart`: (a) archivo inexistente → "El archivo ya no está"; (b) `markReady(pageCount: 12)` + `setPage(3)` → se ve "3 / 12"; (c) `markReady(sections: ['Hoja1','Hoja2'])` → se ven ambos chips y tocar "Hoja2" deja `currentSection == 1`; (d) `fail(encrypted)` → "Documento protegido".

## Criterios de aceptación

- [ ] Firma pública compatible: `ViewerScreen(document: doc)` sigue funcionando.
- [ ] Las dos pruebas existen y cubren los casos.
- [ ] `grep -rnP "Color\(0x|Colors\.(?!transparent)|fontSize:" lib/features/viewer/viewer_screen.dart lib/features/viewer/widgets lib/features/viewer/viewer_messages.dart` no devuelve nada.
- [ ] `grep -rnE "TODO|FIXME|catch \(_\)" lib/features/viewer/viewer_screen.dart lib/features/viewer/widgets` no devuelve nada.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

Abrir un PDF largo: tocar para ocultar/mostrar barras (también la barra del sistema), indicador "x / N", ir a página, información del archivo, compartir; tema oscuro; abrir un reciente borrado del teléfono.
