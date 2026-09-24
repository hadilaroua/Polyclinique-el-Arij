import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Timer? _alertPollingTimer;
  final Set<String> _notifiedAlertIds = {};

  Future<void> init() async {
    if (_isInitialized) return;

    // Configuration Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuration iOS / macOS
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Configuration Linux
    final LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(
      defaultActionName: 'Ouvrir',
      defaultIcon: AssetsLinuxIcon('assets/logo-polyclinique-arij.png'),
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification cliquée : ${response.payload}');
        },
      );

      // Demander la permission sur Android 13+
      if (!kIsWeb && Platform.isAndroid) {
        final androidImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      }

      // Demander la permission sur iOS
      if (!kIsWeb && Platform.isIOS) {
        final iosImplementation = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        await iosImplementation
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            )
            .timeout(
              const Duration(milliseconds: 1500),
              onTimeout: () => null,
            );
      }
    } catch (e) {
      debugPrint('NotificationService: fallback / environnement de test sans canal natif ($e)');
    }

    _isInitialized = true;
  }

  /// Déclencher une notification native sur le téléphone (iOS & Android)
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isCritical = false,
  }) async {
    try {
      await init();

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'arij_medical_channel',
        'Alertes & Soins Polyclinique Arij',
        channelDescription:
            'Notifications prioritaires pour les alertes cliniques et résultats de soins',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Alerte Polyclinique Arij',
        enableVibration: true,
        playSound: true,
        color: Color(0xFF0284C7),
      );

      const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Notification display skipped or not supported on this platform: $e');
    }
  }

  /// Notification spécifique pour une alerte médicale
  Future<void> showClinicalAlert({
    required String title,
    required String description,
    String level = 'URGENT',
    String? patientName,
  }) async {
    final prefix = level == 'CRITICAL' ? '🚨 [URGENCE VITALE]' : '⚠️ [ALERTE MÉDICALE]';
    final fullTitle = '$prefix $title';
    final bodyText = patientName != null && patientName.isNotEmpty
        ? 'Patient: $patientName — $description'
        : description;

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: fullTitle,
      body: bodyText,
      isCritical: level == 'CRITICAL' || level == 'URGENT',
    );
  }

  /// Surveillance active des alertes en tâche de fond / périodique (temps réel : 2.5s)
  void startAlertMonitoring(ApiService api) {
    stopAlertMonitoring();

    // Enregistrer les alertes déjà existantes pour ne pas spammer au lancement
    _seedExistingAlertIds(api);

    // Polling ultra-rapide toutes les 2.5 secondes pour synchronisation en temps réel
    _alertPollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _checkNewAlerts(api);
    });
  }

  Future<void> _seedExistingAlertIds(ApiService api) async {
    try {
      final alerts = await api.getAlerts(isResolved: false);
      for (final a in alerts) {
        final id = a['_id']?.toString();
        if (id != null) _notifiedAlertIds.add(id);
      }
    } catch (_) {}
  }

  void stopAlertMonitoring() {
    _alertPollingTimer?.cancel();
    _alertPollingTimer = null;
  }

  Future<void> _checkNewAlerts(ApiService api) async {
    if (!api.isAuthenticated) return;

    try {
      final alerts = await api.getAlerts(isResolved: false);
      for (final alert in alerts) {
        final alertId = alert['_id']?.toString();
        if (alertId == null) continue;

        if (!_notifiedAlertIds.contains(alertId)) {
          _notifiedAlertIds.add(alertId);

          final patient = alert['patientId'];
          String? patientName;
          if (patient is Map) {
            patientName = '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim();
          }

          final targetDoctor = alert['targetDoctorId'];
          String? targetInfo;
          if (targetDoctor is Map) {
            targetInfo = '🎯 Destiné à Dr. ${targetDoctor['firstName'] ?? ''} ${targetDoctor['lastName'] ?? ''}'.trim();
          }

          final desc = alert['description'] ?? 'Nouvelle alerte médicale enregistrée.';
          final combinedDesc = targetInfo != null ? '$targetInfo — $desc' : desc;

          await showClinicalAlert(
            title: alert['title'] ?? 'Alerte Clinique',
            description: combinedDesc,
            level: alert['level'] ?? 'URGENT',
            patientName: patientName,
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur surveillance notifications : $e');
    }
  }
}
