import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Design System officiel de la Polyclinique Arij Djerba
/// Palette Light Mode : Bleu pétrole #123B50, Bleu médical #247BA0, Turquoise #35B8B0
/// Palette Dark Mode  : Fond profond #0B1218, Surfaces #121E27, Cartes #172733
class AppTheme {
  // ==========================================================================
  // PALETTE LIGHT MODE — Identité visuelle officielle Polyclinique Arij
  // ==========================================================================

  /// Bleu pétrole — couleur de marque, en-têtes AppBar
  static const Color primary = Color(0xFF123B50);
  /// Variation foncée du bleu pétrole pour les gradients et ombres légères
  static const Color primaryDark = Color(0xFF0D2D3D);
  /// Variation claire du bleu pétrole pour les fonds de badge et chips
  static const Color primaryLight = Color(0xFFDDE8EF);
  /// Bleu médical — actions secondaires, liens, badges informatifs
  static const Color accent = Color(0xFF247BA0);
  /// Turquoise — accent fort, indicateurs sélectionnés, icônes actives
  static const Color turquoise = Color(0xFF35B8B0);
  /// Fond général de l'application en mode clair
  static const Color background = Color(0xFFF4F7FA);
  /// Surfaces et cartes blanches
  static const Color surface = Color(0xFFFFFFFF);
  /// Texte principal (haute lisibilité sur fond clair)
  static const Color textMain = Color(0xFF20313D);
  /// Texte secondaire / muted
  static const Color textMuted = Color(0xFF718096);
  /// Bordures et séparateurs en mode clair
  static const Color border = Color(0xFFE2EAF0);

  // Statuts sémantiques cliniques (mode clair)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger  = Color(0xFFEF4444);
  static const Color info    = Color(0xFF247BA0);

  // ==========================================================================
  // PALETTE DARK MODE — Bleu pétrole profond & gris bleuté élégant
  // ==========================================================================

  /// Fond général application en mode sombre (pas de noir pur)
  static const Color darkBackground     = Color(0xFF0B1218);
  /// Surfaces principales (fond de panneau, drawer, modales)
  static const Color darkSurface        = Color(0xFF121E27);
  /// Cartes et conteneurs élevés
  static const Color darkCard           = Color(0xFF172733);
  /// Surfaces très élevées (dialogues, bottom sheets, tooltips)
  static const Color darkElevated       = Color(0xFF203541);
  /// Bleu médical adapté pour le mode sombre (lumineux mais doux)
  static const Color darkAccent         = Color(0xFF5CA9D6);
  /// Turquoise adapté pour le mode sombre
  static const Color darkTurquoise      = Color(0xFF55D3C7);
  /// Texte principal en mode sombre (très lisible, pas blanc pur agressif)
  static const Color darkTextMain       = Color(0xFFF2F6F8);
  /// Texte secondaire en mode sombre
  static const Color darkTextMuted      = Color(0xFFA6B6C2);
  /// Bordures et séparateurs en mode sombre
  static const Color darkBorder         = Color(0xFF2B414F);
  /// Bleu pétrole pour les variantes de brand en mode sombre
  static const Color darkPrimary        = Color(0xFF5CA9D6);

  // Statuts sémantiques cliniques (mode sombre — plus lumineux pour contraste)
  static const Color darkSuccess = Color(0xFF34D399);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkDanger  = Color(0xFFF87171);
  static const Color darkInfo    = Color(0xFF5CA9D6);

  // ==========================================================================
  // RÉTROCOMPATIBILITÉ — Alias vers la nouvelle palette
  // ==========================================================================
  static const Color burntRose     = primary;
  static const Color mutedTeal     = accent;
  static const Color pearlAqua     = primaryLight;
  static const Color neonIce       = turquoise;
  static const Color plumDark      = primaryDark;
  static const Color chocolatePlum = primaryDark;
  static const Color smokyRose     = primary;
  static const Color taupeGrey     = textMuted;

  // Compatibilité avec les accents précédents (utilisés dans les anciens écrans)
  static const Color darkBg        = darkBackground;
  static const Color darkSurf      = darkSurface;

  // ==========================================================================
  // GESTION DYNAMIQUE DU THÈME (Light / Dark / System)
  // ==========================================================================

  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static const String _themePrefKey = 'polyclinique_arij_theme_v2';

  /// Indique si le thème sélectionné est sombre
  /// En mode Système, vérifie la luminosité du MediaQuery
  static bool get isDark => themeModeNotifier.value == ThemeMode.dark;

  /// Vérifie dynamiquement si l'écran est en mode sombre (y compris System)
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

  /// Bascule uniquement entre Light et Dark (sans System)
  static Future<void> toggleTheme() async {
    final next = themeModeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(next);
  }

  // ==========================================================================
  // HELPERS DE COULEURS CONTEXTUELLES (adaptent automatiquement au thème)
  // ==========================================================================

  static Color cardColor(BuildContext context) =>
      isDarkMode(context) ? darkCard : surface;

  static Color surfaceColor(BuildContext context) =>
      isDarkMode(context) ? darkSurface : surface;

  static Color elevatedSurface(BuildContext context) =>
      isDarkMode(context) ? darkElevated : const Color(0xFFF0F4F8);

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
      isDarkMode(context) ? darkAccent : accent;

  static Color turquoiseColor(BuildContext context) =>
      isDarkMode(context) ? darkTurquoise : turquoise;

  static Color successColor(BuildContext context) =>
      isDarkMode(context) ? darkSuccess : success;

  static Color warningColor(BuildContext context) =>
      isDarkMode(context) ? darkWarning : warning;

  static Color dangerColor(BuildContext context) =>
      isDarkMode(context) ? darkDanger : danger;

  // ==========================================================================
  // LIGHT THEME — ThemeData complet (Material 3 + iOS natif)
  // ==========================================================================

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    fontFamily: 'SF Pro Display',
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    cardColor: surface,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS:   CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
    colorScheme: const ColorScheme(
      brightness:    Brightness.light,
      primary:       primary,
      onPrimary:     Colors.white,
      secondary:     accent,
      onSecondary:   Colors.white,
      tertiary:      turquoise,
      onTertiary:    Colors.white,
      surface:       surface,
      onSurface:     textMain,
      error:         danger,
      onError:       Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:  primary,
      foregroundColor:  Colors.white,
      elevation:        0,
      centerTitle:      false,
      shadowColor:      Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize:      17,
        fontWeight:    FontWeight.w700,
        color:         Colors.white,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: Colors.white, size: 22),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: surface,
      elevation:       0,
      width:           300,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontSize: 17, fontWeight: FontWeight.w700, color: textMain,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor:  surface,
      surfaceTintColor: Colors.transparent,
      elevation:        0,
      dragHandleColor:  border,
      dragHandleSize:   Size(40, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor:    surface,
      surfaceTintColor:   Colors.transparent,
      indicatorColor:     Color(0xFFD6F0EE),
      elevation:          0,
      height:             64,
      labelBehavior:      NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: turquoise, size: 24);
        }
        return const IconThemeData(color: textMuted, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: turquoise,
          );
        }
        return const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: textMuted,
        );
      }),
    ),
    dividerTheme: const DividerThemeData(
      color:     border,
      thickness: 0.8,
      space:     0,
    ),
    cardTheme: CardThemeData(
      color:     surface,
      elevation: 0,
      margin:    EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor:  primaryLight,
      selectedColor:    turquoise,
      labelStyle:       const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:          true,
      fillColor:       surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle:       const TextStyle(color: textMuted, fontSize: 14),
      labelStyle:      const TextStyle(color: textMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: turquoise, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: danger),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return turquoise;
        return const Color(0xFFCBD5E1);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return turquoise.withValues(alpha: 0.35);
        }
        return border;
      }),
    ),
  );

  // ==========================================================================
  // DARK THEME — ThemeData complet (Bleu pétrole profond, pas de noir pur)
  // ==========================================================================

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    fontFamily: 'SF Pro Display',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    canvasColor:             darkBackground,
    cardColor:               darkCard,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS:   CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
    colorScheme: const ColorScheme(
      brightness:  Brightness.dark,
      primary:     darkTurquoise,
      onPrimary:   Color(0xFF0B1218),
      secondary:   darkAccent,
      onSecondary: Color(0xFF0B1218),
      tertiary:    darkTurquoise,
      onTertiary:  Color(0xFF0B1218),
      surface:     darkCard,
      onSurface:   darkTextMain,
      error:       darkDanger,
      onError:     Color(0xFF0B1218),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:  darkSurface,
      foregroundColor:  darkTextMain,
      elevation:        0,
      centerTitle:      false,
      shadowColor:      Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize:      17,
        fontWeight:    FontWeight.w700,
        color:         darkTextMain,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: darkTextMain, size: 22),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: darkSurface,
      elevation:       0,
      width:           300,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor:  darkElevated,
      surfaceTintColor: Colors.transparent,
      elevation:        4,
      shadowColor:      Colors.black.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontSize: 17, fontWeight: FontWeight.w700, color: darkTextMain,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor:  darkCard,
      surfaceTintColor: Colors.transparent,
      elevation:        0,
      dragHandleColor:  darkBorder,
      dragHandleSize:   Size(40, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor:  darkSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor:   darkTurquoise.withValues(alpha: 0.2),
      elevation:        0,
      height:           64,
      labelBehavior:    NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: darkTurquoise, size: 24);
        }
        return const IconThemeData(color: darkTextMuted, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: darkTurquoise,
          );
        }
        return const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: darkTextMuted,
        );
      }),
    ),
    dividerTheme: const DividerThemeData(
      color:     darkBorder,
      thickness: 0.8,
      space:     0,
    ),
    cardTheme: CardThemeData(
      color:     darkCard,
      elevation: 0,
      margin:    EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkElevated,
      selectedColor:   darkTurquoise.withValues(alpha: 0.25),
      labelStyle: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: darkTextMain,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled:         true,
      fillColor:      darkElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle:  const TextStyle(color: darkTextMuted, fontSize: 14),
      labelStyle: const TextStyle(color: darkTextMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: darkTurquoise, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: darkDanger),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return darkTurquoise;
        return const Color(0xFF4A5568);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return darkTurquoise.withValues(alpha: 0.35);
        }
        return darkBorder;
      }),
    ),
  );

  // Rétrocompatibilité
  static ThemeData get theme => lightTheme;

  // ==========================================================================
  // COULEURS DE RÔLES
  // ==========================================================================

  static Color getRoleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'DOCTOR':
        return const Color(0xFF247BA0);  // Bleu médical Arij
      case 'NURSE':
        return const Color(0xFF10B981);  // Vert émeraude soins
      case 'MIDWIFE':
        return const Color(0xFFEC4899);  // Rose maternité
      case 'TECHNICIAN':
        return const Color(0xFF8B5CF6);  // Violet plateau technique
      case 'ADMIN':
        return const Color(0xFFF59E0B);  // Ambre administration
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
