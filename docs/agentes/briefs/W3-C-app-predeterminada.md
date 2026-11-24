# Brief W3-C · Folio como app predeterminada para PDF, Word, Excel y PowerPoint

- **Rama:** `feat/app-predeterminada` · **Worktree:** `~/Desktop/Projects/worktrees/folio-feat-app-predeterminada` · **Base:** `fix/visor-inicio`
- **Lee primero:** `AGENTS.md`, `docs/diseno.md`.
- **Objetivo:** que el usuario vea, por tipo de documento, qué app lo abre hoy y pueda dejar a Folio como predeterminada en dos toques.

## Contexto (importante)

Android **no** permite que una app se declare predeterminada para tipos de archivo ni existe un permiso para eso (no hay `RoleManager` para documentos). Lo posible y correcto:
1. **Saber el estado**: `packageManager.resolveActivity(Intent(ACTION_VIEW).setDataAndType(uri, mime), MATCH_DEFAULT_ONLY)` → si resuelve a `dev.yoner.folio` = Folio es predeterminada; si resuelve a la actividad del selector del sistema (`android` / `com.android.internal.app.ResolverActivity` o el paquete del resolver del fabricante) = ninguna elegida; otro paquete = otra app es predeterminada (mostrar su nombre con `loadLabel`). Requiere `<queries>` en el manifiesto (visibilidad de paquetes, Android 11+) para `VIEW` con esos MIME.
2. **Elegir Folio**: lanzar `ACTION_VIEW` **sin paquete** sobre un archivo de muestra con el MIME del tipo → Android muestra su selector con "Siempre"; el usuario elige Folio + "Siempre".
3. **Si otra app ya es la predeterminada**, Android no muestra el selector: hay que llevar al usuario a `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` de **esa app** (`package:<paquete>`) para que toque "Abrir de forma predeterminada → Borrar valores predeterminados", y luego volver a "Elegir Folio".

Muestras ya empaquetadas: `assets/samples/folio-muestra.{pdf,docx,xlsx,pptx}` (en Android están en `flutter_assets/assets/samples/…` dentro del APK; cópialas a `cacheDir/muestras/` y exponlas con un `FileProvider`).

Canal existente para archivos entrantes: `IncomingFiles.kt` (`folio/incoming`) y `lib/features/incoming/incoming_files_listener.dart`. `MainActivity.kt` registra `IncomingFiles` en `configureFlutterEngine`.

## Archivos permitidos

- `android/app/src/main/AndroidManifest.xml` (`<queries>` y `<provider>` FileProvider `${applicationId}.muestras`)
- `android/app/src/main/res/xml/muestras_paths.xml` (**nuevo**)
- `android/app/src/main/kotlin/dev/yoner/folio/DefaultApps.kt` (**nuevo**, canal `folio/defaults`)
- `android/app/src/main/kotlin/dev/yoner/folio/MainActivity.kt` (solo registrar `DefaultApps`)
- `android/app/src/main/kotlin/dev/yoner/folio/IncomingFiles.kt` (solo detectar la muestra, ver paso 4)
- `android/app/build.gradle.kts` (solo si necesitas `androidx.core` para `FileProvider`; Flutter ya lo trae: verifica antes)
- `lib/core/defaults/default_apps.dart` (**nuevo**)
- `lib/features/settings/**`, `lib/features/home/**`, `lib/features/incoming/incoming_files_listener.dart`, `lib/core/files/incoming_files.dart`
- `test/core/**`, `test/features/settings/**`, `test/features/home/**`

## Qué hacer

1. **Kotlin `DefaultApps.kt`** (canal `folio/defaults`):
   - `status` → lista de `{kind: 'pdf'|'word'|'excel'|'powerpoint', state: 'folio'|'other'|'none', appName?: String, package?: String}` usando los MIME: pdf `application/pdf`; word `…wordprocessingml.document`; excel `…spreadsheetml.sheet`; powerpoint `…presentationml.presentation`, y el URI de la muestra de cada tipo.
   - `choose(kind)` → copia la muestra (si no está), `ACTION_VIEW` + `FLAG_GRANT_READ_URI_PERMISSION` + `FLAG_ACTIVITY_NEW_TASK`, sin paquete. `ActivityNotFoundException` → `result.error`.
   - `openAppSettings(package)` → `ACTION_APPLICATION_DETAILS_SETTINGS`.
   - Errores con `Log.w` y `result.error`; nunca tragarlos.
2. **Manifiesto**: `<queries>` con un `<intent>` `VIEW` por MIME (con `<data android:mimeType=…>`), y el `<provider androidx.core.content.FileProvider>` con autoridad `${applicationId}.muestras`, `exported=false`, `grantUriPermissions=true` y `muestras_paths.xml` (`<cache-path name="muestras" path="muestras/"/>`).
3. **Dart `lib/core/defaults/default_apps.dart`**: `enum DefaultState { folio, other, none }`, `class DefaultAppStatus { DocKind kind; DefaultState state; String? appName; String? packageName; }`, `class DefaultApps` con `Future<List<DefaultAppStatus>> status()`, `Future<void> choose(DocKind)`, `Future<void> openAppSettings(String package)`, `MethodChannel` inyectable. En no-Android: `status()` devuelve lista vacía. Con pruebas del mapeo del canal.
4. **Volver de la muestra**: si el usuario elige Folio, Android abrirá la muestra **en Folio**. En `IncomingFiles.kt`, si la autoridad del `Uri` es `dev.yoner.folio.muestras`, en vez de `onFile` envía `invokeMethod("onDefaultChosen", {kind})` (y `getInitial` devuelve `{defaultChosen: kind}`); en Dart (`incoming_files.dart` + listener) eso muestra `SnackBar` "Listo: Folio abrirá tus archivos <PDF|Word|Excel|PowerPoint>" y **no** agrega la muestra a recientes.
5. **Ajustes**: sección nueva "Abrir documentos" (encima de "Acerca de"): una fila por tipo con `DocBadge`, nombre del tipo y estado (`labelMedium`): "Folio" (con `LucideIcons.check` en `accent`), "Ahora: <app>", "Sin app elegida". Botón de texto a la derecha: estado `none` → "Elegir Folio" (`choose`); `other` → "Cambiar" que abre un diálogo explicando en 2 líneas: "Primero quita <app> como predeterminada: en la pantalla que se abrirá toca «Abrir de forma predeterminada» y luego «Borrar valores predeterminados». Después vuelve y toca «Elegir Folio»." con botón "Abrir ajustes de <app>"; `folio` → sin botón. Refresca el estado al volver a la app (`AppLifecycleListener` → `onResume`).
6. **Inicio**: si algún tipo no es `folio`, muestra arriba de la lista una tarjeta discreta (`surface`, borde `border`, radio 12) "Haz de Folio tu visor predeterminado" + "Elegir" (va a Ajustes) + cerrar (×, se recuerda con `shared_preferences` clave `home.defaultsBannerDismissed`). No la muestres si `status()` está vacío.
7. Pruebas: canal simulado para `status`/`choose`; widget de Ajustes muestra los tres estados; la tarjeta de inicio aparece con un tipo `none` y desaparece al cerrarla.

## Criterios de aceptación

- [ ] Pruebas nuevas en verde.
- [ ] `grep -rnP "Color\(0x|Colors\.(?!transparent)|fontSize:" lib/features/settings lib/features/home` sin resultados.
- [ ] `grep -rnE "TODO|FIXME|catch \(_\)" lib android/app/src/main/kotlin` sin resultados.
- [ ] Ningún permiso nuevo `<uses-permission>` en el manifiesto.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

Ajustes → Abrir documentos: ver el estado de cada tipo; "Elegir Folio" en PDF → elegir Folio + "Siempre" → mensaje "Listo"; abrir un PDF desde el gestor de archivos y que vaya directo a Folio; un tipo con otra app predeterminada → "Cambiar".
