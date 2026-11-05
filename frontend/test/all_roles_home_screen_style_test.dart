import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/doctor_home_screen.dart';
import 'package:frontend/screens/technician_home_screen.dart';
import 'package:frontend/screens/nurse_home_screen.dart';
import 'package:frontend/screens/midwife_home_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Harmonisation Visuelle & Briefing IA - Tous les Rôles', () {
    testWidgets('DoctorHomeScreen adopte le style Stitch Pro avec Briefing IA', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorHomeScreen(onLogout: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // En-tête Figma
      expect(find.text('MÉDECIN'), findsOneWidget);
      expect(find.text('26°C'), findsNothing);

      // 3 KPIs
      expect(find.text('Hospitalisés'), findsOneWidget);
      expect(find.text('Urgences Box'), findsOneWidget);
      expect(find.text('Examens labo'), findsOneWidget);

      // Urgences Vitales
      expect(find.text('Urgences & Alertes Vitales'), findsOneWidget);
    });

    testWidgets('TechnicianHomeScreen adopte le style Stitch Pro avec Briefing IA', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: TechnicianHomeScreen(onLogout: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // En-tête Figma
      expect(find.text('PLATEAU TECHNIQUE'), findsOneWidget);
      expect(find.text('26°C'), findsNothing);

      // 3 KPIs
      expect(find.text('En attente'), findsOneWidget);
      expect(find.text('Urgences Box'), findsOneWidget);
      expect(find.text('Validés'), findsOneWidget);

      // Urgences & Prélèvements Critiques
      expect(find.text('Urgences & Prélèvements Critiques'), findsOneWidget);
    });

    testWidgets('NurseHomeScreen adopte le style Stitch Pro avec Briefing IA', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: NurseHomeScreen(onLogout: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // En-tête Figma
      expect(find.text('INFIRMIER'), findsOneWidget);
      expect(find.text('26°C'), findsNothing);

      // 3 KPIs
      expect(find.text('Hospitalisés'), findsOneWidget);
      expect(find.text('Constantes Urg.'), findsOneWidget);
      expect(find.text('Soins à faire'), findsOneWidget);

      // Urgences Vitales
      expect(find.text('Urgences & Alertes Vitales'), findsOneWidget);
    });

    testWidgets('MidwifeHomeScreen adopte le style Stitch Pro avec Briefing IA', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: MidwifeHomeScreen(onLogout: () {}),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // En-tête Figma
      expect(find.text('SAGE-FEMME'), findsOneWidget);
      expect(find.text('26°C'), findsNothing);

      // 3 KPIs
      expect(find.text('Travail Actif'), findsOneWidget);
      expect(find.text('Alertes RCF'), findsOneWidget);
      expect(find.text('Post-Partum'), findsOneWidget);

      // Urgences Vitales
      expect(find.text('Urgences & Alertes Vitales'), findsOneWidget);
    });
  });
}
