import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hybrid typography:
/// - **Manrope** for headlines.
/// - **Work Sans** for body text.
/// - **Inter** for labels (caption / overline).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _manrope({
    required double fontSize,
    required double height,
    required FontWeight fontWeight,
    Color? color,
    double? letterSpacing,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        height: height / fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle _workSans({
    required double fontSize,
    required double height,
    required FontWeight fontWeight,
    Color? color,
    double? letterSpacing,
  }) =>
      GoogleFonts.workSans(
        fontSize: fontSize,
        height: height / fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle _inter({
    required double fontSize,
    required double height,
    required FontWeight fontWeight,
    Color? color,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: fontSize,
        height: height / fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );

  // Headlines (Manrope)
  static TextStyle headlineXl({Color? color}) => _manrope(
        fontSize: 32,
        height: 40,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle headlineLg({Color? color}) => _manrope(
        fontSize: 24,
        height: 32,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle headlineMd({Color? color}) => _manrope(
        fontSize: 20,
        height: 28,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle headlineSm({Color? color}) => _manrope(
        fontSize: 18,
        height: 26,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Body (Work Sans)
  static TextStyle bodyLg({Color? color}) => _workSans(
        fontSize: 18,
        height: 26,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodyMd({Color? color}) => _workSans(
        fontSize: 16,
        height: 24,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodySm({Color? color}) => _workSans(
        fontSize: 14,
        height: 20,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle bodyMdEmphasis({Color? color}) => _workSans(
        fontSize: 16,
        height: 24,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Labels (Inter)
  static TextStyle labelLg({Color? color}) => _inter(
        fontSize: 14,
        height: 18,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.02,
      );

  static TextStyle labelMd({Color? color}) => _inter(
        fontSize: 12,
        height: 16,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.02,
      );

  static TextStyle labelSm({Color? color}) => _inter(
        fontSize: 10,
        height: 14,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.04,
      );

  /// Builds a Material 3 [TextTheme] from the local typography helpers.
  static TextTheme textTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      displayLarge: headlineXl(color: onSurface),
      displayMedium: headlineXl(color: onSurface),
      displaySmall: headlineLg(color: onSurface),
      headlineLarge: headlineXl(color: onSurface),
      headlineMedium: headlineLg(color: onSurface),
      headlineSmall: headlineMd(color: onSurface),
      titleLarge: headlineMd(color: onSurface),
      titleMedium: headlineSm(color: onSurface),
      titleSmall: bodyMdEmphasis(color: onSurface),
      bodyLarge: bodyLg(color: onSurface),
      bodyMedium: bodyMd(color: onSurface),
      bodySmall: bodySm(color: onSurfaceVariant),
      labelLarge: labelLg(color: onSurfaceVariant),
      labelMedium: labelMd(color: onSurfaceVariant),
      labelSmall: labelSm(color: onSurfaceVariant),
    );
  }
}
