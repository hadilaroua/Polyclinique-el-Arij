import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/dark_ambient_background.dart';
import '../widgets/figma_header.dart';
import '../widgets/ios_bottom_nav_bar.dart';
import '../widgets/rooms_and_beds_view.dart';
import 'briefing_detail_screen.dart';
import 'nurse_care_calendar_screen.dart';
import 'patient_dossier_screen.dart';
import 'profile_screen.dart';


class NurseHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const NurseHomeScreen({super.key, required this.onLogout});

  @override
  State<NurseHomeScreen> createState() => _NurseHomeScreenState();
}

class _NurseHomeScreenState extends State<NurseHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTab = 0;
  final api = ApiService();

  List<dynamic> patients = [];
  List<dynamic> vitalSigns = [];
  List<dynamic> beds = [];
  List<dynamic> alerts = [];
  List<dynamic> doctors = [];
  Map<String, dynamic> dailyBriefing = {};
  final Set<String> _readAlertIds = {};
  final Set<String> _deletedVitalIds = {};
  bool isLoading = true;
  String patientSearchQuery = '';
  String _selectedDepartmentFilter = 'ALL';

  Timer? _realtimeTimer;

  int get unreadAlertCount => alerts.where((a) {
        final id = a['_id']?.toString();
        return id != null && !_readAlertIds.contains(id);
      }).length;

  @override
  void initState() {
    super.initState();
    _loadReadAlertIds();
    _loadData();
    _startRealtimeSync();
  }

  Future<void> _loadReadAlertIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('arij_nurse_read_alerts') ?? [];
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
      await prefs.setStringList('arij_nurse_read_alerts', _readAlertIds.toList());
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

  String _formatDate(String isoString) {
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

  void _startRealtimeSync() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      if (!mounted) return;
      try {
        final newAlerts = await api.getAlerts(isResolved: false);
        if (!mounted) return;
        if (newAlerts.length != alerts.length) {
          setState(() {
            alerts = newAlerts;
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final patRes = await api.getPatients();
      final vitalsRes = await api.getVitalSigns();
      final bedsRes = await api.getBeds();
      final alertsRes = await api.getAlerts();
      final docsRes = await api.getDoctors();
      final briefingRes = await api.getDailyBriefing();

      if (mounted) {
        final cleanVitals = vitalsRes.where((v) {
          final id = v['_id']?.toString() ?? v['id']?.toString();
          return id != null && !_deletedVitalIds.contains(id);
        }).toList();

        final validBriefing = briefingRes.isNotEmpty && briefingRes['metrics'] != null
            ? briefingRes
            : _getDefaultBriefingData();

        setState(() {
          patients = patRes;
          vitalSigns = cleanVitals;
          beds = bedsRes;
          alerts = alertsRes;
          doctors = docsRes;
          dailyBriefing = validBriefing;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          dailyBriefing = _getDefaultBriefingData();
          isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _getDefaultBriefingData() {
    final user = api.currentUser;
    final name = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();
    return {
      'date': 'Lundi 26 mai 2025',
      'rawDate': '2025-05-26',
      'greeting': 'Bonjour, $name 👋',
      'subGreeting': 'Voici votre briefing du jour',
      'serviceName': user?['service'] ?? 'Service Soins Infirmiers',
      'weather': {'temp': '26°C', 'city': 'Djerba', 'condition': 'Ensoleillé'},
      'metrics': {
        'consultationsCount': 7,
        'urgentConsultationsCount': 2,
        'hospitalizedCount': 3,
        'toMonitorHospitalizedCount': 1,
        'pendingExamsCount': 2,
        'tasksCount': 4,
        'urgentTasksCount': 1,
      },
      'nextAppointment': {
        'time': '09:30',
        'title': 'Tournée des constantes - Étage 2',
        'room': 'Chambre 204 • Infirmerie',
        'doctor': 'Dr Aroua',
        'patientName': 'Yassine Khelil',
      },
      'aiSummary':
          "Aujourd'hui, vous avez 7 actes de soins planifiés. 3 patients hospitalisés nécessitent une surveillance régulière. 2 examens biologiques sont en attente et 4 tâches prioritaires restent à finaliser. Une attention particulière est requise pour le patient en chambre 407.",
      'aiSummaryPreview':
          "Vous avez 7 soins planifiés aujourd'hui. 2 examens sont en attente de résultat et 3 patients hospitalisés nécessitent une surveillance particulière.",
      'consultationsList': [
        {'time': '09:30', 'title': 'Prise de constantes - Tension & SpO2', 'room': 'Chambre 204', 'specialty': 'Soins Infirmiers', 'isUrgent': true, 'patientName': 'Yassine Khelil'},
        {'time': '11:00', 'title': 'Administration traitement IV', 'room': 'Chambre 312', 'specialty': 'Cardiologie', 'isUrgent': false, 'patientName': 'Leila Bouaziz'},
        {'time': '14:00', 'title': 'Surveillance respiratoire post-aérosol', 'room': 'Chambre 407', 'specialty': 'Pneumologie', 'isUrgent': true, 'patientName': 'Salem Ghrissi'},
      ],
      'hospitalizedList': [
        {'room': 'Chambre 204', 'service': 'Médecine Interne', 'status': 'Stable', 'statusColor': 'green', 'patientName': 'Yassine Khelil'},
        {'room': 'Chambre 312', 'service': 'Cardiologie', 'status': 'En cours', 'statusColor': 'blue', 'patientName': 'Leila Bouaziz'},
        {'room': 'Chambre 407', 'service': 'Pneumologie', 'status': 'À surveiller', 'statusColor': 'orange', 'patientName': 'Salem Ghrissi'},
      ],
      'pendingExamsList': [
        {'title': 'Scanner thoracique', 'patientName': 'Patient (S. Ghrissi)', 'department': 'Radiologie', 'status': 'En attente'},
        {'title': 'Bilan biologique', 'patientName': 'Patient (Y. Khelil)', 'department': 'Laboratoire', 'status': 'En attente'},
      ],
      'tasksList': [
        {'id': 't1', 'title': 'Rendre compte de la visite', 'location': 'Chambre 204', 'time': '10:30', 'isCompleted': false, 'isPriority': true},
        {'id': 't2', 'title': 'Vérifier résultats biologiques', 'location': 'Laboratoire', 'time': '11:00', 'isCompleted': false, 'isPriority': false},
        {'id': 't3', 'title': 'Valider ordonnance de sortie', 'location': 'Chambre 312', 'time': '15:00', 'isCompleted': false, 'isPriority': false},
        {'id': 't4', 'title': 'Contrôle tensionnel post-perfusion', 'location': 'Salle de soins', 'time': '16:30', 'isCompleted': false, 'isPriority': false},
      ],
    };
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
    ).then((_) => _loadData());
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
                        const Icon(Icons.notifications_active, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Alertes Médicales (${alerts.length})',
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
                            Text(
                              'Aucune alerte active',
                              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
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
                              ? '${createdBy['role'] == 'NURSE' ? 'Inf. ' : createdBy['role'] == 'DOCTOR' ? 'Dr. ' : ''}${createdBy['firstName'] ?? ''} ${createdBy['lastName'] ?? ''}'.trim()
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
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
                                          alert['title'] ?? 'Alerte médicale',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isCritical ? const Color(0xFFB91C1C) : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isCritical ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              alert['level'] ?? 'INFO',
                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          if (alert['createdAt'] != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDate(alert['createdAt']),
                                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    alert['description'] ?? '',
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (targetDoctor is Map)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF2FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFC7D2FE)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.person_pin, size: 14, color: Color(0xFF4F46E5)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Transmis à : Dr. ${targetDoctor['firstName'] ?? ''} ${targetDoctor['lastName'] ?? ''}'.trim(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF4338CA),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.groups_outlined, size: 14, color: Color(0xFF64748B)),
                                              SizedBox(width: 4),
                                              Text(
                                                'Destinataire : Tous les médecins',
                                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (creatorName != null && creatorName.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.send_rounded, size: 12, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Émis par : $creatorName',
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                                      if (patient is Map)
                                        TextButton.icon(
                                          icon: const Icon(Icons.folder_shared, size: 15),
                                          label: Text('Dossier: $patName', style: const TextStyle(fontSize: 12)),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _openPatientDossier(patient as Map<String, dynamic>);
                                          },
                                        ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
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
                                    ],
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

  void _showPendingExamsModal() {
    final pendingExams = (dailyBriefing['pendingExamsList'] as List?) ?? [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                Row(
                  children: [
                    const Icon(Icons.science_rounded, color: AppTheme.bondiBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Examens en attente (${pendingExams.length})',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: pendingExams.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF10B981)),
                          SizedBox(height: 8),
                          Text(
                            'Aucun examen en attente',
                            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: pendingExams.length,
                      itemBuilder: (context, idx) {
                        final e = pendingExams[idx];
                        final title = e['title'] ?? 'Examen';
                        final patName = e['patientName'] ?? 'Patient';
                        final dept = e['department'] ?? 'Service';
                        final status = e['status'] ?? 'En attente';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
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
                                      const SizedBox(height: 4),
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
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Workflow : 🔴 Créer une alerte médicale immédiate pour le médecin
  void _showCreateAlertModal({String? preselectedPatientId, String? initialDescription}) {
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun patient disponible')),
      );
      return;
    }

    String selectedPatientId = preselectedPatientId ?? patients.first['_id'];
    // Détecter l'équipe de soin du patient sélectionné
    final selPatient = patients.firstWhere((p) => p['_id'] == selectedPatientId, orElse: () => null);
    String? selectedDoctorUserId;
    if (selPatient != null && selPatient['attendingDoctorId'] != null) {
      final doc = selPatient['attendingDoctorId'];
      if (doc is Map) {
        selectedDoctorUserId = (doc['userId'] is Map ? doc['userId']['_id'] : doc['_id'])?.toString();
      }
    }
    String alertType = 'Constantes vitales anormales';
    String priority = 'URGENT';
    final descCtrl = TextEditingController(text: initialDescription ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final currentPat = patients.firstWhere((p) => p['_id'] == selectedPatientId, orElse: () => null);
          final currentDoc = currentPat?['attendingDoctorId'];
          final currentDocName = currentDoc is Map
              ? 'Dr. ${currentDoc['firstName'] ?? ''} ${currentDoc['lastName'] ?? ''}'.trim()
              : null;
          final currentMidwife = currentPat?['assignedMidwifeId'];
          final currentMidwifeName = currentMidwife is Map
              ? '${currentMidwife['firstName'] ?? ''} ${currentMidwife['lastName'] ?? ''}'.trim()
              : null;

          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
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
                      Icon(Icons.warning_rounded, color: Colors.red, size: 24),
                      SizedBox(width: 8),
                      Text(
                        '🔴 Déclencher une Alerte Médicale',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF991B1B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Transmettez immédiatement l\'alerte au médecin traitant ou à l\'équipe de garde.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: selectedPatientId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Patient concerné *', border: OutlineInputBorder()),
                    items: patients.map<DropdownMenuItem<String>>((p) {
                      return DropdownMenuItem<String>(
                        value: p['_id'],
                        child: Text('${p['firstName']} ${p['lastName']} (${p['dossierNumber'] ?? p['cin']})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedPatientId = val;
                          final newPat = patients.firstWhere((p) => p['_id'] == val, orElse: () => null);
                          if (newPat != null && newPat['attendingDoctorId'] != null) {
                            final doc = newPat['attendingDoctorId'];
                            if (doc is Map) {
                              selectedDoctorUserId = (doc['userId'] is Map ? doc['userId']['_id'] : doc['_id'])?.toString();
                            }
                          }
                        });
                      }
                    },
                  ),

                  // Affichage équipe en charge du patient
                  if (currentDocName != null || currentMidwifeName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('👥 Équipe en charge de ce patient :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (currentDocName != null)
                                ActionChip(
                                  avatar: const Icon(Icons.person, size: 14, color: Color(0xFF1D4ED8)),
                                  label: Text('Médecin : $currentDocName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  backgroundColor: Colors.white,
                                  onPressed: () {
                                    final doc = currentPat['attendingDoctorId'];
                                    if (doc is Map) {
                                      setModalState(() {
                                        selectedDoctorUserId = (doc['userId'] is Map ? doc['userId']['_id'] : doc['_id'])?.toString();
                                      });
                                    }
                                  },
                                ),
                              if (currentMidwifeName != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFFFDF4FF), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF0ABFC))),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.favorite, size: 13, color: Color(0xFFC026D3)),
                                      const SizedBox(width: 4),
                                      Text('Sage-Femme : $currentMidwifeName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9333EA))),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Sélection du Médecin destinataire
                  DropdownButtonFormField<String?>(
                    initialValue: selectedDoctorUserId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Médecin destinataire *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_pin, color: Color(0xFF0284C7)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          '📢 Tous les médecins de garde (Diffusion générale)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                        ),
                      ),
                      ...doctors.map<DropdownMenuItem<String?>>((d) {
                        final u = d['userId'];
                        final docUserId = (u != null && u['_id'] != null) ? u['_id'].toString() : d['_id'].toString();
                        final docName = u != null
                            ? 'Dr. ${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim()
                            : 'Dr. ${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
                        final spec = d['specialty'] ?? 'Médecin';
                        return DropdownMenuItem<String?>(
                          value: docUserId,
                          child: Text(
                            '👨‍⚕️ $docName ($spec)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setModalState(() => selectedDoctorUserId = val);
                    },
                  ),

                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: alertType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type d\'alerte *', border: OutlineInputBorder()),
                    items: [
                      'Constantes vitales anormales',
                      'Pic fébrile élevé (> 38.5°C)',
                      'Désaturation en oxygène (< 92%)',
                      'Douleur aiguë sévère non soulagée',
                      'Dégradation de l\'état hémodynamique',
                      'Complication obstétricale / Maternité',
                      'Autre urgence soignante',
                    ].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => alertType = val);
                    },
                  ),

                  const SizedBox(height: 12),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Text('Niveau d\'urgence : ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ChoiceChip(
                        label: const Text('⚠️ Urgent'),
                        selected: priority == 'URGENT',
                        selectedColor: const Color(0xFFFEE2E2),
                        onSelected: (s) => setModalState(() => priority = 'URGENT'),
                      ),
                      ChoiceChip(
                        label: const Text('🚨 Critique'),
                        selected: priority == 'CRITICAL',
                        selectedColor: const Color(0xFFFCA5A5),
                        onSelected: (s) => setModalState(() => priority = 'CRITICAL'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description des signes cliniques observés *',
                      hintText: 'Ex: Température 39.1°C, patient frissonnant, tachycarde à 110 bpm...',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text(
                      'Transmettre l\'alerte au Médecin',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () async {
                      if (descCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez décrire la situation observée')),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final res = await api.createAlert(
                        patientId: selectedPatientId,
                        title: alertType,
                        description: descCtrl.text.trim(),
                        level: priority,
                        category: 'Alerte Soignante',
                        targetRoles: ['DOCTOR', 'NURSE'],
                        targetDoctorId: selectedDoctorUserId,
                      );

                    await _loadData();
                    if (mounted) {
                      if (res['success'] == true) {
                        NotificationService().showClinicalAlert(
                          title: alertType,
                          description: descCtrl.text.trim(),
                          level: priority,
                        );
                        messenger.showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFFDC2626),
                            content: Text('✅ Alerte médicale transmise avec succès au médecin traitant !'),
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.red.shade800,
                            content: Text('Erreur: ${res['data']?['message'] ?? 'Échec lors de la création de l\'alerte'}'),
                          ),
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
      },
    ),
  );
}

  void _showNewVitalSignModal({String? preselectedPatientId}) {
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun patient disponible dans la clinique')),
      );
      return;
    }
    String selectedPatientId = preselectedPatientId ?? patients.first['_id'];

    final tempCtrl = TextEditingController(text: '37.0');
    final sysCtrl = TextEditingController(text: '120');
    final diaCtrl = TextEditingController(text: '80');
    final hrCtrl = TextEditingController(text: '75');
    final spo2Ctrl = TextEditingController(text: '98');
    final notesCtrl = TextEditingController();
    final fileUrlCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
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
                const Text(
                  '📊 Prise de Constantes Vitales',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: selectedPatientId,
                  decoration: const InputDecoration(labelText: 'Patient *', border: OutlineInputBorder()),
                  items: patients.map<DropdownMenuItem<String>>((p) {
                    return DropdownMenuItem<String>(
                      value: p['_id'],
                      child: Text('${p['firstName']} ${p['lastName']} (${p['dossierNumber'] ?? p['cin']})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedPatientId = val);
                  },
                ),

                const SizedBox(height: 12),
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

                const SizedBox(height: 12),
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

                const SizedBox(height: 12),
                TextField(
                  controller: spo2Ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Saturation O₂ — SpO₂ (%)', border: OutlineInputBorder()),
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Observations infirmières / Sage-femme / Technicien', border: OutlineInputBorder()),
                ),

                const SizedBox(height: 12),
                const Text('📎 Pièce jointe / Résultat écrit / Photo (Optionnel)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textMain)),
                const SizedBox(height: 4),
                if (fileUrlCtrl.text.isEmpty) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.phone_android, color: AppTheme.primary, size: 18),
                    label: const Text(
                      '📷 Joindre une photo du résultat ou un PDF (Téléphone)',
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
                            fileUrlCtrl.text = file.path ?? file.name;
                          });
                        }
                      } catch (_) {}
                    },
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          fileUrlCtrl.text.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                          color: fileUrlCtrl.text.toLowerCase().endsWith('.pdf') ? Colors.red : AppTheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileUrlCtrl.text.split('/').last,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                          onPressed: () {
                            setModalState(() {
                              fileUrlCtrl.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final nurseUserId = api.currentUser?['id'] ?? api.currentUser?['_id'] ?? '';
                      final temp = double.tryParse(tempCtrl.text.trim());
                      final spo2 = int.tryParse(spo2Ctrl.text.trim());

                      final fullNotes = fileUrlCtrl.text.isNotEmpty
                          ? '${notesCtrl.text.trim()} [📄 Fichier joint: ${fileUrlCtrl.text.split('/').last}]'
                          : notesCtrl.text.trim();

                      final res = await api.createVitalSign(
                        patientId: selectedPatientId,
                        recordedByUserId: nurseUserId,
                        temperature: temp,
                        bloodPressureSystolic: int.tryParse(sysCtrl.text.trim()),
                        bloodPressureDiastolic: int.tryParse(diaCtrl.text.trim()),
                        heartRate: int.tryParse(hrCtrl.text.trim()),
                        oxygenSaturation: spo2,
                        notes: fullNotes,
                      );
                      await _loadData();

                      if (mounted) {
                        if (res['success'] == true) {
                          messenger.showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF0D9488),
                              content: Text('✅ Constantes vitales enregistrées avec succès !'),
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.red.shade800,
                              content: Text('Erreur: ${res['data']?['message'] ?? 'Échec de l\'enregistrement'}'),
                            ),
                          );
                        }
                      }

                      // Si constante anormale, proposer de déclencher l'alerte
                      if ((temp != null && temp >= 38.5) || (spo2 != null && spo2 < 92)) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.red[800],
                              duration: const Duration(seconds: 6),
                              content: const Text('⚠️ Constantes anormales détectées ! Alerte médecin recommandée.'),
                              action: SnackBarAction(
                                label: 'Créer Alerte',
                                textColor: Colors.white,
                                onPressed: () {
                                  _showCreateAlertModal(
                                    preselectedPatientId: selectedPatientId,
                                    initialDescription: 'Température ${temp ?? '-'}°C, SpO2 ${spo2 ?? '-'}%. Observation : ${notesCtrl.text.trim()}',
                                  );
                                },
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Enregistrer les Constantes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = api.currentUser;
    final fullName = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        onSelectTab: (idx) => setState(() => _currentTab = idx),
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      body: DarkAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              FigmaHeader(
                roleName: 'INFIRMIER',
                roleColor: AppTheme.getRoleColor('NURSE'),
                onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
                onThemeToggle: AppTheme.toggleTheme,
                onNotificationsPressed: _showAlertsModal,
                unreadNotifications: unreadAlertCount,
                profileImageUrl: user?['avatarUrl'],
                userName: fullName,
              ),
              if (isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: IndexedStack(
                    index: _currentTab,
                    children: [
                      _buildOverviewTab(),
                      _buildPatientsTab(),
                      _buildVitalsTab(),
                      _buildBedsTab(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: IosBottomNavBar(
        selectedIndex: _currentTab,
        onItemSelected: (idx) => setState(() => _currentTab = idx),
        activeColor: AppTheme.tropicalTeal,
        items: const [
          IosBottomNavItem(
            icon: CupertinoIcons.house,
            selectedIcon: CupertinoIcons.house_fill,
            label: 'Accueil',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.person_2,
            selectedIcon: CupertinoIcons.person_2_fill,
            label: 'Patients',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.heart,
            selectedIcon: CupertinoIcons.heart_fill,
            label: 'Constantes',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.bed_double,
            selectedIcon: CupertinoIcons.bed_double_fill,
            label: 'Lits',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final isDark = AppTheme.isDarkMode(context);
    final user = api.currentUser;
    final fullName = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();
    final greeting = dailyBriefing['greeting'] ?? 'Bonjour, $fullName 👋';
    final subGreeting = dailyBriefing['subGreeting'] ?? 'Voici votre briefing du jour';
    final dateStr = dailyBriefing['date'] ?? 'Lundi 26 mai 2025';
    final metrics = (dailyBriefing['metrics'] as Map<String, dynamic>?) ?? {};
    final consultationsCount = metrics['consultationsCount'] ?? 7;
    final hospitalizedCount = metrics['hospitalizedCount'] ?? (beds.isNotEmpty ? beds.where((b) => b['status'] == 'OCCUPIED').length : 3);
    final pendingExamsCount = metrics['pendingExamsCount'] ?? 2;
    final aiSummaryPreview = dailyBriefing['aiSummaryPreview'] ??
        "Vous avez $consultationsCount soins planifiés aujourd'hui. $pendingExamsCount examens sont en attente de résultat et $hospitalizedCount patients hospitalisés nécessitent une surveillance particulière.";

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        children: [
          // ── Greeting & Weather Row ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subGreeting,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('26°C', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        Text('Djerba', style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Date pill ───────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 7),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── 3 KPI Metric Cards ───────────────────────
          Row(
            children: [
              Expanded(
                child: _buildBriefingCard(
                  icon: Icons.favorite_rounded,
                  iconBg: AppTheme.tropicalTeal.withValues(alpha: 0.12),
                  iconColor: AppTheme.tropicalTeal,
                  count: '$consultationsCount',
                  label: 'Constantes',
                  onTap: () => setState(() => _currentTab = 2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBriefingCard(
                  icon: Icons.hotel_rounded,
                  iconBg: AppTheme.oceanMist.withValues(alpha: 0.12),
                  iconColor: AppTheme.oceanMist,
                  count: '$hospitalizedCount',
                  label: 'Hospitalisés',
                  onTap: () => setState(() => _currentTab = 3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBriefingCard(
                  icon: Icons.science_rounded,
                  iconBg: AppTheme.bondiBlue.withValues(alpha: 0.12),
                  iconColor: AppTheme.bondiBlue,
                  count: '$pendingExamsCount',
                  label: 'Examens',
                  onTap: _showPendingExamsModal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Résumé de la journée (IA Card) ──────────────────────
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BriefingDetailScreen(
                  briefingData: dailyBriefing,
                  onRefresh: _loadData,
                  showSmartSummary: true,
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16252C) : const Color(0xFFF0FDF9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.tropicalTeal.withValues(alpha: isDark ? 0.35 : 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.tropicalTeal.withValues(alpha: isDark ? 0.15 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.tropicalTeal, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Résumé IA & Conseils Soignants',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F3E48),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.tropicalTeal,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'IA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.tropicalTeal, size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    aiSummaryPreview,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Prochain rendez-vous Card ───────────────────────────
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NurseCareCalendarScreen())),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.tropicalTeal.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.schedule_rounded, color: AppTheme.tropicalTeal, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Prochain soin programmé',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.tropicalTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '09:00',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.tropicalTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Administration traitement & constantes - Chambre 407',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Surveillance post-opératoire et prise des constantes vitales',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ── Button: Voir le planning complet ────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NurseCareCalendarScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.tropicalTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Voir le planning des soins',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          const SizedBox(height: 20),

          // Actions rapides
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.speed,
                  label: 'Prendre Constantes',
                  color: const Color(0xFF0D9488),
                  onTap: _showNewVitalSignModal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  icon: Icons.notification_important,
                  label: '🔴 Créer Alerte',
                  color: const Color(0xFFDC2626),
                  onTap: () => _showCreateAlertModal(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBriefingCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 116,
        padding: const EdgeInsets.all(14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColor(context),
                    height: 1.1,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
              ],
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- ONGLET 1 : Patients & Dossiers ---
  Widget _buildPatientsTab() {
    final isDark = AppTheme.isDarkMode(context);
    final filtered = patients.where((p) {
      if (_selectedDepartmentFilter != 'ALL') {
        final dept = (p['department'] ?? '').toString().toUpperCase();
        if (_selectedDepartmentFilter == 'MATERNITE' && !dept.contains('MATERNIT') && !dept.contains('OBSTETRIQU')) return false;
        if (_selectedDepartmentFilter == 'CARDIOLOGIE' && !dept.contains('CARDIO')) return false;
        if (_selectedDepartmentFilter == 'CHIRURGIE' && !dept.contains('CHIRURG') && !dept.contains('HOSPIT')) return false;
      }
      final name = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.toLowerCase();
      final cin = (p['cin'] ?? '').toString().toLowerCase();
      final dossier = (p['dossierNumber'] ?? '').toString().toLowerCase();
      final q = patientSearchQuery.toLowerCase();
      return name.contains(q) || cin.contains(q) || dossier.contains(q);
    }).toList();

    filtered.sort((a, b) {
      final nameA = '${a['firstName'] ?? ''} ${a['lastName'] ?? ''}'.toLowerCase();
      final nameB = '${b['firstName'] ?? ''} ${b['lastName'] ?? ''}'.toLowerCase();
      return nameA.compareTo(nameB);
    });

    return Column(
      children: [
        // Barre de recherche Figma style
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
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF059669), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (val) => setState(() => patientSearchQuery = val),
            ),
          ),
        ),

        // Filtre par service / spécialité
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _nurseFilterChip('Tous les pôles', 'ALL', Icons.domain),
              const SizedBox(width: 8),
              _nurseFilterChip('🌸 Pôle Mère-Enfant & Maternité', 'MATERNITE', Icons.pregnant_woman),
              const SizedBox(width: 8),
              _nurseFilterChip('❤️ Cardiologie', 'CARDIOLOGIE', Icons.favorite),
              const SizedBox(width: 8),
              _nurseFilterChip('🏥 Chirurgie & Hospit.', 'CHIRURGIE', Icons.local_hospital),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: filtered.isEmpty
                ? const Center(child: Text('Aucun patient trouvé dans ce service'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final p = filtered[idx];
                      final name = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim();
                      final cin = p['cin'] ?? '-';
                      final dossier = p['dossierNumber'] ?? 'PAT-000';
                      final blood = p['bloodType'] ?? 'Inconnu';
                      final allergies = p['allergies'] ?? '';
                      final dept = p['department'] ?? 'Soins Généraux';

                      // Équipe soignante
                      final doc = p['attendingDoctorId'];
                      final docName = doc is Map
                          ? 'Dr. ${doc['firstName'] ?? ''} ${doc['lastName'] ?? ''}'.trim()
                          : null;
                      final midwife = p['assignedMidwifeId'];
                      final midwifeName = midwife is Map
                          ? '${midwife['firstName'] ?? ''} ${midwife['lastName'] ?? ''}'.trim()
                          : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _openPatientDossier(p),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      AvatarWidget(avatarUrl: p['avatarUrl'], name: name, radius: 22),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: AppTheme.textColor(context),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'CIN: $cin  •  Groupe: $blood',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          dossier,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Tags Service & Équipe pluridisciplinaire
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: dept.toString().contains('Matern') ? const Color(0xFFFDF2F8) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: dept.toString().contains('Matern') ? const Color(0xFFFBCFE8) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Text(
                                          dept,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: dept.toString().contains('Matern') ? const Color(0xFFDB2777) : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                      if (docName != null && docName.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFBFDBFE)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.person_pin, size: 12, color: Color(0xFF2563EB)),
                                              const SizedBox(width: 4),
                                              Text(
                                                docName,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (midwifeName != null && midwifeName.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFDF4FF),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFF0ABFC)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.favorite, size: 12, color: Color(0xFFC026D3)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'SF: $midwifeName',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9333EA)),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (allergies.isNotEmpty && allergies.toLowerCase() != 'aucune')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text('⚠️ Allergies: $allergies', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _nurseFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedDepartmentFilter == value;
    final isDark = AppTheme.isDarkMode(context);
    return InkWell(
      onTap: () => setState(() => _selectedDepartmentFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF059669)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF059669)
                : AppTheme.borderColor(context),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF059669).withValues(alpha: 0.25),
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
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nurse_vitals_fab',
        backgroundColor: const Color(0xFF0D9488),
        onPressed: _showNewVitalSignModal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Saisie Constantes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: vitalSigns.isEmpty
            ? const Center(child: Text('Aucune constante enregistrée'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vitalSigns.length,
                itemBuilder: (context, idx) => _vitalSignCard(vitalSigns[idx]),
              ),
      ),
    );
  }

  Widget _buildBedsTab() {
    return RoomsAndBedsView(
      onRefreshParent: _loadData,
    );
  }

  Widget _vitalSignCard(Map<String, dynamic> v) {
    final isDark = AppTheme.isDarkMode(context);
    final isFever = (v['temperature'] ?? 0) >= 38.5;
    final isHypox = (v['oxygenSaturation'] ?? 100) < 94;
    final isAbnormal = isFever || isHypox;

    // Récupération dynamique du patient
    Map<String, dynamic>? patObj;
    final rawPat = v['patientId'] ?? v['patient'];
    if (rawPat is Map<String, dynamic>) {
      patObj = rawPat;
    } else if (rawPat is Map) {
      patObj = Map<String, dynamic>.from(rawPat);
    } else if (rawPat != null && patients.isNotEmpty) {
      final rawStr = rawPat.toString();
      final found = patients.firstWhere(
        (p) => p['_id']?.toString() == rawStr || p['id']?.toString() == rawStr,
        orElse: () => null,
      );
      if (found is Map) {
        patObj = Map<String, dynamic>.from(found);
      }
    }

    final patName = patObj != null
        ? '${patObj['firstName'] ?? ''} ${patObj['lastName'] ?? ''}'.trim()
        : 'Patient Inconnu';
    final dossierNum = patObj?['dossierNumber'] ?? patObj?['cin'];

    // Formatage de la date
    final recAt = v['recordedAt']?.toString() ?? v['createdAt']?.toString();
    final dateStr = recAt != null ? _formatDate(recAt) : '';

    final id = v['_id']?.toString() ?? '';
    return Dismissible(
      key: Key('vital_$id'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.delete_forever, color: Color(0xFFDC2626), size: 26),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Supprimer la constante ?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Text(
              'Voulez-vous vraiment supprimer la constante enregistrée pour $patName ?\nCette action est irréversible.',
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
      },
      onDismissed: (_) {
        if (id.isNotEmpty) {
          setState(() {
            _deletedVitalIds.add(id);
            vitalSigns.removeWhere((item) => item['_id']?.toString() == id || item['id']?.toString() == id);
          });
          api.deleteVitalSign(id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Color(0xFF1E293B),
                content: Text('🗑️ Constante supprimée avec succès.'),
              ),
            );
          }
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_forever, color: Colors.white, size: 24),
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
          color: isAbnormal
              ? (isDark ? const Color(0xFF451A1A) : const Color(0xFFFFF1F2))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAbnormal
                ? const Color(0xFFFECDD3)
                : AppTheme.borderColor(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: patObj != null ? () => _openPatientDossier(patObj!) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // En-tête : Nom du patient + Numéro Dossier + Anomalie / Date
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isAbnormal ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
                    child: Icon(
                      Icons.person,
                      size: 20,
                      color: isAbnormal ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patName.isNotEmpty ? patName : 'Patient Inconnu',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (dossierNum != null && dossierNum.toString().isNotEmpty)
                          Text(
                            'N° Dossier : $dossierNum',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isAbnormal)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ANOMALIE',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 18, thickness: 1, color: Color(0xFFF1F5F9)),
              // Métriques des constantes vitales
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _vitalMetricChip(
                    label: 'T°',
                    value: '${v['temperature'] ?? '-'} °C',
                    isAlert: isFever,
                    icon: Icons.thermostat,
                  ),
                  _vitalMetricChip(
                    label: 'Pouls',
                    value: '${v['heartRate'] ?? '-'} bpm',
                    isAlert: false,
                    icon: Icons.favorite,
                  ),
                  _vitalMetricChip(
                    label: 'TA',
                    value: '${v['bloodPressureSystolic'] ?? '-'}/${v['bloodPressureDiastolic'] ?? '-'}',
                    isAlert: false,
                    icon: Icons.speed,
                  ),
                  _vitalMetricChip(
                    label: 'SpO2',
                    value: '${v['oxygenSaturation'] ?? '-'}%',
                    isAlert: isHypox,
                    icon: Icons.air,
                  ),
                ],
              ),
              if (v['notes'] != null && (v['notes'] as String).isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Obs. : ${v['notes']}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
}


  Widget _vitalMetricChip({
    required String label,
    required String value,
    required bool isAlert,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isAlert ? Colors.red : const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: isAlert ? Colors.red[800] : const Color(0xFF64748B))),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isAlert ? Colors.red[900] : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
