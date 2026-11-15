import 'package:flutter/material.dart';

import '../../core/design/nexo_design_system.dart';

/// Backward-compatible color aliases referencing the central design system.
/// Existing code using NexoColors.* continues to work unchanged.
class NexoColors {
  static const Color background = NexoDesignColors.background;
  static const Color surface = NexoDesignColors.surface;
  static const Color surfaceElevated = NexoDesignColors.surfaceElevated;
  static const Color surfaceHigh = NexoDesignColors.surfaceHigh;
  static const Color border = NexoDesignColors.border;
  static const Color borderFocus = NexoDesignColors.borderFocus;
  static const Color accent = NexoDesignColors.accent;
  static const Color accentSoft = NexoDesignColors.accentSoft;
  static const Color textPrimary = NexoDesignColors.textPrimary;
  static const Color textSecondary = NexoDesignColors.textSecondary;
  static const Color textTertiary = NexoDesignColors.textTertiary;
  static const Color textDisabled = NexoDesignColors.textDisabled;
  static const Color success = NexoDesignColors.success;
  static const Color warning = NexoDesignColors.warning;
  static const Color error = NexoDesignColors.error;
  static const Color favorite = NexoDesignColors.favorite;
}

/// Backward-compatible spacing aliases.
class NexoSpacing {
  static const double xs = NexoDesignSpacing.xs;
  static const double sm = NexoDesignSpacing.sm;
  static const double md = NexoDesignSpacing.md;
  static const double lg = NexoDesignSpacing.lg;
  static const double xl = NexoDesignSpacing.xl;
  static const double xxl = NexoDesignSpacing.xxl;
}

/// Backward-compatible border radius aliases.
class NexoRadii {
  static const double sm = NexoDesignRadii.sm;
  static const double md = NexoDesignRadii.md;
  static const double lg = NexoDesignRadii.lg;
  static const double xl = NexoDesignRadii.xl;
}

/// NEXO theme — Tema claro y oscuro construidos sobre el design system.
class NexoTheme {
  /// Tema oscuro (Night Blue premium) — Predeterminado para instalaciones nuevas.
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: NexoDesignColors.background,
      colorScheme: const ColorScheme.dark(
        primary: NexoDesignColors.accent,
        secondary: NexoDesignColors.accentSoft,
        surface: NexoDesignColors.surface,
        error: NexoDesignColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: NexoDesignColors.textPrimary,
        onError: Colors.white,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NexoDesignColors.background,
        foregroundColor: NexoDesignColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: NexoDesignColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: NexoDesignColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.md),
          side: const BorderSide(color: NexoDesignColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: NexoDesignSpacing.lg,
          vertical: NexoDesignSpacing.sm,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NexoDesignColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.full),
          borderSide: const BorderSide(color: NexoDesignColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.full),
          borderSide: const BorderSide(color: NexoDesignColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.full),
          borderSide: const BorderSide(color: NexoDesignColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: NexoDesignColors.textSecondary),
        hintStyle: const TextStyle(color: NexoDesignColors.textTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NexoDesignColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: NexoDesignSpacing.xl,
            vertical: NexoDesignSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NexoDesignRadii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NexoDesignColors.accent,
        ),
      ),
      iconTheme: const IconThemeData(color: NexoDesignColors.textSecondary, size: 22),
      dividerTheme: const DividerThemeData(
        color: NexoDesignColors.border,
        thickness: 1,
        space: NexoDesignSpacing.lg,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NexoDesignColors.surface,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: NexoDesignColors.accent);
          }
          return const IconThemeData(color: NexoDesignColors.textTertiary);
        }),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: NexoDesignColors.textPrimary,
        displayColor: NexoDesignColors.textPrimary,
      ).copyWith(
        headlineLarge: const TextStyle(
          color: NexoDesignColors.textPrimary,
          fontSize: 27,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          height: 1.2,
        ),
        headlineMedium: const TextStyle(
          color: NexoDesignColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          height: 1.3,
        ),
        titleLarge: const TextStyle(
          color: NexoDesignColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          color: NexoDesignColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: const TextStyle(
          color: NexoDesignColors.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: const TextStyle(
          color: NexoDesignColors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
        bodySmall: const TextStyle(
          color: NexoDesignColors.textTertiary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  /// Tema claro premium — Conserva la misma identidad visual NEXO.
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: NexoDesignLightColors.background,
      colorScheme: const ColorScheme.light(
        primary: NexoDesignLightColors.accent,
        secondary: NexoDesignLightColors.accentSoft,
        surface: NexoDesignLightColors.surface,
        error: NexoDesignLightColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: NexoDesignLightColors.textPrimary,
        onError: Colors.white,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: NexoDesignLightColors.background,
        foregroundColor: NexoDesignLightColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: NexoDesignLightColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: NexoDesignLightColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.md),
          side: const BorderSide(color: NexoDesignLightColors.border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: NexoDesignSpacing.lg,
          vertical: NexoDesignSpacing.sm,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NexoDesignLightColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.full),
          borderSide: const BorderSide(color: NexoDesignLightColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.full),
          borderSide: const BorderSide(color: NexoDesignLightColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NexoDesignRadii.full),
          borderSide: const BorderSide(color: NexoDesignLightColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: NexoDesignLightColors.textSecondary),
        hintStyle: const TextStyle(color: NexoDesignLightColors.textTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NexoDesignLightColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: NexoDesignSpacing.xl,
            vertical: NexoDesignSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NexoDesignRadii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NexoDesignLightColors.accent,
        ),
      ),
      iconTheme: const IconThemeData(color: NexoDesignLightColors.textSecondary, size: 22),
      dividerTheme: const DividerThemeData(
        color: NexoDesignLightColors.border,
        thickness: 1,
        space: NexoDesignSpacing.lg,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: NexoDesignLightColors.surface,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: NexoDesignLightColors.accent);
          }
          return const IconThemeData(color: NexoDesignLightColors.textTertiary);
        }),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: NexoDesignLightColors.textPrimary,
        displayColor: NexoDesignLightColors.textPrimary,
      ).copyWith(
        headlineLarge: const TextStyle(
          color: NexoDesignLightColors.textPrimary,
          fontSize: 27,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          height: 1.2,
        ),
        headlineMedium: const TextStyle(
          color: NexoDesignLightColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          height: 1.3,
        ),
        titleLarge: const TextStyle(
          color: NexoDesignLightColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: const TextStyle(
          color: NexoDesignLightColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: const TextStyle(
          color: NexoDesignLightColors.textPrimary,
          fontSize: 15,
          height: 1.4,
        ),
        bodyMedium: const TextStyle(
          color: NexoDesignLightColors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
        bodySmall: const TextStyle(
          color: NexoDesignLightColors.textTertiary,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}