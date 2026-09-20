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

  test('AppTheme.initTheme restaure le theme sauvegarde depuis SharedPreferences', () async {
    // La clé en v2 est 'polyclinique_arij_theme_v2'
    SharedPreferences.setMockInitialValues({
      'polyclinique_arij_theme_v2': 'dark',
    });

    await AppTheme.initTheme();
    expect(AppTheme.isDark, isTrue);
    expect(AppTheme.themeModeNotifier.value, ThemeMode.dark);
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

    // En mode clair : l'icône doit être le soleil (sun_max_fill)
    expect(find.byIcon(CupertinoIcons.sun_max_fill), findsOneWidget);

    // Basculer en mode sombre manuellement
    AppTheme.themeModeNotifier.value = ThemeMode.dark;
    await tester.pumpAndSettle();

    // En mode sombre : l'icône doit être la lune
    expect(find.byIcon(CupertinoIcons.moon_fill), findsOneWidget);

    // Basculer en mode Système
    AppTheme.themeModeNotifier.value = ThemeMode.system;
    await tester.pumpAndSettle();

    // En mode Système : l'icône cercle moitié
    expect(find.byIcon(CupertinoIcons.circle_lefthalf_fill), findsOneWidget);
  });

  testWidgets('ThemeToggleButton ouvre un ActionSheet iOS au tap', (WidgetTester tester) async {
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

    // L'ActionSheet iOS doit être visible
    expect(find.text('Mode Clair'), findsOneWidget);
    expect(find.text('Mode Sombre'), findsOneWidget);
    expect(find.text('Suivre le système'), findsOneWidget);
  });
}
