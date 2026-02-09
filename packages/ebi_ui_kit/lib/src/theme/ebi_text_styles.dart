import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/src/theme/ebi_colors.dart';

/// e-bi text style definitions.
class EbiTextStyles {
  EbiTextStyles._();

  // ── Headings ──
  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: EbiColors.darkNavy,
    height: 1.3,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: EbiColors.darkNavy,
    height: 1.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: EbiColors.darkNavy,
    height: 1.4,
  );

  // ── Body ──
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: EbiColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: EbiColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: EbiColors.textSecondary,
    height: 1.5,
  );

  // ── Labels ──
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: EbiColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: EbiColors.textSecondary,
    letterSpacing: 0.5,
  );

  // ── Numbers (monospace for data displays) ──
  static const TextStyle number = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    fontFamily: 'RobotoMono',
    color: EbiColors.textPrimary,
  );

  static const TextStyle numberLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontFamily: 'RobotoMono',
    color: EbiColors.darkNavy,
  );
}
