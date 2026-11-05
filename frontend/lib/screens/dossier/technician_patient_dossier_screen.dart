import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api_service.dart';
import '../../services/patient_pdf_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/theme.dart';
import '../../widgets/patient_dossier_header.dart';
import '../../widgets/patient_dossier_sections.dart';

class TechnicianPatientDossierScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const TechnicianPatientDossierScreen({super.key, required this.patient});

  @override
  State<TechnicianPatientDossierScreen> createState() => _TechnicianPatientDossierScreenState();
}

class _TechnicianPatientDossierScreenState extends State<TechnicianPatientDossierScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _loading = true;
  List<dynamic> _exams = [];
  List<dynamic> _vitalSigns = [];
  List<dynamic> _auditLogs = [];
  Map<String, dynamic>? _activeStay;

  final List<String> _tabLabels = [
    'Examens à traiter',
    'Résultats validés',
    'Informations patient',
    'Alertes critiques',
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
      'Dossier Patient Technicien',
      fileName: 'technician_patient_dossier_screen.dart',
      details:
          'Ouverture dossier technicien pour ${widget.patient['firstName']} ${widget.patient['lastName']}',
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
        _api.getExams(patientId: patientId),
        _api.getVitalSigns(patientId: patientId),
        _api.getAuditLogs(patientId: patientId),
        _api.getStays(patientId: patientId, status: 'ACTIVE'),
      ]);

      if (mounted) {
        setState(() {
          _exams = results[0];
          _vitalSigns = results[1];
          _auditLogs = results[2];
          final stays = results[3];
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
              'Génération Bilan Labo PDF...',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Résultats d\'analyses et examens de $displayName',
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
        consultations: [],
        exams: _exams,
        activeStay: _activeStay,
        currentUserName: _api.currentUser?['lastName'] ?? 'Technicien Labo',
        currentUserRole: 'Technicien de Laboratoire & Imagerie',
      );

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Bilan PDF Généré',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            content: Text(
              'Le bilan d\'examens a été enregistré dans vos Fichiers:\n\n${file.path}',
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
                  Share.shareXFiles([XFile(file.path)], text: 'Bilan Biologique - $displayName');
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
            'Plateau Technique & Labo',
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

            // ── Contenu Spécifique Technicien ───────────────────────────────
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor(context)))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTechnicianPendingExamsTab(isDark),
                        _buildTechnicianValidatedResultsTab(isDark),
                        _buildTechnicianPatientFileTab(pat),
                        _buildTechnicianCriticalAlertsTab(isDark),
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
                        'Générer Bilan Technique IA (PDF)',
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

  Widget _buildTechnicianPendingExamsTab(bool isDark) {
    final pending = _exams.where((exam) {
      final status = exam['status']?.toString().toUpperCase();
      return status == 'PENDING' || status == 'IN_PROGRESS';
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Demandes d\'Examens (${pending.length})',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                label: const Text(
                  'Saisir Résultat',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                onPressed: _showAddExamResultModal,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE5ECE8)),
              ),
              child: const Center(
                child: Text(
                  'Aucun examen en attente de validation pour ce patient.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...pending.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFF7A00).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e['examType'] ?? 'Examen',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Service : ${e['service'] ?? 'Laboratoire'} • Reçu le ${_formatDate(e['createdAt'])}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.pastelOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      onPressed: _showAddExamResultModal,
                      child: const Text(
                        'Valider',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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

  Widget _buildTechnicianValidatedResultsTab(bool isDark) {
    final done = _exams.where((exam) {
      final status = exam['status']?.toString().toUpperCase();
      return status == 'DONE' || status == 'COMPLETED';
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Analyses & Clichés Validés (${done.length})',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 12),
        if (done.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Text('Aucun examen validé.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...done.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
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
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'VALIDÉ',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Résultat : ${e['result']?.toString().trim().isNotEmpty == true ? e['result'] : 'Non renseigné'}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTechnicianPatientFileTab(Map<String, dynamic> patient) {
    return PatientClinicalSummary(
      patient: patient,
      title: 'Informations utiles au laboratoire',
      sections: const [PatientSummarySection.chronicDiseases, PatientSummarySection.careTeamNotes],
    );
  }

  Widget _buildTechnicianCriticalAlertsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Alertes Valeurs Critiques',
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
                'Signaler Valeur Critique',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              onPressed: _showCriticalValueAlertModal,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_auditLogs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucune alerte de laboratoire.', style: TextStyle(color: Colors.grey)),
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
                a['details'] ?? a['action'] ?? 'Alerte Labo',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ),
      ],
    );
  }

  void _showAddExamResultModal() {
    final resultCtrl = TextEditingController();
    String? selectedFileName;

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
                const Text(
                  'Saisie de Résultat & Cliché',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: resultCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Résultat / Compte-rendu d'analyse",
                    hintText: 'Ex: Glycémie à jeun: 1.05 g/L, NFS normale',
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '📷 Cliché / Photo du Résultat / Pièce jointe',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.primaryColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                if (selectedFileName == null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(color: AppTheme.primaryColor(context), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          icon: Icon(
                            Icons.photo_camera_rounded,
                            color: AppTheme.primaryColor(context),
                            size: 18,
                          ),
                          label: Text(
                            '📷 Joindre Photo',
                            style: TextStyle(
                              color: AppTheme.primaryColor(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () async {
                            try {
                              final file = await FilePicker.pickFile(
                                type: FileType.custom,
                                allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                              );
                              if (file != null) {
                                setModalState(() => selectedFileName = file.name);
                              }
                            } catch (_) {}
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(color: AppTheme.primaryColor(context), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          icon: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppTheme.primaryColor(context),
                            size: 18,
                          ),
                          label: Text(
                            '📄 Joindre PDF',
                            style: TextStyle(
                              color: AppTheme.primaryColor(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () async {
                            try {
                              final file = await FilePicker.pickFile(
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'doc', 'docx'],
                              );
                              if (file != null) {
                                setModalState(() => selectedFileName = file.name);
                              }
                            } catch (_) {}
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.isDarkMode(context)
                          ? AppTheme.darkElevated
                          : AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedFileName!.toLowerCase().endsWith('.pdf')
                              ? Icons.picture_as_pdf_rounded
                              : Icons.image_rounded,
                          color: AppTheme.primaryColor(context),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedFileName!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                          onPressed: () => setModalState(() => selectedFileName = null),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.pastelOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    onPressed: () async {
                      if (resultCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      final fullNotes = selectedFileName != null
                          ? '${resultCtrl.text.trim()} [📄 Photo/Cliché joint: $selectedFileName]'
                          : resultCtrl.text.trim();
                      await _api.createExam(
                        patientId:
                            widget.patient['_id']?.toString() ??
                            widget.patient['id']?.toString() ??
                            '',
                        examType: 'Bilan Biologique / Radio Validé',
                        service: 'Laboratoire / Biologie',
                        requestNotes: fullNotes,
                      );
                      _loadPatientData();
                    },
                    child: const Text(
                      'Valider et Transmettre le Résultat',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCriticalValueAlertModal() {
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
              'Alerte Valeur Critique (Laboratoire)',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.alertRed),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: alertCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Détails de la valeur critique",
                hintText: 'Ex: Troponine ultra-sensible très élevée > 500 ng/L',
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
                    title: 'Alerte Valeur Critique Laboratoire',
                    description: alertCtrl.text.trim(),
                    level: 'DANGER',
                    category: 'Valeur Critique',
                  );
                  _loadPatientData();
                },
                child: const Text(
                  'Alerter le Médecin Immédiatement',
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
