import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_service.dart';
import '../utils/app_logger.dart';
import '../utils/theme.dart';
import 'briefing_detail_screen.dart';
import 'ai_voice_assistant_screen.dart';

class AiBriefingScreen extends StatefulWidget {
  final Map<String, dynamic> briefingData;
  final VoidCallback? onBriefingUpdated;
  final String? initialRole;

  const AiBriefingScreen({
    super.key,
    required this.briefingData,
    this.onBriefingUpdated,
    this.initialRole,
  });

  @override
  State<AiBriefingScreen> createState() => _AiBriefingScreenState();
}

class _AiBriefingScreenState extends State<AiBriefingScreen> {
  final ApiService _api = ApiService();
  late Map<String, dynamic> _data;
  bool _isRefreshing = false;

  // ── Voice Agent State & Interactive Prompts (Stitch Innovation) ──
  bool _isVoiceActive = true;
  int _selectedVoicePromptIndex = 0;

  final List<Map<String, String>> _voicePrompts = [
    {
      'chip': 'Résumer la garde',
      'query': '« Quel est le point de situation de la garde à 08h00 ? »',
      'response':
          '« Relève de 08h00 : 34 lits occupés (85%), 4 alertes de constantes en cours de stabilisation et 2 bilans STAT au labo. La priorité est la visite en Ch. 12. »',
    },
    {
      'chip': 'Alerte SpO2 Mme Amor',
      'query': '« Quelle est l\'évolution de la saturation de Mme Amor en Ch. 08 ? »',
      'response':
          '« Mme Fatma Ben Amor (Ch. 08) : SpO2 stabilisée à 91% sous 2L/min d\'O2. Adaptation du débit à 3.5L/min et gazométrie de contrôle conseillées. »',
    },
    {
      'chip': 'Disponibilité lits',
      'query': '« Combien de lits d\'hospitalisation sont libres ? »',
      'response':
          '« 6 lits libres actuellement : 2 en Cardiologie, 3 en Médecine Générale et 1 en Soins Continus. »',
    },
    {
      'chip': 'Risque Sepsis Ch. 12',
      'query': '« Détail de l\'alerte sur le patient Trabelsi ? »',
      'response':
          '« M. Trabelsi (Ch. 12) : Dérive thermique (+1.2°C en 2h, T° 39.1°C) et tachycardie à 108 bpm. Hémoculture STAT recommandée. »',
    },
  ];

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.briefingData);
    final role = _resolveUserRole();
    final time = _data['currentTime'] ?? _formatCurrentTime();
    AppLogger.logInterface(
      'Briefing IA Médical (Gemini)',
      fileName: 'ai_briefing_screen.dart',
      details: 'Ouverture synthèse pour $role à $time',
    );
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '${h}h$m';
  }

  String _resolveUserRole() {
    if (widget.initialRole != null && widget.initialRole!.isNotEmpty) {
      return widget.initialRole!.toUpperCase();
    }
    final user = _api.currentUser;
    final r = (user?['role'] ?? _data['userRole'] ?? 'DOCTOR').toString().toUpperCase();
    return r;
  }

  Map<String, dynamic> _getRolePresentation(String role) {
    switch (role) {
      case 'DOCTOR':
        return {
          'label': 'Médecin Praticien',
          'icon': Icons.medical_services_rounded,
          'focus': 'Consultations, diagnostics & réévaluation',
          'badgeColor': AppTheme.evergreen,
          'badgeBg': const Color(0xFFEDF2EA),
          'badgeText': AppTheme.evergreen,
        };
      case 'NURSE':
        return {
          'label': 'Soins Infirmiers',
          'icon': Icons.healing_rounded,
          'focus': 'Traitements, constantes & surveillance',
          'badgeColor': AppTheme.evergreen,
          'badgeBg': const Color(0xFFEDF2EA),
          'badgeText': AppTheme.evergreen,
        };
      case 'MIDWIFE':
        return {
          'label': 'Maternité & Obstétrique',
          'icon': Icons.pregnant_woman_rounded,
          'focus': 'Surveillance RCF, travail & post-partum',
          'badgeColor': AppTheme.evergreen,
          'badgeBg': const Color(0xFFEDF2EA),
          'badgeText': AppTheme.evergreen,
        };
      case 'TECHNICIAN':
        return {
          'label': 'Plateau Technique & Labo',
          'icon': Icons.biotech_rounded,
          'focus': 'Analyses urgentes, imagerie & validation',
          'badgeColor': AppTheme.evergreen,
          'badgeBg': const Color(0xFFEDF2EA),
          'badgeText': AppTheme.evergreen,
        };
      default:
        return {
          'label': 'Équipe Médicale',
          'icon': Icons.health_and_safety_rounded,
          'focus': 'Coordination clinique & continuité',
          'badgeColor': AppTheme.evergreen,
          'badgeBg': const Color(0xFFEDF2EA),
          'badgeText': AppTheme.evergreen,
        };
    }
  }

  Future<void> _refreshBriefing() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    final role = _resolveUserRole();
    AppLogger.logInterface(
      'Actualisation Briefing IA',
      fileName: 'ai_briefing_screen.dart',
      details: 'Requête directe Gemini AI pour le rôle $role',
    );

    try {
      final fresh = await _api.getDailyBriefing();
      if (mounted && fresh.isNotEmpty && (fresh['metrics'] != null || fresh['aiSummary'] != null)) {
        setState(() {
          _data = fresh;
          _isRefreshing = false;
        });
        widget.onBriefingUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Briefing $role actualisé par ${_data['isRealAi'] == true ? 'Gemini IA' : 'IA locale'} (${_data['currentTime'] ?? _formatCurrentTime()})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.evergreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
        return;
      }
    } catch (e) {
      AppLogger.logInterface(
        'Erreur Refresh Briefing',
        fileName: 'ai_briefing_screen.dart',
        details: e.toString(),
      );
    }

    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  void _shareBriefing() {
    final date = _data['date'] ?? 'Aujourd\'hui';
    final time = _data['currentTime'] ?? _formatCurrentTime();
    final summary = _data['aiSummary'] ?? '';
    final role = _resolveUserRole();
    final text =
        '✨ Briefing IA Médical ($role) - $date à $time\n\n$summary\n\n-- Polyclinique El Arij (Djerba)';
    Share.share(text, subject: 'Briefing IA Clinique - Polyclinique El Arij');
  }

  void _openDetail(String section) {
    AppLogger.logInterface(
      'Détail Secteur Briefing',
      fileName: 'ai_briefing_screen.dart',
      details: 'Navigation vers section : $section',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BriefingDetailScreen(briefingData: _data, scrollToSection: section),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final role = _resolveUserRole();
    final rolePres = _getRolePresentation(role);
    final isRealAi = _data['isRealAi'] != false;
    final providerLabel = isRealAi ? 'Gemini IA' : 'IA locale';

    final dateStr = _data['date'] ?? 'Aujourd\'hui';
    final currentTimeStr = _data['currentTime'] ?? _formatCurrentTime();
    final shiftPeriod = _data['shiftPeriod'] ?? 'Service en cours';

    final metrics = (_data['metrics'] as Map<String, dynamic>?) ?? {};
    final consultationsCount = metrics['consultationsCount'] ?? 0;
    final hospitalizedCount = metrics['hospitalizedCount'] ?? 0;
    final pendingExamsCount = metrics['pendingExamsCount'] ?? 0;
    final tasksCount = metrics['tasksCount'] ?? 0;

    final user = _api.currentUser;
    final lastName = user?['lastName'] ?? _data['userDisplayName'] ?? 'Soignant';
    final greeting = _data['greeting'] ?? 'Bonjour, Dr $lastName';

    final summaryText = (_data['aiSummary'] ?? '').toString().trim().isNotEmpty
        ? _data['aiSummary'].toString().trim()
        : 'Analyse clinique en direct : la charge de soins est orientée sur la prise en charge immédiate des urgences, la validation des bilans et la continuité des soins à $currentTimeStr.';

    final taskOrder = (_data['aiTaskOrder'] as List<dynamic>?) ?? [];
    final recommendations = (_data['aiRecommendations'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.evergreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Briefing IA Médical',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Assistant Vocal Plein Écran',
            icon: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (_) => const AiVoiceAssistantScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Partager le briefing',
            icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 21),
            onPressed: _shareBriefing,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBriefing,
        color: AppTheme.evergreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Hero Card Stitch Pro Crimson (Aéré, Rôle & Horodatage Réel) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.evergreen, AppTheme.evergreen],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.evergreen.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pilule Rôle & IA Active
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(rolePres['icon'] as IconData, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    (rolePres['label'] as String).toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppTheme.evergreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                currentTimeStr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateStr • $shiftPeriod',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Généré par $providerLabel',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 2. Strip Compact des KPI Métriques (4 Mini-Pills aérées) ──────
              Row(
                children: [
                  _buildMetricPill(
                    context: context,
                    icon: Icons.medical_services_rounded,
                    label: 'Actes',
                    count: '$consultationsCount',
                    color: AppTheme.evergreen,
                    onTap: () => _openDetail('consultations'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    context: context,
                    icon: Icons.hotel_rounded,
                    label: 'Hospitalisés',
                    count: '$hospitalizedCount',
                    color: AppTheme.evergreen,
                    onTap: () => _openDetail('hospitalized'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    context: context,
                    icon: Icons.biotech_rounded,
                    label: 'Examens',
                    count: '$pendingExamsCount',
                    color: AppTheme.evergreen,
                    onTap: () => _openDetail('exams'),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    context: context,
                    icon: Icons.notifications_active_rounded,
                    label: 'Alertes',
                    count: '$tasksCount',
                    color: AppTheme.alertRed,
                    onTap: () => _openDetail('tasks'),
                    isDark: isDark,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── 3. Synthèse Clinique Intelligente (Carte Claire, Aérée) ──────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppTheme.evergreen.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: AppTheme.evergreen,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Synthèse en temps réel',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textColor(context),
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDF2EA),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            isRealAi ? 'GEMINI IA' : 'IA LOCALE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isRealAi ? AppTheme.evergreen : AppTheme.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      summaryText,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.dustGrey : AppTheme.darkElevated,
                      ),
                    ),
                  ],
                ),
              ),

              // ── 4. Déroulé & Ordre Recommandé des Tâches (Task Order) ────────
              if (taskOrder.isNotEmpty) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Icon(
                      Icons.format_list_numbered_rounded,
                      size: 18,
                      color: AppTheme.evergreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Déroulé Prioritaire Recommandé',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textColor(context),
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...taskOrder.map((taskItem) {
                  final order = taskItem['order'] ?? 1;
                  final time = (taskItem['time'] ?? currentTimeStr).toString();
                  final title = (taskItem['title'] ?? taskItem['task'] ?? '').toString();
                  final target = (taskItem['target'] ?? '').toString();
                  final reason = (taskItem['reason'] ?? '').toString();
                  final priority = (taskItem['priority'] ?? 'NORMALE').toString().toUpperCase();

                  final isUrgent = priority.contains('URGENT') || priority.contains('HIGH');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isUrgent
                            ? AppTheme.alertRed.withValues(alpha: 0.4)
                            : (isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pastille Numéro / Heure
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isUrgent ? const Color(0xFFEDF2EA) : const Color(0xFFEDF2EA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '$order',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isUrgent ? AppTheme.alertRed : AppTheme.evergreen,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.darkElevated
                                          : const Color(0xFFEDF2EA),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      time,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.evergreen,
                                      ),
                                    ),
                                  ),
                                  if (target.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        target,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B7E72),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ] else
                                    const Spacer(),
                                  if (isUrgent) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.alertRed,
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: const Text(
                                        'URGENT',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textColor(context),
                                ),
                              ),
                              if (reason.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  reason,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7E72),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // ── 5. Conseils Cliniques & Vigilances (Recommendations) ─────────
              if (recommendations.isNotEmpty) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded, size: 18, color: AppTheme.pastelOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vigilances & Conseils Pratiques',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textColor(context),
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...recommendations.map((rec) {
                  final title = (rec['title'] ?? '').toString();
                  final desc = (rec['description'] ?? '').toString();
                  final category = (rec['category'] ?? 'Clinique').toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.evergreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                category.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.evergreen,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: AppTheme.evergreen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            desc,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7E72),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 22),

              // ── 5. Innovation Star : Module Vocal Flottant Mains-Libres "Arij Voice AI" ──
              _buildVoiceAgentCard(context, isDark),

              // ── 6. Accès Rapide par Secteur (Non Encombré) ───────────────────
              Text(
                'Détails par secteur clinique',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor(context),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildSectorCard(
                      context: context,
                      title: 'Consultations',
                      count: '$consultationsCount prévues',
                      icon: Icons.calendar_month_rounded,
                      onTap: () => _openDetail('consultations'),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSectorCard(
                      context: context,
                      title: 'Hospitalisation',
                      count: '$hospitalizedCount lits actifs',
                      icon: Icons.hotel_rounded,
                      onTap: () => _openDetail('hospitalized'),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSectorCard(
                      context: context,
                      title: 'Examens / Labo',
                      count: '$pendingExamsCount en attente',
                      icon: Icons.science_rounded,
                      onTap: () => _openDetail('exams'),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSectorCard(
                      context: context,
                      title: 'Tâches & Alertes',
                      count: '$tasksCount à traiter',
                      icon: Icons.checklist_rounded,
                      onTap: () => _openDetail('tasks'),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ── MODULE VOCAL MAINS-LIBRES (ARIJ VOICE AI - STITCH PRO ARCHITECTURE) ───
  // ===========================================================================

  Widget _buildVoiceAgentCard(BuildContext context, bool isDark) {
    final activePrompt = _voicePrompts[_selectedVoicePromptIndex];
    const emeraldPrimary = Color(0xFF063D2E);
    const terracottaOrange = Color(0xFFD97746);
    const mintGreen = Color(0xFF10B981);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: emeraldPrimary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: mintGreen.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: emeraldPrimary.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header du module vocal ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF003E28),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: mintGreen.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.graphic_eq_rounded,
                        color: mintGreen,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ARIJ VOICE AI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFBAEED8),
                              letterSpacing: 0.8,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Mains-libres salle d\'examen',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF77A894),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isVoiceActive = !_isVoiceActive);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: (_isVoiceActive ? terracottaOrange : Colors.white24).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _isVoiceActive ? terracottaOrange : Colors.white38,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isVoiceActive ? 'Écoute Active' : 'En Veille',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const AiVoiceAssistantScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.fullscreen_rounded, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Orbe Haptique Central & Égaliseur Dynamique ─────────────────────
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Halo d'ambiance double
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        terracottaOrange.withValues(alpha: _isVoiceActive ? 0.25 : 0.05),
                        mintGreen.withValues(alpha: _isVoiceActive ? 0.2 : 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Bouton Orbe Principal
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _isVoiceActive = !_isVoiceActive);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isVoiceActive
                            ? const [Color(0xFF1E4F3F), Color(0xFF00261B), Color(0xFF063D2E)]
                            : const [Color(0xFF17211C), Color(0xFF202C25)],
                      ),
                      border: Border.all(
                        color: _isVoiceActive ? const Color(0xFF6FFBBE).withValues(alpha: 0.6) : Colors.white24,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isVoiceActive ? const Color(0xFF6FFBBE) : Colors.black).withValues(alpha: 0.35),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Barres d'onde sonore (soundwave equalizer)
                        if (_isVoiceActive)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSoundBar(height: 14, color: mintGreen),
                              const SizedBox(width: 3.5),
                              _buildSoundBar(height: 24, color: terracottaOrange),
                              const SizedBox(width: 3.5),
                              _buildSoundBar(height: 32, color: Colors.white),
                              const SizedBox(width: 3.5),
                              _buildSoundBar(height: 20, color: const Color(0xFFFF9561)),
                              const SizedBox(width: 3.5),
                              _buildSoundBar(height: 12, color: mintGreen),
                            ],
                          )
                        else
                          const Icon(Icons.mic_off_rounded, color: Colors.white54, size: 26),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Bulle de Transcription Live ────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_alt_rounded, size: 14, color: Color(0xFFFFDBCC)),
                    const SizedBox(width: 6),
                    Text(
                      'Gemini Santé Synthèse Live'.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFDBCC),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  activePrompt['response']!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFFE1F6E7),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Suggestions rapides interactives (Pills) ───────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(_voicePrompts.length, (idx) {
                final isSelected = _selectedVoicePromptIndex == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedVoicePromptIndex = idx;
                        _isVoiceActive = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(100),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? terracottaOrange.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected ? terracottaOrange : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _voicePrompts[idx]['chip']!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFFFFDBCC) : const Color(0xFFBAEED8),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundBar({required double height, required Color color}) {
    return Container(
      width: 3.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildMetricPill({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String count,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(height: 4),
              Text(
                count,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.darkBackground,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6B7E72),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectorCard({
    required BuildContext context,
    required String title,
    required String count,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.evergreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: AppTheme.evergreen),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    count,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF6B7E72)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.drySage),
          ],
        ),
      ),
    );
  }
}
