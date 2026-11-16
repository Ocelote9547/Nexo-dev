import 'package:flutter/material.dart';

/// ============================================================================
// NEXO Design System — Centralized design tokens for a consistent, premium
// dark and light visual identity across the entire application.
//
// This module defines:
//   - Colors   (background, surfaces, accent, text, status, borders)
//   - Typography (text styles with clear hierarchy)
//   - Spacing   (uniform scale for margins and paddings)
//   - Shapes    (border radii for cards, buttons, inputs)
//   - Elevation (subtle shadow levels)
// ============================================================================

// ---------------------------------------------------------------------------
// Colors — Tema oscuro (Night Blue)
// ---------------------------------------------------------------------------

/// NEXO color palette — Dark theme (Night Blue premium identity).
class NexoDesignColors {
  // Backgrounds — Dark
  static const Color background = Color(0xFF071629); // Main app background (Night Blue)
  static const Color surfaceSecondary = Color(0xFF091A30); // Secondary background
  static const Color surface = Color(0xFF0B1C30); // Surface layer 1 (cards)
  static const Color surfaceElevated = Color(0xFF10243C); // Surface layer 2 (elevated)
  static const Color surfaceHigh = Color(0xFF142B47); // Surface layer 3 (highest contrast)

  // Borders & dividers — Dark
  static const Color border = Color(0xFF223A56); // Discrete border
  static const Color borderFocus = Color(0xFF31577D); // Highlighted border
  static const Color separator = Color(0xFF1A304A); // Separator line

  // Accent (blue NEXO) — Dark
  static const Color accent = Color(0xFF438BFF); // Main electric blue
  static const Color accentBright = Color(0xFF35A7FF); // Light electric blue
  static const Color accentSelected = Color(0xFF1E4A8F); // Selection blue
  static const Color accentSoft = Color(0xFF75B7FF); // Soft blue

  // Text — Dark
  static const Color textPrimary = Color(0xFFF1F5F9); // Primary text
  static const Color textSecondary = Color(0xFFA8B8CC); // Secondary text
  static const Color textTertiary = Color(0xFF74869E); // Tertiary text
  static const Color textDisabled = Color(0xFF52647B); // Disabled text

  // Status
  static const Color success = Color(0xFF22C55E); // Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color favorite = Color(0xFFF4B942); // Favorite star
}

// ---------------------------------------------------------------------------
// Colors — Tema claro
// ---------------------------------------------------------------------------

/// NEXO color palette — Light theme (premium, conservando la identidad NEXO).
class NexoDesignLightColors {
  // Backgrounds — Light
  static const Color background = Color(0xFFF3F6FB); // Main app background
  static const Color surfaceSecondary = Color(0xFFEAEFF8); // Secondary background
  static const Color surface = Color(0xFFFFFFFF); // Surface layer 1 (cards)
  static const Color surfaceElevated = Color(0xFFEAF0F8); // Surface layer 2 (elevated)
  static const Color surfaceHigh = Color(0xFFFFFFFF); // Surface layer 3

  // Borders & dividers — Light
  static const Color border = Color(0xFFDCE5F0); // Discrete border
  static const Color borderFocus = Color(0xFF286FEA); // Highlighted border
  static const Color separator = Color(0xFFE5EBF3); // Separator line

  // Accent (blue NEXO) — Light
  static const Color accent = Color(0xFF286FEA); // Main electric blue
  static const Color accentBright = Color(0xFF3B82F6); // Light electric blue
  static const Color accentSelected = Color(0xFF1E5BD9); // Selection blue
  static const Color accentSoft = Color(0xFF477FCE); // Soft blue with readable contrast

  // Text — Light
  static const Color textPrimary = Color(0xFF14243A); // Primary text
  static const Color textSecondary = Color(0xFF52647C); // Secondary text
  static const Color textTertiary = Color(0xFF7D8CA1); // Tertiary text
  static const Color textDisabled = Color(0xFFA9B7C7); // Disabled text

  // Status
  static const Color success = Color(0xFF15803D); // Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFDC2626); // Red
  static const Color favorite = Color(0xFFD99A18); // Favorite star
}

// ---------------------------------------------------------------------------
// Typography — Compartido por ambos temas
// ---------------------------------------------------------------------------

/// NEXO typography scale — clear hierarchy for readability.
class NexoDesignTypography {
  static const TextStyle nexoName = TextStyle(
    fontSize: 27,
    fontWeight: FontWeight.w600,
    color: NexoDesignColors.textPrimary,
    letterSpacing: -0.4,
    height: 1.2,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: NexoDesignColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: NexoDesignColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle contactCounter = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: NexoDesignColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle sectionLetter = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: NexoDesignColors.textTertiary,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: NexoDesignColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle contactName = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: NexoDesignColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle contactNameMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: NexoDesignColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle contactCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: NexoDesignColors.textSecondary,
    height: 1.3,
  );

  static const TextStyle contactSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: NexoDesignColors.textSecondary,
    height: 1.3,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: NexoDesignColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: NexoDesignColors.textTertiary,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: NexoDesignColors.textTertiary,
    height: 1.3,
  );

  static const TextStyle navLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: NexoDesignColors.textSecondary,
    height: 1.3,
  );

  static const TextStyle birthdayName = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: NexoDesignColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle birthdayDate = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: NexoDesignColors.textSecondary,
    height: 1.3,
  );

  static const TextStyle birthdayDays = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: NexoDesignColors.accent,
    height: 1.3,
  );
}

// ---------------------------------------------------------------------------
// Spacing — Compartido por ambos temas
// ---------------------------------------------------------------------------

/// Uniform spacing scale used for margins and paddings throughout the app.
class NexoDesignSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

// ---------------------------------------------------------------------------
// Shapes — Compartido por ambos temas
// ---------------------------------------------------------------------------

/// Border radii for cards, buttons, inputs, and containers.
class NexoDesignRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 9999.0;
}

// ---------------------------------------------------------------------------
// Elevation — Compartido por ambos temas
// ---------------------------------------------------------------------------

/// Subtle shadow levels — shadows are used sparingly.
class NexoDesignElevation {
  static const double low = 0;
  static const double medium = 1;
  static const double high = 2;
}

// ---------------------------------------------------------------------------
// Component base styles — Compartido por ambos temas
// ---------------------------------------------------------------------------

/// Base button style used by NexoButton variants.
class NexoDesignButtonStyle {
  static const double height = 48;
  static const double smallHeight = 36;
  static const EdgeInsetsGeometry padding =
      EdgeInsets.symmetric(horizontal: NexoDesignSpacing.lg);
}

/// Base input decoration used by NexoTextField.
class NexoDesignInputDecoration {
  static const EdgeInsetsGeometry contentPadding =
      EdgeInsets.symmetric(horizontal: NexoDesignSpacing.lg, vertical: NexoDesignSpacing.md);
  static const BorderSide borderSide = BorderSide(
    color: NexoDesignColors.border,
    width: 1,
  );
  static const BorderSide focusedBorderSide = BorderSide(
    color: NexoDesignColors.accent,
    width: 1.5,
  );
}