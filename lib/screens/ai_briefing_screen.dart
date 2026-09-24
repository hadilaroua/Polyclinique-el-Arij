import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'briefing_detail_screen.dart';

class AiBriefingScreen extends StatefulWidget {
  final Map<String, dynamic> briefingData;
  final VoidCallback? onBriefingUpdated;

  const AiBriefingScreen({
    super.key,
    required this.briefingData,
    this.onBriefingUpdated,
  });

  @override
  State<AiBriefingScreen> createState() => _AiBriefingScreenState();
}

class _AiBriefingScreenState extends State<AiBriefingScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late Map<String, dynamic> _data;
  bool _isRefreshing = false;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.briefingData);
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _refreshBriefing() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _spinController.repeat();

    try {
      final fresh = await _api.getDailyBriefing();
      if (mounted && fresh.isNotEmpty && fresh['metrics'] != null) {
        setState(() {
          _data = fresh;
          _isRefreshing = false;
        });
        _spinController.stop();
        _spinController.reset();
        widget.onBriefingUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Briefing IA actualisé avec succès'),
              ],
            ),
            backgroundColor: const Color(0xFF7047EB),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isRefreshing = false);
      _spinController.stop();
      _spinController.reset();
    }
  }

  void _shareBriefing() {
    final date = _data['date'] ?? 'Aujourd\'hui';
    final summary = _data['aiSummary'] ?? '';
    final text = '✨ Briefing IA - $date\n\n$summary\n\n-- Polyclinique El Arij';
    Share.share(text, subject: 'Briefing IA Clinique');
  }

  void _openDetail(String section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BriefingDetailScreen(
          briefingData: _data,
          scrollToSection: section,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final dateStr = _data['date'] ?? 'Lundi 26 mai 2025';
    final metrics = (_data['metrics'] as Map<String, dynamic>?) ?? {};
    final consultationsCount = metrics['consultationsCount'] ?? 7;
    final urgentConsultations = metrics['urgentConsultationsCount'] ?? 2;
    final hospitalizedCount = metrics['hospitalizedCount'] ?? 3;
    final toMonitorHospitalized = metrics['toMonitorHospitalizedCount'] ?? 1;
    final pendingExamsCount = metrics['pendingExamsCount'] ?? 2;
    final tasksCount = metrics['tasksCount'] ?? 4;
    final urgentTasks = metrics['urgentTasksCount'] ?? 1;

    final summaryText = _data['aiSummary'] ??
        "Aujourd'hui, vous avez $consultationsCount consultations planifiées. $hospitalizedCount patients hospitalisés nécessitent une surveillance régulière. $pendingExamsCount examens sont en attente de résultat et $tasksCount tâches importantes sont à finaliser. Une attention particulière est requise pour le patient en chambre 407.";

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textColor(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Briefing IA',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textColor(context),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.ios_share_rounded,
                color: AppTheme.textColor(context), size: 22),
            onPressed: _shareBriefing,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.borderColor(context)),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date pill + Badge "Généré avec l'IA" ────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.tropicalTeal),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.tropicalTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.tropicalTeal.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 13, color: AppTheme.tropicalTeal),
                      SizedBox(width: 5),
                      Text(
                        'IA Médicale Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.tropicalTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Main Card: Résumé intelligent de votre journée ─────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16252C) : const Color(0xFFF0FDF9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.tropicalTeal.withValues(alpha: isDark ? 0.35 : 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.tropicalTeal.withValues(alpha: isDark ? 0.15 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.tropicalTeal.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome, color: AppTheme.tropicalTeal, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Résumé Intelligent & Orientation',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F3E48),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    summaryText,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actualiser le brief button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _refreshBriefing,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.tropicalTeal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RotationTransition(
                            turns: _spinController,
                            child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isRefreshing ? 'Actualisation en cours...' : 'Actualiser le briefing IA',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Section: Ordre Recommandé des Tâches (AI Task Order) ────────
            if (_data['aiTaskOrder'] is List && (_data['aiTaskOrder'] as List).isNotEmpty) ...[
              const SizedBox(height: 26),
              Row(
                children: [
                  const Icon(Icons.format_list_numbered_rounded, size: 20, color: AppTheme.bondiBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Ordre Recommandé des Tâches',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...(_data['aiTaskOrder'] as List).map((taskItem) {
                final order = taskItem['order'] ?? 1;
                final title = taskItem['task'] ?? '';
                final reason = taskItem['reason'] ?? '';
                final priority = (taskItem['priority'] ?? 'NORMALE').toString().toUpperCase();

                Color badgeColor = AppTheme.oceanMist;
                if (priority.contains('URGENT')) {
                  badgeColor = AppTheme.danger;
                } else if (priority.contains('HAUT')) {
                  badgeColor = const Color(0xFFF59E0B);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderColor(context)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.tropicalTeal, AppTheme.bondiBlue],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$order',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
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
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textColor(context),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    priority,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: badgeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (reason.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                reason,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
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

            // ── Section: Recommandations & Conseils Cliniques (AI) ───────────
            if (_data['aiRecommendations'] is List && (_data['aiRecommendations'] as List).isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 20, color: AppTheme.tropicalTeal),
                  const SizedBox(width: 8),
                  Text(
                    'Conseils Cliniques & Vigilance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...(_data['aiRecommendations'] as List).map((recItem) {
                final title = recItem['title'] ?? '';
                final desc = recItem['description'] ?? '';
                final priority = (recItem['priority'] ?? 'MOYENNE').toString().toUpperCase();
                final category = recItem['category'] ?? 'CLINIQUE';

                Color prioColor = AppTheme.oceanMist;
                if (priority.contains('URGENT')) {
                  prioColor = AppTheme.danger;
                } else if (priority.contains('HAUT')) {
                  prioColor = const Color(0xFFF59E0B);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: prioColor.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: prioColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              priority,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: prioColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.tropicalTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.tropicalTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 24),

            // ── Section: Détails de la synthèse ─────────────────────────────
            Row(
              children: [
                const Icon(Icons.layers_outlined, size: 20, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(
                  'Détails de la synthèse',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 1. Planning des consultations
                  _buildSynthesisTile(
                    icon: Icons.calendar_month_rounded,
                    iconColor: AppTheme.tropicalTeal,
                    iconBg: AppTheme.tropicalTeal.withValues(alpha: 0.12),
                    title: 'Planning des consultations',
                    subtitle: 'Dont $urgentConsultations urgentes',
                    count: '$consultationsCount',
                    onTap: () => _openDetail('consultations'),
                  ),
                  _buildDivider(),

                  // 2. Patients hospitalisés
                  _buildSynthesisTile(
                    icon: Icons.hotel_rounded,
                    iconColor: AppTheme.oceanMist,
                    iconBg: AppTheme.oceanMist.withValues(alpha: 0.12),
                    title: 'Patients hospitalisés',
                    subtitle: '$toMonitorHospitalized à surveiller',
                    count: '$hospitalizedCount',
                    onTap: () => _openDetail('hospitalized'),
                  ),
                  _buildDivider(),

                  // 3. Examens en attente
                  _buildSynthesisTile(
                    icon: Icons.science_rounded,
                    iconColor: AppTheme.bondiBlue,
                    iconBg: AppTheme.bondiBlue.withValues(alpha: 0.12),
                    title: 'Examens en attente',
                    subtitle: 'Résultats à venir',
                    count: '$pendingExamsCount',
                    onTap: () => _openDetail('exams'),
                  ),
                  _buildDivider(),

                  // 4. Tâches à finaliser
                  _buildSynthesisTile(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppTheme.emerald,
                    iconBg: AppTheme.emerald.withValues(alpha: 0.12),
                    title: 'Tâches à finaliser',
                    subtitle: 'Dont $urgentTasks prioritaire',
                    count: '$tasksCount',
                    onTap: () => _openDetail('tasks'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Information alert banner ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Synthèse informative — adaptée à votre rôle et basée sur les dossiers cliniques réels.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSynthesisTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              count,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7047EB),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 68, color: AppTheme.borderColor(context));
  }
}
