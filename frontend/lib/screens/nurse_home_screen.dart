import '../utils/app_logger.dart';

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/theme.dart';
import '../utils/briefing_utils.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/dark_ambient_background.dart';
import '../widgets/figma_header.dart';
import '../widgets/ios_bottom_nav_bar.dart';
import '../widgets/rooms_and_beds_view.dart';
import 'briefing_detail_screen.dart';
import 'ai_briefing_screen.dart';
import 'nurse_care_calendar_screen.dart';
import 'patient_dossier_screen.dart';
import 'profile_screen.dart';
import '../utils/default_patients.dart';
import '../widgets/patient_worklist_card.dart';
import '../widgets/unified_vital_signs_modal.dart';
import 'calendar/clinical_calendar_screen.dart';

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

  List<dynamic> patients = DefaultPatients.getAll();
  List<dynamic> vitalSigns = ApiService().getDefaultVitalSigns();
  List<dynamic> beds = [];
  List<dynamic> alerts = [];
  List<dynamic> doctors = [];
  Map<String, dynamic> dailyBriefing = {};
  final Set<String> _readAlertIds = {};
  final Set<String> _deletedVitalIds = {};
  bool isLoading = true;
  String patientSearchQuery = '';
  String _selectedDepartmentFilter = 'ALL';
  String _vitalsFilter = 'ALL';
  String _vitalsSearch = '';

  Timer? _realtimeTimer;

  int get unreadAlertCount => alerts.where((a) {
    final id = a['_id']?.toString();
    return id != null && !_readAlertIds.contains(id);
  }).length;

  @override
  void initState() {
    super.initState();
    _selectedDepartmentFilter = 'ALL';
    patientSearchQuery = '';
    AppLogger.logInterface(
      'Espace Infirmier(e) - Soins & Constantes',
      fileName: 'nurse_home_screen.dart',
      details: 'Initialisation espace soignant',
    );
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
            backgroundColor: AppTheme.evergreen,
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
            backgroundColor: AppTheme.evergreen,
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
          patients = patRes.isNotEmpty ? patRes : DefaultPatients.getAll();
          vitalSigns = cleanVitals.isNotEmpty ? cleanVitals : api.getDefaultVitalSigns();
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
          if (patients.isEmpty) {
            patients = DefaultPatients.getAll();
          }
          if (vitalSigns.isEmpty) {
            vitalSigns = api.getDefaultVitalSigns();
          }
          dailyBriefing = _getDefaultBriefingData();
          isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _getDefaultBriefingData() {
    final user = api.currentUser;
    final name = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();
    final displayName = name.isNotEmpty ? name : 'Infirmière Amira';
    return {
      'date': 'Lundi 26 mai 2025',
      'rawDate': '2025-05-26',
      'greeting': 'Bonjour, $displayName',
      'subGreeting': 'Voici votre briefing soins du jour',
      'serviceName': user?['service'] ?? 'Service Soins Infirmiers',
      'weather': {'temp': '26°C', 'city': 'Djerba', 'condition': 'Ensoleillé'},
      'metrics': {
        'consultationsCount': 4,
        'urgentConsultationsCount': 1,
        'hospitalizedCount':
            patients
                    .where((p) => p['isHospitalized'] == true || p['status'] == 'HOSPITALIZED')
                    .length >
                0
            ? patients
                  .where((p) => p['isHospitalized'] == true || p['status'] == 'HOSPITALIZED')
                  .length
            : 5,
        'toMonitorHospitalizedCount': 2,
        'pendingExamsCount': 2,
        'tasksCount': alerts.isNotEmpty ? alerts.length : 3,
        'urgentTasksCount': 1,
      },
      'nextAppointment': {
        'time': '08:30',
        'title': 'Prise de constantes & Traitements',
        'room': 'Chambre 201',
        'doctor': 'Soignante',
        'patientName': 'Mourad Ben Ali',
      },
      'aiSummary':
          "Bonjour $displayName. Tournée de soins planifiée pour 5 patients en hospitalisation. 2 constantes nécessitent une réévaluation matinale (T° & SpO2).",
      'aiSummaryPreview': "Tournée de soins planifiée pour 5 patients. Prise de constantes prioritaire en Chambre 201.",
      'consultationsList': [],
      'hospitalizedList': [
        {
          'room': 'Chambre 201 (Lit 1)',
          'service': 'Soins Infirmiers',
          'status': 'À surveiller',
          'patientName': 'Mourad Ben Ali',
        },
      ],
      'pendingExamsList': [],
      'tasksList': [
        {
          'id': 't1',
          'title': 'Prise de constantes matinales',
          'location': 'Chambre 201',
          'time': '08:30',
          'isCompleted': false,
          'isPriority': true,
        },
      ],
    };
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

  void _openPatientDossier(Map<String, dynamic> patient) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PatientDossierScreen(patient: patient)),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppTheme.dustGrey,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active, color: AppTheme.alertRed),
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
                        foregroundColor: AppTheme.evergreen,
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
                            Icon(Icons.check_circle_outline, size: 48, color: AppTheme.evergreen),
                            SizedBox(height: 8),
                            Text(
                              'Aucune alerte active',
                              style: TextStyle(
                                color: Color(0xFF6B7E72),
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

                          final targetDoctor = alert['targetDoctorId'];
                          final createdBy = alert['createdBy'];
                          final creatorName = createdBy is Map
                              ? '${createdBy['role'] == 'NURSE'
                                        ? 'Inf. '
                                        : createdBy['role'] == 'DOCTOR'
                                        ? 'Dr. '
                                        : ''}${createdBy['firstName'] ?? ''} ${createdBy['lastName'] ?? ''}'
                                    .trim()
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isCritical ? AppTheme.background : AppTheme.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isCritical ? AppTheme.dustGrey : AppTheme.dustGrey,
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
                                            color: isCritical
                                                ? AppTheme.alertRed
                                                : AppTheme.darkBackground,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isCritical
                                                  ? AppTheme.alertRed
                                                  : AppTheme.evergreen,
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
                                          if (alert['createdAt'] != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDate(alert['createdAt']),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF6B7E72),
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
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.darkElevated,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (targetDoctor is Map)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.background,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.dustGrey),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.person_pin,
                                                size: 14,
                                                color: AppTheme.evergreen,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Transmis à : Dr. ${targetDoctor['firstName'] ?? ''} ${targetDoctor['lastName'] ?? ''}'
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.background,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.groups_outlined,
                                                size: 14,
                                                color: Color(0xFF6B7E72),
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Destinataire : Tous les médecins',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF6B7E72),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (creatorName != null && creatorName.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.background,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.dustGrey),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.send_rounded,
                                                size: 12,
                                                color: Color(0xFF6B7E72),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Émis par : $creatorName',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF6B7E72),
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
                                      if (patient is Map)
                                        TextButton.icon(
                                          icon: const Icon(Icons.folder_shared, size: 15),
                                          label: Text(
                                            'Dossier: $patName',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _openPatientDossier(patient as Map<String, dynamic>);
                                          },
                                        ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.evergreen,
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
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        onPressed: () async {
                                          await _handleResolveAlert(
                                            alert['_id']?.toString() ?? '',
                                            patName,
                                          );
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: AppTheme.dustGrey,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.science_rounded, color: AppTheme.evergreen),
                    const SizedBox(width: 8),
                    Text(
                      'Examens en attente (${pendingExams.length})',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            Expanded(
              child: pendingExams.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: AppTheme.evergreen),
                          SizedBox(height: 8),
                          Text(
                            'Aucun examen en attente',
                            style: TextStyle(color: Color(0xFF6B7E72), fontWeight: FontWeight.w600),
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
                        final isCompleted =
                            status.toString().toLowerCase().contains('compl') ||
                            status.toString().toLowerCase().contains('termin');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: AppTheme.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppTheme.dustGrey),
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
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 12,
                                            color: AppTheme.drySage,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            dept,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6B7E72),
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
                                    color: isCompleted
                                        ? AppTheme.evergreen.withValues(alpha: 0.1)
                                        : const Color(0xFF0284C7).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isCompleted
                                          ? AppTheme.evergreen
                                          : const Color(0xFF0284C7),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Aucun patient disponible')));
      return;
    }

    String selectedPatientId = preselectedPatientId ?? patients.first['_id'];
    // Détecter l'équipe de soin du patient sélectionné
    final selPatient = patients.firstWhere(
      (p) => p['_id'] == selectedPatientId,
      orElse: () => null,
    );
    String? selectedDoctorUserId;
    if (selPatient != null && selPatient['attendingDoctorId'] != null) {
      final doc = selPatient['attendingDoctorId'];
      if (doc is Map) {
        selectedDoctorUserId = (doc['userId'] is Map ? doc['userId']['_id'] : doc['_id'])
            ?.toString();
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
          final currentPat = patients.firstWhere(
            (p) => p['_id'] == selectedPatientId,
            orElse: () => null,
          );
          final currentDoc = currentPat?['attendingDoctorId'];
          final currentDocName = currentDoc is Map
              ? 'Dr. ${currentDoc['firstName'] ?? ''} ${currentDoc['lastName'] ?? ''}'.trim()
              : null;
          final currentMidwife = currentPat?['assignedMidwifeId'];
          final currentMidwifeName = currentMidwife is Map
              ? '${currentMidwife['firstName'] ?? ''} ${currentMidwife['lastName'] ?? ''}'.trim()
              : null;

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
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.dustGrey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(Icons.warning_rounded, color: AppTheme.alertRed, size: 24),
                      SizedBox(width: 8),
                      Text(
                        '🔴 Déclencher une Alerte Médicale',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.alertRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Transmettez immédiatement l\'alerte au médecin traitant ou à l\'équipe de garde.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7E72)),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: selectedPatientId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Patient concerné *',
                      border: OutlineInputBorder(),
                    ),
                    items: patients.map<DropdownMenuItem<String>>((p) {
                      return DropdownMenuItem<String>(
                        value: p['_id'],
                        child: Text(
                          '${p['firstName']} ${p['lastName']} (${p['dossierNumber'] ?? p['cin']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedPatientId = val;
                          final newPat = patients.firstWhere(
                            (p) => p['_id'] == val,
                            orElse: () => null,
                          );
                          if (newPat != null && newPat['attendingDoctorId'] != null) {
                            final doc = newPat['attendingDoctorId'];
                            if (doc is Map) {
                              selectedDoctorUserId =
                                  (doc['userId'] is Map ? doc['userId']['_id'] : doc['_id'])
                                      ?.toString();
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
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.dustGrey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '👥 Équipe en charge de ce patient :',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.evergreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (currentDocName != null)
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.person,
                                    size: 14,
                                    color: AppTheme.evergreen,
                                  ),
                                  label: Text(
                                    'Médecin : $currentDocName',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: Colors.white,
                                  onPressed: () {
                                    final doc = currentPat['attendingDoctorId'];
                                    if (doc is Map) {
                                      setModalState(() {
                                        selectedDoctorUserId =
                                            (doc['userId'] is Map
                                                    ? doc['userId']['_id']
                                                    : doc['_id'])
                                                ?.toString();
                                      });
                                    }
                                  },
                                ),
                              if (currentMidwifeName != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDF4FF),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFF0ABFC)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.favorite,
                                        size: 13,
                                        color: Color(0xFFC026D3),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Sage-Femme : $currentMidwifeName',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.evergreen,
                                        ),
                                      ),
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
                      prefixIcon: Icon(Icons.person_pin, color: AppTheme.evergreen),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          '📢 Tous les médecins de garde (Diffusion générale)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.evergreen,
                          ),
                        ),
                      ),
                      ...doctors.map<DropdownMenuItem<String?>>((d) {
                        final u = d['userId'];
                        final docUserId = (u != null && u['_id'] != null)
                            ? u['_id'].toString()
                            : d['_id'].toString();
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
                    decoration: const InputDecoration(
                      labelText: 'Type d\'alerte *',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        [
                              'Constantes vitales anormales',
                              'Pic fébrile élevé (> 38.5°C)',
                              'Désaturation en oxygène (< 92%)',
                              'Douleur aiguë sévère non soulagée',
                              'Dégradation de l\'état hémodynamique',
                              'Complication obstétricale / Maternité',
                              'Autre urgence soignante',
                            ]
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t, style: const TextStyle(fontSize: 13)),
                              ),
                            )
                            .toList(),
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
                      const Text(
                        'Niveau d\'urgence : ',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      ChoiceChip(
                        label: const Text('⚠️ Urgent'),
                        selected: priority == 'URGENT',
                        selectedColor: const Color(0xFFEDF2EA),
                        onSelected: (s) => setModalState(() => priority = 'URGENT'),
                      ),
                      ChoiceChip(
                        label: const Text('🚨 Critique'),
                        selected: priority == 'CRITICAL',
                        selectedColor: AppTheme.dustGrey,
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
                      hintText:
                          'Ex: Température 39.1°C, patient frissonnant, tachycarde à 110 bpm...',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.alertRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text(
                        'Transmettre l\'alerte au Médecin',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
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
                                backgroundColor: AppTheme.alertRed,
                                content: Text(
                                  '✅ Alerte médicale transmise avec succès au médecin traitant !',
                                ),
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.alertRed,
                                content: Text(
                                  'Erreur: ${res['data']?['message'] ?? 'Échec lors de la création de l\'alerte'}',
                                ),
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
    UnifiedVitalSignsModal.show(
      context,
      preselectedPatientId: preselectedPatientId,
      patientsList: patients,
      onSuccess: () {
        _loadData();
      },
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

  Widget? _buildNurseFab() {
    switch (_currentTab) {
      case 1:
        return _buildMediumFab(
          heroTag: 'nurse_fab_1',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showNewVitalSignModal,
          icon: Icons.favorite_rounded,
          label: 'Saisir Constantes',
        );
      case 2:
        return _buildMediumFab(
          heroTag: 'nurse_fab_2',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showNewVitalSignModal,
          icon: Icons.favorite,
          label: 'Saisir Constantes',
        );
      case 3:
        return _buildMediumFab(
          heroTag: 'nurse_fab_3',
          backgroundColor: AppTheme.alertRed,
          onPressed: () => _showCreateAlertModal(),
          icon: Icons.warning_amber_rounded,
          label: 'Déclencher Alerte',
        );
      case 0:
      default:
        return _buildMediumFab(
          heroTag: 'nurse_fab_0',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showNewVitalSignModal,
          icon: Icons.favorite,
          label: 'Saisir Constantes',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = api.currentUser;
    final fullName = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();
    final displayName = fullName.isEmpty ? 'Mme. Infirmier(e)' : fullName;
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      key: _scaffoldKey,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _buildNurseFab(),
      drawer: AppDrawer(
        onSelectTab: (idx) => setState(() => _currentTab = idx),
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      body: Column(
        children: [
          FigmaHeader(
            roleName: 'INFIRMIER',
            roleColor: AppTheme.getRoleColor('NURSE'),
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            onThemeToggle: AppTheme.toggleTheme,
            onNotificationsPressed: _showAlertsModal,
            onCalendarPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClinicalCalendarScreen(onLogout: widget.onLogout),
                ),
              );
            },
            unreadNotifications: unreadAlertCount,
            profileImageUrl: user?['avatarUrl'],
            userName: fullName,
            onProfilePressed: _openProfile,
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _loadData();
                },
                child: _buildCurrentTabContent(context, displayName, isDark),
              ),
            ),
        ],
      ),
      bottomNavigationBar: IosBottomNavBar(
        selectedIndex: _currentTab,
        onItemSelected: (idx) => setState(() => _currentTab = idx),
        activeColor: AppTheme.primary,
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
            icon: CupertinoIcons.heart_circle,
            selectedIcon: CupertinoIcons.heart_circle_fill,
            label: 'Surveillance',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.bed_double,
            selectedIcon: CupertinoIcons.bed_double_fill,
            label: 'Chambres',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTabContent(BuildContext context, String displayName, bool isDark) {
    switch (_currentTab) {
      case 1:
        return _buildPatientsTab();
      case 2:
        return _buildSurveillanceTab(isDark);
      case 3:
        return _buildChambresTab(isDark);
      case 0:
      default:
        return _buildDashboardTab(displayName, isDark);
    }
  }

  Widget _buildDashboardTab(String displayName, bool isDark) {
    final hospitalized = patients
        .where((p) => p['hospitalStay'] != null && p['hospitalStay']['status'] == 'ACTIVE')
        .toList();
    final alertsCount = unreadAlertCount;
    final pendingVitals = vitalSigns.where((v) => v['status'] == 'PENDING').length;

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
      fallback: 'Aucune donnée de synthèse disponible pour le moment.',
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
                  AiBriefingScreen(briefingData: dailyBriefing, onBriefingUpdated: _loadData),
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
                  'Synthèse Soins & Surveillance',
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
                        '+${hospitalized.length} patients hospitalisés',
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
                            Icons.hotel_rounded,
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
                              'Actif',
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
                      '${hospitalized.length}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Hospitalisés',
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
                            color: AppTheme.alertRed.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emergency_rounded,
                            size: 15,
                            color: AppTheme.alertRed,
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.alertRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'Urgent',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.alertRed,
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Constantes Urg.',
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
                            Icons.healing_rounded,
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
                              'Attente',
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
                      '$pendingVitals',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Soins à faire',
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

        // ── Urgences & Alertes Vitales Card ──────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                      color: AppTheme.alertRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Urgences & Alertes Vitales',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.alertRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${alerts.isNotEmpty ? alerts.length : 1} Critique',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.alertRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (alerts.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.alertRed.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _getAlertInitials(alerts.first),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.alertRed,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _getAlertPatientName(alerts.first),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• ${alerts.first['level'] ?? 'URGENT'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alerts.first['title'] ?? 'Alerte médicale',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
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
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          alerts.first['description'] ?? 'Constantes anormales détectées',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB91C1C),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text(
                        '5 min',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.evergreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'AK',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.evergreen,
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
                                'M. Amine K.',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '• Chambre 3',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            '48 ans • Arrivé il y a 25 min',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                          'Alerte Température critique: 39.5°C',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                      Text(
                        '5 min',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: _showAlertsModal,
                        icon: const Icon(
                          Icons.notifications_active_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Voir les alertes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: () {
                        if (patients.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PatientDossierScreen(patient: patients.first),
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      child: const Text(
                        'Dossier',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getAlertInitials(Map<String, dynamic> alert) {
    final patient = alert['patientId'];
    if (patient is Map) {
      final fn = (patient['firstName'] ?? '').toString();
      final ln = (patient['lastName'] ?? '').toString();
      return '${fn.isNotEmpty ? fn[0] : ''}${ln.isNotEmpty ? ln[0] : ''}'.toUpperCase();
    }
    return 'AK';
  }

  String _getAlertPatientName(Map<String, dynamic> alert) {
    final patient = alert['patientId'];
    if (patient is Map) {
      return '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim();
    }
    return 'Patient';
  }

  Widget _buildTaskCard(bool isDark, String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textColor(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.square, color: color.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildStatCard(bool isDark, String title, String value, Color color, String icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.subtextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChambresTab(bool isDark) {
    final hospitalized = patients
        .where((p) => p['hospitalStay'] != null && p['hospitalStay']['status'] == 'ACTIVE')
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Toutes mes chambres',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor(context),
          ),
        ),
        const SizedBox(height: 16),
        ...hospitalized.map((p) => _buildRoomCard(p, isDark)),
      ],
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> patient, bool isDark) {
    final pfn = patient['firstName'] ?? '';
    final pln = patient['lastName'] ?? '';
    final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : 'Patient';
    final stay = patient['hospitalStay'];
    final room = stay != null && stay['room'] != null
        ? 'Chambre ${stay['room']['roomNumber'] ?? ''}'
        : 'Chambre Inconnue';
    final bed = stay != null && stay['bed'] != null ? 'Lit: ${stay['bed']['bedNumber'] ?? ''}' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      elevation: 0,
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: InkWell(
        onTap: () => _showNursePatientDetails(patient),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    room,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primary,
                    ),
                  ),
                  if (bed.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        bed,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                    foregroundColor: AppTheme.primary,
                    child: const Icon(Icons.person),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.circle, size: 10, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              'Stable',
                              style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSurveillanceTab(bool isDark) {
    // 1. Calculate metrics
    final totalCount = vitalSigns.length;
    final abnormalVitals = vitalSigns.where((v) {
      final hr = v['heartRate'];
      final sys = v['bloodPressureSystolic'];
      final dia = v['bloodPressureDiastolic'];
      final temp = v['temperature'];
      final spo2 = v['oxygenSaturation'];
      return (hr != null && (hr < 60 || hr > 100)) ||
          (sys != null && sys >= 140) ||
          (dia != null && dia >= 90) ||
          (temp != null && temp >= 38.0) ||
          (spo2 != null && spo2 < 95);
    }).toList();
    final abnormalCount = abnormalVitals.length;
    final normalCount = totalCount - abnormalCount;

    // 2. Filter vitals
    final filtered = vitalSigns.where((v) {
      final pat = v['patientId'];
      final patName = (pat is Map ? '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}' : '')
          .toLowerCase();
      final patCin = (pat is Map ? (pat['cin'] ?? '') : '').toLowerCase();
      final patDossier = (pat is Map ? (pat['dossierNumber'] ?? '') : '').toLowerCase();
      final dept = (pat is Map ? (pat['department'] ?? '') : '').toLowerCase();

      final matchesSearch =
          _vitalsSearch.isEmpty ||
          patName.contains(_vitalsSearch.toLowerCase()) ||
          patCin.contains(_vitalsSearch.toLowerCase()) ||
          patDossier.contains(_vitalsSearch.toLowerCase());
      if (!matchesSearch) return false;

      if (_vitalsFilter == 'ALERTS') {
        final hr = v['heartRate'];
        final sys = v['bloodPressureSystolic'];
        final dia = v['bloodPressureDiastolic'];
        final temp = v['temperature'];
        final spo2 = v['oxygenSaturation'];
        return (hr != null && (hr < 60 || hr > 100)) ||
            (sys != null && sys >= 140) ||
            (dia != null && dia >= 90) ||
            (temp != null && temp >= 38.0) ||
            (spo2 != null && spo2 < 95);
      } else if (_vitalsFilter == 'CHIRURGIE') {
        return dept.contains('chirurgie') || dept.contains('hospit');
      } else if (_vitalsFilter == 'MATERNITE') {
        return dept.contains('maternité') || dept.contains('obstétr');
      } else if (_vitalsFilter == 'CARDIOLOGIE') {
        return dept.contains('cardio') || dept.contains('vascul');
      } else if (_vitalsFilter == 'PEDIATRIE') {
        return dept.contains('pédiatr') || dept.contains('néonat');
      } else if (_vitalsFilter == 'PMA') {
        return dept.contains('pma') || dept.contains('gynéco');
      }
      return true;
    }).toList();

    return Column(
      children: [
        // ── En-tête avec bouton Saisie ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Surveillance des Constantes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Relevés cliniques & suivi physiologique en temps réel',
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.evergreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Saisir Relevé',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                onPressed: () => _showNewVitalSignModal(),
              ),
            ],
          ),
        ),

        // ── Bandeau KPI / Statistiques Cliniques ────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.monitor_heart_rounded,
                          size: 16,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$totalCount',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                          const Text(
                            'Relevés',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.evergreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppTheme.evergreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$normalCount',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.evergreen,
                            ),
                          ),
                          const Text(
                            'Normaux',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: abnormalCount > 0
                          ? AppTheme.alertRed.withValues(alpha: 0.3)
                          : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.alertRed.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_rounded,
                          size: 16,
                          color: AppTheme.alertRed,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$abnormalCount',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.alertRed,
                            ),
                          ),
                          const Text(
                            'Alertes',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Barre de Recherche & Filtres Rapides ────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: CupertinoSearchTextField(
            placeholder: 'Rechercher patient, dossier IPU, CIN...',
            style: TextStyle(fontSize: 13, color: AppTheme.textColor(context)),
            backgroundColor: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            onChanged: (val) => setState(() => _vitalsSearch = val),
          ),
        ),

        // ── Filtres Chips horizontaux ───────────────────────────────
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              _buildVitalsFilterChip(
                'Tous ($totalCount)',
                'ALL',
                Icons.all_inclusive_rounded,
                isDark,
              ),
              const SizedBox(width: 6),
              _buildVitalsFilterChip(
                '🚨 Alertes ($abnormalCount)',
                'ALERTS',
                Icons.warning_rounded,
                isDark,
              ),
              const SizedBox(width: 6),
              _buildVitalsFilterChip(
                '🏥 Chirurgie',
                'CHIRURGIE',
                Icons.local_hospital_rounded,
                isDark,
              ),
              const SizedBox(width: 6),
              _buildVitalsFilterChip(
                '🌸 Maternité',
                'MATERNITE',
                Icons.pregnant_woman_rounded,
                isDark,
              ),
              const SizedBox(width: 6),
              _buildVitalsFilterChip('❤️ Cardio', 'CARDIOLOGIE', Icons.favorite_rounded, isDark),
              const SizedBox(width: 6),
              _buildVitalsFilterChip('👶 Pédiatrie', 'PEDIATRIE', Icons.child_care_rounded, isDark),
              const SizedBox(width: 6),
              _buildVitalsFilterChip('🧬 PMA', 'PMA', Icons.biotech_rounded, isDark),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // ── Liste des Relevés Détaillés ─────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurface
                              : AppTheme.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.monitor_heart_outlined,
                          size: 48,
                          color: isDark ? AppTheme.drySage : AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun relevé correspondant',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _vitalsSearch.isNotEmpty || _vitalsFilter != 'ALL'
                            ? 'Modifiez vos filtres ou réinitialisez la recherche.'
                            : 'Commencez par saisir les constantes d\'un patient.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.subtextColor(context)),
                      ),
                      if (_vitalsFilter != 'ALL' || _vitalsSearch.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _vitalsFilter = 'ALL';
                            _vitalsSearch = '';
                          }),
                          icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                          label: const Text('Réinitialiser les filtres'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final v = filtered[idx];
                    final pat = v['patientId'];
                    final patName = pat is Map
                        ? '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim()
                        : 'Patient';
                    final patDossier = pat is Map
                        ? (pat['dossierNumber'] ?? 'PAT-2026')
                        : 'PAT-2026';
                    final patRoom = pat is Map
                        ? (pat['room'] ?? pat['department'] ?? 'Chambre')
                        : 'Chambre';
                    final patDept = pat is Map ? (pat['department'] ?? '') : '';

                    final sys = v['bloodPressureSystolic'];
                    final dia = v['bloodPressureDiastolic'];
                    final hr = v['heartRate'];
                    final temp = v['temperature'];
                    final spo2 = v['oxygenSaturation'];
                    final resp = v['respiratoryRate'] ?? 16;
                    final gly = v['bloodGlucose'] ?? 1.05;
                    final weight = v['weight'] ?? 74.0;
                    final height = v['height'];
                    final pain = v['painScale'] ?? 0;
                    final notes = v['notes'] ?? '';

                    final dateStr = v['recordedAt'] != null
                        ? _formatDate(v['recordedAt'])
                        : (v['createdAt'] != null ? _formatDate(v['createdAt']) : 'Aujourd\'hui');

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

                    return InkWell(
                      onTap: () => _showVitalSignDetails(v),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isAbnormal
                                ? AppTheme.alertRed.withValues(alpha: 0.35)
                                : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isAbnormal
                                  ? AppTheme.alertRed.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── En-tête Patient & Statut ─────────────────────
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isAbnormal
                                        ? AppTheme.alertRed.withValues(alpha: 0.1)
                                        : AppTheme.evergreen.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isAbnormal
                                          ? Icons.warning_rounded
                                          : Icons.monitor_heart_rounded,
                                      size: 20,
                                      color: isAbnormal ? AppTheme.alertRed : AppTheme.evergreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              patName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.5,
                                                color: AppTheme.textColor(context),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? AppTheme.darkElevated
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              patDossier,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$patRoom ${patDept.isNotEmpty ? '• $patDept' : ''}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.subtextColor(context),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: isAbnormal
                                        ? AppTheme.alertRed.withValues(alpha: 0.1)
                                        : AppTheme.evergreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    isAbnormal ? '⚠️ Alerte' : '✅ Normal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isAbnormal ? AppTheme.alertRed : AppTheme.evergreen,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // ── Métadonnées : Date & Signature soignante ───────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.badge_outlined,
                                      size: 13,
                                      color: AppTheme.evergreen,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      nurseName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.evergreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // ── Grille Complète des 8 Constantes Vitales ──────
                            // Ligne 1 : TA • FC • Température • SpO₂
                            Row(
                              children: [
                                if (sys != null && dia != null)
                                  Expanded(
                                    child: _buildMiniVital(
                                      isDark,
                                      '🩺 TA',
                                      '$sys/$dia',
                                      'mmHg',
                                      (sys >= 140 || dia >= 90)
                                          ? AppTheme.alertRed
                                          : const Color(0xFF7C3AED),
                                      subtitle: (sys >= 140 || dia >= 90) ? 'HTA' : 'Normale',
                                    ),
                                  ),
                                if (sys != null && dia != null) const SizedBox(width: 6),
                                if (hr != null)
                                  Expanded(
                                    child: _buildMiniVital(
                                      isDark,
                                      '❤️ Pouls',
                                      '$hr',
                                      'bpm',
                                      (hr < 60 || hr > 100)
                                          ? AppTheme.alertRed
                                          : const Color(0xFFE11D48),
                                      subtitle: (hr < 60)
                                          ? 'Brady'
                                          : (hr > 100 ? 'Tachy' : 'Régulier'),
                                    ),
                                  ),
                                if (hr != null) const SizedBox(width: 6),
                                if (temp != null)
                                  Expanded(
                                    child: _buildMiniVital(
                                      isDark,
                                      '🌡️ T°',
                                      temp is num ? temp.toStringAsFixed(1) : '$temp',
                                      '°C',
                                      (temp >= 38.0) ? AppTheme.alertRed : const Color(0xFF0D9488),
                                      subtitle: (temp >= 38.0) ? 'Fébrile' : 'Apyrétique',
                                    ),
                                  ),
                                if (temp != null) const SizedBox(width: 6),
                                if (spo2 != null)
                                  Expanded(
                                    child: _buildMiniVital(
                                      isDark,
                                      '🫁 SpO₂',
                                      '$spo2',
                                      '%',
                                      (spo2 < 95) ? AppTheme.alertRed : const Color(0xFF0284C7),
                                      subtitle: (spo2 < 95) ? 'Hypoxie' : 'Optimale',
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Ligne 2 : Fréq. Resp. • Glycémie • Poids • Douleur EVA
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMiniVital(
                                    isDark,
                                    '💨 FR',
                                    '$resp',
                                    'c/min',
                                    const Color(0xFF0891B2),
                                    subtitle: 'Eupnéique',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildMiniVital(
                                    isDark,
                                    '🩸 Glyc.',
                                    '$gly',
                                    'g/L',
                                    const Color(0xFFD97706),
                                    subtitle: 'Normo',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildMiniVital(
                                    isDark,
                                    '⚖️ Poids',
                                    '$weight',
                                    'kg',
                                    const Color(0xFF475569),
                                    subtitle: height != null ? '${height}cm' : 'IMC 23',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildMiniVital(
                                    isDark,
                                    '🧠 Douleur',
                                    'EVA $pain',
                                    '/10',
                                    pain >= 4 ? AppTheme.alertRed : AppTheme.evergreen,
                                    subtitle: pain == 0
                                        ? 'Nulle'
                                        : (pain <= 3 ? 'Faible' : 'Modérée'),
                                  ),
                                ),
                              ],
                            ),

                            // ── Notes et observations infirmières ─────────────
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
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.sticky_note_2_outlined,
                                      size: 15,
                                      color: AppTheme.evergreen,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        notes,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ── Pied de carte : Actions Rapides ────────────────
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showVitalSignDetails(v),
                                  icon: const Icon(
                                    Icons.description_outlined,
                                    size: 15,
                                    color: AppTheme.evergreen,
                                  ),
                                  label: const Text(
                                    'Fiche Complète',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.evergreen,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.evergreen),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 32),
                                  ),
                                ),
                                if (isAbnormal) ...[
                                  const SizedBox(width: 6),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      final patId = pat is Map ? pat['_id']?.toString() : null;
                                      _showCreateAlertModal(
                                        preselectedPatientId: patId,
                                        initialDescription:
                                            '⚠️ Constantes anormales détectées : TA ${sys ?? '-'}/${dia ?? '-'} mmHg, FC ${hr ?? '-'} bpm, T° ${temp is num ? temp.toStringAsFixed(1) : temp}°C, SpO₂ ${spo2 ?? '-'}%.',
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.notification_important_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Alerter Médecin',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.alertRed,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: const Size(0, 32),
                                    ),
                                  ),
                                ],
                                TextButton.icon(
                                  onPressed: () {
                                    if (pat is Map)
                                      _showNursePatientDetails(pat.cast<String, dynamic>());
                                  },
                                  icon: const Icon(
                                    Icons.folder_shared_outlined,
                                    size: 15,
                                    color: Color(0xFF64748B),
                                  ),
                                  label: const Text(
                                    'Dossier',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    minimumSize: const Size(0, 32),
                                  ),
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
    );
  }

  Widget _buildVitalsFilterChip(String label, String code, IconData icon, bool isDark) {
    final isSelected = _vitalsFilter == code;
    return GestureDetector(
      onTap: () => setState(() => _vitalsFilter = code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.evergreen
              : (isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected
                ? AppTheme.evergreen
                : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVitalSignDetails(Map<String, dynamic> v) {
    final isDark = AppTheme.isDarkMode(context);
    final pat = v['patientId'];
    final patName = pat is Map
        ? '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim()
        : 'Patient';
    final patCin = pat is Map ? (pat['cin'] ?? '') : '';
    final patDossier = pat is Map ? (pat['dossierNumber'] ?? 'PAT-2026') : 'PAT-2026';
    final patRoom = pat is Map ? (pat['room'] ?? pat['department'] ?? 'Chambre') : 'Chambre';
    final patDept = pat is Map ? (pat['department'] ?? '') : '';

    final sys = v['bloodPressureSystolic'];
    final dia = v['bloodPressureDiastolic'];
    final hr = v['heartRate'];
    final temp = v['temperature'];
    final spo2 = v['oxygenSaturation'];
    final resp = v['respiratoryRate'] ?? 16;
    final gly = v['bloodGlucose'] ?? 1.05;
    final weight = v['weight'] ?? 74.0;
    final height = v['height'] ?? 178;
    final pain = v['painScale'] ?? 0;
    final notes = v['notes'] ?? '';

    final dateStr = v['recordedAt'] != null
        ? _formatDate(v['recordedAt'])
        : (v['createdAt'] != null ? _formatDate(v['createdAt']) : 'Aujourd\'hui');

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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Header Fiche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isAbnormal
                          ? AppTheme.alertRed.withValues(alpha: 0.1)
                          : AppTheme.evergreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isAbnormal ? Icons.warning_rounded : Icons.monitor_heart_rounded,
                        color: isAbnormal ? AppTheme.alertRed : AppTheme.evergreen,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                        Text(
                          'IPU #$patDossier • CIN: $patCin • $patRoom',
                          style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Contenu Fiche Médicale
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Métadonnées
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkElevated : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date et heure de mesure',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Opérateur soignant',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nurseName,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.evergreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Relevé Paramétrique Détaillé (Normes de Référence)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 1. Pression Artérielle
                  _buildDetailedVitalRow(
                    isDark,
                    '🩺 Pression Artérielle (TA)',
                    '$sys/$dia',
                    'mmHg',
                    'Norme clinique : 100-139 / 60-89 mmHg',
                    (sys >= 140 || dia >= 90) ? 'Hypertension' : 'Normotension',
                    (sys >= 140 || dia >= 90) ? AppTheme.alertRed : AppTheme.evergreen,
                  ),
                  const SizedBox(height: 8),

                  // 2. Fréquence Cardiaque
                  _buildDetailedVitalRow(
                    isDark,
                    '❤️ Fréquence Cardiaque (Pouls)',
                    '$hr',
                    'bpm',
                    'Norme de repos : 60 - 100 battements/min',
                    (hr < 60) ? 'Bradycardie' : (hr > 100 ? 'Tachycardie' : 'Normocarde'),
                    (hr < 60 || hr > 100) ? AppTheme.alertRed : AppTheme.evergreen,
                  ),
                  const SizedBox(height: 8),

                  // 3. Température
                  _buildDetailedVitalRow(
                    isDark,
                    '🌡️ Température Corporelle',
                    temp is num ? temp.toStringAsFixed(1) : '$temp',
                    '°C',
                    'Normothermie : 36.5 - 37.5 °C',
                    (temp >= 38.0) ? 'Hyperthermie / Fièvre' : 'Apyrétique',
                    (temp >= 38.0) ? AppTheme.alertRed : AppTheme.evergreen,
                  ),
                  const SizedBox(height: 8),

                  // 4. SpO2
                  _buildDetailedVitalRow(
                    isDark,
                    '🫁 Saturation en Oxygène (SpO₂)',
                    '$spo2',
                    '%',
                    'Air ambiant : ≥ 95 % (Normal : 95-100%)',
                    (spo2 < 95) ? 'Désaturation / Hypoxie' : 'Oxygénation Optimale',
                    (spo2 < 95) ? AppTheme.alertRed : AppTheme.evergreen,
                  ),
                  const SizedBox(height: 8),

                  // 5. Fréquence Respiratoire
                  _buildDetailedVitalRow(
                    isDark,
                    '💨 Fréquence Respiratoire (FR)',
                    '$resp',
                    'cycles/min',
                    'Norme adulte au repos : 12 - 20 cycles/min',
                    'Eupnéique (rythme régulier)',
                    AppTheme.evergreen,
                  ),
                  const SizedBox(height: 8),

                  // 6. Glycémie
                  _buildDetailedVitalRow(
                    isDark,
                    '🩸 Glycémie Capillaire',
                    '$gly',
                    'g/L',
                    'Norme à jeun : 0.70 - 1.10 g/L',
                    'Normoglycémie',
                    AppTheme.evergreen,
                  ),
                  const SizedBox(height: 8),

                  // 7. Poids & Taille
                  _buildDetailedVitalRow(
                    isDark,
                    '⚖️ Anthropométrie (Poids / Taille)',
                    '$weight kg',
                    height != null ? '• $height cm' : '',
                    'IMC calculé : 23.4 kg/m² (Réf : 18.5 - 24.9)',
                    'Corpulence Normale',
                    AppTheme.evergreen,
                  ),
                  const SizedBox(height: 8),

                  // 8. Évaluation Douleur
                  _buildDetailedVitalRow(
                    isDark,
                    '🧠 Évaluation Douleur (Échelle EVA)',
                    'EVA $pain',
                    '/ 10',
                    'Échelle : 0 (Nulle), 1-3 (Légère), 4-6 (Modérée), 7-10 (Sévère)',
                    pain == 0
                        ? 'Absence de douleur'
                        : (pain <= 3
                              ? 'Douleur légère bien tolérée'
                              : 'Douleur modérée nécessitant antalgie'),
                    pain >= 4 ? AppTheme.alertRed : AppTheme.evergreen,
                  ),

                  // Notes cliniques
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Observations Infirmières & Soins',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevated : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        notes,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  // Actions de la fiche
                  Row(
                    children: [
                      if (isAbnormal) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.alertRed,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.notification_important_rounded, size: 18),
                            label: const Text(
                              'Alerter Médecin',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              final patId = pat is Map ? pat['_id']?.toString() : null;
                              _showCreateAlertModal(
                                preselectedPatientId: patId,
                                initialDescription:
                                    '⚠️ Constantes anormales détectées pour $patName : TA ${sys ?? '-'}/${dia ?? '-'} mmHg, FC ${hr ?? '-'} bpm, T° ${temp is num ? temp.toStringAsFixed(1) : temp}°C, SpO₂ ${spo2 ?? '-'}%.',
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.evergreen),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(
                            Icons.folder_shared_rounded,
                            color: AppTheme.evergreen,
                            size: 18,
                          ),
                          label: const Text(
                            'Dossier Patient',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.evergreen,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (pat is Map) _showNursePatientDetails(pat.cast<String, dynamic>());
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedVitalRow(
    bool isDark,
    String title,
    String value,
    String unit,
    String reference,
    String status,
    Color statusColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkElevated : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textColor(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: statusColor),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.subtextColor(context),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(reference, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  void _showNursePatientDetails(Map<String, dynamic> patient) {
    final pfn = patient['firstName'] ?? '';
    final pln = patient['lastName'] ?? '';
    final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : 'Patient';
    final patRegId = patient['registryId'] ?? 'D-Inconnu';
    final stay = patient['hospitalStay'];
    final room = stay != null && stay['room'] != null
        ? stay['room']['roomNumber']?.toString() ?? ''
        : 'N/A';
    final bed = stay != null && stay['bed'] != null
        ? stay['bed']['bedNumber']?.toString() ?? ''
        : 'N/A';
    final isDark = AppTheme.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: AppTheme.bottomSheetDecoration(context),
        child: Column(
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
            const SizedBox(height: 16),

            // PATIENT HEADER
            Text(
              'Patient',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade400,
              ),
            ),
            const Divider(),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                  foregroundColor: AppTheme.primary,
                  child: const Icon(Icons.person, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        'Dossier: $patRegId',
                        style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chambre: $room',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Lit: $bed',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SURVEILLANCE SECTION
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dernières constantes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade400,
                  ),
                ),
                const Text(
                  '08:42',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildMiniVital(
                    isDark,
                    '🌡 Température',
                    '37.2',
                    '°C',
                    const Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMiniVital(isDark, '❤️ FC', '86', 'bpm', const Color(0xFFE11D48)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildMiniVital(isDark, '🩺 Tension', '115/75', '', Colors.purple)),
                const SizedBox(width: 10),
                Expanded(child: _buildMiniVital(isDark, '🫁 SpO₂', '98', '%', Colors.blue)),
              ],
            ),

            const Spacer(),

            // ACTIONS
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.pastelOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_box),
                label: const Text(
                  'Enregistrer constantes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showNewVitalSignModal(preselectedPatientId: patient['_id']?.toString());
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.show_chart, size: 18),
                    label: const Text('Historique'),
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.warning, size: 18),
                    label: const Text('Alertes'),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniVital(
    bool isDark,
    String label,
    String value,
    String unit,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.textColor(context),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(unit, style: TextStyle(fontSize: 10, color: AppTheme.subtextColor(context))),
              ],
            ],
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- ONGLET : Patients & Dossiers (Même Style & UI que Médecin) ---
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
        // En-tête Dossiers Patients (Stitch Design - identique Médecin)
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
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: AppTheme.evergreen, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (val) => setState(() => patientSearchQuery = val),
            ),
          ),
        ),

        // Filtre par service / spécialité (Tous les pôles en premier - identique Médecin)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _nurseFilterChip('Tous les pôles', 'ALL', Icons.domain),
              const SizedBox(width: 8),
              _nurseFilterChip('🏥 Chirurgie & Hospit.', 'CHIRURGIE', Icons.local_hospital),
              const SizedBox(width: 8),
              _nurseFilterChip('🌸 Maternité & Obstétrique', 'MATERNITE', Icons.pregnant_woman),
              const SizedBox(width: 8),
              _nurseFilterChip('❤️ Cardiologie', 'CARDIOLOGIE', Icons.favorite),
              const SizedBox(width: 8),
              _nurseFilterChip('👶 Pédiatrie', 'PEDIATRIE', Icons.child_care),
              const SizedBox(width: 8),
              _nurseFilterChip('🧬 PMA & Gynéco.', 'PMA', Icons.biotech_rounded),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
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
                            fileName: 'nurse_home_screen.dart',
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

  Widget _nurseFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedDepartmentFilter == value;
    final isDark = AppTheme.isDarkMode(context);
    return InkWell(
      onTap: () {
        setState(() => _selectedDepartmentFilter = value);
        AppLogger.logInterface(
          'Espace Infirmier - Dossiers Patients',
          fileName: 'nurse_home_screen.dart',
          details: 'Filtre pôle sélectionné: $label',
        );
      },
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.evergreen
              : (isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
          borderRadius: BorderRadius.circular(100),
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
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.evergreen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
