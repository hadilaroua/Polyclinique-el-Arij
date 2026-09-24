import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Design System — Polyclinique El Arij (Djerba)
/// Mediterranean Clinical Precision & iOS HIG-informed Glassmorphism
class AppTheme {
  // ==========================================================================
  // PALETTE OFFICIELLE DU DESIGN SYSTEM (Mediterranean Clinical Precision)
  // ==========================================================================
  
  /// Primary Institutional Navy (#001026 / #0B2545)
  static const Color primary = Color(0xFF001026);
  static const Color primaryNavy = Color(0xFF0B2545);
  static const Color primaryContainer = Color(0xFF0B2545);
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = Color(0xFF778DB2);

  /// Secondary Mediterranean Bondi Blue (#006688 / #007EA7)
  static const Color secondary = Color(0xFF006688);
  static const Color secondaryBondi = Color(0xFF007EA7);
  static const Color secondaryContainer = Color(0xFF78D1FE);
  static const Color onSecondaryContainer = Color(0xFF005977);
  static const Color secondaryFixed = Color(0xFFC2E8FF);
  static const Color secondaryFixedDim = Color(0xFF78D1FE);

  /// Tertiary Ocean Teal (#00A896 / #79F7E3)
  static const Color tertiary = Color(0xFF00120F);
  static const Color tertiaryTeal = Color(0xFF00A896);
  static const Color tertiaryFixed = Color(0xFF79F7E3);
  static const Color tertiaryFixedDim = Color(0xFF59DBC7);
  static const Color tertiaryContainer = Color(0xFF002A25);
  static const Color onTertiaryContainer = Color(0xFF009D8C);

  /// Sky & Atmospheric Tints
  static const Color skyTint = Color(0xFFE0F2FE);
  static const Color primaryFixed = Color(0xFFD5E3FF);
  static const Color primaryFixedDim = Color(0xFFB1C7F0);

  /// Surfaces & Backgrounds
  static const Color surface = Color(0xFFF8F9FF);
  static const Color canvasBg = Color(0xFFF8FAFC);
  static const Color background = Color(0xFFF8F9FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD3E4FE);
  static const Color surfaceDim = Color(0xFFCBDBF5);
  static const Color surfaceGlass = Color(0xC7FFFFFF); // rgba(255,255,255,0.78)

  /// Typographie & Neutres
  static const Color onSurface = Color(0xFF0B1C30);
  static const Color onSurfaceVariant = Color(0xFF44474E);
  static const Color textMain = Color(0xFF0B1C30);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color outline = Color(0xFF74777F);
  static const Color outlineVariant = Color(0xFFC4C6CF);

  /// Vital Clinical Tokens (Triage Médical)
  static const Color vitalEmergency = Color(0xFFE11D48); // Rouge Urgence / NEWS ≥ 5 / Troponine+
  static const Color vitalScheduled = Color(0xFFF59E0B); // Ambre / Surveillance / Attention
  static const Color vitalDischarged = Color(0xFF10B981); // Émeraude / Normal / Validé / De garde
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ==========================================================================
  // PALETTE DARK MODE (OLED / Électron)
  // ==========================================================================
  static const Color darkBackground = Color(0xFF0B131E);
  static const Color darkSurface = Color(0xFF121E2E);
  static const Color darkCard = Color(0xFF1B293C);
  static const Color darkElevated = Color(0xFF22344B);
  static const Color darkTextMain = Color(0xFFF1F5F9);
  static const Color darkTextMuted = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF28394E);
  static const Color darkPrimary = Color(0xFF78D1FE);
  static const Color darkSecondary = Color(0xFF59DBC7);

  // ==========================================================================
  // RÉTROCOMPATIBILITÉ AVEC L'ANCIENNE CHARTE
  // ==========================================================================
  static const Color tropicalTeal = Color(0xFF007EA7);
  static const Color bondiBlue = Color(0xFF006688);
  static const Color emerald = Color(0xFF10B981);
  static const Color oceanMist = Color(0xFF00A896);
  static const Color willowGreen = Color(0xFF10B981);
  static const Color lightGreen = Color(0xFF79F7E3);
  static const Color limeCream = Color(0xFFE0F2FE);
  static const Color primaryDark = Color(0xFF001026);
  static const Color primaryLight = Color(0xFFE0F2FE);
  static const Color accent = Color(0xFF006688);
  static const Color turquoise = Color(0xFF00A896);
  static const Color purple = Color(0xFF006688);
  static const Color purpleLight = Color(0xFFE0F2FE);
  static const Color purpleDark = Color(0xFF001026);
  static const Color success = vitalDischarged;
  static const Color warning = vitalScheduled;
  static const Color danger = vitalEmergency;
  static const Color info = secondary;
  static const Color darkAccent = Color(0xFF59DBC7);
  static const Color darkTurquoise = Color(0xFF79F7E3);
  static const Color darkSuccess = Color(0xFF34D399);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkDanger = Color(0xFFF87171);
  static const Color darkInfo = Color(0xFF78D1FE);
  static const Color darkPurple = Color(0xFF78D1FE);
  static const Color darkPurpleLight = Color(0xFF1B293C);
  static const Color burntRose = primary;
  static const Color mutedTeal = accent;
  static const Color pearlAqua = primaryLight;
  static const Color neonIce = turquoise;
  static const Color plumDark = primaryDark;
  static const Color chocolatePlum = primaryDark;
  static const Color smokyRose = primary;
  static const Color taupeGrey = textMuted;
  static const Color darkBg = darkBackground;
  static const Color darkSurf = darkSurface;

  // Palette Maternité / Sage-femme
  static const Color midwifePrimary = Color(0xFFD946EF);
  static const Color midwifeDark = Color(0xFFA21CAF);
  static const Color midwifeLight = Color(0xFFFAE8FF);
  static const Color midwifeAccent = Color(0xFFE879F9);

  // ==========================================================================
  // GESTION DU THÈME
  // ==========================================================================
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static const String _themePrefKey = 'polyclinique_arij_theme_v2';

  static bool get isDark => themeModeNotifier.value == ThemeMode.dark;

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Future<void> initTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_themePrefKey);
      switch (saved) {
        case 'dark':
          themeModeNotifier.value = ThemeMode.dark;
          break;
        case 'light':
          themeModeNotifier.value = ThemeMode.light;
          break;
        case 'system':
        default:
          themeModeNotifier.value = ThemeMode.system;
          break;
      }
    } catch (_) {}
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String val;
      switch (mode) {
        case ThemeMode.dark:
          val = 'dark';
          break;
        case ThemeMode.light:
          val = 'light';
          break;
        default:
          val = 'system';
      }
      await prefs.setString(_themePrefKey, val);
    } catch (_) {}
  }

  static Future<void> toggleTheme() async {
    final next = themeModeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(next);
  }

  // ==========================================================================
  // HELPERS CONTEXTUELS DE COULEURS
  // ==========================================================================
  static Color cardColor(BuildContext context) =>
      isDarkMode(context) ? darkCard : surfaceContainerLowest;

  static Color surfaceColor(BuildContext context) =>
      isDarkMode(context) ? darkSurface : surfaceContainerLowest;

  static Color surfaceContainerLowColor(BuildContext context) =>
      isDarkMode(context) ? darkElevated : surfaceContainerLow;

  static Color surfaceContainerColor(BuildContext context) =>
      isDarkMode(context) ? darkElevated : surfaceContainer;

  static Color elevatedSurface(BuildContext context) =>
      isDarkMode(context) ? darkElevated : surfaceContainerHigh;

  static Color backgroundColor(BuildContext context) =>
      isDarkMode(context) ? darkBackground : background;

  static Color textColor(BuildContext context) =>
      isDarkMode(context) ? darkTextMain : textMain;

  static Color subtextColor(BuildContext context) =>
      isDarkMode(context) ? darkTextMuted : textMuted;

  static Color borderColor(BuildContext context) =>
      isDarkMode(context) ? darkBorder : border;

  static Color primaryColor(BuildContext context) =>
      isDarkMode(context) ? darkPrimary : primary;

  static Color accentColor(BuildContext context) =>
      isDarkMode(context) ? darkSecondary : secondary;

  static Color turquoiseColor(BuildContext context) =>
      isDarkMode(context) ? darkSecondary : tertiaryTeal;

  static Color successColor(BuildContext context) =>
      isDarkMode(context) ? darkSuccess : vitalDischarged;

  static Color warningColor(BuildContext context) =>
      isDarkMode(context) ? darkWarning : vitalScheduled;

  static Color dangerColor(BuildContext context) =>
      isDarkMode(context) ? darkDanger : vitalEmergency;

  static Color purpleColor(BuildContext context) =>
      isDarkMode(context) ? darkPurple : secondary;

  static Color purpleLightColor(BuildContext context) =>
      isDarkMode(context) ? darkPurpleLight : secondaryFixed;

  // ==========================================================================
  // OMBRES & ÉLÉVATION iOS
  // ==========================================================================
  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = isDarkMode(context);
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.35)
            : const Color(0xFF0B2545).withValues(alpha: 0.05),
        blurRadius: 18,
        offset: const Offset(0, 4),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : const Color(0xFF0B2545).withValues(alpha: 0.02),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> modalShadow(BuildContext context) {
    final isDark = isDarkMode(context);
    return [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.6)
            : const Color(0xFF0B2545).withValues(alpha: 0.16),
        blurRadius: 32,
        offset: const Offset(0, 12),
        spreadRadius: -4,
      ),
    ];
  }

  // ==========================================================================
  // LIGHT THEME (iOS Premium)
  // ==========================================================================
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        brightness: Brightness.light,
        scaffoldBackgroundColor: background,
        canvasColor: background,
        cardColor: surfaceContainerLowest,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
          },
        ),
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: primary,
          onPrimary: Colors.white,
          secondary: secondary,
          onSecondary: Colors.white,
          tertiary: tertiaryTeal,
          onTertiary: Colors.white,
          surface: surfaceContainerLowest,
          onSurface: textMain,
          error: vitalEmergency,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: textMain,
          elevation: 0,
          centerTitle: false,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textMain,
            letterSpacing: -0.4,
          ),
          iconTheme: IconThemeData(color: textMain, size: 22),
        ),
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 0.8,
          space: 0,
        ),
        cardTheme: CardThemeData(
          color: surfaceContainerLowest,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: textMuted, fontSize: 14),
          labelStyle: const TextStyle(color: textMuted, fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: secondary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: vitalEmergency),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      );

  // ==========================================================================
  // DARK THEME (OLED / Électron)
  // ==========================================================================
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        canvasColor: darkBackground,
        cardColor: darkCard,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
          },
        ),
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: darkPrimary,
          onPrimary: Color(0xFF0B131E),
          secondary: darkSecondary,
          onSecondary: Color(0xFF0B131E),
          tertiary: darkSecondary,
          onTertiary: Color(0xFF0B131E),
          surface: darkCard,
          onSurface: darkTextMain,
          error: darkDanger,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: darkTextMain,
          elevation: 0,
          centerTitle: false,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: darkTextMain,
            letterSpacing: -0.4,
          ),
          iconTheme: IconThemeData(color: darkTextMain, size: 22),
        ),
        dividerTheme: const DividerThemeData(
          color: darkBorder,
          thickness: 0.8,
          space: 0,
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: darkBorder, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkElevated,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: darkTextMuted, fontSize: 14),
          labelStyle: const TextStyle(color: darkTextMuted, fontSize: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: darkPrimary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: darkDanger),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkPrimary,
            foregroundColor: const Color(0xFF0B131E),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
      );

  static ThemeData get theme => lightTheme;

  // ==========================================================================
  // COULEURS & LABELS DES RÔLES
  // ==========================================================================
  static Color getRoleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'DOCTOR':
        return secondary; // Bondi Blue (#006688)
      case 'NURSE':
        return vitalDischarged; // Emerald (#10B981)
      case 'MIDWIFE':
        return midwifePrimary; // Magenta / Amaranth (#D946EF)
      case 'TECHNICIAN':
        return tertiaryTeal; // Ocean Teal (#00A896)
      case 'ADMIN':
        return primary; // Institutional Navy (#001026)
      default:
        return secondary;
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
        return CupertinoIcons.lab_flask_solid;
      case 'ADMIN':
        return CupertinoIcons.gear_alt_fill;
      default:
        return CupertinoIcons.person_fill;
    }
  }
}
