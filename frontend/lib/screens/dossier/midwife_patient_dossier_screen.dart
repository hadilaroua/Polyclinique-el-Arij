import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api_service.dart';
import '../../services/patient_pdf_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/theme.dart';
import '../../widgets/patient_timeline_view.dart';
import '../../widgets/patient_dossier_header.dart';
import '../../widgets/patient_dossier_sections.dart';
import '../../widgets/unified_vital_signs_modal.dart';

class MidwifePatientDossierScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const MidwifePatientDossierScreen({super.key, required this.patient});

  @override
  State<MidwifePatientDossierScreen> createState() => _MidwifePatientDossierScreenState();
}

class _MidwifePatientDossierScreenState extends State<MidwifePatientDossierScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _loading = true;
  List<dynamic> _consultations = [];
  List<dynamic> _exams = [];
  List<dynamic> _vitalSigns = [];
  List<dynamic> _auditLogs = [];
  Map<String, dynamic>? _activeStay;

  final List<String> _tabLabels = [
    'Monitoring Obstétrical',
    'Antécédents & Contexte',
    'Prescriptions & Bilans',
    'Alertes Maternité',
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
      'Dossier Patient Sage-Femme',
      fileName: 'midwife_patient_dossier_screen.dart',
      details:
          'Ouverture dossier maternité pour ${widget.patient['firstName']} ${widget.patient['lastName']}',
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
      if (mounted) setState(() => _loading = false);
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

  Future<void> _exportPdfRecap() async {
    final pat = widget.patient;
    final patientId = pat['_id']?.toString() ?? '';
    final rawName = '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim();
    final displayName = rawName.isEmpty ? 'Patiente' : rawName;

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
              'Génération Dossier Maternité...',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Synthèse Obstétricale & Constantes Mère-Enfant',
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
        currentUserName: _api.currentUser?['lastName'] ?? 'Sage-Femme',
        currentUserRole: 'Sage-Femme / Maïeuticienne',
      );

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Dossier PDF Prêt',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            content: Text(
              'Le dossier de suivi a été enregistré dans vos Fichiers:\n\n${file.path}',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.isDarkMode(context)
                      ? AppTheme.darkPrimary
                      : AppTheme.evergreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Partager', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(file.path)], text: 'Dossier Maternité - $displayName');
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final pat = widget.patient;
    final rawName = '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim();
    final displayName = rawName.isEmpty ? 'Patiente' : 'Mme. $rawName';
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
          title: const Text(
            'Dossier Maternité (Sage-Femme)',
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
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

            // ── Contenu Spécifique Sage-Femme ───────────────────────────────
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor(context)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMidwifeMonitoringTab(isDark),
                        _buildMidwifeDossierTab(isDark, pat),
                        _buildMidwifePrescriptionsTab(isDark),
                        _buildMidwifeAlertsTab(isDark),
                        PatientTimelineView(
                          patientId: pat['_id']?.toString() ?? '',
                          patientName: displayName,
                        ),
                      ],
                    ),
            ),

            // ── Barre Unique Récapitulatif IA (Uniquement sur Tab 0) ────────
            if (_tabController.index == 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE5ECE8),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.isDarkMode(context)
                            ? AppTheme.darkPrimary
                            : AppTheme.evergreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      icon: const Icon(Icons.auto_awesome, color: Color(0xFFFF7A00), size: 18),
                      label: const Text(
                        'Générer Récapitulatif Maternité IA (PDF)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                      onPressed: _exportPdfRecap,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMidwifeMonitoringTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Monitoring Mère & Foetus',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.pastelOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                icon: const Icon(Icons.favorite_rounded, size: 16),
                label: const Text(
                  'Saisir Constantes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                onPressed: _showAddObstetricVitalsModal,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_vitalSigns.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE5ECE8)),
              ),
              child: const Center(
                child: Text(
                  'Aucun relevé obstétrical enregistré.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._vitalSigns.map(
              (v) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE5ECE8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(v['measuredAt']),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'TA : ${v['bloodPressure'] ?? '-'} mmHg • Pouls : ${v['heartRate'] ?? '-'} bpm',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          'SpO2 : ${v['spO2'] ?? '-'}% • Temp : ${v['temperature'] ?? '-'}°C',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF5A6E63)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A00).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.child_care_rounded,
                        color: Color(0xFFFF7A00),
                        size: 20,
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

  Widget _buildMidwifeDossierTab(bool isDark, Map<String, dynamic> patient) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PatientClinicalSummary(
            patient: patient,
            title: 'Contexte de suivi',
            sections: const [
              PatientSummarySection.chronicDiseases,
              PatientSummarySection.emergencyContact,
              PatientSummarySection.careTeamNotes,
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consultations enregistrées',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                if (_consultations.isEmpty)
                  const Text(
                    'Aucune consultation antérieure enregistrée.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey),
                  )
                else
                  ..._consultations.map((consultation) {
                    final reason = consultation['motive']?.toString().trim() ?? '';
                    final diagnosis =
                        (consultation['diagnostic'] ?? consultation['diagnosis'])
                            ?.toString()
                            .trim() ??
                        '';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(
                              (consultation['date'] ?? consultation['createdAt'])?.toString(),
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor(context),
                            ),
                          ),
                          if (reason.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Motif : $reason', style: const TextStyle(fontSize: 12.5)),
                          ],
                          if (diagnosis.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text('Diagnostic : $diagnosis', style: const TextStyle(fontSize: 12.5)),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMidwifePrescriptionsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Bilans & examens prescrits',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
        ),
        const SizedBox(height: 12),
        if (_exams.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucun examen prescrit.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._exams.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE5ECE8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pregnant_woman_rounded, color: Color(0xFFFF7A00), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e['examType'] ?? 'Examen sans intitulé',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          'Service : ${e['service']?.toString().trim().isNotEmpty == true ? e['service'] : 'Non spécifié'} • Statut : ${e['status'] ?? 'Non renseigné'}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMidwifeAlertsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Alertes Obstétricales',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.alertRed,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              icon: const Icon(Icons.warning_amber_rounded, size: 16),
              label: const Text(
                'Alerte Maternité',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              onPressed: _showObstetricAlertModal,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_auditLogs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucune alerte obstétricale récente.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._auditLogs.map(
            (a) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.alertRed.withValues(alpha: 0.3)),
              ),
              child: Text(
                a['details'] ?? a['action'] ?? 'Alerte maternité',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
      ],
    );
  }

  void _showAddObstetricVitalsModal() {
    UnifiedVitalSignsModal.show(
      context,
      preselectedPatient: widget.patient,
      preselectedPatientId: (widget.patient['_id'] ?? widget.patient['id'])?.toString(),
      onSuccess: () {
        _loadPatientData();
      },
    );
  }

  void _showObstetricAlertModal() {
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
              'Alerte Obstétricale Urgente',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.alertRed),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: alertCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description de l'anomalie",
                hintText: 'Ex: Hémorragie, contractions rapprochées, anomalie BDCF',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                onPressed: () async {
                  if (alertCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  await _api.createAlert(
                    patientId: widget.patient['_id']?.toString() ?? '',
                    title: 'Alerte Obstétricale Maternité',
                    description: alertCtrl.text.trim(),
                    level: 'DANGER',
                    category: 'Obstétrique & Maternité',
                  );
                  _loadPatientData();
                },
                child: const Text(
                  'Transmettre l\'Alerte Obstétricale',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
