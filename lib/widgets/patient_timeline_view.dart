import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class PatientTimelineView extends StatefulWidget {
  final String patientId;
  final String patientName;
  final VoidCallback? onNavigateToMonitoring;

  const PatientTimelineView({
    super.key,
    required this.patientId,
    required this.patientName,
    this.onNavigateToMonitoring,
  });

  @override
  State<PatientTimelineView> createState() => _PatientTimelineViewState();
}

class _PatientTimelineViewState extends State<PatientTimelineView> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String _selectedFilter = 'ALL';
  String _selectedPeriod = 'ALL';
  List<dynamic> _events = [];
  int _totalEvents = 0;

  // Filtres par type
  final List<Map<String, dynamic>> _filterOptions = [
    {'id': 'ALL', 'label': 'Tout', 'icon': CupertinoIcons.square_grid_2x2},
    {'id': 'EVENTS', 'label': 'Interventions', 'icon': CupertinoIcons.calendar},
    {'id': 'CONSULTATIONS', 'label': 'Consultations', 'icon': CupertinoIcons.person_crop_circle_badge_checkmark},
    {'id': 'EXAMS', 'label': 'Examens', 'icon': CupertinoIcons.lab_flask},
    {'id': 'PRESCRIPTIONS', 'label': 'Prescriptions', 'icon': CupertinoIcons.bandage},
    {'id': 'RESULTS', 'label': 'Résultats', 'icon': CupertinoIcons.doc_text},
    {'id': 'OBSERVATIONS', 'label': 'Observations', 'icon': CupertinoIcons.doc_plaintext},
    {'id': 'VITALS', 'label': 'Constantes', 'icon': CupertinoIcons.waveform_path_ecg},
  ];

  // Filtres par période
  final List<Map<String, String>> _periodOptions = [
    {'id': 'ALL', 'label': 'Tout l\'historique'},
    {'id': 'TODAY', 'label': 'Aujourd\'hui'},
    {'id': '7D', 'label': '7 jours'},
    {'id': '30D', 'label': '30 jours'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getPatientTimeline(
        widget.patientId,
        filter: _selectedFilter,
        period: _selectedPeriod,
      );

      final clinicalList = await _api.getClinicalEvents(patientId: widget.patientId);
      final mappedClinicalEvents = clinicalList.map((ce) {
        return {
          'id': ce['_id'] ?? ce['id'] ?? 'ce_${DateTime.now().millisecondsSinceEpoch}',
          'type': 'CLINICAL_EVENT',
          'category': 'EVENTS',
          'title': '${ce['procedureTitle'] ?? ce['procedureType'] ?? 'Intervention'} — ${ce['roomName'] ?? 'Bloc'}',
          'date': ce['date'] ?? DateTime.now().toIso8601String(),
          'time': '${ce['startTime'] ?? '09:00'} - ${ce['endTime'] ?? '10:30'}',
          'author': ce['doctorName'] ?? 'Médecin Traitant',
          'doctor': ce['doctorName'] ?? 'Médecin Traitant',
          'location': ce['roomName'] ?? 'Bloc opératoire',
          'status': ce['status'] ?? 'SCHEDULED',
          'notes': ce['notes'] ?? '',
          'raw': ce,
        };
      }).toList();

      if (mounted) {
        setState(() {
          final timelineEvents = (res['events'] as List<dynamic>?) ?? [];
          final combined = [...mappedClinicalEvents, ...timelineEvents];
          if (_selectedFilter == 'EVENTS') {
            _events = mappedClinicalEvents;
          } else if (_selectedFilter != 'ALL') {
            _events = timelineEvents;
          } else {
            _events = combined;
          }
          _totalEvents = _events.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onFilterChanged(String filterId) {
    if (_selectedFilter == filterId) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedFilter = filterId);
    _loadTimeline();
  }

  void _onPeriodChanged(String periodId) {
    if (_selectedPeriod == periodId) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedPeriod = periodId);
    _loadTimeline();
  }

  // --- Dialogue / Modal Résumé IA ---
  Future<void> _openAiSummaryModal() async {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AiTimelineSummarySheet(
        patientId: widget.patientId,
        patientName: widget.patientName,
        currentPeriod: _selectedPeriod,
        eventsCount: _events.length,
      ),
    );
  }

  // --- Modal Détail d'un événement ---
  void _openEventDetail(Map<String, dynamic> event) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TimelineEventDetailSheet(
        event: event,
        onNavigateToMonitoring: widget.onNavigateToMonitoring != null
            ? () {
                Navigator.pop(ctx);
                widget.onNavigateToMonitoring!();
              }
            : null,
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Column(
      children: [
        // ── Barre Supérieure Unifiée & Allégée ──────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            border: Border(
              bottom: BorderSide(color: AppTheme.borderColor(context), width: 0.8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Titre + Nombre + Bouton Synthèse IA
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.evergreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.waveform_path_badge_plus, size: 17, color: AppTheme.evergreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Parcours Chronologique',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '$_totalEvents événement${_totalEvents > 1 ? 's' : ''} ordonnés',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.subtextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Ligne 2 : Filtres combinés (Périodes + Catégories) en une seule rangée fluide
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    // Segment Périodes
                    ..._periodOptions.map((period) {
                      final isSelected = _selectedPeriod == period['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => _onPeriodChanged(period['id']!),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.darkTeal
                                  : (isDark ? AppTheme.darkSurface : AppTheme.background),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.darkTeal
                                    : (isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
                                width: isSelected ? 1.2 : 0.8,
                              ),
                            ),
                            child: Text(
                              period['label']!,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : AppTheme.subtextColor(context),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Séparateur vertical discret
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      height: 18,
                      width: 1.2,
                      color: AppTheme.borderColor(context),
                    ),

                    // Catégories d'événements
                    ..._filterOptions.map((f) {
                      final isSelected = _selectedFilter == f['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => _onFilterChanged(f['id'] as String),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.evergreen
                                  : (isDark ? AppTheme.darkSurface : AppTheme.background),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.evergreen
                                    : (isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
                                width: isSelected ? 1.2 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  f['icon'] as IconData,
                                  size: 12,
                                  color: isSelected ? AppTheme.evergreen : AppTheme.subtextColor(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  f['label'] as String,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : AppTheme.textColor(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Timeline List Ordonnée & Épurée ──────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CupertinoActivityIndicator(radius: 14))
              : _events.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadTimeline,
                      color: AppTheme.evergreen,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index] as Map<String, dynamic>;
                          final isFirst = index == 0;
                          final isLast = index == _events.length - 1;
                          final currentDate = event['dateFormatted']?.toString() ?? '';
                          final prevDate = index > 0
                              ? (_events[index - 1] as Map<String, dynamic>)['dateFormatted']?.toString() ?? ''
                              : '';
                          final showDateHeader = index == 0 || (currentDate.isNotEmpty && currentDate != prevDate);

                          return _TimelineItemTile(
                            event: event,
                            isFirst: isFirst,
                            isLast: isLast,
                            showDateHeader: showDateHeader,
                            dateHeaderLabel: currentDate,
                            onTap: () => _openEventDetail(event),
                            onVitalTap: widget.onNavigateToMonitoring,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.evergreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.clock_fill, size: 36, color: AppTheme.evergreen),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun événement sur cette sélection',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Modifiez le filtre d\'événement ou la période pour voir plus d\'activités.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.subtextColor(context),
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.evergreen,
              borderRadius: BorderRadius.circular(16),
              onPressed: () {
                setState(() {
                  _selectedFilter = 'ALL';
                  _selectedPeriod = 'ALL';
                });
                _loadTimeline();
              },
              child: const Text('Réinitialiser les filtres', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ── ITEM TILE DE LA TIMELINE VERTICALE ÉPURÉE ─────────────────────────────────
// =============================================================================

class _TimelineItemTile extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isFirst;
  final bool isLast;
  final bool showDateHeader;
  final String? dateHeaderLabel;
  final VoidCallback onTap;
  final VoidCallback? onVitalTap;

  const _TimelineItemTile({
    required this.event,
    required this.isFirst,
    required this.isLast,
    this.showDateHeader = false,
    this.dateHeaderLabel,
    required this.onTap,
    this.onVitalTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final type = event['type']?.toString() ?? 'OTHER';
    final meta = _getEventMeta(type);

    final timeStr = event['timeFormatted'] ?? '';
    final title = event['title'] ?? 'Événement';
    final summary = event['summary'] ?? '';
    final author = event['author'] ?? 'Équipe médicale';
    final service = event['service'] ?? '';
    final isVital = type == 'VITALS';

    final tileWidget = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Colonne Heure épurée
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: Text(
                timeStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.dustGrey : AppTheme.darkElevated,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),

          // 2. Colonne Ligne Verticale + Nœud Icône
          SizedBox(
            width: 32,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 2,
                      margin: EdgeInsets.only(
                        top: isFirst ? 14 : 0,
                        bottom: isLast ? 24 : 0,
                      ),
                      color: isDark ? AppTheme.darkElevated : AppTheme.borderColor(context),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: meta.color, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: meta.color.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(meta.icon, size: 13, color: meta.color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 3. Carte Événement Stitch Pro
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: meta.color.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête de la carte : Catégorie Badge & Flèche
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: meta.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              meta.label,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: meta.color,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (service.isNotEmpty)
                            Text(
                              service,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.subtextColor(context),
                              ),
                            ),
                          const SizedBox(width: 4),
                          Icon(CupertinoIcons.chevron_right, size: 12, color: AppTheme.subtextColor(context)),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Titre
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                          letterSpacing: -0.2,
                        ),
                      ),

                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          summary,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: isDark ? AppTheme.dustGrey : AppTheme.darkElevated,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],

                      const SizedBox(height: 6),

                      // Bas de carte : Auteur + Action rapide si Constante
                      Row(
                        children: [
                          Icon(CupertinoIcons.person_crop_circle, size: 12, color: AppTheme.subtextColor(context)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.subtextColor(context),
                              ),
                            ),
                          ),
                          if (isVital && onVitalTap != null)
                            InkWell(
                              onTap: onVitalTap,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.evergreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.waveform_path_ecg, size: 11, color: AppTheme.evergreen),
                                    SizedBox(width: 3),
                                    Text(
                                      'Surveillance →',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.evergreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (showDateHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 12, bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.softLinen,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.calendar, size: 12, color: AppTheme.darkTeal),
                  const SizedBox(width: 5),
                  Text(
                    dateHeaderLabel ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.darkTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),
          tileWidget,
        ],
      );
    }

    return tileWidget;
  }

  _EventMeta _getEventMeta(String type) {
    switch (type.toUpperCase()) {
      case 'ADMISSION':
        return _EventMeta(
          label: 'Admission',
          color: AppTheme.evergreen,
          icon: CupertinoIcons.building_2_fill,
        );
      case 'CONSULTATION':
        return _EventMeta(
          label: 'Consultation',
          color: AppTheme.darkTeal,
          icon: CupertinoIcons.person_crop_circle_badge_checkmark,
        );
      case 'PRESCRIPTION':
        return _EventMeta(
          label: 'Prescription',
          color: AppTheme.darkTeal,
          icon: CupertinoIcons.bandage_fill,
        );
      case 'EXAM_REQUEST':
        return _EventMeta(
          label: 'Demande Examen',
          color: const Color(0xFFFF7A00),
          icon: CupertinoIcons.lab_flask_solid,
        );
      case 'EXAM_RESULT':
        return _EventMeta(
          label: 'Résultat Validé',
          color: AppTheme.evergreen,
          icon: CupertinoIcons.doc_checkmark_fill,
        );
      case 'VITALS':
        return _EventMeta(
          label: 'Constantes Vitales',
          color: AppTheme.darkTeal,
          icon: CupertinoIcons.heart_fill,
        );
      case 'ALERT':
        return _EventMeta(
          label: 'Alerte Clinique',
          color: AppTheme.cayenneRed,
          icon: CupertinoIcons.exclamationmark_triangle_fill,
        );
      case 'OBSERVATION':
      default:
        return _EventMeta(
          label: 'Observation',
          color: const Color(0xFF6B7E72),
          icon: CupertinoIcons.doc_plaintext,
        );
    }
  }
}

class _EventMeta {
  final String label;
  final Color color;
  final IconData icon;

  _EventMeta({required this.label, required this.color, required this.icon});
}

// =============================================================================
// ── MODAL DÉTAIL D'UN ÉVÉNEMENT (iOS Style) ──────────────────────────────────
// =============================================================================

class _TimelineEventDetailSheet extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onNavigateToMonitoring;

  const _TimelineEventDetailSheet({
    required this.event,
    this.onNavigateToMonitoring,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final title = event['title'] ?? 'Détail de l\'événement';
    final details = event['details'] ?? 'Aucun détail supplémentaire.';
    final author = event['author'] ?? 'Équipe médicale';
    final authorRole = event['authorRole'] ?? '';
    final service = event['service'] ?? 'Polyclinique El Arij';
    final dateStr = event['dateFormatted'] ?? '';
    final timeStr = event['timeFormatted'] ?? '';
    final isVital = event['type'] == 'VITALS';
    final docs = (event['documents'] as List<dynamic>?) ?? [];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewPadding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée iOS
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppTheme.dustGrey,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // En-tête
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateStr à $timeStr • $service',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.evergreen,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 24, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Intervenant
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBackground : AppTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.evergreen.withValues(alpha: 0.15),
                  child: const Icon(CupertinoIcons.person_fill, size: 18, color: AppTheme.evergreen),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      Text(
                        authorRole.isNotEmpty ? authorRole : 'Professionnel de santé',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.subtextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contenu détaillé
          Text(
            'Contenu & Données cliniques',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBackground : AppTheme.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              details,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppTheme.textColor(context),
              ),
            ),
          ),

          // Documents / Pièces jointes
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Documents associés',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 6),
            ...docs.map((doc) {
              final docName = (doc is Map ? doc['name'] : doc.toString()) ?? 'Document';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.doc_text_fill, size: 16, color: AppTheme.evergreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        docName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                    ),
                    const Icon(CupertinoIcons.arrow_down_circle, size: 16, color: AppTheme.evergreen),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 20),

          // Action vers surveillance si applicable
          if (isVital && onNavigateToMonitoring != null)
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: AppTheme.evergreen,
                borderRadius: BorderRadius.circular(14),
                onPressed: onNavigateToMonitoring,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.waveform_path_ecg, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Ouvrir dans Smart Patient Monitoring',
                      style: TextStyle(
                        color: Colors.white,
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
    );
  }
}

// =============================================================================
// ── MODAL RÉSUMÉ IA DE LA PÉRIODE (✨ IA Assistant) ──────────────────────────
// =============================================================================

class _AiTimelineSummarySheet extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String currentPeriod;
  final int eventsCount;

  const _AiTimelineSummarySheet({
    required this.patientId,
    required this.patientName,
    required this.currentPeriod,
    required this.eventsCount,
  });

  @override
  State<_AiTimelineSummarySheet> createState() => _AiTimelineSummarySheetState();
}

class _AiTimelineSummarySheetState extends State<_AiTimelineSummarySheet> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String _summary = '';
  List<String> _eventsUsed = [];
  bool _showSources = false;

  @override
  void initState() {
    super.initState();
    _generateSummary();
  }

  Future<void> _generateSummary() async {
    setState(() => _loading = true);
    try {
      final res = await _api.summarizePatientTimeline(
        widget.patientId,
        period: widget.currentPeriod,
      );
      if (mounted) {
        setState(() {
          _summary = res['summary'] ?? 'Aucun résumé disponible.';
          _eventsUsed = (res['eventsUsed'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summary = 'Une erreur est survenue lors de la synthèse intelligente.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewPadding.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée iOS
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: AppTheme.dustGrey,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Titre avec dégradé IA
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.evergreen, AppTheme.evergreen],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Résumé Intelligent de la Période',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Synthèse factuelle du parcours de ${widget.patientName}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.subtextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 24, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Corps du résumé
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CupertinoActivityIndicator(radius: 16),
                        const SizedBox(height: 16),
                        Text(
                          'Analyse des événements chronologiques...',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Extraction stricte et factuelle sans extrapolation',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.subtextColor(context),
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Zone du texte résumé
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkBackground : AppTheme.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.evergreen.withValues(alpha: 0.25),
                            ),
                          ),
                          child: SelectableText(
                            _summary,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Avertissement réglementaire & factuel
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.evergreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.evergreen.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.info_circle_fill, size: 16, color: AppTheme.evergreen),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '« Résumé généré à partir des événements sélectionnés » — Non diagnostique.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textColor(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Section Événements sources vérifiables
                        if (_eventsUsed.isNotEmpty) ...[
                          InkWell(
                            onTap: () => setState(() => _showSources = !_showSources),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    _showSources ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                                    size: 14,
                                    color: AppTheme.evergreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Vérifier les événements sources (${_eventsUsed.length})',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.evergreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showSources)
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : AppTheme.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _eventsUsed.map((evt) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      const Icon(CupertinoIcons.check_mark_circled_solid, size: 12, color: AppTheme.evergreen),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          evt,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: AppTheme.textColor(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
          ),

          // Bouton Copier / Fermer
          if (!_loading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: isDark ? AppTheme.darkSurface : AppTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _summary));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Résumé copié dans le presse-papier'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.doc_on_clipboard, size: 16, color: AppTheme.textColor(context)),
                        const SizedBox(width: 6),
                        Text(
                          'Copier le résumé',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: AppTheme.evergreen,
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Terminé',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
