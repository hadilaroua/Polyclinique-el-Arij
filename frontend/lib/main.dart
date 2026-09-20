import 'package:flutter/material.dart';
import 'screens/doctor_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/midwife_home_screen.dart';
import 'screens/nurse_home_screen.dart';
import 'screens/technician_home_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'utils/theme.dart';
import 'widgets/floating_messenger_head.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ArijApp());
}

class ArijApp extends StatefulWidget {
  const ArijApp({super.key});

  @override
  State<ArijApp> createState() => _ArijAppState();
}

class _ArijAppState extends State<ArijApp> {
  final api = ApiService();
  final notif = NotificationService();
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. Initialiser le service de notification native
    await notif.init();

    // 2. Tenter la restauration automatique de session
    final loggedIn = await api.tryAutoLogin();
    if (loggedIn) {
      // Démarrer l'écoute continue des alertes médicales
      notif.startAlertMonitoring(api);
    }

    if (mounted) {
      setState(() => _checkingSession = false);
    }
  }

  void _handleLogout() {
    notif.stopAlertMonitoring();
    api.logout();
    setState(() {});
  }

  void _handleLoginSuccess() {
    notif.startAlertMonitoring(api);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Polyclinique Arij Djerba — Staff',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: _checkingSession ? _buildSplashScreen() : _resolveRootScreen(),
    );
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: AppTheme.chocolatePlum,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.burntRose.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logo-polyclinique-arij.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.local_hospital, size: 40, color: AppTheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Polyclinique Arij Djerba',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Connexion sécurisée en cours...',
              style: TextStyle(
                color: AppTheme.pearlAqua,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.pearlAqua),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resolveRootScreen() {

    if (!api.isAuthenticated) {
      return LoginScreen(onLoginSuccess: _handleLoginSuccess);
    }

    final role = api.currentUser?['role']?.toString().toUpperCase() ?? 'DOCTOR';
    Widget screen;

    switch (role) {
      case 'DOCTOR':
        screen = DoctorHomeScreen(onLogout: _handleLogout);
        break;
      case 'NURSE':
        screen = NurseHomeScreen(onLogout: _handleLogout);
        break;
      case 'MIDWIFE':
        screen = MidwifeHomeScreen(onLogout: _handleLogout);
        break;
      case 'TECHNICIAN':
        screen = TechnicianHomeScreen(onLogout: _handleLogout);
        break;
      case 'ADMIN':
      default:
        screen = DoctorHomeScreen(onLogout: _handleLogout);
        break;
    }

    return FloatingMessengerHead(
      onLogout: _handleLogout,
      child: screen,
    );
  }

}
