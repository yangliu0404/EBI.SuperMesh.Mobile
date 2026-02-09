import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/src/theme/ebi_colors.dart';

/// Builds a complete ThemeData for e-bi apps.
class EbiTheme {
  EbiTheme._();

  /// MeshWork (employee) theme — cool gray background.
  static ThemeData meshWork() => _buildTheme(EbiColors.bgMeshWork);

  /// MeshPortal (client) theme — clean white background.
  static ThemeData meshPortal() => _buildTheme(EbiColors.bgMeshPortal);

  static ThemeData _buildTheme(Color scaffoldBg) {
    return ThemeData(
      useMaterial3: true,
      primarySwatch: EbiColors.primarySwatch,
      colorScheme: ColorScheme.fromSeed(
        seedColor: EbiColors.primaryBlue,
        primary: EbiColors.primaryBlue,
        secondary: EbiColors.secondaryCyan,
        surface: EbiColors.white,
        error: EbiColors.error,
      ),
      scaffoldBackgroundColor: scaffoldBg,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: EbiColors.primaryBlue,
        foregroundColor: EbiColors.white,
        elevation: 0,
        centerTitle: true,
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: EbiColors.darkNavy,
        selectedItemColor: EbiColors.primaryBlue,
        unselectedItemColor: EbiColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Card
      cardTheme: CardThemeData(
        color: EbiColors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EbiColors.primaryBlue,
          foregroundColor: EbiColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EbiColors.primaryBlue,
          side: const BorderSide(color: EbiColors.primaryBlue),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EbiColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: EbiColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: EbiColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: EbiColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: EbiColors.error),
        ),
        hintStyle: const TextStyle(
          color: EbiColors.textHint,
          fontSize: 14,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: EbiColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
