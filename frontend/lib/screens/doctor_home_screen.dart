import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/app_logger.dart';
import '../utils/briefing_utils.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/dark_ambient_background.dart';
import '../widgets/figma_header.dart';
import '../widgets/ios_bottom_nav_bar.dart';
import 'ai_briefing_screen.dart';
import 'briefing_detail_screen.dart';
import 'patient_dossier_screen.dart';
import 'profile_screen.dart';
import '../utils/default_patients.dart';
import '../widgets/patient_worklist_card.dart';
import '../widgets/unified_consultation_modal.dart';
import '../widgets/unified_vital_signs_modal.dart';
import 'calendar/clinical_calendar_screen.dart';
import '../widgets/exam_result_detail_modal.dart';

class DoctorHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final int initialTabIndex;

  const DoctorHomeScreen({super.key, required this.onLogout, this.initialTabIndex = 0});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentTab;
  final api = ApiService();

  List<dynamic> patients = DefaultPatients.getAll();
  List<dynamic> consultations = [];
  List<dynamic> exams = [];
  List<dynamic> alerts = [];
  List<dynamic> technicians = [];
  Map<String, dynamic> dailyBriefing = {};
  final Set<String> _readAlertIds = {};
  final Set<String> _deletedConsultationIds = {};
  bool isLoading = true;
  String patientSearchQuery = '';
  String _selectedDepartmentFilter = 'ALL';
  String _consultationSearchQuery = '';
  String _selectedConsultationFilter = 'ALL';

  Timer? _realtimeTimer;

  int get unreadAlertCount => alerts.where((a) {
    final id = a['_id']?.toString();
    return id != null && !_readAlertIds.contains(id);
  }).length;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTabIndex;
    _selectedDepartmentFilter = 'ALL';
    patientSearchQuery = '';
    AppLogger.logInterface(
      'Espace Médecin (Tableau de Bord)',
      fileName: 'doctor_home_screen.dart',
      details: 'Initialisation de l\'espace praticien',
    );
    _loadReadAlertIds();
    _loadData();
    _startRealtimeSync();
  }

  Future<void> _loadReadAlertIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('arij_doctor_read_alerts') ?? [];
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
      await prefs.setStringList('arij_doctor_read_alerts', _readAlertIds.toList());
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
            content: Text('✅ Alerte ($patName) prise en charge et clôturée !'),
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
        final updatedExams = await api.getExams();
        if (!mounted) return;

        final oldCount = alerts.length;
        final newCount = newAlerts.length;

        if (oldCount != newCount || updatedExams.length != exams.length) {
          if (newCount > oldCount && !isLoading) {
            final latest = newAlerts.first;
            final creatorId = latest['createdBy'] is Map
                ? latest['createdBy']['_id']
                : latest['createdBy'];
            final isMine = creatorId?.toString() == api.currentUser?['_id']?.toString();

            if (!isMine) {
              final pat = latest['patientId'];
              final patName = pat is Map
                  ? '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim()
                  : 'Patient';

              // Push Notification locale
              NotificationService().showClinicalAlert(
                title: latest['title'] ?? 'Alerte médicale',
                description: latest['description'] ?? '',
                level: latest['level'] ?? 'URGENT',
                patientName: patName,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.alertRed,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                  content: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🚨 NOUVELLE ALERTE : ${latest['title'] ?? 'Urgence'} ($patName)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              latest['description'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  action: SnackBarAction(
                    label: 'VOIR',
                    textColor: Colors.white,
                    onPressed: _showAlertsModal,
                  ),
                ),
              );
            }
          }

          setState(() {
            alerts = newAlerts;
            exams = updatedExams;
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
      final consultRes = await api.getConsultations();
      final examRes = await api.getExams();
      final alertRes = await api.getAlerts();
      final techRes = await api.getTechnicians();
      final briefingRes = await api.getDailyBriefing();

      if (mounted) {
        final cleanConsultations = consultRes.where((c) {
          final id = c['_id']?.toString() ?? c['id']?.toString();
          return id != null && !_deletedConsultationIds.contains(id);
        }).toList();

        final validBriefing = briefingRes.isNotEmpty && briefingRes['metrics'] != null
            ? briefingRes
            : _getDefaultBriefingData();

        setState(() {
          final allPatients = patRes.isNotEmpty ? patRes : DefaultPatients.getAll();
          final docUserId = api.currentUser?['_id']?.toString();
          final docLastName = api.currentUser?['lastName']?.toString();

          patients = allPatients.where((p) {
            final attending = p['attendingDoctorId'];
            if (docUserId == null && docLastName == null) return true;
            if (attending == null) return true;

            if (attending is Map) {
              final matchId = attending['_id']?.toString() == docUserId;
              final matchName = attending['lastName']?.toString() == docLastName;
              return (docUserId != null && matchId) || (docLastName != null && matchName);
            }
            return attending.toString() == docUserId;
          }).toList();
          // Retain any locally created consultations that are not yet in cleanConsultations
          final fetchedIds = cleanConsultations
              .map((c) => (c['_id'] ?? c['id'])?.toString())
              .toSet();
          final localUnsynced = consultations.where((c) {
            final id = (c['_id'] ?? c['id'])?.toString();
            return id != null && !fetchedIds.contains(id) && !_deletedConsultationIds.contains(id);
          }).toList();

          consultations = [...localUnsynced, ...cleanConsultations];
          if (consultations.isEmpty) {
            consultations = _getDefaultMockConsultations();
          }
          exams = examRes;
          alerts = alertRes;
          technicians = techRes;
          dailyBriefing = validBriefing;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (consultations.isEmpty) {
            consultations = _getDefaultMockConsultations();
          }
          if (patients.isEmpty) {
            final allPatients = DefaultPatients.getAll();
            final docUserId = api.currentUser?['_id']?.toString();
            final docLastName = api.currentUser?['lastName']?.toString();
            patients = allPatients.where((p) {
              final attending = p['attendingDoctorId'];
              if (docUserId == null && docLastName == null) return true;
              if (attending == null) return true;
              if (attending is Map) {
                final matchId = attending['_id']?.toString() == docUserId;
                final matchName = attending['lastName']?.toString() == docLastName;
                return (docUserId != null && matchId) || (docLastName != null && matchName);
              }
              return attending.toString() == docUserId;
            }).toList();
          }
          dailyBriefing = _getDefaultBriefingData();
          isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getDefaultMockConsultations() {
    return [
      {
        '_id': 'consult_chirurgie_01',
        'patientId': 'pat_chirurgie_01',
        'patientName': 'Amine Khelifi',
        'doctorId': 'doc_chirurgie',
        'doctorName': 'Dr. Karima Trabelsi',
        'date': '2026-05-26',
        'motive': 'Consultation - Suivi Post-Opératoire Cholécystectomie',
        'reason': 'Consultation - Suivi Post-Opératoire Cholécystectomie',
        'diagnostic': 'Post-opératoire J+2 cholécystectomie sous cœlioscopie. Évolution clinique très favorable.',
        'diagnosis': 'Post-opératoire J+2 cholécystectomie sous cœlioscopie.',
        'clinicalExam': 'Abdomen souple, cicatrices de trocarts propres sans signe de surinfection. Apyrexie à 36.8°C.',
        'prescription': 'Paracétamol 1g (1 cp 3x/jour si douleur) - Spasfon 80mg (1 cp 3x/jour)',
        'treatmentPlan': 'Surveillance des constantes, réfection du pansement et reprise progressive de l\'alimentation.',
        'prescriptionItems': [
          {'medicine': 'Paracétamol 1g', 'posology': '1 comprimé 3 fois par jour'},
          {'medicine': 'Spasfon 80mg', 'posology': '1 comprimé 3 fois par jour'},
        ],
        'prescriptions': [
          {'medicine': 'Paracétamol 1g', 'posology': '1 comprimé 3 fois par jour'},
          {'medicine': 'Spasfon 80mg', 'posology': '1 comprimé 3 fois par jour'},
        ],
        'isUrgent': true,
      },
      {
        '_id': 'consult_maternite_02',
        'patientId': 'pat_maternite_02',
        'patientName': 'Sarra Ben Mahmoud',
        'doctorId': 'doc_maternite',
        'doctorName': 'Dr. Karima Trabelsi',
        'date': '2026-05-26',
        'motive': 'Consultation Prénatale T3 & Bilan Obstétrique',
        'reason': 'Consultation Prénatale T3 & Bilan Obstétrique',
        'diagnostic':
            'Grossesse mono-fœtale 36 SA évolutive. Hauteur utérine conforme, BCF réguliers.',
        'diagnosis': 'Grossesse 36 SA évolutive.',
        'clinicalExam': 'Bruits du cœur fœtaux réguliers à 142 bpm. Pression artérielle maternelle 115/75 mmHg.',
        'prescription': 'Fer + Acide Folique 1 cp/jour, Magne B6 2 cps/jour.',
        'treatmentPlan': 'Programmation échographie T3 et bilan d\'anesthesie péridurale.',
        'prescriptionItems': [
          {'medicine': 'Fer + Acide Folique', 'posology': '1 comprimé par jour le matin'},
          {'medicine': 'Magne B6', 'posology': '2 comprimés par jour'},
        ],
        'prescriptions': [
          {'medicine': 'Fer + Acide Folique', 'posology': '1 comprimé par jour le matin'},
          {'medicine': 'Magne B6', 'posology': '2 comprimés par jour'},
        ],
        'isUrgent': false,
      },
      {
        '_id': 'consult_cardio_03',
        'patientId': 'pat_cardio_03',
        'patientName': 'Mohamed Trabelsi',
        'doctorId': 'doc_cardio',
        'doctorName': 'Dr. Karima Trabelsi',
        'date': '2026-05-25',
        'motive': 'Consultation Cardiologie & Évaluation Post-Stent',
        'reason': 'Consultation Cardiologie & Évaluation Post-Stent',
        'diagnostic': 'Suivi angioplastie coronaire. Stabilité hémodynamique et tolérance clinique satisfaisante.',
        'diagnosis': 'Insuffisance coronarienne stabilisée.',
        'clinicalExam': 'Auscultation cardiaque : bruits réguliers sans souffle. PA : 128/82 mmHg. FC : 68 bpm.',
        'prescription': 'Kardegic 75mg (1 sachet/jour) - Tahor 20mg (1 cp le soir)',
        'treatmentPlan': 'ECG de contrôle dans 1 mois et épreuve d\'effort à 3 mois.',
        'prescriptionItems': [
          {'medicine': 'Kardegic 75mg', 'posology': '1 sachet au milieu du repas'},
          {'medicine': 'Tahor 20mg', 'posology': '1 comprimé le soir'},
        ],
        'prescriptions': [
          {'medicine': 'Kardegic 75mg', 'posology': '1 sachet au milieu du repas'},
          {'medicine': 'Tahor 20mg', 'posology': '1 comprimé le soir'},
        ],
        'isUrgent': false,
      },
      {
        '_id': 'consult_pediatrie_04',
        'patientId': 'pat_pediatrie_04',
        'patientName': 'Youssef Gharbi',
        'doctorId': 'doc_pediatrie',
        'doctorName': 'Dr. Youssef Mahfoudh',
        'date': '2026-05-24',
        'motive': 'Consultation Pédiatrique - Contrôle Asthme du Nourrisson',
        'reason': 'Consultation Pédiatrique - Contrôle Asthme du Nourrisson',
        'diagnostic':
            'Bronchiolite aiguë en phase de résolution. Râles sibilants nettement diminués.',
        'diagnosis': 'Bronchiolite nourrisson en amélioration.',
        'clinicalExam':
            'Eupneique au repos. Fréquence respiratoire 28/min. SpO2 98% en air ambiant.',
        'prescription': 'Ventoline 100µg (2 bouffées via chambre d\'inhalation 4x/jour)',
        'treatmentPlan': 'Continuer les lavages nasaux multiquotidiens.',
        'prescriptionItems': [
          {'medicine': 'Ventoline 100µg Inhalateur', 'posology': '2 bouffées 4x/jour'},
        ],
        'prescriptions': [
          {'medicine': 'Ventoline 100µg Inhalateur', 'posology': '2 bouffées 4x/jour'},
        ],
        'isUrgent': false,
      },
      {
        '_id': 'consult_pma_05',
        'patientId': 'pat_pma_05',
        'patientName': 'Nour Ben Salem',
        'doctorId': 'doc_pma',
        'doctorName': 'Dr. Karima Trabelsi',
        'date': '2026-05-23',
        'motive': 'Consultation Suivi Protocole PMA & Monitorage Ovulation',
        'reason': 'Consultation Suivi Protocole PMA & Monitorage Ovulation',
        'diagnostic':
            'Monitorage folliculaire J10. 2 follicules dominants à droite (17mm et 15mm).',
        'diagnosis': 'Réponse folliculaire adéquate sous stimulation.',
        'clinicalExam': 'Endomètre à 8.5mm, aspect en triple feuillet idéal.',
        'prescription': 'Ovitrelle 250µg (1 injection sous-cutanée le soir à 22h précises)',
        'treatmentPlan': 'Déclenchement ce soir et insémination à H36.',
        'prescriptionItems': [
          {'medicine': 'Ovitrelle 250µg Stylo', 'posology': '1 injection SC à 22h00'},
        ],
        'prescriptions': [
          {'medicine': 'Ovitrelle 250µg Stylo', 'posology': '1 injection SC à 22h00'},
        ],
        'isUrgent': false,
      },
    ];
  }

  Map<String, dynamic> _getDefaultBriefingData() {
    final user = api.currentUser;
    final lastName = user?['lastName'] ?? 'Trabelsi';
    final firstName = user?['firstName'] ?? '';
    final nameStr = '$firstName $lastName'.trim();

    return {
      'date': 'Lundi 26 mai 2025',
      'rawDate': '2025-05-26',
      'greeting': 'Bonjour, Dr $lastName',
      'subGreeting': 'Voici votre briefing du jour',
      'serviceName': user?['service'] ?? 'Service Médecine Interne',
      'weather': {'temp': '26°C', 'city': 'Djerba', 'condition': 'Ensoleillé'},
      'metrics': {
        'consultationsCount': consultations.isNotEmpty ? consultations.length : 6,
        'urgentConsultationsCount': 2,
        'hospitalizedCount':
            patients
                    .where((p) => p['isHospitalized'] == true || p['status'] == 'HOSPITALIZED')
                    .length >
                0
            ? patients
                  .where((p) => p['isHospitalized'] == true || p['status'] == 'HOSPITALIZED')
                  .length
            : 4,
        'toMonitorHospitalizedCount': 1,
        'pendingExamsCount': exams.where((e) => e['status'] == 'PENDING').length > 0
            ? exams.where((e) => e['status'] == 'PENDING').length
            : 3,
        'tasksCount': alerts.isNotEmpty ? alerts.length : 2,
        'urgentTasksCount': 1,
      },
      'nextAppointment': {
        'time': '09:30',
        'title': 'Consultation - Suivi Post-Opératoire',
        'room': 'Cabinet 2',
        'doctor': 'Dr $lastName',
        'patientName': 'Amine Khelifi',
      },
      'aiSummary':
          "Bonjour Dr $lastName. Votre service en cours à la Polyclinique El Arij comprend 6 consultations programmées, 4 patients hospitalisés sous surveillance et 3 bilans biologiques & radiologiques en attente. Une vigilance particulière est recommandée sur les constantes de M. Amine Khelifi.",
      'aiSummaryPreview': "6 consultations et 4 patients hospitalisés sous surveillance. Vigilance prioritaire sur Amine Khelifi.",
      'consultationsList': [
        {
          'time': '09:30',
          'title': 'Consultation - Suivi Post-Opératoire',
          'room': 'Cabinet 2',
          'patientName': 'Amine Khelifi',
          'isUrgent': true,
        },
      ],
      'hospitalizedList': [
        {
          'room': 'Chambre 201 (Lit 1)',
          'service': 'Médecine Interne',
          'status': 'À surveiller',
          'patientName': 'Mourad Ben Ali',
        },
      ],
      'pendingExamsList': [
        {
          'title': 'Bilan sanguin complet',
          'patientName': 'Amine Khelifi',
          'department': 'Laboratoire',
          'status': 'En attente',
          'isUrgent': true,
        },
      ],
      'tasksList': [
        {
          'id': 't1',
          'title': 'Valider le scanner de contrôle',
          'location': 'Chambre 201',
          'time': '10:30',
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
    final patName = '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim();
    AppLogger.logInterface(
      'Dossier Patient 360°',
      fileName: 'patient_dossier_screen.dart',
      details: 'Patient : $patName (N° ${patient['dossierNumber'] ?? 'N/A'})',
    );
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
          decoration: AppTheme.bottomSheetDecoration(context),
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
                        'Tout traiter',
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
                              'Aucune alerte en attente',
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
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.darkSurface,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isCritical
                                                  ? AppTheme.alertRed
                                                  : AppTheme.evergreen,
                                              borderRadius: BorderRadius.circular(12),
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
                                                'Destiné à : Dr. ${targetDoctor['firstName'] ?? ''} ${targetDoctor['lastName'] ?? ''}'
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
                                                'Diffusion : Tous les médecins',
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
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      if (patient is Map)
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppTheme.evergreen,
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            alignment: Alignment.centerLeft,
                                          ),
                                          icon: const Icon(Icons.folder_shared, size: 15),
                                          label: Text(
                                            'Dossier: $patName',
                                            style: const TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _openPatientDossier(patient as Map<String, dynamic>);
                                          },
                                        ),
                                      const SizedBox(height: 4),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.evergreen,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(Icons.check_circle_outline, size: 14),
                                        label: const Text(
                                          'Prendre en charge',
                                          style: TextStyle(
                                            fontSize: 12,
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

  Future<void> _pickRealPhoneFile(
    BuildContext context,
    StateSetter setModalState,
    TextEditingController docNameCtrl,
    TextEditingController docUrlCtrl,
  ) async {
    try {
      final file = await FilePicker.pickFile(type: FileType.any);

      if (file != null) {
        setModalState(() {
          docNameCtrl.text = file.name;
          docUrlCtrl.text = file.path ?? 'file://${file.name}';
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Fichier sélectionné : "${file.name}"'),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('FilePicker error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sélecteur de fichier : ${e.toString().split('\n').first}'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    }
  }

  void _showPhoneFilePickerModal(
    BuildContext context,
    StateSetter setModalState,
    TextEditingController docNameCtrl,
    TextEditingController docUrlCtrl,
  ) {
    final List<Map<String, String>> samplePhoneFiles = [
      {
        'type': 'PDF',
        'name': 'Ordonnance_Medicale_Arij.pdf',
        'url': 'file:///storage/emulated/0/Download/Ordonnance_Medicale_Arij.pdf',
        'size': '245 KB',
        'date': 'Aujourd\'hui',
      },
      {
        'type': 'IMAGE',
        'name': 'Scan_Ordonnance_Tamponnee.jpg',
        'url': 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=500',
        'size': '1.2 MB',
        'date': 'Hier',
      },
      {
        'type': 'IMAGE',
        'name': 'Ordonnance_Manuscrite_Photo.png',
        'url': 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=500',
        'size': '850 KB',
        'date': '10/09/2026',
      },
    ];

    final customUrlCtrl = TextEditingController(text: docUrlCtrl.text);
    final customNameCtrl = TextEditingController(text: docNameCtrl.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        decoration: AppTheme.bottomSheetDecoration(ctx),
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
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.phone_android, color: AppTheme.evergreen),
                SizedBox(width: 8),
                Text(
                  'Fichiers du téléphone',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Parcourez la mémoire du téléphone ou choisissez dans l\'historique récent :',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),

            // Bouton Parcourir Fichiers Réels
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.evergreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.folder_open_rounded, size: 20),
                label: const Text(
                  '📂 Parcourir les fichiers du téléphone...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _pickRealPhoneFile(context, setModalState, docNameCtrl, docUrlCtrl);
                },
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              '📱 Ou sélectionner un fichier récent :',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMain),
            ),
            const SizedBox(height: 8),

            ...samplePhoneFiles.map((file) {
              final isPdf = file['type'] == 'PDF';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.dustGrey),
                ),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF2EA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.image,
                      color: isPdf ? AppTheme.alertRed : AppTheme.evergreen,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    file['name']!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${file['size']} • ${file['date']}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.textMuted,
                  ),
                  onTap: () {
                    setModalState(() {
                      docNameCtrl.text = file['name']!;
                      docUrlCtrl.text = file['url']!;
                    });
                    Navigator.pop(ctx);
                  },
                ),
              );
            }),

            const SizedBox(height: 12),
            const Divider(),
            const Text(
              '🔗 Saisir manuellement :',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMain),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: customNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom du fichier (ex: Ordonnance_Dr.pdf)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: customUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'Lien / Chemin d\'accès',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.evergreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text(
                  'Valider ce fichier',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  if (customNameCtrl.text.trim().isNotEmpty) {
                    setModalState(() {
                      docNameCtrl.text = customNameCtrl.text.trim();
                      docUrlCtrl.text = customUrlCtrl.text.trim().isNotEmpty
                          ? customUrlCtrl.text.trim()
                          : 'file:///storage/ordonnance.pdf';
                    });
                  }
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewConsultationModal() {
    UnifiedConsultationModal.show(
      context,
      patientsList: patients,
      onSuccess: (newConsult) {
        if (mounted) {
          setState(() {
            final id = (newConsult['_id'] ?? newConsult['id'])?.toString();
            consultations.removeWhere((c) => (c['_id'] ?? c['id'])?.toString() == id);
            consultations.insert(0, newConsult);
          });
          _loadData();
        }
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.evergreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.evergreen,
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required BuildContext context,
    bool isMultiline = false,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF2F4EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.dustGrey.withOpacity(0.6),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: isMultiline ? 3 : 1,
        style: TextStyle(color: isDark ? Colors.white : AppTheme.evergreen, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF8A9E8A),
            fontSize: 14,
          ),
          prefixIcon: isMultiline ? null : Icon(icon, color: AppTheme.evergreen, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(isMultiline ? 16 : 14),
        ),
      ),
    );
  }

  void _showNewExamModal() {
    if (patients.isEmpty) return;
    String selectedPatientId = patients.first['_id'];
    String selectedService = 'Laboratoire / Biologie';
    String? selectedTechId;
    String examType = 'Bilan sanguin complet';
    String priority = 'NORMAL';
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                      color: AppTheme.dustGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '🔬 Prescrire un Examen Complémentaire',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),

                // Sélection du Patient
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedPatientId,
                  decoration: const InputDecoration(
                    labelText: 'Patient *',
                    border: OutlineInputBorder(),
                  ),
                  items: patients.map<DropdownMenuItem<String>>((p) {
                    return DropdownMenuItem<String>(
                      value: p['_id'],
                      child: Text(
                        '${p['firstName']} ${p['lastName']} (${p['cin']})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedPatientId = val);
                  },
                ),

                const SizedBox(height: 12),

                // Département / Service des examens
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedService,
                  decoration: const InputDecoration(
                    labelText: 'Département / Plateau Technique *',
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
                      value: 'Autre Service',
                      child: Text('🏥 Autre Service', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedService = val);
                  },
                ),

                const SizedBox(height: 12),

                // Technicien spécifique désigné
                Builder(
                  builder: (context) {
                    final availableTechnicians = technicians.isNotEmpty
                        ? technicians
                        : [
                            {
                              '_id': 'tech_lab_1',
                              'firstName': 'Sami',
                              'lastName': 'Kefi',
                              'department': 'Laboratoire d\'analyses',
                            },
                            {
                              '_id': 'tech_rad_1',
                              'firstName': 'Bilel',
                              'lastName': 'Trabelsi',
                              'department': 'Radiologie & Scanner',
                            },
                            {
                              '_id': 'tech_cardio_1',
                              'firstName': 'Yassine',
                              'lastName': 'Ben Ali',
                              'department': 'Cardiologie & ECG',
                            },
                            {
                              '_id': 'tech_echo_1',
                              'firstName': 'Salma',
                              'lastName': 'Mansour',
                              'department': 'Échographie & Doppler',
                            },
                          ];

                    return DropdownButtonFormField<String?>(
                      isExpanded: true,
                      value: selectedTechId,
                      decoration: const InputDecoration(
                        labelText: 'Technicien ou Personne Responsable *',
                        helperText:
                            'Désignez le technicien responsable ou adressez à tout le service',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            '👥 Tout le personnel du plateau technique',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.evergreen,
                            ),
                          ),
                        ),
                        ...availableTechnicians.map<DropdownMenuItem<String?>>((t) {
                          final u = t['userId'];
                          final fn = u is Map ? (u['firstName'] ?? '') : (t['firstName'] ?? '');
                          final ln = u is Map ? (u['lastName'] ?? '') : (t['lastName'] ?? '');
                          final name = '$fn $ln'.trim().isNotEmpty
                              ? 'Tech. $fn $ln'
                              : 'Technicien de santé';
                          final dept = t['department'] ?? t['service'] ?? '';
                          final label = dept.toString().isNotEmpty ? '$name ($dept)' : name;
                          return DropdownMenuItem<String?>(
                            value: t['_id']?.toString(),
                            child: Text(label, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setModalState(() => selectedTechId = val);
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: examType,
                  decoration: const InputDecoration(
                    labelText: 'Type d\'examen *',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'Bilan sanguin complet',
                            'Électrocardiogramme (ECG)',
                            'Scanner thoracique sans injection',
                            'Échographie abdominale',
                            'Radiographie pulmonaire',
                            'Bilan Hémostase / TP-INR',
                            'Gaz du sang',
                            'Spermogramme / Bilan PMA',
                          ]
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => examType = val);
                  },
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Priorité : ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ChoiceChip(
                      label: const Text('Normale'),
                      selected: priority == 'MEDIUM',
                      onSelected: (s) => setModalState(() => priority = 'MEDIUM'),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('🚨 Urgente'),
                      selected: priority == 'URGENT',
                      selectedColor: const Color(0xFFEDF2EA),
                      onSelected: (s) => setModalState(() => priority = 'URGENT'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Renseignements cliniques pour le technicien',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.evergreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final docUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];
                      final res = await api.createExam(
                        patientId: selectedPatientId,
                        requestingDoctorId: docUserId,
                        assignedTechnicianId: selectedTechId,
                        service: selectedService,
                        examType: examType,
                        priority: priority,
                        requestNotes: notesCtrl.text.trim(),
                      );
                      _loadData();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: res['success'] == true
                              ? AppTheme.evergreen
                              : AppTheme.alertRed,
                          content: Text(
                            res['success'] == true
                                ? '✅ Demande d\'examen ($examType) transmise au technicien !'
                                : '❌ Échec de la transmission : ${res['error'] ?? 'Vérifiez les données.'}',
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Envoyer l\'ordre au laboratoire/radio',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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

  Widget? _buildDoctorFab() {
    switch (_currentTab) {
      case 1:
        return _buildMediumFab(
          heroTag: 'doctor_patient_fab',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showNewConsultationModal,
          icon: Icons.person_add_alt_1,
          label: 'Nouveau Dossier',
        );
      case 2:
        return _buildMediumFab(
          heroTag: 'doctor_consult_fab',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showNewConsultationModal,
          icon: Icons.add_circle,
          label: 'Nouvelle Consultation',
        );
      case 3:
        return _buildMediumFab(
          heroTag: 'doctor_exam_fab',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showNewExamModal,
          icon: Icons.add_circle_outline,
          label: 'Prescrire Examen',
        );
      case 0:
      default:
        return _buildMediumFab(
          heroTag: 'doctor_overview_fab',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: _showNewConsultationModal,
          icon: Icons.add,
          label: 'Nouvelle Consultation',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = api.currentUser;
    final fullName = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();

    return Scaffold(
      key: _scaffoldKey,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _buildDoctorFab(),
      drawer: AppDrawer(
        onSelectTab: (idx) => setState(() {
          _currentTab = idx;
          if (idx == 1) {
            _selectedDepartmentFilter = 'ALL';
            patientSearchQuery = '';
          }
        }),
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      body: DarkAmbientBackground(
        child: Column(
          children: [
            FigmaHeader(
              roleName: 'MÉDECIN',
              roleColor: AppTheme.getRoleColor('DOCTOR'),
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
                child: IndexedStack(
                  index: _currentTab,
                  children: [
                    _buildOverviewTab(),
                    _buildPatientsTab(),
                    _buildConsultationsTab(),
                    _buildExamsTab(),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: IosBottomNavBar(
        selectedIndex: _currentTab,
        onItemSelected: (idx) {
          final tabNames = [
            'Accueil (Tableau de Bord)',
            'Dossiers Patients (Worklist)',
            'Consultations',
            'Examens Médicaux',
          ];
          final tabName = idx < tabNames.length ? tabNames[idx] : 'Onglet $idx';
          AppLogger.logInterface(
            'Espace Médecin',
            fileName: 'doctor_home_screen.dart',
            details: 'Bascule vers onglet : $tabName',
          );
          setState(() {
            _currentTab = idx;
            if (idx == 1) {
              _selectedDepartmentFilter = 'ALL';
              patientSearchQuery = '';
            }
          });
        },
        activeColor: AppTheme.evergreen,
        items: const [
          IosBottomNavItem(
            icon: CupertinoIcons.house,
            selectedIcon: CupertinoIcons.house_fill,
            label: 'Accueil',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.folder,
            selectedIcon: CupertinoIcons.folder_fill,
            label: 'Dossiers Patients',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.doc_text,
            selectedIcon: CupertinoIcons.doc_text_fill,
            label: 'Consultations',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.waveform_path_ecg,
            selectedIcon: CupertinoIcons.waveform_path_ecg,
            label: 'Examens',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final isDark = AppTheme.isDarkMode(context);
    final user = api.currentUser;
    final lastName = user?['lastName'] ?? 'Trabelsi';
    final displayName = 'Bonjour, Dr $lastName';

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
      fallback:
          _getDefaultBriefingData()['aiSummaryPreview']?.toString() ??
          'Briefing clinique indisponible.',
    );

    final briefingMetrics = dailyBriefing['metrics'] as Map? ?? const {};
    final patientHospitalizedCount = patients.where((patient) {
      final stay = patient['hospitalStay'];
      return (stay is Map && stay['status'] == 'ACTIVE') ||
          patient['isHospitalized'] == true ||
          patient['status'] == 'HOSPITALIZED';
    }).length;
    final hospitalizedCount = briefingMetrics['hospitalizedCount'] ?? patientHospitalizedCount;
    final pendingExamsCount = exams
        .where((e) => e['status'] == 'PENDING' || e['status'] == 'IN_PROGRESS')
        .length;

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
                  'Rapport matinal & Synthèse clinique',
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
                        '+$hospitalizedCount patients suivis',
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
                      '$hospitalizedCount',
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
                  color: AppTheme.evergreen.withValues(alpha: isDark ? 0.2 : 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.evergreen.withValues(alpha: 0.3)),
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
                            color: Color(0xFFEDF2EA),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emergency_rounded,
                            size: 15,
                            color: AppTheme.evergreen,
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.evergreen,
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
                        color: AppTheme.evergreen,
                      ),
                    ),
                    const Text(
                      'Urgences Box',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.evergreen,
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
                            Icons.science_rounded,
                            size: 15,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                      '$pendingExamsCount',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Examens labo',
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
            border: Border.all(color: AppTheme.evergreen.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.evergreen.withValues(alpha: 0.08),
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
                      color: AppTheme.evergreen,
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
                      color: const Color(0xFFEDF2EA),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      '1 Critique',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.evergreen,
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
                      color: Color(0xFFEDF2EA),
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
                              '• Box 2',
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
                        'Alerte Potassium critique: 6.2 mmol/L',
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
                          'Prendre en charge',
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

  Widget _buildDashboardStat(bool isDark, String title, String value, Color color, String icon) {
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

  Widget _buildActionCard(bool isDark, String title, String subtitle, IconData icon, Color color) {
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
          Icon(CupertinoIcons.chevron_right, color: color.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildConsultationRow(String time, String name, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            time,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppTheme.darkElevated : Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: AppTheme.subtextColor(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
        // En-tête Dossiers Patients (Stitch Design)
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
              color: isDark ? AppTheme.darkSurface : Colors.white,
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
                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.drySage),
                prefixIcon: const Icon(Icons.search, color: AppTheme.evergreen, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (val) => setState(() => patientSearchQuery = val),
            ),
          ),
        ),

        // Filtre par service / spécialité (Tous les pôles en premier)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _filterChip('Tous les pôles', 'ALL', Icons.domain),
              const SizedBox(width: 8),
              _filterChip('🏥 Chirurgie & Hospit.', 'CHIRURGIE', Icons.local_hospital),
              const SizedBox(width: 8),
              _filterChip('🌸 Maternité & Obstétrique', 'MATERNITE', Icons.pregnant_woman),
              const SizedBox(width: 8),
              _filterChip('❤️ Cardiologie', 'CARDIOLOGIE', Icons.favorite),
              const SizedBox(width: 8),
              _filterChip('👶 Pédiatrie', 'PEDIATRIE', Icons.child_care),
              const SizedBox(width: 8),
              _filterChip('🧬 PMA & Gynéco.', 'PMA', Icons.biotech_rounded),
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
                            fileName: 'doctor_home_screen.dart',
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

  Widget _filterChip(String label, String value, IconData icon) {
    final isSelected = _selectedDepartmentFilter == value;
    final isDark = AppTheme.isDarkMode(context);
    return InkWell(
      onTap: () {
        setState(() => _selectedDepartmentFilter = value);
        AppLogger.logInterface(
          'Espace Médecin - Dossiers Patients',
          fileName: 'doctor_home_screen.dart',
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
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.evergreen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationsTab() {
    final isDark = AppTheme.isDarkMode(context);

    // Filter consultations based on search query and filter
    final filtered = consultations.where((c) {
      final patMap = _resolveConsultationPatientMap(c);
      final pu = patMap['userId'] is Map
          ? patMap['userId']
          : (patMap['user'] is Map ? patMap['user'] : null);
      final pfn = (patMap['firstName'] ?? pu?['firstName'] ?? '').toString();
      final pln = (patMap['lastName'] ?? pu?['lastName'] ?? '').toString();
      final patName = '$pfn $pln'.trim().isNotEmpty
          ? '$pfn $pln'.trim()
          : (c['patientName']?.toString().isNotEmpty == true ? c['patientName'].toString() : '');
      final motive = (c['motive'] ?? c['reason'] ?? '').toString();
      final diagnostic = (c['diagnostic'] ?? c['diagnosis'] ?? '').toString();

      final matchesQuery =
          _consultationSearchQuery.isEmpty ||
          patName.toLowerCase().contains(_consultationSearchQuery.toLowerCase()) ||
          motive.toLowerCase().contains(_consultationSearchQuery.toLowerCase()) ||
          diagnostic.toLowerCase().contains(_consultationSearchQuery.toLowerCase());

      if (!matchesQuery) return false;

      if (_selectedConsultationFilter == 'WITH_PRESCRIPTION') {
        final items =
            (c['prescriptionItems'] as List<dynamic>?) ??
            (c['prescriptions'] as List<dynamic>?) ??
            [];
        return items.isNotEmpty;
      } else if (_selectedConsultationFilter == 'TODAY') {
        final date = (c['date'] ?? '').toString();
        return date.contains('2026') || date.contains('Aujourd') || date.contains('mai');
      }

      return true;
    }).toList();

    final withPrescriptionCount = consultations.where((c) {
      final items =
          (c['prescriptionItems'] as List<dynamic>?) ??
          (c['prescriptions'] as List<dynamic>?) ??
          [];
      return items.isNotEmpty;
    }).length;

    final todayCount = consultations.where((c) {
      final date = (c['date'] ?? '').toString();
      return date.contains('2026') || date.contains('Aujourd') || date.contains('mai');
    }).length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        children: [
          // ── Greeting & Clinique Header Row (Style Accueil) ─────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consultations Médicales',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Actes cliniques, diagnostics & ordonnances sécurisées',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7E72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.evergreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppTheme.evergreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.meeting_room_rounded, size: 14, color: AppTheme.evergreen),
                    const SizedBox(width: 4),
                    Text(
                      'Cabinet 4',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.evergreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Search Bar Stitch ───────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) => setState(() => _consultationSearchQuery = val),
              decoration: InputDecoration(
                hintText: 'Rechercher patient, motif, diagnostic...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.drySage : const Color(0xFF6B7E72),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.evergreen),
                suffixIcon: _consultationSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _consultationSearchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Stitch 3-Card Dynamic KPI Counters (Style Accueil) ───────────
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedConsultationFilter = 'ALL'),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _selectedConsultationFilter == 'ALL'
                            ? AppTheme.evergreen
                            : AppTheme.borderColor(context),
                        width: _selectedConsultationFilter == 'ALL' ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.evergreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.medical_services_rounded,
                                size: 16,
                                color: AppTheme.evergreen,
                              ),
                            ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.evergreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.evergreen,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${consultations.length}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.darkBackground,
                          ),
                        ),
                        const Text(
                          'Actes médicaux',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7E72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedConsultationFilter = 'WITH_PRESCRIPTION'),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _selectedConsultationFilter == 'WITH_PRESCRIPTION'
                            ? AppTheme.evergreen
                            : AppTheme.borderColor(context),
                        width: _selectedConsultationFilter == 'WITH_PRESCRIPTION' ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEDF2EA),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.medication_rounded,
                                size: 16,
                                color: AppTheme.evergreen,
                              ),
                            ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDF2EA),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: const Text(
                                  'Ordon.',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.evergreen,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$withPrescriptionCount',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.evergreen,
                          ),
                        ),
                        const Text(
                          'Prescriptions',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7E72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedConsultationFilter = 'TODAY'),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _selectedConsultationFilter == 'TODAY'
                            ? AppTheme.evergreen
                            : AppTheme.borderColor(context),
                        width: _selectedConsultationFilter == 'TODAY' ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.evergreen.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: AppTheme.evergreen,
                              ),
                            ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.evergreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: const Text(
                                  'Jour',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.evergreen,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$todayCount',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.darkBackground,
                          ),
                        ),
                        const Text(
                          'Rendez-vous',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7E72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Prochaine consultation Card (Style Accueil) ─────────────────
          if (consultations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (ctx) {
                final next = consultations.first;
                final patMap = _resolveConsultationPatientMap(next);
                final pu = patMap['userId'] is Map
                    ? patMap['userId']
                    : (patMap['user'] is Map ? patMap['user'] : null);
                final pfn = (patMap['firstName'] ?? pu?['firstName'] ?? '').toString();
                final pln = (patMap['lastName'] ?? pu?['lastName'] ?? '').toString();
                final patName = '$pfn $pln'.trim().isNotEmpty
                    ? '$pfn $pln'.trim()
                    : (next['patientName']?.toString().isNotEmpty == true
                          ? next['patientName'].toString()
                          : 'Patient');
                final time = (next['date'] ?? '09:30').toString();
                final motive =
                    (next['motive'] ?? next['reason'] ?? 'Consultation de contrôle clinique')
                        .toString();

                return InkWell(
                  onTap: () {
                    AppLogger.logInterface(
                      'Dossier Patient 360°',
                      fileName: 'doctor_home_screen.dart',
                      details: 'Clic prochaine séance -> Dossier: $patName',
                    );
                    _openPatientDossier(patMap);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
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
                            const Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: AppTheme.evergreen,
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Consultation en cours / Prochaine séance',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.evergreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF2EA),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                'Prioritaire',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.evergreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDF2EA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                time.length > 5 ? time.substring(0, 5) : time,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.evergreen,
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textColor(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    motive,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF6B7E72),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.evergreen,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],

          // ── Section Title & Count ───────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Dossiers de consultation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textColor(context),
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF2EA),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${filtered.length} affichée(s)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.evergreen,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Consultations List or Empty State ───────────────────────────
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDF2EA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.medical_services_outlined,
                      size: 32,
                      color: AppTheme.evergreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune consultation trouvée',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _consultationSearchQuery.isNotEmpty
                        ? 'Aucun résultat pour "$_consultationSearchQuery"'
                        : 'Aucune consultation n\'a encore été enregistrée pour ce filtre.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.drySage : const Color(0xFF6B7E72),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.pastelOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    icon: const Icon(Icons.add_circle, size: 16),
                    label: const Text(
                      'Créer une consultation',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      AppLogger.logInterface(
                        'Nouvelle Consultation Médecin',
                        fileName: 'doctor_home_screen.dart',
                        details: 'Ouverture modal création consultation depuis état vide',
                      );
                      _showNewConsultationModal();
                    },
                  ),
                ],
              ),
            )
          else
            ...filtered.map((c) => _consultationCard(c)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _consultationFilterChip({
    required String label,
    required String id,
    required bool isDark,
  }) {
    final isSelected = _selectedConsultationFilter == id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedConsultationFilter = id);
        AppLogger.logInterface(
          'Filtre Consultations: $label',
          fileName: 'doctor_home_screen.dart',
          details: 'Sélection filtre consultations: $id',
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.evergreen
              : (isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA)),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected
                ? AppTheme.evergreen
                : (isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.evergreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? AppTheme.dustGrey : AppTheme.evergreen),
          ),
        ),
      ),
    );
  }

  Widget _buildExamsTab() {
    final isDark = AppTheme.isDarkMode(context);
    return Column(
      children: [
        // Header & Action Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.evergreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${exams.length} Examens Prescrits',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.evergreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: exams.isEmpty
                ? const Center(child: Text('Aucun examen prescrit'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: exams.length,
                    itemBuilder: (context, idx) {
                      final ex = exams[idx];
                      final status = ex['status'] ?? 'PENDING';
                      final isCompleted = status == 'COMPLETED' || status == 'DONE';
                      final isInProgress = status == 'IN_PROGRESS';

                      final patMap = ExamResultDetailModal.resolvePatientMap(
                        ex['patientId'] ?? ex['patient'],
                        patients,
                      );
                      final pfn = patMap['firstName'] ?? '';
                      final pln = patMap['lastName'] ?? '';
                      final patName = '$pfn $pln'.trim().isNotEmpty
                          ? '$pfn $pln'.trim()
                          : 'Patient';
                      final serviceName = ex['service'] ?? 'Plateau Technique';

                      final techObj = ex['assignedTechnicianId'];
                      final techUser = techObj is Map
                          ? (techObj['userId'] is Map ? techObj['userId'] : techObj['user'])
                          : null;
                      final tfn = techUser is Map
                          ? (techUser['firstName'] ?? '')
                          : (techObj is Map ? (techObj['firstName'] ?? '') : '');
                      final tln = techUser is Map
                          ? (techUser['lastName'] ?? '')
                          : (techObj is Map ? (techObj['lastName'] ?? '') : '');
                      final techName = '$tfn $tln'.trim().isNotEmpty ? 'Tech. $tfn $tln' : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
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
                            onTap: () => ExamResultDetailModal.show(
                              context,
                              exam: ex,
                              patient: patMap,
                              globalPatientsList: patients,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ex['examType'] ?? 'Examen',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: AppTheme.textColor(context),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? const Color(0xFFEDF2EA)
                                              : isInProgress
                                              ? const Color(0xFFEDF2EA)
                                              : const Color(0xFFFDF6EC),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          isCompleted
                                              ? 'Envoyé'
                                              : isInProgress
                                              ? 'Traitée'
                                              : 'En attente',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isCompleted
                                                ? AppTheme.evergreen
                                                : isInProgress
                                                ? AppTheme.evergreen
                                                : AppTheme.pastelOrange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Patient : $patName  •  Service : $serviceName  •  Priorité : ${ex['priority'] ?? 'NORMAL'}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7E72)),
                                  ),
                                  if (ex['requestNotes'] != null &&
                                      ex['requestNotes'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Motif clinique : ${ex['requestNotes']}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: AppTheme.darkElevated,
                                      ),
                                    ),
                                  ],
                                  if (isCompleted ||
                                      (ex['result'] != null &&
                                          ex['result'].toString().isNotEmpty)) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.background,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppTheme.dustGrey),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                size: 16,
                                                color: AppTheme.evergreen,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  techName != null
                                                      ? 'Résultat validé par $techName :'
                                                      : 'Résultat validé par le plateau technique :',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: AppTheme.evergreen,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            ex['result']?.toString() ?? 'Examen validé.',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.evergreen,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (ex['technicalNotes'] != null &&
                                              ex['technicalNotes'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Notes technicien : ${ex['technicalNotes']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.evergreen,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                          if (ex['resultDocumentUrl'] != null &&
                                              ex['resultDocumentUrl'].toString().isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            InkWell(
                                              onTap: () => _triggerRealDownload(
                                                context,
                                                'result_${ex['_id']}.pdf',
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEDF2EA),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: AppTheme.drySage),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.picture_as_pdf,
                                                      size: 15,
                                                      color: AppTheme.evergreen,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        'Document joint : ${ex['resultDocumentUrl']}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppTheme.evergreen,
                                                          fontWeight: FontWeight.w600,
                                                          decoration: TextDecoration.underline,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
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
                                  const SizedBox(height: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.evergreen,
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          alignment: Alignment.centerLeft,
                                        ),
                                        icon: const Icon(CupertinoIcons.doc_text_search, size: 15),
                                        label: const Text(
                                          'Ouvrir le résultat',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onPressed: () => ExamResultDetailModal.show(
                                          context,
                                          exam: ex,
                                          patient: patMap,
                                          globalPatientsList: patients,
                                        ),
                                      ),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.evergreen,
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          alignment: Alignment.centerLeft,
                                        ),
                                        icon: const Icon(Icons.folder_open, size: 15),
                                        label: const Text(
                                          'Dossier patient',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onPressed: () => _openPatientDossier(patMap),
                                      ),
                                    ],
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

  Future<void> _triggerRealDownload(
    BuildContext context,
    String fileName, {
    dynamic consultation,
  }) async {
    String targetPath = '';
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final file = File('${dir.path}/$cleanFileName');

      final patient = consultation != null ? consultation['patientId'] : null;
      final patientName = patient is Map
          ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim()
          : 'Patient';
      final items = consultation != null
          ? ((consultation['prescriptionItems'] as List<dynamic>?) ?? [])
          : [];

      final contentBuffer = StringBuffer();
      contentBuffer.writeln('==========================================');
      contentBuffer.writeln('       POLYCLINIQUE ARIJ DJERBA');
      contentBuffer.writeln('  Plateau Médical & Chirurgies Spécialisées');
      contentBuffer.writeln('==========================================');
      contentBuffer.writeln('DOCUMENT OFFICIEL — ORDONNANCE MÉDICALE');
      contentBuffer.writeln(
        'Date : ${consultation != null ? (consultation['date'] ?? '13/09/2026') : '13/09/2026'}',
      );
      contentBuffer.writeln('Patient : $patientName');
      contentBuffer.writeln(
        'Motif : ${consultation != null ? (consultation['motive'] ?? 'Consultation') : '-'}',
      );
      contentBuffer.writeln(
        'Diagnostic : ${consultation != null ? (consultation['diagnostic'] ?? 'Suivi') : '-'}',
      );
      contentBuffer.writeln('------------------------------------------');
      contentBuffer.writeln('TRAITEMENT PRESCRIT :');
      if (items.isNotEmpty) {
        for (final it in items) {
          contentBuffer.writeln('• ${it['medicine']} ${it['dosage'] ?? ''}');
          contentBuffer.writeln(
            '  Posologie: ${it['posology'] ?? '1 cp'} | Fréquence: ${it['frequency'] ?? '3x/j'} | Durée: ${it['duration'] ?? '5j'}',
          );
        }
      } else {
        contentBuffer.writeln('Ordonnance scannée numérisée jointe au dossier.');
      }
      contentBuffer.writeln('------------------------------------------');
      contentBuffer.writeln('Dr. Spécialiste — Polyclinique Arij');
      contentBuffer.writeln('Cachet Électronique & Signature Certifiée');
      contentBuffer.writeln('==========================================');

      await file.writeAsString(contentBuffer.toString());
      targetPath = file.path;
    } catch (e) {
      debugPrint('Download file save error: $e');
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        double progress = 0.0;
        bool isFinished = false;

        return StatefulBuilder(
          builder: (stContext, setState) {
            if (!isFinished && progress == 0.0) {
              Future.delayed(const Duration(milliseconds: 150), () {
                if (stContext.mounted) setState(() => progress = 0.45);
              });
              Future.delayed(const Duration(milliseconds: 450), () {
                if (stContext.mounted) setState(() => progress = 0.85);
              });
              Future.delayed(const Duration(milliseconds: 750), () {
                if (stContext.mounted) {
                  setState(() {
                    progress = 1.0;
                    isFinished = true;
                  });
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isFinished) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: AppTheme.evergreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: AppTheme.evergreen,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Téléchargement & Génération...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fileName,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppTheme.border,
                        color: AppTheme.evergreen,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.evergreen,
                            ),
                          ),
                          const Text(
                            '248 KB',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Fichier PDF Téléchargé !',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Le fichier "$fileName" est enregistré sur votre appareil.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: AppTheme.evergreen),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.share_rounded,
                                size: 18,
                                color: AppTheme.evergreen,
                              ),
                              label: const Text(
                                'Partager / Enregistrer',
                                style: TextStyle(
                                  color: AppTheme.evergreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              onPressed: () {
                                if (targetPath.isNotEmpty) {
                                  Share.shareXFiles([
                                    XFile(targetPath),
                                  ], text: 'Ordonnance Médicale - Polyclinique Arij');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: AppTheme.evergreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text(
                                'OK',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDocumentPreviewerDialog(
    BuildContext context,
    dynamic c,
    String fileName,
    String fileUrl,
  ) {
    final patient = c['patientId'];
    final patientName = patient is Map
        ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim()
        : 'Patient';
    final items = (c['prescriptionItems'] as List<dynamic>?) ?? [];
    final attachments = (c['attachments'] as List<dynamic>?) ?? [];
    final firstAtt = attachments.isNotEmpty ? attachments.first : null;
    final displayFileName = fileName.isNotEmpty
        ? fileName
        : (firstAtt != null
              ? (firstAtt['name'] ?? 'ordonnance_medicale.pdf')
              : 'ordonnance_medicale.pdf');
    final isImage =
        fileUrl.toLowerCase().contains('.jpg') ||
        fileUrl.toLowerCase().contains('.png') ||
        fileUrl.toLowerCase().contains('unsplash');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.evergreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppTheme.evergreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Aperçu Officiel — Ordonnance Médicale',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textMain,
                          ),
                        ),
                        Text(
                          'Polyclinique Arij Djerba • ${c['date'] ?? '13/09/2026'}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor(context), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'POLYCLINIQUE ARIJ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: AppTheme.evergreen,
                                    ),
                                  ),
                                  const Text(
                                    'Plateau Médical & Chirurgies Djerba',
                                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  ),
                                  Text(
                                    'Date : ${c['date'] ?? '13/09/2026'}',
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.verified, size: 14, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'Certifié Officiel',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        Text(
                          'Patient : $patientName',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textMain,
                          ),
                        ),
                        Text(
                          'Motif : ${c['motive'] ?? 'Consultation médicale'}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        Text(
                          'Diagnostic : ${c['diagnostic'] ?? 'Suivi médical'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Section scanner / Document joint
                        if (attachments.isNotEmpty || fileUrl.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.dustGrey),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.picture_as_pdf_outlined,
                                      size: 18,
                                      color: AppTheme.alertRed,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Pièce jointe du téléphone : $displayFileName',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppTheme.textMain,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEDF2EA),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Page 1/1 • PDF Canvas',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.evergreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isImage && fileUrl.startsWith('http')) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      fileUrl,
                                      height: 160,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => Container(
                                        height: 90,
                                        color: Colors.grey.shade100,
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'Document numérisé joint au dossier',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 110,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.dustGrey),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.picture_as_pdf,
                                          color: AppTheme.alertRed,
                                          size: 36,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          displayFileName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: AppTheme.textMain,
                                          ),
                                        ),
                                        const Text(
                                          'Document scanné & archivé dans le dossier médical du patient',
                                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const Text(
                          '💊 Traitement & Prescriptions :',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.evergreen,
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (items.isNotEmpty)
                          ...items.map(
                            (it) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.medication_outlined,
                                    color: AppTheme.evergreen,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${it['medicine']} ${it['dosage'] ?? ''}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          'Posologie: ${it['posology'] ?? '1 cp'} • Fréquence: ${it['frequency'] ?? '3x/j'} • Durée: ${it['duration'] ?? '5j'}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Ordonnance numérisée certifiée jointe au dossier médical.',
                              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Signature du Médecin :',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  api.currentUser?['firstName'] != null
                                      ? 'Dr. ${api.currentUser!['firstName']} ${api.currentUser!['lastName'] ?? ''}'
                                      : 'Dr. Spécialiste',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.evergreen,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.evergreen, width: 1.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Column(
                                children: [
                                  Text(
                                    'POLYCLINIQUE ARIJ',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.evergreen,
                                    ),
                                  ),
                                  Text(
                                    'Cachet Électronique',
                                    style: TextStyle(fontSize: 8, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.print_outlined, size: 18, color: AppTheme.textMain),
                      label: const Text(
                        'Imprimer',
                        style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '🖨️ Ordre d\'impression envoyé à l\'imprimante de la clinique !',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.evergreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text(
                        'Télécharger PDF',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _triggerRealDownload(context, displayFileName, consultation: c);
                      },
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

  Map<String, dynamic> _resolveConsultationPatientMap(dynamic c) {
    if (c == null) return {};

    // 1. Check if patientId or patient inside c is a Map with firstName/lastName
    final patField = c['patientId'] ?? c['patient'];
    if (patField is Map) {
      final map = Map<String, dynamic>.from(patField as Map);
      final fn =
          (map['firstName'] ?? (map['userId'] is Map ? map['userId']['firstName'] : null))
              ?.toString() ??
          '';
      final ln =
          (map['lastName'] ?? (map['userId'] is Map ? map['userId']['lastName'] : null))
              ?.toString() ??
          '';
      if (fn.trim().isNotEmpty || ln.trim().isNotEmpty) {
        return map;
      }
    }

    // 2. Search ID (from string patientId / patient or _id)
    final searchId = patField is String
        ? patField
        : (patField is Map
              ? (patField['_id'] ?? patField['id'])?.toString()
              : c['patientId']?.toString());

    if (searchId != null && searchId.isNotEmpty) {
      for (final p in patients) {
        if (p is Map &&
            (p['_id']?.toString() == searchId ||
                p['id']?.toString() == searchId ||
                p['cin']?.toString() == searchId ||
                p['dossierNumber']?.toString() == searchId)) {
          return Map<String, dynamic>.from(p as Map);
        }
      }
      for (final defaultP in DefaultPatients.getAll()) {
        if (defaultP['_id']?.toString() == searchId ||
            defaultP['id']?.toString() == searchId ||
            defaultP['cin']?.toString() == searchId ||
            defaultP['dossierNumber']?.toString() == searchId) {
          return Map<String, dynamic>.from(defaultP);
        }
      }
    }

    // 3. Search by patientName string field if provided
    final nameVal =
        (c['patientName'] ??
                c['patient_name'] ??
                (patField is Map ? patField['patientName'] : null))
            ?.toString()
            .trim();
    if (nameVal != null && nameVal.isNotEmpty && nameVal != searchId) {
      final q = nameVal.toLowerCase();
      for (final p in patients) {
        if (p is Map) {
          final fn = (p['firstName'] ?? '').toString().toLowerCase();
          final ln = (p['lastName'] ?? '').toString().toLowerCase();
          final full = '$fn $ln'.trim();
          if (full == q || fn == q || ln == q || (full.isNotEmpty && q.contains(full))) {
            return Map<String, dynamic>.from(p as Map);
          }
        }
      }
      for (final defaultP in DefaultPatients.getAll()) {
        final fn = (defaultP['firstName'] ?? '').toString().toLowerCase();
        final ln = (defaultP['lastName'] ?? '').toString().toLowerCase();
        final full = '$fn $ln'.trim();
        if (full == q || fn == q || ln == q || (full.isNotEmpty && q.contains(full))) {
          return Map<String, dynamic>.from(defaultP);
        }
      }
      return {
        '_id': searchId ?? 'pat_${nameVal.replaceAll(' ', '_').toLowerCase()}',
        'firstName': nameVal,
        'lastName': '',
        'cin': c['cin'] ?? '08123456',
        'dossierNumber': c['dossierNumber'] ?? 'PAT-2026-000',
      };
    }

    // 4. Fallback if no matching patient found
    if (patients.isNotEmpty && patients.first is Map) {
      return Map<String, dynamic>.from(patients.first as Map);
    }
    return Map<String, dynamic>.from(DefaultPatients.getAll().first);
  }

  Widget _consultationCard(dynamic c) {
    final isDark = AppTheme.isDarkMode(context);

    final patMap = _resolveConsultationPatientMap(c);
    final pu = patMap['userId'] is Map
        ? patMap['userId']
        : (patMap['user'] is Map ? patMap['user'] : null);
    final pfn = (patMap['firstName'] ?? pu?['firstName'] ?? '').toString();
    final pln = (patMap['lastName'] ?? pu?['lastName'] ?? '').toString();
    final rawName = '$pfn $pln'.trim().isNotEmpty
        ? '$pfn $pln'.trim()
        : (c['patientName']?.toString().isNotEmpty == true
              ? c['patientName'].toString()
              : 'Patient');

    final gender = (patMap['gender'] ?? pu?['gender'] ?? '').toString();
    final civility = gender == 'MALE' || gender == 'M'
        ? 'M. '
        : (gender == 'FEMALE' || gender == 'F' ? 'Mme. ' : '');
    final patientName = rawName.startsWith('M.') || rawName.startsWith('Mme')
        ? rawName
        : '$civility$rawName';

    // Extraction initiales pour l'avatar Stitch
    String initials = '';
    if (pfn.isNotEmpty && pln.isNotEmpty) {
      initials = '${pfn[0]}${pln[0]}'.toUpperCase();
    } else if (rawName.isNotEmpty) {
      final parts = rawName.split(' ');
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = rawName.substring(0, rawName.length >= 2 ? 2 : 1).toUpperCase();
      }
    } else {
      initials = 'PT';
    }

    final patCin = patMap['cin'] ?? patMap['dossierNumber'] ?? '08123456';
    final items =
        (c['prescriptionItems'] as List<dynamic>?) ?? (c['prescriptions'] as List<dynamic>?) ?? [];
    final attachments = (c['attachments'] as List<dynamic>?) ?? [];
    final rawId = (c['_id'] ?? c['id'])?.toString();
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'consult_${c['patientId'] ?? 'p'}_${c['date'] ?? '2026'}_${c['motive'].hashCode}';

    return Dismissible(
      key: Key('consultation_$id'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.delete_forever, color: AppTheme.alertRed, size: 26),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Supprimer la consultation ?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Text(
              'Voulez-vous vraiment supprimer la consultation de $patientName ?\nCette action est irréversible.',
              style: const TextStyle(fontSize: 13, color: AppTheme.evergreen),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7E72))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.alertRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            _deletedConsultationIds.add(id);
            consultations.removeWhere(
              (item) => item['_id']?.toString() == id || item['id']?.toString() == id,
            );
          });
          api.deleteConsultation(id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppTheme.darkSurface,
                content: Text('🗑️ Consultation supprimée avec succès.'),
              ),
            );
          }
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.alertRed,
          borderRadius: BorderRadius.circular(24),
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
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.evergreen.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              AppLogger.logInterface(
                'Dossier Patient 360°',
                fileName: 'doctor_home_screen.dart',
                details: 'Clic consultation pour ouvrir dossier: $patientName',
              );
              _openPatientDossier(patMap);
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: Avatar Initiales + Nom + Badges ──────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar Initiales Stitch (Palette #FFDADA / #40000C)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF2EA),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.evergreen.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: AppTheme.evergreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patientName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppTheme.textColor(context),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: AppTheme.evergreen,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        c['date'] ?? 'Aujourd\'hui',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : AppTheme.evergreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (patCin != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppTheme.darkElevated
                                          : const Color(0xFFEDF2EA),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      'IPU #$patCin',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.evergreen,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFF6B7E72),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Motif de Consultation ────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBackground : AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.medical_information_outlined,
                          size: 16,
                          color: AppTheme.evergreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white70 : AppTheme.evergreen,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Motif : ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.evergreen,
                                  ),
                                ),
                                TextSpan(text: c['motive'] ?? 'Consultation médicale générale'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Diagnostic Retenu ────────────────────────────────────
                  if (c['diagnostic'] != null && c['diagnostic'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEDF2EA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 16, color: AppTheme.evergreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Diagnostic : ${c['diagnostic']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.evergreen,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Ordonnance / Prescriptions Items ─────────────────────
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Prescription médicale',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.evergreen,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: items.map((it) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA),
                            ),
                          ),
                          child: Text(
                            '💊 ${it['medicine']} ${it['dosage'] ?? ''}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.darkBackground,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 14),
                  Divider(height: 1, color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
                  const SizedBox(height: 12),

                  // ── Actions Footer Stitch (Dossier 360° • Aperçu • PDF) ──
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Accès dossier
                      InkWell(
                        onTap: () {
                          AppLogger.logInterface(
                            'Dossier Patient 360°',
                            fileName: 'doctor_home_screen.dart',
                            details: 'Consultation -> Ouverture dossier: $patientName',
                          );
                          _openPatientDossier(patMap);
                        },
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.evergreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Dossier patient',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.evergreen,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: AppTheme.evergreen,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Boutons Aperçu & PDF
                      if (attachments.isNotEmpty || items.isNotEmpty) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            side: const BorderSide(color: AppTheme.evergreen),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          icon: const Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: AppTheme.evergreen,
                          ),
                          label: const Text(
                            'Aperçu',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.evergreen,
                            ),
                          ),
                          onPressed: () {
                            AppLogger.logInterface(
                              'Aperçu Document Médical',
                              fileName: 'doctor_home_screen.dart',
                              details: 'Aperçu ordonnance de $patientName',
                            );
                            final firstAtt = attachments.isNotEmpty ? attachments.first : null;
                            final fileName = firstAtt != null
                                ? (firstAtt['name'] ?? 'ordonnance_scanne.pdf')
                                : 'ordonnance_medicale_${c['date'] ?? '2026'}.pdf';
                            final fileUrl = firstAtt != null ? (firstAtt['url'] ?? '') : '';
                            _showDocumentPreviewerDialog(context, c, fileName, fileUrl);
                          },
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            backgroundColor: AppTheme.evergreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 14),
                          label: const Text(
                            'PDF Ordonnance',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () {
                            AppLogger.logInterface(
                              'Téléchargement PDF Ordonnance',
                              fileName: 'doctor_home_screen.dart',
                              details: 'Export PDF pour $patientName',
                            );
                            final firstAtt = attachments.isNotEmpty ? attachments.first : null;
                            final fileName = firstAtt != null
                                ? (firstAtt['name'] ?? 'ordonnance_scanne.pdf')
                                : 'ordonnance_medicale_${c['date'] ?? '2026'}.pdf';
                            _triggerRealDownload(context, fileName, consultation: c);
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
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
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppTheme.textColor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
