import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/patient_dossier_screen.dart';
import 'package:frontend/utils/briefing_utils.dart';
import 'package:frontend/utils/theme.dart';
import 'package:frontend/widgets/figma_header.dart';
import 'package:frontend/widgets/patient_dossier_sections.dart';

void main() {
  test('Briefing summary supports current, legacy, and fallback content', () {
    expect(
      getBriefingSummaryPreview({'aiSummaryPreview': '  Résumé aperçu  '}, fallback: 'fallback'),
      'Résumé aperçu',
    );
    expect(
      getBriefingSummaryPreview({'aiSummary': 'Résumé complet'}, fallback: 'fallback'),
      'Résumé complet',
    );
    expect(
      getBriefingSummaryPreview({'summary': 'Résumé historique'}, fallback: 'fallback'),
      'Résumé historique',
    );
    expect(getBriefingSummaryPreview({}, fallback: 'Briefing de secours'), 'Briefing de secours');
  });

  final mockPatient = {
    '_id': '64d1234567890abcdef12345',
    'firstName': 'Amine',
    'lastName': 'K.',
    'gender': 'M',
    'age': 48,
    'bloodType': 'O+',
    'dossierNumber': '884920',
    'allergies': ['Pénicilline', 'Latex (Risque anaphylactique)'],
    'phone': '+216 71 000 000',
  };

  testWidgets('Dark dossier uses charcoal surfaces and a blue accent', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: PatientDossierScreen(patient: mockPatient, overrideRole: 'DOCTOR'),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final appBar = tester.widget<AppBar>(find.byType(AppBar).first);
    expect(scaffold.backgroundColor, AppTheme.darkBackground);
    expect(appBar.backgroundColor, AppTheme.darkTopBar);
    expect(AppTheme.darkTheme.colorScheme.primary, AppTheme.darkPrimary);
  });

  testWidgets('App header uses El ArijFlow as its visible name', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FigmaHeader(
            roleName: 'MÉDECIN',
            roleColor: AppTheme.evergreen,
            onMenuPressed: () {},
            onNotificationsPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('El ArijFlow'), findsOneWidget);
    expect(find.text('Polyclinique El Arij'), findsNothing);
  });

  testWidgets('DoctorPatientDossierScreen sépare synthèse, prescriptions et examens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PatientDossierScreen(patient: mockPatient, overrideRole: 'DOCTOR'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Vérifier Header Médical
    expect(find.text('Dossier Médical Praticien'), findsOneWidget);
    expect(find.byTooltip('Actualiser'), findsNothing);
    expect(find.text('M. Amine K.'), findsOneWidget);
    expect(find.text('IPU #884920'), findsOneWidget);
    expect(find.text('Groupe O+'), findsOneWidget);
    expect(find.text('Allergies : Pénicilline, Latex (Risque anaphylactique)'), findsOneWidget);

    // Vérifier absence des boutons redondants et icônes d'appel/message
    expect(find.text('Note médicale'), findsNothing);
    expect(find.text('Prescription'), findsNothing);
    expect(find.byIcon(Icons.phone), findsNothing);
    expect(find.byIcon(Icons.chat), findsNothing);

    // Vérifier les sections du dossier médecin sans liste d'examens dupliquée.
    expect(find.text('Synthèse & Antécédents'), findsOneWidget);
    expect(find.text('Constantes Vitales'), findsOneWidget);
    expect(find.text('Consultations & Notes'), findsOneWidget);
    expect(find.text('Prescriptions'), findsOneWidget);
    expect(find.text('Prescriptions & Examens'), findsNothing);
    expect(find.text('Imagerie & Labo'), findsOneWidget);
  });

  testWidgets('NursePatientDossierScreen affiche les onglets soignants et la synthèse soins', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PatientDossierScreen(patient: mockPatient, overrideRole: 'NURSE'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Dossier Soignant (Infirmier)'), findsOneWidget);
    expect(find.text('Surveillance & Constantes'), findsOneWidget);
    expect(find.text('Prescriptions & Soins'), findsOneWidget);
    expect(find.text('Synthèse Patient'), findsOneWidget);
    expect(find.text('Générer Récapitulatif Soins IA (PDF)'), findsOneWidget);
  });

  testWidgets('MidwifePatientDossierScreen affiche les onglets maternité', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PatientDossierScreen(patient: mockPatient, overrideRole: 'MIDWIFE'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Dossier Maternité (Sage-Femme)'), findsOneWidget);
    expect(find.text('Monitoring Obstétrical'), findsOneWidget);
    expect(find.text('Antécédents & Contexte'), findsOneWidget);
    expect(find.text('Générer Récapitulatif Maternité IA (PDF)'), findsOneWidget);
  });

  testWidgets('TechnicianPatientDossierScreen affiche les onglets plateau technique', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PatientDossierScreen(patient: mockPatient, overrideRole: 'TECHNICIAN'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Plateau Technique & Labo'), findsOneWidget);
    expect(find.text('Examens à traiter'), findsOneWidget);
    expect(find.text('Résultats validés'), findsOneWidget);
    expect(find.text('Informations patient'), findsOneWidget);
    expect(find.text('Générer Bilan Technique IA (PDF)'), findsOneWidget);
  });

  testWidgets(
    'PatientPrescriptionList affiche les ordonnances de consultation sans reprendre le texte dupliqué',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PatientPrescriptionList(
              heading: 'Prescriptions',
              emptyMessage: 'Aucune prescription',
              consultations: [
                {
                  'date': '2026-10-28',
                  'prescription': 'Texte ancien dupliqué',
                  'prescriptionItems': [
                    {'medicine': 'Paracétamol', 'dosage': '500 mg', 'posology': '1 comprimé'},
                  ],
                },
              ],
            ),
          ),
        ),
      );

      expect(find.text('Paracétamol'), findsOneWidget);
      expect(find.textContaining('500 mg'), findsOneWidget);
      expect(find.text('Texte ancien dupliqué'), findsNothing);
    },
  );
}
