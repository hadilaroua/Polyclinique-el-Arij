import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dark_ambient_background.dart';
import '../widgets/figma_header.dart';
import '../widgets/ios_bottom_nav_bar.dart';
import 'patient_dossier_screen.dart';
import 'profile_screen.dart';


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
    final results = await Future.wait([
      api.getExams(),
      api.getAlerts(isResolved: false),
    ]);
    if (mounted) {
      final list = results[0].where((e) {
        final id = e['_id']?.toString() ?? e['id']?.toString();
        return id != null && !_deletedExamIds.contains(id);
      }).toList();
      setState(() {
        exams = list;
        alerts = results[1];
        isLoading = false;
      });
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
      final results = await Future.wait([
        api.getPatients(),
        api.getDoctors(),
      ]);
      patients = results[0];
      doctors = results[1];
    } catch (_) {}

    String? selectedPatientId = patients.isNotEmpty ? patients.first['_id']?.toString() : null;
    String? selectedDoctorId;
    if (selectedPatientId != null) {
      final firstPat = patients.first;
      final defaultDocObj = firstPat['attendingDoctorId'];
      final targetDocId = defaultDocObj is Map ? defaultDocObj['_id']?.toString() : defaultDocObj?.toString();
      if (targetDocId != null && doctors.any((d) => d['_id']?.toString() == targetDocId || (d['userId'] is Map && d['userId']['_id']?.toString() == targetDocId))) {
        final matched = doctors.firstWhere((d) => d['_id']?.toString() == targetDocId || (d['userId'] is Map && d['userId']['_id']?.toString() == targetDocId));
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
      'Hémogramme (NFS)': 'Hb: 14.0 g/dL, Leucocytes: 6,800/mm3, Plaquettes: 240,000/mm3. Formule normale.',
      'Glycémie & Bio': 'Glycémie à jeun: 5.2 mmol/L. Créatinine: 68 µmol/L. Ionogramme équilibré.',
      'Radio Thoracique': 'Cliché pulmonaire de face : Transparence parenchymateuse préservée, pas de foyer.',
      'Scanner Abdominal': 'Morphologie des viscères abdominaux sans particularité aiguë. Pas d\'épanchement.',
      'Échographie Pelvienne': 'Utérus de taille normale. Ovaires d\'aspect folliculaire physiologique.',
      'Bilan PMA / Spermogramme': 'Numération 52 M/mL, mobilité progressives 45%, vitalité 82%. Compatible protocole.',
    };

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
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
                const Text('Patient concerné *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                if (patients.isEmpty)
                  const Text('Aucun patient trouvé dans la base clinic.', style: TextStyle(color: Colors.red, fontSize: 12))
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedPatientId,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
                        final pat = patients.firstWhere((p) => p['_id']?.toString() == v, orElse: () => null);
                        if (pat != null && pat['attendingDoctorId'] != null) {
                          final defaultDocObj = pat['attendingDoctorId'];
                          final targetDocId = defaultDocObj is Map ? defaultDocObj['_id']?.toString() : defaultDocObj?.toString();
                          if (targetDocId != null && doctors.any((d) => d['_id']?.toString() == targetDocId || (d['userId'] is Map && d['userId']['_id']?.toString() == targetDocId))) {
                            final matched = doctors.firstWhere((d) => d['_id']?.toString() == targetDocId || (d['userId'] is Map && d['userId']['_id']?.toString() == targetDocId));
                            selectedDoctorId = matched['_id']?.toString();
                          }
                        }
                      });
                    },
                  ),

                const SizedBox(height: 12),
                // Sélection du Médecin Prescripteur / Destinataire
                const Text('Médecin Prescripteur / Destinataire (optionnel)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                if (doctors.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    initialValue: selectedDoctorId,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Aucun médecin assigné', style: TextStyle(color: Color(0xFF64748B))),
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
                const Text('Modèles rapides :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: templates.keys.map((key) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF0284C7)),
                          label: Text(key, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            setModalState(() {
                              typeCtrl.text = key;
                              resultCtrl.text = templates[key] ?? '';
                              if (key.contains('Radio') || key.contains('Scan') || key.contains('Écho')) {
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
                        decoration: const InputDecoration(labelText: 'Priorité', border: OutlineInputBorder()),
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
                  title: const Text('Acte déjà réalisé — Enregistrer les résultats directement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                    label: const Text('Créer l\'Examen dans le Dossier Patient', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      if (selectedPatientId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un patient')));
                        return;
                      }
                      if (typeCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez renseigner le type d\'examen')));
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
                            resultCtrl.text.trim().isEmpty ? 'Examen validé.' : resultCtrl.text.trim(),
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
        builder: (_) => ProfileScreen(
          onProfileUpdated: () => setState(() {}),
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  void _openPatientDossier(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PatientDossierScreen(patient: patient),
      ),
    ).then((_) => _loadExams());
  }

  void _takeChargeExam(String examId, String examTitle) async {
    final techUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];
    setState(() => isLoading = true);
    await api.assignExam(examId, techUserId);
    _loadExams();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0284C7),
        content: Text('🔄 Examen "$examTitle" pris en charge (En cours de réalisation) !'),
      ),
    );
  }

  void _showCreatePanicAlertModal(Map<String, dynamic> exam) async {
    List<dynamic> doctors = [];
    try {
      doctors = await api.getDoctors();
    } catch (_) {}

    final patient = exam['patientId'];
    final patName = patient is Map ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim() : 'Patient';

    final doctorObj = exam['requestingDoctorId'] ?? (patient is Map ? patient['attendingDoctorId'] : null);
    final targetDocId = doctorObj is Map ? doctorObj['_id']?.toString() : doctorObj?.toString();
    String? selectedDoctorId;
    if (targetDocId != null && doctors.any((d) => d['_id']?.toString() == targetDocId || (d['userId'] is Map && d['userId']['_id']?.toString() == targetDocId))) {
      final matched = doctors.firstWhere((d) => d['_id']?.toString() == targetDocId || (d['userId'] is Map && d['userId']['_id']?.toString() == targetDocId));
      selectedDoctorId = matched['_id']?.toString();
    } else if (doctors.isNotEmpty) {
      selectedDoctorId = doctors.first['_id']?.toString();
    }

    final alertCtrl = TextEditingController(text: 'Résultat critique sur ${exam['examType'] ?? 'Examen'} : valeur panique à prendre en charge d\'urgence.');

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final chosenDoc = doctors.firstWhere((d) => d['_id']?.toString() == selectedDoctorId, orElse: () => null);
          final docUser = chosenDoc != null ? (chosenDoc['userId'] is Map ? chosenDoc['userId'] : chosenDoc['user']) : null;
          final dfn = docUser is Map ? (docUser['firstName'] ?? '') : (chosenDoc != null ? (chosenDoc['firstName'] ?? '') : '');
          final dln = docUser is Map ? (docUser['lastName'] ?? '') : (chosenDoc != null ? (chosenDoc['lastName'] ?? '') : '');
          final currentDocName = '$dfn $dln'.trim().isNotEmpty ? 'Dr. $dfn $dln'.trim() : 'Médecin prescripteur';

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Color(0xFFDC2626), size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '🚨 Alerte Critique / Valeur Panique ($patName)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sélection du Médecin destinataire
                  const Text('Médecin Destinataire de l\'Alerte *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (doctors.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedDoctorId,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFCA5A5))),
                    child: Text('Cette alerte sera transmise en temps réel à $currentDocName et à l\'équipe de garde.', style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
                  ),
                  const SizedBox(height: 12),
                  const Text('Description de l\'anomalie majeure *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: alertCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Ex: Troponine I > 5000 ng/L, suspicion infarctus aigu...'),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text('Émettre l\'Alerte d\'Urgence', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final patId = patient is Map ? patient['_id']?.toString() : exam['patientId']?.toString();

                        final targetDocUser = chosenDoc != null ? (chosenDoc['userId'] is Map ? chosenDoc['userId'] : chosenDoc['user']) : null;
                        final targetDocUserId = targetDocUser is Map ? targetDocUser['_id']?.toString() : chosenDoc?['_id']?.toString();

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
                          SnackBar(backgroundColor: const Color(0xFF059669), content: Text('✅ Alerte critique transmise avec succès à $currentDocName !')),
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
    final examId = exam['_id']?.toString() ?? '';
    final examTitle = exam['examType'] ?? 'Examen';
    final resultCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final docUrlCtrl = TextEditingController();

    final templates = {
      'Scanner': 'Absence d\'anomalie évolutive aiguë. Parenchyme homogène. Pas d\'épanchement ni de masse suspecte décelée.',
      'Radio': 'Cliché de bonne qualité technique. Transparence pulmonaire conservée. Silhouette cardio-médiastinale dans les limites de la normale.',
      'NFS': 'Hb: 13.5 g/dL, Leucocytes: 7,200/mm3, Plaquettes: 260,000/mm3. Formule leucocytaire équilibrée.',
      'Biochimie': 'Ionogramme normal (Na+: 140 mmol/L, K+: 4.2 mmol/L). Urée: 5.1 mmol/L, Créatinine: 74 µmol/L. Fonction rénale conservée.',
      'PMA': 'Spermogramme / Bilan de fertilité : Numération 48 M/mL, mobilité progressive 42%, vitalité 78%. Paramètres compatibles avec protocole FIV.',
      'Échographie': 'Organes abdominaux de morphologie et d\'échogénicité normales. Pas de calcul ni d\'adénomégalie.',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.biotech, color: Color(0xFF0284C7), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🔬 Saisie Résultat : $examTitle',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Modèles types
                const Text('Modèles rapides de compte-rendu :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: templates.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF0284C7)),
                          label: Text(entry.key, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            setModalState(() {
                              resultCtrl.text = entry.value;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),
                const Text('Résultats & Conclusions techniques *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: resultCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Saisir les conclusions de l\'analyse ou de l\'imagerie...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),
                const Text('Notes techniques internes (Appareil / Réactifs / Conditions)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Automate Sysmex XN-550, lot réactif #882, étalonnage OK',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),
                const Text('📎 Document joint / Cliché / Compte-rendu PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                if (docUrlCtrl.text.isEmpty) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.phone_android, color: AppTheme.primary, size: 20),
                    label: const Text(
                      '📷 Prendre une photo du résultat ou choisir un PDF du téléphone',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    onPressed: () async {
                      try {
                        final file = await FilePicker.pickFile(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
                        );
                        if (file != null) {
                          setModalState(() {
                            docUrlCtrl.text = file.path ?? file.name;
                          });
                        }
                      } catch (_) {}
                    },
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          docUrlCtrl.text.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                          color: docUrlCtrl.text.toLowerCase().endsWith('.pdf') ? Colors.red : AppTheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            docUrlCtrl.text.split('/').last,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                          onPressed: () {
                            setModalState(() {
                              docUrlCtrl.clear();
                            });
                          },
                        ),
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
                    label: const Text('Valider & Notifier le Médecin Prescripteur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      if (resultCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez renseigner les résultats')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      await api.completeExam(
                        examId,
                        resultCtrl.text.trim(),
                        notes: notesCtrl.text.trim(),
                        resultDocumentUrl: docUrlCtrl.text.trim(),
                      );
                      _loadExams();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF059669),
                          content: Text('🔔 Examen validé ! Le médecin prescripteur a été immédiatement notifié.'),
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

  void _showAlertsModal() {
    _markAlertsAsRead();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
                      label: const Text('Tout clôturer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        await _handleResolveAllAlerts(ctx);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
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
                            Text('Aucune alerte active', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: alerts.length,
                        itemBuilder: (context, idx) {
                          final alert = alerts[idx];
                          final isCritical = alert['level'] == 'CRITICAL' || alert['level'] == 'URGENT';
                          final patient = alert['patientId'];
                          final patName = patient is Map ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim() : 'Patient';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0))),
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
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isCritical ? const Color(0xFFB91C1C) : const Color(0xFF0F172A)),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: isCritical ? const Color(0xFFDC2626) : const Color(0xFF0284C7), borderRadius: BorderRadius.circular(4)),
                                        child: Text(alert['level'] ?? 'INFO', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(alert['description'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF059669),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.check_circle_outline, size: 14),
                                      label: const Text('Clôturer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                      onPressed: () async {
                                        await _handleResolveAlert(alert['_id']?.toString() ?? '', patName);
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

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final user = api.currentUser;
    final fullName = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();

    // Filtre des examens
    final filteredExams = exams.where((ex) {
      // Filtre service
      if (_selectedServiceFilter != 'ALL') {
        final serv = (ex['service'] ?? '').toString().toLowerCase();
        final type = (ex['examType'] ?? '').toString().toLowerCase();
        if (_selectedServiceFilter == 'RADIO' && !serv.contains('radio') && !serv.contains('imag') && !type.contains('scan') && !type.contains('radio') && !type.contains('echo')) return false;
        if (_selectedServiceFilter == 'LABO' && !serv.contains('lab') && !serv.contains('bio') && !type.contains('nfs') && !type.contains('sang') && !type.contains('bio')) return false;
        if (_selectedServiceFilter == 'CARDIO' && !serv.contains('cardio') && !serv.contains('ecg') && !type.contains('ecg') && !type.contains('cardio')) return false;
        if (_selectedServiceFilter == 'PMA' && !serv.contains('pma') && !serv.contains('reprod') && !type.contains('sperm') && !type.contains('fiv')) return false;
      }

      // Filtre statut
      if (_selectedStatusFilter != 'ALL' && ex['status'] != _selectedStatusFilter) {
        return false;
      }

      // Recherche texte
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final pat = ex['patientId'];
        final patName = pat is Map ? '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.toLowerCase() : '';
        final type = (ex['examType'] ?? '').toString().toLowerCase();
        if (!patName.contains(q) && !type.contains(q)) return false;
      }

      return true;
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundColor(context),
      drawer: AppDrawer(
        onSelectTab: (idx) => _onTabChanged(idx),
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tech_new_exam_fab',
        backgroundColor: techPrimary,
        onPressed: _showCreateDirectExamModal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouvel Examen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: DarkAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── FigmaHeader ──────────────────────────────────
              FigmaHeader(
                roleName: 'PLATEAU TECHNIQUE',
                roleColor: AppTheme.getRoleColor('TECHNICIAN'),
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                onThemeToggle: AppTheme.toggleTheme,
                onNotificationsPressed: _showAlertsModal,
                unreadNotifications: unreadAlertCount,
                profileImageUrl: user?['avatarUrl'],
                userName: fullName,
              ),

            // ── Subheader par onglet ────────────────────────────
            if (_currentTab == 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? const Color(0xFF131C2A) : const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.camera_viewfinder, size: 18, color: techPrimary),
                    const SizedBox(width: 8),
                    const Text(
                      'Pôle Radiologie & Imagerie Médicale',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: techPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${exams.where((e) => (e['service'] ?? '').toString().toLowerCase().contains('radio') || (e['service'] ?? '').toString().toLowerCase().contains('imag')).length} examens',
                        style: const TextStyle(fontSize: 11, color: techPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else if (_currentTab == 2)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? const Color(0xFF131C2A) : const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.lab_flask_solid, size: 18, color: techPrimary),
                    const SizedBox(width: 8),
                    const Text(
                      'Laboratoire d\'Analyses & Biologie',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: techPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${exams.where((e) => (e['service'] ?? '').toString().toLowerCase().contains('lab') || (e['service'] ?? '').toString().toLowerCase().contains('bio')).length} examens',
                        style: const TextStyle(fontSize: 11, color: techPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else if (_currentTab == 3)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isDark ? const Color(0xFF131C2A) : const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.checkmark_seal_fill, size: 18, color: Color(0xFF059669)),
                    const SizedBox(width: 8),
                    const Text(
                      'Examens Finalisés & Validés',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$completedCount validés',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // ── iOS Unified Search Bar & Dropdown Filter ────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  // Champ de recherche style iOS
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B293C) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E3E52) : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppTheme.textColor(context),
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            CupertinoIcons.search,
                            size: 18,
                            color: isDark ? const Color(0xFF8E9BAE) : const Color(0xFF64748B),
                          ),
                          hintText: 'Rechercher un examen, patient...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Bouton Menu Dropdown Filtre iOS
                  PopupMenuButton<String>(
                    tooltip: 'Filtrer les examens',
                    elevation: 10,
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    offset: const Offset(0, 48),
                    onSelected: (val) {
                      setState(() {
                        if (val.startsWith('STATUS_')) {
                          _selectedStatusFilter = val.replaceFirst('STATUS_', '');
                        } else if (val.startsWith('SERVICE_')) {
                          _selectedServiceFilter = val.replaceFirst('SERVICE_', '');
                        } else if (val == 'RESET_ALL') {
                          _selectedStatusFilter = 'ALL';
                          _selectedServiceFilter = 'ALL';
                        }
                      });
                    },
                    itemBuilder: (ctx) => [
                      // Section Statut
                      const PopupMenuItem<String>(
                        enabled: false,
                        height: 28,
                        child: Text(
                          'STATUT DE L\'EXAMEN',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                        ),
                      ),
                      _buildPopupItem(
                        'STATUS_ALL',
                        'Tous les statuts (${exams.length})',
                        CupertinoIcons.layers_fill,
                        _selectedStatusFilter == 'ALL',
                      ),
                      _buildPopupItem(
                        'STATUS_PENDING',
                        'En attente ($pendingCount)',
                        CupertinoIcons.clock_fill,
                        _selectedStatusFilter == 'PENDING',
                        iconColor: const Color(0xFFF59E0B),
                      ),
                      _buildPopupItem(
                        'STATUS_IN_PROGRESS',
                        'En cours ($inProgressCount)',
                        CupertinoIcons.gear_alt_fill,
                        _selectedStatusFilter == 'IN_PROGRESS',
                        iconColor: const Color(0xFF0284C7),
                      ),
                      _buildPopupItem(
                        'STATUS_COMPLETED',
                        'Validés & Finalisés ($completedCount)',
                        CupertinoIcons.checkmark_seal_fill,
                        _selectedStatusFilter == 'COMPLETED',
                        iconColor: const Color(0xFF10B981),
                      ),
                      const PopupMenuDivider(),

                      // Section Pôle (seulement si sur l'onglet Tout)
                      if (_currentTab == 0) ...[
                        const PopupMenuItem<String>(
                          enabled: false,
                          height: 28,
                          child: Text(
                            'PÔLE / SERVICE',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                          ),
                        ),
                        _buildPopupItem(
                          'SERVICE_ALL',
                          'Tous les pôles',
                          CupertinoIcons.square_grid_2x2_fill,
                          _selectedServiceFilter == 'ALL',
                        ),
                        _buildPopupItem(
                          'SERVICE_RADIO',
                          'Radiologie & Imagerie',
                          CupertinoIcons.camera_viewfinder,
                          _selectedServiceFilter == 'RADIO',
                          iconColor: const Color(0xFF007EA7),
                        ),
                        _buildPopupItem(
                          'SERVICE_LABO',
                          'Laboratoire & Biologie',
                          CupertinoIcons.lab_flask_solid,
                          _selectedServiceFilter == 'LABO',
                          iconColor: const Color(0xFF00A896),
                        ),
                        _buildPopupItem(
                          'SERVICE_CARDIO',
                          'Cardiologie & ECG',
                          CupertinoIcons.heart_fill,
                          _selectedServiceFilter == 'CARDIO',
                          iconColor: const Color(0xFFE11D48),
                        ),
                        _buildPopupItem(
                          'SERVICE_PMA',
                          'PMA & Reproduction',
                          CupertinoIcons.sparkles,
                          _selectedServiceFilter == 'PMA',
                          iconColor: const Color(0xFF9333EA),
                        ),
                        const PopupMenuDivider(),
                      ],

                      // Réinitialiser
                      const PopupMenuItem<String>(
                        value: 'RESET_ALL',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.arrow_counterclockwise, size: 15, color: Color(0xFFEF4444)),
                            SizedBox(width: 8),
                            Text(
                              'Réinitialiser tous les filtres',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: (_selectedStatusFilter != 'ALL' || _selectedServiceFilter != 'ALL')
                            ? techPrimary.withValues(alpha: isDark ? 0.2 : 0.12)
                            : (isDark ? const Color(0xFF1B293C) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_selectedStatusFilter != 'ALL' || _selectedServiceFilter != 'ALL')
                              ? techPrimary
                              : (isDark ? const Color(0xFF2E3E52) : const Color(0xFFE2E8F0)),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.slider_horizontal_3,
                            size: 18,
                            color: (_selectedStatusFilter != 'ALL' || _selectedServiceFilter != 'ALL')
                                ? techPrimary
                                : (isDark ? Colors.white : const Color(0xFF334155)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getFilterButtonLabel(),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: (_selectedStatusFilter != 'ALL' || _selectedServiceFilter != 'ALL')
                                  ? techPrimary
                                  : (isDark ? Colors.white : const Color(0xFF334155)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_down,
                            size: 13,
                            color: (_selectedStatusFilter != 'ALL' || _selectedServiceFilter != 'ALL')
                                ? techPrimary
                                : (isDark ? const Color(0xFF8E9BAE) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Pastille de Filtre Actif (si un filtre est sélectionné) ──
            if (_selectedStatusFilter != 'ALL' || _selectedServiceFilter != 'ALL')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (_selectedStatusFilter != 'ALL') ...[
                              _buildActiveFilterChip(
                                label: 'Statut: ${_getStatusLabel(_selectedStatusFilter)}',
                                onRemove: () => setState(() => _selectedStatusFilter = 'ALL'),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (_selectedServiceFilter != 'ALL') ...[
                              _buildActiveFilterChip(
                                label: 'Pôle: ${_getServiceLabel(_selectedServiceFilter)}',
                                onRemove: () => setState(() => _selectedServiceFilter = 'ALL'),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedStatusFilter = 'ALL';
                          _selectedServiceFilter = 'ALL';
                        });
                      },
                      child: const Text('Tout effacer', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 2),

            // ── Exam List ──────────────────────────────────────
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredExams.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(CupertinoIcons.doc_text_search, size: 30, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectedStatusFilter == 'PENDING'
                                    ? 'Aucune demande d\'examen en attente'
                                    : 'Aucun examen trouvé pour ces critères',
                                style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                              const SizedBox(height: 6),
                              if (_selectedStatusFilter != 'ALL' || _selectedServiceFilter != 'ALL')
                                TextButton.icon(
                                  icon: const Icon(CupertinoIcons.arrow_counterclockwise, size: 14),
                                  label: const Text('Réinitialiser les filtres', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    setState(() {
                                      _selectedStatusFilter = 'ALL';
                                      _selectedServiceFilter = 'ALL';
                                    });
                                  },
                                ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadExams,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                            itemCount: filteredExams.length,
                            itemBuilder: (context, idx) {
                              final exam = filteredExams[idx];
                              return _buildExamCard(exam);
                            },
                          ),
                        ),
            ),
        ],
      ),
    ),
  ),
  bottomNavigationBar: IosBottomNavBar(
    selectedIndex: _currentTab,
    onItemSelected: _onTabChanged,
    activeColor: AppTheme.tropicalTeal,
    items: const [
      IosBottomNavItem(
        icon: CupertinoIcons.house,
        selectedIcon: CupertinoIcons.house_fill,
        label: 'Accueil',
      ),
      IosBottomNavItem(
        icon: CupertinoIcons.camera_viewfinder,
        selectedIcon: CupertinoIcons.camera_viewfinder,
        label: 'Radiologie',
      ),
      IosBottomNavItem(
        icon: CupertinoIcons.lab_flask,
        selectedIcon: CupertinoIcons.lab_flask_solid,
        label: 'Laboratoire',
      ),
      IosBottomNavItem(
        icon: CupertinoIcons.checkmark_seal,
        selectedIcon: CupertinoIcons.checkmark_seal_fill,
        label: 'Validés',
      ),
    ],
  ),
);
}

  PopupMenuItem<String> _buildPopupItem(
    String value,
    String label,
    IconData icon,
    bool isSelected, {
    Color? iconColor,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: iconColor ?? (isSelected ? techPrimary : (isDark ? const Color(0xFF8E9BAE) : const Color(0xFF64748B))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? techPrimary : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
          ),
          if (isSelected)
            const Icon(CupertinoIcons.checkmark_alt, size: 16, color: techPrimary),
        ],
      ),
    );
  }

  String _getFilterButtonLabel() {
    if (_selectedStatusFilter != 'ALL' && _selectedServiceFilter != 'ALL') {
      return '2 Filtres';
    } else if (_selectedStatusFilter != 'ALL') {
      return _getStatusLabel(_selectedStatusFilter);
    } else if (_selectedServiceFilter != 'ALL') {
      return _getServiceLabel(_selectedServiceFilter);
    }
    return 'Filtres';
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'En attente';
      case 'IN_PROGRESS':
        return 'En cours';
      case 'COMPLETED':
        return 'Validés';
      default:
        return 'Tous';
    }
  }

  String _getServiceLabel(String service) {
    switch (service) {
      case 'RADIO':
        return 'Radiologie';
      case 'LABO':
        return 'Laboratoire';
      case 'CARDIO':
        return 'Cardiologie';
      case 'PMA':
        return 'PMA';
      default:
        return 'Tous';
    }
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

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final examId = exam['_id']?.toString() ?? exam['id']?.toString() ?? '';
    final examType = exam['examType'] ?? 'Examen technique';
    final status = exam['status'] ?? 'PENDING';
    final priority = exam['priority'] ?? 'MEDIUM';
    final isUrgent = priority == 'URGENT' || priority == 'HIGH';

    final patient = exam['patientId'];
    final pu = patient is Map ? (patient['userId'] is Map ? patient['userId'] : (patient['user'] is Map ? patient['user'] : null)) : null;
    final pfn = patient is Map ? (patient['firstName'] ?? pu?['firstName'] ?? '') : '';
    final pln = patient is Map ? (patient['lastName'] ?? pu?['lastName'] ?? '') : '';
    final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : (patient is Map ? (patient['name'] ?? 'Patient') : 'Patient');
    final patCin = patient is Map ? patient['cin'] : null;

    final doctorObj = exam['requestingDoctorId'] ?? (patient is Map ? patient['attendingDoctorId'] : null);
    final docUser = doctorObj is Map ? (doctorObj['userId'] is Map ? doctorObj['userId'] : doctorObj['user']) : null;
    final dfn = docUser is Map ? (docUser['firstName'] ?? '') : (doctorObj is Map ? (doctorObj['firstName'] ?? '') : '');
    final dln = docUser is Map ? (docUser['lastName'] ?? '') : (doctorObj is Map ? (doctorObj['lastName'] ?? '') : '');
    final docName = '$dfn $dln'.trim().isNotEmpty ? 'Dr. $dfn $dln'.trim() : 'Dr. Prescripteur';

    final assignedTechObj = exam['assignedTechnicianId'];
    final techUser = assignedTechObj is Map ? (assignedTechObj['userId'] is Map ? assignedTechObj['userId'] : assignedTechObj['user']) : null;
    final tfn = techUser is Map ? (techUser['firstName'] ?? '') : (assignedTechObj is Map ? (assignedTechObj['firstName'] ?? '') : '');
    final tln = techUser is Map ? (techUser['lastName'] ?? '') : (assignedTechObj is Map ? (assignedTechObj['lastName'] ?? '') : '');
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
    if (servLower.contains('radio') || servLower.contains('imag') || typeLower.contains('scan') || typeLower.contains('radio') || typeLower.contains('echo')) {
      poleIcon = CupertinoIcons.camera_viewfinder;
      poleColor = const Color(0xFF007EA7);
    } else if (servLower.contains('lab') || servLower.contains('bio') || typeLower.contains('nfs') || typeLower.contains('sang')) {
      poleIcon = CupertinoIcons.lab_flask_solid;
      poleColor = const Color(0xFF00A896);
    } else if (servLower.contains('cardio') || typeLower.contains('ecg')) {
      poleIcon = CupertinoIcons.heart_fill;
      poleColor = const Color(0xFFE11D48);
    } else if (servLower.contains('pma') || typeLower.contains('sperm')) {
      poleIcon = CupertinoIcons.sparkles;
      poleColor = const Color(0xFF9333EA);
    }

    Color statusBg = isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7);
    Color statusColor = isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
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
                                    Icon(CupertinoIcons.flame_fill, size: 10, color: Color(0xFFEF4444)),
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
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
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
                    Icon(CupertinoIcons.person_crop_circle_fill, size: 16, color: AppTheme.subtextColor(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textColor(context)),
                          children: [
                            TextSpan(text: patName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (patCin != null)
                              TextSpan(
                                text: ' ($patCin)',
                                style: TextStyle(color: AppTheme.subtextColor(context), fontSize: 11.5),
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
                      style: TextStyle(fontSize: 11.5, color: AppTheme.subtextColor(context), fontWeight: FontWeight.w500),
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
                      Icon(CupertinoIcons.quote_bubble_fill, size: 13, color: AppTheme.subtextColor(context).withValues(alpha: 0.7)),
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
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
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
                          Icon(CupertinoIcons.checkmark_circle_fill, size: 14, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669)),
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
              Row(
                children: [
                  if (patient is Map)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openPatientDossier(patient as Map<String, dynamic>),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: techPrimary.withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.folder_badge_person_crop, size: 14, color: techPrimary),
                              SizedBox(width: 4),
                              Text('Dossier', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: techPrimary)),
                            ],
                          ),
                        ),
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
                      child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFEF4444), size: 15),
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
                      child: const Icon(CupertinoIcons.trash, color: Color(0xFF94A3B8), size: 15),
                    ),
                  ),

                  const Spacer(),

                  // Bouton Action Principale
                  if (status == 'PENDING')
                    ElevatedButton.icon(
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
                      label: const Text('Prendre en charge', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      onPressed: () => _takeChargeExam(examId, examType),
                    )
                  else if (status == 'IN_PROGRESS')
                    ElevatedButton.icon(
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
                      label: const Text('Saisir & Valider', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      onPressed: () => _completeExamModal(exam),
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
                              Text('Modifier', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
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

