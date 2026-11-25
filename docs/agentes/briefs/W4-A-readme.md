# Brief W4-A · README profesional (inglés + español), CONTRIBUTING, CHANGELOG y textos de tienda

- **Rama:** `docs/readme` · **Worktree:** `~/Desktop/Projects/worktrees/folio-docs-readme` · **Base:** `release/v1.0.0`
- **Lee primero:** `AGENTS.md`, `docs/diseno.md`, `THIRD_PARTY_NOTICES.md`, `run.sh`, `pubspec.yaml`, `lib/core/files/doc_kind.dart`.
- **Objetivo:** que el GitHub de Folio quede al nivel de proyectos como NewPipe: README claro, visual y completo, en inglés (`README.md`) y español (`README.es.md`).

## Datos del proyecto (úsalos tal cual; no inventes nada)

- **Nombre:** Folio. **Paquete:** `dev.yoner.folio`. **Versión actual:** **1.0.0** (`pubspec.yaml`: `1.0.0+1`). **Repo:** `https://github.com/y0ner/folio`. **Licencia:** GNU GPL v3 (archivo `LICENSE`).
- **Qué es:** visor minimalista para Android de PDF, Word, Excel y PowerPoint. Solo muestra documentos (no edita). Funciona 100 % sin conexión; no recopila datos.
- **Formatos:** PDF (`.pdf`); Word (`.docx`, `.docm`, `.dotx`); Excel (`.xlsx`, `.xlsm`, `.xls`, `.csv`); PowerPoint (`.pptx`, `.ppsx`, `.pptm`). No admite `.doc`/`.ppt` antiguos.
- **Funciones (verificadas en un celular real):**
  - Recientes agrupados (Hoy / Esta semana / Anteriores), búsqueda que ignora tildes y mayúsculas, filtros por tipo.
  - Abre desde el selector del sistema y desde "Abrir con" / "Compartir" de otras apps (WhatsApp, Gmail, gestor de archivos).
  - Puede quedar como **visor predeterminado** por tipo (Ajustes → Abrir documentos): muestra qué app abre cada tipo y lleva al selector de Android con "Siempre".
  - PDF nativo (PDFium vía pdfrx): zoom con pellizco y doble toque, selección de texto, enlaces internos, PDF con contraseña, **búsqueda dentro del PDF** con resaltado y contador.
  - Word con páginas fieles (docx-preview), fuentes compatibles con Calibri/Cambria/Arial/Times (Carlito, Caladea, Liberation).
  - Excel con encabezados fijos, celdas combinadas, pestañas de hojas y **hojas de hasta 20 000 filas** fluidas (ventana virtual + lectura en Web Worker).
  - PowerPoint como lista de diapositivas a lo ancho, con carga progresiva.
  - Modo inmersivo (un toque oculta las barras), indicador "3 / 24", ir a página.
  - Información del archivo con su **ruta real** y "Copiar ruta"; "Guardar una copia…" en otra carpeta; compartir.
  - Tema claro, oscuro o del sistema. Diseño "tinta y papel", tipografía Inter, iconos Lucide.
- **Requisitos:** Android 7.0 o superior (minSdk 24), arm64 recomendado. **Tamaño de la APK:** ~34 MB (arm64).
- **Permisos:** solo `INTERNET`, exigido por el WebView de Android para crearse; Folio **no** usa la red (los motores y documentos se cargan desde la propia app y cualquier URL externa se bloquea).
- **Stack:** Flutter 3.47 / Dart 3.13 · pdfrx (PDFium) · flutter_inappwebview + motores web empaquetados (docx-preview 0.4.1, SheetJS CE 0.20.3, pptx-preview 1.0.7) · Material 3 a medida.
- **Firma de la APK (para verificar):** SHA-256 `8E:1A:B0:DE:25:7E:BF:3D:FF:28:8B:0A:59:47:6E:C4:D9:93:EC:65:47:98:B3:53:BF:23:20:FD:E0:19:F8:E4` (certificado `CN=Folio, OU=y0ner, C=CO`).
- **Descarga:** GitHub Releases → `https://github.com/y0ner/folio/releases/latest` (archivo `folio-v1.0.0-arm64.apk`).
- **Sitio web:** `https://folio-visor.vercel.app` (el jefe lo confirmará; úsalo así).
- **Compilar:** `./run.sh android` · `./run.sh linux` (en escritorio Word/Excel/PowerPoint no están disponibles) · `./run.sh apk` · `./run.sh install` · `./run.sh test` · `./run.sh analyze`. Requiere Flutter 3.47+ y Android SDK.
- **Hecho con agentes:** el desarrollo se coordinó con un agente jefe (Claude Code) y agentes trabajadores (Gemini) por oleadas, con revisión y pruebas en un celular real (ver `AGENTS.md` y `docs/agentes/`). Menciónalo en una sección breve "How it was built / Cómo se construyó".

## Imágenes (rutas fijas; el jefe las genera)

- Ícono: `fastlane/metadata/android/en-US/images/icon.png` (512 px).
- Gráfico destacado: `fastlane/metadata/android/en-US/images/featureGraphic.png` (1024×500).
- Capturas (1080×2400, en ese orden): `fastlane/metadata/android/en-US/images/phoneScreenshots/1.png` … `8.png`:
  1 Inicio (claro) · 2 Visor PDF · 3 Word · 4 Excel con pestañas · 5 PowerPoint · 6 Búsqueda en PDF · 7 Ajustes → Abrir documentos · 8 Inicio (oscuro).

## Archivos permitidos

- `README.md` (inglés, reemplaza el actual), `README.es.md` (**nuevo**, español)
- `CONTRIBUTING.md` (**nuevo**, inglés, con una línea al principio que enlace a las reglas de `AGENTS.md`)
- `CHANGELOG.md` (**nuevo**, formato Keep a Changelog, versión `1.0.0` con fecha `2026-11-24`)
- `fastlane/metadata/android/en-US/{title.txt,short_description.txt,full_description.txt,changelogs/1.txt}` (**nuevos**)
- `fastlane/metadata/android/es-ES/{title.txt,short_description.txt,full_description.txt,changelogs/1.txt}` (**nuevos**)

## Qué hacer

1. **Estructura del README** (inspirada en NewPipe, con estilo propio y sobrio):
   - Encabezado HTML centrado: ícono (`fastlane/.../icon.png`, ancho 120), `<h2>` "Folio", `<h4>` frase corta ("A minimalist, offline document viewer for Android" / "Visor de documentos minimalista y sin conexión para Android").
   - Botón de descarga: enlace a releases/latest con una insignia shields.io grande ("Download APK", color `1A1A1A`). Insignias shields.io: release (`github/v/release/y0ner/folio`), licencia GPLv3, Android 7.0+, Flutter, "offline" / "no tracking". Sin insignias de servicios que no existen (nada de F-Droid, Weblate, chat).
   - Selector de idioma: `English · [Español](README.es.md)` (y al revés en el español).
   - Barra de enlaces internos separada por `&bull;`: Screenshots · Features · Supported formats · Download · Building · Contributing · License. Segunda barra: Website · Releases · Changelog.
   - **Versión visible**: una línea "Current version: **1.0.0** — [release notes](CHANGELOG.md)".
   - `## Screenshots`: las 8 capturas enlazadas, ancho 200, en dos filas de 4 (con `<br/>`), más el gráfico destacado arriba de ellas.
   - `## Description`, `## Features` (agrupadas: Viewing / Files / Comfort / Privacy), `## Supported formats` (tabla Formato | Extensiones | Motor).
   - `## Download & installation`: APK desde Releases, cómo instalar (permitir fuentes desconocidas), cómo dejar Folio como visor predeterminado, y `### APK signing certificate` con el SHA-256 en un bloque de código (como NewPipe).
   - `## Privacy` (sin red, sin datos, explica el permiso INTERNET en una frase).
   - `## Building from source` (requisitos y comandos de `run.sh`), `## Tech stack & architecture` (breve, con la estructura de carpetas de `AGENTS.md` §3 resumida), `## How it was built`.
   - `## Contributing` (enlace a CONTRIBUTING.md), `## Third-party` (enlace a THIRD_PARTY_NOTICES.md), `## License` (GPLv3, con el texto estándar "Folio is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License…").
2. `README.es.md`: la misma estructura traducida con naturalidad (no literal).
3. `CONTRIBUTING.md`: cómo reportar errores (issue con pasos, versión de Android, tipo de archivo), cómo proponer cambios (fork, rama desde `dev`, `./run.sh analyze` y `./run.sh test`, PR a `dev`), estilo (ver `docs/diseno.md`, español en el código).
4. `CHANGELOG.md`: `## [1.0.0] - 2026-11-24` con Added (todas las funciones) y enlace de comparación.
5. Fastlane (formato F-Droid): `title.txt` = "Folio"; `short_description.txt` ≤ 80 caracteres; `full_description.txt` (texto plano o HTML simple de F-Droid, ≤ 4000 caracteres); `changelogs/1.txt` ≤ 500 caracteres. En `en-US` y `es-ES`.
6. Comprueba que los enlaces internos (anclas) coinciden con los encabezados reales.

## Criterios de aceptación

- [ ] `git diff --stat release/v1.0.0` solo muestra archivos permitidos.
- [ ] `wc -m fastlane/metadata/android/*/short_description.txt` ≤ 80 cada uno; `full_description.txt` ≤ 4000.
- [ ] Ningún dato inventado: cada función y número sale de este brief o del código.
- [ ] `grep -n "TODO\|lorem\|example.com" README*.md CONTRIBUTING.md CHANGELOG.md` sin resultados.

## Qué revisará el humano

Que el README se vea profesional en GitHub (claro y oscuro), con capturas, versión, descarga y licencia.
