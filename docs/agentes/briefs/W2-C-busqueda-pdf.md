# Brief W2-C · Buscar texto dentro del PDF

- **Rama:** `feat/busqueda-pdf` · **Worktree:** `../worktrees/folio-feat-busqueda-pdf` · **Base:** `integracion/oleada-1`
- **Lee primero:** `AGENTS.md`, `docs/diseno.md` §5 "Visor".
- **Objetivo:** desde la barra del visor, buscar una palabra en el PDF, ver "3 de 12", saltar entre resultados y verlos resaltados.

## Contexto

- Contrato nuevo (NO editar): `ViewerSearch` en `lib/features/viewer/viewer_controller.dart` (`query`, `isSearching`, `matchCount`, `currentIndex`, `search`, `next`, `previous`, `clear`; es un `Listenable`). El cuerpo lo registra con `controller.attach(onGoToPage: …, search: miBusqueda)` **antes** de `markReady`; la pantalla lo lee en `controller.search`.
- Cuerpo PDF: `lib/features/viewer/pdf/pdf_document_view.dart` (pdfrx 3.0.0). Ahí `onViewerReady` hace `markReady` y `_attachViewerController`.
- pdfrx trae `PdfTextSearcher` (`~/.pub-cache/hosted/pub.dev/pdfrx-3.0.0/lib/src/widgets/pdf_text_searcher.dart`): `startTextSearch`, `goToNextMatch`/`goToPrevMatch` (verifica los nombres reales), `matches`, `currentIndex`, `isSearching`, `resetTextSearch`, y `pageTextMatchPaintCallback` para resaltar (se pasa en `PdfViewerParams.pagePaintCallbacks`). Lee el archivo y el `README.md` de pdfrx; no inventes métodos.
- Pantalla: `lib/features/viewer/viewer_screen.dart` y `lib/features/viewer/widgets/viewer_top_bar.dart`.

## Archivos permitidos

- `lib/features/viewer/pdf/pdf_document_view.dart`
- `lib/features/viewer/pdf/pdf_search.dart` (**nuevo**: `PdfViewerSearch implements ViewerSearch`, adaptador sobre `PdfTextSearcher`)
- `lib/features/viewer/viewer_screen.dart`
- `lib/features/viewer/widgets/viewer_top_bar.dart`
- `lib/features/viewer/widgets/viewer_search_bar.dart` (**nuevo**)
- `test/features/viewer/**` (nuevas pruebas; puedes ajustar `viewer_screen_test.dart` solo si un cambio tuyo lo exige, sin debilitarla)

## Qué hacer

1. `PdfViewerSearch` (`ChangeNotifier implements ViewerSearch`): envuelve `PdfTextSearcher`, reenvía sus notificaciones, búsqueda **sin distinguir mayúsculas** (y, si pdfrx lo permite con un patrón, sin tildes), `search('')` = `clear()`. `currentIndex` en base 0 o −1.
2. En el cuerpo PDF: crea el buscador cuando el visor está listo, regístralo con `attach(search: …)`, pasa el `pageTextMatchPaintCallback` a `pagePaintCallbacks`; colores del resaltado: todos los resultados `context.folio.accent` con alfa 0.25 y el actual con alfa 0.55 (si pdfrx no permite distinguirlos, usa sus parámetros de color y explícalo). Libéralo en `dispose`.
3. Barra superior: si `controller.search != null` y el estado es `ready`, muestra un botón `LucideIcons.search` (tooltip "Buscar") antes de compartir.
4. Modo búsqueda (`viewer_search_bar.dart`), reemplaza la barra superior con la misma altura y estilo (`surface`, borde inferior): botón cerrar (`LucideIcons.x`, tooltip "Cerrar búsqueda"), `TextField` con foco automático y `hintText` "Buscar en el documento", contador (`labelMedium`, cifras tabulares) "3 de 12" / "Sin resultados" / un indicador de 16 dp mientras `isSearching` sin resultados aún, y botones anterior/siguiente (`LucideIcons.chevronUp`/`chevronDown`, desactivados sin resultados). Buscar al escribir con 350 ms de espera; Enter = siguiente.
5. Al cerrar: `search.clear()` y vuelve la barra normal. Durante la búsqueda, el toque sobre el documento **no** oculta las barras.
6. Pruebas:
   - `test/features/viewer/viewer_search_bar_test.dart` con un `ViewerSearch` falso (`ChangeNotifier`): muestra "3 de 12", "Sin resultados", llama `next`/`previous`, y cerrar llama `clear`.
   - En `viewer_screen_test.dart` agrega un caso: con un controlador al que se le hizo `attach(search: falso)` + `markReady(pageCount: 5)` aparece el botón "Buscar" y al tocarlo aparece el campo.

## Criterios de aceptación

- [ ] Las pruebas existen y pasan los casos pedidos.
- [ ] `grep -rnP "Color\(0x|Colors\.(?!transparent|black)|fontSize:" lib/features/viewer` no devuelve nada.
- [ ] `grep -rnE "TODO|FIXME|catch \(_\)" lib/features/viewer` no devuelve nada.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

Buscar una palabra en un PDF de 200 páginas: contador, saltos, resaltado, tildes y mayúsculas; cerrar la búsqueda; tema oscuro.
