# Brief W3-B · Selector nativo para conocer la ubicación real del archivo

- **Rama:** `feat/selector-nativo` · **Worktree:** `~/Desktop/Projects/worktrees/folio-feat-selector-nativo` · **Base:** `fix/visor-inicio`
- **Lee primero:** `AGENTS.md`.
- **Objetivo:** que "Información del archivo → Ubicación" muestre la ruta real (p. ej. `/storage/emulated/0/Download/carta solicitud.docx`) para archivos abiertos con "Abrir archivo" y con "Abrir con".

## Problema (verificado en el celular)

`FileIntake.pick()` usa `FilePicker.pickFile`, que copia el archivo a `cache/file_picker/<uuid>/` y su `PlatformFile.uri` apunta a **esa copia**, no al original. Hoy la Ubicación muestra `/data/data/dev.yoner.folio/cache/file_picker/…`.

## Contexto

- Canal existente `folio/incoming`: `android/app/src/main/kotlin/dev/yoner/folio/IncomingFiles.kt` (copia un `Uri` a `cacheDir/incoming`, nombre por `OpenableColumns`, extensión por MIME, hilo de fondo, envía `{path, name, uri}`), `MainActivity.kt`, y en Dart `lib/core/files/incoming_files.dart`.
- `lib/core/files/file_intake.dart`: `pick()` e `importFile(File, {name, sourceUri})`. `DocumentRef.source` guarda el URI y `lib/core/files/source_location.dart` (`describeSource`) lo convierte en texto (ya entiende `file://` y `content://com.android.externalstorage.documents/...`).

## Archivos permitidos

- `android/app/src/main/kotlin/dev/yoner/folio/IncomingFiles.kt`, `MainActivity.kt`
- `lib/core/files/incoming_files.dart`, `lib/core/files/file_intake.dart`
- `test/core/**`

## Qué hacer

1. **Kotlin — método `pick`** en el canal `folio/incoming`: lanza `Intent.ACTION_OPEN_DOCUMENT` (`CATEGORY_OPENABLE`, `type = "*/*"`, `EXTRA_MIME_TYPES` con los MIME de PDF, docx, xlsx, xls, csv, pptx, ppsx) con `startActivityForResult` y un código propio; `MainActivity.onActivityResult` lo reenvía a `IncomingFiles`. Resultado: cancelado → `result.success(null)`; elegido → en hilo de fondo copia con la lógica existente y responde `{path, name, uri}`. Solo una petición a la vez (si llega otra, `result.error("busy", …)`).
2. **Kotlin — ruta real** `resolveDisplayUri(uri): String` usada por `pick` **y** por los intents VIEW/SEND: devuelve `file://<ruta absoluta>` cuando la pueda deducir, si no el `uri.toString()` original:
   - `com.android.externalstorage.documents`: docId `primary:<rel>` → `/storage/emulated/0/<rel>`; `<VOL>:<rel>` → `/storage/<VOL>/<rel>`.
   - `com.android.providers.downloads.documents`: docId `raw:<ruta>` → `<ruta>`; `msf:<id>` o numérico → consulta `MediaStore` (`MediaStore.Downloads` / `MediaStore.Files.getContentUri("external")`, columnas `RELATIVE_PATH` + `DISPLAY_NAME` en API 29+, `DATA` en API < 29) y arma `/storage/emulated/0/<RELATIVE_PATH><DISPLAY_NAME>`.
   - `com.android.providers.media.documents`: docId `document:<id>` (u otro tipo) → la misma consulta a `MediaStore.Files`.
   - `file://` → su ruta.
   - Cualquier excepción o cursor vacío → `Log.w` y se usa el URI original (nunca falla el pick por esto).
3. **Dart**: `IncomingFiles.pick()` → `Future<IncomingFile?>` (incluye `uri`). `FileIntake` recibe en su constructor un `Future<IncomingFile?> Function()? nativePick`; en Android (`defaultTargetPlatform == TargetPlatform.android`) `pick()` usa el selector nativo y llama `importFile(..., sourceUri: incoming.uri)` y borra la copia temporal de `cache/incoming`; en otras plataformas sigue con `FilePicker.pickFile`. `main.dart` **no** se toca: el valor por defecto de `nativePick` debe crear/usar `IncomingFiles()` de forma perezosa solo en Android (cuidado: `IncomingFiles()` instala un `setMethodCallHandler`; no crees una segunda instancia que pise la del `IncomingFilesListener` — usa una instancia compartida, p. ej. `IncomingFiles.instance`, y adapta el listener si hace falta… pero el listener NO está en tus archivos permitidos: entonces haz que `pick` use `MethodChannel('folio/incoming').invokeMethod('pick')` directamente **sin** registrar handler).
4. Pruebas: `pick()` con el canal simulado (elegido y cancelado); `FileIntake.pick` en Android simulado (`debugDefaultTargetPlatformOverride`) usa `nativePick` y guarda `source`.

## Criterios de aceptación

- [ ] Pruebas nuevas en verde.
- [ ] `grep -rnE "TODO|FIXME|catch \(_\)" lib/core android/app/src/main/kotlin` sin resultados.
- [ ] `git diff fix/visor-inicio --stat` solo muestra archivos permitidos.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

Abrir un .docx desde "Abrir archivo" eligiéndolo en Descargas y desde la pestaña "Recientes" del selector: la Ubicación debe mostrar `/storage/emulated/0/Download/…`.
