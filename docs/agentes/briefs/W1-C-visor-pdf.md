# Brief W1-C · Cuerpo del visor PDF

- **Rama:** `feat/visor-pdf` · **Worktree:** `../worktrees/folio-feat-visor-pdf`
- **Lee primero:** `AGENTS.md` y `docs/diseno.md` §5 "Visor".
- **Objetivo:** mostrar PDF de forma nativa, fluida y bonita (claro y oscuro), informando a la pantalla del visor páginas, página actual y errores.

## Contexto

- `lib/features/viewer/pdf/pdf_document_view.dart` es un marcador vacío con la firma definitiva `PdfDocumentView({document, controller, onTap})`: **conserva la firma**, implementa el cuerpo.
- Contrato: `lib/features/viewer/viewer_controller.dart` (léelo completo). El cuerpo llama `controller.markReady(pageCount: n)`, `controller.setPage(p)`, `controller.fail(ViewerFailure(kind, detail: …))` y registra `controller.attach(onGoToPage: …)`.
- La barra superior, el indicador "3 / 24" y las pantallas de error/carga los dibuja `ViewerScreen` (otro brief): **tú no dibujas barras, ni indicador de página, ni texto de error**. Mientras carga, no muestres nada encima (fondo `canvas`).
- Librería: **pdfrx 3.0.0** (PDFium nativo). Fuente en `~/.pub-cache/hosted/pub.dev/pdfrx-3.0.0/` y `pdfrx_engine-0.9.3/`. Lee `lib/src/widgets/pdf_viewer.dart`, `pdf_viewer_params.dart`, `pdf_viewer_scroll_thumb.dart` y el `README.md` / `example/` antes de escribir. No inventes parámetros.

## Archivos permitidos

- `lib/features/viewer/pdf/pdf_document_view.dart`
- `lib/features/viewer/pdf/pdf_password_dialog.dart` (**nuevo**)
- `lib/features/viewer/pdf/pdf_scroll_thumb.dart` (**nuevo**, opcional)
- `test/features/viewer/pdf/**` (**nuevo**)

## Qué hacer

1. `StatefulWidget` con un `PdfViewerController`. Usa `PdfViewer.file(document.path, controller: …, params: PdfViewerParams(...))`.
2. Apariencia: `backgroundColor: context.folio.canvas`; separación entre páginas 12; márgenes 12; sombra de página suave (`BoxShadow` con `context.folio`… no hay token de sombra de página: usa `Colors.black.withValues(alpha: context.isDark ? 0.5 : 0.08)`, `blurRadius: 12`, `offset: Offset(0, 2)` — **esta es la única excepción permitida** a la regla de `Colors.*`, déjalo con un comentario en español que lo explique). Ajuste inicial: ancho de página al ancho de la pantalla.
3. Gestos: zoom con pellizco y doble toque (lo que trae pdfrx); `onGeneralTap` (o el mecanismo equivalente de pdfrx 3.0.0) → llama `onTap()` solo con **toque simple** sobre el contenido (no al seguir un enlace ni al seleccionar texto). Enlaces internos del PDF: navegan a su página; enlaces externos: no hacer nada.
4. Selección de texto activada si pdfrx 3.0.0 lo permite con parámetros simples (`textSelectionParams`), con el color de selección basado en `context.folio.accent` (alfa 0.3).
5. Indicador de desplazamiento vertical: `PdfViewerScrollThumb` en `viewerOverlayBuilder`, a la derecha, con forma de píldora `surface` + borde `border` y el número de página en `labelMedium`. Siempre visible y discreto (no depende del modo inmersivo).
6. Contrato: en `onViewerReady` → `controller.markReady(pageCount: document.pages.length)` y `controller.attach(onGoToPage: (p) => pdfController.goToPage(pageNumber: p))`; en `onPageChanged` → `controller.setPage(p)`.
7. Contraseña: si el PDF está cifrado, usa el `passwordProvider` de pdfrx para mostrar `PdfPasswordDialog` (título "Documento protegido", campo de contraseña oculto con botón mostrar/ocultar, "Cancelar" / "Abrir"; si la contraseña falla, el diálogo vuelve a aparecer con el texto "Contraseña incorrecta"). Si el usuario cancela → `controller.fail(ViewerFailure(ViewerFailureKind.encrypted))`.
8. Errores de carga (archivo dañado, no es PDF): `controller.fail(ViewerFailure(ViewerFailureKind.corrupt, detail: '$error'))` y `debugPrint`. Usa el `errorBannerBuilder`/manejo equivalente de pdfrx para **no** mostrar su banner por defecto.
9. Limpieza: `dispose` del controlador; `controller.attach()` sin callbacks al desmontar.
10. Prueba `test/features/viewer/pdf/pdf_password_dialog_test.dart`: el diálogo devuelve la contraseña escrita al pulsar "Abrir", `null` al pulsar "Cancelar", y muestra "Contraseña incorrecta" cuando se le indica.

## Criterios de aceptación

- [ ] Firma de `PdfDocumentView` sin cambios.
- [ ] La prueba del diálogo existe.
- [ ] `grep -rnE "TODO|FIXME|catch \(_\)" lib/features/viewer/pdf` no devuelve nada.
- [ ] `grep -rnP "Color\(0x|fontSize:" lib/features/viewer/pdf` no devuelve nada.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

PDF de 1 página y de 200 páginas: desplazamiento fluido, zoom con pellizco y doble toque, saltar a página desde el indicador, PDF con contraseña, PDF dañado, tema oscuro.
