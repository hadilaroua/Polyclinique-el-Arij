import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/app_logger.dart';
import '../utils/briefing_utils.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dark_ambient_background.dart';
import '../widgets/figma_header.dart';
import '../widgets/ios_bottom_nav_bar.dart';
import '../widgets/patient_worklist_card.dart';
import '../widgets/unified_vital_signs_modal.dart';
import '../widgets/rooms_and_beds_view.dart';
import 'ai_briefing_screen.dart';
import 'patient_dossier_screen.dart';
import 'profile_screen.dart';
import 'calendar/clinical_calendar_screen.dart';

class MidwifeHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MidwifeHomeScreen({super.key, required this.onLogout});

  @override
  State<MidwifeHomeScreen> createState() => _MidwifeHomeScreenState();
}

class _MidwifeHomeScreenState extends State<MidwifeHomeScreen> {
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
  bool isLoading = true;
  String patientSearchQuery = '';

  Timer? _realtimeTimer;

  int get unreadAlertCount => alerts.where((a) {
    final id = a['_id']?.toString();
    return id != null && !_readAlertIds.contains(id);
  }).length;

  @override
  void initState() {
    super.initState();
    AppLogger.logInterface(
      'Espace Sage-Femme - Salle de Naissance',
      fileName: 'midwife_home_screen.dart',
      details: 'Initialisation espace maternité',
    );
    _loadReadAlertIds();
    _loadData();
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
      final list = prefs.getStringList('arij_midwife_read_alerts') ?? [];
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
      await prefs.setStringList('arij_midwife_read_alerts', _readAlertIds.toList());
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
        final newAlerts = await api.getAlerts(isResolved: false);
        if (!mounted) return;

        final oldCount = alerts.length;
        final newCount = newAlerts.length;

        if (oldCount != newCount) {
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
                  : 'Patiente';

              NotificationService().showClinicalAlert(
                title: latest['title'] ?? 'Alerte Maternité',
                description: latest['description'] ?? '',
                level: latest['level'] ?? 'URGENT',
                patientName: patName,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.evergreen,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                  content: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '🚨 ALERTE : ${latest['title'] ?? ''} ($patName)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final results = await Future.wait<dynamic>([
      api.getPatients(),
      api.getVitalSigns(),
      api.getBeds(),
      api.getAlerts(isResolved: false),
      api.getDoctors(),
      api.getDailyBriefing(),
    ]);
    if (mounted) {
      setState(() {
        patients = results[0];
        vitalSigns = results[1];
        beds = results[2];
        alerts = results[3];
        doctors = results[4];
        dailyBriefing = results[5];
        isLoading = false;
      });
    }
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
                        const Icon(Icons.notifications_active, color: AppTheme.evergreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Alertes Maternité (${alerts.length})',
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
                              'Aucune alerte obstétricale active',
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
                              : 'Patiente';

                          final targetDoctor = alert['targetDoctorId'];
                          final createdBy = alert['createdBy'];
                          final creatorName = createdBy is Map
                              ? '${createdBy['role'] == 'MIDWIFE'
                                        ? 'Sage-femme '
                                        : createdBy['role'] == 'DOCTOR'
                                        ? 'Dr. '
                                        : 'Inf. '}${createdBy['firstName'] ?? ''} ${createdBy['lastName'] ?? ''}'
                                    .trim()
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isCritical ? const Color(0xFFEDF2EA) : AppTheme.background,
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
                                          alert['title'] ?? 'Alerte Maternité',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isCritical
                                                ? AppTheme.evergreen
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
                                                  ? AppTheme.evergreen
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
                                            color: const Color(0xFFEDF2EA),
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
                                                'Diffusion : Tous les obstétriciens/médecins',
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

  // 🚨 Créer une alerte médicale / obstétricale ciblée
  void _showCreateAlertModal({String? preselectedPatientId, String? initialDescription}) {
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Aucune patiente disponible')));
      return;
    }

    String selectedPatientId = preselectedPatientId ?? patients.first['_id'];
    String? selectedDoctorUserId;
    String alertType = 'Rythme Cardiaque Fœtal anormal (BCF)';
    String priority = 'URGENT';
    final descCtrl = TextEditingController(text: initialDescription ?? '');

    final alertCategories = [
      'Rythme Cardiaque Fœtal anormal (BCF)',
      'Suspicion Prééclampsie / HTA gravidique',
      'Hémorragie de la délivrance / Saignement',
      'Arrêt de progression du travail',
      'Rupture prématurée des membranes (RPM)',
      'Fièvre maternelle / Chorioamniotite',
      'Autre urgence obstétricale',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                    Icon(Icons.warning_amber_rounded, color: AppTheme.evergreen, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Alerte Obstétricale & Gynécologue',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text(
                  'Patiente concernée *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedPatientId,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: patients.map<DropdownMenuItem<String>>((p) {
                    final u = p['userId'] is Map
                        ? p['userId']
                        : (p['user'] is Map ? p['user'] : null);
                    final fn = p['firstName'] ?? u?['firstName'] ?? '';
                    final ln = p['lastName'] ?? u?['lastName'] ?? '';
                    final fullName = '$fn $ln'.trim().isNotEmpty
                        ? '$fn $ln'.trim()
                        : (p['name'] ?? 'Patiente');
                    return DropdownMenuItem<String>(
                      value: p['_id'],
                      child: Text(
                        '$fullName (${p['cin'] ?? '—'})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final selectedPat = patients.firstWhere(
                        (p) => p['_id'] == val,
                        orElse: () => null,
                      );
                      final doc = selectedPat != null ? selectedPat['attendingDoctorId'] : null;
                      final docId = doc is Map ? doc['_id']?.toString() : doc?.toString();
                      setModalState(() {
                        selectedPatientId = val;
                        if (docId != null) selectedDoctorUserId = docId;
                      });
                    }
                  },
                ),

                // Équipe soignante attitrée
                Builder(
                  builder: (context) {
                    final selPat = patients.firstWhere(
                      (p) => p['_id'] == selectedPatientId,
                      orElse: () => null,
                    );
                    final doc = selPat != null ? selPat['attendingDoctorId'] : null;
                    final docName = doc is Map
                        ? 'Dr. ${doc['firstName'] ?? ''} ${doc['lastName'] ?? ''}'.trim()
                        : null;
                    final docId = doc is Map ? doc['_id']?.toString() : doc?.toString();
                    final nurse = selPat != null ? selPat['assignedNurseId'] : null;
                    final nurseName = nurse is Map
                        ? 'Inf. ${nurse['firstName'] ?? ''} ${nurse['lastName'] ?? ''}'.trim()
                        : null;
                    final nurseId = nurse is Map ? nurse['_id']?.toString() : nurse?.toString();

                    if (docName == null && nurseName == null) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF2EA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.dustGrey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Équipe soignante associée à la patiente :',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.evergreen,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (docName != null)
                                ActionChip(
                                  backgroundColor: selectedDoctorUserId == docId
                                      ? AppTheme.evergreen
                                      : Colors.white,
                                  avatar: Icon(
                                    Icons.medical_services,
                                    size: 14,
                                    color: selectedDoctorUserId == docId
                                        ? Colors.white
                                        : AppTheme.evergreen,
                                  ),
                                  label: Text(
                                    'Gynéco : $docName',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: selectedDoctorUserId == docId
                                          ? Colors.white
                                          : AppTheme.evergreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () =>
                                      setModalState(() => selectedDoctorUserId = docId),
                                ),
                              if (nurseName != null)
                                ActionChip(
                                  backgroundColor: selectedDoctorUserId == nurseId
                                      ? AppTheme.evergreen
                                      : Colors.white,
                                  avatar: Icon(
                                    Icons.local_hospital,
                                    size: 14,
                                    color: selectedDoctorUserId == nurseId
                                        ? Colors.white
                                        : AppTheme.evergreen,
                                  ),
                                  label: Text(
                                    'Infirmière : $nurseName',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: selectedDoctorUserId == nurseId
                                          ? Colors.white
                                          : AppTheme.evergreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () =>
                                      setModalState(() => selectedDoctorUserId = nurseId),
                                ),
                              ActionChip(
                                backgroundColor: selectedDoctorUserId == null
                                    ? AppTheme.darkElevated
                                    : Colors.white,
                                avatar: Icon(
                                  Icons.campaign,
                                  size: 14,
                                  color: selectedDoctorUserId == null
                                      ? Colors.white
                                      : AppTheme.darkElevated,
                                ),
                                label: Text(
                                  'Équipe de garde',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: selectedDoctorUserId == null
                                        ? Colors.white
                                        : AppTheme.darkElevated,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () => setModalState(() => selectedDoctorUserId = null),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),
                const Text(
                  'Médecin / Destinataire de l\'alerte *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: selectedDoctorUserId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Sélectionner le praticien',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        '📢 Tous les médecins / gynécologues de garde',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.evergreen),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...doctors.map<DropdownMenuItem<String?>>((doc) {
                      final u = doc['userId'];
                      final docUserId = u is Map ? u['_id']?.toString() : doc['userId']?.toString();
                      final name = u is Map
                          ? '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim()
                          : 'Dr.';
                      final spec = doc['specialty'] ?? 'Médecin';
                      return DropdownMenuItem<String?>(
                        value: docUserId,
                        child: Text('👨‍⚕️ Dr. $name ($spec)', overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (val) => setModalState(() => selectedDoctorUserId = val),
                ),

                const SizedBox(height: 12),
                const Text(
                  'Motif de l\'alerte *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: alertType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: alertCategories.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
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
                        selectedColor: AppTheme.dustGrey,
                        onSelected: (sel) => setModalState(() => priority = 'URGENT'),
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
                        selectedColor: const Color(0xFFEDF2EA),
                        onSelected: (sel) => setModalState(() => priority = 'CRITICAL'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Text(
                  'Observations cliniques & Détails',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ex: BCF ralenti à 95 bpm persistant. CU intenses. Dr. Gynécologue demandé en salle d\'accouchement.',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.evergreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text(
                      'Émettre l\'Alerte Immédiate',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final res = await api.createAlert(
                        patientId: selectedPatientId,
                        targetDoctorId: selectedDoctorUserId,
                        title: alertType,
                        description: descCtrl.text.trim().isNotEmpty
                            ? descCtrl.text.trim()
                            : 'Alerte déclenchée par la sage-femme pour $alertType',
                        level: priority,
                      );

                      if (res['success'] == true) {
                        _loadData();
                        messenger.showSnackBar(
                          const SnackBar(
                            backgroundColor: AppTheme.evergreen,
                            content: Text(
                              '✅ Alerte obstétricale transmise au médecin avec succès !',
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

  void _showCreateObstetricVitalsModal({String? preselectedPatientId}) {
    UnifiedVitalSignsModal.show(
      context,
      preselectedPatientId: preselectedPatientId,
      patientsList: patients,
      onSuccess: () {
        _loadData();
      },
    );
  }

  void _unusedOldObstetricModal({String? preselectedPatientId}) {
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune patiente')));
      return;
    }

    String selectedPatientId = preselectedPatientId ?? patients.first['_id'];
    final sysCtrl = TextEditingController(text: '120');
    final diaCtrl = TextEditingController(text: '80');
    final hrCtrl = TextEditingController(text: '78');
    final tempCtrl = TextEditingController(text: '37.0');
    final spo2Ctrl = TextEditingController(text: '98');

    // Obstétrique
    final fhrCtrl = TextEditingController(text: '140'); // BCF
    final huCtrl = TextEditingController(text: '32'); // Hauteur Utérine cm
    final cuCtrl = TextEditingController(text: '3'); // Contractions / 10min
    final dilCtrl = TextEditingController(text: '4'); // Dilatation col cm
    String membraneState = 'Intacte';
    String fluidColor = 'Clair';
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                    Icon(Icons.pregnant_woman, color: AppTheme.evergreen, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Constantes Fœto-Maternelles',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text(
                  'Patiente *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedPatientId,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: patients.map<DropdownMenuItem<String>>((p) {
                    final u = p['userId'] is Map
                        ? p['userId']
                        : (p['user'] is Map ? p['user'] : null);
                    final fn = p['firstName'] ?? u?['firstName'] ?? '';
                    final ln = p['lastName'] ?? u?['lastName'] ?? '';
                    final fullName = '$fn $ln'.trim().isNotEmpty
                        ? '$fn $ln'.trim()
                        : (p['name'] ?? 'Patiente');
                    return DropdownMenuItem<String>(
                      value: p['_id'],
                      child: Text(
                        '$fullName (${p['cin'] ?? '—'})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedPatientId = val);
                  },
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2EA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dustGrey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.child_care, color: AppTheme.evergreen, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Surveillance Fœtale & Obstétrique',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.evergreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: fhrCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'BCF (bpm)',
                                hintText: '110-160',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.favorite,
                                  size: 16,
                                  color: AppTheme.evergreen,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: huCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'H. Utérine (cm)',
                                hintText: 'ex: 32',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cuCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'CU (/10 min)',
                                hintText: 'Contractions',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: dilCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Dilatation (cm)',
                                hintText: '0 à 10',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: membraneState,
                              decoration: const InputDecoration(
                                labelText: 'Poche des eaux',
                                border: OutlineInputBorder(),
                              ),
                              items: ['Intacte', 'Rompue', 'Fissurée']
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s, style: const TextStyle(fontSize: 12)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setModalState(() => membraneState = v ?? 'Intacte'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: fluidColor,
                              decoration: const InputDecoration(
                                labelText: 'Liquide',
                                border: OutlineInputBorder(),
                              ),
                              items: ['Clair', 'Méconial', 'Teinté', 'Sanguinolent']
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s, style: const TextStyle(fontSize: 12)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setModalState(() => fluidColor = v ?? 'Clair'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Text(
                  'Constantes Maternelles Standard',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'TA Syst (mmHg)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: diaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'TA Diast (mmHg)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tempCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'T° (°C)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: hrCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Pouls (bpm)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: spo2Ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'SpO2 (%)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observations sage-femme',
                    hintText: 'Présentation céphalique, col souple, tolérance maternelle...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.evergreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'Enregistrer le Relevé Obstétrical',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final sys = int.tryParse(sysCtrl.text.trim());
                      final dia = int.tryParse(diaCtrl.text.trim());
                      final hr = int.tryParse(hrCtrl.text.trim());
                      final temp = double.tryParse(tempCtrl.text.trim());
                      final spo2 = int.tryParse(spo2Ctrl.text.trim());
                      final fhr = fhrCtrl.text.trim();
                      final hu = huCtrl.text.trim();
                      final cu = cuCtrl.text.trim();
                      final dil = dilCtrl.text.trim();

                      final fullNotes =
                          'Obstétrique [BCF: $fhr bpm, HU: $hu cm, CU: $cu/10min, Dilat: $dil cm, Poche: $membraneState, Liq: $fluidColor]. ${notesCtrl.text.trim()}';

                      Navigator.pop(ctx);
                      final res = await api.createVitalSign(
                        patientId: selectedPatientId,
                        bloodPressureSystolic: sys,
                        bloodPressureDiastolic: dia,
                        heartRate: hr,
                        temperature: temp,
                        oxygenSaturation: spo2,
                        notes: fullNotes,
                      );

                      if (res['success'] == true) {
                        _loadData();

                        // Vérifier si seuils obstétricaux critiques
                        final fhrNum = double.tryParse(fhr);
                        final isAbnormalFHR = fhrNum != null && (fhrNum < 110 || fhrNum > 160);
                        final isHighBP = (sys != null && sys >= 140) || (dia != null && dia >= 90);

                        if (isAbnormalFHR || isHighBP) {
                          _showCreateAlertModal(
                            preselectedPatientId: selectedPatientId,
                            initialDescription: isAbnormalFHR
                                ? '⚠️ Anomalie BCF : $fhr bpm (Norme : 110-160). Intervention gynécologue recommandée.'
                                : '⚠️ HTA gravidique : TA $sys/$dia mmHg. Risque de prééclampsie.',
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              backgroundColor: AppTheme.evergreen,
                              content: Text('✅ Constantes obstétricales enregistrées !'),
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

  Widget? _buildMidwifeFab() {
    switch (_currentTab) {
      case 1:
        return _buildMediumFab(
          heroTag: 'midwife_fab_1',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: () => _showCreateObstetricVitalsModal(),
          icon: Icons.favorite_rounded,
          label: 'Saisir Constantes Obs.',
        );
      case 2:
        return _buildMediumFab(
          heroTag: 'midwife_fab_2',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: () => _showCreateObstetricVitalsModal(),
          icon: Icons.favorite,
          label: 'Enregistrer Constantes',
        );
      case 3:
        return _buildMediumFab(
          heroTag: 'midwife_fab_3',
          backgroundColor: AppTheme.alertRed,
          onPressed: () => _showCreateAlertModal(),
          icon: Icons.warning_amber_rounded,
          label: 'Créer Alerte',
        );
      case 0:
      default:
        return _buildMediumFab(
          heroTag: 'midwife_fab_0',
          backgroundColor: AppTheme.pastelOrange,
          onPressed: () => _showCreateObstetricVitalsModal(),
          icon: Icons.favorite,
          label: 'Enregistrer Constantes',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = api.currentUser;
    final fullName = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();
    final displayName = fullName.isEmpty ? 'Mme. Sage-Femme' : fullName;

    return Scaffold(
      key: _scaffoldKey,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _buildMidwifeFab(),
      drawer: AppDrawer(
        onSelectTab: (idx) => setState(() => _currentTab = idx),
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      body: Column(
        children: [
          FigmaHeader(
            roleName: 'SAGE-FEMME',
            roleColor: AppTheme.getRoleColor('MIDWIFE'),
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
                child: _buildCurrentTabContent(context, displayName),
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
            icon: CupertinoIcons.house,
            selectedIcon: CupertinoIcons.house_fill,
            label: 'Dashboard',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.person_2,
            selectedIcon: CupertinoIcons.person_2_fill,
            label: 'Patientes',
          ),
          IosBottomNavItem(
            icon: CupertinoIcons.waveform_path_ecg,
            selectedIcon: CupertinoIcons.waveform_path_ecg,
            label: 'Surveillance',
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

  Widget _buildCurrentTabContent(BuildContext context, String displayName) {
    switch (_currentTab) {
      case 1:
        return _buildPatientesTab();
      case 2:
        return _buildSurveillanceTab();
      case 3:
        return _buildAlertsTab();
      case 0:
      default:
        return _buildDashboardTab(displayName);
    }
  }

  Widget _buildDashboardTab(String displayName) {
    final isDark = AppTheme.isDarkMode(context);
    final myPatients = patients
        .where((p) => p['assignedMidwifeId'] == api.currentUser?['_id'])
        .length;
    final hospitalized = patients
        .where((p) => p['hospitalStay'] != null && p['hospitalStay']['status'] == 'ACTIVE')
        .length;

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
      fallback: 'Synthèse obstétricale matinale : 2 patientes en travail actif, surveillance monitorage fœtal recommandée.',
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
                colors: [AppTheme.evergreen, AppTheme.darkTeal],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.evergreen.withValues(alpha: 0.35),
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
                  'Synthèse Maternité & Obstétrique',
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
                        '+${hospitalized > 0 ? hospitalized : 4} patientes suivies',
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
                            Icons.pregnant_woman_rounded,
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
                      '${myPatients > 0 ? myPatients : 3}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Travail Actif',
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
                      'Alertes RCF',
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
                            Icons.child_care_rounded,
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
                              'Suivi',
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
                      '${hospitalized > 0 ? hospitalized : 5}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Post-Partum',
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
                      'Urgences & Alertes Vitales',
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
                        'SB',
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
                              'Mme Salma B.',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '• Box Accouchement 1',
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
                          '39 SA • Travail déclenché il y a 40 min',
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
                        'Rythme cardiaque fœtal : ralentissement modéré',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                    Text(
                      '2 min',
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
                          'Voir alertes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: OutlinedButton.icon(
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
                        icon: const Icon(
                          Icons.folder_shared_rounded,
                          size: 15,
                          color: Color(0xFF0F766E),
                        ),
                        label: const Text(
                          'Dossier patiente',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

        // ── Mes patientes ─────────────────────────────
        Text(
          'Patientes en Salle & Maternité',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ...patients.take(3).map((p) => _buildPatientListCard(p, isDark)),
      ],
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

  String _selectedMidwifeFilter = 'ALL';

  Widget _buildPatientesTab() {
    final isDark = AppTheme.isDarkMode(context);

    final filtered = patients.where((p) {
      // Filtre par catégorie maternité
      if (_selectedMidwifeFilter != 'ALL') {
        final dept = (p['department'] ?? '').toString().toUpperCase();
        final stay = p['hospitalStay'];
        final isHospitalized = stay != null && stay['status'] == 'ACTIVE';
        if (_selectedMidwifeFilter == 'TRAVAIL' && !isHospitalized) return false;
        if (_selectedMidwifeFilter == 'POSTPARTUM' && isHospitalized) return false;
        if (_selectedMidwifeFilter == 'EXTERNE' && isHospitalized) return false;
        if (_selectedMidwifeFilter == 'GROSSESSE' &&
            !dept.contains('MATERN') &&
            !dept.contains('OBSTET') &&
            !dept.contains('GROSS'))
          return false;
      }
      // Recherche textuelle
      final name = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.toLowerCase();
      final cin = (p['cin'] ?? '').toString().toLowerCase();
      final dossier = (p['dossierNumber'] ?? '').toString().toLowerCase();
      final q = patientSearchQuery.toLowerCase();
      return name.contains(q) || cin.contains(q) || dossier.contains(q);
    }).toList();

    return Column(
      children: [
        // ── En-tête Dossiers Patientes (Stitch Design) ──────────
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
                      'Dossiers Patientes',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textColor(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${filtered.length} dossiers maternité disponibles',
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

        // ── Barre de recherche Figma style ──────────
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

        // ── Filtres Maternité ──────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _midwifeFilterChip('Toutes', 'ALL', Icons.domain),
              const SizedBox(width: 8),
              _midwifeFilterChip('🤰 Grossesse', 'GROSSESSE', Icons.pregnant_woman),
              const SizedBox(width: 8),
              _midwifeFilterChip('🏥 Travail Actif', 'TRAVAIL', Icons.local_hospital),
              const SizedBox(width: 8),
              _midwifeFilterChip('👶 Post-Partum', 'POSTPARTUM', Icons.child_care),
              const SizedBox(width: 8),
              _midwifeFilterChip('📋 Suivi Externe', 'EXTERNE', Icons.assignment_outlined),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Liste des patientes ──────────
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
                            'Aucune patiente trouvée',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textColor(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            patientSearchQuery.isNotEmpty
                                ? 'Aucune patiente ne correspond à "$patientSearchQuery"'
                                : 'Aucune patiente ne correspond au filtre sélectionné.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppTheme.subtextColor(context)),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedMidwifeFilter = 'ALL';
                                patientSearchQuery = '';
                              });
                            },
                            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                            label: const Text('Afficher toutes les patientes'),
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
                      return PatientWorklistCard(patient: p, onTap: () => _openPatientDossier(p));
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _midwifeFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedMidwifeFilter == value;
    final isDark = AppTheme.isDarkMode(context);
    return InkWell(
      onTap: () => setState(() => _selectedMidwifeFilter = value),
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

  Widget _buildPatientListCard(Map<String, dynamic> p, bool isDark) {
    final name = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim();
    final cin = p['cin'] ?? '-';
    final dossier = p['dossierNumber'] ?? 'MAT-000';
    final blood = p['bloodType'] ?? 'Inconnu';
    final dept = p['department'] ?? 'Suivi Maternité';
    final allergiesRaw = p['allergies'];
    final allergies = allergiesRaw is List
        ? allergiesRaw.join(', ')
        : (allergiesRaw ?? '').toString();
    final stay = p['hospitalStay'];
    final isHospitalized = stay != null && stay['status'] == 'ACTIVE';

    // Médecin traitant
    final doc = p['attendingDoctorId'];
    final docName = doc is Map
        ? 'Dr. ${doc['firstName'] ?? ''} ${doc['lastName'] ?? ''}'.trim()
        : null;

    final prefix = p['gender'] == 'M' ? 'M.' : 'Mme.';
    final displayName = name.isEmpty
        ? 'Mme. Patiente'
        : (name.startsWith('M.') || name.startsWith('Mme.') ? name : '$prefix $name');
    final hasAllergies =
        allergies.isNotEmpty &&
        allergies.toLowerCase() != 'aucune' &&
        allergies.toLowerCase() != 'aucune connue';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
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
          onTap: () => _openPatientDossier(p),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Stitch Style avec initiales
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEDF2EA),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${p['firstName']?.toString().isNotEmpty == true ? p['firstName'].toString()[0] : 'P'}${p['lastName']?.toString().isNotEmpty == true ? p['lastName'].toString()[0] : 'X'}'
                              .toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.evergreen,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : AppTheme.darkBackground,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  'N° $dossier',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.evergreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${p['age'] ?? ''} ans • CIN: $cin',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white70 : AppTheme.evergreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.alertRed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Groupe $blood',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : AppTheme.darkBackground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  dept,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.evergreen,
                                  ),
                                ),
                              ),
                              if (isHospitalized)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_hospital,
                                        size: 11,
                                        color: Color(0xFFEA580C),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Hospitalisée',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFEA580C),
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
                ),
                // Allergies
                if (hasAllergies) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF2EA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_rounded, color: AppTheme.alertRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ALLERGIE : $allergies',
                            style: const TextStyle(
                              color: AppTheme.alertRed,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Médecin traitant
                if (docName != null && docName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkElevated : const Color(0xFFF0F7F4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.evergreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.medical_services, size: 14, color: AppTheme.evergreen),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Gynécologue : $docName',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.evergreen,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
                const SizedBox(height: 10),
                // Actions : Dossier 360° + Alerter le médecin
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _openPatientDossier(p),
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.evergreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_shared, size: 13, color: AppTheme.evergreen),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Dossier patient',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.evergreen,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 11,
                                color: AppTheme.evergreen,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            _showCreateAlertModal(preselectedPatientId: p['_id']?.toString()),
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notification_important,
                                size: 13,
                                color: Color(0xFFEA580C),
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Alerter Médecin',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFEA580C),
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildSurveillanceTab() {
    final isDark = AppTheme.isDarkMode(context);
    if (vitalSigns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.evergreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.monitor_heart_outlined,
                size: 48,
                color: isDark ? AppTheme.drySage : AppTheme.evergreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune constante enregistrée',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enregistrez les constantes fœto-maternelles\nvia le bouton en bas de l\'écran.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.subtextColor(context)),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vitalSigns.length > 15 ? 15 : vitalSigns.length,
      itemBuilder: (context, idx) {
        final v = vitalSigns[idx];
        final pat = v['patientId'];
        final patName = pat is Map
            ? '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim()
            : 'Patiente';
        final bp = '${v['bloodPressureSystolic'] ?? '-'}/${v['bloodPressureDiastolic'] ?? '-'}';
        final hr = v['heartRate']?.toString() ?? '-';
        final temp = v['temperature']?.toString() ?? '-';
        final spo2 = v['oxygenSaturation']?.toString() ?? '-';
        final notes = v['notes']?.toString() ?? '';
        final date = v['createdAt'] != null ? _formatDate(v['createdAt']) : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      patName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textColor(context),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (date.isNotEmpty)
                    Text(
                      date,
                      style: TextStyle(fontSize: 10, color: AppTheme.subtextColor(context)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMiniVital(isDark, '🩺 TA', bp, 'mmHg', Colors.purple)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildMiniVital(isDark, '❤️ FC', hr, 'bpm', Colors.red)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildMiniVital(isDark, '🌡 T°', temp, '°C', Colors.orange)),
                  const SizedBox(width: 6),
                  Expanded(child: _buildMiniVital(isDark, '🫁 SpO₂', spo2, '%', Colors.blue)),
                ],
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppTheme.subtextColor(context)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertsTab() {
    final isDark = AppTheme.isDarkMode(context);
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 48, color: AppTheme.evergreen),
            const SizedBox(height: 8),
            Text(
              'Aucune alerte active',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toutes les alertes ont été traitées.',
              style: TextStyle(fontSize: 13, color: AppTheme.subtextColor(context)),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length,
      itemBuilder: (context, idx) {
        final alert = alerts[idx];
        final isCritical = alert['level'] == 'CRITICAL' || alert['level'] == 'URGENT';
        final patient = alert['patientId'];
        final patName = patient is Map
            ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim()
            : 'Patiente';
        final createdBy = alert['createdBy'];
        final creatorName = createdBy is Map
            ? '${createdBy['role'] == 'MIDWIFE'
                      ? 'SF. '
                      : createdBy['role'] == 'DOCTOR'
                      ? 'Dr. '
                      : 'Inf. '}${createdBy['firstName'] ?? ''} ${createdBy['lastName'] ?? ''}'
                  .trim()
            : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCritical
                  ? const Color(0xFFEA580C).withValues(alpha: 0.4)
                  : AppTheme.borderColor(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      alert['title'] ?? 'Alerte Obstétricale',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isCritical ? const Color(0xFFEA580C) : AppTheme.textColor(context),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCritical ? const Color(0xFFEA580C) : AppTheme.evergreen,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      alert['level'] ?? 'INFO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                alert['description'] ?? '',
                style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 13, color: AppTheme.evergreen),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      patName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.evergreen,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (creatorName != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'par $creatorName',
                      style: TextStyle(fontSize: 10, color: AppTheme.subtextColor(context)),
                    ),
                  ],
                  if (alert['createdAt'] != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(alert['createdAt']),
                      style: TextStyle(fontSize: 10, color: AppTheme.subtextColor(context)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (patient is Map)
                    TextButton.icon(
                      icon: const Icon(Icons.folder_shared, size: 14),
                      label: const Text('Dossier', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _openPatientDossier(patient as Map<String, dynamic>),
                    ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.evergreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const Text(
                      'Clôturer',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () async {
                      await _handleResolveAlert(alert['_id']?.toString() ?? '', patName);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMidwifePatientDetails(Map<String, dynamic> patient) {
    final pfn = patient['firstName'] ?? '';
    final pln = patient['lastName'] ?? '';
    final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : 'Patiente';
    final patRegId = patient['dossierNumber'] ?? patient['registryId'] ?? 'MAT-Inconnu';
    final stay = patient['hospitalStay'];
    final room = stay != null && stay['room'] != null
        ? stay['room']['roomNumber']?.toString() ?? ''
        : 'N/A';
    final isDark = AppTheme.isDarkMode(context);
    final doc = patient['attendingDoctorId'];
    final docName = doc is Map
        ? 'Dr. ${doc['firstName'] ?? ''} ${doc['lastName'] ?? ''}'.trim()
        : null;

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
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: Color(0xFFEDF2EA), shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '${pfn.isNotEmpty ? pfn[0] : 'P'}${pln.isNotEmpty ? pln[0] : 'X'}'
                          .toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.evergreen,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
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
                        patName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dossier: $patRegId',
                        style: const TextStyle(
                          color: AppTheme.evergreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (docName != null && docName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Gynécologue : $docName',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2EA),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Service: Maternité',
                    style: TextStyle(
                      color: AppTheme.evergreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF2EA),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Chambre: $room',
                    style: TextStyle(
                      color: AppTheme.evergreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SURVEILLANCE SECTION
            const Text(
              'Dernières Constantes',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const Divider(),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(child: _buildMiniVital(isDark, '❤️ FC', '98', 'bpm', Colors.red)),
                const SizedBox(width: 10),
                Expanded(child: _buildMiniVital(isDark, '🌡 Temp', '37.2', '°C', Colors.orange)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildMiniVital(isDark, '🫁 SpO₂', '98', '%', Colors.blue)),
                const SizedBox(width: 10),
                Expanded(child: _buildMiniVital(isDark, '🩺 Tension', '110/70', '', Colors.purple)),
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
                icon: const Icon(Icons.add_chart),
                label: const Text(
                  'Enregistrer constantes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCreateObstetricVitalsModal(preselectedPatientId: patient['_id']?.toString());
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.notification_important),
                label: const Text(
                  'Envoyer Alerte au Médecin',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showCreateAlertModal(preselectedPatientId: patient['_id']?.toString());
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppTheme.evergreen),
                    ),
                    icon: const Icon(Icons.folder_shared, size: 18, color: AppTheme.evergreen),
                    label: const Text(
                      'Dossier patient',
                      style: TextStyle(color: AppTheme.evergreen),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openPatientDossier(patient);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniVital(bool isDark, String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.textColor(context),
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(unit, style: TextStyle(fontSize: 9, color: AppTheme.subtextColor(context))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
