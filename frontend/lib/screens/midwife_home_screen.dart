import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar_widget.dart';
import 'patient_dossier_screen.dart';
import 'profile_screen.dart';


class MidwifeHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MidwifeHomeScreen({super.key, required this.onLogout});

  @override
  State<MidwifeHomeScreen> createState() => _MidwifeHomeScreenState();
}

class _MidwifeHomeScreenState extends State<MidwifeHomeScreen> {
  int _currentTab = 0;
  final api = ApiService();

  List<dynamic> patients = [];
  List<dynamic> vitalSigns = [];
  List<dynamic> beds = [];
  List<dynamic> alerts = [];
  List<dynamic> doctors = [];
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
            final creatorId = latest['createdBy'] is Map ? latest['createdBy']['_id'] : latest['createdBy'];
            final isMine = creatorId?.toString() == api.currentUser?['_id']?.toString();
            
            if (!isMine) {
              final pat = latest['patientId'];
              final patName = pat is Map ? '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim() : 'Patiente';

            NotificationService().showClinicalAlert(
              title: latest['title'] ?? 'Alerte Maternité',
              description: latest['description'] ?? '',
              level: latest['level'] ?? 'URGENT',
              patientName: patName,
            );

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFFBE185D),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                content: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🚨 ALERTE : ${latest['title'] ?? ''} ($patName)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
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
    final results = await Future.wait([
      api.getPatients(),
      api.getVitalSigns(),
      api.getBeds(),
      api.getAlerts(isResolved: false),
      api.getDoctors(),
    ]);
    if (mounted) {
      setState(() {
        patients = results[0];
        vitalSigns = results[1];
        beds = results[2];
        alerts = results[3];
        doctors = results[4];
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
                        const Icon(Icons.notifications_active, color: Color(0xFFBE185D)),
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
                              'Aucune alerte obstétricale active',
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
                              : 'Patiente';

                          final targetDoctor = alert['targetDoctorId'];
                          final createdBy = alert['createdBy'];
                          final creatorName = createdBy is Map
                              ? '${createdBy['role'] == 'MIDWIFE' ? 'Sage-femme ' : createdBy['role'] == 'DOCTOR' ? 'Dr. ' : 'Inf. '}${createdBy['firstName'] ?? ''} ${createdBy['lastName'] ?? ''}'.trim()
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isCritical ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isCritical ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
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
                                            color: isCritical ? const Color(0xFF9F1239) : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isCritical ? const Color(0xFFE11D48) : const Color(0xFF0284C7),
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
                                            color: const Color(0xFFFDF2F8),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFFBCFE8)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.person_pin, size: 14, color: Color(0xFFBE185D)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Destiné à : Dr. ${targetDoctor['firstName'] ?? ''} ${targetDoctor['lastName'] ?? ''}'.trim(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF9D174D),
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
                                                'Diffusion : Tous les obstétriciens/médecins',
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

  // 🚨 Créer une alerte médicale / obstétricale ciblée
  void _showCreateAlertModal({String? preselectedPatientId, String? initialDescription}) {
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune patiente disponible')),
      );
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
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFBE185D), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Alerte Obstétricale & Gynécologue',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Patiente concernée *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedPatientId,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: patients.map<DropdownMenuItem<String>>((p) {
                    final u = p['userId'] is Map ? p['userId'] : (p['user'] is Map ? p['user'] : null);
                    final fn = p['firstName'] ?? u?['firstName'] ?? '';
                    final ln = p['lastName'] ?? u?['lastName'] ?? '';
                    final fullName = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : (p['name'] ?? 'Patiente');
                    return DropdownMenuItem<String>(
                      value: p['_id'],
                      child: Text('$fullName (${p['cin'] ?? '—'})', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final selectedPat = patients.firstWhere((p) => p['_id'] == val, orElse: () => null);
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
                    final selPat = patients.firstWhere((p) => p['_id'] == selectedPatientId, orElse: () => null);
                    final doc = selPat != null ? selPat['attendingDoctorId'] : null;
                    final docName = doc is Map ? 'Dr. ${doc['firstName'] ?? ''} ${doc['lastName'] ?? ''}'.trim() : null;
                    final docId = doc is Map ? doc['_id']?.toString() : doc?.toString();
                    final nurse = selPat != null ? selPat['assignedNurseId'] : null;
                    final nurseName = nurse is Map ? 'Inf. ${nurse['firstName'] ?? ''} ${nurse['lastName'] ?? ''}'.trim() : null;
                    final nurseId = nurse is Map ? nurse['_id']?.toString() : nurse?.toString();

                    if (docName == null && nurseName == null) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF2F8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFCE7F3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Équipe soignante associée à la patiente :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9D174D))),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (docName != null)
                                ActionChip(
                                  backgroundColor: selectedDoctorUserId == docId ? const Color(0xFFBE185D) : Colors.white,
                                  avatar: Icon(Icons.medical_services, size: 14, color: selectedDoctorUserId == docId ? Colors.white : const Color(0xFFBE185D)),
                                  label: Text('Gynéco : $docName', style: TextStyle(fontSize: 11, color: selectedDoctorUserId == docId ? Colors.white : const Color(0xFF9D174D), fontWeight: FontWeight.bold)),
                                  onPressed: () => setModalState(() => selectedDoctorUserId = docId),
                                ),
                              if (nurseName != null)
                                ActionChip(
                                  backgroundColor: selectedDoctorUserId == nurseId ? const Color(0xFF059669) : Colors.white,
                                  avatar: Icon(Icons.local_hospital, size: 14, color: selectedDoctorUserId == nurseId ? Colors.white : const Color(0xFF059669)),
                                  label: Text('Infirmière : $nurseName', style: TextStyle(fontSize: 11, color: selectedDoctorUserId == nurseId ? Colors.white : const Color(0xFF065F46), fontWeight: FontWeight.bold)),
                                  onPressed: () => setModalState(() => selectedDoctorUserId = nurseId),
                                ),
                              ActionChip(
                                backgroundColor: selectedDoctorUserId == null ? const Color(0xFF334155) : Colors.white,
                                avatar: Icon(Icons.campaign, size: 14, color: selectedDoctorUserId == null ? Colors.white : const Color(0xFF334155)),
                                label: Text('Équipe de garde', style: TextStyle(fontSize: 11, color: selectedDoctorUserId == null ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.bold)),
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
                const Text('Médecin / Destinataire de l\'alerte *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                      child: Text('📢 Tous les médecins / gynécologues de garde', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFBE185D)), overflow: TextOverflow.ellipsis),
                    ),
                    ...doctors.map<DropdownMenuItem<String?>>((doc) {
                      final u = doc['userId'];
                      final docUserId = u is Map ? u['_id']?.toString() : doc['userId']?.toString();
                      final name = u is Map ? '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim() : 'Dr.';
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
                const Text('Motif de l\'alerte *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: alertType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: alertCategories.map((type) {
                    return DropdownMenuItem<String>(value: type, child: Text(type, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => alertType = val);
                  },
                ),

                const SizedBox(height: 12),
                const Text('Niveau d\'urgence *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('⚠️ URGENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        selected: priority == 'URGENT',
                        selectedColor: const Color(0xFFFCE7F3),
                        onSelected: (sel) => setModalState(() => priority = 'URGENT'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('🚨 CRITIQUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        selected: priority == 'CRITICAL',
                        selectedColor: const Color(0xFFFFE4E6),
                        onSelected: (sel) => setModalState(() => priority = 'CRITICAL'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Text('Observations cliniques & Détails', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                      backgroundColor: const Color(0xFFBE185D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text('Émettre l\'Alerte Immédiate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
                            backgroundColor: Color(0xFF059669),
                            content: Text('✅ Alerte obstétricale transmise au médecin avec succès !'),
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

  // 📊 Saisie complète des constantes obstétricales & fœto-maternelles
  void _showCreateObstetricVitalsModal({String? preselectedPatientId}) {
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
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.pregnant_woman, color: Color(0xFFBE185D), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Constantes Fœto-Maternelles',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Patiente *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedPatientId,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: patients.map<DropdownMenuItem<String>>((p) {
                    final u = p['userId'] is Map ? p['userId'] : (p['user'] is Map ? p['user'] : null);
                    final fn = p['firstName'] ?? u?['firstName'] ?? '';
                    final ln = p['lastName'] ?? u?['lastName'] ?? '';
                    final fullName = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : (p['name'] ?? 'Patiente');
                    return DropdownMenuItem<String>(
                      value: p['_id'],
                      child: Text('$fullName (${p['cin'] ?? '—'})', overflow: TextOverflow.ellipsis),
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
                    color: const Color(0xFFFDF2F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCE7F3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                           Icon(Icons.child_care, color: Color(0xFFBE185D), size: 18),
                          SizedBox(width: 6),
                          Text('Surveillance Fœtale & Obstétrique', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9D174D))),
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
                                prefixIcon: Icon(Icons.favorite, size: 16, color: Color(0xFFBE185D)),
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
                              decoration: const InputDecoration(labelText: 'Poche des eaux', border: OutlineInputBorder()),
                              items: ['Intacte', 'Rompue', 'Fissurée'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setModalState(() => membraneState = v ?? 'Intacte'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: fluidColor,
                              decoration: const InputDecoration(labelText: 'Liquide', border: OutlineInputBorder()),
                              items: ['Clair', 'Méconial', 'Teinté', 'Sanguinolent'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setModalState(() => fluidColor = v ?? 'Clair'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),
                const Text('Constantes Maternelles Standard', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'TA Syst (mmHg)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: diaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'TA Diast (mmHg)', border: OutlineInputBorder()),
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
                        decoration: const InputDecoration(labelText: 'T° (°C)', border: OutlineInputBorder()),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: spo2Ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'SpO2 (%)', border: OutlineInputBorder()),
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
                      backgroundColor: const Color(0xFFBE185D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Enregistrer le Relevé Obstétrical', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

                      final fullNotes = 'Obstétrique [BCF: $fhr bpm, HU: $hu cm, CU: $cu/10min, Dilat: $dil cm, Poche: $membraneState, Liq: $fluidColor]. ${notesCtrl.text.trim()}';

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
                              backgroundColor: Color(0xFF059669),
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

  @override
  Widget build(BuildContext context) {
    final user = api.currentUser;
    final fullName = '${user?['firstName'] ?? ''} ${user?['lastName'] ?? ''}'.trim();

    return Scaffold(
      drawer: AppDrawer(
        onSelectTab: (idx) => setState(() => _currentTab = idx),
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      appBar: AppBar(
        backgroundColor: AppTheme.getRoleColor('MIDWIFE'),
        foregroundColor: Colors.white,
        elevation: 0,
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
                errorBuilder: (context, error, stackTrace) => const Icon(CupertinoIcons.person_2_fill, color: AppTheme.primary, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Maternité & Pôle Mère-Enfant',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    fullName.isNotEmpty ? fullName : 'Sage-femme Arij',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Bouton d'alertes avec compteur

          // Bouton cloche d'alertes avec badge dynamique
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Alertes Maternité',
                onPressed: _showAlertsModal,
              ),
              if (unreadAlertCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFBE185D), shape: BoxShape.circle),
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
                role: 'MIDWIFE',
                radius: 18,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentTab,
              children: [
                _buildMaternityOverviewTab(),
                _buildBedsTab(),
                _buildVitalsTab(),
                _buildLaborTrackingTab(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (idx) => setState(() => _currentTab = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.child_friendly_outlined),
            selectedIcon: Icon(Icons.child_friendly),
            label: 'Maternité',
          ),
          NavigationDestination(
            icon: Icon(Icons.single_bed_outlined),
            selectedIcon: Icon(Icons.single_bed),
            label: 'Boxes & Lits',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Constantes',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Suivi Travail',
          ),
        ],
      ),
    );
  }

  // 👩‍🍼 Onglet 1 : Tableau de bord Maternité & Patientes
  Widget _buildMaternityOverviewTab() {
    final filtered = patients.where((p) {
      final q = patientSearchQuery.toLowerCase();
      final fn = (p['firstName'] ?? '').toString().toLowerCase();
      final ln = (p['lastName'] ?? '').toString().toLowerCase();
      final cin = (p['cin'] ?? '').toString().toLowerCase();
      return fn.contains(q) || ln.contains(q) || cin.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bannière dégradée
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFFBE185D)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Polyclinique Arij — Pôle Obstétrique',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Unité Mère-Enfant & Suites de Couches',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${patients.length} Patientes', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${beds.length} Lits & Boxes', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.child_care, size: 52, color: Colors.white24),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Boutons d'actions rapides
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBE185D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.favorite_border, size: 18),
                  label: const Text('Prendre Constantes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _showCreateObstetricVitalsModal(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.warning_amber, size: 18),
                  label: const Text('Alerter Médecin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _showCreateAlertModal(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Barre de recherche
          TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher une patiente (Nom, Prénom, CIN)...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (val) => setState(() => patientSearchQuery = val),
          ),

          const SizedBox(height: 16),
          const Text('Patientes Suivies en Maternité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),

          if (filtered.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Aucune patiente trouvée', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ...filtered.map((p) {
              final u = p['userId'] is Map ? p['userId'] : (p['user'] is Map ? p['user'] : null);
              final fn = p['firstName'] ?? u?['firstName'] ?? '';
              final ln = p['lastName'] ?? u?['lastName'] ?? '';
              final fullName = '$fn $ln'.trim().isNotEmpty ? '$fn $ln'.trim() : (p['name'] ?? 'Patiente Maternité');
              final rawAllergies = p['allergies'];
              final allergiesStr = rawAllergies is List ? rawAllergies.join(', ') : (rawAllergies?.toString() ?? '');
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFFFCE7F3),
                    child: Icon(Icons.pregnant_woman, color: Color(0xFFBE185D)),
                  ),
                  title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('CIN: ${p['cin'] ?? '—'} | Groupe: ${p['bloodType'] ?? 'O+'}'),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF2F8),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFBCFE8)),
                            ),
                            child: const Text('Suivi Maternité', style: TextStyle(color: Color(0xFFBE185D), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          if (allergiesStr.isNotEmpty && allergiesStr.toLowerCase() != 'aucune')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('⚠️ Allergies: $allergiesStr', style: const TextStyle(color: Colors.red, fontSize: 10)),
                            ),
                        ],
                      ),
                      // Équipe soignante associée
                      Builder(
                        builder: (context) {
                          final doc = p['attendingDoctorId'];
                          final docName = doc is Map ? 'Dr. ${doc['firstName'] ?? ''} ${doc['lastName'] ?? ''}'.trim() : null;
                          final nurse = p['assignedNurseId'];
                          final nurseName = nurse is Map ? 'Inf. ${nurse['firstName'] ?? ''} ${nurse['lastName'] ?? ''}'.trim() : null;

                          if (docName == null && nurseName == null) return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (docName != null && docName.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text('👨‍⚕️ $docName (Gynéco)', style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 10, fontWeight: FontWeight.w600)),
                                  ),
                                if (nurseName != null && nurseName.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                    ),
                                    child: Text('💉 $nurseName', style: const TextStyle(color: Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.w600)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'dossier') _openPatientDossier(p as Map<String, dynamic>);
                      if (action == 'vitals') _showCreateObstetricVitalsModal(preselectedPatientId: p['_id']);
                      if (action == 'alert') _showCreateAlertModal(preselectedPatientId: p['_id']);
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'dossier', child: Row(children: [Icon(Icons.folder_shared, size: 18), SizedBox(width: 8), Text('Dossier Médical')])),
                      const PopupMenuItem(value: 'vitals', child: Row(children: [Icon(Icons.favorite, size: 18, color: Color(0xFFBE185D)), SizedBox(width: 8), Text('Prendre Constantes')])),
                      const PopupMenuItem(value: 'alert', child: Row(children: [Icon(Icons.warning, size: 18, color: Colors.red), SizedBox(width: 8), Text('Alerter Médecin')])),
                    ],
                  ),
                  onTap: () => _openPatientDossier(p as Map<String, dynamic>),
                ),
              );
            }),
        ],
      ),
    );
  }

  // 🛏️ Onglet 2 : Boxes d'Accouchement & Lits de Maternité
  Widget _buildBedsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: beds.isEmpty
          ? const Center(child: Text('Aucun lit configuré'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Boxes de Travail & Chambres Maternité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...beds.map((bed) {
                  final status = bed['status'] ?? 'AVAILABLE';
                  final isOccupied = status == 'OCCUPIED' || bed['isOccupied'] == true;
                  final room = bed['roomId'];
                  final roomNum = room is Map ? room['number'] : (bed['roomNumber'] ?? '101');
                  final roomDept = room is Map ? room['department'] : 'Maternité';
                  final bedNum = bed['number'] ?? bed['bedNumber'] ?? '1';
                  final patient = bed['currentPatientId'];
                  final patName = patient is Map ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim() : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isOccupied ? const Color(0xFFFCE7F3) : const Color(0xFFECFDF5),
                        child: Icon(Icons.single_bed, color: isOccupied ? const Color(0xFFBE185D) : const Color(0xFF059669)),
                      ),
                      title: Text('Box / Lit : $bedNum — Chambre $roomNum ($roomDept)', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(isOccupied ? 'Occupé par : ${patName ?? 'Patiente'}' : 'Disponible pour accouchement / suites de couches', style: TextStyle(color: isOccupied ? const Color(0xFFBE185D) : const Color(0xFF059669))),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOccupied ? const Color(0xFFFCE7F3) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOccupied ? 'OCCUPÉ' : 'LIBRE',
                          style: TextStyle(
                            color: isOccupied ? const Color(0xFFBE185D) : const Color(0xFF059669),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  // 📊 Onglet 3 : Constantes Fœto-Maternelles
  Widget _buildVitalsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: vitalSigns.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Aucun relevé de constantes enregistré'),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateObstetricVitalsModal(),
                    icon: const Icon(Icons.add),
                    label: const Text('Enregistrer constantes'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vitalSigns.length,
              itemBuilder: (context, idx) {
                final v = vitalSigns[idx];
                final pat = v['patientId'];
                final pu = pat is Map ? (pat['userId'] is Map ? pat['userId'] : (pat['user'] is Map ? pat['user'] : null)) : null;
                final pfn = pat is Map ? (pat['firstName'] ?? pu?['firstName'] ?? '') : '';
                final pln = pat is Map ? (pat['lastName'] ?? pu?['lastName'] ?? '') : '';
                final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : (pat is Map ? (pat['name'] ?? 'Patiente') : 'Patiente');
                final notes = (v['notes'] ?? '').toString();
                final isObstetric = notes.contains('Obstétrique');

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(patName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isObstetric ? const Color(0xFFFDF2F8) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isObstetric ? '🤰 Fœto-Maternel' : 'Standard',
                                style: TextStyle(
                                  color: isObstetric ? const Color(0xFFBE185D) : const Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('TA: ${v['bloodPressureSystolic'] ?? '—'}/${v['bloodPressureDiastolic'] ?? '—'} mmHg', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            Text('T°: ${v['temperature'] ?? '—'}°C'),
                            const SizedBox(width: 12),
                            Text('Pouls: ${v['heartRate'] ?? '—'} bpm'),
                            const SizedBox(width: 12),
                            Text('SpO2: ${v['oxygenSaturation'] ?? '—'}%'),
                          ],
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(notes, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ⏱️ Onglet 4 : Suivi du Travail & Partogramme
  Widget _buildLaborTrackingTab() {
    final laborVitals = vitalSigns.where((v) => (v['notes'] ?? '').toString().contains('Dilat:') || (v['notes'] ?? '').toString().contains('BCF:')).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.timeline, color: Color(0xFFBE185D)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Surveillance active de l\'évolution du travail & BCF pour les femmes en salle d\'accouchement.',
                    style: TextStyle(color: Color(0xFF9F1239), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (laborVitals.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Aucun enregistrement de travail actif', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ...laborVitals.map((v) {
              final pat = v['patientId'];
              final pu = pat is Map ? (pat['userId'] is Map ? pat['userId'] : (pat['user'] is Map ? pat['user'] : null)) : null;
              final pfn = pat is Map ? (pat['firstName'] ?? pu?['firstName'] ?? '') : '';
              final pln = pat is Map ? (pat['lastName'] ?? pu?['lastName'] ?? '') : '';
              final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : (pat is Map ? (pat['name'] ?? 'Patiente') : 'Patiente');
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('🤰 $patName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Text('Partogramme', style: TextStyle(color: Color(0xFFBE185D), fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(v['notes'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                      const SizedBox(height: 6),
                      Text('Constantes mère : TA ${v['bloodPressureSystolic'] ?? '—'}/${v['bloodPressureDiastolic'] ?? '—'} mmHg — Pouls ${v['heartRate'] ?? '—'} bpm — T° ${v['temperature'] ?? '—'}°C', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
