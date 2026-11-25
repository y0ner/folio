# Brief W2-D · Ícono de la app y pantalla de arranque

- **Rama:** `feat/icono-splash` · **Worktree:** `../worktrees/folio-feat-icono-splash` · **Base:** `integracion/oleada-1`
- **Lee primero:** `AGENTS.md`, `docs/diseno.md` §2 (colores).
- **Objetivo:** un ícono propio, sobrio y reconocible, y un arranque sin destello blanco en tema oscuro.

## Concepto del ícono (obligatorio)

Una **hoja de papel con la esquina superior derecha doblada**, en blanco `#FFFFFF`, sobre fondo tinta `#1A1A1A`. Dentro de la hoja, tres líneas horizontales de texto en `#1A1A1A` (la última más corta, 60 %). Sin degradados, sin sombras, sin letras. La hoja ocupa ~44 % del lienzo de 108 dp (zona segura de íconos adaptativos: 66 dp centrales), esquinas de la hoja redondeadas 2 dp.

## Archivos permitidos

- `android/app/src/main/res/drawable/ic_launcher_foreground.xml` (**nuevo**, vector 108×108 dp)
- `android/app/src/main/res/drawable/ic_launcher_monochrome.xml` (**nuevo**, misma forma en un solo color para íconos temáticos de Android 13)
- `android/app/src/main/res/values/colors.xml` (**nuevo**: `ic_launcher_background` `#1A1A1A`, `splash_background` `#F7F7F5`)
- `android/app/src/main/res/values-night/colors.xml` (**nuevo**: `splash_background` `#0E0E10`)
- `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` y `ic_launcher_round.xml` (**nuevos**: `adaptive-icon` con `background` = color, `foreground` y `monochrome`)
- `android/app/src/main/res/drawable/launch_background.xml`, `android/app/src/main/res/drawable-v21/launch_background.xml` (fondo `@color/splash_background`, sin imagen)
- `android/app/src/main/res/values/styles.xml`, `android/app/src/main/res/values-night/styles.xml` (ventana de arranque con `@color/splash_background`)
- `android/app/src/main/res/values-v31/styles.xml`, `android/app/src/main/res/values-night-v31/styles.xml` (**nuevos**: `android:windowSplashScreenBackground` = `@color/splash_background`, `android:windowSplashScreenAnimatedIcon` = `@drawable/ic_launcher_foreground`, `android:windowSplashScreenIconBackgroundColor` = `@color/ic_launcher_background`)
- `docs/brand/folio-icon.svg` (**nuevo**: el mismo dibujo en SVG 1024×1024 con fondo, para que el jefe genere los PNG de respaldo de Android 7)

## Qué hacer

1. Dibuja el vector con `pathData` limpios (coordenadas enteras o con un decimal). La esquina doblada es un triángulo en el borde superior derecho de la hoja, en un gris `#D9D9D6` (único color extra permitido).
2. Mantén los nombres de tema existentes (`LaunchTheme`, `NormalTheme`): solo cambian sus fondos y se agregan las variantes v31. No cambies `AndroidManifest.xml` (ya usa `@mipmap/ic_launcher`).
3. **No** borres los PNG existentes de `mipmap-*dpi` (siguen sirviendo a Android 7; el jefe los regenerará desde tu SVG).
4. Verifica que cada XML sea válido: `python3 -c "import xml.dom.minidom,sys;[xml.dom.minidom.parse(f) for f in sys.argv[1:]]" <archivos>`.

## Criterios de aceptación

- [ ] `git diff --stat integracion/oleada-1` solo muestra archivos permitidos.
- [ ] Los XML se parsean sin error (comando del paso 4).
- [ ] `docs/brand/folio-icon.svg` existe y se ve igual al vector.

## Qué se probará en el celular (humano)

Ícono en el cajón de apps (normal y con íconos temáticos), arranque en claro y oscuro sin destello blanco.
