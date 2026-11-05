import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/ai_voice_assistant_screen.dart';

void main() {
  testWidgets('AiVoiceAssistantScreen affiche l\'orbe vocal épuré et simule l\'interaction vocale', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));

    await tester.pumpWidget(
      const MaterialApp(
        home: AiVoiceAssistantScreen(),
      ),
    );

    await tester.pump();

    // Vérification de l'interface épurée
    expect(find.text('ARIJ VOICE • EN LIGNE'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    // Vérification de l'accueil initial
    expect(find.textContaining('Bonjour'), findsOneWidget);

    // Déclenchement de la simulation via le tap sur l'orbe
    await tester.tap(find.byKey(const Key('voice_orb_button')));
    await tester.pump();

    // État écoute actif
    expect(find.text('MICROPHONE ACTIF'), findsOneWidget);
    expect(find.text('Écoute en cours...'), findsOneWidget);

    // Avancement du timer de simulation vers thinking puis speaking
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 1000));

    // Vérification de la réponse vocale de l'IA avec le nom du soignant
    expect(find.text('RÉPONSE VOCALE'), findsOneWidget);
    expect(find.textContaining('comment puis-je vous aider'), findsOneWidget);
  });
}
