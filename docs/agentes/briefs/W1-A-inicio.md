# Brief W1-A · Pantalla de inicio y ajustes

- **Rama:** `feat/inicio` · **Worktree:** `../worktrees/folio-feat-inicio`
- **Lee primero:** `AGENTS.md` y `docs/diseno.md` (secciones 1–5 completas; son obligatorias).
- **Objetivo:** que el usuario vea sus documentos recientes, los filtre y busque, abra uno nuevo con el selector del sistema y cambie el tema claro/oscuro.

## Contexto

- `lib/features/home/home_screen.dart` y `lib/features/settings/settings_screen.dart` son marcadores vacíos: reemplázalos.
- Servicios: `AppScope.of(context)` (`lib/core/app_scope.dart`) da `recents` (`RecentStore`, un `ChangeNotifier`; usa `ListenableBuilder`), `settings` (`SettingsStore.themeMode` / `setThemeMode`) e `intake` (`FileIntake.pick()` devuelve un `IntakeResult` sellado: `IntakeOpened`, `IntakeCancelled`, `IntakeUnsupported`; `deleteLocalCopy(ref)`).
- Para abrir un documento usa **siempre** `openDocument(context, ref)` de `lib/core/open_document.dart`.
- Modelo: `DocumentRef` (`path`, `name`, `kind`, `sizeBytes`, `openedAt`) y `DocKind` (`label`, `abbreviation`, `color(context)`, `tint(context)`), en `lib/core/files/`.
- Tokens: `FolioTokens`, `context.folio` (`lib/core/theme/`). Iconos: `LucideIcons` (`~/.pub-cache/hosted/pub.dev/lucide_icons_flutter-4.0.3/`). Compartir: `share_plus` 13 (`SharePlus.instance.share(ShareParams(files: [XFile(path)]))`; verifica la API en `~/.pub-cache/hosted/pub.dev/share_plus-13.3.1/`).

## Archivos permitidos

- `lib/features/home/home_screen.dart`
- `lib/features/home/**` (**nuevos**: widgets de la pantalla, p. ej. `recent_tile.dart`, `type_filter_bar.dart`, `recent_groups.dart`)
- `lib/features/settings/settings_screen.dart`
- `lib/features/settings/licenses.dart` (**nuevo**)
- `lib/ui/**` (**nuevos**: `doc_badge.dart`, `empty_state.dart`, `section_header.dart`, `format.dart`)
- `test/features/home/**`, `test/features/settings/**`, `test/ui/**` (**nuevos**)

## Qué hacer

1. `lib/ui/doc_badge.dart`: `DocBadge(kind, {size = 40})` — cuadro con radio `size/4`, fondo `kind.tint(context)`, abreviatura en `labelSmall` peso 700 color `kind.color(context)`. Variante pequeña (`size: 24`) para la barra del visor.
2. `lib/ui/format.dart` (funciones puras, en español, **sin** `DateFormat` ni datos de locale):
   - `formatBytes(int)` → `"850 B"`, `"12 KB"`, `"3,4 MB"`, `"1,2 GB"` (coma decimal, un decimal desde MB).
   - `formatOpenedAt(DateTime t, {required DateTime now})` → `"Hoy, 14:05"`, `"Ayer, 09:30"`, `"12 nov"` (mismo año), `"12 nov 2025"` (otro año). Meses abreviados en minúscula: ene feb mar abr may jun jul ago sep oct nov dic.
3. `lib/features/home/recent_groups.dart`: `groupRecents(List<DocumentRef>, {required DateTime now})` → lista ordenada de grupos `Hoy`, `Esta semana` (últimos 7 días sin hoy), `Anteriores`; omite grupos vacíos; conserva el orden de entrada dentro de cada grupo. También `filterRecents(items, {String query, DocKind? kind})` (búsqueda sin distinguir mayúsculas ni tildes: "informe" encuentra "Informe Técnico", "tecnico" encuentra "Técnico").
4. `HomeScreen` según `docs/diseno.md` §5 "Inicio":
   - `CustomScrollView` con encabezado "Folio" (`displaySmall`) y botón de ajustes (`LucideIcons.settings2`, tooltip "Ajustes") que navega a `SettingsScreen`.
   - Campo de búsqueda ("Buscar en recientes"), chips de filtro (Todos, PDF, Word, Excel, PowerPoint; los de tipo con un punto de 8 dp de su color; chip seleccionado en `ink`).
   - Lista agrupada (`SectionHeader` en `labelMedium` mayúsculas, tracking 0.6). Fila (`RecentTile`): `DocBadge`, nombre (1 línea, elipsis, `bodyLarge`), meta `formatBytes · formatOpenedAt` (`labelMedium`), botón de menú (`LucideIcons.ellipsisVertical`) con "Compartir" y "Quitar de recientes" (quita y llama `intake.deleteLocalCopy`).
   - Tocar una fila: si `File(path)` no existe → `SnackBar` "Este archivo ya no está disponible" con acción "Quitar"; si existe → `openDocument`.
   - Botón flotante píldora centrado abajo, relleno `ink`: icono `LucideIcons.folderOpen` + "Abrir archivo". Llama `intake.pick()`; `IntakeOpened` → `openDocument`; `IntakeUnsupported` → `SnackBar` "Folio no puede abrir «nombre»"; cancelado → nada. Muestra un indicador de carga en el botón mientras copia.
   - Estado vacío (`EmptyState` en `lib/ui/`): icono `LucideIcons.fileText` 48 dp en `textTertiary`, "Abre tu primer documento" (`titleMedium`) y "PDF, Word, Excel y PowerPoint, sin conexión." (`bodyMedium`). Si hay recientes pero el filtro no da resultados: "Sin resultados".
   - Margen lateral `FolioTokens.gutter`; espacio inferior para que el botón no tape la última fila.
5. `SettingsScreen`: `AppBar` "Ajustes"; sección "Apariencia" con `SegmentedButton<ThemeMode>` (Sistema / Claro / Oscuro, iconos `LucideIcons.monitorSmartphone`, `sun`, `moon`) ligado a `settings`; sección "Acerca de" con "Folio" + versión fija `1.0.0` y fila "Licencias de terceros" → `showLicensePage(context: context, applicationName: 'Folio', applicationVersion: '1.0.0')`.
6. `lib/features/settings/licenses.dart`: `void registerAssetLicenses()` que agrega al `LicenseRegistry` los textos de `assets/licenses/` (Inter, Carlito, Caladea con paquetes `['Inter']`, `['Carlito']`, `['Caladea']`; docx-preview y jszip). Lee con `rootBundle.loadString`. (El jefe la llamará desde `main.dart`; tú **no** edites `main.dart`.)
7. Pruebas:
   - `test/ui/format_test.dart`: casos de bytes (0, 850, 12 288, 3,4 MB, 1,2 GB) y de fechas (hoy, ayer, mismo año, otro año).
   - `test/features/home/recent_groups_test.dart`: agrupación con `now` fijo, grupos vacíos omitidos, filtro por tipo y búsqueda sin tildes.
   - `test/features/home/home_screen_test.dart`: con `AppScope` real (`RecentStore` sobre `InMemorySharedPreferencesAsync`, mira `test/core/recent_store_test.dart`) y `FolioTheme.light()`: (a) sin recientes muestra "Abre tu primer documento"; (b) con 2 recientes muestra sus nombres y el filtro "Word" deja solo el `.docx`.

## Criterios de aceptación

- [ ] Las 3 pruebas nuevas existen y cubren lo pedido.
- [ ] `grep -rnE "Color\(0x|Colors\.(?!transparent)|fontSize:" lib/features/home lib/features/settings lib/ui` (usa `grep -P`) no devuelve nada.
- [ ] `grep -rn "TODO\|FIXME\|catch (_)" lib/features/home lib/features/settings lib/ui` no devuelve nada.
- [ ] `flutter analyze --no-pub` sin problemas.

## Qué se probará en el celular (humano)

Abrir un PDF con el botón, volver y verlo en "Recientes · Hoy"; buscar y filtrar; quitar de recientes; cambiar a oscuro y a claro en Ajustes.
