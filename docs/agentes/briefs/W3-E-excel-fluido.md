# Brief W3-E · Excel fluido: ventana virtual y encabezado fijo

- **Rama:** `feat/excel-fluido` · **Worktree:** `~/Desktop/Projects/worktrees/folio-feat-excel-fluido` · **Base:** `fix/office-cargando`
- **Lee primero:** `AGENTS.md`.
- **Objetivo:** que una hoja de 20 000 filas se desplace sin pantallazos blancos y con la fila de letras de columna (A, B, C…) siempre visible.

## Problemas medidos por el jefe en el Xiaomi (APK release)

1. **Pantallazo blanco al desplazar rápido.** `assets/engines/xlsx/xlsx-engine.js` agrega bloques de 100 filas **en orden** desde arriba (centinela + `appendNextBlock`). Un deslizamiento rápido hasta la fila ~1000 deja la pantalla en blanco unos 2–3 s mientras dibuja los bloques intermedios.
2. **El encabezado de columnas deja de estar fijo** al bajar (las filas pasan por debajo de la barra del visor y no se ve "A, B, C…"). Los números de fila (izquierda) sí quedan fijos. `thead th` usa `position: sticky; top: var(--inset-top, 0px)` (`xlsx.css`); `--inset-top` lo fija Dart (barra superior ≈ 90 px CSS) y `body` tiene `padding-top: var(--inset-top)` (`assets/engines/common/base.css`).
3. Lectura: `XLSX.read` del libro completo tarda ~2,2 s en Chrome de escritorio para 20 000 × 24 (bloquea el hilo principal).

## Archivos permitidos

- `assets/engines/xlsx/xlsx-engine.js`, `assets/engines/xlsx/xlsx.css`
- `assets/engines/xlsx/xlsx-worker.js` (**nuevo**, opcional, ver paso 3)

## Qué hacer

1. **Ventana virtual por posición, no secuencial.** Con `rowTops` (ya calculado), en cada `scroll` (con `requestAnimationFrame`) calcula el rango de filas visible `[primera − 50, última + 50]` y dibuja **solo esos bloques**, colocados con espaciadores arriba y abajo (`<tr>` con alto = suma de las filas no dibujadas). Al saltar lejos se dibuja directamente la zona destino. Mantén como máximo ~6 bloques en el DOM. Las combinaciones (`!merges`) que crucen bloques: incluye los bloques necesarios para que el `rowspan` sea correcto. El aspecto no cambia.
2. **Encabezado fijo real.** Encuentra por qué `thead` deja de ser `sticky` (p. ej. un ancestro con `overflow`, `transform`, `contain`, o la tabla dentro de un contenedor que no es el que desplaza) y corrígelo para que la fila de letras quede pegada justo debajo de la barra (`top: var(--inset-top)`) y la esquina superior izquierda quede fija en ambos ejes. Verifícalo desplazando a la fila 5 000.
3. **(Opcional, si cabe)** Lectura en un Web Worker (`new Worker('xlsx-worker.js')`, que hace `importScripts('../vendor/xlsx.full.min.js')`): el hilo principal no se congela mientras lee. Si lo haces, la hoja se dibuja cuando el worker devuelve los datos de las filas pedidas (no transfieras el libro completo por `postMessage` si es enorme: pide filas por rango). Si no lo haces, explica por qué.
4. Mide en Chrome de escritorio (Puppeteer está disponible en `/home/yoner/.claude/jobs/8b8f9226/tmp/pp`, con `run.js` como ejemplo; si no tienes acceso, describe tu prueba) con una hoja de 20 000 × 24: tiempo hasta `ready`, número máximo de `<td>` en el DOM tras desplazar a la fila 10 000, y que `thead` siga visible (posición `top` de un `th` ≈ `--inset-top`).

## Criterios de aceptación

- [ ] `node -e "new Function(require('fs').readFileSync('assets/engines/xlsx/xlsx-engine.js','utf8'))"` sin error.
- [ ] `grep -rnE "TODO|FIXME|catch \(_\)|https?://" assets/engines/xlsx` sin resultados.
- [ ] `git diff fix/office-cargando --stat` solo muestra `assets/engines/xlsx/`.
- [ ] Informe con las tres mediciones del paso 4.

## Qué se probará en el celular (humano)

Hoja de 20 000 filas: deslizar rápido hasta abajo y arriba sin pantalla blanca prolongada, letras de columna siempre visibles, cambiar de hoja.
Hoja de prueba: /home/yoner/.claude/jobs/8b8f9226/tmp/site/doc/grande.xlsx (20 000 × 24).
