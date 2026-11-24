# Brief W1-B · Abrir archivos desde otras apps ("Abrir con" y "Compartir")

- **Rama:** `feat/apertura-android` · **Worktree:** `../worktrees/folio-feat-apertura-android`
- **Lee primero:** `AGENTS.md`.
- **Objetivo:** que Folio aparezca en "Abrir con…" y "Compartir" de Android para PDF, Word, Excel y PowerPoint, y que el documento se abra directo en el visor (con la app cerrada o abierta).

## Contexto

- `android/app/src/main/kotlin/dev/yoner/folio/MainActivity.kt` es la `FlutterActivity` vacía de la plantilla.
- `lib/core/files/file_intake.dart`: `FileIntake.importFile(File source, {required String name})` copia el archivo a la carpeta de la app y devuelve `IntakeResult` (`IntakeOpened(doc)` / `IntakeUnsupported(name)`).
- `lib/core/open_document.dart`: `openDocument(context, ref)` registra en recientes y abre el visor. Necesita un `context` **debajo** del `Navigator` del `MaterialApp`.
- `lib/app.dart` tiene `home: const HomeScreen()`.

## Archivos permitidos

- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/dev/yoner/folio/MainActivity.kt`
- `android/app/src/main/kotlin/dev/yoner/folio/IncomingFiles.kt` (**nuevo**)
- `lib/core/files/incoming_files.dart` (**nuevo**)
- `lib/features/incoming/incoming_files_listener.dart` (**nuevo**)
- `lib/app.dart` (**solo** la línea `home:`)
- `test/core/incoming_files_test.dart` (**nuevo**)

## Qué hacer

1. **Manifest** (en la `activity` principal, `launchMode="singleTop"` ya existe; verifícalo):
   - `intent-filter` `android.intent.action.VIEW` + categorías `DEFAULT` y `BROWSABLE`, `scheme` `content` y `file`, con `mimeType`: `application/pdf`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`, `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, `application/vnd.ms-excel`, `text/csv`, `text/comma-separated-values`, `application/vnd.openxmlformats-officedocument.presentationml.presentation`, `application/vnd.openxmlformats-officedocument.presentationml.slideshow`.
   - Otro `intent-filter` igual para `android.intent.action.SEND` (mismos MIME).
   - Etiqueta de la app: `android:label="Folio"`.
2. **Kotlin** (`IncomingFiles.kt` + `MainActivity.kt`): canal `MethodChannel("folio/incoming")`.
   - Al recibir un `Intent` VIEW (`intent.data`) o SEND (`EXTRA_STREAM`, usa `IntentCompat.getParcelableExtra` o la variante según API), en un hilo de fondo (`Executors.newSingleThreadExecutor()`): obtener nombre visible (`OpenableColumns.DISPLAY_NAME`; si no hay, el último segmento del URI), el MIME (`contentResolver.getType`), copiar el contenido a `cacheDir/incoming/<nombre>` con `contentResolver.openInputStream`. Si el nombre no trae extensión, agregar la del MIME (`pdf`, `docx`, `xlsx`, `xls`, `csv`, `pptx`, `ppsx`).
   - Método `getInitial` → devuelve `{path, name}` del intent con que se lanzó la actividad (solo una vez; después `null`).
   - En `onNewIntent` → tras copiar, `channel.invokeMethod("onFile", {path, name})` en el hilo principal.
   - Errores (sin permiso, stream nulo, `IOException`): `invokeMethod("onError", {message})` o `result.error(...)`; nunca tragarlos. Registrar con `Log.w("Folio", ...)`.
3. **Dart** `lib/core/files/incoming_files.dart`: clase `IncomingFiles` con `Future<IncomingFile?> initial()`, `Stream<IncomingFile> get files`, `Stream<String> get errors`, y `IncomingFile.fromMap(Map)` que valida `path` y `name` (devuelve `null` si faltan). Acepta un `MethodChannel` inyectable para pruebas.
4. **Dart** `lib/features/incoming/incoming_files_listener.dart`: `IncomingFilesListener({required Widget child, IncomingFiles? incoming})`, `StatefulWidget` que en `initState` (con `addPostFrameCallback`) pide `initial()` y escucha `files`/`errors`. Por cada archivo: `AppScope.of(context).intake.importFile(File(path), name: name)`, luego borra la copia de `cacheDir/incoming`, y si es `IntakeOpened` → `openDocument(context, doc)`; si `IntakeUnsupported` → `SnackBar` "Folio no puede abrir «nombre»"; errores → `SnackBar` "No se pudo recibir el archivo".
5. `lib/app.dart`: `home: const IncomingFilesListener(child: HomeScreen())` (agrega el import). Nada más.
6. **Prueba** `test/core/incoming_files_test.dart`: con `TestDefaultBinaryMessengerBinding` simula el canal: `initial()` devuelve el archivo; `onFile` emite en `files`; `fromMap` con datos incompletos devuelve `null`.

## Criterios de aceptación

- [ ] La prueba existe y cubre `initial`, `onFile` y mapas inválidos.
- [ ] `grep -n "catch (_)\|TODO" lib/core/files/incoming_files.dart lib/features/incoming android/app/src/main/kotlin -r` no devuelve nada.
- [ ] `git diff dev -- lib/app.dart` solo cambia la línea `home:` y un import.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

Desde el gestor de archivos y desde WhatsApp/Gmail: "Abrir con → Folio" con la app cerrada y con la app abierta; "Compartir → Folio".
