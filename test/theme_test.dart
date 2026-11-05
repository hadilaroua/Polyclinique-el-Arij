import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/theme.dart';
import 'package:frontend/widgets/theme_toggle_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppTheme.themeModeNotifier.value = ThemeMode.light;
  });

  test('AppTheme.toggleTheme bascule entre Light et Dark mode', () async {
    expect(AppTheme.isDark, isFalse);
    expect(AppTheme.themeModeNotifier.value, ThemeMode.light);

    await AppTheme.toggleTheme();
    expect(AppTheme.isDark, isTrue);
    expect(AppTheme.themeModeNotifier.value, ThemeMode.dark);

    await AppTheme.toggleTheme();
    expect(AppTheme.isDark, isFalse);
    expect(AppTheme.themeModeNotifier.value, ThemeMode.light);
  });

  test('AppTheme.setThemeMode supporte ThemeMode.system', () async {
    await AppTheme.setThemeMode(ThemeMode.system);
    expect(AppTheme.themeModeNotifier.value, ThemeMode.system);
  });

  test('AppTheme.initTheme initialise ThemeMode.system par défaut pour suivre le système', () async {
    await AppTheme.initTheme();
    expect(AppTheme.themeModeNotifier.value, ThemeMode.system);
  });

  test('AppTheme.initTheme restaure ThemeMode.system', () async {
    SharedPreferences.setMockInitialValues({
      'polyclinique_arij_theme_v2': 'system',
    });

    await AppTheme.initTheme();
    expect(AppTheme.themeModeNotifier.value, ThemeMode.system);
  });

  testWidgets('ThemeToggleButton affiche l\'icone correcte selon le mode', (WidgetTester tester) async {
    AppTheme.themeModeNotifier.value = ThemeMode.light;

    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeModeNotifier,
        builder: (context, mode, _) => MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const Scaffold(
            body: Center(child: ThemeToggleButton()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // En mode clair : l'icône indique qu'on peut passer en mode sombre (moon_fill)
    expect(find.byIcon(CupertinoIcons.moon_fill), findsOneWidget);

    // Basculer en mode sombre manuellement
    AppTheme.themeModeNotifier.value = ThemeMode.dark;
    await tester.pumpAndSettle();

    // En mode sombre : l'icône est le soleil (sun_max_fill)
    expect(find.byIcon(CupertinoIcons.sun_max_fill), findsOneWidget);
  });

  testWidgets('ThemeToggleButton bascule le theme au tap', (WidgetTester tester) async {
    AppTheme.themeModeNotifier.value = ThemeMode.light;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const Scaffold(
          body: Center(child: ThemeToggleButton()),
        ),
      ),
    );

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(AppTheme.themeModeNotifier.value, ThemeMode.dark);
  });

  test('La nouvelle palette ARIJ est rigoureusement conforme', () {
    expect(AppTheme.fern, const Color(0xFF588157));
    expect(AppTheme.hunterGreen, const Color(0xFF3A5A40));
    expect(AppTheme.pineTeal, const Color(0xFF344E41));
    expect(AppTheme.drySage, const Color(0xFFA3B18A));
    expect(AppTheme.dustGrey, const Color(0xFFDAD7CD));
    expect(AppTheme.pastelOrange, const Color(0xFFFF7A00));
    expect(AppTheme.alertRed, const Color(0xFFC62828));

    // App Bar principale en Evergreen #002626 (Harmonisé avec container briefing)
    expect(AppTheme.lightTheme.appBarTheme.backgroundColor, AppTheme.evergreen);
    expect(AppTheme.lightTheme.appBarTheme.foregroundColor, Colors.white);

    // Boutons principaux en Hunter Green #3A5A40
    expect(AppTheme.lightTheme.elevatedButtonTheme.style?.backgroundColor?.resolve({}), const Color(0xFF3A5A40));

    // Bottom Sheet standardisé avec Radius 24 et drag handle dustGrey
    final bsTheme = AppTheme.lightTheme.bottomSheetTheme;
    expect(bsTheme.dragHandleColor, const Color(0xFFDAD7CD));
    expect(bsTheme.shape, isA<RoundedRectangleBorder>());
    final shape = bsTheme.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, const BorderRadius.vertical(top: Radius.circular(24)));
  });

  test('Le Dark Mode ARIJ est une véritable interface iOS médicale premium', () {
    // Backgrounds & Surfaces
    expect(AppTheme.darkBackground, const Color(0xFF17211C));
    expect(AppTheme.darkSurface, const Color(0xFF202C25));
    expect(AppTheme.darkCard, const Color(0xFF202C25));
    expect(AppTheme.darkSurfaceSecondary, const Color(0xFF29382F));
    expect(AppTheme.darkElevated, const Color(0xFF29382F));
    expect(AppTheme.darkSurfaceActive, const Color(0xFF344E41));
    expect(AppTheme.darkBorder, const Color(0xFF29382F));

    // Textes Dark Mode (Hiérarchie Apple iOS)
    expect(AppTheme.darkTextPrimary, const Color(0xFFF1F5F2));
    expect(AppTheme.darkTextSecondary, const Color(0xFFC8D2CC));
    expect(AppTheme.darkTextTertiary, const Color(0xFF9EACA3));
    expect(AppTheme.darkTextDisabled, const Color(0xFF6F7C74));

    // Alertes teintées sombres
    expect(AppTheme.darkWarningBg, const Color(0xFF3A3020));
    expect(AppTheme.darkCriticalBg, const Color(0xFF351F20));

    // Thème Dark appliqué
    final darkTheme = AppTheme.darkTheme;
    expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF17211C));
    expect(darkTheme.cardColor, const Color(0xFF202C25));

    // App Bar Evergreen #002626 conservée pour harmonisation
    expect(darkTheme.appBarTheme.backgroundColor, AppTheme.evergreen);
    expect(darkTheme.appBarTheme.foregroundColor, Colors.white);

    // Bottom Sheet Dark : surface secondaire #29382F (plus claire que le background)
    final darkBsTheme = darkTheme.bottomSheetTheme;
    expect(darkBsTheme.backgroundColor, const Color(0xFF29382F));
    expect(darkBsTheme.dragHandleColor, const Color(0xFF9EACA3));
    final bsShape = darkBsTheme.shape as RoundedRectangleBorder;
    expect(bsShape.borderRadius, const BorderRadius.vertical(top: Radius.circular(24)));

    // Boutons Dark : Hunter Green #3A5A40 avec texte primaire
    expect(darkTheme.elevatedButtonTheme.style?.backgroundColor?.resolve({}), const Color(0xFF3A5A40));
    expect(darkTheme.elevatedButtonTheme.style?.foregroundColor?.resolve({}), const Color(0xFFF1F5F2));
  });
}
