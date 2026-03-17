import 'package:flutter/material.dart';

/// e-bi brand color palette derived from the corporate logo.
class EbiColors {
  EbiColors._();

  // ── Brand Colors ──
  static const Color primaryBlue = Color(0xFF009FE3);
  static const Color secondaryCyan = Color(0xFF29C4F0);
  static const Color darkNavy = Color(0xFF0B3D59);

  // ── Background ──
  static const Color bgMeshWork = Color(0xFFF5F7FA);
  static const Color bgMeshPortal = Color(0xFFFAFDFF);
  static const Color white = Color(0xFFFFFFFF);

  // ── Text ──
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // ── Status ──
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Divider & Border ──
  static const Color divider = Color(0xFFE5E7EB);
  static const Color border = Color(0xFFD1D5DB);

  // ── Primary Swatch ──
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF009FE3,
    <int, Color>{
      50: Color(0xFFE6F5FC),
      100: Color(0xFFB3E2F7),
      200: Color(0xFF80CFF2),
      300: Color(0xFF4DBCED),
      400: Color(0xFF26ADE8),
      500: Color(0xFF009FE3),
      600: Color(0xFF008FCC),
      700: Color(0xFF007DB3),
      800: Color(0xFF006B99),
      900: Color(0xFF004D6D),
    },
  );
}
