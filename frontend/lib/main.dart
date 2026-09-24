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

      // 2. Tenter la restauration de session avec un timeout strict
      final loggedIn = await api.tryAutoLogin().timeout(
        const Duration(milliseconds: 800),
        onTimeout: () => false,
      );
      if (loggedIn) {
        notif.startAlertMonitoring(api);
      }
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
      MaterialPageRoute(
        builder: (_) => LoginScreen(onLoginSuccess: _handleLoginSuccess),
      ),
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
          title: 'Polyclinique Arij Djerba — Staff',
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
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryBondi.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.border,
                  width: 1,
                ),
              ),
              child: Image.asset(
                'assets/logo-polyclinique-arij.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.local_hospital_rounded, size: 42, color: AppTheme.secondaryBondi),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Polyclinique Arij Djerba',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextMain : AppTheme.primaryNavy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Système Hospitalier & Soins Intégrés',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryBondi),
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
