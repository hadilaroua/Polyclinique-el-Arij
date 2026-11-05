import 'package:flutter/material.dart';

import 'screens/doctor_home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/midwife_home_screen.dart';
import 'screens/nurse_home_screen.dart';
import 'screens/technician_home_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'utils/app_logger.dart';
import 'utils/theme.dart';
import 'widgets/floating_messenger_head.dart';

/// Global navigator key — allows logout from anywhere in the widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.initTheme();
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
    try {
      // 1. Initialiser le service de notification en arrière-plan sans bloquer
      notif.init().catchError((e) {
        debugPrint('Notif init error: $e');
      });

      // Durée d'affichage minimale de 3 secondes pour le splashscreen
      await Future.delayed(const Duration(seconds: 3));

      final hasSession = await api.tryAutoLogin();
      if (hasSession) notif.startAlertMonitoring(api);
    } catch (e) {
      debugPrint('App init error: $e');
    } finally {
      if (mounted) {
        setState(() => _checkingSession = false);
      }
    }
  }

  void _handleLogout() {
    notif.stopAlertMonitoring();
    api.logout();
    // Use the global navigatorKey to clear the stack and go to LoginScreen
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(onLoginSuccess: _handleLoginSuccess)),
      (_) => false,
    );
  }

  void _handleLoginSuccess() {
    notif.startAlertMonitoring(api);
    // Resolve which home screen to show based on role
    final role = api.currentUser?['role']?.toString().toUpperCase() ?? 'DOCTOR';
    Widget screen;
    switch (role) {
      case 'NURSE':
        screen = NurseHomeScreen(onLogout: _handleLogout);
        break;
      case 'MIDWIFE':
        screen = MidwifeHomeScreen(onLogout: _handleLogout);
        break;
      case 'TECHNICIAN':
        screen = TechnicianHomeScreen(onLogout: _handleLogout);
        break;
      case 'DOCTOR':
      case 'ADMIN':
      default:
        screen = DoctorHomeScreen(onLogout: _handleLogout);
        break;
    }
    final homeWidget = FloatingMessengerHead(onLogout: _handleLogout, child: screen);
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => homeWidget),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [InterfaceLoggingNavigatorObserver()],
          title: 'El ArijFlow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: _checkingSession ? _buildSplashScreen() : _resolveRootScreen(),
        );
      },
    );
  }

  Widget _buildSplashScreen() {
    final isDark = AppTheme.isDark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A1E1A) : const Color(0xFFFAF8F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(34),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.fern.withValues(alpha: 0.22),
                    blurRadius: 36,
                    offset: const Offset(0, 12),
                  ),
                ],
                border: Border.all(color: AppTheme.fern.withValues(alpha: 0.35), width: 1.8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/logo-polyclinique-arij.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.local_hospital_rounded,
                    size: 72,
                    color: AppTheme.hunterGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'El ArijFlow',
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.pineTeal,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coordination Clinique • Polyclinique El Arij',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF4A5D52),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A00).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFFFF7A00).withValues(alpha: 0.35)),
                  ),
                  child: const Text(
                    'Système d\'Information Hospitalier & Soins',
                    style: TextStyle(
                      color: Color(0xFFFF7A00),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3.2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.fern),
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
      case 'NURSE':
        screen = NurseHomeScreen(onLogout: _handleLogout);
        break;
      case 'MIDWIFE':
        screen = MidwifeHomeScreen(onLogout: _handleLogout);
        break;
      case 'TECHNICIAN':
        screen = TechnicianHomeScreen(onLogout: _handleLogout);
        break;
      case 'DOCTOR':
      case 'ADMIN':
      default:
        screen = DoctorHomeScreen(onLogout: _handleLogout);
        break;
    }
    return FloatingMessengerHead(onLogout: _handleLogout, child: screen);
  }
}
