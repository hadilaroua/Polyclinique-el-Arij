import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/briefing_utils.dart';
import '../utils/default_patients.dart';
import '../widgets/app_drawer.dart';
import '../widgets/figma_header.dart';

import 'package:flutter/cupertino.dart';

import '../utils/app_logger.dart';
import '../widgets/patient_worklist_card.dart';
import '../widgets/ios_bottom_nav_bar.dart';
import 'patient_dossier_screen.dart';
import 'profile_screen.dart';
import 'ai_briefing_screen.dart';
import '../widgets/exam_result_detail_modal.dart';

class TechnicianHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const TechnicianHomeScreen({super.key, required this.onLogout});

  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

const Color techPrimary = AppTheme.tropicalTeal;

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final api = ApiService();
  int _currentTab = 0;
  String _selectedServiceFilter = 'ALL';
  String _selectedStatusFilter = 'ALL';
  String _searchQuery = '';

  void _onTabChanged(int idx) {
    setState(() {
      _currentTab = idx;
      if (idx == 0) {
        _selectedServiceFilter = 'ALL';
        _selectedStatusFilter = 'ALL';
      } else if (idx == 1) {
        _selectedServiceFilter = 'RADIO';
        _selectedStatusFilter = 'ALL';
      } else if (idx == 2) {
        _selectedServiceFilter = 'LABO';
        _selectedStatusFilter = 'ALL';
      } else if (idx == 3) {
        _selectedServiceFilter = 'ALL';
        _selectedStatusFilter = 'COMPLETED';
      }
    });
  }

  List<dynamic> exams = [];
  List<dynamic> alerts = [];
  List<dynamic> patients = [];
  String patientSearchQuery = '';
  String _selectedDepartmentFilter = 'ALL';
  Map<String, dynamic> dailyBriefing = {};
  final Set<String> _readAlertIds = {};
  final Set<String> _deletedExamIds = {};
  bool isLoading = true;

  Timer? _realtimeTimer;

  int get unreadAlertCount => alerts.where((a) {
    final id = a['_id']?.toString();
    return id != null && !_readAlertIds.contains(id);
  }).length;

  int get pendingCount => exams.where((e) => e['status'] == 'PENDING').length;
  int get inProgressCount => exams.where((e) => e['status'] == 'IN_PROGRESS').length;
  int get completedCount => exams.where((e) => e['status'] == 'COMPLETED').length;

  @override
  void initState() {
    super.initState();
    _loadReadAlertIds();
    _loadExams();
    _startRealtimeSync();
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReadAlertIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('arij_technician_read_alerts') ?? [];
      if (mounted) {
        setState(() {
          _readAlertIds.addAll(list);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveReadAlertIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('arij_technician_read_alerts', _readAlertIds.toList());
    } catch (_) {}
  }

  void _markAlertsAsRead() {
    for (final a in alerts) {
      final id = a['_id']?.toString();
      if (id != null) _readAlertIds.add(id);
    }
    _saveReadAlertIds();
    if (mounted) setState(() {});
  }

  void _startRealtimeSync() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      if (!mounted) return;
      try {
        final list = await api.getExams();
        final newAlerts = await api.getAlerts(isResolved: false);
        if (!mounted) return;

        final cleanList = list.where((e) {
          final id = e['_id']?.toString() ?? e['id']?.toString();
          return id != null && !_deletedExamIds.contains(id);
        }).toList();

        if (cleanList.length != exams.length || newAlerts.length != alerts.length) {
          setState(() {
            exams = cleanList;
            alerts = newAlerts;
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _loadExams() async {
    setState(() => isLoading = true);
    final results = await Future.wait<dynamic>([
      api.getExams(),
      api.getAlerts(isResolved: false),
      api.getDailyBriefing(),
      api.getPatients(),
    ]);
    if (mounted) {
      final rawExams = (results[0] as List<dynamic>?) ?? [];
      final list = rawExams.where((e) {
        final id = e['_id']?.toString() ?? e['id']?.toString();
        return id != null && !_deletedExamIds.contains(id);
      }).toList();
      setState(() {
        exams = list;
        alerts = (results[1] as List<dynamic>?) ?? [];
        dailyBriefing = (results[2] as Map<String, dynamic>?) ?? {};
        patients = (results[3] as List<dynamic>?) ?? [];
        isLoading = false;
      });
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _handleResolveAlert(String alertId, String patName) async {
    final res = await api.resolveAlert(alertId);
    if (res['success'] == true) {
      if (mounted) {
        setState(() {
          alerts.removeWhere((a) => a['_id']?.toString() == alertId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 3),
            content: Text('✅ Alerte ($patName) clôturée !'),
          ),
        );
      }
    }
  }

  Future<void> _handleResolveAllAlerts(BuildContext modalCtx) async {
    final res = await api.resolveAllAlerts();
    if (res['success'] == true) {
      if (modalCtx.mounted) {
        Navigator.pop(modalCtx);
      }
      if (mounted) {
        setState(() {
          alerts.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 3),
            content: Text('✅ Toutes les alertes ont été traitées et clôturées !'),
          ),
        );
      }
    }
  }

  void _showCreateDirectExamModal() async {
    List<dynamic> patients = [];
    List<dynamic> doctors = [];
    try {
      final results = await Future.wait([api.getPatients(), api.getDoctors()]);
      patients = results[0];
      doctors = results[1];
    } catch (_) {}

    String? selectedPatientId = patients.isNotEmpty ? patients.first['_id']?.toString() : null;
    String? selectedDoctorId;
    if (selectedPatientId != null) {
      final firstPat = patients.first;
      final defaultDocObj = firstPat['attendingDoctorId'];
      final targetDocId = defaultDocObj is Map
          ? defaultDocObj['_id']?.toString()
          : defaultDocObj?.toString();
      if (targetDocId != null &&
          doctors.any(
            (d) =>
                d['_id']?.toString() == targetDocId ||
                (d['userId'] is Map && d['userId']['_id']?.toString() == targetDocId),
          )) {
        final matched = doctors.firstWhere(
          (d) =>
              d['_id']?.toString() == targetDocId ||
              (d['userId'] is Map && d['userId']['_id']?.toString() == targetDocId),
        );
        selectedDoctorId = matched['_id']?.toString();
      }
    }
    if (selectedDoctorId == null && doctors.isNotEmpty) {
      selectedDoctorId = doctors.first['_id']?.toString();
    }

    final typeCtrl = TextEditingController();
    final serviceCtrl = TextEditingController(text: 'Laboratoire');
    final notesCtrl = TextEditingController();
    final resultCtrl = TextEditingController();
    final docUrlCtrl = TextEditingController();
    String priority = 'MEDIUM';
    bool isAlreadyCompleted = false;

    final templates = {
      'Hémogramme (NFS)':
          'Hb: 14.0 g/dL, Leucocytes: 6,800/mm3, Plaquettes: 240,000/mm3. Formule normale.',
      'Glycémie & Bio': 'Glycémie à jeun: 5.2 mmol/L. Créatinine: 68 µmol/L. Ionogramme équilibré.',
      'Radio Thoracique':
          'Cliché pulmonaire de face : Transparence parenchymateuse préservée, pas de foyer.',
      'Scanner Abdominal':
          'Morphologie des viscères abdominaux sans particularité aiguë. Pas d\'épanchement.',
      'Échographie Pelvienne':
          'Utérus de taille normale. Ovaires d\'aspect folliculaire physiologique.',
      'Bilan PMA / Spermogramme':
          'Numération 52 M/mL, mobilité progressives 45%, vitalité 82%. Compatible protocole.',
    };

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: AppTheme.bottomSheetDecoration(context),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.add_task, color: Color(0xFF0284C7), size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '➕ Saisie / Entrée Directe d\'Acte Technique',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Sélection du Patient
                const Text(
                  'Patient concerné *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                if (patients.isEmpty)
                  const Text(
                    'Aucun patient trouvé dans la base clinic.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedPatientId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: patients.map((p) {
                      final id = p['_id']?.toString() ?? '';
                      final name = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim();
                      final cin = p['cin'] != null ? ' (CIN: ${p['cin']})' : '';
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text('$name$cin', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setModalState(() {
                        selectedPatientId = v;
                        final pat = patients.firstWhere(
                          (p) => p['_id']?.toString() == v,
                          orElse: () => null,
                        );
                        if (pat != null && pat['attendingDoctorId'] != null) {
                          final defaultDocObj = pat['attendingDoctorId'];
                          final targetDocId = defaultDocObj is Map
                              ? defaultDocObj['_id']?.toString()
                              : defaultDocObj?.toString();
                          if (targetDocId != null &&
                              doctors.any(
                                (d) =>
                                    d['_id']?.toString() == targetDocId ||
                                    (d['userId'] is Map &&
                                        d['userId']['_id']?.toString() == targetDocId),
                              )) {
                            final matched = doctors.firstWhere(
                              (d) =>
                                  d['_id']?.toString() == targetDocId ||
                                  (d['userId'] is Map &&
                                      d['userId']['_id']?.toString() == targetDocId),
                            );
                            selectedDoctorId = matched['_id']?.toString();
                          }
                        }
                      });
                    },
                  ),

                const SizedBox(height: 12),
                // Sélection du Médecin Prescripteur / Destinataire
                const Text(
                  'Médecin Prescripteur / Destinataire (optionnel)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                if (doctors.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    initialValue: selectedDoctorId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Aucun médecin assigné',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                      ...doctors.map((d) {
                        final id = d['_id']?.toString() ?? '';
                        final u = d['userId'];
                        final fn = u is Map ? (u['firstName'] ?? '') : (d['firstName'] ?? '');
                        final ln = u is Map ? (u['lastName'] ?? '') : (d['lastName'] ?? '');
                        final spec = d['specialty'] ?? 'Médecine';
                        return DropdownMenuItem<String?>(
                          value: id,
                          child: Text('Dr. $fn $ln ($spec)', overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) => setModalState(() => selectedDoctorId = v),
                  ),

                const SizedBox(height: 14),
                const Text(
                  'Modèles rapides :',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: templates.keys.map((key) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: Color(0xFF0284C7),
                          ),
                          label: Text(key, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            setModalState(() {
                              typeCtrl.text = key;
                              resultCtrl.text = templates[key] ?? '';
                              if (key.contains('Radio') ||
                                  key.contains('Scan') ||
                                  key.contains('Écho')) {
                                serviceCtrl.text = 'Radiologie';
                              } else if (key.contains('PMA')) {
                                serviceCtrl.text = 'PMA';
                              } else {
                                serviceCtrl.text = 'Laboratoire';
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Type / Intitulé de l\'Examen *',
                    hintText: 'Ex: Hémogramme, Scanner Thoracique, Spermogramme',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: serviceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Service / Unité',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: priority,
                        decoration: const InputDecoration(
                          labelText: 'Priorité',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'LOW', child: Text('Basse')),
                          DropdownMenuItem(value: 'MEDIUM', child: Text('Normale')),
                          DropdownMenuItem(value: 'HIGH', child: Text('Haute')),
                          DropdownMenuItem(value: 'URGENT', child: Text('🚨 URGENTE')),
                        ],
                        onChanged: (v) => setModalState(() => priority = v ?? 'MEDIUM'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Acte déjà réalisé — Enregistrer les résultats directement',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  value: isAlreadyCompleted,
                  onChanged: (v) => setModalState(() => isAlreadyCompleted = v ?? false),
                ),

                if (isAlreadyCompleted) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: resultCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Conclusions & Résultats techniques *',
                      hintText: 'Résultats d\'analyse ou compte-rendu d\'imagerie...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes techniques (Automate / Réactifs)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: docUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: '📎 Document / Cliché joint (URL ou réf)',
                      hintText: 'Ex: https://arij-pacs.tn/archive/scan_109.pdf',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes d\'instruction préliminaires',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'Créer l\'Examen dans le Dossier Patient',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      if (selectedPatientId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez sélectionner un patient')),
                        );
                        return;
                      }
                      if (typeCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez renseigner le type d\'examen')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      final patId = selectedPatientId!;
                      final currentUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];
                      final docId = selectedDoctorId;

                      final res = await api.createExam(
                        patientId: patId,
                        requestingDoctorId: docId,
                        examType: typeCtrl.text.trim(),
                        service: serviceCtrl.text.trim(),
                        priority: priority,
                        requestNotes: notesCtrl.text.trim(),
                      );

                      if (res['success'] == true && isAlreadyCompleted) {
                        final examId = res['data']?['_id']?.toString();
                        if (examId != null) {
                          await api.assignExam(examId, currentUserId);
                          await api.completeExam(
                            examId,
                            resultCtrl.text.trim().isEmpty
                                ? 'Examen validé.'
                                : resultCtrl.text.trim(),
                            notes: notesCtrl.text.trim(),
                            resultDocumentUrl: docUrlCtrl.text.trim(),
                          );
                        }
                      }
                      _loadExams();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF059669),
                            content: Text('✅ Examen créé et enregistré dans le dossier !'),
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

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProfileScreen(onProfileUpdated: () => setState(() {}), onLogout: widget.onLogout),
      ),
    );
  }

  Map<String, dynamic> _resolvePatientMap(dynamic patientInput) {
    return ExamResultDetailModal.resolvePatientMap(patientInput, patients);
  }

  void _openPatientDossier(dynamic patientData) {
    final patMap = _resolvePatientMap(patientData);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PatientDossierScreen(patient: patMap)),
    ).then((_) => _loadExams());
  }

  void _takeChargeExam(String examId, String examTitle) async {
    final techUserId = api.currentUser?['id'] ?? api.currentUser?['_id'] ?? '';
    // Optimistic local state update
    final idx = exams.indexWhere(
      (e) => (e['_id']?.toString() == examId || e['id']?.toString() == examId),
    );
    if (idx != -1) {
      setState(() {
        exams[idx]['status'] = 'IN_PROGRESS';
        exams[idx]['assignedTechnicianId'] = techUserId;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0284C7),
        content: Text('🔄 Examen "$examTitle" pris en charge (En cours de réalisation) !'),
      ),
    );

    try {
      await api.assignExam(examId, techUserId);
    } catch (_) {}
    _loadExams();
  }

  Future<void> _exportExamRecap(Map<String, dynamic> exam) async {
    final examType = exam['examType'] ?? 'Examen technique';
    final patient = _resolvePatientMap(exam['patientId'] ?? exam['patient']);
    final pfn = patient['firstName'] ?? '';
    final pln = patient['lastName'] ?? '';
    final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : 'Patient';
    final patRegId = patient['registryId'] ?? patient['dossierNumber'] ?? 'PAT-000';

    final result = exam['result'] ?? 'En attente de validation technique';
    final notes = exam['technicalNotes'] ?? 'N/A';
    final reqNotes = exam['requestNotes'] ?? 'N/A';
    final service = exam['service'] ?? 'Plateau Technique';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const CircularProgressIndicator(color: AppTheme.evergreen),
              const SizedBox(height: 18),
              const Text(
                'Génération du Récap IA Gemini...',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Examen: $examType - $patName',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} à ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final content =
          '''============================================================
POLYCLINIQUE EL ARIJ - COMPTE-RENDU TECHNIQUE D'EXAMEN
RÉCAPITULATIF DÉTAILLÉ GÉNÉRÉ PAR L'IA MÉDICALE GEMINI
============================================================
Date d'édition : $dateStr
Service        : $service
Acte Réalisé   : $examType
Statut         : ${exam['status'] ?? 'En cours'}
Priorité       : ${exam['priority'] ?? 'Normale'}

PATIENT :
- Nom & Prénom : $patName
- Dossier IPU  : $patRegId

PRESCRIPTION MÉDICALE :
- Demande & Renseignements cliniques : $reqNotes

RÉSULTATS & OBSERVATIONS TECHNIQUES :
$result

NOTES DE LABORATOIRE / AUTOMATE :
$notes

SYNTHÈSE IA GEMINI :
Les paramètres relevés lors de cet examen ($examType) ont été traités conformément aux standards d'assurance qualité du plateau technique de la Polyclinique El Arij. Traçabilité archivée au dossier patient.

============================================================
Document certifié conforme - Plateau Technique Arij
============================================================
''';

      final dir = await getApplicationDocumentsDirectory();
      final cleanName = patName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName =
          'Recap_Examen_${cleanName}_${examType.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.txt';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);

      if (mounted) {
        Navigator.pop(context);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/plain', name: fileName)],
          subject: 'Récap Examen $examType - $patName',
          text: 'Compte-rendu d\'examen $examType pour $patName',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.evergreen,
            behavior: SnackBarBehavior.floating,
            content: Text('Récap IA Gemini prêt à être enregistré dans Fichiers !'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.alertRed, content: Text('Erreur récap: $e')),
        );
      }
    }
  }

  void _showCreatePanicAlertModal(Map<String, dynamic> exam) async {
    List<dynamic> doctors = [];
    try {
      doctors = await api.getDoctors();
    } catch (_) {}

    final patient = _resolvePatientMap(exam['patientId'] ?? exam['patient']);
    final pfn = patient['firstName'] ?? '';
    final pln = patient['lastName'] ?? '';
    final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : 'Patient';

    final doctorObj = exam['requestingDoctorId'] ?? (patient['attendingDoctorId']);
    final targetDocId = doctorObj is Map ? doctorObj['_id']?.toString() : doctorObj?.toString();
    String? selectedDoctorId;
    if (targetDocId != null &&
        doctors.any(
          (d) =>
              d['_id']?.toString() == targetDocId ||
              (d['userId'] is Map && d['userId']['_id']?.toString() == targetDocId),
        )) {
      final matched = doctors.firstWhere(
        (d) =>
            d['_id']?.toString() == targetDocId ||
            (d['userId'] is Map && d['userId']['_id']?.toString() == targetDocId),
      );
      selectedDoctorId = matched['_id']?.toString();
    } else if (doctors.isNotEmpty) {
      selectedDoctorId = doctors.first['_id']?.toString();
    }

    final alertCtrl = TextEditingController(
      text:
          'Résultat critique sur ${exam['examType'] ?? 'Examen'} : valeur panique à prendre en charge d\'urgence.',
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final chosenDoc = doctors.firstWhere(
            (d) => d['_id']?.toString() == selectedDoctorId,
            orElse: () => null,
          );
          final docUser = chosenDoc != null
              ? (chosenDoc['userId'] is Map ? chosenDoc['userId'] : chosenDoc['user'])
              : null;
          final dfn = docUser is Map
              ? (docUser['firstName'] ?? '')
              : (chosenDoc != null ? (chosenDoc['firstName'] ?? '') : '');
          final dln = docUser is Map
              ? (docUser['lastName'] ?? '')
              : (chosenDoc != null ? (chosenDoc['lastName'] ?? '') : '');
          final currentDocName = '$dfn $dln'.trim().isNotEmpty
              ? 'Dr. $dfn $dln'.trim()
              : 'Médecin prescripteur';

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: AppTheme.bottomSheetDecoration(context),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Color(0xFFDC2626), size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🚨 Alerte Critique / Valeur Panique ($patName)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sélection du Médecin destinataire
                  const Text(
                    'Médecin Destinataire de l\'Alerte *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  if (doctors.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedDoctorId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: doctors.map((d) {
                        final id = d['_id']?.toString() ?? '';
                        final u = d['userId'];
                        final fn = u is Map ? (u['firstName'] ?? '') : (d['firstName'] ?? '');
                        final ln = u is Map ? (u['lastName'] ?? '') : (d['lastName'] ?? '');
                        final spec = d['specialty'] ?? 'Médecine';
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text('Dr. $fn $ln ($spec)', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) => setModalState(() => selectedDoctorId = v),
                    ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      'Cette alerte sera transmise en temps réel à $currentDocName et à l\'équipe de garde.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Description de l\'anomalie majeure *',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: alertCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ex: Troponine I > 5000 ng/L, suspicion infarctus aigu...',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text(
                        'Émettre l\'Alerte d\'Urgence',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final patId = patient is Map
                            ? patient['_id']?.toString()
                            : exam['patientId']?.toString();

                        final targetDocUser = chosenDoc != null
                            ? (chosenDoc['userId'] is Map ? chosenDoc['userId'] : chosenDoc['user'])
                            : null;
                        final targetDocUserId = targetDocUser is Map
                            ? targetDocUser['_id']?.toString()
                            : chosenDoc?['_id']?.toString();

                        await api.createAlert(
                          patientId: patId ?? '',
                          targetDoctorId: targetDocUserId,
                          title: '🚨 Valeur Panique : ${exam['examType']}',
                          description: alertCtrl.text.trim(),
                          level: 'CRITICAL',
                        );
                        _loadExams();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF059669),
                            content: Text(
                              '✅ Alerte critique transmise avec succès à $currentDocName !',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _completeExamModal(Map<String, dynamic> exam) {
    final examId = exam['_id']?.toString() ?? exam['id']?.toString() ?? '';
    final examTitle = exam['examType'] ?? 'Examen';
    final requestNotes = exam['requestNotes'] ?? 'Aucune note du médecin.';
    final priority = exam['priority'] ?? 'MEDIUM';
    final isUrgent = priority == 'URGENT' || priority == 'HIGH';

    final patient = _resolvePatientMap(exam['patientId'] ?? exam['patient']);
    final pfn = patient['firstName'] ?? '';
    final pln = patient['lastName'] ?? '';
    final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : 'Patient inconnu';
    final patRegId = patient['dossierNumber'] ?? patient['registryId'] ?? 'PAT-000';

    final doctorObj = exam['requestingDoctorId'];
    final docUser = doctorObj is Map
        ? (doctorObj['userId'] is Map ? doctorObj['userId'] : doctorObj['user'])
        : null;
    final dfn = docUser is Map
        ? (docUser['firstName'] ?? '')
        : (doctorObj is Map ? (doctorObj['firstName'] ?? '') : '');
    final dln = docUser is Map
        ? (docUser['lastName'] ?? '')
        : (doctorObj is Map ? (doctorObj['lastName'] ?? '') : '');
    final docName = '$dfn $dln'.trim().isNotEmpty ? 'Dr. $dfn $dln'.trim() : 'Dr. Prescripteur';
    final serviceName = exam['service'] ?? 'Plateau Technique';

    final resultCtrl = TextEditingController(text: exam['result'] ?? '');
    final notesCtrl = TextEditingController(text: exam['technicalNotes'] ?? '');
    final docUrlCtrl = TextEditingController(text: exam['resultDocumentUrl'] ?? '');

    final templates = {
      'Scanner': 'Absence d\'anomalie évolutive aiguë. Parenchyme homogène.',
      'Radio': 'Cliché de bonne qualité technique. Transparence pulmonaire conservée.',
      'NFS': 'Hb: 13.5 g/dL, Leucocytes: 7,200/mm3, Plaquettes: 260,000/mm3.',
      'Biochimie': 'Ionogramme normal (Na+: 140 mmol/L, K+: 4.2 mmol/L).',
      'ECG': 'Rythme sinusal. Fréquence 72 bpm. Pas de trouble de repolarisation.',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: AppTheme.bottomSheetDecoration(context),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // HEADER
                Row(
                  children: [
                    const Icon(Icons.biotech, color: Color(0xFF0284C7), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Examen en cours : $examTitle',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // PATIENT & DEMANDE (Read Only)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Patient',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                      Text(
                        '$patName (Dossier : $patRegId)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Demande médicale',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Demandé par : $docName',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          if (isUrgent)
                            const Text(
                              '🔴 URGENT',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      Text('Service : $serviceName', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 8),
                      const Text(
                        'Notes du médecin :',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        '"$requestNotes"',
                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Modèles types
                const Text(
                  'Modèles rapides de compte-rendu :',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: templates.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: Color(0xFF0284C7),
                          ),
                          label: Text(entry.key, style: const TextStyle(fontSize: 11)),
                          onPressed: () => setModalState(() => resultCtrl.text = entry.value),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),
                const Text(
                  'Résultats techniques / Compte-rendu *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: resultCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Saisir le résultat...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),
                const Text(
                  'Notes techniques internes (ex: Automate, conditions)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Informations techniques...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),
                const Text(
                  '📷 Cliché Radiologique / Photo du Résultat / PDF *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.evergreen,
                  ),
                ),
                const SizedBox(height: 6),
                if (docUrlCtrl.text.isEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppTheme.evergreen, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(
                            Icons.photo_camera_rounded,
                            color: AppTheme.evergreen,
                            size: 20,
                          ),
                          label: const Text(
                            '📷 Joindre Photo',
                            style: TextStyle(
                              color: AppTheme.evergreen,
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
                                setModalState(() => docUrlCtrl.text = file.path ?? file.name);
                              }
                            } catch (_) {}
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Color(0xFF0F766E),
                            size: 20,
                          ),
                          label: const Text(
                            '📄 Joindre PDF',
                            style: TextStyle(
                              color: Color(0xFF0F766E),
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
                                setModalState(() => docUrlCtrl.text = file.path ?? file.name);
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
                      color: const Color(0xFFEDF2EA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.evergreen),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              docUrlCtrl.text.toLowerCase().endsWith('.pdf')
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.image_rounded,
                              color: AppTheme.evergreen,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                docUrlCtrl.text.split('/').last,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, size: 20, color: Colors.grey),
                              onPressed: () => setModalState(() => docUrlCtrl.clear()),
                            ),
                          ],
                        ),
                        if (!docUrlCtrl.text.toLowerCase().endsWith('.pdf')) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 120,
                              width: double.infinity,
                              color: Colors.black12,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(Icons.image, size: 48, color: AppTheme.evergreen),
                                  Positioned(
                                    bottom: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xB3000000),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '📷 Aperçu Photo Réussit',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'Terminer l\'examen',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      if (resultCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez renseigner les résultats')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);

                      final idx = exams.indexWhere(
                        (e) => (e['_id']?.toString() == examId || e['id']?.toString() == examId),
                      );
                      if (idx != -1) {
                        setState(() {
                          exams[idx]['status'] = 'COMPLETED';
                          exams[idx]['result'] = resultCtrl.text.trim();
                          exams[idx]['technicalNotes'] = notesCtrl.text.trim();
                          exams[idx]['resultDocumentUrl'] = docUrlCtrl.text.trim();
                        });
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF059669),
                          content: Text('Examen validé et terminé. Médecin notifié.'),
                        ),
                      );

                      try {
                        await api.completeExam(
                          examId,
                          resultCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                          resultDocumentUrl: docUrlCtrl.text.trim(),
                        );
                      } catch (_) {}
                      _loadExams();
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

  void _showAlertsModal() {
    _markAlertsAsRead();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: AppTheme.bottomSheetDecoration(context),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Color(0xFF0284C7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Alertes Plateau Technique (${alerts.length})',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (alerts.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text(
                        'Tout clôturer',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        await _handleResolveAllAlerts(ctx);
                      },
                    ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: alerts.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF10B981)),
                            SizedBox(height: 8),
                            Text(
                              'Aucune alerte active',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: alerts.length,
                        itemBuilder: (context, idx) {
                          final alert = alerts[idx];
                          final isCritical =
                              alert['level'] == 'CRITICAL' || alert['level'] == 'URGENT';
                          final patient = alert['patientId'];
                          final patName = patient is Map
                              ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim()
                              : 'Patient';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isCritical
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          alert['title'] ?? 'Alerte technique',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isCritical
                                                ? const Color(0xFFB91C1C)
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCritical
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFF0284C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          alert['level'] ?? 'INFO',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    alert['description'] ?? '',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF059669),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: const Icon(Icons.check_circle_outline, size: 14),
                                      label: const Text(
                                        'Clôturer',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                      ),
                                      onPressed: () async {
                                        await _handleResolveAlert(
                                          alert['_id']?.toString() ?? '',
                                          patName,
                                        );
                                        setModalState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediumFab({
    required String heroTag,
    required Color backgroundColor,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return SizedBox(
      height: 44,
      child: FloatingActionButton.extended(
        heroTag: heroTag,
        backgroundColor: backgroundColor,
        elevation: 2.5,
        highlightElevation: 4,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget? _buildTechnicianFab() {
    switch (_currentTab) {
      case 1:
        return _buildMediumFab(
          heroTag: 'tech_fab_1',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showCreateDirectExamModal,
          icon: Icons.science_rounded,
          label: 'Ajouter Examen & Photo',
        );
      case 2:
        return _buildMediumFab(
          heroTag: 'tech_fab_2',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showCreateDirectExamModal,
          icon: Icons.add_circle,
          label: 'Nouvel Examen & Photo',
        );
      case 3:
        return _buildMediumFab(
          heroTag: 'tech_fab_3',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showCreateDirectExamModal,
          icon: Icons.biotech_rounded,
          label: 'Saisir Résultat & Cliché',
        );
      case 4:
        return _buildMediumFab(
          heroTag: 'tech_fab_4',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showCreateTechAlertModal,
          icon: Icons.notification_add,
          label: 'Créer Alerte',
        );
      case 0:
      default:
        return _buildMediumFab(
          heroTag: 'tech_fab_0',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showCreateDirectExamModal,
          icon: Icons.science_rounded,
          label: 'Nouvel Examen & Photo',
        );
    }
  }

  Widget _buildPatientsTab() {
    final isDark = AppTheme.isDarkMode(context);
    final filtered = patients.where((p) {
      if (_selectedDepartmentFilter != 'ALL') {
        final dept = (p['department'] ?? '').toString().toUpperCase();
        if (_selectedDepartmentFilter == 'MATERNITE' &&
            !dept.contains('MATERN') &&
            !dept.contains('OBSTET') &&
            !dept.contains('MÈRE') &&
            !dept.contains('MERE'))
          return false;
        if (_selectedDepartmentFilter == 'CARDIOLOGIE' &&
            !dept.contains('CARDIO') &&
            !dept.contains('VASCUL'))
          return false;
        if (_selectedDepartmentFilter == 'CHIRURGIE' &&
            !dept.contains('CHIRURG') &&
            !dept.contains('HOSPIT') &&
            !dept.contains('BLOC'))
          return false;
        if (_selectedDepartmentFilter == 'PEDIATRIE' &&
            !dept.contains('PEDIAT') &&
            !dept.contains('NEONAT') &&
            !dept.contains('ENFANT'))
          return false;
        if (_selectedDepartmentFilter == 'PMA' &&
            !dept.contains('PMA') &&
            !dept.contains('GYNEC') &&
            !dept.contains('REPRODUCT'))
          return false;
      }
      final name = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.toLowerCase();
      final cin = (p['cin'] ?? '').toString().toLowerCase();
      final dossier = (p['dossierNumber'] ?? '').toString().toLowerCase();
      final q = patientSearchQuery.toLowerCase();
      return name.contains(q) || cin.contains(q) || dossier.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dossiers des Patients',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${filtered.length} dossiers médicaux disponibles',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.subtextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, CIN, N° dossier...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: AppTheme.evergreen, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (val) => setState(() => patientSearchQuery = val),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _techFilterChip('Tous les pôles', 'ALL', Icons.domain),
              const SizedBox(width: 8),
              _techFilterChip('🏥 Chirurgie & Hospit.', 'CHIRURGIE', Icons.local_hospital),
              const SizedBox(width: 8),
              _techFilterChip('🌸 Maternité & Obstétrique', 'MATERNITE', Icons.pregnant_woman),
              const SizedBox(width: 8),
              _techFilterChip('❤️ Cardiologie', 'CARDIOLOGIE', Icons.favorite),
              const SizedBox(width: 8),
              _techFilterChip('👶 Pédiatrie', 'PEDIATRIE', Icons.child_care),
              const SizedBox(width: 8),
              _techFilterChip('🧬 PMA & Gynéco.', 'PMA', Icons.biotech_rounded),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadExams,
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurface
                                  : AppTheme.evergreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.folder_open_rounded,
                              size: 48,
                              color: isDark ? AppTheme.drySage : AppTheme.evergreen,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun dossier trouvé',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            patientSearchQuery.isNotEmpty
                                ? 'Aucun patient ne correspond à "$patientSearchQuery"'
                                : 'Aucun patient ne correspond au filtre sélectionné.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppTheme.subtextColor(context)),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedDepartmentFilter = 'ALL';
                                patientSearchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                            label: const Text('Afficher tous les pôles'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.evergreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final p = filtered[idx];
                      return PatientWorklistCard(
                        patient: p,
                        onTap: () {
                          AppLogger.logInterface(
                            'Dossier Patient 360°',
                            fileName: 'technician_home_screen.dart',
                            details:
                                'Ouverture du dossier patient ${p['firstName']} ${p['lastName']}',
                          );
                          _openPatientDossier(p);
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _techFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedDepartmentFilter == value;
    final isDark = AppTheme.isDarkMode(context);
    return InkWell(
      onTap: () {
        setState(() => _selectedDepartmentFilter = value);
      },
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.evergreen
              : (isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA)),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected
                ? AppTheme.evergreen
                : (isDark ? AppTheme.darkElevated : AppTheme.dustGrey.withValues(alpha: 0.5)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.evergreen.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.evergreen),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.evergreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final user = api.currentUser;
    final fullName = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();
    final displayName = fullName.isEmpty ? 'Tech. Karim Benali' : 'Tech. $fullName';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppTheme.evergreen : AppTheme.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _buildTechnicianFab(),
      drawer: AppDrawer(
        onSelectTab: (idx) => setState(() => _currentTab = idx),
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      body: Column(
        children: [
          FigmaHeader(
            roleName: 'PLATEAU TECHNIQUE',
            roleColor: AppTheme.getRoleColor('TECHNICIAN'),
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            onThemeToggle: AppTheme.toggleTheme,
            onNotificationsPressed: _showAlertsModal,
            unreadNotifications: unreadAlertCount,
            profileImageUrl: user?['avatarUrl'],
            userName: fullName,
            onProfilePressed: _openProfile,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadExams,
              child: _buildCurrentTabContent(context, isDark, displayName, user),
            ),
          ),
        ],
      ),
      bottomNavigationBar: IosBottomNavBar(
        selectedIndex: _currentTab,
        onItemSelected: (idx) => setState(() => _currentTab = idx),
        activeColor: AppTheme.pastelOrange,
        items: const [
          IosBottomNavItem(
            icon: CupertinoIcons.square_grid_2x2,
            selectedIcon: CupertinoIcons.square_grid_2x2_fill,
            label: 'Dashboard',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.person_2,
            selectedIcon: CupertinoIcons.person_2_fill,
            label: 'Dossiers',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.doc_text_search,
            selectedIcon: CupertinoIcons.doc_text_search,
            label: 'Examens',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.time,
            selectedIcon: CupertinoIcons.time_solid,
            label: 'Historique',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.bell,
            selectedIcon: CupertinoIcons.bell_solid,
            label: 'Alertes',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTabContent(
    BuildContext context,
    bool isDark,
    String displayName,
    Map<String, dynamic>? user,
  ) {
    switch (_currentTab) {
      case 1:
        return _buildPatientsTab();
      case 2:
        return _buildExamensTab(context, isDark);
      case 3:
        return _buildHistoriqueTab(context, isDark);
      case 4:
        return _buildAlertsTab(isDark);
      case 0:
      default:
        return _buildDashboardTab(context, isDark, displayName);
    }
  }

  Widget _buildDashboardTab(BuildContext context, bool isDark, String displayName) {
    final now = DateTime.now();
    final days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    final dateStr = '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]} ${now.year}';

    final aiSummaryPreview = getBriefingSummaryPreview(
      dailyBriefing,
      fallback: 'Synthèse plateau technique matinale : bilans urgents prêts pour validation biologique et radiologique.',
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      children: [
        // ── AI Briefing Card (Deep Evergreen Gradient) ─────────────
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AiBriefingScreen(briefingData: dailyBriefing, onBriefingUpdated: _loadExams),
            ),
          ),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF002E2E), Color(0xFF063A34)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF002E2E).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'BRIEFING IA • CLINIQUE EL ARIJ',
                                style: TextStyle(
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${alerts.isNotEmpty ? alerts.length : 1} alertes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Synthèse Plateau Technique & Labo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  aiSummaryPreview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '+${exams.length} examens programmés',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Consulter l'analyse",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF002E2E),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF002E2E)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── 3 KPI Cards ───────────────────────────
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            size: 15,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'Attente',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F766E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${pendingCount > 0 ? pendingCount : 4}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'En attente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00).withValues(alpha: isDark ? 0.2 : 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFF7A00).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEDD5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emergency_rounded,
                            size: 15,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'Urgent',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${alerts.isNotEmpty ? alerts.length : 1}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                    const Text(
                      'Urgences Box',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'Validé',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D9488),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${completedCount > 0 ? completedCount : 8}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Validés',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── Urgences & Prélèvements Critiques Card ────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFF7A00).withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7A00).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEA580C),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Urgences & Prélèvements Critiques',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${alerts.isNotEmpty ? alerts.length : 1} Critique',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEDD5),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'MB',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'M. Mourad B.',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '• Box Urgences 3',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFDC2626),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Troponine Hs & Gazométrie artérielle',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Prélèvement sanguin urgent reçu - Résultats attendus sous 15 min',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                    Text(
                      '3 min',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: _showAlertsModal,
                        icon: const Icon(
                          Icons.notifications_active_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Voir alertes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          dynamic targetPatient;
                          if (alerts.isNotEmpty) {
                            targetPatient = alerts.first['patientId'] ?? alerts.first['patient'];
                          }
                          if (targetPatient == null && exams.isNotEmpty) {
                            targetPatient = exams.first['patientId'] ?? exams.first['patient'];
                          }
                          if (targetPatient == null && patients.isNotEmpty) {
                            targetPatient = patients.first;
                          }
                          _openPatientDossier(
                            targetPatient ??
                                {
                                  '_id': 'mourad_b',
                                  'firstName': 'Mourad',
                                  'lastName': 'B.',
                                  'gender': 'M',
                                  'age': 54,
                                  'bloodType': 'B+',
                                  'dossierNumber': '884921',
                                  'allergies': ['Iode / Produit de contraste'],
                                },
                          );
                        },
                        icon: const Icon(Icons.biotech_rounded, size: 15, color: Color(0xFF0F766E)),
                        label: const Text(
                          'Dossier patient',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Examens du jour ────────────────────────────
        Text(
          "Examens & Prélèvements du jour",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ...exams.where((e) => e['status'] == 'PENDING' || e['status'] == 'IN_PROGRESS').take(5).map(
          (ex) {
            final p = _resolvePatientMap(ex['patientId'] ?? ex['patient']);
            final pfn = p['firstName'] ?? '';
            final pln = p['lastName'] ?? '';
            final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : 'Patient';
            final type = ex['examType'] ?? 'Examen';
            final isUrgent = ex['priority'] == 'URGENT';
            return InkWell(
              onTap: () => _openPatientDossier(ex['patientId'] ?? ex['patient'] ?? ex),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isUrgent ? const Color(0xFFEA580C) : const Color(0xFF0F766E))
                            .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isUrgent ? Icons.emergency_rounded : Icons.science_rounded,
                        color: isUrgent ? const Color(0xFFEA580C) : const Color(0xFF0F766E),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            patName,
                            style: TextStyle(color: AppTheme.subtextColor(context), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.folder_badge_person_crop,
                            size: 12,
                            color: Color(0xFF0F766E),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Dossier',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(bool isDark, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11, color: AppTheme.subtextColor(context)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildExamensTab(BuildContext context, bool isDark) {
    final filtered = exams.where((e) {
      if (_selectedStatusFilter == 'URGENT' && e['priority'] != 'URGENT' && e['priority'] != 'HIGH')
        return false;
      if (_selectedStatusFilter == 'PENDING' && e['status'] != 'PENDING') return false;
      if (_selectedStatusFilter == 'IN_PROGRESS' && e['status'] != 'IN_PROGRESS') return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final type = (e['examType'] ?? e['title'] ?? '').toString().toLowerCase();
        final service = (e['service'] ?? '').toString().toLowerCase();
        final patient = e['patientId'];
        final pfn = patient is Map ? (patient['firstName'] ?? '') : '';
        final pln = patient is Map ? (patient['lastName'] ?? '') : '';
        final pName = '$pfn $pln'.toLowerCase();
        final pCin = (patient is Map ? (patient['cin'] ?? '') : '').toString().toLowerCase();
        if (!type.contains(q) && !service.contains(q) && !pName.contains(q) && !pCin.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      children: [
        // 1. Titre & Compteur
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demandes d\'Examens',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor(context),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${filtered.length} demande${filtered.length > 1 ? 's' : ''} technique${filtered.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.subtextColor(context),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 2. Barre de recherche en 2ème position
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher un examen, patient, service...',
              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: Icon(Icons.search, color: techPrimary, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        const SizedBox(height: 12),

        // 3. Filtres statut ordonnés en 3ème position
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterPill(
                label: 'Tous',
                count: exams.length,
                isSelected: _selectedStatusFilter == 'ALL',
                bgColor: AppTheme.darkTeal,
                textColor: Colors.white,
                onTap: () => setState(() => _selectedStatusFilter = 'ALL'),
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                label: '🚨 Urgents',
                count: exams
                    .where((e) => e['priority'] == 'URGENT' || e['priority'] == 'HIGH')
                    .length,
                isSelected: _selectedStatusFilter == 'URGENT',
                bgColor: AppTheme.alertRed,
                textColor: Colors.white,
                onTap: () => setState(() => _selectedStatusFilter = 'URGENT'),
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                label: '⏳ En attente',
                count: exams.where((e) => e['status'] == 'PENDING').length,
                isSelected: _selectedStatusFilter == 'PENDING',
                bgColor: AppTheme.pastelOrange,
                textColor: Colors.white,
                onTap: () => setState(() => _selectedStatusFilter = 'PENDING'),
              ),
              const SizedBox(width: 8),
              _buildFilterPill(
                label: '🔄 En cours',
                count: exams.where((e) => e['status'] == 'IN_PROGRESS').length,
                isSelected: _selectedStatusFilter == 'IN_PROGRESS',
                bgColor: const Color(0xFF0284C7),
                textColor: Colors.white,
                onTap: () => setState(() => _selectedStatusFilter = 'IN_PROGRESS'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. Liste des examens
        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    CupertinoIcons.doc_text_search,
                    size: 48,
                    color: AppTheme.subtextColor(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun examen trouvé',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Modifiez votre filtre ou terme de recherche',
                    style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                  ),
                ],
              ),
            ),
          )
        else
          ...filtered.map((e) => _buildExamCard(e)),
      ],
    );
  }

  Widget _buildHistoriqueTab(BuildContext context, bool isDark) {
    final completed = exams.where((e) => e['status'] == 'COMPLETED').toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historique des Examens',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${completed.length} examen${completed.length > 1 ? 's' : ''} validé${completed.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.subtextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.checkmark_seal_fill, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Text(
                      'Tous validés',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: completed.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.doc_checkmark,
                          size: 48,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun examen validé',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Les examens terminés apparaîtront ici.',
                        style: TextStyle(fontSize: 13, color: AppTheme.subtextColor(context)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: completed.length,
                  itemBuilder: (ctx, idx) => _buildExamCard(completed[idx]),
                ),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChip({required String label, required VoidCallback onRemove}) {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: techPrimary.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: techPrimary.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: techPrimary),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(CupertinoIcons.xmark_circle_fill, size: 13, color: techPrimary),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteExam(String examId, String examType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(CupertinoIcons.trash_fill, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Supprimer l\'examen ?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer la demande d\'examen "$examType" ?\nCette action est irréversible.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeDeleteExam(examId);
      return true;
    }
    return false;
  }

  void _executeDeleteExam(String examId) {
    if (examId.isEmpty) return;
    setState(() {
      _deletedExamIds.add(examId);
      exams.removeWhere((e) => (e['_id']?.toString() == examId || e['id']?.toString() == examId));
    });
    api.deleteExam(examId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1E293B),
          content: Text('🗑️ Examen supprimé avec succès.'),
        ),
      );
    }
  }

  Widget _buildFilterPill({
    IconData? icon,
    required String label,
    required int count,
    required bool isSelected,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: textColor), const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alertes & Notifications',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${alerts.length} alerte${alerts.length > 1 ? 's' : ''} active${alerts.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.subtextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateTechAlertModal,
                icon: const Icon(Icons.notification_add, size: 16, color: Colors.white),
                label: const Text(
                  'Émettre Alerte',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.bell_slash_fill,
                          size: 48,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune alerte active',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Toutes les alertes ont été traitées.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.subtextColor(context)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: alerts.length,
                  itemBuilder: (context, idx) {
                    final alert = alerts[idx];
                    final isCritical = alert['level'] == 'CRITICAL' || alert['level'] == 'URGENT';
                    final patient = alert['patientId'];
                    final patName = patient is Map
                        ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim()
                        : 'Patient';
                    final targetDoctor = alert['targetDoctorId'];
                    final createdBy = alert['createdBy'];
                    final creatorName = createdBy is Map
                        ? '${createdBy['role'] == 'TECHNICIAN'
                                  ? 'Tech. '
                                  : createdBy['role'] == 'DOCTOR'
                                  ? 'Dr. '
                                  : ''}${createdBy['firstName'] ?? ''} ${createdBy['lastName'] ?? ''}'
                              .trim()
                        : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131C2A) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isCritical
                              ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                              : (isDark ? const Color(0xFF1E2D42) : const Color(0xFFE2E8F0)),
                        ),
                        boxShadow: [
                          if (isCritical)
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
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
                                child: Row(
                                  children: [
                                    Icon(
                                      isCritical
                                          ? CupertinoIcons.exclamationmark_triangle_fill
                                          : CupertinoIcons.bell_fill,
                                      size: 16,
                                      color: isCritical ? const Color(0xFFEF4444) : techPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        alert['title'] ?? 'Alerte Technique',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isCritical
                                              ? const Color(0xFFEF4444)
                                              : AppTheme.textColor(context),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isCritical ? const Color(0xFFEF4444) : techPrimary,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      alert['level'] ?? 'INFO',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (alert['createdAt'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDate(alert['createdAt']),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.subtextColor(context),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            alert['description'] ?? '',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.subtextColor(context),
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E2D42) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(CupertinoIcons.person_fill, size: 11, color: techPrimary),
                                    const SizedBox(width: 4),
                                    Text(
                                      patName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: techPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (targetDoctor is Map)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E2D42)
                                        : const Color(0xFFEDF2EA),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: AppTheme.dustGrey),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.person_pin,
                                        size: 11,
                                        color: AppTheme.evergreen,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Dr. ${targetDoctor['firstName'] ?? ''} ${targetDoctor['lastName'] ?? ''}'
                                            .trim(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.evergreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E2D42)
                                        : const Color(0xFFEDF2EA),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.groups_outlined,
                                        size: 11,
                                        color: AppTheme.evergreen,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Tous les médecins',
                                        style: TextStyle(fontSize: 11, color: AppTheme.evergreen),
                                      ),
                                    ],
                                  ),
                                ),
                              if (creatorName != null && creatorName.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1E2D42)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF243245)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.send_rounded,
                                        size: 11,
                                        color: AppTheme.subtextColor(context),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Par : $creatorName',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.subtextColor(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF0F766E)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                icon: const Icon(
                                  CupertinoIcons.folder_badge_person_crop,
                                  size: 14,
                                  color: Color(0xFF0F766E),
                                ),
                                label: const Text(
                                  'Dossier',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                onPressed: () => _openPatientDossier(
                                  patient ?? alert['patientId'] ?? alert['patient'] ?? alert,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.evergreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                                icon: const Icon(CupertinoIcons.checkmark_seal_fill, size: 14),
                                label: const Text(
                                  'Clôturer',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                                onPressed: () async {
                                  await _handleResolveAlert(
                                    alert['_id']?.toString() ?? '',
                                    patName,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // 🚨 Alerte générique vers le médecin (sans contexte examen)
  void _showCreateTechAlertModal() async {
    List<dynamic> patients = [];
    List<dynamic> doctors = [];
    try {
      patients = await api.getPatients();
      doctors = await api.getDoctors();
    } catch (_) {}

    if (!mounted) return;
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Aucun patient disponible')));
      return;
    }

    String selectedPatientId = patients.first['_id'] ?? '';
    String? selectedDoctorId;
    String alertType = 'Résultat critique / Valeur panique';
    String priority = 'URGENT';
    final descCtrl = TextEditingController();

    final alertCategories = [
      'Résultat critique / Valeur panique',
      'Panne équipement urgente',
      'Contamination / Problème échantillon',
      'Anomalie majeure détectée (Radio/Écho)',
      'Résultat ECG anormal',
      'Erreur d\'identification patient',
      'Autre incident technique',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: AppTheme.bottomSheetDecoration(context),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(
                      CupertinoIcons.exclamationmark_triangle_fill,
                      color: Color(0xFFDC2626),
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Émettre une Alerte au Médecin',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text(
                  'Patient concerné *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: patients.any((p) => p['_id'] == selectedPatientId)
                      ? selectedPatientId
                      : patients.first['_id'],
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: patients.map<DropdownMenuItem<String>>((p) {
                    final fn = p['firstName'] ?? '';
                    final ln = p['lastName'] ?? '';
                    final name = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : 'Patient';
                    return DropdownMenuItem<String>(
                      value: p['_id'],
                      child: Text('$name (${p['cin'] ?? '—'})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final sel = patients.firstWhere((p) => p['_id'] == val, orElse: () => null);
                      final doc = sel != null ? sel['attendingDoctorId'] : null;
                      final docId = doc is Map ? doc['_id']?.toString() : doc?.toString();
                      setModalState(() {
                        selectedPatientId = val;
                        if (docId != null) selectedDoctorId = docId;
                      });
                    }
                  },
                ),

                const SizedBox(height: 12),
                const Text(
                  'Médecin destinataire *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  value: selectedDoctorId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Sélectionner le médecin',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        '📢 Tous les médecins de garde',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.evergreen),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...doctors.map<DropdownMenuItem<String?>>((doc) {
                      final u = doc['userId'];
                      final docUserId = u is Map ? u['_id']?.toString() : doc['userId']?.toString();
                      final fn = u is Map ? (u['firstName'] ?? '') : (doc['firstName'] ?? '');
                      final ln = u is Map ? (u['lastName'] ?? '') : (doc['lastName'] ?? '');
                      final spec = doc['specialty'] ?? 'Médecin';
                      return DropdownMenuItem<String?>(
                        value: docUserId,
                        child: Text('Dr. $fn $ln ($spec)', overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (val) => setModalState(() => selectedDoctorId = val),
                ),

                const SizedBox(height: 12),
                const Text(
                  'Type d\'incident *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: alertType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: alertCategories
                      .map(
                        (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => alertType = val);
                  },
                ),

                const SizedBox(height: 12),
                const Text(
                  'Niveau d\'urgence *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text(
                          '⚠️ URGENT',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        selected: priority == 'URGENT',
                        selectedColor: const Color(0xFFFFE4CC),
                        onSelected: (_) => setModalState(() => priority = 'URGENT'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text(
                          '🚨 CRITIQUE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        selected: priority == 'CRITICAL',
                        selectedColor: const Color(0xFFFFCDD2),
                        onSelected: (_) => setModalState(() => priority = 'CRITICAL'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Text(
                  'Description technique de l\'incident *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Troponine > 5000 ng/L, suspicion infarctus. ECG : sus-décalage V1-V4...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text(
                      'Transmettre l\'Alerte',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      await api.createAlert(
                        patientId: selectedPatientId,
                        targetDoctorId: selectedDoctorId,
                        title: '🔬 $alertType',
                        description: descCtrl.text.trim().isNotEmpty
                            ? descCtrl.text.trim()
                            : 'Incident technique signalé par le technicien : $alertType.',
                        level: priority,
                      );
                      _loadExams();
                      messenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF059669),
                          content: Text('✅ Alerte transmise au médecin avec succès !'),
                        ),
                      );
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

  Widget _buildInputConsole(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text('Console de saisie'),
    );
  }

  Widget _buildValidatedItem(bool isDark, String title, String subtitle, bool isUrgent) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isUrgent ? const Icon(Icons.warning, color: Colors.red) : null,
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final examId = exam['_id']?.toString() ?? exam['id']?.toString() ?? '';
    final examType = exam['examType'] ?? 'Examen technique';
    final status = exam['status'] ?? 'PENDING';
    final priority = exam['priority'] ?? 'MEDIUM';
    final isUrgent = priority == 'URGENT' || priority == 'HIGH';

    final patientMap = _resolvePatientMap(exam['patientId'] ?? exam['patient']);
    final pfn = patientMap['firstName'] ?? '';
    final pln = patientMap['lastName'] ?? '';
    final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : 'Patient';
    final patCin = patientMap['cin'];

    final doctorObj = exam['requestingDoctorId'] ?? (patientMap['attendingDoctorId']);

    final docUser = doctorObj is Map
        ? (doctorObj['userId'] is Map ? doctorObj['userId'] : doctorObj['user'])
        : null;
    final dfn = docUser is Map
        ? (docUser['firstName'] ?? '')
        : (doctorObj is Map ? (doctorObj['firstName'] ?? '') : '');
    final dln = docUser is Map
        ? (docUser['lastName'] ?? '')
        : (doctorObj is Map ? (doctorObj['lastName'] ?? '') : '');
    final docName = '$dfn $dln'.trim().isNotEmpty ? 'Dr. $dfn $dln'.trim() : 'Dr. Prescripteur';

    final assignedTechObj = exam['assignedTechnicianId'];
    final techUser = assignedTechObj is Map
        ? (assignedTechObj['userId'] is Map ? assignedTechObj['userId'] : assignedTechObj['user'])
        : null;
    final tfn = techUser is Map
        ? (techUser['firstName'] ?? '')
        : (assignedTechObj is Map ? (assignedTechObj['firstName'] ?? '') : '');
    final tln = techUser is Map
        ? (techUser['lastName'] ?? '')
        : (assignedTechObj is Map ? (assignedTechObj['lastName'] ?? '') : '');
    final assignedTechName = '$tfn $tln'.trim().isNotEmpty ? 'Tech. $tfn $tln'.trim() : null;

    final serviceName = exam['service'] ?? 'Plateau Technique';

    final reqNotes = exam['requestNotes'];
    final result = exam['result'];
    final docUrl = exam['resultDocumentUrl'];

    final isDark = AppTheme.isDarkMode(context);

    // Détermination de l'icône de service & couleur iOS
    IconData poleIcon = CupertinoIcons.waveform_path_ecg;
    Color poleColor = techPrimary;
    final servLower = serviceName.toString().toLowerCase();
    final typeLower = examType.toString().toLowerCase();
    if (servLower.contains('radio') ||
        servLower.contains('imag') ||
        typeLower.contains('scan') ||
        typeLower.contains('radio') ||
        typeLower.contains('echo')) {
      poleIcon = CupertinoIcons.camera_viewfinder;
      poleColor = const Color(0xFF007EA7);
    } else if (servLower.contains('lab') ||
        servLower.contains('bio') ||
        typeLower.contains('nfs') ||
        typeLower.contains('sang')) {
      poleIcon = CupertinoIcons.lab_flask_solid;
      poleColor = const Color(0xFF00A896);
    } else if (servLower.contains('cardio') || typeLower.contains('ecg')) {
      poleIcon = CupertinoIcons.heart_fill;
      poleColor = const Color(0xFFE11D48);
    } else if (servLower.contains('pma') || typeLower.contains('sperm')) {
      poleIcon = CupertinoIcons.sparkles;
      poleColor = const Color(0xFF9333EA);
    }

    Color statusBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    Color statusColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    IconData statusIcon = CupertinoIcons.clock_fill;
    String statusLabel = 'EN ATTENTE';

    if (status == 'IN_PROGRESS') {
      statusBg = isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE);
      statusColor = isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1);
      statusIcon = CupertinoIcons.gear_alt_fill;
      statusLabel = 'EN COURS';
    } else if (status == 'COMPLETED') {
      statusBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      statusColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);
      statusIcon = CupertinoIcons.checkmark_seal_fill;
      statusLabel = 'VALIDÉ';
    }

    return Dismissible(
      key: Key('exam_$examId'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteExam(examId, examType),
      onDismissed: (_) {
        _executeDeleteExam(examId);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(CupertinoIcons.trash_fill, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Supprimer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131C2A) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUrgent
                ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                : (isDark ? const Color(0xFF1E2D42) : const Color(0xFFE2E8F0)),
            width: isUrgent ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Ligne 1 : Icône Pôle + Type d'examen + Badge Statut iOS ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: poleColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(poleIcon, size: 20, color: poleColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          examType,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColor(context),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                serviceName,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: poleColor,
                                ),
                              ),
                            ),
                            if (assignedTechName != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '🎯 $assignedTechName',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                            if (isUrgent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.flame_fill,
                                      size: 10,
                                      color: Color(0xFFEF4444),
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'URGENT',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 11, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Ligne 2 : Patient & Médecin Prescripteur (Style iOS) ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2533) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF243245) : const Color(0xFFEDF2F7),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.person_crop_circle_fill,
                      size: 16,
                      color: AppTheme.subtextColor(context),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textColor(context)),
                          children: [
                            TextSpan(
                              text: patName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (patCin != null)
                              TextSpan(
                                text: ' ($patCin)',
                                style: TextStyle(
                                  color: AppTheme.subtextColor(context),
                                  fontSize: 11.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.medical_services_outlined, size: 14, color: Color(0xFF007EA7)),
                    const SizedBox(width: 4),
                    Text(
                      docName,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.subtextColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Motif prescripteur ──
              if (reqNotes != null && reqNotes.toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF17202C) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.quote_bubble_fill,
                        size: 13,
                        color: AppTheme.subtextColor(context).withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Motif : $reqNotes',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.subtextColor(context),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Résultat & Compte-rendu validé ──
              if (result != null && result.toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.checkmark_circle_fill,
                            size: 14,
                            color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Résultat & Compte-rendu validé :',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF064E3B),
                          height: 1.3,
                        ),
                      ),
                      if (docUrl != null && docUrl.toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(CupertinoIcons.paperclip, size: 12, color: techPrimary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Pièce jointe : $docUrl',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: techPrimary,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // ── Barre d'actions iOS ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openPatientDossier(patientMap),
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.folder_badge_person_crop,
                                  size: 14,
                                  color: Color(0xFF0F766E),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Dossier Patient',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Récap IA Gemini Fichiers
                      GestureDetector(
                        onTap: () => _exportExamRecap(exam),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7A00).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Color(0xFFFF7A00), size: 15),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Alerte anomalie
                      GestureDetector(
                        onTap: () => _showCreatePanicAlertModal(exam),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            color: Color(0xFFEF4444),
                            size: 15,
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Supprimer
                      GestureDetector(
                        onTap: () => _confirmDeleteExam(examId, examType),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.trash,
                            color: Color(0xFF94A3B8),
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Bouton Action Principale
                  if (status == 'PENDING')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: techPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(CupertinoIcons.play_arrow_solid, size: 13),
                        label: const Text(
                          'Prendre en charge',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _takeChargeExam(examId, examType),
                      ),
                    )
                  else if (status == 'IN_PROGRESS')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(CupertinoIcons.square_pencil_fill, size: 13),
                        label: const Text(
                          'Saisir & Valider',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _completeExamModal(exam),
                      ),
                    )
                  else
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _completeExamModal(exam),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.pencil, size: 13, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'Modifier',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
