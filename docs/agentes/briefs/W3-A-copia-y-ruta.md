# Brief W3-A · "Guardar una copia…" y ubicación original del archivo

- **Rama:** `feat/copia-y-ruta` · **Worktree:** `~/Desktop/Projects/worktrees/folio-feat-copia-y-ruta` · **Base:** `dev`
- **Lee primero:** `AGENTS.md`, `docs/diseno.md`.
- **Objetivo:** desde el menú ⋮ del visor, guardar rápido una copia del documento en la carpeta que el usuario elija; y que "Información del archivo" muestre de dónde vino el archivo (su ruta), con botón para copiarla.

## Contexto

- Folio trabaja sobre una **copia interna** (`DocumentRef.path`, dentro de `getApplicationSupportDirectory()/documents`). Hoy no se guarda de dónde vino el archivo.
- Orígenes:
  1. Selector del sistema: `FileIntake.pick()` (`lib/core/files/file_intake.dart`) usa `FilePicker.pickFile`; el `PlatformFile` trae `uri` (en Android, el `content://` original). API en `~/.pub-cache/hosted/pub.dev/file_picker_platform_interface-4.3.0/lib/src/platform_file.dart`.
  2. "Abrir con / Compartir": `android/app/src/main/kotlin/dev/yoner/folio/IncomingFiles.kt` copia el `Uri` a caché y envía `{path, name}` por el canal `folio/incoming`; Dart: `lib/core/files/incoming_files.dart` (`IncomingFile`) y `lib/features/incoming/incoming_files_listener.dart` (llama `intake.importFile`).
- Guardar copia: `FilePicker.saveFile({fileName, bytes, mimeType, dialogTitle})` en `~/.pub-cache/hosted/pub.dev/file_picker-13.4.1/lib/src/file_picker.dart` (en Android abre el diálogo "Guardar en…" del sistema y devuelve el `Uri` o `null` si se cancela).
- Pantalla: `lib/features/viewer/widgets/viewer_top_bar.dart` (menú ⋮), `lib/features/viewer/viewer_screen.dart` (acciones), `lib/features/viewer/widgets/document_info_sheet.dart`.
- **Otro trabajo en paralelo** toca `viewer_screen.dart` (márgenes del contenido) y los cuerpos `pdf/` y `office/`: en `viewer_screen.dart` limita tus cambios a lo mínimo (pasar el callback nuevo a la barra y el método que lo maneja). **No toques** `pdf/`, `office/` ni `assets/`.

## Archivos permitidos

- `lib/core/files/document_ref.dart` (agregar campo opcional `source`)
- `lib/core/files/file_intake.dart` (guardar el origen)
- `lib/core/files/source_location.dart` (**nuevo**)
- `lib/core/files/incoming_files.dart`, `lib/features/incoming/incoming_files_listener.dart`
- `android/app/src/main/kotlin/dev/yoner/folio/IncomingFiles.kt` (enviar también `uri`)
- `lib/features/viewer/widgets/viewer_top_bar.dart`, `lib/features/viewer/widgets/document_info_sheet.dart`
- `lib/features/viewer/document_actions.dart` (**nuevo**: lógica de "Guardar una copia")
- `lib/features/viewer/viewer_screen.dart` (solo el cableado del menú)
- `test/core/**`, `test/features/viewer/**` (nuevas pruebas o ajustes sin debilitar las existentes)

## Qué hacer

1. **`DocumentRef.source`** (`String?`): el URI original (`content://…` o `file://…`). Inclúyelo en `toJson`/`fromJson` (clave `source`, opcional: los recientes viejos sin ella siguen cargando) y en `copyWith`.
2. **`FileIntake`**: `importFile(File source, {required String name, String? sourceUri})` lo guarda en el `DocumentRef`. `pick()` pasa `file.uri.toString()` cuando exista.
3. **Abrir con**: `IncomingFiles.kt` agrega `"uri" to uri.toString()` al mapa; `IncomingFile` lo lee (`uri` opcional) y el listener lo pasa a `importFile(sourceUri: …)`.
4. **`source_location.dart`**: `String? describeSource(String? uri)` → texto legible en español:
   - `content://com.android.externalstorage.documents/document/primary%3ADownload%2Fcarta.docx` → `/storage/emulated/0/Download/carta.docx` (docId `primary:<ruta>` → `/storage/emulated/0/<ruta>`; otro volumen `XXXX-XXXX:<ruta>` → `/storage/XXXX-XXXX/<ruta>`).
   - `file:///storage/emulated/0/Documents/a.pdf` → `/storage/emulated/0/Documents/a.pdf`.
   - `content://com.android.providers.downloads.documents/…` → `Descargas`.
   - autoridad que contenga `whatsapp` → `Compartido desde WhatsApp`; `com.google.android.gm` → `Adjunto de Gmail`; `com.google.android.apps.docs` → `Google Drive`; `media` (`com.android.providers.media.documents`) → `Almacenamiento del teléfono`.
   - otro `content://` → `Compartido desde otra app (<autoridad>)`; `null` → `null`.
   Con pruebas en `test/core/source_location_test.dart` para cada caso.
5. **Información del archivo** (`document_info_sheet.dart`): fila "Ubicación" con `describeSource(document.source)` (si es `null`: "Desconocida (abierto antes de esta versión)"), texto seleccionable, y botón de icono `LucideIcons.copy` (tooltip "Copiar ruta") que copia al portapapeles y muestra `SnackBar` "Ruta copiada". Fila extra "Copia en Folio" con `document.path` en `labelSmall` `textTertiary`, también seleccionable.
6. **"Guardar una copia…"** (menú ⋮, icono `LucideIcons.download` o `copy`, primero en el menú): `document_actions.dart` → `Future<SaveCopyResult> saveDocumentCopy(DocumentRef doc)`: lee bytes de `doc.path`, MIME según `doc.kind`/extensión, `FilePicker.saveFile(fileName: doc.name, bytes: …, mimeType: …, dialogTitle: 'Guardar una copia')`. Resultados: guardado (`SnackBar` "Copia guardada"), cancelado (nada), error (`SnackBar` "No se pudo guardar la copia" + `debugPrint`). Si el archivo pesa más de 150 MB, no lo intentes: `SnackBar` "El archivo es demasiado grande para copiarlo así; usa Compartir".
7. Pruebas: `document_ref` con y sin `source` (ida y vuelta JSON; JSON viejo sin `source`), `source_location_test.dart`, y en la prueba de la hoja de información que se vea "Ubicación" y la ruta.

## Criterios de aceptación

- [ ] Pruebas nuevas en verde según los casos pedidos.
- [ ] `grep -rnP "Color\(0x|Colors\.(?!transparent|black)|fontSize:" lib/features/viewer/widgets lib/features/viewer/document_actions.dart` sin resultados.
- [ ] `grep -rnE "TODO|FIXME|catch \(_\)" lib/core lib/features/viewer/widgets lib/features/viewer/document_actions.dart` sin resultados.
- [ ] `git diff dev --stat` no muestra `pdf/`, `office/` ni `assets/`.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

Abrir un .docx desde el gestor y otro desde WhatsApp: "Información del archivo" muestra su ubicación y "Copiar ruta" funciona; "Guardar una copia…" en Descargas y en Documentos.
