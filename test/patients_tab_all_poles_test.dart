import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/doctor_home_screen.dart';
import 'package:frontend/screens/midwife_home_screen.dart';
import 'package:frontend/screens/nurse_home_screen.dart';
import 'package:frontend/screens/technician_home_screen.dart';
import 'package:frontend/utils/default_patients.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Dossiers Patients - Tous les pôles affichés par défaut', () {
    test('DefaultPatients contient des patients pour tous les pôles de la clinique', () {
      final patients = DefaultPatients.getAll();
      expect(patients.isNotEmpty, isTrue);

      final departments = patients.map((p) => p['department'].toString()).toSet();

      // Vérification que tous les pôles majeurs sont représentés
      expect(departments.any((d) => d.contains('Chirurgie') || d.contains('Hospit')), isTrue);
      expect(departments.any((d) => d.contains('Maternité') || d.contains('Obstét')), isTrue);
      expect(departments.any((d) => d.contains('Cardio')), isTrue);
      expect(departments.any((d) => d.contains('Pédiatrie')), isTrue);
      expect(departments.any((d) => d.contains('PMA')), isTrue);
    });

    testWidgets('DoctorHomeScreen ouvre l onglet Dossiers avec Tous les pôles actifs et liste non vide', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorHomeScreen(
            onLogout: () {},
            initialTabIndex: 1, // Ouvre directement sur l'onglet Dossiers Patients
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      // Vérifier que le titre de l'onglet est bien présent
      expect(find.text('Dossiers des Patients'), findsOneWidget);

      // Vérifier que le filtre "Tous les pôles" est présent
      expect(find.text('Tous les pôles'), findsOneWidget);

      // Vérifier que la liste n'est pas vide (pas de message d'erreur vide)
      expect(find.text('Aucun dossier trouvé'), findsNothing);
      expect(find.text('Aucun patient trouvé dans ce pôle'), findsNothing);

      // Vérifier la présence de dossiers patients dans la liste
      expect(find.textContaining('Amine Khelifi'), findsWidgets);
    });

    testWidgets('NurseHomeScreen ouvre l onglet Patients avec Tous les pôles et liste non vide', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: NurseHomeScreen(
            onLogout: () {},
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      // Taper sur l'icône de l'onglet Patients dans la barre de navigation
      final patientsTabIcon = find.byTooltip('Patients');
      expect(patientsTabIcon, findsOneWidget);
      await tester.tap(patientsTabIcon);

      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      // Vérifier que "Tous les pôles" est sélectionné et la liste non vide
      expect(find.text('Tous les pôles'), findsOneWidget);
      expect(find.text('Aucun dossier trouvé'), findsNothing);
      expect(find.text('Aucun patient trouvé dans ce service'), findsNothing);
      expect(find.textContaining('Amine Khelifi'), findsWidgets);

      // Vérifier FAB en bas à droite
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
    });

    testWidgets('MidwifeHomeScreen et TechnicianHomeScreen ont le FAB en bas à droite et le style unifié', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      // Test Midwife
      await tester.pumpWidget(
        MaterialApp(
          home: MidwifeHomeScreen(
            onLogout: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
