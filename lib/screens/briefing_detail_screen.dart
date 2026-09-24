import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/theme.dart';

class BriefingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> briefingData;
  final VoidCallback? onRefresh;
  final int initialTabIndex; // 0: Synthèse complète, 1: Par catégorie
  final String? scrollToSection; // 'consultations', 'hospitalized', 'exams', 'tasks'
  final bool showSmartSummary;

  const BriefingDetailScreen({
    super.key,
    required this.briefingData,
    this.onRefresh,
    this.initialTabIndex = 0,
    this.scrollToSection,
    this.showSmartSummary = false,
  });

  @override
  State<BriefingDetailScreen> createState() => _BriefingDetailScreenState();
}

class _BriefingDetailScreenState extends State<BriefingDetailScreen> {
  int _selectedTab = 0; // 0: Synthèse complète, 1: Par catégorie
  String _categoryFilter = 'ALL'; // ALL, CONSULTATIONS, HOSPITALIZED, EXAMS, TASKS
  bool _expandConsultations = false;
  late Map<String, dynamic> _data;
  late List<dynamic> _tasks;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    _data = Map<String, dynamic>.from(widget.briefingData);
    _tasks = List<dynamic>.from(_data['tasksList'] ?? []);

    if (widget.scrollToSection != null) {
      if (widget.scrollToSection == 'consultations') _categoryFilter = 'CONSULTATIONS';
      if (widget.scrollToSection == 'hospitalized') _categoryFilter = 'HOSPITALIZED';
      if (widget.scrollToSection == 'exams') _categoryFilter = 'EXAMS';
      if (widget.scrollToSection == 'tasks') _categoryFilter = 'TASKS';
    }
  }

  void _shareBriefing() {
    final date = _data['date'] ?? 'Aujourd\'hui';
    final summary = _data['aiSummary'] ?? '';
    final text = '📋 Briefing Clinique - $date\n\n$summary\n\n-- Polyclinique El Arij';
    Share.share(text, subject: 'Briefing Clinique');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final dateStr = _data['date'] ?? 'Lundi 26 mai 2025';
    final consultations = (_data['consultationsList'] as List?) ?? [];
    final hospitalized = (_data['hospitalizedList'] as List?) ?? [];
    final exams = (_data['pendingExamsList'] as List?) ?? [];

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
          'Détail du briefing',
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
            // ── Date pill ──────────────────────────────────────────────
            _buildDatePill(dateStr),

            const SizedBox(height: 16),

            // ── AI Summary ─────────────────────────────────────────────
            if (widget.showSmartSummary && _data['aiSummary'] != null && _data['aiSummary'].toString().isNotEmpty) ...[
              _buildSmartSummary(_data['aiSummary']),
              const SizedBox(height: 16),
            ],

            // ── Segmented Control: Synthèse complète / Par catégorie ──
            _buildSegmentedControl(),

            const SizedBox(height: 20),

            if (_selectedTab == 1) ...[
              _buildCategoryPills(),
              const SizedBox(height: 16),
            ],

            // ── Section 1 : Planning des consultations ─────────────────
            if (_selectedTab == 0 || _categoryFilter == 'ALL' || _categoryFilter == 'CONSULTATIONS') ...[
              _buildConsultationsSection(consultations),
              const SizedBox(height: 20),
            ],

            // ── Section 2 : Patients hospitalisés ──────────────────────
            if (_selectedTab == 0 || _categoryFilter == 'ALL' || _categoryFilter == 'HOSPITALIZED') ...[
              _buildHospitalizedSection(hospitalized),
              const SizedBox(height: 20),
            ],

            // ── Section 3 : Examens en attente ─────────────────────────
            if (_selectedTab == 0 || _categoryFilter == 'ALL' || _categoryFilter == 'EXAMS') ...[
              _buildExamsSection(exams),
              const SizedBox(height: 20),
            ],

            // ── Section 4 : Tâches à finaliser ─────────────────────────
            if (_selectedTab == 0 || _categoryFilter == 'ALL' || _categoryFilter == 'TASKS') ...[
              _buildTasksSection(_tasks),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDatePill(String dateStr) {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
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
    );
  }

  Widget _buildSmartSummary(String summary) {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF16A34A), size: 18),
              const SizedBox(width: 8),
              Text(
                'Résumé Intelligent IA',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summary,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.textColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? AppTheme.tropicalTeal
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: AppTheme.tropicalTeal.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Synthèse complète',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _selectedTab == 0 ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? AppTheme.tropicalTeal
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: AppTheme.tropicalTeal.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Par catégorie',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _selectedTab == 1 ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPills() {
    final categories = [
      {'id': 'ALL', 'label': 'Toutes'},
      {'id': 'CONSULTATIONS', 'label': 'Planning'},
      {'id': 'HOSPITALIZED', 'label': 'Hospitalisés'},
      {'id': 'EXAMS', 'label': 'Examens'},
      {'id': 'TASKS', 'label': 'Tâches'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _categoryFilter == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat['label']!),
              selected: isSelected,
              onSelected: (_) => setState(() => _categoryFilter = cat['id']!),
              selectedColor: AppTheme.tropicalTeal,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textColor(context),
              ),
              backgroundColor: AppTheme.surfaceColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : AppTheme.borderColor(context),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Section 1 : Planning des consultations ────────────────────────────────
  Widget _buildConsultationsSection(List<dynamic> items) {
    final isDark = AppTheme.isDarkMode(context);
    final count = items.length;
    final displayItems = _expandConsultations ? items : items.take(3).toList();

    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF9333EA), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Planning des consultations',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.tropicalTeal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _expandConsultations = !_expandConsultations),
                child: Text(
                  _expandConsultations ? 'Réduire' : 'Voir tout',
                  style: const TextStyle(
                    color: AppTheme.tropicalTeal,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          ...displayItems.map((c) => _buildConsultationRow(c)),

          if (!_expandConsultations && items.length > 3) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _expandConsultations = true),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '+ ${items.length - 3} autres consultations',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.tropicalTeal,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.tropicalTeal, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConsultationRow(dynamic c) {
    final time = c['time'] ?? '09:00';
    final title = c['title'] ?? 'Consultation';
    final room = c['room'] ?? 'Salle 1';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            time,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  room,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 2 : Patients hospitalisés ──────────────────────────────────────
  Widget _buildHospitalizedSection(List<dynamic> items) {
    final isDark = AppTheme.isDarkMode(context);
    final count = items.length;

    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.hotel_rounded, color: Color(0xFF0D9488), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Patients hospitalisés',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Voir tout',
                style: TextStyle(
                  color: AppTheme.tropicalTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          ...items.map((h) => _buildHospitalizedRow(h)),
        ],
      ),
    );
  }

  Widget _buildHospitalizedRow(dynamic h) {
    final room = h['room'] ?? 'Chambre 204';
    final service = h['service'] ?? 'Médecine Interne';
    final status = h['status'] ?? 'Stable';
    final statusColor = h['statusColor'] ?? 'green';

    Color bgColor;
    Color textColor;
    if (status == 'Stable' || statusColor == 'green') {
      bgColor = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF16A34A);
    } else if (status == 'En cours' || statusColor == 'blue') {
      bgColor = const Color(0xFFDBEAFE);
      textColor = const Color(0xFF2563EB);
    } else {
      bgColor = const Color(0xFFFFEDD5);
      textColor = const Color(0xFFEA580C);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.hotel_outlined, size: 18, color: Color(0xFF0D9488)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$room  •  $service',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor(context),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 3 : Examens en attente ─────────────────────────────────────────
  Widget _buildExamsSection(List<dynamic> items) {
    final isDark = AppTheme.isDarkMode(context);
    final count = items.length;

    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.science_rounded, color: Color(0xFFEA580C), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Examens en attente',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Voir tout',
                style: TextStyle(
                  color: AppTheme.tropicalTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          ...items.map((e) => _buildExamRow(e)),
        ],
      ),
    );
  }

  Widget _buildExamRow(dynamic e) {
    final title = e['title'] ?? 'Examen clinique';
    final patName = e['patientName'] ?? 'Patient';
    final dept = e['department'] ?? 'Radiologie';
    final status = e['status'] ?? 'En attente';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title  •  $patName',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(
                      dept,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEA580C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 4 : Tâches à finaliser ─────────────────────────────────────────
  Widget _buildTasksSection(List<dynamic> items) {
    final isDark = AppTheme.isDarkMode(context);
    final count = items.length;

    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tâches à finaliser',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.tropicalTeal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Voir tout',
                style: TextStyle(
                  color: AppTheme.tropicalTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final t = entry.value;
            return _buildTaskRow(t, idx);
          }),
        ],
      ),
    );
  }

  Widget _buildTaskRow(dynamic t, int idx) {
    final title = t['title'] ?? 'Tâche clinique';
    final location = t['location'] ?? 'Chambre 204';
    final time = t['time'] ?? '10:30';
    final isDone = t['isCompleted'] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _tasks[idx]['isCompleted'] = !isDone;
              });
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDone ? AppTheme.tropicalTeal : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDone ? AppTheme.tropicalTeal : const Color(0xFF94A3B8),
                  width: 1.8,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
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
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone
                        ? const Color(0xFF94A3B8)
                        : AppTheme.textColor(context),
                  ),
                ),
                Text(
                  location,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
