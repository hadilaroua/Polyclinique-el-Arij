import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/doctor_home_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('DoctorHomeScreen onglet Consultations adopte le style Stitch El Arij de l\'accueil', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    await tester.pumpWidget(
      MaterialApp(
        home: DoctorHomeScreen(
          onLogout: () {},
          initialTabIndex: 2, // Onglet Consultations
        ),
      ),
    );

    await tester.pump();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // Vérification de l'en-tête type Accueil
    expect(find.text('Consultations Médicales'), findsOneWidget);
    expect(find.text('Cabinet 4'), findsOneWidget);

    // Vérification de la barre de recherche Stitch en 2ème position
    expect(find.text('Rechercher patient, motif, diagnostic...'), findsOneWidget);

    // Vérification des 3 cartes KPI Counters style Accueil
    expect(find.text('Actes médicaux'), findsOneWidget);
    expect(find.text('Prescriptions'), findsOneWidget);
    expect(find.text('Rendez-vous'), findsOneWidget);

    // Vérification de la barre de recherche Stitch
    expect(find.text('Rechercher patient, motif, diagnostic...'), findsOneWidget);

    // Vérification des filtres Stitch
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Ordon.'), findsOneWidget);

    // Vérification des éléments de consultations
    expect(find.text('Dossiers de consultation'), findsOneWidget);
  });
}
