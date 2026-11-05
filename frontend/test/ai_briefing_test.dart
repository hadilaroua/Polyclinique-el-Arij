import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/ai_briefing_screen.dart';

void main() {
  testWidgets('AiBriefingScreen affiche la synthèse Gemini épurée et adaptée', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    final mockBriefing = {
      'date': 'Vendredi 25 septembre 2026',
      'currentTime': '14h45',
      'shiftPeriod': 'Service de l\'après-midi (14h00 - 20h00)',
      'userRole': 'DOCTOR',
      'userDisplayName': 'Dr Karim Aroua',
      'greeting': 'Bonjour, Dr Aroua 👋',
      'aiSummary': 'À 14h45, le service enregistre 7 consultations et 3 patients hospitalisés. La priorité est donnée à la réévaluation des dossiers post-opératoires.',
      'metrics': {
        'consultationsCount': 7,
        'hospitalizedCount': 3,
        'pendingExamsCount': 2,
        'tasksCount': 4,
      },
      'aiTaskOrder': [
        {
          'order': 1,
          'time': '14h45',
          'title': 'Visite des patients hospitalisés prioritaires',
          'target': 'Chambre 201',
          'reason': 'Surveillance post-opératoire immédiate',
          'priority': 'HIGH',
        }
      ],
      'aiRecommendations': [
        {
          'title': 'Validation des gaz du sang',
          'description': 'Contrôler les bilans d\'hémostase reçus du laboratoire.',
          'category': 'Sécurité Clinique',
          'priority': 'HIGH',
        }
      ],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: AiBriefingScreen(briefingData: mockBriefing),
      ),
    );

    await tester.pump();

    // Vérification des éléments de la Hero Card et du rôle
    expect(find.text('Briefing IA Médical'), findsOneWidget);
    expect(find.text('MÉDECIN PRATICIEN'), findsOneWidget);
    expect(find.text('Bonjour, Dr Aroua 👋'), findsOneWidget);
    expect(find.text('14h45'), findsWidgets);

    // Vérification des 4 KPI métriques épurés
    expect(find.text('Actes'), findsOneWidget);
    expect(find.text('Hospitalisés'), findsOneWidget);
    expect(find.text('Examens'), findsOneWidget);
    expect(find.text('Alertes'), findsOneWidget);

    // Vérification de la synthèse Gemini
    expect(find.text('Synthèse en temps réel'), findsOneWidget);
    expect(find.text('GEMINI IA'), findsOneWidget);
    expect(find.textContaining('À 14h45, le service enregistre 7 consultations'), findsOneWidget);

    // Vérification des tâches et recommandations
    expect(find.text('Déroulé Prioritaire Recommandé'), findsOneWidget);
    expect(find.text('Vigilances & Conseils Pratiques'), findsOneWidget);
    expect(find.text('Détails par secteur clinique'), findsOneWidget);
  });
}
