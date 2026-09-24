import 'package:flutter/material.dart';
import '../screens/staff_messenger_screen.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/patient_timeline_view.dart';
import '../widgets/smart_patient_monitoring_view.dart';

class PatientDossierScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientDossierScreen({super.key, required this.patient});

  @override
  State<PatientDossierScreen> createState() => _PatientDossierScreenState();
}

class _PatientDossierScreenState extends State<PatientDossierScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _loading = true;
  bool _showRawVitals = false;
  List<dynamic> _consultations = [];
  List<dynamic> _exams = [];
  List<dynamic> _vitalSigns = [];
  List<dynamic> _auditLogs = [];
  Map<String, dynamic>? _activeStay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadPatientData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    setState(() => _loading = true);
    final patientId = widget.patient['_id']?.toString() ?? '';
    try {
      final results = await Future.wait([
        _api.getConsultations(patientId: patientId),
        _api.getExams(patientId: patientId),
        _api.getVitalSigns(patientId: patientId),
        _api.getAuditLogs(patientId: patientId),
        _api.getStays(patientId: patientId, status: 'ACTIVE'),
      ]);

      if (mounted) {
        setState(() {
          _consultations = results[0];
          _exams = results[1];
          _vitalSigns = results[2];
          _auditLogs = results[3];
          final stays = results[4];
          _activeStay = stays.isNotEmpty ? (stays.first as Map<String, dynamic>) : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _formatShortDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final pat = widget.patient;
    final fullName = '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim();
    final cin = pat['cin'] ?? 'N/A';
    final dossier = pat['dossierNumber'] ?? 'PAT-000';
    final bloodType = pat['bloodType'] ?? 'Inconnu';
    final allergies = pat['allergies'] is List
        ? (pat['allergies'] as List).join(', ')
        : (pat['allergies']?.toString() ?? 'Aucune');
    final hasAllergies = allergies.isNotEmpty &&
        allergies.toLowerCase() != 'aucune' &&
        allergies.toLowerCase() != 'aucune connue';
    final phone = pat['phone'] ?? '-';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textColor(context), size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Dossier Patient',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textColor(context),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded,
                color: AppTheme.tropicalTeal, size: 22),
            tooltip: 'Messagerie clinique',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffMessengerScreen(onLogout: () {}),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: AppTheme.subtextColor(context), size: 22),
            tooltip: 'Actualiser',
            onPressed: _loadPatientData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.borderColor(context),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.tropicalTeal))
          : Column(
              children: [
                // ── Patient Identity Card ─────────────────────────────────
                Container(
                  color: AppTheme.surfaceColor(context),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        fullName,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textColor(context),
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${pat['age'] ?? '?'} ans • ${pat['gender'] == 'M' ? 'Homme' : pat['gender'] == 'F' ? 'Femme' : (pat['gender'] ?? '')} • Dossier: $dossier',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.subtextColor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'CIN: $cin • Groupe: $bloodType • Tél: $phone',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.subtextColor(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          AvatarWidget(
                            avatarUrl: pat['avatarUrl'],
                            name: fullName,
                            radius: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Status & Hospitalization Pills
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Stay pill
                          if (_activeStay != null)
                            InkWell(
                              onTap: _showHospitalizationModal,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.tropicalTeal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.tropicalTeal.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.hotel_rounded, size: 14, color: AppTheme.tropicalTeal),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Chambre ${_activeStay!['roomId']?['number'] ?? _activeStay!['roomNumber'] ?? 'N/A'} • Lit ${_activeStay!['bedId']?['label'] ?? _activeStay!['bedId']?['number'] ?? 'A'}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.tropicalTeal,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.tropicalTeal),
                                  ],
                                ),
                              ),
                            )
                          else
                            InkWell(
                              onTap: _showHospitalizationModal,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.borderColor(context)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.hotel_outlined, size: 14, color: AppTheme.subtextColor(context)),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Ambulatoire (Non hospitalisé)',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.subtextColor(context),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.add_circle_outline, size: 13, color: AppTheme.tropicalTeal),
                                  ],
                                ),
                              ),
                            ),

                          // Allergy pill
                          if (hasAllergies)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.danger.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.danger),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Allergie: $allergies',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.danger,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.shield_outlined, size: 13, color: AppTheme.emerald),
                                  SizedBox(width: 4),
                                  Text(
                                    'Sans allergie connue',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.emerald,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Quick Actions Row (Modern Toolbar) ───────────────────
                Container(
                  width: double.infinity,
                  color: AppTheme.surfaceColor(context),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildQuickActionButton(
                          icon: Icons.assignment_outlined,
                          label: 'Consultation',
                          onTap: _showAddConsultationModal,
                          isPrimary: true,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickActionButton(
                          icon: Icons.science_outlined,
                          label: 'Examen',
                          onTap: _showAddExamModal,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickActionButton(
                          icon: Icons.monitor_heart_outlined,
                          label: 'Constantes',
                          onTap: _showAddVitalSignsModal,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickActionButton(
                          icon: Icons.meeting_room_outlined,
                          label: _activeStay != null ? 'Chambre ${_activeStay!['roomId']?['number'] ?? ''}' : 'Hospitaliser',
                          onTap: _showHospitalizationModal,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Tab Bar ───────────────────────────────────────────────
                Container(
                  color: AppTheme.surfaceColor(context),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: AppTheme.tropicalTeal,
                    unselectedLabelColor: AppTheme.subtextColor(context),
                    indicatorColor: AppTheme.tropicalTeal,
                    indicatorWeight: 2.5,
                    labelStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    dividerColor: AppTheme.borderColor(context),
                    tabs: [
                      Tab(text: 'Consultation (${_consultations.length})'),
                      Tab(text: 'Examens (${_exams.length})'),
                      const Tab(text: 'Constantes & Surveillance'),
                      const Tab(text: 'Timeline Parcours'),
                      Tab(text: 'Traçabilité (${_auditLogs.length})'),
                    ],
                  ),
                ),

                // ── Tab Content ───────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildConsultationsTab(),
                      _buildExamsTab(),
                      Column(
                        children: [
                          Container(
                            color: AppTheme.surfaceColor(context),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  _showRawVitals ? 'Mode Liste Brute' : 'Mode Graphique & Tendances',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.subtextColor(context),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setState(() => _showRawVitals = !_showRawVitals),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bondiBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _showRawVitals ? Icons.show_chart_rounded : Icons.list_alt_rounded,
                                          size: 14,
                                          color: AppTheme.bondiBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _showRawVitals ? 'Voir Graphiques' : 'Voir Tableau Brut',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.bondiBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _showRawVitals
                                ? _buildVitalSignsTab()
                                : SmartPatientMonitoringView(
                                    patientId: pat['_id']?.toString() ?? '',
                                    patientName: fullName,
                                    onNavigateToTimeline: () => _tabController.animateTo(3),
                                  ),
                          ),
                        ],
                      ),
                      PatientTimelineView(
                        patientId: pat['_id']?.toString() ?? '',
                        patientName: fullName,
                        onNavigateToMonitoring: () => _tabController.animateTo(2),
                      ),
                      _buildAuditLogsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppTheme.tropicalTeal
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary
                ? AppTheme.tropicalTeal
                : AppTheme.borderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.white : AppTheme.tropicalTeal,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isPrimary
                    ? Colors.white
                    : (isDark ? Colors.white : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAB 1: CONSULTATIONS
  // ==========================================================================

  Widget _buildConsultationsTab() {
    final isDark = AppTheme.isDarkMode(context);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Historique Clinique (${_consultations.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.tropicalTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Nouvelle',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: _showAddConsultationModal,
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_consultations.isEmpty)
          _buildEmptyState('Aucune consultation enregistrée pour ce patient.')
        else
          ..._consultations.map((c) {
            final doctor = c['doctorId'];
            final doctorName = doctor != null
                ? 'Dr. ${doctor['firstName'] ?? ''} ${doctor['lastName'] ?? ''}'.trim()
                : 'Médecin Praticien';
            final items = (c['prescriptionItems'] as List<dynamic>?) ?? [];
            final attachments = (c['attachments'] as List<dynamic>?) ?? [];
            final dateStr = _formatShortDate(c['date'] ?? c['createdAt']);

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.tropicalTeal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.tropicalTeal),
                            const SizedBox(width: 5),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppTheme.tropicalTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        doctorName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.bondiBlue,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Motive
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Motif : ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.subtextColor(context),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          c['motive'] ?? 'Consultation générale',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Diagnostic Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16252C) : const Color(0xFFF0FDF9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.tropicalTeal.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.assignment_turned_in_rounded, size: 17, color: AppTheme.tropicalTeal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Diagnostic : ${c['diagnostic'] ?? 'En cours d\'investigation'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark ? Colors.white : const Color(0xFF0F3E48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (c['clinicalExam'] != null && (c['clinicalExam'] as String).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Examen clinique : ${c['clinicalExam']}',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.subtextColor(context)),
                    ),
                  ],

                  // Ordonnance
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Prescription médicamenteuse :',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Column(
                      children: items.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderColor(context)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.medication_rounded, size: 16, color: AppTheme.bondiBlue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${item['medicine']} ${item['dosage'] ?? ''} — ${item['posology'] ?? ''} ${item['frequency'] ?? ''} (${item['duration'] ?? ''})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textColor(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ] else if (c['prescription'] != null && (c['prescription'] as String).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Prescription : ${c['prescription']}',
                      style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: AppTheme.subtextColor(context)),
                    ),
                  ],

                  // Attachments
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: attachments.map((att) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.tropicalTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.attach_file, size: 14, color: AppTheme.tropicalTeal),
                              const SizedBox(width: 4),
                              Text(
                                att['name'] ?? 'Document joint',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.tropicalTeal),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  if (c['followUpDate'] != null && (c['followUpDate'] as String).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.event_repeat_rounded, size: 14, color: AppTheme.emerald),
                        const SizedBox(width: 5),
                        Text(
                          'Prochain suivi : ${c['followUpDate']}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================================================
  // TAB 2: EXAMENS
  // ==========================================================================

  Widget _buildExamsTab() {
    final isDark = AppTheme.isDarkMode(context);
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Plateau Technique (${_exams.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textColor(context),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.bondiBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.science_outlined, size: 16),
              label: const Text(
                'Prescrire',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: _showAddExamModal,
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_exams.isEmpty)
          _buildEmptyState('Aucun examen prescrit ou réalisé pour ce patient.')
        else
          ..._exams.map((exam) {
            final status = (exam['status'] ?? 'PENDING').toString().toUpperCase();
            final isCompleted = status == 'COMPLETED';
            final isInProgress = status == 'IN_PROGRESS';

            Color statusColor = const Color(0xFFD97706);
            String statusLabel = 'En attente';

            if (isCompleted) {
              statusColor = AppTheme.emerald;
              statusLabel = 'Validé / Terminé';
            } else if (isInProgress) {
              statusColor = AppTheme.bondiBlue;
              statusLabel = 'En cours';
            }

            final priority = (exam['priority'] ?? 'MEDIUM').toString().toUpperCase();
            Color prioColor = AppTheme.oceanMist;
            if (priority.contains('HIGH') || priority.contains('URGENT')) {
              prioColor = AppTheme.danger;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                        child: Text(
                          exam['examType'] ?? 'Examen Médical',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: prioColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Priorité: $priority',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: prioColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Service: ${exam['service'] ?? 'Général'}',
                        style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                      ),
                    ],
                  ),

                  if (exam['requestNotes'] != null && (exam['requestNotes'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Indication : ${exam['requestNotes']}',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.subtextColor(context), fontStyle: FontStyle.italic),
                    ),
                  ],

                  if (!isCompleted) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emerald,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.edit_note, size: 16),
                        label: const Text(
                          'Saisir Résultat',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () => _showCompleteExamModal(exam),
                      ),
                    ),
                  ],

                  if (isCompleted) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF132A1C) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.emerald.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 15, color: AppTheme.emerald),
                              SizedBox(width: 6),
                              Text(
                                'Résultat Validé :',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                  color: AppTheme.emerald,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            exam['result'] ?? 'Conforme aux normes.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFFBBF7D0) : const Color(0xFF14532D),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (exam['technicalNotes'] != null && (exam['technicalNotes'] as String).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Notes technicien: ${exam['technicalNotes']}',
                              style: TextStyle(fontSize: 11.5, color: AppTheme.subtextColor(context)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================================================
  // TAB 3: CONSTANTES VITALES
  // ==========================================================================

  Widget _buildVitalSignsTab() {
    final isDark = AppTheme.isDarkMode(context);

    if (_vitalSigns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monitor_heart_outlined, size: 52, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 12),
              const Text('Aucune constante vitale enregistrée pour ce patient.', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tropicalTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Prendre les Constantes', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: _showAddVitalSignsModal,
              ),
            ],
          ),
        ),
      );
    }

    final latest = _vitalSigns.first;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dernières Constantes Relevées',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.textColor(context),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.tropicalTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Prendre',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: _showAddVitalSignsModal,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid of 4 KPIs
        Row(
          children: [
            Expanded(
              child: _buildVitalKpi(
                'Température',
                '${latest['temperature'] ?? '-'} °C',
                Icons.thermostat_rounded,
                (latest['temperature'] ?? 37.0) >= 38.5,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildVitalKpi(
                'Pouls (FC)',
                '${latest['heartRate'] ?? '-'} bpm',
                Icons.favorite_rounded,
                (latest['heartRate'] ?? 75) > 110,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildVitalKpi(
                'Tension (TA)',
                '${latest['bloodPressureSystolic'] ?? '-'}/${latest['bloodPressureDiastolic'] ?? '-'}',
                Icons.speed_rounded,
                (latest['bloodPressureSystolic'] ?? 120) > 150,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildVitalKpi(
                'Oxygène (SpO2)',
                '${latest['oxygenSaturation'] ?? '-'} %',
                Icons.air_rounded,
                (latest['oxygenSaturation'] ?? 98) < 94,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Text(
          'Historique de Surveillance (${_vitalSigns.length})',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: AppTheme.textColor(context),
          ),
        ),
        const SizedBox(height: 12),

        ..._vitalSigns.map((v) {
          final isFever = (v['temperature'] ?? 0) >= 38.5;
          final isHypox = (v['oxygenSaturation'] ?? 100) < 94;
          final isAbnormal = isFever || isHypox;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isAbnormal
                  ? (isDark ? const Color(0xFF2A1517) : const Color(0xFFFFF1F2))
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAbnormal
                    ? AppTheme.danger.withValues(alpha: 0.4)
                    : AppTheme.borderColor(context),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(v['recordedAt']),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    if (isAbnormal)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Anomalie',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'T°: ${v['temperature'] ?? '-'}°C   •   FC: ${v['heartRate'] ?? '-'} bpm   •   TA: ${v['bloodPressureSystolic'] ?? '-'}/${v['bloodPressureDiastolic'] ?? '-'}   •   SpO2: ${v['oxygenSaturation'] ?? '-'}%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isAbnormal ? AppTheme.danger : AppTheme.subtextColor(context),
                  ),
                ),
                if (v['notes'] != null && (v['notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Notes: ${v['notes']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.subtextColor(context),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVitalKpi(String label, String value, IconData icon, bool alert) {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alert
            ? (isDark ? const Color(0xFF2A1517) : const Color(0xFFFEE2E2))
            : (isDark ? const Color(0xFF1E293B) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alert ? AppTheme.danger : AppTheme.borderColor(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (alert ? AppTheme.danger : AppTheme.tropicalTeal).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: alert ? AppTheme.danger : AppTheme.tropicalTeal, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: alert ? AppTheme.danger : AppTheme.subtextColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: alert ? AppTheme.danger : AppTheme.textColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 4: TRACABILITE AUDIT LOGS
  // ==========================================================================

  Widget _buildAuditLogsTab() {
    final isDark = AppTheme.isDarkMode(context);
    if (_auditLogs.isEmpty) {
      return _buildEmptyState('Aucun acte clinique consigné dans le journal pour ce patient.');
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        final action = log['action'] ?? '';
        final actor = log['actorName'] ?? 'Personnel soignant';
        final details = log['details'] ?? '';
        final date = _formatDate(log['createdAt']);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.tropicalTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, size: 16, color: AppTheme.tropicalTeal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          actor,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(fontSize: 11, color: AppTheme.subtextColor(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textColor(context)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                          color: AppTheme.subtextColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppTheme.subtextColor(context)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // MODALS: ACTIONS
  // ==========================================================================

  void _showAddConsultationModal() {
    final motiveCtrl = TextEditingController();
    final diagCtrl = TextEditingController();
    final examCtrl = TextEditingController();
    final symptomsCtrl = TextEditingController();
    final followUpCtrl = TextEditingController();

    final List<Map<String, TextEditingController>> medItems = [];

    void addMedicine() {
      medItems.add({
        'name': TextEditingController(),
        'dosage': TextEditingController(),
        'posology': TextEditingController(),
        'duration': TextEditingController(),
      });
    }

    addMedicine(); // Start with 1 item

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.assignment_add, color: AppTheme.tropicalTeal, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Nouvelle Consultation',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: motiveCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motif de consultation *',
                    hintText: 'Ex: Suivi hypertension, Douleurs...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: diagCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Diagnostic Médical *',
                    hintText: 'Ex: Hypertension artérielle stade 1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: symptomsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Symptômes observés',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: examCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Examen clinique',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Prescriptions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Prescriptions médicamenteuses',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setModalState(addMedicine),
                      icon: const Icon(Icons.add, size: 16, color: AppTheme.tropicalTeal),
                      label: const Text('+ Médicament', style: TextStyle(color: AppTheme.tropicalTeal, fontSize: 12)),
                    ),
                  ],
                ),
                ...medItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: item['name'],
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Médicament #${idx + 1}',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: item['dosage'],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Dosage',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: item['posology'],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Posologie (Ex: 1 cp matin)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: item['duration'],
                                decoration: const InputDecoration(
                                  isDense: true,
                                  labelText: 'Durée (Ex: 7 jours)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 10),
                TextField(
                  controller: followUpCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Date de suivi recommandée (Optionnel)',
                    hintText: 'Ex: 15/10/2025',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tropicalTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      if (motiveCtrl.text.trim().isEmpty || diagCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez remplir le motif et le diagnostic')),
                        );
                        return;
                      }

                      final itemsPayload = medItems
                          .where((i) => i['name']!.text.trim().isNotEmpty)
                          .map((i) => {
                                'medicine': i['name']!.text.trim(),
                                'dosage': i['dosage']!.text.trim(),
                                'posology': i['posology']!.text.trim(),
                                'frequency': '',
                                'duration': i['duration']!.text.trim(),
                              })
                          .toList();

                      final patientId = (widget.patient['_id'] ?? widget.patient['id'])?.toString() ?? '';
                      final docUserId = (_api.currentUser?['id'] ?? _api.currentUser?['_id'])?.toString() ?? '';

                      if (patientId.isEmpty || docUserId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Identifiant patient ou médecin introuvable')),
                        );
                        return;
                      }

                      final res = await _api.createConsultation(
                        patientId: patientId,
                        doctorId: docUserId,
                        motive: motiveCtrl.text.trim(),
                        diagnostic: diagCtrl.text.trim(),
                        symptoms: symptomsCtrl.text.trim(),
                        clinicalExam: examCtrl.text.trim(),
                        prescriptionItems: itemsPayload.isNotEmpty ? itemsPayload : null,
                        followUpDate: followUpCtrl.text.trim(),
                      );

                      if (res['success'] == true) {
                        if (mounted) {
                          Navigator.pop(ctx);
                          _loadPatientData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF059669),
                              content: Text('✅ Consultation enregistrée avec succès'),
                            ),
                          );
                        }
                      } else {
                        final errMsg = res['data']?['message'] ?? res['error'] ?? 'Erreur';
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFFDC2626),
                              content: Text('❌ Erreur: $errMsg'),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Enregistrer la consultation', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddExamModal() {
    final typeCtrl = TextEditingController();
    final serviceCtrl = TextEditingController(text: 'Laboratoire');
    final notesCtrl = TextEditingController();
    String priority = 'MEDIUM';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.science_rounded, color: AppTheme.bondiBlue, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Prescrire un Examen',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Type d\'examen *',
                    hintText: 'Ex: NFS, Bilan lipidique, Radio Thorax, Écho...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: serviceCtrl.text,
                  decoration: const InputDecoration(labelText: 'Service de destination', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Laboratoire', child: Text('Laboratoire de biologie')),
                    DropdownMenuItem(value: 'Radiologie', child: Text('Radiologie / Imagerie')),
                    DropdownMenuItem(value: 'PMA', child: Text('Centre PMA / Fertilité')),
                    DropdownMenuItem(value: 'Général', child: Text('Plateau Général')),
                  ],
                  onChanged: (v) => setModalState(() => serviceCtrl.text = v ?? 'Laboratoire'),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Niveau de priorité', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'LOW', child: Text('Basse (Routine)')),
                    DropdownMenuItem(value: 'MEDIUM', child: Text('Normale (Standard)')),
                    DropdownMenuItem(value: 'HIGH', child: Text('Haute (Sous 24h)')),
                    DropdownMenuItem(value: 'URGENT', child: Text('URGENT (Immédiat)')),
                  ],
                  onChanged: (v) => setModalState(() => priority = v ?? 'MEDIUM'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Indication clinique & instructions',
                    hintText: 'Ex: Recherche anémie, suspicion fracture...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.bondiBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      if (typeCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez spécifier le type d\'examen')),
                        );
                        return;
                      }

                      final currentUserId = _api.currentUser?['id'] ?? _api.currentUser?['_id'] ?? '';
                      try {
                        await _api.createExam(
                          patientId: widget.patient['_id']?.toString() ?? '',
                          requestingDoctorId: currentUserId,
                          examType: typeCtrl.text.trim(),
                          priority: priority,
                          service: serviceCtrl.text,
                          requestNotes: notesCtrl.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(ctx);
                          _loadPatientData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Examen prescrit avec succès')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Valider la prescription', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddVitalSignsModal() {
    final tempCtrl = TextEditingController(text: '37.0');
    final sysCtrl = TextEditingController(text: '120');
    final diaCtrl = TextEditingController(text: '80');
    final hrCtrl = TextEditingController(text: '75');
    final spo2Ctrl = TextEditingController(text: '98');
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.monitor_heart_rounded, color: AppTheme.tropicalTeal, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Prise de Constantes Vitales',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tempCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Température (°C)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: hrCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Pouls (bpm)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: sysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'TA Systolique (mmHg)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: diaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'TA Diastolique (mmHg)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: spo2Ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Saturation O2 (%)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observations soignantes (Optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tropicalTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    try {
                      await _api.createVitalSign(
                        patientId: widget.patient['_id']?.toString() ?? '',
                        temperature: double.tryParse(tempCtrl.text) ?? 37.0,
                        heartRate: int.tryParse(hrCtrl.text) ?? 75,
                        bloodPressureSystolic: int.tryParse(sysCtrl.text) ?? 120,
                        bloodPressureDiastolic: int.tryParse(diaCtrl.text) ?? 80,
                        oxygenSaturation: int.tryParse(spo2Ctrl.text) ?? 98,
                        notes: notesCtrl.text.trim(),
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadPatientData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Constantes enregistrées avec succès')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Enregistrer dans le dossier', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHospitalizationModal() async {
    final patientId = widget.patient['_id']?.toString() ?? '';

    if (_activeStay != null) {
      // Patient is admitted: show stay details + discharge option
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.hotel_rounded, color: AppTheme.tropicalTeal, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Séjour Hospitalier Actif',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Chambre : ${_activeStay!['roomId']?['number'] ?? _activeStay!['roomNumber'] ?? 'N/A'}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Lit : ${_activeStay!['bedId']?['label'] ?? _activeStay!['bedId']?['number'] ?? 'Lit standard'} • Service : ${_activeStay!['service'] ?? 'Maternité'}',
                style: TextStyle(fontSize: 13, color: AppTheme.subtextColor(context)),
              ),
              const SizedBox(height: 4),
              Text(
                'Admis le : ${_formatDate(_activeStay!['admissionDate'])}',
                style: TextStyle(fontSize: 12.5, color: AppTheme.subtextColor(context)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                  label: const Text('Prononcer la sortie (Décharge)', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () async {
                    try {
                      await _api.dischargePatient(stayId: _activeStay!['_id']);
                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadPatientData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sortie du patient enregistrée')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Patient is not admitted: show rooms with beds to admit
      List<dynamic> roomsWithBeds = [];
      try {
        roomsWithBeds = await _api.getRoomsWithBeds();
      } catch (_) {}

      if (!mounted) return;

      String? selectedBedId;
      String selectedService = 'MATERNITE';
      final reasonCtrl = TextEditingController(text: 'Surveillance clinique');

      final freeBeds = <Map<String, dynamic>>[];
      for (final r in roomsWithBeds) {
        final beds = (r['beds'] as List<dynamic>?) ?? [];
        for (final b in beds) {
          if (b['status'] == 'AVAILABLE' || b['isOccupied'] == false) {
            freeBeds.add({
              'bedId': b['_id']?.toString() ?? '',
              'label': 'Ch. ${r['number']} • Lit ${b['number'] ?? b['label'] ?? 'A'} (${r['service'] ?? 'Général'})',
              'service': r['service'] ?? 'MATERNITE',
            });
          }
        }
      }

      if (freeBeds.isNotEmpty) {
        selectedBedId = freeBeds.first['bedId'];
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.hotel_rounded, color: AppTheme.tropicalTeal, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Hospitaliser le Patient',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textColor(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (freeBeds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Aucun lit disponible pour le moment. Veuillez libérer un lit depuis la gestion des chambres.',
                          style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600),
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        value: selectedBedId,
                        decoration: const InputDecoration(labelText: 'Sélectionner une chambre & un lit libre', border: OutlineInputBorder()),
                        items: freeBeds.map((fb) {
                          return DropdownMenuItem<String>(
                            value: fb['bedId'],
                            child: Text(fb['label']),
                          );
                        }).toList(),
                        onChanged: (v) => setModalState(() => selectedBedId = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonCtrl,
                        decoration: const InputDecoration(labelText: 'Motif d\'admission', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.tropicalTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            if (selectedBedId == null) return;
                            try {
                              await _api.admitPatient(
                                patientId: patientId,
                                bedId: selectedBedId!,
                                service: selectedService,
                                admissionReason: reasonCtrl.text.trim(),
                              );
                              if (mounted) {
                                Navigator.pop(ctx);
                                _loadPatientData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Patient hospitalisé avec succès')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e')),
                                );
                              }
                            }
                          },
                          child: const Text('Confirmer l\'affectation de lit', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
  }

  void _showCompleteExamModal(Map<String, dynamic> exam) {
    final examId = exam['_id']?.toString() ?? '';
    final examTitle = exam['examType'] ?? 'Examen';
    final resultCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.science_rounded, color: AppTheme.emerald, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saisie Résultat : $examTitle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: resultCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Résultats & Conclusions techniques *',
                  hintText: 'Saisir les résultats ou compte-rendu...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes internes (Automates / Réactifs)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Valider & Clôturer l\'Examen', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () async {
                    if (resultCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veuillez renseigner le résultat')),
                      );
                      return;
                    }
                    try {
                      await _api.completeExam(
                        examId,
                        resultCtrl.text.trim(),
                        notes: notesCtrl.text.trim(),
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadPatientData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Résultat d\'examen validé')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
