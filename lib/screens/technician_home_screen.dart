import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar_widget.dart';
import 'patient_dossier_screen.dart';
import 'profile_screen.dart';
import 'staff_messenger_screen.dart';

class TechnicianHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const TechnicianHomeScreen({super.key, required this.onLogout});

  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen> {
  final api = ApiService();
  String _selectedServiceFilter = 'ALL';
  String _selectedStatusFilter = 'ALL';
  String _searchQuery = '';

  List<dynamic> exams = [];
  List<dynamic> alerts = [];
  final Set<String> _readAlertIds = {};
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
      final list = prefs.getStringList('arij_tech_read_alerts') ?? [];
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
      await prefs.setStringList('arij_tech_read_alerts', _readAlertIds.toList());
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

        if (list.length != exams.length || newAlerts.length != alerts.length) {
          setState(() {
            exams = list;
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
      setState(() {
        exams = results[0];
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

    Map<String, dynamic>? selectedPatient = patients.isNotEmpty ? patients.first as Map<String, dynamic> : null;

    final defaultDocObj = selectedPatient != null ? selectedPatient['attendingDoctorId'] : null;
    Map<String, dynamic>? selectedDoctor = defaultDocObj is Map ? defaultDocObj as Map<String, dynamic> : (doctors.isNotEmpty ? doctors.first as Map<String, dynamic> : null);

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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selectedPatient,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: patients.map((p) {
                      final name = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim();
                      final cin = p['cin'] != null ? ' (CIN: ${p['cin']})' : '';
                      return DropdownMenuItem(
                        value: p as Map<String, dynamic>,
                        child: Text('$name$cin', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setModalState(() {
                        selectedPatient = v;
                        if (v != null && v['attendingDoctorId'] is Map) {
                          selectedDoctor = v['attendingDoctorId'] as Map<String, dynamic>;
                        }
                      });
                    },
                  ),

                const SizedBox(height: 12),
                // Sélection du Médecin Prescripteur / Destinataire
                const Text('Médecin Prescripteur / Destinataire (optionnel)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                if (doctors.isNotEmpty)
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selectedDoctor,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: doctors.map((d) {
                      final u = d['userId'];
                      final fn = u is Map ? (u['firstName'] ?? '') : (d['firstName'] ?? '');
                      final ln = u is Map ? (u['lastName'] ?? '') : (d['lastName'] ?? '');
                      final spec = d['specialty'] ?? 'Médecine';
                      return DropdownMenuItem(
                        value: d as Map<String, dynamic>,
                        child: Text('Dr. $fn $ln ($spec)', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setModalState(() => selectedDoctor = v),
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
                      if (selectedPatient == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un patient')));
                        return;
                      }
                      if (typeCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez renseigner le type d\'examen')));
                        return;
                      }
                      Navigator.pop(ctx);
                      final patId = selectedPatient!['_id']?.toString() ?? '';
                      final currentUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];
                      final docId = selectedDoctor?['_id']?.toString();

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
    Map<String, dynamic>? selectedDoctor = doctorObj is Map ? doctorObj as Map<String, dynamic> : (doctors.isNotEmpty ? doctors.first as Map<String, dynamic> : null);

    final alertCtrl = TextEditingController(text: 'Résultat critique sur ${exam['examType'] ?? 'Examen'} : valeur panique à prendre en charge d\'urgence.');

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final docUser = selectedDoctor != null ? (selectedDoctor!['userId'] is Map ? selectedDoctor!['userId'] : selectedDoctor!['user']) : null;
          final dfn = docUser is Map ? (docUser['firstName'] ?? '') : (selectedDoctor != null ? (selectedDoctor!['firstName'] ?? '') : '');
          final dln = docUser is Map ? (docUser['lastName'] ?? '') : (selectedDoctor != null ? (selectedDoctor!['lastName'] ?? '') : '');
          final currentDocName = '$dfn $dln'.trim().isNotEmpty ? 'Dr. $dfn $dln'.trim() : 'Médecin prescripteur';

          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: selectedDoctor,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      items: doctors.map((d) {
                        final u = d['userId'];
                        final fn = u is Map ? (u['firstName'] ?? '') : (d['firstName'] ?? '');
                        final ln = u is Map ? (u['lastName'] ?? '') : (d['lastName'] ?? '');
                        final spec = d['specialty'] ?? 'Médecine';
                        return DropdownMenuItem(
                          value: d as Map<String, dynamic>,
                          child: Text('Dr. $fn $ln ($spec)', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) => setModalState(() => selectedDoctor = v),
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

                        final targetDocUser = selectedDoctor != null ? (selectedDoctor!['userId'] is Map ? selectedDoctor!['userId'] : selectedDoctor!['user']) : null;
                        final targetDocUserId = targetDocUser is Map ? targetDocUser['_id']?.toString() : selectedDoctor?['_id']?.toString();

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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      drawer: AppDrawer(
        onSelectTab: (_) {},
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
              child: Image.asset(
                'assets/logo-polyclinique-arij.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.biotech, color: AppTheme.primary, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Plateau Technique & Labo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    fullName.isNotEmpty ? fullName : 'Technicien Arij',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Messagerie & Appels Staff',
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0F172A)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.forum, color: Colors.white, size: 18),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => StaffMessengerScreen(onLogout: widget.onLogout)),
              );
            },
          ),
          IconButton(
            tooltip: 'Saisie / Entrée Directe d\'Acte Technique',
            icon: const Icon(Icons.add_circle, color: Color(0xFF0284C7), size: 26),
            onPressed: _showCreateDirectExamModal,
          ),
          // Bouton cloche d'alertes avec badge dynamique
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Alertes Plateau Technique',
                onPressed: _showAlertsModal,
              ),
              if (unreadAlertCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFF0284C7), shape: BoxShape.circle),
                    child: Text(
                      '$unreadAlertCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          GestureDetector(
            onTap: _openProfile,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: AvatarWidget(
                avatarUrl: user?['avatarUrl'],
                name: fullName,
                role: 'TECHNICIAN',
                radius: 18,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Bandeau Services Plateaux Techniques
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildServiceChip('ALL', '🌐 Tous Plateaux'),
                  const SizedBox(width: 8),
                  _buildServiceChip('RADIO', '🩻 Radiologie & Scanner'),
                  const SizedBox(width: 8),
                  _buildServiceChip('LABO', '🧪 Laboratoire & Bio'),
                  const SizedBox(width: 8),
                  _buildServiceChip('CARDIO', '🫀 Cardiologie & ECG'),
                  const SizedBox(width: 8),
                  _buildServiceChip('PMA', '🧬 PMA & Fécondation'),
                ],
              ),
            ),
          ),

          // Barre de Statuts & Compteurs
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                _buildStatusTab('ALL', 'Tous (${exams.length})'),
                const SizedBox(width: 6),
                _buildStatusTab('PENDING', '⏳ En attente ($pendingCount)'),
                const SizedBox(width: 6),
                _buildStatusTab('IN_PROGRESS', '🔄 En cours ($inProgressCount)'),
                const SizedBox(width: 6),
                _buildStatusTab('COMPLETED', '✅ Validés ($completedCount)'),
              ],
            ),
          ),

          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un examen ou un patient...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          const Divider(height: 1),

          // Liste des examens
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredExams.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.biotech_outlined, size: 54, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 10),
                            Text(
                              _selectedStatusFilter == 'PENDING' ? 'Aucune demande d\'examen en attente' : 'Aucun examen trouvé',
                              style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadExams,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(14),
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
    );
  }

  Widget _buildServiceChip(String key, String label) {
    final isSelected = _selectedServiceFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF334155), fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 12)),
      selected: isSelected,
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (_) => setState(() => _selectedServiceFilter = key),
    );
  }

  Widget _buildStatusTab(String key, String label) {
    final isSelected = _selectedStatusFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatusFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final examId = exam['_id']?.toString() ?? '';
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
    final docName = '$dfn $dln'.trim().isNotEmpty ? 'Dr. $dfn $dln'.trim() : 'Dr. Prescripteur / Traitant';

    final assignedTechObj = exam['assignedTechnicianId'];
    final techUser = assignedTechObj is Map ? (assignedTechObj['userId'] is Map ? assignedTechObj['userId'] : assignedTechObj['user']) : null;
    final tfn = techUser is Map ? (techUser['firstName'] ?? '') : (assignedTechObj is Map ? (assignedTechObj['firstName'] ?? '') : '');
    final tln = techUser is Map ? (techUser['lastName'] ?? '') : (assignedTechObj is Map ? (assignedTechObj['lastName'] ?? '') : '');
    final assignedTechName = '$tfn $tln'.trim().isNotEmpty ? 'Tech. $tfn $tln'.trim() : null;

    final serviceName = exam['service'] ?? 'Plateau Technique';

    final reqNotes = exam['requestNotes'];
    final result = exam['result'];
    final docUrl = exam['resultDocumentUrl'];

    Color statusBg = const Color(0xFFFEF3C7);
    Color statusColor = const Color(0xFFB45309);
    String statusLabel = 'EN ATTENTE';

    if (status == 'IN_PROGRESS') {
      statusBg = const Color(0xFFE0F2FE);
      statusColor = const Color(0xFF0369A1);
      statusLabel = 'EN COURS';
    } else if (status == 'COMPLETED') {
      statusBg = const Color(0xFFD1FAE5);
      statusColor = const Color(0xFF047857);
      statusLabel = 'VALIDÉ';
    }

    return Dismissible(
      key: Key('exam_${exam['_id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_sweep, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Masquer / Supprimer',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        final id = exam['_id']?.toString();
        if (id != null) {
          await api.deleteExam(id);
          _loadExams();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Élément masqué de votre liste (conservé pour l\'administration).'),
              ),
            );
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1 : Type d'examen et badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    examType,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Ligne 2 : Service / Département & Technicien ciblé
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    serviceName,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    assignedTechName != null ? '🎯 $assignedTechName' : '👥 Tout le service',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: assignedTechName != null ? FontWeight.bold : FontWeight.normal,
                      color: assignedTechName != null ? const Color(0xFF059669) : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Ligne 3 : Infos patient & Prescripteur
            Row(
              children: [
                const Icon(Icons.person, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(patName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (patCin != null) Text(' ($patCin)', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    docName,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (reqNotes != null && reqNotes.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                child: Text('Motif prescripteur : $reqNotes', style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontStyle: FontStyle.italic)),
              ),
            ],

            // Si résultat disponible
            if (result != null && result.toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFA7F3D0))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text('Résultat & Compte-rendu validé :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF065F46))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(result.toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF064E3B))),
                    if (docUrl != null && docUrl.toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.attach_file, size: 13, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Document attaché : $docUrl',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), decoration: TextDecoration.underline),
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

            const SizedBox(height: 12),

            // Barre d'actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (patient is Map)
                  TextButton.icon(
                    icon: const Icon(Icons.folder_shared, size: 15),
                    label: const Text('Dossier', style: TextStyle(fontSize: 12)),
                    onPressed: () => _openPatientDossier(patient as Map<String, dynamic>),
                  ),
                const SizedBox(width: 6),

                // Bouton Alerte Valeur Panique
                IconButton(
                  icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                  tooltip: 'Signaler anomalie critique',
                  onPressed: () => _showCreatePanicAlertModal(exam),
                ),
                const SizedBox(width: 4),

                if (status == 'PENDING')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Prendre en charge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _takeChargeExam(examId, examType),
                  )
                else if (status == 'IN_PROGRESS')
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('Saisir & Valider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _completeExamModal(exam),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.visibility, size: 15, color: Color(0xFF059669)),
                    label: const Text('Modifier résultat', style: TextStyle(fontSize: 12, color: Color(0xFF059669))),
                    onPressed: () => _completeExamModal(exam),
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

