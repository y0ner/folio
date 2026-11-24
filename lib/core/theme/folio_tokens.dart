import 'package:flutter/animation.dart';

/// Medidas del sistema de diseño (ver `docs/diseno.md`, sección 4).
abstract final class FolioTokens {
  // Espaciado (rejilla de 4).
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;

  /// Margen lateral de las pantallas.
  static const double gutter = 20;

  // Radios.
  static const double rSm = 8;
  static const double rMd = 12;
  static const double rLg = 16;
  static const double rPill = 999;

  /// Área táctil mínima.
  static const double minTouch = 48;

  // Iconos.
  static const double iconList = 20;
  static const double iconBar = 22;

  // Movimiento.
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Curve curve = Curves.easeOutCubic;
}
