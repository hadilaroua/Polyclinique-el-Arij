import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  // Palette Originale — Medical Teal & Clinical Blue
  static const Color primary = Color(0xFF00897B);      // Medical Teal
  static const Color primaryDark = Color(0xFF00695C);  // Dark Teal Header
  static const Color primaryLight = Color(0xFFE0F2F1); // Light Teal Tint
  static const Color accent = Color(0xFF0284C7);        // Clinical Blue
  static const Color background = Color(0xFFF8FAFC);    // Slate Grey BG
  static const Color surface = Colors.white;
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Redirection des anciennes constantes vers la palette originale
  static const Color burntRose = primary;
  static const Color mutedTeal = accent;
  static const Color pearlAqua = primaryLight;
  static const Color neonIce = Color(0xFF80FFEC);
  static const Color plumDark = primaryDark;
  static const Color chocolatePlum = primaryDark;
  static const Color smokyRose = primary;
  static const Color taupeGrey = textMuted;

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'SF Pro Display',
    scaffoldBackgroundColor: background,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),
  );

  // Rôles Staff avec Couleurs d'origine
  static Color getRoleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'DOCTOR':
        return const Color(0xFF0284C7);  // Clinical Blue
      case 'NURSE':
        return const Color(0xFF10B981);  // Mint Green
      case 'MIDWIFE':
        return const Color(0xFFEC4899);  // Rose Pink
      case 'TECHNICIAN':
        return const Color(0xFF8B5CF6);  // Purple
      case 'ADMIN':
        return const Color(0xFFF59E0B);  // Amber
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
        return CupertinoIcons.plus_square_fill;
      case 'NURSE':
        return CupertinoIcons.heart_fill;
      case 'MIDWIFE':
        return CupertinoIcons.person_2_fill;
      case 'TECHNICIAN':
        return CupertinoIcons.lab_flask;
      case 'ADMIN':
        return CupertinoIcons.gear_alt_fill;
      default:
        return CupertinoIcons.person_fill;
    }
  }
}
