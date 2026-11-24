# Folio · Sistema de diseño

Folio es un **visor** (solo lectura) de PDF, Word, Excel y PowerPoint para
Android. La interfaz debe desaparecer: el protagonista es el documento.

## 1. Principios

1. **El documento manda.** Cromado mínimo; en el visor, un toque sobre el
   contenido oculta y muestra las barras (modo inmersivo).
2. **Tinta y papel.** Interfaz monocroma (neutros cálidos). El único color
   lo aportan los **tipos de archivo** (PDF rojo, Word azul, Excel verde,
   PowerPoint naranja), para reconocerlos de un vistazo.
3. **Una acción principal por pantalla.** Inicio → "Abrir archivo". Visor → leer.
4. **Claro y oscuro de primera clase.** Ningún color fijo fuera de los tokens.
5. **Accesible.** Áreas táctiles ≥ 48 dp, contraste AA, textos escalables.

Referencias: Apple Files (organización por recientes y tipo), Linear y
Vercel Geist (neutros precisos, tinta como color de acción), Radix Colors
(escalas de color para claro/oscuro), iA Writer (lectura sin distracciones) y
la propuesta de diseño móvil de MuPDF (pantalla completa, toque para mostrar
controles).

## 2. Color (tokens)

Se acceden **solo** con `context.folio` (`FolioColors`, un `ThemeExtension`
en `lib/core/theme/folio_colors.dart`) o con el `ColorScheme` del tema.

| Token | Claro | Oscuro | Uso |
| :--- | :--- | :--- | :--- |
| `background` | `#F7F7F5` | `#0E0E10` | Fondo de pantallas |
| `surface` | `#FFFFFF` | `#17171A` | Tarjetas, barras, hojas |
| `surfaceMuted` | `#F0F0EE` | `#1F1F23` | Campo de búsqueda, chips inactivos |
| `border` | `#E6E6E3` | `#2A2A2F` | Divisores y bordes de 1 px |
| `textPrimary` | `#1A1A1A` | `#EDEDEF` | Títulos y texto principal |
| `textSecondary` | `#6B6B6B` | `#A0A0A8` | Metadatos |
| `textTertiary` | `#9A9A9A` | `#6E6E76` | Ayudas, marcadores de posición |
| `ink` | `#1A1A1A` | `#EDEDEF` | Botón principal (relleno) |
| `onInk` | `#FFFFFF` | `#0E0E10` | Texto sobre `ink` |
| `accent` | `#3B6CF6` | `#6E92FF` | Foco, selección, enlaces, progreso |
| `canvas` | `#E9E9E6` | `#08080A` | Fondo detrás de las páginas del documento |
| `danger` | `#D93036` | `#FF6369` | Errores |

Colores por tipo (`DocKind.color(context)`; mismo tono en claro y oscuro, con
fondo tintado al 12 % en claro y 18 % en oscuro):

| Tipo | Color | Abreviatura |
| :--- | :--- | :--- |
| PDF | `#E5484D` | PDF |
| Word | `#3E63DD` | DOC |
| Excel | `#30A46C` | XLS |
| PowerPoint | `#F76B15` | PPT |

## 3. Tipografía

**Inter** (empaquetada, sin red) para toda la interfaz. Escala en
`FolioType` (`lib/core/theme/folio_theme.dart`, mapeada al `TextTheme`):

| Estilo | Tamaño / alto | Peso | Uso |
| :--- | :--- | :--- | :--- |
| `displaySmall` | 28 / 34 | 600, tracking −0.4 | Título "Folio" en inicio |
| `titleLarge` | 20 / 26 | 600, tracking −0.2 | Títulos de pantalla |
| `titleMedium` | 16 / 22 | 600 | Nombre de archivo en el visor, encabezados |
| `bodyLarge` | 15 / 22 | 400 | Texto principal, nombres en listas |
| `bodyMedium` | 14 / 20 | 400 | Texto secundario |
| `labelLarge` | 14 / 20 | 500 | Botones |
| `labelMedium` | 12 / 16 | 500 | Chips, metadatos, contador de páginas |

Los documentos (Word/PowerPoint/Excel) se renderizan con sus propias fuentes;
para Calibri y Cambria se empaquetan Carlito y Caladea (métricamente
compatibles).

## 4. Espaciado, radios y movimiento

`FolioTokens` (`lib/core/theme/folio_tokens.dart`):

- Espaciado (rejilla de 4): `s4 s8 s12 s16 s20 s24 s32 s48`. Margen lateral de
  pantalla: **20**.
- Radios: `rSm 8` (chips), `rMd 12` (filas, tarjetas, campos), `rLg 16`
  (hojas), `rPill 999`.
- Bordes: 1 px `border`. **Sin sombras** salvo en elementos flotantes
  (indicador de página, botón "Abrir"): sombra suave `0 4 16 rgba(0,0,0,.08)`
  en claro, ninguna en oscuro (se usa borde).
- Movimiento: `fast 150 ms`, `normal 220 ms`, curva `easeOutCubic`.
- Iconos: `lucide_icons_flutter` (trazo fino), 20 dp en listas, 22 dp en barras.

## 5. Pantallas

### Inicio
- Encabezado grande: "Folio" (`displaySmall`) + botón de ajustes (icono) a la derecha.
- Campo de búsqueda (`surfaceMuted`, radio 12, icono lupa) que filtra los recientes por nombre.
- Chips de filtro por tipo: Todos · PDF · Word · Excel · PowerPoint (los de tipo llevan un punto de su color).
- Lista "Recientes" agrupada por **Hoy / Esta semana / Anteriores**. Cada fila:
  insignia del tipo (cuadro 40 dp radio 10, fondo tintado, abreviatura),
  nombre (1 línea, elipsis), metadatos `tamaño · fecha` (`labelMedium`,
  `textSecondary`) y menú (compartir, quitar de recientes).
- Botón flotante tipo píldora, abajo al centro: **"Abrir archivo"** (relleno `ink`).
- Estado vacío: icono grande en trazo fino, "Abre tu primer documento" y una línea de ayuda.

### Visor
- Barra superior `surface` con borde inferior: atrás, nombre del archivo
  (`titleMedium`, 1 línea) con la insignia pequeña del tipo, y acciones
  (buscar si aplica, compartir, más → información del archivo, abrir con otra app).
- Fondo `canvas`; páginas con sombra muy suave.
- Toque simple en el contenido → oculta/muestra barras (220 ms, fundido + desplazamiento).
- Indicador flotante en píldora `3 / 24` abajo al centro (PDF y PowerPoint).
- Excel: pestañas de hojas en una barra inferior desplazable.
- Errores: pantalla con icono, mensaje claro en español y acción ("Abrir con otra app").

### Ajustes
- Apariencia: Sistema / Claro / Oscuro (control segmentado).
- Acerca de: versión y licencias de terceros.

## 6. Textos

Español neutro, frases cortas, sin tecnicismos: "No se pudo abrir el archivo",
"Este documento está protegido con contraseña".
