import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'folio_colors.dart';
import 'folio_tokens.dart';

/// Temas claro y oscuro de Folio (ver `docs/diseno.md`).
abstract final class FolioTheme {
  static const String fontFamily = 'Inter';

  static ThemeData light() => _build(FolioColors.light, Brightness.light);
  static ThemeData dark() => _build(FolioColors.dark, Brightness.dark);

  static TextTheme _textTheme(FolioColors c) {
    TextStyle s(double size, double height, FontWeight w,
            {double tracking = 0, Color? color}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          height: height / size,
          fontWeight: w,
          letterSpacing: tracking,
          color: color ?? c.textPrimary,
        );
    return TextTheme(
      displaySmall: s(28, 34, FontWeight.w600, tracking: -0.4),
      titleLarge: s(20, 26, FontWeight.w600, tracking: -0.2),
      titleMedium: s(16, 22, FontWeight.w600),
      titleSmall: s(14, 20, FontWeight.w600),
      bodyLarge: s(15, 22, FontWeight.w400),
      bodyMedium: s(14, 20, FontWeight.w400, color: c.textSecondary),
      bodySmall: s(12, 16, FontWeight.w400, color: c.textSecondary),
      labelLarge: s(14, 20, FontWeight.w500),
      labelMedium: s(12, 16, FontWeight.w500, color: c.textSecondary),
      labelSmall: s(11, 14, FontWeight.w500, color: c.textSecondary),
    );
  }

  static ThemeData _build(FolioColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.ink,
      onPrimary: c.onInk,
      secondary: c.accent,
      onSecondary: c.onInk,
      error: c.danger,
      onError: c.onInk,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerHighest: c.surfaceMuted,
      outline: c.border,
      outlineVariant: c.border,
    );
    final text = _textTheme(c);
    final dark = b == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FolioTokens.rMd),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.border,
      splashFactory: InkSparkle.splashFactory,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
        systemOverlayStyle:
            dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.textPrimary, size: FolioTokens.iconBar),
      listTileTheme: ListTileThemeData(
        shape: shape,
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.onInk,
          textStyle: text.labelLarge,
          minimumSize: const Size(64, FolioTokens.minTouch),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textPrimary,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceMuted,
        hintStyle: text.bodyLarge?.copyWith(color: c.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FolioTokens.s16,
          vertical: FolioTokens.s12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FolioTokens.rMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FolioTokens.rMd),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceMuted,
        selectedColor: c.ink,
        labelStyle: text.labelMedium?.copyWith(color: c.textPrimary),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: c.onInk),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioTokens.rPill),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: FolioTokens.s8),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.border,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(FolioTokens.rLg)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: text.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioTokens.rMd),
          side: BorderSide(color: c.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioTokens.rLg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onInk),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FolioTokens.rMd),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          side: WidgetStatePropertyAll(BorderSide(color: c.border)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.ink : c.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.onInk : c.textPrimary,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}
