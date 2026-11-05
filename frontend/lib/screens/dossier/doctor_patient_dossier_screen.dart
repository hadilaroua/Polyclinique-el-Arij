import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api_service.dart';
import '../../services/patient_pdf_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/theme.dart';
import '../../widgets/patient_timeline_view.dart';
import '../../widgets/smart_patient_monitoring_view.dart';
import '../../widgets/unified_consultation_modal.dart';
import '../../widgets/unified_vital_signs_modal.dart';
import '../../widgets/exam_result_detail_modal.dart';
import '../../widgets/patient_dossier_header.dart';
import '../../widgets/patient_dossier_sections.dart';

class DoctorPatientDossierScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const DoctorPatientDossierScreen({super.key, required this.patient});

  @override
  State<DoctorPatientDossierScreen> createState() => _DoctorPatientDossierScreenState();
}

class _DoctorPatientDossierScreenState extends State<DoctorPatientDossierScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _loading = true;
  List<dynamic> _consultations = [];
  List<dynamic> _exams = [];
  List<dynamic> _vitalSigns = [];
  Map<String, dynamic>? _activeStay;

  final List<String> _tabLabels = [
    'Synthèse & Antécédents',
    'Constantes Vitales',
    'Consultations & Notes',
    'Prescriptions',
    'Imagerie & Labo',
    'Timeline Parcours',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    AppLogger.logInterface(
      'Dossier Patient Médecin',
      fileName: 'doctor_patient_dossier_screen.dart',
      details:
          'Ouverture dossier médecin pour ${widget.patient['firstName']} ${widget.patient['lastName']}',
    );
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
          final fetched = (results[0] as List<dynamic>? ?? []);
          final fetchedIds = fetched.map((c) => (c['_id'] ?? c['id'])?.toString()).toSet();
          final localUnsynced = _consultations.where((c) {
            final id = (c['_id'] ?? c['id'])?.toString();
            return id != null && !fetchedIds.contains(id);
          }).toList();

          _consultations = [...localUnsynced, ...fetched];
          _exams = results[1];
          _vitalSigns = results[2];
          final stays = results[4];
          _activeStay = stays.isNotEmpty ? (stays.first as Map<String, dynamic>) : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _patientDisplayName {
    final pat = widget.patient;
    final rawName = '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim();
    return rawName.isEmpty ? 'Patient' : rawName;
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

  Future<void> _exportPdfRecap() async {
    final pat = widget.patient;
    final patientId = pat['_id']?.toString() ?? '';
    final rawName = '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim();
    final displayName = rawName.isEmpty ? 'Patient' : rawName;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            CircularProgressIndicator(color: AppTheme.primaryColor(context)),
            const SizedBox(height: 18),
            const Text(
              'Génération du Dossier PDF...',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Synthèse IA Gemini & Données Réelles de $displayName',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      String aiSummary = '';
      if (patientId.isNotEmpty) {
        final res = await _api.getPatientSummary(patientId);
        if (res['success'] != false && res['summary'] != null) {
          aiSummary = res['summary'].toString();
        }
      }

      final file = await PatientPdfService().generateAndSavePatientPdf(
        patient: pat,
        aiSummary: aiSummary,
        vitalSigns: _vitalSigns,
        consultations: _consultations,
        exams: _exams,
        activeStay: _activeStay,
        currentUserName: _api.currentUser?['lastName'] ?? 'Dr. Karima',
        currentUserRole: 'Médecin Praticien',
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A00).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFFF7A00),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Dossier PDF Prêt',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: Text(
              'Le document officiel avec la synthèse IA Gemini et les constantes a été enregistré dans vos Fichiers:\n\n${file.path}',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.isDarkMode(context)
                      ? AppTheme.darkPrimary
                      : AppTheme.evergreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text(
                  'Partager / Exporter',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(file.path)], text: 'Dossier Médical PDF - $displayName');
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création du PDF: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final pat = widget.patient;
    final rawName = '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim();
    final prefix = pat['gender'] == 'F' ? 'Mme.' : 'M.';
    final displayName = rawName.isEmpty
        ? 'Patient'
        : (rawName.startsWith('M.') || rawName.startsWith('Mme.') ? rawName : '$prefix $rawName');
    final dossier = pat['dossierNumber']?.toString() ?? '';
    final bloodType = pat['bloodType']?.toString() ?? '';
    final topBarColor = isDark ? AppTheme.darkTopBar : AppTheme.evergreen;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: topBarColor,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
        appBar: AppBar(
          backgroundColor: topBarColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: topBarColor,
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            tooltip: 'Retour',
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Dossier Médical Praticien',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            ValueListenableBuilder<ThemeMode>(
              valueListenable: AppTheme.themeModeNotifier,
              builder: (context, mode, _) {
                final isDarkActive = AppTheme.isDarkMode(context);
                return IconButton(
                  icon: Icon(
                    isDarkActive ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_stars_fill,
                    color: isDarkActive ? const Color(0xFFFFD60A) : Colors.white,
                    size: 20,
                  ),
                  tooltip: 'Changer Thème (Sombre / Clair)',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    AppTheme.toggleTheme();
                  },
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            PatientDossierHeader(
              patient: pat,
              displayName: displayName,
              dossierNumber: dossier.toString(),
              bloodType: bloodType.toString(),
              stayLabel: _activeStay == null ? null : 'Ch. ${_activeStay!['roomNumber'] ?? 'N/A'}',
              tabController: _tabController,
              tabs: _tabLabels,
            ),

            const SizedBox(height: 6),

            // ── Contenu des Onglets ─────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor(context)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildSummaryTab(),
                        _buildVitalsTab(isDark),
                        _buildConsultationsTab(isDark),
                        _buildPrescriptionsTab(),
                        _buildImagingAndLabTab(isDark),
                        PatientTimelineView(
                          patientId: pat['_id']?.toString() ?? '',
                          patientName: displayName,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    return PatientClinicalSummary(
      patient: widget.patient,
      title: 'Antécédents et informations utiles',
      sections: PatientSummarySection.values,
    );
  }

  Widget _buildVitalsTab(bool isDark) {
    if (_vitalSigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border_rounded, size: 40, color: Colors.grey),
            const SizedBox(height: 10),
            const Text(
              'Aucune constante enregistrée pour ce patient.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showAddVitalSignsModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.pastelOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Saisir une première constante',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
    return SmartPatientMonitoringView(
      patientId: widget.patient['_id']?.toString() ?? '',
      patientName: _patientDisplayName,
      onNavigateToTimeline: () => _tabController.animateTo(5),
    );
  }

  Widget _buildConsultationsTab(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _consultations.length + 1,
      itemBuilder: (ctx, idx) {
        if (idx == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Consultations (${_consultations.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.pastelOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text(
                    'Nouvelle Note',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _showAddConsultationModal,
                ),
              ],
            ),
          );
        }
        final c = _consultations[idx - 1];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE5ECE8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate((c['date'] ?? c['createdAt'])?.toString()),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor(context),
                    ),
                  ),
                  if (c['doctorName']?.toString().trim().isNotEmpty == true)
                    Text(
                      c['doctorName'].toString(),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                c['motive'] ?? c['reason'] ?? 'Motif non renseigné',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              if (c['diagnostic'] != null || c['diagnosis'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Diagnostic : ${c['diagnostic'] ?? c['diagnosis']}',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ],
              if (c['treatmentPlan'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Plan : ${c['treatmentPlan']}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5A6E63)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrescriptionsTab() {
    return PatientPrescriptionList(
      consultations: _consultations,
      heading: 'Ordonnances issues des consultations',
      emptyMessage: 'Aucune prescription médicamenteuse enregistrée.',
    );
  }

  Widget _buildImagingAndLabTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Examens de radiologie et laboratoire',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.pastelOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 36),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text(
                'Demander',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: _showAddExamModal,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_exams.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                'Aucun examen de laboratoire ou imagerie',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._exams.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE5ECE8)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () =>
                      ExamResultDetailModal.show(context, exam: e, patient: widget.patient),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e['examType'] ?? 'Examen',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    (e['status'] == 'DONE' || e['status'] == 'COMPLETED'
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFFF7A00))
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                e['status'] == 'DONE' || e['status'] == 'COMPLETED'
                                    ? 'TERMINÉ'
                                    : 'EN COURS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: e['status'] == 'DONE' || e['status'] == 'COMPLETED'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFF7A00),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (e['result'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Résultat validé : ${e['result']}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Voir détails & tous les champs',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.evergreen,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 10,
                              color: AppTheme.evergreen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Modals for Doctor Actions
  void _showAddConsultationModal() {
    UnifiedConsultationModal.show(
      context,
      preselectedPatient: widget.patient,
      preselectedPatientId: (widget.patient['_id'] ?? widget.patient['id'])?.toString(),
      onSuccess: (newConsult) {
        if (mounted) {
          setState(() {
            final id = (newConsult['_id'] ?? newConsult['id'])?.toString();
            _consultations.removeWhere((c) => (c['_id'] ?? c['id'])?.toString() == id);
            _consultations.insert(0, newConsult);
          });
          _loadPatientData();
        }
      },
    );
  }

  void _showAddExamModal() {
    String selectedService = 'Laboratoire / Biologie';
    String examType = 'Bilan sanguin complet';
    String priority = 'MEDIUM';
    final customExamCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final patientName = '${widget.patient['firstName'] ?? ''} ${widget.patient['lastName'] ?? ''}'
        .trim();

    AppTheme.showArijBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: AppTheme.bottomSheetDecoration(context),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTheme.bottomSheetDragHandle(),
                const Row(
                  children: [
                    Icon(Icons.science, color: AppTheme.evergreen, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Prescrire un Examen Complémentaire',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (patientName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Patient : $patientName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.evergreen,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Service / Département
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedService,
                  decoration: const InputDecoration(
                    labelText: 'Service de destination / Plateau Technique *',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Laboratoire / Biologie',
                      child: Text('🧪 Laboratoire / Biologie', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Radiologie / Imagerie',
                      child: Text('🩻 Radiologie / Imagerie', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Cardiologie / ECG',
                      child: Text('🫀 Cardiologie / ECG', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Échographie / Doppler',
                      child: Text('🔊 Échographie / Doppler', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'EFR / Pneumologie',
                      child: Text('🫁 EFR / Pneumologie', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'Autre Examen Spécifique',
                      child: Text('🏥 Autre Examen', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (v) =>
                      setModalState(() => selectedService = v ?? 'Laboratoire / Biologie'),
                ),
                const SizedBox(height: 12),

                // Type d'Examen
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: examType,
                  decoration: const InputDecoration(
                    labelText: "Examen demandé *",
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'Bilan sanguin complet',
                            'NFS + Plaquettes',
                            'Bilan Hépatique & Rénal',
                            'Gaz du sang',
                            'Électrocardiogramme (ECG)',
                            'Scanner thoracique sans injection',
                            'Échographie abdominale',
                            'Radiographie pulmonaire (Face/Profil)',
                            'Bilan Hémostase (TP / INR / TCA)',
                            'ECBU + Antibiogramme',
                            'Autre (Préciser ci-dessous)',
                          ]
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setModalState(() => examType = v ?? 'Bilan sanguin complet'),
                ),

                if (examType.startsWith('Autre')) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customExamCtrl,
                    decoration: const InputDecoration(
                      labelText: "Intitulé précis de l'examen",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                // Priority
                Row(
                  children: [
                    const Text(
                      'Priorité : ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Normale'),
                      selected: priority == 'MEDIUM',
                      onSelected: (_) => setModalState(() => priority = 'MEDIUM'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('🚨 Urgente'),
                      selected: priority == 'URGENT',
                      selectedColor: const Color(0xFFEDF2EA),
                      onSelected: (_) => setModalState(() => priority = 'URGENT'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('⚡ STAT'),
                      selected: priority == 'CRITICAL',
                      selectedColor: const Color(0xFFFDE8E8),
                      onSelected: (_) => setModalState(() => priority = 'CRITICAL'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Renseignements cliniques & Motifs de la demande',
                    hintText: 'ex: Fièvre inexpliquée, douleur fosse iliaque droite, suspicion embolie...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.pastelOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text(
                      "Envoyer la Prescription d'Examen",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                    onPressed: () async {
                      final finalExamType =
                          (examType.startsWith('Autre') && customExamCtrl.text.trim().isNotEmpty)
                          ? customExamCtrl.text.trim()
                          : examType;
                      Navigator.pop(ctx);
                      final res = await _api.createExam(
                        patientId:
                            widget.patient['_id']?.toString() ??
                            widget.patient['id']?.toString() ??
                            '',
                        examType: finalExamType,
                        service: selectedService,
                        priority: priority,
                        requestNotes: notesCtrl.text.trim(),
                      );
                      _loadPatientData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: res['success'] == true
                                ? AppTheme.evergreen
                                : AppTheme.alertRed,
                            content: Text(
                              res['success'] == true
                                  ? '✅ Demande d\'examen ($finalExamType) transmise au plateau technique !'
                                  : '❌ Échec : ${res['error'] ?? 'Données invalides.'}',
                            ),
                          ),
                        );
                      }
                    },
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
    UnifiedVitalSignsModal.show(
      context,
      preselectedPatient: widget.patient,
      preselectedPatientId: (widget.patient['_id'] ?? widget.patient['id'])?.toString(),
      onSuccess: () {
        _loadPatientData();
      },
    );
  }

  void _showAlertModal() {
    final alertCtrl = TextEditingController();

    AppTheme.showArijBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        decoration: AppTheme.bottomSheetDecoration(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTheme.bottomSheetDragHandle(),
            const Text(
              'Déclencher une Alerte Médicale',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.alertRed),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: alertCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description de l'urgence",
                hintText: 'Ex: Chute brutale de tension, détresse respiratoire',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                onPressed: () async {
                  if (alertCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  await _api.createAlert(
                    patientId: widget.patient['_id']?.toString() ?? '',
                    title: 'Alerte Médicale Praticien',
                    description: alertCtrl.text.trim(),
                    level: 'DANGER',
                    category: 'Urgence Médicale',
                  );
                  _loadPatientData();
                },
                child: const Text(
                  'Diffuser l\'Alerte Immédiate',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
