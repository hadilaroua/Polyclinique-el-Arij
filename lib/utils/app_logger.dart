import 'package:flutter/material.dart';

/// Utilitaire de logging d'interface clinique pour Polyclinique El Arij
class AppLogger {
  static void logInterface(String interfaceName, {String? fileName, String? details}) {
    debugPrint('\n╔══════════════════════════════════════════════════════════════════════');
    debugPrint('║ 📱 [INTERFACE ACTIVE] : $interfaceName');
    if (fileName != null) {
      debugPrint('║ 📄 [FICHIER SOURCE]   : $fileName');
    }
    if (details != null) {
      debugPrint('║ ℹ️  [ACTION / ONGLET]  : $details');
    }
    debugPrint('╚══════════════════════════════════════════════════════════════════════\n');
  }
}

/// Observateur de navigation globale pour afficher automatiquement le nom de l'interface
class InterfaceLoggingNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRoute('OUVERTURE ÉCRAN', route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logRoute('REMPLACEMENT ÉCRAN', newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _logRoute('RETOUR VERS ÉCRAN', previousRoute);
    }
  }

  void _logRoute(String action, Route<dynamic> route) {
    final routeName = route.settings.name ?? route.runtimeType.toString();
    debugPrint('\n▶▶▶ 🧭 [$action] : $routeName ◀◀◀');
  }
}
