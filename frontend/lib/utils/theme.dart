import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Design System — Polyclinique El Arij (Djerba)
/// Mediterranean Clinical Precision & iOS HIG-informed Glassmorphism
class AppTheme {
  // ==========================================================================
  // NOUVELLE PALETTE OFFICIELLE DU DESIGN SYSTEM ARIJ
  // ==========================================================================

  /// Fern — #588157 : Couleur principale (App Bar / Top Bar, éléments principaux, accents, actifs)
  static const Color fern = Color(0xFF588157);

  /// Hunter Green — #3A5A40 : Boutons principaux, actions importantes, états actifs, fort contraste
  static const Color hunterGreen = Color(0xFF3A5A40);

  /// Pine Teal — #344E41 : Textes principaux, titres, icônes importantes, fort contraste
  static const Color pineTeal = Color(0xFF344E41);

  /// Dry Sage — #A3B18A : Accents secondaires, badges, éléments décoratifs, informations secondaires
  static const Color drySage = Color(0xFFA3B18A);

  /// Dust Grey — #DAD7CD : Arrière-plans secondaires, séparateurs, bordures et surfaces légères
  static const Color dustGrey = Color(0xFFDAD7CD);

  /// Vibrant Orange (anciennement Pastel Orange) — #FF7A00 : Actions d'ajout, boutons flottants, etc.
  static const Color pastelOrange = Color(0xFFFF7A00);

  /// Alert Red — #C62828 : Uniquement alertes critiques, erreurs, suppression, gravité
  static const Color alertRed = Color(0xFFC62828);

  // ==========================================================================
  // PALETTE ÉTENDUE & NUANCES (Evergreen, Dark Teal, Yellow Green, Cayenne Red, Soft Linen)
  // ==========================================================================
  /// Evergreen — #002626 : Vert très profond / teintes sombres
  static const Color evergreen = Color(0xFF002626);

  /// Dark Teal — #0E4749 : Sarcelle foncé, accents cliniques froids
  static const Color darkTeal = Color(0xFF0E4749);

  /// Yellow Green — #95C623 : Vert lime / vert-jaune vif, accents de vitalité
  static const Color yellowGreen = Color(0xFF95C623);

  /// Cayenne Red — #E55812 : Rouge Cayenne / Orangé vif, alertes chaleureuses
  static const Color cayenneRed = Color(0xFFE55812);

  /// Soft Linen — #EFE7DA : Lin doux / Blanc cassé naturel, surfaces et cartes claires
  static const Color softLinen = Color(0xFFEFE7DA);

  // --- Mappage Fonctionnel Design System ---
  static const Color primary = fern; // #588157
  static const Color primaryNavy = hunterGreen; // #3A5A40
  static const Color primaryContainer = Color(0xFFEDF2EA);
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = pineTeal;

  static const Color secondary = drySage; // #A3B18A
  static const Color secondaryBondi = hunterGreen; // #3A5A40
  static const Color secondaryContainer = Color(0xFFEFF3EC);
  static const Color onSecondaryContainer = pineTeal;
  static const Color secondaryFixed = Color(0xFFDDE6D5);
  static const Color secondaryFixedDim = drySage;

  static const Color tertiary = pineTeal; // #344E41
  static const Color tertiaryTeal = fern; // #588157
  static const Color tertiaryFixed = Color(0xFFD6E3D4);
  static const Color tertiaryFixedDim = drySage;
  static const Color tertiaryContainer = Color(0xFFE6ECE4);
  static const Color onTertiaryContainer = pineTeal;

  static const Color skyTint = Color(0xFFEDF2EA);
  static const Color primaryFixed = Color(0xFFDDE6D5);
  static const Color primaryFixedDim = drySage;

  /// Surfaces & Backgrounds
  static const Color surface = Colors.white;
  static const Color surfaceLinen = softLinen; // #EFE7DA
  static const Color canvasBg = Color(0xFFFAF9F6);
  static const Color background = Color(0xFFFAF9F6);
  static const Color surfaceContainerLowest = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFF2F4EF);
  static const Color surfaceContainer = Color(0xFFE9EDE5);
  static const Color surfaceContainerHigh = Color(0xFFE1E7DC);
  static const Color surfaceContainerHighest = dustGrey;
  static const Color surfaceDim = Color(0xFFD4DBD0);
  static const Color surfaceGlass = Color(0xE6FFFFFF);

  /// Typographie & Neutres
  static const Color onSurface = pineTeal;
  static const Color onSurfaceVariant = hunterGreen;
  static const Color textMain = pineTeal; // #344E41
  static const Color textMuted = Color(0xFF6B7E72);
  static const Color border = dustGrey; // #DAD7CD
  static const Color outline = dustGrey;
  static const Color outlineVariant = Color(0xFFC7C5BB);

  /// Tokens Cliniques
  static const Color vitalEmergency =
      cayenneRed; // #E55812 (Rouge Cayenne - Urgence Vitale / Alerte)
  static const Color vitalScheduled = pastelOrange; // #E9B872 (Attention / Surveillance)
  static const Color vitalDischarged = yellowGreen; // #95C623 (Yellow Green - Normal / Validé)
  static const Color error = cayenneRed; // #E55812
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF410002);

  // ==========================================================================
  // PALETTE DARK MODE OFFICIELLE ARIJ (Interface iOS Médicale Premium)
  // ==========================================================================
  /// Background principal : #17211C — fond général très sombre avec une légère dominante verte
  static const Color darkBackground = Color(0xFF17211C);
  static const Color darkTopBar = Color(0xFF17211C);

  /// Surface / Cards : #202C25 — cartes, sections, conteneurs et éléments principaux
  static const Color darkSurface = Color(0xFF202C25);
  static const Color darkCard = Color(0xFF202C25);

  /// Surface secondaire : #29382F — éléments légèrement surélevés, menus, Bottom Sheets et composants secondaires
  static const Color darkSurfaceSecondary = Color(0xFF29382F);
  static const Color darkElevated = Color(0xFF29382F);

  /// Surface active : #344E41 — éléments sélectionnés, états actifs et composants mis en évidence
  static const Color darkSurfaceActive = pineTeal;

  /// Bordures Dark Mode discrètes
  static const Color darkBorder = Color(0xFF29382F);
  static const Color darkBorderSubtle = Color(0xFF243028);

  /// Couleurs du texte Dark Mode (Hiérarchie Apple iOS)
  /// Primary Text : #F1F5F2 — titres, noms des patients et informations essentielles
  static const Color darkTextPrimary = Color(0xFFF1F5F2);
  static const Color darkTextMain = Color(0xFFF1F5F2);

  /// Secondary Text : #C8D2CC — descriptions, informations secondaires et métadonnées
  static const Color darkTextSecondary = Color(0xFFC8D2CC);
  static const Color darkTextSub = Color(0xFFC8D2CC);

  /// Tertiary Text : #9EACA3 — dates, labels, informations moins importantes
  static const Color darkTextTertiary = Color(0xFF9EACA3);
  static const Color darkTextMuted = Color(0xFF9EACA3);

  /// Disabled Text : #6F7C74 — éléments désactivés
  static const Color darkTextDisabled = Color(0xFF6F7C74);

  /// États et alertes teintés Dark Mode
  /// Pastel Orange #E9B872 (avertissement)
  static const Color darkWarning = pastelOrange; // #E9B872
  /// Warning background : #3A3020 (fond teinté sombre pour avertissement)
  static const Color darkWarningBg = Color(0xFF3A3020);

  /// Alert Red #C62828 (critique / erreur)
  static const Color darkDanger = alertRed; // #C62828
  /// Critical background : #351F20 (fond teinté sombre pour alerte critique)
  static const Color darkCriticalBg = Color(0xFF351F20);
  static const Color darkDangerBg = darkCriticalBg;

  static const Color darkPrimary = Color(0xFF0866FF);
  static const Color darkSecondary = Color(0xFF56A9FF);
  static const Color darkSuccess = Color(0xFF43D6A0);

  // Aliases rétrocompatibles pointant TOUS vers la nouvelle palette
  static const Color tropicalTeal = fern;
  static const Color bondiBlue = hunterGreen;
  static const Color emerald = fern;
  static const Color oceanMist = drySage;
  static const Color willowGreen = drySage;
  static const Color lightGreen = drySage;
  static const Color limeCream = Color(0xFFEDF2EA);
  static const Color primaryDark = hunterGreen;
  static const Color primaryLight = Color(0xFFEDF2EA);
  static const Color accent = drySage;
  static const Color turquoise = fern;
  static const Color purple = hunterGreen;
  static const Color purpleLight = Color(0xFFEDF2EA);
  static const Color purpleDark = pineTeal;
  static const Color success = fern;
  static const Color warning = pastelOrange;
  static const Color danger = alertRed;
  static const Color info = hunterGreen;
  static const Color darkAccent = drySage;
  static const Color darkTurquoise = drySage;
  static const Color darkInfo = drySage;
  static const Color darkPurple = drySage;
  static const Color darkPurpleLight = darkElevated;
  static const Color burntRose = fern;
  static const Color mutedTeal = hunterGreen;
  static const Color pearlAqua = drySage;
  static const Color neonIce = drySage;
  static const Color plumDark = pineTeal;
  static const Color chocolatePlum = pineTeal;
  static const Color smokyRose = fern;
  static const Color taupeGrey = dustGrey;
  static const Color darkBg = darkBackground;
  static const Color darkSurf = darkSurface;

  // Secteur Maternité & Soins alignés sur la palette
  static const Color midwifePrimary = fern;
  static const Color midwifeDark = hunterGreen;
  static const Color midwifeLight = Color(0xFFEFF4ED);
  static const Color midwifeAccent = drySage;
  static const Color coralRed = alertRed;
  static const Color amethystPurple = hunterGreen;

  // ==========================================================================
  // GESTION DU THÈME
  // ==========================================================================
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  static const String _themePrefKey = 'polyclinique_arij_theme_v2';

  static bool get isDark => themeModeNotifier.value == ThemeMode.dark;

  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Future<void> initTheme() async {
    // Mode automatique basé sur le système du téléphone (iOS / Android)
    themeModeNotifier.value = ThemeMode.system;
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
    final next = themeModeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }

  // ==========================================================================
  // HELPERS CONTEXTUELS DE COULEURS
  // ==========================================================================
  static Color cardColor(BuildContext context) =>
      isDarkMode(context) ? darkCard : surfaceContainerLowest;

  static Color surfaceColor(BuildContext context) =>
      isDarkMode(context) ? darkSurface : surfaceContainerLowest;

  static Color surfaceSecondaryColor(BuildContext context) =>
      isDarkMode(context) ? darkSurfaceSecondary : surfaceContainerLow;

  static Color surfaceActiveColor(BuildContext context) =>
      isDarkMode(context) ? darkSurfaceActive : hunterGreen;

  static Color surfaceContainerLowColor(BuildContext context) =>
      isDarkMode(context) ? darkSurfaceSecondary : surfaceContainerLow;

  static Color surfaceContainerColor(BuildContext context) =>
      isDarkMode(context) ? darkSurfaceSecondary : surfaceContainer;

  static Color elevatedSurface(BuildContext context) =>
      isDarkMode(context) ? darkSurfaceSecondary : surfaceContainerHigh;

  static Color backgroundColor(BuildContext context) =>
      isDarkMode(context) ? darkBackground : background;

  static Color textColor(BuildContext context) => isDarkMode(context) ? darkTextPrimary : textMain;

  static Color subtextColor(BuildContext context) =>
      isDarkMode(context) ? darkTextSecondary : textMuted;

  static Color tertiaryTextColor(BuildContext context) =>
      isDarkMode(context) ? darkTextTertiary : const Color(0xFF6B7E72);

  static Color disabledTextColor(BuildContext context) =>
      isDarkMode(context) ? darkTextDisabled : const Color(0xFF9EACA3);

  static Color borderColor(BuildContext context) => isDarkMode(context) ? darkBorder : border;

  static Color primaryColor(BuildContext context) => isDarkMode(context) ? darkPrimary : primary;

  static Color accentColor(BuildContext context) => isDarkMode(context) ? darkSecondary : secondary;

  static Color turquoiseColor(BuildContext context) =>
      isDarkMode(context) ? darkSecondary : tertiaryTeal;

  static Color successColor(BuildContext context) =>
      isDarkMode(context) ? darkSuccess : vitalDischarged;

  static Color warningColor(BuildContext context) =>
      isDarkMode(context) ? darkWarning : vitalScheduled;

  static Color warningBgColor(BuildContext context) =>
      isDarkMode(context) ? darkWarningBg : const Color(0xFFFDF6EC);

  static Color dangerColor(BuildContext context) =>
      isDarkMode(context) ? darkDanger : vitalEmergency;

  static Color criticalBgColor(BuildContext context) =>
      isDarkMode(context) ? darkCriticalBg : const Color(0xFFEDF2EA);

  static Color purpleColor(BuildContext context) => isDarkMode(context) ? darkPrimary : secondary;

  static Color purpleLightColor(BuildContext context) =>
      isDarkMode(context) ? darkSurfaceActive : secondaryFixed;

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
      backgroundColor: evergreen, // Evergreen #002626 : identique au container de synthèse clinique
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: Colors.white, size: 22),
      actionsIconTheme: IconThemeData(color: Colors.white, size: 22),
    ),
    dividerTheme: const DividerThemeData(color: dustGrey, thickness: 0.8, space: 0),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: dustGrey, width: 1),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: dustGrey, width: 1),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      dragHandleColor: dustGrey,
      dragHandleSize: Size(44, 4.5),
      showDragHandle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      labelStyle: const TextStyle(color: textMuted, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: dustGrey, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: dustGrey, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: hunterGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: alertRed),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: hunterGreen, // Hunter Green #3A5A40 : boutons principaux
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: evergreen,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: dustGrey, width: 1.2),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 2.5,
      extendedPadding: EdgeInsets.symmetric(horizontal: 16),
      extendedTextStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.2),
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
    cardColor: darkCard, // #202C25
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
      onPrimary: Colors.white,
      secondary: darkSecondary,
      onSecondary: Colors.white,
      tertiary: darkSurfaceActive,
      onTertiary: Colors.white,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      error: darkDanger,
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: evergreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: Colors.white, size: 22),
      actionsIconTheme: IconThemeData(color: Colors.white, size: 22),
    ),
    dividerTheme: const DividerThemeData(color: darkBorder, thickness: 0.8, space: 0),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkSurfaceSecondary,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: darkBorder, width: 1),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      dragHandleColor: darkTextTertiary,
      dragHandleSize: Size(44, 4.5),
      showDragHandle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurfaceSecondary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: darkTextTertiary, fontSize: 14),
      labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: darkBorder, width: 1),
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
        backgroundColor: hunterGreen,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: darkTextPrimary,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: darkBorder, width: 1.2),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: darkPrimary,
      foregroundColor: Colors.white,
      elevation: 2.5,
      extendedPadding: EdgeInsets.symmetric(horizontal: 16),
      extendedTextStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.2),
    ),
  );

  static ThemeData get theme => lightTheme;

  // ==========================================================================
  // COULEURS & LABELS DES RÔLES (Harmonisés avec la nouvelle palette ARIJ)
  // ==========================================================================
  static Color getRoleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'DOCTOR':
        return hunterGreen; // Hunter Green (#3A5A40)
      case 'NURSE':
        return fern; // Fern (#588157)
      case 'MIDWIFE':
        return drySage; // Dry Sage (#A3B18A)
      case 'TECHNICIAN':
        return darkTeal; // Dark Teal (#0E4749)
      case 'ADMIN':
        return hunterGreen; // Hunter Green (#3A5A40)
      default:
        return fern;
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

  // ==========================================================================
  // COMPOSANTS UNIFIÉS (Cartes & Bottom Sheets)
  // ==========================================================================

  /// Décoration standardisée pour toutes les cartes de l'application
  static BoxDecoration cardDecoration(
    BuildContext context, {
    Color? color,
    Color? borderColor,
    double borderRadius = 18,
    bool hasShadow = true,
  }) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      color: color ?? (isDark ? darkCard : Colors.white),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? (isDark ? darkBorder : dustGrey), width: 1),
      boxShadow: hasShadow ? cardShadow(context) : null,
    );
  }

  /// Décoration standardisée pour les conteneurs de Bottom Sheets
  static BoxDecoration bottomSheetDecoration(BuildContext context, {double borderRadius = 26}) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      color: isDark ? darkSurface : Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
      border: Border.all(color: isDark ? darkBorder : const Color(0xFFE5ECE8), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
          blurRadius: 24,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }

  /// Barre d'accroche (drag handle) standardisée pour tous les Bottom Sheets
  static Widget bottomSheetDragHandle({Color? color}) {
    return Center(
      child: Container(
        width: 44,
        height: 4.5,
        margin: const EdgeInsets.only(top: 10, bottom: 12),
        decoration: BoxDecoration(
          color: color ?? const Color(0xFFD1D8D4),
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }

  /// En-tête de Bottom Sheet standardisé avec drag handle et titre Pine Teal
  static Widget bottomSheetHeader(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    final isDark = isDarkMode(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bottomSheetDragHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? darkTextMain : pineTeal,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? darkTextMuted : textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
            ],
          ),
        ),
        Divider(color: isDark ? darkBorder : const Color(0xFFE5ECE8), height: 16),
      ],
    );
  }

  /// Ouverture d'un Bottom Sheet au style unifié ARIJ
  static Future<T?> showArijBottomSheet<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    Color? backgroundColor,
    bool useSafeArea = true,
  }) {
    final isDark = isDarkMode(context);
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      backgroundColor: backgroundColor ?? (isDark ? darkSurface : Colors.white),
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: isDark ? darkBorder : const Color(0xFFE5ECE8), width: 1),
      ),
      builder: builder,
    );
  }
}
