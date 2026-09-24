import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar_widget.dart';
import 'ai_briefing_screen.dart';
import 'briefing_detail_screen.dart';
import 'profile_screen.dart';
import 'staff_messenger_screen.dart';

class DailyBriefingScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final Function(int)? onNavigateTab; // To switch tabs in doctor/nurse screen if desired

  const DailyBriefingScreen({
    super.key,
    required this.onLogout,
    this.onNavigateTab,
  });

  @override
  State<DailyBriefingScreen> createState() => _DailyBriefingScreenState();
}

class _DailyBriefingScreenState extends State<DailyBriefingScreen> {
  final ApiService _api = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  Map<String, dynamic> _briefing = {};
  int _currentBottomNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBriefing();
  }

  Future<void> _loadBriefing() async {
    try {
      final data = await _api.getDailyBriefing();
      if (mounted && data.isNotEmpty && data['metrics'] != null) {
        setState(() {
          _briefing = data;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback riche pour affichage parfait en développement ou hors ligne
    if (mounted) {
      setState(() {
        _briefing = _getDefaultBriefingData();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getDefaultBriefingData() {
    final user = _api.currentUser;
    final lastName = user?['lastName'] ?? 'Aroua';
    return {
      'date': 'Lundi 26 mai 2025',
      'rawDate': '2025-05-26',
      'greeting': 'Bonjour, Dr $lastName 👋',
      'subGreeting': 'Voici votre briefing du jour',
      'serviceName': user?['service'] ?? 'Service Médecine Interne',
      'weather': {
        'temp': '26°C',
        'city': 'Djerba',
        'condition': 'Ensoleillé',
      },
      'metrics': {
        'consultationsCount': 7,
        'urgentConsultationsCount': 2,
        'hospitalizedCount': 3,
        'toMonitorHospitalizedCount': 1,
        'pendingExamsCount': 2,
        'tasksCount': 4,
        'urgentTasksCount': 1,
      },
      'nextAppointment': {
        'time': '09:30',
        'title': 'Consultation - Médecine Interne',
        'room': 'Salle 3 • Dr $lastName',
        'doctor': 'Dr $lastName',
        'patientName': 'Ahmed Ben Salah',
      },
      'aiSummary':
          "Aujourd'hui, vous avez 7 consultations planifiées. 3 patients hospitalisés nécessitent une surveillance régulière. 2 examens sont en attente de résultat et 4 tâches importantes sont à finaliser. Une attention particulière est requise pour le patient en chambre 407.",
      'aiSummaryPreview':
          "Vous avez 7 consultations planifiées aujourd'hui. 2 examens sont en attente de résultat et 3 patients hospitalisés nécessitent un suivi particulier.",
      'consultationsList': [
        {'time': '09:30', 'title': 'Consultation - Médecine Interne', 'room': 'Salle 3', 'specialty': 'Médecine Interne', 'isUrgent': true, 'patientName': 'Ahmed Ben Salah'},
        {'time': '11:00', 'title': 'Consultation - Cardiologie', 'room': 'Salle 1', 'specialty': 'Cardiologie', 'isUrgent': false, 'patientName': 'Fatma Triki'},
        {'time': '14:00', 'title': 'Consultation - Pneumologie', 'room': 'Salle 2', 'specialty': 'Pneumologie', 'isUrgent': true, 'patientName': 'Moncef Trabelsi'},
        {'time': '15:15', 'title': 'Consultation - Contrôle diabète', 'room': 'Salle 3', 'specialty': 'Médecine Interne', 'isUrgent': false, 'patientName': 'Samia Mabrouk'},
        {'time': '16:00', 'title': 'Consultation - Suivi cardiologique', 'room': 'Salle 1', 'specialty': 'Cardiologie', 'isUrgent': false, 'patientName': 'Kamel Dridi'},
        {'time': '16:45', 'title': 'Consultation - Bilan biologique', 'room': 'Salle 3', 'specialty': 'Médecine Interne', 'isUrgent': false, 'patientName': 'Rim Ben Salem'},
        {'time': '17:30', 'title': 'Consultation - Avis pneumologique', 'room': 'Salle 2', 'specialty': 'Pneumologie', 'isUrgent': false, 'patientName': 'Hédi Zouari'},
      ],
      'hospitalizedList': [
        {'room': 'Chambre 204', 'service': 'Médecine Interne', 'status': 'Stable', 'statusColor': 'green', 'patientName': 'Yassine Khelil'},
        {'room': 'Chambre 312', 'service': 'Cardiologie', 'status': 'En cours', 'statusColor': 'blue', 'patientName': 'Leila Bouaziz'},
        {'room': 'Chambre 407', 'service': 'Pneumologie', 'status': 'À surveiller', 'statusColor': 'orange', 'patientName': 'Salem Ghrissi'},
      ],
      'pendingExamsList': [
        {'title': 'Scanner thoracique', 'patientName': 'Patient (S. Ghrissi)', 'department': 'Radiologie', 'status': 'En attente'},
        {'title': 'Bilan biologique', 'patientName': 'Patient (Y. Khelil)', 'department': 'Laboratoire', 'status': 'En attente'},
      ],
      'tasksList': [
        {'id': 't1', 'title': 'Rendre compte de la visite', 'location': 'Chambre 204', 'time': '10:30', 'isCompleted': false, 'isPriority': true},
        {'id': 't2', 'title': 'Vérifier résultats biologiques', 'location': 'Laboratoire', 'time': '11:00', 'isCompleted': false, 'isPriority': false},
        {'id': 't3', 'title': 'Valider ordonnance de sortie', 'location': 'Chambre 312', 'time': '15:00', 'isCompleted': false, 'isPriority': false},
        {'id': 't4', 'title': 'Contrôle tensionnel post-perfusion', 'location': 'Salle de soins', 'time': '16:30', 'isCompleted': false, 'isPriority': false},
      ],
    };
  }

  void _openDetail({String? section}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BriefingDetailScreen(
          briefingData: _briefing,
          scrollToSection: section,
          onRefresh: _loadBriefing,
        ),
      ),
    );
  }

  void _openAiBriefing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiBriefingScreen(
          briefingData: _briefing,
          onBriefingUpdated: _loadBriefing,
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          onProfileUpdated: () => setState(() {}),
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  void _openMessenger() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffMessengerScreen(onLogout: widget.onLogout),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final user = _api.currentUser;
    final fullName = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();
    final greeting = _briefing['greeting'] ?? 'Bonjour, Dr Aroua 👋';
    final subGreeting = _briefing['subGreeting'] ?? 'Voici votre briefing du jour';
    final serviceName = _briefing['serviceName'] ?? 'Service Médecine Interne';
    final dateStr = _briefing['date'] ?? 'Lundi 26 mai 2025';
    final metrics = (_briefing['metrics'] as Map<String, dynamic>?) ?? {};
    final consultationsCount = metrics['consultationsCount'] ?? 7;
    final hospitalizedCount = metrics['hospitalizedCount'] ?? 3;
    final pendingExamsCount = metrics['pendingExamsCount'] ?? 2;
    final tasksCount = metrics['tasksCount'] ?? 4;
    final aiSummaryPreview = _briefing['aiSummaryPreview'] ??
        "Vous avez 7 consultations planifiées aujourd'hui. 2 examens sont en attente de résultat et 3 patients hospitalisés nécessitent un suivi particulier.";
    final nextAppointment = (_briefing['nextAppointment'] as Map<String, dynamic>?) ?? {};

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      drawer: AppDrawer(
        onSelectTab: (idx) {
          if (widget.onNavigateTab != null) {
            widget.onNavigateTab!(idx);
          }
        },
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadBriefing,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top Header (Brand, Service, Notification, Avatar) ──
                      _buildHeader(serviceName, user, fullName),

                      const SizedBox(height: 18),

                      // ── Greeting & Weather Row ──────────────────────────────
                      _buildGreetingRow(greeting, subGreeting),

                      const SizedBox(height: 14),

                      // ── Date pill ───────────────────────────────────────────
                      _buildDatePill(dateStr),

                      const SizedBox(height: 18),

                      // ── 4 KPI Metric Cards (2x2 Grid) ───────────────────────
                      _buildMetricCardsGrid(
                        consultationsCount,
                        hospitalizedCount,
                        pendingExamsCount,
                        tasksCount,
                      ),

                      const SizedBox(height: 18),

                      // ── Résumé de la journée (IA Card) ──────────────────────
                      _buildAiSummaryCard(aiSummaryPreview),

                      const SizedBox(height: 18),

                      // ── Prochain rendez-vous Card ───────────────────────────
                      _buildNextAppointmentCard(nextAppointment),

                      const SizedBox(height: 22),

                      // ── Button: Voir le planning complet ────────────────────
                      _buildFullPlanningButton(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Top Header Widget ─────────────────────────────────────────────────────
  Widget _buildHeader(String serviceName, Map<String, dynamic>? user, String fullName) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.menu_rounded, size: 26),
          color: AppTheme.textColor(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        const SizedBox(width: 12),
        // Clinic icon + title
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Icon(Icons.local_hospital_rounded, color: Color(0xFF2563EB), size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Polyclinique Arij Djerba',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor(context),
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                serviceName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Notification bell with red badge 1
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, size: 24),
              color: AppTheme.textColor(context),
              onPressed: () => _openDetail(section: 'tasks'),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        // Avatar
        GestureDetector(
          onTap: _openProfile,
          child: AvatarWidget(
            avatarUrl: user?['avatarUrl'],
            name: fullName.isNotEmpty ? fullName : 'Dr Aroua',
            radius: 17,
          ),
        ),
      ],
    );
  }

  // ── Greeting & Weather Row ────────────────────────────────────────────────
  Widget _buildGreetingRow(String greeting, String subGreeting) {
    final isDark = AppTheme.isDarkMode(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textColor(context),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subGreeting,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        // Weather widget
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '26°C',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Djerba',
                    style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Date pill ─────────────────────────────────────────────────────────────
  Widget _buildDatePill(String dateStr) {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF64748B)),
          const SizedBox(width: 7),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4 KPI Metric Cards (2x2 Grid) ─────────────────────────────────────────
  Widget _buildMetricCardsGrid(
    int consultationsCount,
    int hospitalizedCount,
    int pendingExamsCount,
    int tasksCount,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.calendar_month_rounded,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF9333EA),
                count: '$consultationsCount',
                label: 'Consultations prévues',
                onTap: () => _openDetail(section: 'consultations'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.hotel_rounded,
                iconBg: const Color(0xFFCCFBF1),
                iconColor: const Color(0xFF0D9488),
                count: '$hospitalizedCount',
                label: 'Patients hospitalisés suivis',
                onTap: () => _openDetail(section: 'hospitalized'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.science_rounded,
                iconBg: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
                count: '$pendingExamsCount',
                label: 'Examens en attente',
                onTap: () => _openDetail(section: 'exams'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.check_circle_outline_rounded,
                iconBg: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                count: '$tasksCount',
                label: 'Tâches à finaliser',
                onTap: () => _openDetail(section: 'tasks'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor(context),
                    height: 1.1,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 18, color: const Color(0xFF94A3B8)),
              ],
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Résumé de la journée (IA Card) ─────────────────────────────────────────
  Widget _buildAiSummaryCard(String summaryText) {
    final isDark = AppTheme.isDarkMode(context);
    return InkWell(
      onTap: _openAiBriefing,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.4) : const Color(0xFFFAF7FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9D5FF).withValues(alpha: isDark ? 0.3 : 0.8)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7047EB).withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF7047EB), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Résumé de la journée',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7047EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'IA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF7047EB), size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summaryText,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Prochain rendez-vous Card ──────────────────────────────────────────────
  Widget _buildNextAppointmentCard(Map<String, dynamic> nextAppointment) {
    final isDark = AppTheme.isDarkMode(context);
    final time = nextAppointment['time'] ?? '09:30';
    final title = nextAppointment['title'] ?? 'Consultation - Médecine Interne';
    final room = nextAppointment['room'] ?? 'Salle 3 • Dr Aroua';

    return InkWell(
      onTap: () => _openDetail(section: 'consultations'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                SizedBox(width: 6),
                Text(
                  'Prochain rendez-vous',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7047EB),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        room,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Button: Voir le planning complet ──────────────────────────────────────
  Widget _buildFullPlanningButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BriefingDetailScreen(
                briefingData: _briefing,
                showSmartSummary: true,
                onRefresh: _loadBriefing,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7047EB),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Planning complet (IA)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Navigation Bar ─────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, CupertinoIcons.square_grid_2x2, CupertinoIcons.square_grid_2x2_fill, 'Accueil'),
              _buildNavItem(1, CupertinoIcons.person_2, CupertinoIcons.person_2_fill, 'Patients'),
              _buildNavItem(2, CupertinoIcons.waveform_path_ecg, CupertinoIcons.waveform_path_ecg, 'Examens'),
              _buildNavItem(3, CupertinoIcons.chat_bubble_2, CupertinoIcons.chat_bubble_2_fill, 'Messages', badgeCount: 2),
              _buildNavItem(4, CupertinoIcons.bars, CupertinoIcons.bars, 'Plus'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, {int? badgeCount}) {
    final isSelected = _currentBottomNavIndex == index;
    final primaryActive = AppTheme.tropicalTeal;
    final isDark = AppTheme.isDarkMode(context);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: () {
        setState(() => _currentBottomNavIndex = index);
        if (index == 3) {
          _openMessenger();
        } else if (index == 4) {
          _scaffoldKey.currentState?.openDrawer();
        } else if (index == 1 && widget.onNavigateTab != null) {
          widget.onNavigateTab!(1); // Navigate to Patients tab in doctor screen
        } else if (index == 2 && widget.onNavigateTab != null) {
          widget.onNavigateTab!(2); // Navigate to Exams tab in doctor screen
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryActive.withValues(alpha: isDark ? 0.22 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: 22,
                    color: isSelected ? primaryActive : inactiveColor,
                  ),
                ),
                if (badgeCount != null)
                  Positioned(
                    right: 4,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
                color: isSelected ? primaryActive : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
