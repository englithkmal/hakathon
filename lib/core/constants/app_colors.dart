import 'package:flutter/material.dart';

/// WafferApp brand palette.
///
/// The semantic tokens (`primary`, `surface`, `onSurface`, …) are sourced
/// **verbatim from the Figma design** (`6vgP9Ke4v57ATbHAJkOcCq`) — a
/// Forest-Green / Sage-Mist interpretation of the brand. They are what the
/// app actually renders.
///
/// The Filament admin panel ramp lives alongside (`teal*`, `green*`,
/// `slate*`, `sky*`, `amber*`, `rose*`) so backend-driven UI (chips,
/// status pills, charts) can mirror the panel without affecting the
/// product chrome.
///
/// Filament reference (`AdminPanelProvider.php`):
/// • Primary  — Teal     `#2BA98C` (`teal500`)
/// • Success  — Green    `#34A85A` (`green500`)
/// • Gray     — Slate    `#64748B` (`slate500`)
/// • Info     — Sky      `#0EA5E9` (`sky500`)
/// • Warning  — Amber    `#F59E0B` (`amber500`)
/// • Danger   — Rose     `#F43F5E` (`rose500`)
class AppColors {
  AppColors._();

  // ════════════ Brand (Forest Green — matches Figma) ════════════════

  // Primary (Forest Green)
  static const Color primary = Color(0xFF0F5238);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF2D6A4F);
  static const Color onPrimaryContainer = Color(0xFFA8E7C5);
  static const Color inversePrimary = Color(0xFF95D4B3);
  static const Color surfaceTint = Color(0xFF2C694E);

  // Secondary (Sage Mist)
  static const Color secondary = Color(0xFF57615C);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD8E2DC);
  static const Color onSecondaryContainer = Color(0xFF5B6560);

  // Tertiary (Mint Pastel)
  static const Color tertiary = Color(0xFF0D5237);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF2C6A4E);
  static const Color onTertiaryContainer = Color(0xFFA7E7C4);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Surfaces (light) — warm off-white scheme from Figma
  static const Color background = Color(0xFFF8F9FA);
  static const Color onBackground = Color(0xFF191C1D);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color surfaceDim = Color(0xFFD9DADB);
  static const Color surfaceBright = Color(0xFFF8F9FA);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F4F5);
  static const Color surfaceContainer = Color(0xFFEDEEEF);
  static const Color surfaceContainerHigh = Color(0xFFE7E8E9);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E4);
  static const Color surfaceVariant = Color(0xFFE1E3E4);
  static const Color onSurface = Color(0xFF191C1D);
  static const Color onSurfaceVariant = Color(0xFF404943);
  static const Color inverseSurface = Color(0xFF2E3132);
  static const Color inverseOnSurface = Color(0xFFF0F1F2);
  static const Color outline = Color(0xFF707973);
  static const Color outlineVariant = Color(0xFFBFC9C1);

  // Fixed accents (used by HomeInsightTile, balance card glow, etc.)
  static const Color primaryFixed = Color(0xFFB1F0CE);
  static const Color primaryFixedDim = Color(0xFF95D4B3);
  static const Color onPrimaryFixed = Color(0xFF002114);
  static const Color onPrimaryFixedVariant = Color(0xFF0E5138);

  static const Color secondaryFixed = Color(0xFFDBE5DF);
  static const Color secondaryFixedDim = Color(0xFFBFC9C3);
  static const Color onSecondaryFixed = Color(0xFF151D1A);
  static const Color onSecondaryFixedVariant = Color(0xFF3F4945);

  static const Color tertiaryFixed = Color(0xFFB0F1CC);
  static const Color tertiaryFixedDim = Color(0xFF94D4B1);
  static const Color onTertiaryFixed = Color(0xFF002113);
  static const Color onTertiaryFixedVariant = Color(0xFF0C5136);

  // Dark surfaces (Material 3 dark variants — derived for night mode)
  static const Color darkBackground = Color(0xFF0E1311);
  static const Color darkSurface = Color(0xFF0E1311);
  static const Color darkSurfaceContainerLowest = Color(0xFF080D0B);
  static const Color darkSurfaceContainerLow = Color(0xFF161B19);
  static const Color darkSurfaceContainer = Color(0xFF1A1F1D);
  static const Color darkSurfaceContainerHigh = Color(0xFF252A28);
  static const Color darkSurfaceContainerHighest = Color(0xFF2F3432);
  static const Color darkOnSurface = Color(0xFFE1E3E0);
  static const Color darkOnSurfaceVariant = Color(0xFFBFC9C1);
  static const Color darkOutline = Color(0xFF8A938D);
  static const Color darkOutlineVariant = Color(0xFF404943);

  /// Soft mint highlight used inside cards (per DESIGN.md "mint accent",
  /// also `#ECFDF5` in the Figma — kept here at the original tint for
  /// continuity with existing widgets).
  static const Color mintAccent = Color(0xFFD8F3DC);

  /// Emerald `50` — the chip/icon background tint observed throughout the
  /// Figma (e.g. quick-action icons, savings goal badges).
  static const Color brandTint = Color(0xFFECFDF5);

  /// Emerald `700` — used by Figma for sub-labels and small accents on
  /// branded surfaces (e.g. "+2.5% هذا الشهر" delta on the balance card).
  static const Color brandAccent = Color(0xFF047857);

  // ════════════ Filament admin panel ramps (utility) ════════════════
  // These mirror the Filament `AdminPanelProvider.php` palette so any
  // backend-driven UI (status pills, segments, charts) can stay in lock-
  // step with the panel without affecting the Figma-defined chrome above.

  // Teal (Filament `primary`)
  static const Color teal50 = Color(0xFFEEFBF8);
  static const Color teal100 = Color(0xFFD5F4EC);
  static const Color teal200 = Color(0xFFABE7D7);
  static const Color teal300 = Color(0xFF7FD7C0);
  static const Color teal400 = Color(0xFF52C2A6);
  static const Color teal500 = Color(0xFF2BA98C);
  static const Color teal600 = Color(0xFF1F8B8E);
  static const Color teal700 = Color(0xFF1A6E73);
  static const Color teal800 = Color(0xFF15565B);
  static const Color teal900 = Color(0xFF103F44);
  static const Color teal950 = Color(0xFF082529);

  // Green (Filament `success`)
  static const Color green50 = Color(0xFFF1FBF4);
  static const Color green100 = Color(0xFFDBF5E1);
  static const Color green200 = Color(0xFFB7EBC4);
  static const Color green300 = Color(0xFF85DA9D);
  static const Color green400 = Color(0xFF54C374);
  static const Color green500 = Color(0xFF34A85A);
  static const Color green600 = Color(0xFF258846);
  static const Color green700 = Color(0xFF206A39);
  static const Color green800 = Color(0xFF1A5430);
  static const Color green900 = Color(0xFF143F25);
  static const Color green950 = Color(0xFF082516);

  // Slate (Filament `gray`) — Tailwind
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate950 = Color(0xFF020617);

  // Sky (Filament `info`) — Tailwind
  static const Color sky50 = Color(0xFFF0F9FF);
  static const Color sky100 = Color(0xFFE0F2FE);
  static const Color sky200 = Color(0xFFBAE6FD);
  static const Color sky300 = Color(0xFF7DD3FC);
  static const Color sky400 = Color(0xFF38BDF8);
  static const Color sky500 = Color(0xFF0EA5E9);
  static const Color sky600 = Color(0xFF0284C7);
  static const Color sky700 = Color(0xFF0369A1);
  static const Color sky800 = Color(0xFF075985);
  static const Color sky900 = Color(0xFF0C4A6E);
  static const Color sky950 = Color(0xFF082F49);

  // Amber (Filament `warning`) — Tailwind
  static const Color amber50 = Color(0xFFFFFBEB);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber200 = Color(0xFFFDE68A);
  static const Color amber300 = Color(0xFFFCD34D);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber800 = Color(0xFF92400E);
  static const Color amber900 = Color(0xFF78350F);
  static const Color amber950 = Color(0xFF451A03);

  // Rose (Filament `danger`) — Tailwind
  static const Color rose50 = Color(0xFFFFF1F2);
  static const Color rose100 = Color(0xFFFFE4E6);
  static const Color rose200 = Color(0xFFFECDD3);
  static const Color rose300 = Color(0xFFFDA4AF);
  static const Color rose400 = Color(0xFFFB7185);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color rose600 = Color(0xFFE11D48);
  static const Color rose700 = Color(0xFFBE123C);
  static const Color rose800 = Color(0xFF9F1239);
  static const Color rose900 = Color(0xFF881337);
  static const Color rose950 = Color(0xFF4C0519);

  // Convenience semantic helpers (mirror Filament names) — useful for
  // chips/pills that need to communicate state without going through the
  // Material `ColorScheme`.
  static const Color success = green500;
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = green100;
  static const Color onSuccessContainer = green900;

  static const Color warning = amber500;
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = amber100;
  static const Color onWarningContainer = amber900;

  static const Color info = sky500;
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoContainer = sky100;
  static const Color onInfoContainer = sky900;
}
