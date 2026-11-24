import 'package:flutter/material.dart';

/// Colores semánticos de Folio (ver `docs/diseno.md`, sección 2).
///
/// Uso: `context.folio.textSecondary`. Nunca escribir colores sueltos en
/// las pantallas.
@immutable
class FolioColors extends ThemeExtension<FolioColors> {
  const FolioColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.ink,
    required this.onInk,
    required this.accent,
    required this.canvas,
    required this.danger,
    required this.floatingShadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color ink;
  final Color onInk;
  final Color accent;
  final Color canvas;
  final Color danger;

  /// Sombra de los elementos flotantes (vacía en oscuro: ahí se usa borde).
  final List<BoxShadow> floatingShadow;

  static const light = FolioColors(
    background: Color(0xFFF7F7F5),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF0F0EE),
    border: Color(0xFFE6E6E3),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B6B6B),
    textTertiary: Color(0xFF9A9A9A),
    ink: Color(0xFF1A1A1A),
    onInk: Color(0xFFFFFFFF),
    accent: Color(0xFF3B6CF6),
    canvas: Color(0xFFE9E9E6),
    danger: Color(0xFFD93036),
    floatingShadow: [
      BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
    ],
  );

  static const dark = FolioColors(
    background: Color(0xFF0E0E10),
    surface: Color(0xFF17171A),
    surfaceMuted: Color(0xFF1F1F23),
    border: Color(0xFF2A2A2F),
    textPrimary: Color(0xFFEDEDEF),
    textSecondary: Color(0xFFA0A0A8),
    textTertiary: Color(0xFF6E6E76),
    ink: Color(0xFFEDEDEF),
    onInk: Color(0xFF0E0E10),
    accent: Color(0xFF6E92FF),
    canvas: Color(0xFF08080A),
    danger: Color(0xFFFF6369),
    floatingShadow: [],
  );

  @override
  FolioColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? ink,
    Color? onInk,
    Color? accent,
    Color? canvas,
    Color? danger,
    List<BoxShadow>? floatingShadow,
  }) {
    return FolioColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      accent: accent ?? this.accent,
      canvas: canvas ?? this.canvas,
      danger: danger ?? this.danger,
      floatingShadow: floatingShadow ?? this.floatingShadow,
    );
  }

  @override
  FolioColors lerp(FolioColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FolioColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      ink: l(ink, other.ink),
      onInk: l(onInk, other.onInk),
      accent: l(accent, other.accent),
      canvas: l(canvas, other.canvas),
      danger: l(danger, other.danger),
      floatingShadow: t < 0.5 ? floatingShadow : other.floatingShadow,
    );
  }
}

extension FolioColorsContext on BuildContext {
  /// Colores semánticos del tema actual.
  FolioColors get folio => Theme.of(this).extension<FolioColors>()!;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
