# Manual operativo para agentes de IA — Folio

Folio es un **visor** de PDF, Word, Excel y PowerPoint para Android (Flutter).
Rige cómo trabajan los agentes de IA en este repositorio. Si algo de este
archivo choca con una instrucción de un brief, gana este archivo.

## 1. Roles

| Rol | Quién | Qué hace |
|---|---|---|
| **Humano** | Yoner | Aprueba cada oleada, autoriza los merges y prueba en su celular Android. |
| **Agente jefe** | Claude Code | Escribe los briefs, crea ramas y *worktrees*, revisa, corre pruebas y builds, abre los PR y fusiona a `dev` con autorización. |
| **Agentes trabajadores** | Gemini (CLI `agy`) | Implementan **una tarea por rama**, en su propio *worktree*, tocando solo los archivos de su brief. |

## 2. Flujo (una tarea = una rama = un PR)

1. El jefe crea el *worktree*: `git worktree add ../worktrees/<rama> -b <rama> dev`.
2. El trabajador recibe `docs/agentes/briefs/<id>.md` y trabaja **solo** en su *worktree*.
3. El trabajador hace commits pequeños y **no hace push**.
4. El jefe revisa (sección 5), hace push y abre el PR contra `dev`.
5. Si algo falla, el jefe devuelve el error exacto; el trabajador corrige en la misma rama.
6. `main` solo recibe cambios tras la prueba del humano en el celular.

## 3. Arquitectura (no cambiarla sin brief)

```
lib/
  main.dart, app.dart            arranque, tema, AppScope
  core/
    app_scope.dart               servicios compartidos (recents, settings, intake)
    open_document.dart           openDocument(context, ref): registra en recientes y abre el visor
    theme/                       FolioTokens, FolioColors (context.folio), FolioTheme
    files/                       DocKind, DocumentRef, RecentStore, FileIntake
    settings/                    SettingsStore (tema)
  ui/                            widgets compartidos (insignia de tipo, estado vacío…)
  features/
    home/                        inicio
    settings/                    ajustes
    viewer/
      viewer_controller.dart     contrato pantalla ↔ cuerpo (estado, páginas, secciones)
      viewer_screen.dart         barras, modo inmersivo, indicador, errores
      pdf/                       cuerpo PDF (pdfrx, nativo)
      office/                    cuerpo Word/Excel/PowerPoint (WebView + motores JS)
assets/engines/
  vendor/                        librerías JS de terceros (NO editar)
  fonts/                         Carlito/Caladea para documentos
  common/ docx/ xlsx/ pptx/      HTML/JS/CSS propios de cada motor
```

Contratos que **no** se modifican sin que el brief lo diga: `viewer_controller.dart`,
`core/files/*`, `core/theme/*`, `app_scope.dart`, `pubspec.yaml`.

## 4. Reglas para los trabajadores

1. **Aislamiento:** solo los "Archivos permitidos" del brief. Si hace falta otro, te detienes y lo reportas.
2. **Sin merge, push, rebase ni cambio de rama.**
3. **Solo análisis estático:** puedes correr `flutter analyze --no-pub`; **no** `flutter test`, `flutter build` ni `flutter pub get` (los corre el jefe, uno a la vez).
4. **Sin dependencias nuevas** (no tienes red). Las disponibles están en `pubspec.yaml`; su código fuente está en `~/.pub-cache/hosted/pub.dev/` (léelo para no inventar APIs).
5. **Código completo:** sin `TODO`/`FIXME`, métodos vacíos, datos falsos ni errores silenciados (`catch (_) {}` prohibido: registra con `debugPrint` y muestra el estado de error).
6. **Pruebas:** toda lógica nueva fuera de widgets llega con su prueba en `test/` (espejo de `lib/`). Los widgets importantes, con una prueba de widget.
7. **Diseño:** sigue `docs/diseno.md`. Colores solo con `context.folio.*`, `DocKind.color/tint` o el `ColorScheme`; medidas con `FolioTokens`; textos con `Theme.of(context).textTheme`. **Prohibido** `Color(0x…)`, `Colors.*` (salvo `Colors.transparent`) y `fontSize:` sueltos en `lib/features` y `lib/ui`.
8. **Iconos:** `lucide_icons_flutter` (`LucideIcons.*`).
9. **Idioma:** español en comentarios, textos de usuario y commits.
10. **Formato:** no ejecutes `dart format` sobre archivos que no creaste.
11. **Pruebas viejas:** nunca escondas widgets (opacidad 0, `Offstage`) ni fuerces el tema para que pase una prueba; repórtalo.

### Alcance prohibido

- Editar documentos: Folio solo **muestra**.
- Red: la app funciona 100 % sin internet. Nada de CDNs, analítica ni descargas; todo JS/fuente se carga desde `assets/`.
- Permisos de Android nuevos sin que el brief lo pida.

## 5. Lista de revisión de cada PR (jefe)

1. **[Aislamiento]** Solo cambió los archivos permitidos.
2. **[Integridad]** Sin `TODO`, simulaciones ni errores silenciados.
3. **[Análisis]** `flutter analyze` sin problemas.
4. **[Pruebas]** `flutter test` en verde.
5. **[Build]** `flutter build apk --debug` compila.
6. **[Criterios]** Cada criterio de aceptación del brief se puede señalar en el diff.
7. **[Celular]** El PR dice qué debe probar el humano.
