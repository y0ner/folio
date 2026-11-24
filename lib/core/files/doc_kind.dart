import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../theme/folio_colors.dart';

/// Tipos de documento que Folio sabe mostrar.
enum DocKind {
  pdf('PDF', 'PDF', Color(0xFFE5484D), {'pdf'}),
  word('Word', 'DOC', Color(0xFF3E63DD), {'docx', 'docm', 'dotx'}),
  excel('Excel', 'XLS', Color(0xFF30A46C), {'xlsx', 'xlsm', 'xls', 'csv'}),
  powerpoint('PowerPoint', 'PPT', Color(0xFFF76B15), {'pptx', 'ppsx', 'pptm'});

  const DocKind(this.label, this.abbreviation, this.baseColor, this.extensions);

  /// Nombre visible ("Word").
  final String label;

  /// Abreviatura para la insignia ("DOC").
  final String abbreviation;

  /// Color de identidad del tipo (igual en claro y oscuro).
  final Color baseColor;

  /// Extensiones en minúsculas, sin punto.
  final Set<String> extensions;

  /// Color del tipo.
  Color color(BuildContext context) => baseColor;

  /// Fondo tintado de la insignia: 12 % en claro, 18 % en oscuro.
  Color tint(BuildContext context) =>
      baseColor.withValues(alpha: context.isDark ? 0.18 : 0.12);

  /// Todas las extensiones admitidas.
  static Set<String> get allExtensions =>
      {for (final k in values) ...k.extensions};

  /// Deduce el tipo por la extensión del nombre o ruta; `null` si no se admite.
  static DocKind? fromName(String nameOrPath) {
    final ext = p.extension(nameOrPath).replaceFirst('.', '').toLowerCase();
    for (final k in values) {
      if (k.extensions.contains(ext)) return k;
    }
    return null;
  }

  /// Deduce el tipo por el tipo MIME; `null` si no se reconoce.
  static DocKind? fromMime(String? mime) {
    if (mime == null) return null;
    final m = mime.toLowerCase();
    if (m == 'application/pdf') return pdf;
    if (m.contains('wordprocessingml') || m == 'application/msword') {
      return word;
    }
    if (m.contains('spreadsheetml') ||
        m == 'application/vnd.ms-excel' ||
        m == 'text/csv' ||
        m == 'text/comma-separated-values') {
      return excel;
    }
    if (m.contains('presentationml') ||
        m == 'application/vnd.ms-powerpoint') {
      return powerpoint;
    }
    return null;
  }
}
