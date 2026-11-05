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

class NursePatientDossierScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const NursePatientDossierScreen({super.key, required this.patient});

  @override
  State<NursePatientDossierScreen> createState() => _NursePatientDossierScreenState();
}

class _NursePatientDossierScreenState extends State<NursePatientDossierScreen>
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
    'Surveillance & Constantes',
    'Prescriptions & Soins',
    'Synthèse Patient',
    'Alertes Soignantes',
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
      'Dossier Patient Infirmier',
      fileName: 'nurse_patient_dossier_screen.dart',
      details:
          'Ouverture dossier infirmier pour ${widget.patient['firstName']} ${widget.patient['lastName']}',
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
              'Synthèse IA & Relevés de Soins pour $displayName',
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
        currentUserName: _api.currentUser?['lastName'] ?? 'Infirmier Soignant',
        currentUserRole: 'Infirmier Diplômé d\'État',
      );

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Dossier PDF Généré',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            content: Text('Le dossier complet a été enregistré dans vos Fichiers:\n\n${file.path}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.isDarkMode(context)
                      ? AppTheme.darkPrimary
                      : AppTheme.evergreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('Partager'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles([XFile(file.path)], text: 'Dossier Soignant - $displayName');
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
          title: const Text(
            'Dossier Soignant (Infirmier)',
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
              stayLabel: _activeStay == null ? null : 'Lit ${_activeStay!['roomNumber'] ?? 'N/A'}',
              tabController: _tabController,
              tabs: _tabLabels,
            ),

            const SizedBox(height: 6),

            // ── Contenu Spécifique Infirmier ────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor(context)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildNurseVitalsSurveillanceTab(isDark),
                        _buildNursePrescriptionsCareTab(),
                        _buildNurseSummaryTab(isDark, pat),
                        _buildNurseAlertsTab(isDark),
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
                      icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                      label: const Text(
                        'Générer Récapitulatif Soins IA (PDF)',
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

  Widget _buildNurseVitalsSurveillanceTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Surveillance des Constantes Vitales',
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
                  'Saisir Constante',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                onPressed: _showAddVitalSignsModal,
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
                  'Aucun relevé enregistré. Cliquez sur "Saisir Constante" ci-dessus.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._vitalSigns.map((v) {
              final dateStr = _formatDate(v['recordedAt'] ?? v['createdAt'] ?? v['measuredAt']);
              final sys = v['bloodPressureSystolic'];
              final dia = v['bloodPressureDiastolic'];
              final bp = (sys != null && dia != null)
                  ? '$sys/$dia mmHg'
                  : (v['bloodPressure'] ?? '-');
              final hr = v['heartRate'];
              final temp = v['temperature'];
              final spo2 = v['oxygenSaturation'] ?? v['spO2'];
              final resp = v['respiratoryRate'];
              final gly = v['bloodGlucose'];
              final weight = v['weight'];
              final pain = v['painScale'];
              final notes = v['notes'] ?? '';
              final recorder = v['recordedByUserId'];
              final nurseName = recorder is Map
                  ? '${recorder['role'] == 'NURSE' ? 'Inf. ' : ''}${recorder['firstName'] ?? ''} ${recorder['lastName'] ?? ''}'
                        .trim()
                  : 'Inf. Sonia Ben Amor';
              final isAbnormal =
                  (hr != null && (hr < 60 || hr > 100)) ||
                  (sys != null && sys >= 140) ||
                  (dia != null && dia >= 90) ||
                  (temp != null && temp >= 38.0) ||
                  (spo2 != null && spo2 < 95);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAbnormal
                        ? AppTheme.alertRed.withValues(alpha: 0.35)
                        : (isDark ? AppTheme.darkBorder : const Color(0xFFE5ECE8)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isAbnormal
                                    ? AppTheme.alertRed.withValues(alpha: 0.1)
                                    : AppTheme.successColor(context).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  isAbnormal ? Icons.warning_rounded : Icons.monitor_heart_rounded,
                                  color: isAbnormal
                                      ? AppTheme.alertRed
                                      : AppTheme.successColor(context),
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryColor(context),
                                  ),
                                ),
                                Text(
                                  nurseName,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7F74)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isAbnormal
                                ? AppTheme.alertRed.withValues(alpha: 0.1)
                                : AppTheme.successColor(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            isAbnormal ? 'Alerte Clinique' : 'Constantes Normales',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isAbnormal
                                  ? AppTheme.alertRed
                                  : AppTheme.successColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildVitalsChip('🩺 Tension', bp, isDark),
                        if (hr != null) _buildVitalsChip('❤️ Pouls', '$hr bpm', isDark),
                        if (temp != null)
                          _buildVitalsChip(
                            '🌡️ T°',
                            '${temp is num ? temp.toStringAsFixed(1) : temp}°C',
                            isDark,
                          ),
                        if (spo2 != null) _buildVitalsChip('🫁 SpO₂', '$spo2%', isDark),
                        if (resp != null) _buildVitalsChip('💨 FR', '$resp c/min', isDark),
                        if (gly != null) _buildVitalsChip('🩸 Glycémie', '$gly g/L', isDark),
                        if (weight != null) _buildVitalsChip('⚖️ Poids', '$weight kg', isDark),
                        if (pain != null) _buildVitalsChip('🧠 Douleur', 'EVA $pain/10', isDark),
                      ],
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkElevated : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          '📝 Notes : $notes',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildVitalsChip(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNursePrescriptionsCareTab() {
    return PatientPrescriptionList(
      consultations: _consultations,
      heading: 'Prescriptions médicales',
      emptyMessage: 'Aucune prescription enregistrée dans les consultations.',
    );
  }

  Widget _buildNurseSummaryTab(bool isDark, Map<String, dynamic> patient) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PatientClinicalSummary(
            patient: patient,
            title: 'Informations utiles aux soins',
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
                  'Consultations récentes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                if (_consultations.isEmpty)
                  const Text(
                    'Aucune consultation médicale enregistrée.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey),
                  )
                else
                  ..._consultations.take(3).map((consultation) {
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

  Widget _buildNurseAlertsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Alertes & Transmissions',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              icon: const Icon(Icons.warning_amber_rounded, size: 16),
              label: const Text(
                'Déclencher Alerte',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              onPressed: _showAlertModal,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_auditLogs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucune alerte récente.', style: TextStyle(color: Colors.grey)),
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
                a['details'] ?? a['action'] ?? 'Alerte soignante',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
      ],
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
              'Alerter le Médecin de Garde',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.alertRed),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: alertCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description de l'anomalie",
                hintText: 'Ex: Chute tensionnelle, douleur aiguë',
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
                    title: 'Alerte Soignante Infirmier',
                    description: alertCtrl.text.trim(),
                    level: 'WARNING',
                    category: 'Surveillance & Soins',
                  );
                  _loadPatientData();
                },
                child: const Text(
                  'Transmettre l\'Alerte',
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
