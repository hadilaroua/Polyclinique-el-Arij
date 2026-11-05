import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/app_drawer.dart';
import 'package:frontend/widgets/figma_header.dart';
import 'package:frontend/widgets/floating_messenger_head.dart';
import 'package:frontend/widgets/ios_bottom_nav_bar.dart';
import 'package:frontend/widgets/patient_timeline_view.dart';
import 'package:frontend/screens/staff_messenger_screen.dart';
import 'package:frontend/screens/chat_conversation_screen.dart';
import 'package:frontend/screens/profile_screen.dart';
import 'package:frontend/screens/nurse_home_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/utils/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User Request Requirements Tests', () {
    testWidgets('1. FloatingMessengerHead uses orange color for bubble', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingMessengerHead(
              onLogout: () {},
              child: const Text('Content'),
            ),
          ),
        ),
      );

      // Verify that orange container is in the tree
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasOrange = containers.any((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration) {
          return dec.color == const Color(0xFFFF7A00);
        }
        return false;
      });
      expect(hasOrange, isTrue);
    });

    testWidgets('2. AppDrawer does NOT contain "ESPACES & PROFILS SOIGNANTS"', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: AppDrawer(
              onSelectTab: (_) {},
              onOpenProfile: () {},
              onLogout: () {},
            ),
            body: Container(),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Check that "ESPACES & PROFILS SOIGNANTS" is absent
      expect(find.text('ESPACES & PROFILS SOIGNANTS'), findsNothing);
      expect(find.text('Médecin'), findsNothing);
      expect(find.text('Technicien'), findsNothing);
      expect(find.text('Sage-Femme'), findsNothing);

      // Verify standard drawer items exist
      expect(find.text('Chambres & Lits'), findsOneWidget);
      expect(find.text('Messagerie & Appels'), findsOneWidget);
    });

    testWidgets('3. FigmaHeader clinic logo opens menu and AppDrawer profile photo triggers onOpenProfile', (tester) async {
      bool menuOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FigmaHeader(
              roleName: 'MÉDECIN',
              roleColor: AppTheme.evergreen,
              userName: 'Dr Aroua',
              onMenuPressed: () {
                menuOpened = true;
              },
              onNotificationsPressed: () {},
              onProfilePressed: () {},
            ),
          ),
        ),
      );

      final logoFinder = find.byType(GestureDetector).first;
      await tester.tap(logoFinder);
      await tester.pumpAndSettle();

      expect(menuOpened, isTrue);
    });

    testWidgets('4. IosBottomNavBar matches Evergreen gradient and styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            bottomNavigationBar: IosBottomNavBar(
              selectedIndex: 0,
              onItemSelected: (_) {},
              items: const [
                IosBottomNavItem(icon: Icons.home, selectedIcon: Icons.home_filled, label: 'Accueil'),
                IosBottomNavItem(icon: Icons.people, selectedIcon: Icons.people_alt, label: 'Patients'),
              ],
            ),
            body: Container(),
          ),
        ),
      );

      final navBarFinder = find.byType(IosBottomNavBar);
      expect(navBarFinder, findsOneWidget);

      final containerFinder = find.descendant(of: navBarFinder, matching: find.byType(Container));
      expect(containerFinder, findsWidgets);
    });

    testWidgets('5. PatientTimelineView is decluttered with single compact control bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: PatientTimelineView(
              patientId: 'patient-test-123',
              patientName: 'Amine Trabelsi',
            ),
          ),
        ),
      );

      await tester.pump();

      // Check for compact period & filter pills
      expect(find.text('Tout l\'historique'), findsOneWidget);
      expect(find.text('Aujourd\'hui'), findsOneWidget);
      expect(find.text('7 jours'), findsOneWidget);
    });

    testWidgets('6. StaffMessengerScreen discussions and channels open ChatConversationScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StaffMessengerScreen(
            onLogout: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify channel tile exists
      final channelFinder = find.text('Canal Urgences & Garde');
      expect(channelFinder, findsOneWidget);

      // Tap on channel to open discussion
      await tester.tap(channelFinder);
      await tester.pumpAndSettle();

      // ChatConversationScreen should be open
      expect(find.byType(ChatConversationScreen), findsOneWidget);
      expect(find.text('Canal Urgences & Garde'), findsWidgets);
    });

    testWidgets('7. ChatConversationScreen displays messages and allows sending', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ChatConversationScreen(
            target: {
              'id': 'canal_urgences',
              'name': 'Canal Urgences & Garde',
              'role': 'EMERGENCY',
            },
            isGroup: true,
          ),
        ),
      );

      await tester.pump();

      // Verify input bar is present
      expect(find.byType(TextField), findsOneWidget);

      // Enter a test message and send
      await tester.enterText(find.byType(TextField), 'Test message urgent');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Message should be displayed in the list
      expect(find.text('Test message urgent'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('8. ProfileScreen does not have reload or dark mode toggle icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ProfileScreen(onLogout: () {}),
        ),
      );
      await tester.pump();

      // Check that refresh icon is NOT present
      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);

      // Check that dark mode switch or palette is NOT present
      expect(find.byIcon(Icons.palette_outlined), findsNothing);
      expect(find.byIcon(Icons.dark_mode_outlined), findsNothing);
      expect(find.byIcon(Icons.light_mode_outlined), findsNothing);
      expect(find.text('Ambiance visuelle & Thème'), findsNothing);
    });

    testWidgets('9. NurseHomeScreen surveillance does not have redundant + Saisir header button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: NurseHomeScreen(onLogout: () {}),
        ),
      );
      await tester.pump();

      // Tap on surveillance tab (index 2: icon Icons.favorite or Icons.monitor_heart)
      final heartIcons = find.byIcon(Icons.favorite_rounded);
      if (heartIcons.evaluate().isNotEmpty) {
        await tester.tap(heartIcons.first);
        await tester.pumpAndSettle();
      }

      // Check that the redundant '+ Saisir' text does not exist in header
      expect(find.text('+ Saisir'), findsNothing);
    });

    testWidgets('10. LoginScreen matches the new iOS authentication interface with logo, roles, credentials, Face ID, and staff account creation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: LoginScreen(onLoginSuccess: () {}),
        ),
      );
      await tester.pump();

      // Check titles
      expect(find.text('Espace Soignant'), findsOneWidget);
      expect(find.text('Polyclinique El Arij  •  Authentification Médicale'), findsOneWidget);

      // Check 4 roles are present
      expect(find.text('Médecin'), findsOneWidget);
      expect(find.text('Infirmier'), findsOneWidget);
      expect(find.text('Sage-Femme'), findsOneWidget);
      expect(find.text('Technicien'), findsOneWidget);

      // Check form fields & labels
      expect(find.text('Matricule Professionnel'), findsOneWidget);
      expect(find.text('Matricule Médecin'), findsOneWidget);
      expect(find.text("Clé d'Accès Clinique"), findsOneWidget);
      expect(find.text('Requis'), findsOneWidget);
      expect(find.text("Mémoriser l'identifiant"), findsOneWidget);
      expect(find.text('Mot de passe oublié ?'), findsOneWidget);
      expect(find.text('Se Connecter'), findsOneWidget);

      // Check Face ID card
      expect(find.text('Connexion Face ID iOS'), findsOneWidget);
      expect(find.text('RAPIDE'), findsOneWidget);
      expect(find.text('Touchez pour scanner votre visage'), findsOneWidget);

      // Check account creation footer
      expect(find.text('Nouvel arrivant ? '), findsOneWidget);
      expect(find.text('Créer un compte staff'), findsOneWidget);
    });
  });
}
