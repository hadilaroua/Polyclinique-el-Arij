import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF00897B); // Medical Teal
  static const Color primaryDark = Color(0xFF00695C);
  static const Color primaryLight = Color(0xFFE0F2F1);
  static const Color accent = Color(0xFF0284C7); // Clinical Blue
  static const Color background = Color(0xFFF8FAFC); // Clean slate
  static const Color surface = Colors.white;
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textMain,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textMain,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),
  );

  static Color getRoleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'DOCTOR':
        return const Color(0xFF0284C7);
      case 'NURSE':
        return const Color(0xFF10B981);
      case 'MIDWIFE':
        return const Color(0xFFEC4899);
      case 'TECHNICIAN':
        return const Color(0xFF8B5CF6);
      case 'ADMIN':
        return const Color(0xFFF59E0B);
      default:
        return primary;
    }
  }

  static String getRoleLabel(String? role) {
    switch (role?.toUpperCase()) {
      case 'DOCTOR':
        return 'Médecin Spécialiste';
      case 'NURSE':
        return 'Infirmier Soignant';
      case 'MIDWIFE':
        return 'Sage-femme';
      case 'TECHNICIAN':
        return 'Technicien Plateau';
      case 'ADMIN':
        return 'Administrateur';
      default:
        return 'Personnel Médical';
    }
  }

  static IconData getRoleIcon(String? role) {
    switch (role?.toUpperCase()) {
      case 'DOCTOR':
        return Icons.medical_services_outlined;
      case 'NURSE':
        return Icons.healing_outlined;
      case 'MIDWIFE':
        return Icons.child_care_outlined;
      case 'TECHNICIAN':
        return Icons.biotech_outlined;
      case 'ADMIN':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.person_outline;
    }
  }
}
